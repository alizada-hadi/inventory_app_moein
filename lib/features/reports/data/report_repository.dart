import '../../../core/constants/app_constants.dart';
import '../../../core/data/page_result.dart';
import '../../../core/database/app_database.dart';
import '../../sales/data/sale.dart';
import '../../purchases/data/purchase.dart';
import 'report_filters.dart';

class ReportRepository {
  ReportRepository({AppDatabase? database})
    : database = database ?? AppDatabase.instance;
  final AppDatabase database;

  Future<PageResult<SaleReportRow, TransactionCursor>> getSalesPage(
    TransactionFilter filter, {
    TransactionCursor? cursor,
    int limit = 50,
  }) async {
    final db = await database.database;
    final built = _transactionWhere('s', filter, cursor, 'sale_date');
    final rows = await db.rawQuery('''
      SELECT s.id, s.product_id, s.quantity, s.unit, s.quantity_base,
             s.unit_price, s.currency, s.total_amount, s.sale_date, s.note,
             s.created_at, s.updated_at, p.name AS product_name
      FROM sales s JOIN products p ON p.id = s.product_id
      WHERE ${built.sql} ORDER BY s.sale_date DESC, s.id DESC LIMIT ${limit + 1}
    ''', built.args);
    final page = rows.take(limit).toList();
    return PageResult(
      items: page
          .map(
            (row) =>
                SaleReportRow(Sale.fromMap(row), row['product_name'] as String),
          )
          .toList(growable: false),
      nextCursor: rows.length > limit && page.isNotEmpty
          ? TransactionCursor(
              date: page.last['sale_date'] as String,
              id: page.last['id'] as int,
            )
          : null,
    );
  }

  Future<PageResult<PurchaseReportRow, TransactionCursor>> getPurchasesPage(
    TransactionFilter filter, {
    TransactionCursor? cursor,
    int limit = 50,
  }) async {
    final db = await database.database;
    final built = _transactionWhere('p', filter, cursor, 'purchase_date');
    final rows = await db.rawQuery('''
      SELECT p.id, p.product_id, p.quantity, p.unit, p.quantity_base,
             p.unit_cost, p.currency, p.total_cost, p.purchase_date, p.note,
             p.created_at, p.updated_at, x.name AS product_name
      FROM purchases p JOIN products x ON x.id = p.product_id
      WHERE ${built.sql} ORDER BY p.purchase_date DESC, p.id DESC LIMIT ${limit + 1}
    ''', built.args);
    final page = rows.take(limit).toList();
    return PageResult(
      items: page
          .map(
            (row) => PurchaseReportRow(
              Purchase.fromMap(row),
              row['product_name'] as String,
            ),
          )
          .toList(growable: false),
      nextCursor: rows.length > limit && page.isNotEmpty
          ? TransactionCursor(
              date: page.last['purchase_date'] as String,
              id: page.last['id'] as int,
            )
          : null,
    );
  }

  Future<TransactionSummary> getSalesSummary(TransactionFilter filter) =>
      _summary('sales', 'sale_date', 'total_amount', filter);
  Future<TransactionSummary> getPurchasesSummary(TransactionFilter filter) =>
      _summary('purchases', 'purchase_date', 'total_cost', filter);

  Future<TransactionSummary> _summary(
    String table,
    String dateColumn,
    String amountColumn,
    TransactionFilter filter,
  ) async {
    final db = await database.database;
    final built = _transactionWhere('', filter, null, dateColumn);
    final row = (await db.rawQuery('''
      SELECT COUNT(*) AS total_count,
        COALESCE(SUM(CASE WHEN currency = 'afn' THEN $amountColumn ELSE 0 END), 0) AS afn_total,
        COALESCE(SUM(CASE WHEN currency = 'usd' THEN $amountColumn ELSE 0 END), 0) AS usd_total
      FROM $table WHERE ${built.sql}
    ''', built.args)).single;
    return TransactionSummary(
      count: row['total_count'] as int,
      afnTotal: row['afn_total'] as num,
      usdTotal: row['usd_total'] as num,
    );
  }

  Future<PageResult<InventoryReportRow, ProductInventoryCursor>>
  getInventoryPage(
    InventoryFilter filter, {
    ProductInventoryCursor? cursor,
    int limit = 50,
  }) async {
    final db = await database.database;
    final clauses = <String>[];
    final args = <Object?>[];
    if (filter.search.trim().isNotEmpty) {
      clauses.add('(name LIKE ? OR barcode LIKE ?)');
      args.addAll(['%${filter.search.trim()}%', '%${filter.search.trim()}%']);
    }
    switch (filter.status) {
      case StockStatus.all:
        break;
      case StockStatus.low:
        clauses.add(
          'current_stock_base > 0 AND current_stock_base <= restock_level',
        );
      case StockStatus.outOfStock:
        clauses.add('current_stock_base = 0');
      case StockStatus.inStock:
        clauses.add('current_stock_base > 0');
    }
    if (cursor != null) {
      clauses.add('(updated_at < ? OR (updated_at = ? AND id < ?))');
      args.addAll([cursor.updatedAt, cursor.updatedAt, cursor.id]);
    }
    final rows = await db.query(
      'products',
      columns: const [
        'id',
        'name',
        'unit',
        'current_stock_base',
        'restock_level',
        'sale_price',
        'carton_sale_price',
        'package_sale_price',
        'pocket_sale_price',
        'item_sale_price',
        'price_currency',
        'updated_at',
      ],
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'updated_at DESC, id DESC',
      limit: limit + 1,
    );
    final page = rows.take(limit).toList();
    return PageResult(
      items: page.map(InventoryReportRow.fromMap).toList(growable: false),
      nextCursor: rows.length > limit && page.isNotEmpty
          ? ProductInventoryCursor(
              updatedAt: page.last['updated_at'] as String,
              id: page.last['id'] as int,
            )
          : null,
    );
  }

  _Where _transactionWhere(
    String alias,
    TransactionFilter filter,
    TransactionCursor? cursor,
    String dateColumn,
  ) {
    final prefix = alias.isEmpty ? '' : '$alias.';
    final clauses = ['${prefix}$dateColumn >= ?', '${prefix}$dateColumn < ?'];
    final args = <Object?>[
      filter.dateRange.startDate.toIso8601String(),
      filter.dateRange.endDate.toIso8601String(),
    ];
    if (filter.productId != null) {
      clauses.add('${prefix}product_id = ?');
      args.add(filter.productId);
    }
    if (filter.currency != null) {
      clauses.add('${prefix}currency = ?');
      args.add(filter.currency!.name);
    }
    if (cursor != null) {
      clauses.add(
        '(${prefix}$dateColumn < ? OR (${prefix}$dateColumn = ? AND ${prefix}id < ?))',
      );
      args.addAll([cursor.date, cursor.date, cursor.id]);
    }
    return _Where(clauses.join(' AND '), args);
  }
}

class _Where {
  const _Where(this.sql, this.args);
  final String sql;
  final List<Object?> args;
}

class TransactionCursor {
  const TransactionCursor({required this.date, required this.id});
  final String date;
  final int id;
}

class ProductInventoryCursor {
  const ProductInventoryCursor({required this.updatedAt, required this.id});
  final String updatedAt;
  final int id;
}

class SaleReportRow {
  const SaleReportRow(this.sale, this.productName);
  final Sale sale;
  final String productName;
}

class PurchaseReportRow {
  const PurchaseReportRow(this.purchase, this.productName);
  final Purchase purchase;
  final String productName;
}

class TransactionSummary {
  const TransactionSummary({
    required this.count,
    required this.afnTotal,
    required this.usdTotal,
  });
  final int count;
  final num afnTotal, usdTotal;
}

class InventoryReportRow {
  const InventoryReportRow({
    required this.id,
    required this.name,
    required this.unit,
    required this.stock,
    required this.threshold,
    required this.salePrice,
    required this.currency,
  });
  final int id;
  final num stock, threshold;
  final String name, unit;
  final num? salePrice;
  final Currency currency;
  bool get lowStock => stock > 0 && stock <= threshold;
  factory InventoryReportRow.fromMap(Map<String, Object?> row) {
    final unit = InventoryUnit.values.byName(row['unit'] as String);
    final price =
        (row['sale_price'] as num?) ??
        switch (unit) {
          InventoryUnit.carton => row['carton_sale_price'] as num?,
          InventoryUnit.package => row['package_sale_price'] as num?,
          InventoryUnit.pocket => row['pocket_sale_price'] as num?,
          InventoryUnit.item => row['item_sale_price'] as num?,
        };
    return InventoryReportRow(
      id: row['id'] as int,
      name: row['name'] as String,
      unit: unit.label,
      stock: row['current_stock_base'] as num,
      threshold: row['restock_level'] as num,
      salePrice: price,
      currency: Currency.values.byName(row['price_currency'] as String),
    );
  }
}
