import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/core/constants/app_constants.dart';
import 'package:inventory_app/features/products/data/product.dart';
import 'package:inventory_app/features/products/data/product_conversion.dart';
import 'package:inventory_app/features/sales/data/sale.dart';

Product soap({int stock = 1200, int cartonPrice = 1500}) => Product(
  id: 1,
  name: 'صابون',
  supportsCarton: true,
  supportsPackage: true,
  itemsPerPackage: 6,
  packagesPerCarton: 20,
  currentStockBase: stock,
  cartonSalePrice: cartonPrice,
  packageSalePrice: 85,
  itemSalePrice: 15,
  priceCurrency: Currency.afn,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Sale sale({
  required int base,
  int price = 1500,
  Currency currency = Currency.afn,
}) => Sale(
  id: 1,
  productId: 1,
  quantity: 2,
  unit: StockUnit.carton,
  quantityBase: base,
  unitPrice: price,
  currency: currency,
  totalAmount: 3000,
  saleDate: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('فروش دو کارتن از موجودی ۱۲۰۰، موجودی را به ۹۶۰ می‌رساند', () {
    final sold = calculateSaleQuantityBase(soap(), 2, StockUnit.carton);
    expect(sold, 240);
    expect(soap().currentStockBase - sold, 960);
  });

  test('فروش بیشتر از موجودی رد می‌شود', () {
    final sold = calculateSaleQuantityBase(
      soap(stock: 100),
      2,
      StockUnit.carton,
    );
    expect(100 - sold < 0, isTrue);
  });

  test('فروش بسته و عدد به واحد پایه تبدیل می‌شود', () {
    expect(calculateSaleQuantityBase(soap(), 5, StockUnit.package), 30);
    expect(calculateSaleQuantityBase(soap(), 7, StockUnit.item), 7);
  });

  test('قیمت دقیق فروش و ارز دالر در سابقه حفظ می‌شود', () {
    final value = sale(base: 240, price: 1450, currency: Currency.usd);
    expect(value.unitPrice, 1450);
    expect(value.totalAmount, 3000);
    expect(value.currency, Currency.usd);
    expect(Sale.fromMap(value.toMap()).unitPrice, 1450);
  });

  test('تغییر قیمت فروش محصول سابقه فروش را تغییر نمی‌دهد', () {
    final historical = sale(base: 240, price: 1200);
    final changedProduct = soap(cartonPrice: 1500);
    expect(historical.unitPrice, 1200);
    expect(changedProduct.cartonSalePrice, 1500);
  });

  test('قیمت دستی فروش قیمت محصول را تغییر نمی‌دهد', () {
    final product = soap();
    final saleValue = sale(base: 240, price: 1400);
    expect(saleValue.unitPrice, 1400);
    expect(product.cartonSalePrice, 1500);
  });

  test('ویرایش فروش به مقدار بیشتر فقط تفاوت را از موجودی کم می‌کند', () {
    expect(saleStockDifference(sale(base: 240), sale(base: 360)), -120);
  });

  test('ویرایش فروش به مقدار کمتر موجودی را برمی‌گرداند', () {
    expect(saleStockDifference(sale(base: 360), sale(base: 120)), 240);
  });

  test('ویرایش فقط قیمت موجودی را تغییر نمی‌دهد', () {
    expect(
      saleStockDifference(sale(base: 240), sale(base: 240, price: 1400)),
      0,
    );
  });

  test('حذف فروش به اندازه مقدار پایه موجودی را برمی‌گرداند', () {
    expect(960 + sale(base: 240).quantityBase, 1200);
  });

  test('موجودی منفی هرگز مجاز نیست', () {
    expect(
      100 - calculateSaleQuantityBase(soap(stock: 100), 2, StockUnit.carton) >=
          0,
      isFalse,
    );
  });

  test('قیمت و مقدار نامعتبر رد می‌شوند', () {
    expect(
      () => calculateSaleQuantityBase(soap(), 0, StockUnit.item),
      throwsA(isA<SaleValidationException>()),
    );
    expect(
      () => calculateSaleTotalAmount(1, -1),
      throwsA(isA<SaleValidationException>()),
    );
  });

  test('قیمت پیش‌فرض از واحد انتخاب‌شده خوانده می‌شود', () {
    expect(salePriceForUnit(soap(), StockUnit.carton), 1500);
    expect(salePriceForUnit(soap(), StockUnit.package), 85);
    expect(salePriceForUnit(soap(), StockUnit.item), 15);
  });
}
