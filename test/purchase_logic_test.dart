import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/core/constants/app_constants.dart';
import 'package:inventory_app/features/products/data/product.dart';
import 'package:inventory_app/features/products/data/product_conversion.dart';
import 'package:inventory_app/features/purchases/data/purchase.dart';

Product soap({int stock = 0}) => Product(
  id: 1,
  name: 'صابون',
  supportsCarton: true,
  supportsPackage: true,
  itemsPerPackage: 6,
  packagesPerCarton: 20,
  currentStockBase: stock,
  priceCurrency: Currency.afn,
  cartonSalePrice: 1200,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Purchase purchase({
  required int base,
  int cost = 1000,
  Currency currency = Currency.afn,
}) => Purchase(
  id: 1,
  productId: 1,
  quantity: 10,
  unit: StockUnit.carton,
  quantityBase: base,
  unitCost: cost,
  currency: currency,
  totalCost: 10000,
  purchaseDate: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('۳۰ کارتن به ۳۶۰۰ واحد پایه تبدیل و جمع هزینه محاسبه می‌شود', () {
    expect(calculatePurchaseQuantityBase(soap(), 30, StockUnit.carton), 3600);
    expect(calculatePurchaseTotalCost(30, 1000), 30000);
  });

  test('موجودی فعلی با خرید افزایش می‌یابد', () {
    expect(
      soap(stock: 240).currentStockBase +
          calculatePurchaseQuantityBase(soap(), 30, StockUnit.carton),
      3840,
    );
  });

  test('خرید بسته و عدد نیز به واحد پایه تبدیل می‌شوند', () {
    expect(calculatePurchaseQuantityBase(soap(), 5, StockUnit.package), 30);
    expect(calculatePurchaseQuantityBase(soap(), 7, StockUnit.item), 7);
  });

  test('ارز دالر در مدل خرید حفظ می‌شود و قیمت فروش تغییر نمی‌کند', () {
    final value = purchase(base: 600, currency: Currency.usd, cost: 100);
    expect(value.currency, Currency.usd);
    expect(soap().cartonSalePrice, 1200);
  });

  test('ویرایش خرید فقط تفاوت موجودی را تغییر می‌دهد', () {
    expect(
      purchaseStockDifference(purchase(base: 1200), purchase(base: 1440)),
      240,
    );
    expect(
      purchaseStockDifference(purchase(base: 1200), purchase(base: 960)),
      -240,
    );
  });

  test('ویرایش یا حذف در صورت منفی شدن موجودی رد می‌شود', () {
    expect(canApplyStockChange(1000, -240), isTrue);
    expect(canApplyStockChange(50, -100), isFalse);
    expect(canApplyStockChange(50, -50), isTrue);
  });

  test('واحد پشتیبانی‌نشده و مقدار نامعتبر رد می‌شوند', () {
    final itemOnly = soap().copyWith(
      supportsCarton: false,
      supportsPackage: false,
    );
    expect(
      () => calculatePurchaseQuantityBase(itemOnly, 1, StockUnit.carton),
      throwsA(isA<PurchaseValidationException>()),
    );
    expect(
      () => calculatePurchaseTotalCost(0, 100),
      throwsA(isA<PurchaseValidationException>()),
    );
    expect(
      () => calculatePurchaseTotalCost(1, -1),
      throwsA(isA<PurchaseValidationException>()),
    );
  });
}
