import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../data/financial_models.dart';
import '../data/financial_repository.dart';

final financialReportRepositoryProvider = Provider(
  (_) => FinancialReportRepository(),
);
final financialReportsProvider =
    FutureProvider.autoDispose<List<FinancialReport>>(
      (ref) => ref.read(financialReportRepositoryProvider).getReportsPage(),
    );

class FinancialReportController {
  FinancialReportController(this.ref);
  final Ref ref;
  FinancialReportRepository get repository =>
      ref.read(financialReportRepositoryProvider);
  Future<int> createReport({
    required DateTime date,
    required Currency currency,
    required List<FinancialEntryDraft> entries,
    String? note,
  }) async {
    final id = await repository.createReport(
      reportDate: date,
      currency: currency,
      entries: entries,
      note: note,
    );
    _refresh();
    return id;
  }

  Future<int> updateReport({
    required int id,
    required DateTime date,
    required Currency currency,
    required List<FinancialEntryDraft> entries,
    String? note,
  }) async {
    final value = await repository.updateReport(
      id: id,
      reportDate: date,
      currency: currency,
      entries: entries,
      note: note,
    );
    _refresh();
    return value;
  }

  Future<void> deleteReport(int id) async {
    await repository.deleteReport(id);
    _refresh();
  }

  Future<FinancialReport?> loadReportDetails(int id) =>
      repository.getReportById(id);
  Future<FinancialReport?> resolvePreviousReport(
    DateTime date, {
    int? excludingId,
  }) => repository.getPreviousReport(date, excludingId: excludingId);
  void _refresh() {
    ref.invalidate(financialReportsProvider);
  }
}

final financialReportControllerProvider = Provider(
  (ref) => FinancialReportController(ref),
);
