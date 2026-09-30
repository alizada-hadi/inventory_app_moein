import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/core/constants/app_constants.dart';
import 'package:inventory_app/features/products/data/product.dart';
import 'package:inventory_app/features/products/data/product_conversion.dart';

Product boxed({bool carton = true, bool package = true, int? directItems}) =>
    Product(
      id: null,
      name: 'صابون',
      supportsCarton: carton,
      supportsPackage: package,
      itemsPerPackage: package ? 6 : null,
      packagesPerCarton: carton && package ? 20 : null,
      itemsPerCartonDirect: carton && !package ? directItems : null,
      priceCurrency: Currency.afn,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  test(
    '۳ کارتن برابر ۳۶۰ عدد است',
    () => expect(
      ProductConversion.convertToBase(boxed(), 3, StockUnit.carton),
      360,
    ),
  );
  test(
    '۵ بسته برابر ۳۰ عدد است',
    () => expect(
      ProductConversion.convertToBase(boxed(), 5, StockUnit.package),
      30,
    ),
  );
  test(
    '۷ عدد برابر ۷ عدد است',
    () =>
        expect(ProductConversion.convertToBase(boxed(), 7, StockUnit.item), 7),
  );
  test('۲۶۷ عدد به ۲ کارتن، ۴ بسته و ۳ عدد تبدیل می‌شود', () {
    final result = ProductConversion.breakdown(boxed(), 267);
    expect(result.cartons, 2);
    expect(result.packages, 4);
    expect(result.items, 3);
  });
  test('کارتن مستقیم بدون بسته پشتیبانی می‌شود', () {
    final product = boxed(package: false, directItems: 24);
    expect(ProductConversion.convertToBase(product, 3, StockUnit.carton), 72);
    final result = ProductConversion.breakdown(product, 50);
    expect(result.cartons, 2);
    expect(result.packages, 0);
    expect(result.items, 2);
  });

  test('بسته بدون کارتن به واحد پایه تبدیل می‌شود', () {
    final product = Product(
      id: 1,
      name: 'محصول',
      supportsCarton: false,
      supportsPackage: true,
      itemsPerPackage: 10,
      currentStockBase: 0,
      priceCurrency: Currency.afn,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(ProductConversion.convertToBase(product, 3, StockUnit.package), 30);
    expect(ProductConversion.breakdown(product, 35).packages, 3);
    expect(ProductConversion.breakdown(product, 35).items, 5);
  });

  test('محصول عددی فقط به واحد عدد نمایش داده می‌شود', () {
    final product = Product(
      id: 1,
      name: 'محصول',
      supportsCarton: false,
      supportsPackage: false,
      currentStockBase: 0,
      priceCurrency: Currency.afn,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final breakdown = ProductConversion.breakdown(product, 17);
    expect(breakdown.cartons, 0);
    expect(breakdown.packages, 0);
    expect(breakdown.items, 17);
  });

  test('واحدهای صفر و منفی اعتبارسنجی نمی‌شوند', () {
    final product = Product(
      id: 1,
      name: 'محصول',
      supportsCarton: true,
      supportsPackage: true,
      itemsPerPackage: 0,
      packagesPerCarton: -1,
      currentStockBase: 0,
      priceCurrency: Currency.afn,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(
      () => validateProduct(product),
      throwsA(isA<ProductValidationException>()),
    );
  });
  test('پیکربندی نامعتبر رد می‌شود', () {
    final product = boxed().copyWith(itemsPerPackage: 0);
    expect(
      () => validateProduct(product),
      throwsA(isA<ProductValidationException>()),
    );
  });
}
