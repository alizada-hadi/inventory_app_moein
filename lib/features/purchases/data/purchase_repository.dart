import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/data/page_result.dart';
import '../../products/data/product.dart';
import 'purchase.dart';

class PurchaseRepository {
  PurchaseRepository({AppDatabase? database})
    : database = database ?? AppDatabase.instance;
  final AppDatabase database;

  Future<Purchase> createPurchase(Purchase purchase) async {
    final db = await database.database;
    return db.transaction((txn) async {
      final product = await _product(txn, purchase.productId);
      final normalized = _normalize(purchase, product);
      final id = await txn.insert(
        'purchases',
        normalized.toMap()..remove('id'),
      );
      await _changeStock(txn, product.id!, normalized.quantityBase);
      await _insertMovement(
        txn,
        product.id!,
        normalized.quantityBase,
        id,
        normalized.purchaseDate,
        normalized.createdAt,
      );
      return normalized.copyWithId(id);
    });
  }

  Future<Purchase?> getPurchaseById(int id) async {
    final rows = await (await database.database).query(
      'purchases',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Purchase.fromMap(rows.first);
  }

  Future<List<Purchase>> getAllPurchases() async {
    final rows = await (await database.database).query(
      'purchases',
      orderBy: 'purchase_date DESC, id DESC',
    );
    return rows.map(Purchase.fromMap).toList();
  }

  Future<PageResult<PurchaseListItem, PurchaseCursor>> getPurchasesPage({
    PurchaseCursor? cursor,
    int limit = 50,
  }) async {
    final args = <Object?>[];
    var where = '';
    if (cursor != null) {
      where = 'WHERE p.purchase_date < ? OR (p.purchase_date = ? AND p.id < ?)';
      args.addAll([cursor.purchaseDate, cursor.purchaseDate, cursor.id]);
    }
    final rows = await (await database.database).rawQuery('''
      SELECT p.id, p.product_id, p.quantity, p.unit, p.quantity_base,
             p.unit_cost, p.currency, p.total_cost, p.purchase_date, p.note,
             p.created_at, p.updated_at, x.name AS product_name
      FROM purchases p JOIN products x ON x.id = p.product_id
      $where
      ORDER BY p.purchase_date DESC, p.id DESC
      LIMIT ${limit + 1}
    ''', args);
    final pageRows = rows.take(limit).toList();
    final items = pageRows
        .map(PurchaseListItem.fromMap)
        .toList(growable: false);
    final next = rows.length > limit && items.isNotEmpty
        ? PurchaseCursor(
            purchaseDate: pageRows.last['purchase_date'] as String,
            id: pageRows.last['id'] as int,
          )
        : null;
    return PageResult(items: items, nextCursor: next);
  }

  Future<List<Purchase>> getPurchasesByProduct(
    int productId, {
    int? limit,
  }) async {
    final rows = await (await database.database).query(
      'purchases',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'purchase_date DESC, id DESC',
      limit: limit,
    );
    return rows.map(Purchase.fromMap).toList();
  }

  Future<List<Purchase>> getPurchasesByDateRange(
    DateTime from,
    DateTime to,
  ) async {
    final rows = await (await database.database).query(
      'purchases',
      where: 'purchase_date >= ? AND purchase_date <= ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'purchase_date DESC, id DESC',
    );
    return rows.map(Purchase.fromMap).toList();
  }

  Future<Purchase> updatePurchase(Purchase purchase) async {
    if (purchase.id == null) throw ArgumentError('Purchase id is required');
    final db = await database.database;
    return db.transaction((txn) async {
      final old = await _purchase(txn, purchase.id!);
      final oldProduct = await _product(txn, old.productId);
      final newProduct = await _product(txn, purchase.productId);
      final normalized = _normalize(purchase, newProduct);
      await _changeStock(txn, oldProduct.id!, -old.quantityBase);
      await _changeStock(txn, newProduct.id!, normalized.quantityBase);
      await txn.update(
        'purchases',
        normalized.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [purchase.id],
      );
      final movement = await txn.query(
        'stock_movements',
        where: 'reference_type = ? AND reference_id = ?',
        whereArgs: ['purchase', purchase.id],
        limit: 1,
      );
      if (movement.isEmpty) {
        await _insertMovement(
          txn,
          newProduct.id!,
          normalized.quantityBase,
          purchase.id!,
          normalized.purchaseDate,
          normalized.createdAt,
        );
      } else {
        await txn.update(
          'stock_movements',
          {
            'product_id': newProduct.id,
            'quantity_change': normalized.quantityBase,
            'movement_date': normalized.purchaseDate.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [movement.first['id']],
        );
      }
      return normalized.copyWithId(purchase.id!);
    });
  }

  Future<void> deletePurchase(int id) async {
    final db = await database.database;
    await db.transaction((txn) => _deletePurchase(txn, id));
  }

  Future<void> deletePurchases(Iterable<int> ids) async {
    final db = await database.database;
    await db.transaction((txn) async {
      for (final id in ids) {
        await _deletePurchase(txn, id);
      }
    });
  }

  Future<void> _deletePurchase(Transaction txn, int id) async {
    final purchase = await _purchase(txn, id);
    final product = await _product(txn, purchase.productId);
    await _changeStock(txn, product.id!, -purchase.quantityBase);
    await txn.delete('purchases', where: 'id = ?', whereArgs: [id]);
    await txn.delete(
      'stock_movements',
      where: 'reference_type = ? AND reference_id = ?',
      whereArgs: ['purchase', id],
    );
  }

  Future<Product> _product(Transaction txn, int id) async {
    final rows = await txn.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw const PurchaseValidationException('محصول پیدا نشد');
    return Product.fromMap(rows.first);
  }

  Future<Purchase> _purchase(Transaction txn, int id) async {
    final rows = await txn.query(
      'purchases',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw const PurchaseValidationException('خرید پیدا نشد');
    return Purchase.fromMap(rows.first);
  }

  Purchase _normalize(Purchase purchase, Product product) {
    if (purchase.quantity <= 0) {
      throw const PurchaseValidationException('مقدار باید بیشتر از صفر باشد');
    }
    if (purchase.unitCost < 0) {
      throw const PurchaseValidationException('قیمت خرید معتبر نیست');
    }
    if (purchase.currency != Currency.afn &&
        purchase.currency != Currency.usd) {
      throw const PurchaseValidationException('ارز خرید الزامی است');
    }
    final quantityBase = calculatePurchaseQuantityBase(
      product,
      purchase.quantity,
      purchase.unit,
    );
    return Purchase(
      productId: product.id!,
      quantity: purchase.quantity,
      unit: purchase.unit,
      quantityBase: quantityBase,
      unitCost: purchase.unitCost,
      currency: purchase.currency,
      totalCost: calculatePurchaseTotalCost(
        purchase.quantity,
        purchase.unitCost,
      ),
      purchaseDate: purchase.purchaseDate,
      note: purchase.note,
      createdAt: purchase.createdAt,
      updatedAt: purchase.updatedAt,
      id: purchase.id,
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
    if (rows.isEmpty) throw const PurchaseValidationException('محصول پیدا نشد');
    final current = rows.first['current_stock_base'] as num;
    if (!canApplyStockChange(current, change)) {
      throw const PurchaseValidationException(
        'این تغییر باعث منفی شدن موجودی می‌شود',
      );
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
    int purchaseId,
    DateTime date,
    DateTime createdAt,
  ) => txn.insert('stock_movements', {
    'product_id': productId,
    'type': 'purchase',
    'quantity_change': quantity,
    'reference_type': 'purchase',
    'reference_id': purchaseId,
    'movement_date': date.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  });
}

class PurchaseCursor {
  const PurchaseCursor({required this.purchaseDate, required this.id});
  final String purchaseDate;
  final int id;
}

class PurchaseListItem {
  const PurchaseListItem({required this.purchase, required this.productName});
  final Purchase purchase;
  final String productName;

  factory PurchaseListItem.fromMap(Map<String, Object?> map) =>
      PurchaseListItem(
        purchase: Purchase.fromMap(map),
        productName: map['product_name'] as String,
      );
}

extension on Purchase {
  Purchase copyWithId(int id) => Purchase(
    id: id,
    productId: productId,
    quantity: quantity,
    unit: unit,
    quantityBase: quantityBase,
    unitCost: unitCost,
    currency: currency,
    totalCost: totalCost,
    purchaseDate: purchaseDate,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
