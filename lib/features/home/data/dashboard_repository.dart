import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';

class DashboardRepository {
  DashboardRepository({AppDatabase? database})
    : database = database ?? AppDatabase.instance;
  final AppDatabase database;

  Future<List<LowStockItem>> getLowStockItems() async {
    final db = await database.database;
    final rows = await db.rawQuery('''
      SELECT id, name, current_stock_base, unit
      FROM products
      WHERE restock_level IS NOT NULL
        AND current_stock_base > 0
        AND current_stock_base <= restock_level
      ORDER BY current_stock_base ASC, name COLLATE NOCASE ASC
    ''');
    return rows.map(LowStockItem.fromMap).toList(growable: false);
  }

  Future<DashboardSummary> getSummary() async {
    final db = await database.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day + 1).toIso8601String();
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM products'),
        ) ??
        0;
    final purchaseTotals = await db.rawQuery(
      '''SELECT COUNT(*) AS count,
             COALESCE(SUM(CASE WHEN currency = 'afn' THEN total_cost ELSE 0 END), 0) AS afn,
             COALESCE(SUM(CASE WHEN currency = 'usd' THEN total_cost ELSE 0 END), 0) AS usd
             FROM purchases WHERE purchase_date >= ? AND purchase_date < ?''',
      [start, end],
    );
    final saleTotals = await db.rawQuery(
      '''SELECT COUNT(*) AS count,
             COALESCE(SUM(CASE WHEN currency = 'afn' THEN total_amount ELSE 0 END), 0) AS afn,
             COALESCE(SUM(CASE WHEN currency = 'usd' THEN total_amount ELSE 0 END), 0) AS usd
             FROM sales WHERE sale_date >= ? AND sale_date < ?''',
      [start, end],
    );
    final purchases = Sqflite.firstIntValue(purchaseTotals) ?? 0;
    final sales = Sqflite.firstIntValue(saleTotals) ?? 0;
    final lowStockCount =
        Sqflite.firstIntValue(
          await db.rawQuery('''
            SELECT COUNT(*) FROM products
            WHERE restock_level IS NOT NULL
              AND current_stock_base > 0
              AND current_stock_base <= restock_level
          '''),
        ) ??
        0;
    final lowRows = await getLowStockItems();
    final activityRows = await db.rawQuery('''
      SELECT sm.type, sm.quantity_change, sm.movement_date, p.name AS product_name
      FROM stock_movements sm JOIN products p ON p.id = sm.product_id
      ORDER BY sm.movement_date DESC, sm.id DESC
      LIMIT 10
    ''');
    final financialRows = await db.query(
      'financial_reports',
      orderBy: 'report_date DESC, id DESC',
      limit: 1,
    );
    final latestFinancial = financialRows.isEmpty ? null : financialRows.first;
    final previousFinancial = latestFinancial == null
        ? <Map<String, Object?>>[]
        : await db.query(
            'financial_reports',
            where: 'report_date < ?',
            whereArgs: [latestFinancial['report_date']],
            orderBy: 'report_date DESC, id DESC',
            limit: 1,
          );
    return DashboardSummary(
      productCount: count,
      purchasesToday: purchases,
      salesToday: sales,
      purchasesTodayAfn: purchaseTotals.first['afn'] as num,
      purchasesTodayUsd: purchaseTotals.first['usd'] as num,
      salesTodayAfn: saleTotals.first['afn'] as num,
      salesTodayUsd: saleTotals.first['usd'] as num,
      lowStockCount: lowStockCount,
      lowStock: lowRows.take(5).toList(growable: false),
      activities: activityRows
          .map(ActivityItem.fromMap)
          .toList(growable: false),
      latestFinancialNet: latestFinancial?['net_position'] as int?,
      latestFinancialChange:
          latestFinancial == null || previousFinancial.isEmpty
          ? null
          : (latestFinancial['net_position'] as int) -
                (previousFinancial.first['net_position'] as int),
      latestFinancialDate: latestFinancial == null
          ? null
          : DateTime.parse(latestFinancial['report_date'] as String),
      latestFinancialCurrency: latestFinancial == null
          ? null
          : Currency.values.byName(latestFinancial['currency'] as String),
    );
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.productCount,
    required this.purchasesToday,
    required this.salesToday,
    required this.purchasesTodayAfn,
    required this.purchasesTodayUsd,
    required this.salesTodayAfn,
    required this.salesTodayUsd,
    required this.lowStockCount,
    required this.lowStock,
    required this.activities,
    this.latestFinancialNet,
    this.latestFinancialChange,
    this.latestFinancialDate,
    this.latestFinancialCurrency,
  });
  final int productCount, purchasesToday, salesToday;
  final num purchasesTodayAfn, purchasesTodayUsd, salesTodayAfn, salesTodayUsd;
  final int lowStockCount;
  final List<LowStockItem> lowStock;
  final List<ActivityItem> activities;
  final int? latestFinancialNet, latestFinancialChange;
  final DateTime? latestFinancialDate;
  final Currency? latestFinancialCurrency;
}

class LowStockItem {
  const LowStockItem({
    required this.productId,
    required this.name,
    required this.amount,
    required this.unit,
  });
  final int productId;
  final String name;
  final InventoryUnit unit;
  final num amount;
  factory LowStockItem.fromMap(Map<String, Object?> map) => LowStockItem(
    productId: map['id'] as int,
    name: map['name'] as String,
    amount: map['current_stock_base'] as num,
    unit: InventoryUnit.values.byName(map['unit'] as String),
  );
}

class ActivityItem {
  const ActivityItem({
    required this.type,
    required this.amount,
    required this.date,
    required this.productName,
  });
  final String type, date, productName;
  final num amount;
  factory ActivityItem.fromMap(Map<String, Object?> map) => ActivityItem(
    type: map['type'] as String,
    amount: (map['quantity_change'] as num).abs(),
    date: map['movement_date'] as String,
    productName: map['product_name'] as String,
  );
}
