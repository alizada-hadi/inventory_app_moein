import '../../../core/database/app_database.dart';
import '../../../core/data/page_result.dart';
import 'product.dart';

class ProductRepository {
  ProductRepository({AppDatabase? database})
    : database = database ?? AppDatabase.instance;
  final AppDatabase database;

  Future<int> createProduct(Product product) async {
    validateProduct(product);
    final db = await database.database;
    return db.insert('products', product.toMap()..remove('id'));
  }

  Future<int> updateProduct(Product product) async {
    if (product.id == null) throw ArgumentError('Product id is required');
    validateProduct(product);
    final db = await database.database;
    final updated = await db.update(
      'products',
      product.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [product.id],
    );
    if (updated == 0) {
      throw const ProductValidationException('محصول پیدا نشد');
    }
    return updated;
  }

  Future<int> deleteProduct(int id) async {
    final product = await getProductById(id);
    if (product == null) return 0;
    if (product.currentStockBase != 0) {
      throw const ProductValidationException(
        'محصول دارای موجودی است و حذف نمی‌شود',
      );
    }
    final db = await database.database;
    return db.transaction((txn) async {
      final references = <String, String>{
        'purchases': 'خرید',
        'sales': 'فروش',
        'product_price_history': 'تاریخچه قیمت',
      };
      for (final entry in references.entries) {
        final rows = await txn.query(
          entry.key,
          columns: ['id'],
          where: 'product_id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          throw ProductValidationException(
            'این محصول دارای سابقه ${entry.value} است و حذف نمی‌شود',
          );
        }
      }
      return txn.delete('products', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteProducts(Iterable<int> ids) async {
    final db = await database.database;
    await db.transaction((txn) async {
      for (final id in ids) {
        final rows = await txn.query(
          'products',
          columns: ['current_stock_base'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (rows.isEmpty) continue;
        if ((rows.first['current_stock_base'] as num) != 0) {
          throw const ProductValidationException(
            'محصول دارای موجودی است و حذف نمی‌شود',
          );
        }
        for (final table in ['purchases', 'sales', 'product_price_history']) {
          final references = await txn.query(
            table,
            columns: ['id'],
            where: 'product_id = ?',
            whereArgs: [id],
            limit: 1,
          );
          if (references.isNotEmpty) {
            throw const ProductValidationException(
              'یکی از محصولات انتخاب‌شده دارای سابقه است و حذف نمی‌شود',
            );
          }
        }
        await txn.delete('products', where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  Future<Product?> getProductById(int id) async {
    final rows = await (await database.database).query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  Future<PageResult<Product, ProductCursor>> getProductsPage({
    ProductCursor? cursor,
    String query = '',
    int limit = 50,
  }) async {
    final db = await database.database;
    final trimmed = query.trim();
    final clauses = <String>[];
    final args = <Object?>[];
    if (trimmed.isNotEmpty) {
      clauses.add('(name LIKE ? OR barcode LIKE ?)');
      args.addAll(['%$trimmed%', '%$trimmed%']);
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
        'barcode',
        'unit',
        'amount',
        'restock_level',
        'supports_carton',
        'supports_package',
        'supports_pocket',
        'items_per_package',
        'items_per_pocket',
        'packages_per_carton',
        'items_per_carton_direct',
        'current_stock_base',
        'carton_sale_price',
        'package_sale_price',
        'pocket_sale_price',
        'item_sale_price',
        'cost_price',
        'sale_price',
        'price_currency',
        'created_at',
        'updated_at',
      ],
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'updated_at DESC, id DESC',
      limit: limit + 1,
    );
    final pageRows = rows.take(limit).toList();
    final items = pageRows.map(Product.fromMap).toList(growable: false);
    final next = rows.length > limit && items.isNotEmpty
        ? ProductCursor(
            updatedAt: pageRows.last['updated_at'] as String,
            id: pageRows.last['id'] as int,
          )
        : null;
    return PageResult(items: items, nextCursor: next);
  }
}

class ProductCursor {
  const ProductCursor({required this.updatedAt, required this.id});
  final String updatedAt;
  final int id;
}
