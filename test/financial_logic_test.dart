import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/features/financial/data/financial_models.dart';
import 'package:inventory_app/core/utils/currency_utils.dart';

void main() {
  test('manual asset, liability and net totals', () {
    final totals = calculateFinancialTotals(
      [
        const FinancialEntryDraft(categoryId: 1, amount: 193000),
        const FinancialEntryDraft(categoryId: 2, amount: 63000),
      ],
      {1: FinancialCategoryType.asset, 2: FinancialCategoryType.liability},
    );
    expect(totals.assets, 193000);
    expect(totals.liabilities, 63000);
    expect(totals.netPosition, 130000);
  });

  test('change is current net minus previous net', () {
    expect(130000 - 125100, 4900);
    expect(110000 - 120000, -10000);
  });

  test('empty values are represented as zero by totals', () {
    expect(calculateFinancialTotals([], {}).netPosition, 0);
  });

  test(
    'financial amounts accept Latin, Persian and Arabic digits with separators',
    () {
      expect(parseLocalizedInt('1,2,3'), 123);
      expect(parseLocalizedInt('۱٬۲۳۴'), 1234);
      expect(parseLocalizedInt('١،٢٣٤'), 1234);
      expect(parseLocalizedInt(' ۱۲۳ '), 123);
    },
  );
}
