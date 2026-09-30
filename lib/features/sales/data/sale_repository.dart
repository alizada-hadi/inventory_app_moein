import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/data/page_result.dart';
import '../../products/data/product.dart';
import 'sale.dart';

class SaleRepository {
  SaleRepository({AppDatabase? database})
    : database = database ?? AppDatabase.instance;
  final AppDatabase database;

  Future<Sale> createSale(Sale sale) async {
    final db = await database.database;
    return db.transaction((txn) async {
      final product = await _product(txn, sale.productId);
      final normalized = _normalize(sale, product);
      await _changeStock(txn, product.id!, -normalized.quantityBase);
      final id = await txn.insert('sales', normalized.toMap()..remove('id'));
      await _insertMovement(
        txn,
        product.id!,
        -normalized.quantityBase,
        id,
        normalized.saleDate,
        normalized.createdAt,
      );
      return normalized.copyWithId(id);
    });
  }

  Future<Sale?> getSaleById(int id) async {
    final rows = await (await database.database).query(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Sale.fromMap(rows.first);
  }

  Future<List<Sale>> getAllSales() async {
    final rows = await (await database.database).query(
      'sales',
      orderBy: 'sale_date DESC, id DESC',
    );
    return rows.map(Sale.fromMap).toList();
  }

  Future<PageResult<SaleListItem, SaleCursor>> getSalesPage({
    SaleCursor? cursor,
    int limit = 50,
  }) async {
    final args = <Object?>[];
    var where = '';
    if (cursor != null) {
      where = 'WHERE s.sale_date < ? OR (s.sale_date = ? AND s.id < ?)';
      args.addAll([cursor.saleDate, cursor.saleDate, cursor.id]);
    }
    final rows = await (await database.database).rawQuery('''
      SELECT s.id, s.product_id, s.quantity, s.unit, s.quantity_base,
             s.unit_price, s.currency, s.total_amount, s.sale_date, s.note,
             s.created_at, s.updated_at, p.name AS product_name
      FROM sales s JOIN products p ON p.id = s.product_id
      $where
      ORDER BY s.sale_date DESC, s.id DESC
      LIMIT ${limit + 1}
    ''', args);
    final pageRows = rows.take(limit).toList();
    final items = pageRows.map(SaleListItem.fromMap).toList(growable: false);
    final next = rows.length > limit && items.isNotEmpty
        ? SaleCursor(
            saleDate: pageRows.last['sale_date'] as String,
            id: pageRows.last['id'] as int,
          )
        : null;
    return PageResult(items: items, nextCursor: next);
  }

  Future<List<Sale>> getSalesByProduct(int productId, {int? limit}) async {
    final rows = await (await database.database).query(
      'sales',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'sale_date DESC, id DESC',
      limit: limit,
    );
    return rows.map(Sale.fromMap).toList();
  }

  Future<List<Sale>> getSalesByDateRange(DateTime from, DateTime to) async {
    final rows = await (await database.database).query(
      'sales',
      where: 'sale_date >= ? AND sale_date <= ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'sale_date DESC, id DESC',
    );
    return rows.map(Sale.fromMap).toList();
  }

  Future<Sale> updateSale(Sale sale) async {
    if (sale.id == null) throw ArgumentError('Sale id is required');
    final db = await database.database;
    return db.transaction((txn) async {
      final old = await _sale(txn, sale.id!);
      final oldProduct = await _product(txn, old.productId);
      final newProduct = await _product(txn, sale.productId);
      final normalized = _normalize(sale, newProduct);
      await _changeStock(txn, oldProduct.id!, old.quantityBase);
      await _changeStock(txn, newProduct.id!, -normalized.quantityBase);
      await txn.update(
        'sales',
        normalized.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [sale.id],
      );
      final movement = await txn.query(
        'stock_movements',
        where: 'reference_type = ? AND reference_id = ?',
        whereArgs: ['sale', sale.id],
        limit: 1,
      );
      if (movement.isEmpty) {
        await _insertMovement(
          txn,
          newProduct.id!,
          -normalized.quantityBase,
          sale.id!,
          normalized.saleDate,
          normalized.createdAt,
        );
      } else {
        await txn.update(
          'stock_movements',
          {
            'product_id': newProduct.id,
            'quantity_change': -normalized.quantityBase,
            'movement_date': normalized.saleDate.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [movement.first['id']],
        );
      }
      return normalized.copyWithId(sale.id!);
    });
  }

  Future<void> deleteSale(int id) async {
    final db = await database.database;
    await db.transaction((txn) => _deleteSale(txn, id));
  }

  Future<void> deleteSales(Iterable<int> ids) async {
    final db = await database.database;
    await db.transaction((txn) async {
      for (final id in ids) {
        await _deleteSale(txn, id);
      }
    });
  }

  Future<void> _deleteSale(Transaction txn, int id) async {
    final sale = await _sale(txn, id);
    final product = await _product(txn, sale.productId);
    await _changeStock(txn, product.id!, sale.quantityBase);
    await txn.delete('sales', where: 'id = ?', whereArgs: [id]);
    await txn.delete(
      'stock_movements',
      where: 'reference_type = ? AND reference_id = ?',
      whereArgs: ['sale', id],
    );
  }

  Future<Product> _product(Transaction txn, int id) async {
    final rows = await txn.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw const SaleValidationException('محصول پیدا نشد');
    return Product.fromMap(rows.first);
  }

  Future<Sale> _sale(Transaction txn, int id) async {
    final rows = await txn.query(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw const SaleValidationException('فروش پیدا نشد');
    return Sale.fromMap(rows.first);
  }

  Sale _normalize(Sale sale, Product product) {
    if (sale.currency != Currency.afn && sale.currency != Currency.usd) {
      throw const SaleValidationException('ارز فروش الزامی است');
    }
    final quantityBase = calculateSaleQuantityBase(
      product,
      sale.quantity,
      sale.unit,
    );
    return Sale(
      productId: product.id!,
      quantity: sale.quantity,
      unit: sale.unit,
      quantityBase: quantityBase,
      unitPrice: sale.unitPrice,
      currency: sale.currency,
      totalAmount: calculateSaleTotalAmount(sale.quantity, sale.unitPrice),
      saleDate: sale.saleDate,
      note: sale.note,
      createdAt: sale.createdAt,
      updatedAt: sale.updatedAt,
      id: sale.id,
    );
  }

  Future<void> _changeStock(Transaction txn, int productId, num change) async {
    final rows = await txn.query(
      'products',
      columns: ['current_stock_base'],
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (rows.isEmpty) throw const SaleValidationException('محصول پیدا نشد');
    final current = rows.first['current_stock_base'] as num;
    if (current + change < 0) {
      throw const SaleValidationException('موجودی کافی نیست');
    }
    await txn.update(
      'products',
      {
        'current_stock_base': current + change,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<void> _insertMovement(
    Transaction txn,
    int productId,
    num quantity,
    int saleId,
    DateTime date,
    DateTime createdAt,
  ) => txn.insert('stock_movements', {
    'product_id': productId,
    'type': 'sale',
    'quantity_change': quantity,
    'reference_type': 'sale',
    'reference_id': saleId,
    'movement_date': date.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  });
}

class SaleCursor {
  const SaleCursor({required this.saleDate, required this.id});
  final String saleDate;
  final int id;
}

class SaleListItem {
  const SaleListItem({required this.sale, required this.productName});
  final Sale sale;
  final String productName;

  factory SaleListItem.fromMap(Map<String, Object?> map) => SaleListItem(
    sale: Sale.fromMap(map),
    productName: map['product_name'] as String,
  );
}

extension on Sale {
  Sale copyWithId(int id) => Sale(
    id: id,
    productId: productId,
    quantity: quantity,
    unit: unit,
    quantityBase: quantityBase,
    unitPrice: unitPrice,
    currency: currency,
    totalAmount: totalAmount,
    saleDate: saleDate,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
