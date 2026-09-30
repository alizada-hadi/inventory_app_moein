enum Currency { afn, usd }

extension CurrencyLabel on Currency {
  String get label => switch (this) {
    Currency.afn => 'افغانی',
    Currency.usd => 'دالر',
  };
}

enum InventoryUnit { carton, package, pocket, item }

extension InventoryUnitLabel on InventoryUnit {
  String get label => switch (this) {
    InventoryUnit.carton => 'کارتن',
    InventoryUnit.package => 'بسته',
    InventoryUnit.pocket => 'پاکت',
    InventoryUnit.item => 'عدد',
  };
}
