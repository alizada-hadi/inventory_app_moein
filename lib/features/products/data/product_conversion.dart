import 'product.dart';

enum StockUnit { carton, package, pocket, item }

extension StockUnitLabel on StockUnit {
  String get label => switch (this) {
    StockUnit.carton => 'کارتن',
    StockUnit.package => 'بسته',
    StockUnit.pocket => 'پاکت',
    StockUnit.item => 'عدد',
  };
}

class StockBreakdown {
  const StockBreakdown({
    required this.cartons,
    required this.packages,
    required this.pockets,
    required this.items,
  });
  final num cartons;
  final num packages;
  final num pockets;
  final num items;
}

abstract final class ProductConversion {
  static num convertToBase(Product product, num quantity, StockUnit unit) {
    if (quantity < 0) throw ArgumentError('quantity cannot be negative');
    return switch (unit) {
      StockUnit.item => quantity,
      StockUnit.package =>
        product.supportsPackage
            ? quantity * product.itemsPerPackage!
            : (throw ArgumentError('package is unsupported')),
      StockUnit.pocket =>
        product.supportsPocket
            ? quantity * product.itemsPerPocket!
            : (throw ArgumentError('pocket is unsupported')),
      StockUnit.carton =>
        product.supportsCarton
            ? quantity * product.itemsPerCarton
            : (throw ArgumentError('carton is unsupported')),
    };
  }

  static StockBreakdown breakdown(Product product, num baseQuantity) {
    if (baseQuantity < 0) {
      throw ArgumentError('baseQuantity cannot be negative');
    }
    var remaining = baseQuantity;
    num cartons = 0;
    num packages = 0;
    num pockets = 0;
    if (product.supportsCarton) {
      cartons = remaining ~/ product.itemsPerCarton;
      remaining %= product.itemsPerCarton;
    }
    if (product.supportsPackage) {
      packages = remaining ~/ product.itemsPerPackage!;
      remaining %= product.itemsPerPackage!;
    }
    if (product.supportsPocket) {
      pockets = remaining ~/ product.itemsPerPocket!;
      remaining %= product.itemsPerPocket!;
    }
    return StockBreakdown(
      cartons: cartons,
      packages: packages,
      pockets: pockets,
      items: remaining,
    );
  }
}
