import 'app_database.dart';

class ProductStockIntegrityIssue {
  const ProductStockIntegrityIssue({
    required this.productId,
    required this.storedStock,
    required this.expectedStock,
  });

  final int productId;
  final num storedStock;
  final num expectedStock;
}

/// Development/diagnostic checker. It is intentionally not exposed in the UI.
class DatabaseIntegrityChecker {
  DatabaseIntegrityChecker({AppDatabase? database})
    : database = database ?? AppDatabase.instance;

  final AppDatabase database;

  Future<List<ProductStockIntegrityIssue>> findStockIssues() async {
    final db = await database.database;
    final products = await db.query(
      'products',
      columns: ['id', 'current_stock_base'],
    );
    final issues = <ProductStockIntegrityIssue>[];
    for (final product in products) {
      final id = product['id'] as int;
      final purchaseRows = await db.rawQuery(
        'SELECT COALESCE(SUM(quantity_base), 0) AS total FROM purchases WHERE product_id = ?',
        [id],
      );
      final saleRows = await db.rawQuery(
        'SELECT COALESCE(SUM(quantity_base), 0) AS total FROM sales WHERE product_id = ?',
        [id],
      );
      final purchases = purchaseRows.first['total'] as num;
      final sales = saleRows.first['total'] as num;
      final expected = purchases - sales;
      final stored = product['current_stock_base'] as num;
      if (expected != stored) {
        issues.add(
          ProductStockIntegrityIssue(
            productId: id,
            storedStock: stored,
            expectedStock: expected,
          ),
        );
      }
    }
    return issues;
  }
}
