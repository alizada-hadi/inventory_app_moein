import 'package:shamsi_date/shamsi_date.dart';

import '../../../core/constants/app_constants.dart';

enum ReportDatePreset {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  lastMonth,
  custom,
}

enum StockStatus { all, low, outOfStock, inStock }

class DateRangeFilter {
  const DateRangeFilter({
    required this.startDate,
    required this.endDate,
    required this.preset,
  });
  final DateTime startDate;
  final DateTime endDate;
  final ReportDatePreset preset;

  factory DateRangeFilter.thisMonth() {
    final now = Jalali.now();
    final start = Jalali(now.year, now.month, 1);
    final end = start.addMonths(1);
    return DateRangeFilter(
      startDate: start.toDateTime(),
      endDate: end.toDateTime(),
      preset: ReportDatePreset.thisMonth,
    );
  }

  factory DateRangeFilter.preset(ReportDatePreset preset) {
    final now = Jalali.now();
    late Jalali start;
    late Jalali end;
    switch (preset) {
      case ReportDatePreset.today:
        start = Jalali(now.year, now.month, now.day);
        end = start.addDays(1);
      case ReportDatePreset.yesterday:
        end = Jalali(now.year, now.month, now.day);
        start = end.addDays(-1);
      case ReportDatePreset.thisWeek:
        start = now.addDays(-(now.weekDay - 1));
        start = Jalali(start.year, start.month, start.day);
        end = start.addDays(7);
      case ReportDatePreset.thisMonth:
        start = Jalali(now.year, now.month, 1);
        end = start.addMonths(1);
      case ReportDatePreset.lastMonth:
        end = Jalali(now.year, now.month, 1);
        start = end.addMonths(-1);
      case ReportDatePreset.custom:
        return DateRangeFilter.thisMonth();
    }
    return DateRangeFilter(
      startDate: start.toDateTime(),
      endDate: end.toDateTime(),
      preset: preset,
    );
  }
}

class TransactionFilter {
  const TransactionFilter({
    required this.dateRange,
    this.productId,
    this.currency,
  });
  final DateRangeFilter dateRange;
  final int? productId;
  final Currency? currency;

  TransactionFilter copyWith({
    DateRangeFilter? dateRange,
    int? productId,
    bool clearProduct = false,
    Currency? currency,
    bool clearCurrency = false,
  }) => TransactionFilter(
    dateRange: dateRange ?? this.dateRange,
    productId: clearProduct ? null : productId ?? this.productId,
    currency: clearCurrency ? null : currency ?? this.currency,
  );
}

class InventoryFilter {
  const InventoryFilter({this.search = '', this.status = StockStatus.all});
  final String search;
  final StockStatus status;
  InventoryFilter copyWith({String? search, StockStatus? status}) =>
      InventoryFilter(
        search: search ?? this.search,
        status: status ?? this.status,
      );
}
