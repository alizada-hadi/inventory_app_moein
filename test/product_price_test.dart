import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/core/constants/app_constants.dart';
import 'package:inventory_app/features/products/data/product.dart';
import 'package:inventory_app/features/products/data/product_conversion.dart';
import 'package:inventory_app/features/products/data/product_price_history.dart';
import 'package:inventory_app/features/products/data/product_price_repository.dart';
import 'package:inventory_app/features/purchases/data/purchase.dart';
import 'package:inventory_app/features/sales/data/sale.dart';

Product pricedProduct({
  int? carton = 1200,
  int? package = 70,
  int? item = 12,
  Currency currency = Currency.afn,
}) => Product(
  id: 1,
  name: 'صابون',
  supportsCarton: true,
  supportsPackage: true,
  itemsPerPackage: 6,
  packagesPerCarton: 20,
  cartonSalePrice: carton,
  packageSalePrice: package,
  itemSalePrice: item,
  priceCurrency: currency,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('تغییر قیمت کارتن مبلغ جدید را نگه می‌دارد', () {
    final request = PriceUpdateRequest(
      cartonPrice: 1500,
      currency: Currency.afn,
      effectiveDate: DateTime(2026, 9, 10),
    );
    expect(pricedProduct(carton: request.cartonPrice).cartonSalePrice, 1500);
  });

  test('تغییر قیمت سابقه قدیم و جدید ایجاد می‌کند', () {
    final history = ProductPriceHistory(
      id: 1,
      productId: 1,
      unit: StockUnit.carton,
      oldPrice: 1200,
      newPrice: 1500,
      currency: Currency.afn,
      effectiveDate: DateTime(2026, 9, 10),
      createdAt: DateTime(2026, 9, 10),
    );
    final restored = ProductPriceHistory.fromMap(history.toMap());
    expect(restored.oldPrice, 1200);
    expect(restored.newPrice, 1500);
  });

  test('قیمت بدون تغییر، تغییر واقعی محسوب نمی‌شود', () {
    final product = pricedProduct();
    expect(product.cartonSalePrice, product.cartonSalePrice);
  });

  test('چند قیمت در یک درخواست قیمت ثبت می‌شوند', () {
    final request = PriceUpdateRequest(
      cartonPrice: 1500,
      packagePrice: 85,
      currency: Currency.afn,
      effectiveDate: DateTime(2026),
    );
    expect(request.cartonPrice, 1500);
    expect(request.packagePrice, 85);
  });

  test('قیمت تاریخی فروش بعد از تغییر محصول ثابت می‌ماند', () {
    final historicalSale = Sale(
      id: 1,
      productId: 1,
      quantity: 1,
      unit: StockUnit.carton,
      quantityBase: 120,
      unitPrice: 1200,
      currency: Currency.afn,
      totalAmount: 1200,
      saleDate: DateTime(2026),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(historicalSale.unitPrice, 1200);
    expect(pricedProduct(carton: 1500).cartonSalePrice, 1500);
  });

  test('هزینه تاریخی خرید بعد از تغییر محصول ثابت می‌ماند', () {
    final historicalPurchase = Purchase(
      id: 1,
      productId: 1,
      quantity: 1,
      unit: StockUnit.carton,
      quantityBase: 120,
      unitCost: 1000,
      currency: Currency.afn,
      totalCost: 1000,
      purchaseDate: DateTime(2026),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(historicalPurchase.unitCost, 1000);
    expect(pricedProduct(carton: 1500).cartonSalePrice, 1500);
  });

  test('فروش آینده می‌تواند قیمت جدید را پیش‌فرض بگیرد', () {
    expect(pricedProduct(carton: 1500).cartonSalePrice, 1500);
  });

  test('واحد پشتیبانی‌نشده قیمت ندارد', () {
    final product = pricedProduct(carton: null).copyWith(supportsCarton: false);
    expect(product.cartonSalePrice, isNull);
  });

  test('ارز تاریخچه به‌درستی ذخیره می‌شود', () {
    final history = ProductPriceHistory(
      id: 1,
      productId: 1,
      unit: StockUnit.item,
      oldPrice: 12,
      newPrice: 15,
      currency: Currency.usd,
      effectiveDate: DateTime(2026),
      createdAt: DateTime(2026),
    );
    expect(ProductPriceHistory.fromMap(history.toMap()).currency, Currency.usd);
  });

  test('قیمت منفی رد می‌شود', () {
    expect(() => calculateSaleTotalAmount(1, -1), throwsA(isA<Exception>()));
  });
}
