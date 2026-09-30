import '../../../core/constants/app_constants.dart';
import '../../products/data/product.dart';
import '../../products/data/product_conversion.dart';

class Sale {
  const Sale({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.unit,
    required this.quantityBase,
    required this.unitPrice,
    required this.currency,
    required this.totalAmount,
    required this.saleDate,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int productId;
  final num quantity;
  final StockUnit unit;
  final num quantityBase;
  final num unitPrice;
  final Currency currency;
  final num totalAmount;
  final DateTime saleDate;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'product_id': productId,
    'quantity': quantity,
    'unit': unit.name,
    'quantity_base': quantityBase,
    'unit_price': unitPrice,
    'currency': currency.name,
    'total_amount': totalAmount,
    'sale_date': saleDate.toIso8601String(),
    'note': note,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Sale.fromMap(Map<String, Object?> map) => Sale(
    id: map['id'] as int?,
    productId: map['product_id'] as int,
    quantity: map['quantity'] as num,
    unit: StockUnit.values.byName(map['unit'] as String),
    quantityBase: map['quantity_base'] as num,
    unitPrice: (map['unit_price'] as num).toDouble(),
    currency: Currency.values.byName(map['currency'] as String),
    totalAmount: (map['total_amount'] as num).toDouble(),
    saleDate: DateTime.parse(map['sale_date'] as String),
    note: map['note'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );
}

class SaleValidationException implements Exception {
  const SaleValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

num calculateSaleQuantityBase(Product product, num quantity, StockUnit unit) {
  if (quantity <= 0) {
    throw const SaleValidationException('مقدار باید بیشتر از صفر باشد');
  }
  if (unit == StockUnit.carton && !product.supportsCarton ||
      unit == StockUnit.package && !product.supportsPackage ||
      unit == StockUnit.pocket && !product.supportsPocket) {
    throw const SaleValidationException('این واحد برای محصول پشتیبانی نمی‌شود');
  }
  return ProductConversion.convertToBase(product, quantity, unit);
}

num calculateSaleTotalAmount(num quantity, num unitPrice) {
  if (quantity <= 0) {
    throw const SaleValidationException('مقدار باید بیشتر از صفر باشد');
  }
  if (unitPrice < 0) {
    throw const SaleValidationException('قیمت فروش معتبر نیست');
  }
  return quantity * unitPrice;
}

num saleStockDifference(Sale oldSale, Sale newSale) =>
    oldSale.quantityBase - newSale.quantityBase;

num salePriceForUnit(Product product, StockUnit unit) => switch (unit) {
  StockUnit.carton => product.cartonSalePrice ?? 0,
  StockUnit.package => product.packageSalePrice ?? 0,
  StockUnit.pocket => product.pocketSalePrice ?? 0,
  StockUnit.item => product.itemSalePrice ?? 0,
};
