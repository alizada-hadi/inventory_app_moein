import '../../../core/constants/app_constants.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    this.barcode,
    this.unit = InventoryUnit.package,
    this.amount = 0,
    this.restockLevel = 10,
    required this.supportsCarton,
    required this.supportsPackage,
    this.supportsPocket = false,
    this.itemsPerPackage,
    this.itemsPerPocket,
    this.packagesPerCarton,
    this.itemsPerCartonDirect,
    this.currentStockBase = 0,
    this.cartonSalePrice,
    this.packageSalePrice,
    this.pocketSalePrice,
    this.itemSalePrice,
    this.costPrice,
    this.salePrice,
    required this.priceCurrency,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String name;
  final String? barcode;
  final InventoryUnit unit;
  final num amount;
  final num restockLevel;
  final bool supportsCarton;
  final bool supportsPackage;
  final bool supportsPocket;
  final int? itemsPerPackage;
  final int? itemsPerPocket;
  final int? packagesPerCarton;
  final int? itemsPerCartonDirect;
  final num currentStockBase;
  final num? cartonSalePrice;
  final num? packageSalePrice;
  final num? pocketSalePrice;
  final num? itemSalePrice;
  final num? costPrice;
  final num? salePrice;
  final Currency priceCurrency;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get itemsPerCarton => supportsCarton
      ? (supportsPackage
            ? itemsPerPackage! * packagesPerCarton!
            : itemsPerCartonDirect!)
      : 0;

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    InventoryUnit? unit,
    num? amount,
    num? restockLevel,
    bool? supportsCarton,
    bool? supportsPackage,
    bool? supportsPocket,
    int? itemsPerPackage,
    int? itemsPerPocket,
    int? packagesPerCarton,
    int? itemsPerCartonDirect,
    num? currentStockBase,
    num? cartonSalePrice,
    num? packageSalePrice,
    num? pocketSalePrice,
    num? itemSalePrice,
    num? costPrice,
    num? salePrice,
    Currency? priceCurrency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    barcode: barcode ?? this.barcode,
    unit: unit ?? this.unit,
    amount: amount ?? this.amount,
    restockLevel: restockLevel ?? this.restockLevel,
    supportsCarton: supportsCarton ?? this.supportsCarton,
    supportsPackage: supportsPackage ?? this.supportsPackage,
    supportsPocket: supportsPocket ?? this.supportsPocket,
    itemsPerPackage: itemsPerPackage ?? this.itemsPerPackage,
    itemsPerPocket: itemsPerPocket ?? this.itemsPerPocket,
    packagesPerCarton: packagesPerCarton ?? this.packagesPerCarton,
    itemsPerCartonDirect: itemsPerCartonDirect ?? this.itemsPerCartonDirect,
    currentStockBase: currentStockBase ?? this.currentStockBase,
    cartonSalePrice: cartonSalePrice ?? this.cartonSalePrice,
    packageSalePrice: packageSalePrice ?? this.packageSalePrice,
    pocketSalePrice: pocketSalePrice ?? this.pocketSalePrice,
    itemSalePrice: itemSalePrice ?? this.itemSalePrice,
    costPrice: costPrice ?? this.costPrice,
    salePrice: salePrice ?? this.salePrice,
    priceCurrency: priceCurrency ?? this.priceCurrency,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'barcode': barcode,
    'unit': unit.name,
    'amount': amount,
    'restock_level': restockLevel,
    'supports_carton': supportsCarton ? 1 : 0,
    'supports_package': supportsPackage ? 1 : 0,
    'supports_pocket': supportsPocket ? 1 : 0,
    'items_per_package': itemsPerPackage,
    'items_per_pocket': itemsPerPocket,
    'packages_per_carton': packagesPerCarton,
    'items_per_carton_direct': itemsPerCartonDirect,
    'current_stock_base': currentStockBase,
    'carton_sale_price': cartonSalePrice,
    'package_sale_price': packageSalePrice,
    'pocket_sale_price': pocketSalePrice,
    'item_sale_price': itemSalePrice,
    'cost_price': costPrice,
    'sale_price': salePrice,
    'price_currency': priceCurrency.name,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Product.fromMap(Map<String, Object?> map) => Product(
    id: map['id'] as int?,
    name: map['name'] as String,
    barcode: map['barcode'] as String?,
    unit: InventoryUnit.values.byName((map['unit'] as String?) ?? 'item'),
    amount: (map['amount'] as num?)?.toDouble() ?? 0,
    restockLevel: (map['restock_level'] as num?)?.toDouble() ?? 10,
    supportsCarton: (map['supports_carton'] as int) == 1,
    supportsPackage: (map['supports_package'] as int) == 1,
    supportsPocket: (map['supports_pocket'] as int?) == 1,
    itemsPerPackage: map['items_per_package'] as int?,
    itemsPerPocket: map['items_per_pocket'] as int?,
    packagesPerCarton: map['packages_per_carton'] as int?,
    itemsPerCartonDirect: map['items_per_carton_direct'] as int?,
    currentStockBase: (map['current_stock_base'] as num),
    cartonSalePrice: (map['carton_sale_price'] as num?)?.toDouble(),
    packageSalePrice: (map['package_sale_price'] as num?)?.toDouble(),
    pocketSalePrice: (map['pocket_sale_price'] as num?)?.toDouble(),
    itemSalePrice: (map['item_sale_price'] as num?)?.toDouble(),
    costPrice: (map['cost_price'] as num?)?.toDouble(),
    salePrice: (map['sale_price'] as num?)?.toDouble(),
    priceCurrency: Currency.values.byName(map['price_currency'] as String),
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );
}

class ProductValidationException implements Exception {
  const ProductValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

void validateProduct(Product product) {
  if (product.name.trim().isEmpty) {
    throw const ProductValidationException('نام محصول الزامی است');
  }
  if (product.amount < 0) {
    throw const ProductValidationException('مقدار نمی‌تواند منفی باشد');
  }
  if (product.restockLevel < 0) {
    throw const ProductValidationException(
      'حداقل موجودی برای خرید مجدد نمی‌تواند منفی باشد',
    );
  }
  if ((product.costPrice != null && product.costPrice! < 0) ||
      (product.salePrice != null && product.salePrice! < 0)) {
    throw const ProductValidationException('قیمت نمی‌تواند منفی باشد');
  }
  if (product.currentStockBase < 0) {
    throw const ProductValidationException('موجودی نمی‌تواند منفی باشد');
  }
  if (product.supportsPackage &&
      (product.itemsPerPackage == null || product.itemsPerPackage! <= 0)) {
    throw const ProductValidationException(
      'تعداد عدد در هر بسته باید مثبت باشد',
    );
  }
  if (product.supportsPocket &&
      (product.itemsPerPocket == null || product.itemsPerPocket! <= 0)) {
    throw const ProductValidationException(
      'تعداد عدد در هر پاکت باید مثبت باشد',
    );
  }
  if (product.supportsCarton) {
    if (product.supportsPackage &&
        (product.packagesPerCarton == null ||
            product.packagesPerCarton! <= 0)) {
      throw const ProductValidationException(
        'تعداد بسته در هر کارتن باید مثبت باشد',
      );
    }
    if (!product.supportsPackage &&
        (product.itemsPerCartonDirect == null ||
            product.itemsPerCartonDirect! <= 0)) {
      throw const ProductValidationException(
        'تعداد عدد در هر کارتن باید مثبت باشد',
      );
    }
  }
  if (!product.supportsPackage &&
      (product.itemsPerPackage != null || product.packagesPerCarton != null)) {
    throw const ProductValidationException('تنظیمات بسته معتبر نیست');
  }
  if (product.supportsPackage &&
      !product.supportsCarton &&
      product.packagesPerCarton != null) {
    throw const ProductValidationException(
      'تعداد بسته در هر کارتن بدون کارتن معتبر نیست',
    );
  }
  if (!product.supportsCarton && product.itemsPerCartonDirect != null) {
    throw const ProductValidationException(
      'تعداد عدد در هر کارتن بدون کارتن معتبر نیست',
    );
  }
  if (!product.supportsPocket && product.pocketSalePrice != null) {
    throw const ProductValidationException(
      'قیمت واحد پشتیبانی‌نشده معتبر نیست',
    );
  }
  if (!product.supportsCarton && product.cartonSalePrice != null ||
      !product.supportsPackage && product.packageSalePrice != null) {
    throw const ProductValidationException(
      'قیمت واحد پشتیبانی‌نشده معتبر نیست',
    );
  }
  for (final price in [
    product.cartonSalePrice,
    product.packageSalePrice,
    product.itemSalePrice,
  ]) {
    if (price != null && price < 0) {
      throw const ProductValidationException('قیمت نمی‌تواند منفی باشد');
    }
  }
}
