import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import 'product.dart';
import 'product_conversion.dart';
import 'product_price_history.dart';

class PriceUpdateRequest {
  const PriceUpdateRequest({
    this.cartonPrice,
    this.packagePrice,
    this.itemPrice,
    required this.currency,
    required this.effectiveDate,
  });
  // Dynamic keeps this request source-compatible with older callers that use
  // int prices while allowing decimal values from the form.
  final dynamic cartonPrice;
  final dynamic packagePrice;
  final dynamic itemPrice;
  final Currency currency;
  final DateTime effectiveDate;
}

class ProductPriceRepository {
  ProductPriceRepository({AppDatabase? database})
    : database = database ?? AppDatabase.instance;
  final AppDatabase database;

  Future<List<ProductPriceHistory>> getHistory(
    int productId, {
    int? limit,
  }) async {
    final rows = await (await database.database).query(
      'product_price_history',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'effective_date DESC, id DESC',
      limit: limit,
    );
    return rows.map(ProductPriceHistory.fromMap).toList();
  }

  Future<List<ProductPriceHistory>> updatePrices(
    int productId,
    PriceUpdateRequest request,
  ) async {
    final db = await database.database;
    return db.transaction((txn) async {
      final product = await _getProduct(txn, productId);
      _validateRequest(product, request);
      final currencyChanged = product.priceCurrency != request.currency;
      final values = <StockUnit, num?>{
        StockUnit.carton: product.cartonSalePrice,
        StockUnit.package: product.packageSalePrice,
        StockUnit.pocket: product.pocketSalePrice,
        StockUnit.item: product.itemSalePrice,
      };
      values[StockUnit.carton] =
          request.cartonPrice ?? values[StockUnit.carton];
      values[StockUnit.package] =
          request.packagePrice ?? values[StockUnit.package];
      values[StockUnit.item] = request.itemPrice ?? values[StockUnit.item];
      final supported = _supportedUnits(product);
      final changed = <StockUnit>[];
      for (final unit in supported) {
        final oldPrice = _price(product, unit);
        final newPrice = values[unit];
        if (newPrice == null && (currencyChanged || oldPrice != null)) {
          throw const ProductValidationException(
            'برای واحدهای پشتیبانی‌شده قیمت را وارد کنید',
          );
        }
        if (newPrice != oldPrice || currencyChanged) changed.add(unit);
      }
      if (changed.isEmpty) {
        throw const ProductValidationException('حداقل یک قیمت را تغییر دهید');
      }
      final map = product.toMap();
      map['carton_sale_price'] = values[StockUnit.carton];
      map['package_sale_price'] = values[StockUnit.package];
      map['pocket_sale_price'] = values[StockUnit.pocket];
      map['item_sale_price'] = values[StockUnit.item];
      map['sale_price'] = switch (product.unit) {
        InventoryUnit.carton => values[StockUnit.carton],
        InventoryUnit.package => values[StockUnit.package],
        InventoryUnit.pocket => values[StockUnit.pocket],
        InventoryUnit.item => values[StockUnit.item],
      };
      map['price_currency'] = request.currency.name;
      map['updated_at'] = DateTime.now().toIso8601String();
      await txn.update(
        'products',
        map..remove('id'),
        where: 'id = ?',
        whereArgs: [productId],
      );
      final createdAt = DateTime.now();
      final history = <ProductPriceHistory>[];
      for (final unit in changed) {
        final entry = ProductPriceHistory(
          id: null,
          productId: productId,
          unit: unit,
          oldPrice: _price(product, unit),
          newPrice: values[unit]!,
          currency: request.currency,
          effectiveDate: request.effectiveDate,
          createdAt: createdAt,
        );
        final id = await txn.insert(
          'product_price_history',
          entry.toMap()..remove('id'),
        );
        history.add(
          ProductPriceHistory(
            id: id,
            productId: entry.productId,
            unit: entry.unit,
            oldPrice: entry.oldPrice,
            newPrice: entry.newPrice,
            currency: entry.currency,
            effectiveDate: entry.effectiveDate,
            createdAt: entry.createdAt,
          ),
        );
      }
      return history;
    });
  }

  Future<Product> _getProduct(Transaction txn, int id) async {
    final rows = await txn.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw const ProductValidationException('محصول پیدا نشد');
    return Product.fromMap(rows.first);
  }

  void _validateRequest(Product product, PriceUpdateRequest request) {
    if (request.cartonPrice != null && !product.supportsCarton ||
        request.packagePrice != null && !product.supportsPackage) {
      throw const ProductValidationException(
        'واحد انتخاب‌شده برای این محصول پشتیبانی نمی‌شود',
      );
    }
    for (final price in [
      request.cartonPrice,
      request.packagePrice,
      request.itemPrice,
    ]) {
      if (price != null && price < 0) {
        throw const ProductValidationException('قیمت نمی‌تواند منفی باشد');
      }
    }
  }

  List<StockUnit> _supportedUnits(Product product) => [
    if (product.supportsCarton) StockUnit.carton,
    if (product.supportsPackage) StockUnit.package,
    if (product.supportsPocket) StockUnit.pocket,
    StockUnit.item,
  ];

  num? _price(Product product, StockUnit unit) => switch (unit) {
    StockUnit.carton => product.cartonSalePrice,
    StockUnit.package => product.packageSalePrice,
    StockUnit.pocket => product.pocketSalePrice,
    StockUnit.item => product.itemSalePrice,
  };
}
