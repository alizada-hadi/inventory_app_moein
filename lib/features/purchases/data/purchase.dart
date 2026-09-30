import '../../../core/constants/app_constants.dart';
import '../../products/data/product_conversion.dart';
import '../../products/data/product.dart';

class Purchase {
  const Purchase({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.unit,
    required this.quantityBase,
    required this.unitCost,
    required this.currency,
    required this.totalCost,
    required this.purchaseDate,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int productId;
  final num quantity;
  final StockUnit unit;
  final num quantityBase;
  final num unitCost;
  final Currency currency;
  final num totalCost;
  final DateTime purchaseDate;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'product_id': productId,
    'quantity': quantity,
    'unit': unit.name,
    'quantity_base': quantityBase,
    'unit_cost': unitCost,
    'currency': currency.name,
    'total_cost': totalCost,
    'purchase_date': purchaseDate.toIso8601String(),
    'note': note,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Purchase.fromMap(Map<String, Object?> map) => Purchase(
    id: map['id'] as int?,
    productId: map['product_id'] as int,
    quantity: map['quantity'] as num,
    unit: StockUnit.values.byName(map['unit'] as String),
    quantityBase: map['quantity_base'] as num,
    unitCost: (map['unit_cost'] as num).toDouble(),
    currency: Currency.values.byName(map['currency'] as String),
    totalCost: (map['total_cost'] as num).toDouble(),
    purchaseDate: DateTime.parse(map['purchase_date'] as String),
    note: map['note'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );
}

class PurchaseValidationException implements Exception {
  const PurchaseValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

num calculatePurchaseQuantityBase(
  Product product,
  num quantity,
  StockUnit unit,
) {
  if (quantity <= 0) {
    throw const PurchaseValidationException('مقدار باید بیشتر از صفر باشد');
  }
  if (unit == StockUnit.carton && !product.supportsCarton ||
      unit == StockUnit.package && !product.supportsPackage ||
      unit == StockUnit.pocket && !product.supportsPocket) {
    throw const PurchaseValidationException(
      'این واحد برای محصول پشتیبانی نمی‌شود',
    );
  }
  return ProductConversion.convertToBase(product, quantity, unit);
}

num calculatePurchaseTotalCost(num quantity, num unitCost) {
  if (quantity <= 0) {
    throw const PurchaseValidationException('مقدار باید بیشتر از صفر باشد');
  }
  if (unitCost < 0) {
    throw const PurchaseValidationException('قیمت خرید معتبر نیست');
  }
  return quantity * unitCost;
}

num purchaseStockDifference(Purchase oldPurchase, Purchase newPurchase) =>
    newPurchase.quantityBase - oldPurchase.quantityBase;

bool canApplyStockChange(num currentStock, num change) =>
    currentStock + change >= 0;
