import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import 'financial_models.dart';

class FinancialReportRepository {
  FinancialReportRepository({AppDatabase? database})
    : database = database ?? AppDatabase.instance;
  final AppDatabase database;
  Future<FinancialReport?> getPreviousReport(
    DateTime date, {
    int? excludingId,
  }) async {
    final db = await database.database;
    final args = <Object?>[date.toIso8601String()];
    var where = 'report_date < ?';
    if (excludingId != null) {
      where += ' AND id != ?';
      args.add(excludingId);
    }
    final rows = await db.query(
      'financial_reports',
      where: where,
      whereArgs: args,
      orderBy: 'report_date DESC, id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : FinancialReport.fromMap(rows.first);
  }

  Future<FinancialReport?> getNextReport(
    DateTime date, {
    int? excludingId,
  }) async {
    final db = await database.database;
    final args = <Object?>[date.toIso8601String()];
    var where = 'report_date > ?';
    if (excludingId != null) {
      where += ' AND id != ?';
      args.add(excludingId);
    }
    final rows = await db.query(
      'financial_reports',
      where: where,
      whereArgs: args,
      orderBy: 'report_date ASC, id ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : FinancialReport.fromMap(rows.first);
  }

  Future<List<FinancialReport>> getReportsPage({
    int offset = 0,
    int limit = 30,
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await database.database;
    final clauses = <String>[];
    final args = <Object?>[];
    if (start != null) {
      clauses.add('report_date >= ?');
      args.add(start.toIso8601String());
    }
    if (end != null) {
      clauses.add('report_date < ?');
      args.add(end.toIso8601String());
    }
    final rows = await db.query(
      'financial_reports',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'report_date DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return Future.wait(rows.map((m) async => _withDetails(m)));
  }

  Future<FinancialReport?> getReportById(int id) async {
    final db = await database.database;
    final rows = await db.query(
      'financial_reports',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _withDetails(rows.first);
  }

  Future<List<FinancialEntry>> getReportEntries(int reportId) async {
    final db = await database.database;
    final rows = await db.rawQuery(
      'SELECT e.*, COALESCE(e.category_name, c.name) AS category_name, COALESCE(e.category_type, c.type) AS type FROM financial_report_entries e LEFT JOIN financial_categories c ON c.id=e.category_id WHERE e.report_id=? ORDER BY type, e.id',
      [reportId],
    );
    return rows.map(FinancialEntry.fromMap).toList();
  }

  Future<FinancialReport> _withDetails(Map<String, Object?> row) async =>
      FinancialReport.fromMap(
        row,
        entries: await getReportEntries(row['id'] as int),
        previousReport: await getPreviousReport(
          DateTime.parse(row['report_date'] as String),
          excludingId: row['id'] as int,
        ),
      );
  Future<int> createReport({
    required DateTime reportDate,
    required Currency currency,
    required List<FinancialEntryDraft> entries,
    String? note,
  }) async => _write(null, reportDate, currency, entries, note);
  Future<int> updateReport({
    required int id,
    required DateTime reportDate,
    required Currency currency,
    required List<FinancialEntryDraft> entries,
    String? note,
  }) async => _write(id, reportDate, currency, entries, note);
  Future<int> _write(
    int? id,
    DateTime date,
    Currency currency,
    List<FinancialEntryDraft> entries,
    String? note,
  ) async {
    if (entries.map((e) => e.categoryId).toSet().length != entries.length ||
        entries.any((e) => e.amount < 0))
      throw const FormatException('مقادیر مالی معتبر نیستند');
    final db = await database.database;
    final now = DateTime.now().toIso8601String();
    return db.transaction((txn) async {
      final types = {
        for (final e in entries)
          e.categoryId: (e.type ?? FinancialCategoryType.asset).name,
      };
      final totalAssets = entries
          .where((e) => types[e.categoryId] == 'asset')
          .fold<int>(0, (s, e) => s + e.amount);
      final totalLiabilities = entries
          .where((e) => types[e.categoryId] == 'liability')
          .fold<int>(0, (s, e) => s + e.amount);
      final values = {
        'report_date': date.toIso8601String(),
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
        'total_assets': totalAssets,
        'total_liabilities': totalLiabilities,
        'net_position': totalAssets - totalLiabilities,
        'currency': currency.name,
        'updated_at': now,
      };
      final int reportId;
      if (id == null) {
        reportId = await txn.insert('financial_reports', {
          ...values,
          'created_at': now,
        });
      } else {
        await txn.update(
          'financial_reports',
          values,
          where: 'id = ?',
          whereArgs: [id],
        );
        reportId = id;
      }
      await txn.delete(
        'financial_report_entries',
        where: 'report_id = ?',
        whereArgs: [reportId],
      );
      for (final entry in entries.where((e) => e.amount != 0))
        await txn.insert('financial_report_entries', {
          'report_id': reportId,
          'category_id': entry.categoryId,
          'category_name': entry.categoryName ?? 'بدون نام',
          'category_type': entry.type?.name ?? 'asset',
          'amount': entry.amount,
          'note': entry.note,
          'created_at': now,
          'updated_at': now,
        });
      return reportId;
    });
  }

  Future<void> deleteReport(int id) async {
    final db = await database.database;
    await db.delete('financial_reports', where: 'id = ?', whereArgs: [id]);
  }
}
