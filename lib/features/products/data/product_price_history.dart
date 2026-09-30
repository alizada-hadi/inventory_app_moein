import '../../../core/constants/app_constants.dart';
import 'product_conversion.dart';

class ProductPriceHistory {
  const ProductPriceHistory({
    required this.id,
    required this.productId,
    required this.unit,
    required this.oldPrice,
    required this.newPrice,
    required this.currency,
    required this.effectiveDate,
    required this.createdAt,
  });

  final int? id;
  final int productId;
  final StockUnit unit;
  final num? oldPrice;
  final num newPrice;
  final Currency currency;
  final DateTime effectiveDate;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'product_id': productId,
    'unit': unit.name,
    'old_price': oldPrice,
    'new_price': newPrice,
    'currency': currency.name,
    'effective_date': effectiveDate.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  factory ProductPriceHistory.fromMap(Map<String, Object?> map) =>
      ProductPriceHistory(
        id: map['id'] as int?,
        productId: map['product_id'] as int,
        unit: StockUnit.values.byName(map['unit'] as String),
        oldPrice: (map['old_price'] as num?)?.toDouble(),
        newPrice: (map['new_price'] as num).toDouble(),
        currency: Currency.values.byName(map['currency'] as String),
        effectiveDate: DateTime.parse(map['effective_date'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
