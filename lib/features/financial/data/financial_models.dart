import '../../../core/constants/app_constants.dart';

enum FinancialCategoryType { asset, liability }

class FinancialCategory {
  const FinancialCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.isDefault,
    required this.isActive,
  });
  final int id;
  final String name;
  final FinancialCategoryType type;
  final bool isDefault;
  final bool isActive;
  factory FinancialCategory.fromMap(Map<String, Object?> m) =>
      FinancialCategory(
        id: m['id'] as int,
        name: m['name'] as String,
        type: FinancialCategoryType.values.byName(m['type'] as String),
        isDefault: m['is_default'] == 1,
        isActive: m['is_active'] == 1,
      );
}

class FinancialEntry {
  const FinancialEntry({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.type,
    required this.amount,
    this.note,
  });
  final int? id;
  final int categoryId;
  final String categoryName;
  final FinancialCategoryType type;
  final int amount;
  final String? note;
  factory FinancialEntry.fromMap(Map<String, Object?> m) => FinancialEntry(
    id: m['id'] as int?,
    categoryId: m['category_id'] as int,
    categoryName: m['category_name'] as String,
    type: FinancialCategoryType.values.byName(m['type'] as String),
    amount: (m['amount'] as num).toInt(),
    note: m['entry_note'] as String?,
  );
}

class FinancialReport {
  const FinancialReport({
    required this.id,
    required this.reportDate,
    required this.note,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netPosition,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
    required this.entries,
    this.previousReport,
    this.netChange,
  });
  final int? id;
  final DateTime reportDate;
  final String? note;
  final int totalAssets, totalLiabilities, netPosition;
  final Currency currency;
  final DateTime createdAt, updatedAt;
  final List<FinancialEntry> entries;
  final FinancialReport? previousReport;
  final int? netChange;
  bool get isFirst => previousReport == null;
  factory FinancialReport.fromMap(
    Map<String, Object?> m, {
    List<FinancialEntry> entries = const [],
    FinancialReport? previousReport,
  }) {
    final net = (m['net_position'] as num).toInt();
    return FinancialReport(
      id: m['id'] as int?,
      reportDate: DateTime.parse(m['report_date'] as String),
      note: m['note'] as String?,
      totalAssets: (m['total_assets'] as num).toInt(),
      totalLiabilities: (m['total_liabilities'] as num).toInt(),
      netPosition: net,
      currency: Currency.values.byName(m['currency'] as String),
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
      entries: entries,
      previousReport: previousReport,
      netChange: previousReport == null
          ? null
          : net - previousReport.netPosition,
    );
  }
}

class FinancialEntryDraft {
  const FinancialEntryDraft({
    required this.categoryId,
    required this.amount,
    this.categoryName,
    this.type,
    this.note,
  });
  final int categoryId;
  final int amount;
  final String? categoryName;
  final FinancialCategoryType? type;
  final String? note;
}

class FinancialTotals {
  const FinancialTotals(this.assets, this.liabilities);
  final int assets;
  final int liabilities;
  int get netPosition => assets - liabilities;
}

FinancialTotals calculateFinancialTotals(
  Iterable<FinancialEntryDraft> entries,
  Map<int, FinancialCategoryType> categoryTypes,
) {
  var assets = 0;
  var liabilities = 0;
  for (final entry in entries) {
    if (categoryTypes[entry.categoryId] == FinancialCategoryType.asset) {
      assets += entry.amount;
    } else if (categoryTypes[entry.categoryId] ==
        FinancialCategoryType.liability) {
      liabilities += entry.amount;
    }
  }
  return FinancialTotals(assets, liabilities);
}
