import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqflite/sqflite.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/jalali_date_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../data/financial_models.dart';
import '../providers/financial_providers.dart';

class FinancialReportsScreen extends ConsumerWidget {
  const FinancialReportsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financialReportsProvider);
    return AppScaffold(
      title: 'گزارش‌های مالی',
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(financialReportsProvider),
            child: const Text('تلاش دوباره'),
          ),
        ),
        data: (reports) => Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'ایجاد گزارش مالی',
                icon: Icons.add_chart,
                onPressed: () => context.push('/financial-form'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: reports.isEmpty
                  ? const Center(child: Text('هنوز گزارش مالی ثبت نشده است.'))
                  : ListView.builder(
                      itemCount: reports.length,
                      itemBuilder: (_, i) => _ReportCard(reports[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard(this.report);
  final FinancialReport report;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/financial-details', extra: report.id),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    JalaliDateUtils.format(report.reportDate),
                    style: AppTextStyles.sectionTitle,
                  ),
                ),
                Text(report.currency.label, style: AppTextStyles.muted),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'موجودی‌ها: ${formatNumber(report.totalAssets)}   بدهی‌ها: ${formatNumber(report.totalLiabilities)}',
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('خالص: '),
                Text(
                  formatCurrency(report.netPosition, report.currency),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (report.netChange != null) ...[
                  const Spacer(),
                  Text(
                    '${report.netChange! >= 0 ? '+' : ''}${formatCurrency(report.netChange!, report.currency)} نسبت به گزارش قبلی',
                    style: TextStyle(
                      color: report.netChange! >= 0
                          ? Colors.green.shade700
                          : Colors.orange.shade800,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class FinancialReportFormScreen extends ConsumerStatefulWidget {
  const FinancialReportFormScreen({this.initialReport, super.key});
  final FinancialReport? initialReport;
  @override
  ConsumerState<FinancialReportFormScreen> createState() =>
      _FinancialReportFormState();
}

class _FinancialReportFormState
    extends ConsumerState<FinancialReportFormScreen> {
  final note = TextEditingController();
  final amounts = <int, TextEditingController>{};
  DateTime date = DateTime.now();
  Currency currency = Currency.usd;
  List<FinancialCategory> categories = [];
  int _nextCategoryId = -1;
  FinancialReport? previous;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    if (widget.initialReport != null) {
      final r = widget.initialReport!;
      date = r.reportDate;
      currency = r.currency;
      note.text = r.note ?? '';
      for (final e in r.entries)
        amounts[e.categoryId] = TextEditingController(
          text: e.amount.toString(),
        );
    }
    _load();
  }

  Future<void> _load() async {
    final entries = widget.initialReport?.entries ?? const <FinancialEntry>[];
    if (!mounted) return;
    setState(() {
      categories = [
        for (final e in entries)
          FinancialCategory(
            id: _nextCategoryId--,
            name: e.categoryName,
            type: e.type,
            isDefault: false,
            isActive: true,
          ),
      ];
    });
    _resolvePrevious();
  }

  Future<void> _resolvePrevious() async {
    final value = await ref
        .read(financialReportControllerProvider)
        .resolvePreviousReport(date, excludingId: widget.initialReport?.id);
    if (mounted) setState(() => previous = value);
  }

  @override
  void dispose() {
    note.dispose();
    for (final c in amounts.values) c.dispose();
    super.dispose();
  }

  int _amount(int id) => parseLocalizedInt(amounts[id]?.text ?? '') ?? 0;
  int get assets => categories
      .where((c) => c.type == FinancialCategoryType.asset)
      .fold(0, (s, c) => s + _amount(c.id));
  int get liabilities => categories
      .where((c) => c.type == FinancialCategoryType.liability)
      .fold(0, (s, c) => s + _amount(c.id));
  Future<void> _pickDate() async {
    final j = await showAfghanJalaliDatePicker(
      context,
      initialDate: Jalali.fromDateTime(date),
      firstDate: Jalali(1300, 1, 1),
      lastDate: Jalali(1500, 12, 29),
    );
    if (j != null) {
      setState(() => date = j.toDateTime());
      _resolvePrevious();
    }
  }

  Future<void> _add(FinancialCategoryType type) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _CategoryDialog(type: type),
    );
    if (name != null) {
      setState(() {
        categories = [
          ...categories,
          FinancialCategory(
            id: _nextCategoryId--,
            name: name,
            type: type,
            isDefault: false,
            isActive: true,
          ),
        ];
      });
    }
  }

  void _remove(FinancialCategory category) {
    final controller = amounts.remove(category.id);
    controller?.dispose();
    setState(() => categories.removeWhere((c) => c.id == category.id));
  }

  Future<void> _save() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final entries = categories
          .map(
            (c) => FinancialEntryDraft(
              categoryId: c.id,
              categoryName: c.name,
              type: c.type,
              amount: _amount(c.id),
            ),
          )
          .where((e) => e.amount != 0)
          .toList();
      final controller = ref.read(financialReportControllerProvider);
      if (widget.initialReport == null)
        await controller.createReport(
          date: date,
          currency: currency,
          entries: entries,
          note: note.text,
        );
      else
        await controller.updateReport(
          id: widget.initialReport!.id!,
          date: date,
          currency: currency,
          entries: entries,
          note: note.text,
        );
      if (mounted) context.pop();
    } on DatabaseException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('UNIQUE')
                  ? 'برای این تاریخ قبلاً گزارش مالی ثبت شده است.'
                  : 'ذخیره گزارش موفق نشد.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final net = assets - liabilities;
    final change = previous == null ? null : net - previous!.netPosition;
    return AppScaffold(
      title: widget.initialReport == null
          ? 'ایجاد گزارش مالی'
          : 'ویرایش گزارش مالی',
      body: ListView(
        children: [
          _dateField(),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<Currency>(
            value: currency,
            decoration: const InputDecoration(labelText: 'ارز'),
            items: Currency.values
                .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => currency = v);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _section('موجودی‌ها', FinancialCategoryType.asset),
          _section('بدهی‌ها', FinancialCategoryType.liability),
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('خلاصه', style: AppTextStyles.sectionTitle),
                  Text('مجموع موجودی‌ها: ${formatNumber(assets)}'),
                  Text('مجموع بدهی‌ها: ${formatNumber(liabilities)}'),
                  const SizedBox(height: 4),
                  Text(
                    'خالص دارایی: ${formatCurrency(net, currency)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (previous == null)
                    const Text('این اولین گزارش مالی است.')
                  else
                    Text(
                      'تغییر نسبت به گزارش قبلی: ${change! >= 0 ? '+' : ''}${formatCurrency(change, currency)}',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: note,
            decoration: const InputDecoration(
              labelText: 'یادداشت (اختیاری)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: busy ? 'در حال ذخیره...' : 'ذخیره گزارش',
              onPressed: busy ? null : _save,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _dateField() => InkWell(
    onTap: _pickDate,
    child: InputDecorator(
      decoration: const InputDecoration(
        labelText: 'تاریخ گزارش',
        suffixIcon: Icon(Icons.calendar_month_outlined),
      ),
      child: Text(JalaliDateUtils.format(date)),
    ),
  );
  Widget _section(String title, FinancialCategoryType type) {
    final list = categories.where((c) => c.type == type).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: [
              ...list.map((c) => _amountRow(c)),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(
                  type == FinancialCategoryType.asset
                      ? 'افزودن نوع موجودی'
                      : 'افزودن نوع بدهی',
                ),
                onTap: () => _add(type),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _amountRow(FinancialCategory c) {
    final controller = amounts.putIfAbsent(c.id, () => TextEditingController());
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.left,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: c.name,
          suffixText: currency.label,
          prefixIcon: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'حذف نوع',
            onPressed: () => _remove(c),
          ),
        ),
      ),
    );
  }
}

class FinancialReportDetailsScreen extends ConsumerWidget {
  const FinancialReportDetailsScreen({required this.id, super.key});
  final int id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<FinancialReport?>(
      future: ref.read(financialReportControllerProvider).loadReportDetails(id),
      builder: (context, snap) {
        final r = snap.data;
        if (r == null)
          return AppScaffold(
            title: 'گزارش مالی',
            body: const Center(child: CircularProgressIndicator()),
          );
        return AppScaffold(
          title: 'گزارش مالی',
          actions: [
            IconButton(
              onPressed: () => context.push('/financial-form', extra: r),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: () => _delete(context, ref, r),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
          body: ListView(
            children: [
              Text(
                JalaliDateUtils.format(r.reportDate),
                style: AppTextStyles.pageTitle,
              ),
              if (r.note != null) Text(r.note!, style: AppTextStyles.muted),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'موجودی‌ها: ${formatNumber(r.totalAssets)}\nبدهی‌ها: ${formatNumber(r.totalLiabilities)}\nخالص دارایی: ${formatCurrency(r.netPosition, r.currency)}\nتغییر: ${r.netChange == null ? 'ندارد' : formatCurrency(r.netChange!, r.currency)}',
                  ),
                ),
              ),
              ..._entries(r, FinancialCategoryType.asset),
              ..._entries(r, FinancialCategoryType.liability),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _entries(FinancialReport r, FinancialCategoryType type) {
    final e = r.entries.where((x) => x.type == type).toList();
    return [
      Text(
        type == FinancialCategoryType.asset ? 'موجودی‌ها' : 'بدهی‌ها',
        style: AppTextStyles.sectionTitle,
      ),
      ...e.map(
        (x) => ListTile(
          title: Text(x.categoryName),
          trailing: Text(formatNumber(x.amount)),
        ),
      ),
    ];
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    FinancialReport r,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف گزارش مالی؟'),
        content: const Text('این گزارش حذف خواهد شد.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await ref.read(financialReportControllerProvider).deleteReport(r.id!);
      if (context.mounted) context.pop();
    }
  }
}

class _CategoryDialog extends StatelessWidget {
  const _CategoryDialog({required this.type});
  final FinancialCategoryType type;
  @override
  Widget build(BuildContext context) {
    final c = TextEditingController();
    return AlertDialog(
      title: Text(
        type == FinancialCategoryType.asset
            ? 'افزودن نوع موجودی'
            : 'افزودن نوع بدهی',
      ),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'نام نوع'),
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: const Text('لغو')),
        FilledButton(
          onPressed: () {
            if (c.text.trim().isNotEmpty) context.pop(c.text.trim());
          },
          child: const Text('افزودن'),
        ),
      ],
    );
  }
}
