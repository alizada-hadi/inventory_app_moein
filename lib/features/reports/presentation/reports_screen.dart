import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/jalali_date_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../products/data/product.dart';
import '../../products/data/product_conversion.dart';
import '../../products/data/product_repository.dart';
import '../../products/presentation/product_details_screen.dart';
import '../../purchases/presentation/purchase_details_screen.dart';
import '../../sales/presentation/sale_details_screen.dart';
import '../data/report_filters.dart';
import '../data/report_repository.dart';
import '../providers/report_providers.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: AppScaffold(
      title: 'گزارش‌ها',
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Card(
                color: AppColors.infoSurface,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.analytics_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'بررسی و تحلیل اطلاعات کسب‌وکار شما',
                          textAlign: TextAlign.right,
                          style: AppTextStyles.sectionTitle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _ReportsTabHeaderDelegate(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(3),
                    indicator: BoxDecoration(
                      color: AppColors.infoSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary),
                    ),
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.mutedText,
                    labelStyle: AppTextStyles.label,
                    tabs: const [
                      Tab(child: Text('گزارش فروش', softWrap: false)),
                      Tab(child: Text('گزارش خرید', softWrap: false)),
                      Tab(child: Text('گزارش موجودی', softWrap: false)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: const TabBarView(
            children: [_SalesReport(), _PurchasesReport(), _InventoryReport()],
          ),
        ),
      ),
    ),
  );
}

class _ReportsTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ReportsTabHeaderDelegate({required this.child});
  final Widget child;

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Container(
    color: Theme.of(context).scaffoldBackgroundColor,
    padding: const EdgeInsets.only(top: 4, bottom: 4),
    child: child,
  );

  @override
  bool shouldRebuild(covariant _ReportsTabHeaderDelegate oldDelegate) => false;
}

class _SalesReport extends ConsumerStatefulWidget {
  const _SalesReport();
  @override
  ConsumerState<_SalesReport> createState() =>
      _TransactionReportState<_SalesReport>(isSales: true);
}

class _PurchasesReport extends ConsumerStatefulWidget {
  const _PurchasesReport();
  @override
  ConsumerState<_PurchasesReport> createState() =>
      _TransactionReportState<_PurchasesReport>(isSales: false);
}

class _TransactionReportState<W extends ConsumerStatefulWidget>
    extends ConsumerState<W> {
  _TransactionReportState({required this.isSales});
  final bool isSales;
  int? productId;
  String? productName;
  Currency? currency;
  ReportDatePreset preset = ReportDatePreset.thisMonth;
  DateRangeFilter range = DateRangeFilter.thisMonth();

  @override
  Widget build(BuildContext context) {
    final sales = ref.watch(salesReportProvider);
    final purchases = ref.watch(purchasesReportProvider);
    final rows = isSales ? sales.items : purchases.items;
    final loading = isSales ? sales.loading : purchases.loading;
    final loadingMore = isSales ? sales.loadingMore : purchases.loadingMore;
    final error = isSales ? sales.error : purchases.error;
    final summary = isSales ? sales.summary : purchases.summary;
    if (loading && summary == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final headerCount = summary == null ? 1 : 2;
    final hasTail = loadingMore || error != null;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 350) _loadMore();
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 4, bottom: 20),
        itemCount:
            headerCount + (rows.isEmpty ? 1 : rows.length) + (hasTail ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) return _filterBar();
          if (summary != null && index == 1) return _summary(summary);
          final rowIndex = index - headerCount;
          if (rows.isEmpty && rowIndex == 0) {
            return SizedBox(
              height: 240,
              child: EmptyState(
                message: isSales
                    ? 'هیچ فروشی در این بازه پیدا نشد.'
                    : 'هیچ خریدی در این بازه پیدا نشد.',
              ),
            );
          }
          if (rowIndex == rows.length) {
            return loadingMore
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : TextButton(
                    onPressed: _loadMore,
                    child: const Text('تلاش مجدد'),
                  );
          }
          if (isSales) {
            final report = sales.items[rowIndex];
            final sale = report.sale;
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: const Icon(Icons.point_of_sale_outlined),
                title: Text(
                  report.productName,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.sectionTitle,
                ),
                subtitle: Text(
                  '${formatNumber(sale.quantity)} ${sale.unit.label} • ${formatCurrency(sale.unitPrice, sale.currency)}\n${JalaliDateUtils.format(sale.saleDate)}',
                  textAlign: TextAlign.right,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SaleDetailsScreen(sale: sale),
                  ),
                ),
              ),
            );
          }
          final report = purchases.items[rowIndex];
          final purchase = report.purchase;
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: const Icon(Icons.shopping_cart_outlined),
              title: Text(
                report.productName,
                textAlign: TextAlign.right,
                style: AppTextStyles.sectionTitle,
              ),
              subtitle: Text(
                '${formatNumber(purchase.quantity)} ${purchase.unit.label} • ${formatCurrency(purchase.unitCost, purchase.currency)}\n${JalaliDateUtils.format(purchase.purchaseDate)}',
                textAlign: TextAlign.right,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PurchaseDetailsScreen(purchase: purchase),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(height: 10),
      ),
    );
  }

  Widget _filterBar() => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Padding(
      padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(label: _dateLabel, icon: Icons.calendar_month),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: productName ?? 'همه محصولات',
                    icon: Icons.inventory_2_outlined,
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: currency?.label ?? 'همه ارزها',
                    icon: Icons.currency_exchange,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'فیلتر',
            onPressed: _openFilters,
            icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
          ),
        ],
      ),
    ),
  );

  Widget _summary(TransactionSummary summary) => LayoutBuilder(
    builder: (context, constraints) {
      final metrics = [
        _MetricCard(
          title: 'تعداد ${isSales ? 'فروش' : 'خرید'}',
          value: formatNumber(summary.count),
          icon: isSales ? Icons.shopping_cart : Icons.inventory_2_outlined,
          color: const Color(0xFFE5F0FF),
        ),
        _MetricCard(
          title: 'مجموع افغانی',
          value: formatNumber(summary.afnTotal),
          suffix: 'افغانی',
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFFE0F6EC),
        ),
        _MetricCard(
          title: 'مجموع دالر',
          value: formatNumber(summary.usdTotal),
          suffix: 'دالر',
          icon: Icons.attach_money,
          color: const Color(0xFFFFF1DD),
        ),
      ];
      final compact = constraints.maxWidth < 380;
      return Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: compact
              ? Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final metric in metrics)
                      SizedBox(
                        width: (constraints.maxWidth - 3 * AppSpacing.sm) / 2,
                        child: metric,
                      ),
                  ],
                )
              : Row(
                  children: [
                    for (var index = 0; index < metrics.length; index++) ...[
                      if (index > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(child: metrics[index]),
                    ],
                  ],
                ),
        ),
      );
    },
  );

  String get _dateLabel => switch (preset) {
    ReportDatePreset.today => 'امروز',
    ReportDatePreset.yesterday => 'دیروز',
    ReportDatePreset.thisWeek => 'این هفته',
    ReportDatePreset.thisMonth => 'این ماه',
    ReportDatePreset.lastMonth => 'ماه گذشته',
    ReportDatePreset.custom =>
      '${JalaliDateUtils.format(range.startDate)} تا ${JalaliDateUtils.format(range.endDate.subtract(const Duration(days: 1)))}',
  };
  void _loadMore() => isSales
      ? ref.read(salesReportProvider.notifier).loadMore()
      : ref.read(purchasesReportProvider.notifier).loadMore();

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_ReportFilterResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReportFilterSheet(
        initialRange: range,
        initialPreset: preset,
        initialCurrency: currency,
        initialProductId: productId,
        initialProductName: productName,
      ),
    );
    if (result == null) return;
    setState(() {
      productId = result.productId;
      productName = result.productName;
      currency = result.currency;
      range = result.range;
      preset = result.preset;
    });
    final filter = TransactionFilter(
      dateRange: range,
      productId: productId,
      currency: currency,
    );
    if (isSales)
      ref.read(salesReportProvider.notifier).load(filter);
    else
      ref.read(purchasesReportProvider.notifier).load(filter);
  }
}

class _ReportFilterResult {
  const _ReportFilterResult({
    required this.range,
    required this.preset,
    this.productId,
    this.productName,
    this.currency,
  });
  final DateRangeFilter range;
  final ReportDatePreset preset;
  final int? productId;
  final String? productName;
  final Currency? currency;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.infoSurface,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(label, style: AppTextStyles.label),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.suffix,
  });
  final String title, value;
  final String? suffix;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 8),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.muted,
        ),
        Text(value, style: AppTextStyles.display.copyWith(fontSize: 19)),
        if (suffix != null) Text(suffix!, style: AppTextStyles.muted),
      ],
    ),
  );
}

class _ReportFilterSheet extends StatefulWidget {
  const _ReportFilterSheet({
    required this.initialRange,
    required this.initialPreset,
    this.initialCurrency,
    this.initialProductId,
    this.initialProductName,
  });
  final DateRangeFilter initialRange;
  final ReportDatePreset initialPreset;
  final Currency? initialCurrency;
  final int? initialProductId;
  final String? initialProductName;
  @override
  State<_ReportFilterSheet> createState() => _ReportFilterSheetState();
}

class _ReportFilterSheetState extends State<_ReportFilterSheet> {
  late DateRangeFilter range;
  late ReportDatePreset preset;
  Currency? currency;
  int? productId;
  String? productName;
  @override
  void initState() {
    super.initState();
    range = widget.initialRange;
    preset = widget.initialPreset;
    currency = widget.initialCurrency;
    productId = widget.initialProductId;
    productName = widget.initialProductName;
  }

  String get _customRangeLabel {
    final end = range.endDate.subtract(const Duration(days: 1));
    return '${JalaliDateUtils.format(range.startDate)} تا ${JalaliDateUtils.format(end)}';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 12,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Wrap(
      runSpacing: 12,
      children: [
        Text('فیلتر گزارش', style: AppTextStyles.sectionTitle),
        DropdownButtonFormField<ReportDatePreset>(
          initialValue: preset,
          decoration: const InputDecoration(labelText: 'بازه زمانی'),
          items: [
            const DropdownMenuItem(
              value: ReportDatePreset.today,
              child: Text('امروز'),
            ),
            const DropdownMenuItem(
              value: ReportDatePreset.yesterday,
              child: Text('دیروز'),
            ),
            const DropdownMenuItem(
              value: ReportDatePreset.thisWeek,
              child: Text('این هفته'),
            ),
            const DropdownMenuItem(
              value: ReportDatePreset.thisMonth,
              child: Text('این ماه'),
            ),
            const DropdownMenuItem(
              value: ReportDatePreset.lastMonth,
              child: Text('ماه گذشته'),
            ),
            DropdownMenuItem(
              value: ReportDatePreset.custom,
              child: Text(
                preset == ReportDatePreset.custom
                    ? _customRangeLabel
                    : 'بازه دلخواه',
              ),
            ),
          ],
          onChanged: (value) async {
            if (value == null) return;
            if (value == ReportDatePreset.custom) {
              final picked = await _pickRange();
              if (picked != null)
                setState(() {
                  range = picked;
                  preset = value;
                });
            } else {
              setState(() {
                preset = value;
                range = DateRangeFilter.preset(value);
              });
            }
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(productName ?? 'همه محصولات'),
          trailing: const Icon(Icons.search),
          onTap: () async {
            final choice = await showDialog<_ProductChoice>(
              context: context,
              builder: (_) => const _ProductSearchDialog(),
            );
            if (choice != null)
              setState(() {
                productId = choice.id;
                productName = choice.name;
              });
          },
        ),
        DropdownButtonFormField<Currency?>(
          initialValue: currency,
          decoration: const InputDecoration(labelText: 'ارز'),
          items: const [
            DropdownMenuItem(value: null, child: Text('همه ارزها')),
            DropdownMenuItem(value: Currency.afn, child: Text('افغانی')),
            DropdownMenuItem(value: Currency.usd, child: Text('دالر')),
          ],
          onChanged: (value) => setState(() => currency = value),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  productId = null;
                  productName = null;
                  currency = null;
                  preset = ReportDatePreset.thisMonth;
                  range = DateRangeFilter.thisMonth();
                }),
                child: const Text('پاک کردن فیلترها'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                label: 'اعمال فیلتر',
                onPressed: () => Navigator.pop(
                  context,
                  _ReportFilterResult(
                    range: range,
                    preset: preset,
                    productId: productId,
                    productName: productName,
                    currency: currency,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  Future<DateRangeFilter?> _pickRange() async {
    final start = await showAfghanJalaliDatePicker(
      context,
      initialDate: Jalali.fromDateTime(range.startDate),
      firstDate: Jalali(1300, 1, 1),
      lastDate: Jalali(1500, 12, 29),
    );
    if (start == null || !mounted) return null;
    final end = await showAfghanJalaliDatePicker(
      context,
      initialDate: (() {
        final previousEnd = range.endDate.subtract(const Duration(days: 1));
        return previousEnd.isBefore(start.toDateTime())
            ? start
            : Jalali.fromDateTime(previousEnd);
      })(),
      firstDate: start,
      lastDate: Jalali(1500, 12, 29),
    );
    if (end == null) return null;
    return DateRangeFilter(
      startDate: start.toDateTime(),
      endDate: end.addDays(1).toDateTime(),
      preset: ReportDatePreset.custom,
    );
  }
}

class _ProductChoice {
  const _ProductChoice(this.id, this.name);
  final int id;
  final String name;
}

class _ProductSearchDialog extends StatefulWidget {
  const _ProductSearchDialog();
  @override
  State<_ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<_ProductSearchDialog> {
  final controller = TextEditingController();
  Timer? timer;
  Future<List<Product>> results = Future.value(const []);
  final repo = ProductRepository();
  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('انتخاب محصول'),
    content: SizedBox(
      width: 340,
      height: 420,
      child: Column(
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'جستجوی نام یا بارکد',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) {
              timer?.cancel();
              timer = Timer(
                const Duration(milliseconds: 300),
                () => setState(
                  () => results = repo
                      .getProductsPage(query: controller.text)
                      .then((page) => page.items),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: results,
              builder: (_, snapshot) => ListView.builder(
                itemCount: snapshot.data?.length ?? 0,
                itemBuilder: (_, index) {
                  final p = snapshot.data![index];
                  return ListTile(
                    title: Text(p.name),
                    onTap: () =>
                        Navigator.pop(context, _ProductChoice(p.id!, p.name)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('لغو'),
      ),
    ],
  );
}

class _InventoryReport extends ConsumerStatefulWidget {
  const _InventoryReport();
  @override
  ConsumerState<_InventoryReport> createState() => _InventoryReportState();
}

class _InventoryReportState extends ConsumerState<_InventoryReport> {
  String search = '';
  StockStatus status = StockStatus.all;
  Timer? timer;
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryReportProvider);
    final rows = state.items;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 350) {
          ref.read(inventoryReportProvider.notifier).loadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 4, bottom: 20),
        itemCount: rows.isEmpty ? 2 : rows.length + (state.loadingMore ? 2 : 1),
        itemBuilder: (_, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'جستجوی محصول یا بارکد',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        timer?.cancel();
                        timer = Timer(const Duration(milliseconds: 300), () {
                          search = value;
                          ref
                              .read(inventoryReportProvider.notifier)
                              .load(
                                InventoryFilter(search: value, status: status),
                              );
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<StockStatus>(
                    value: status,
                    items: const [
                      DropdownMenuItem(
                        value: StockStatus.all,
                        child: Text('همه'),
                      ),
                      DropdownMenuItem(
                        value: StockStatus.low,
                        child: Text('موجودی کم'),
                      ),
                      DropdownMenuItem(
                        value: StockStatus.outOfStock,
                        child: Text('ناموجود'),
                      ),
                      DropdownMenuItem(
                        value: StockStatus.inStock,
                        child: Text('دارای موجودی'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => status = value);
                        ref
                            .read(inventoryReportProvider.notifier)
                            .load(
                              InventoryFilter(search: search, status: value),
                            );
                      }
                    },
                  ),
                ],
              ),
            );
          }
          if (state.loading && rows.isEmpty) {
            return const SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (rows.isEmpty) {
            return const SizedBox(
              height: 240,
              child: EmptyState(message: 'هیچ محصولی با این فیلتر پیدا نشد.'),
            );
          }
          if (index == rows.length + 1) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final row = rows[index - 1];
          return Card(
            child: ListTile(
              title: Text(row.name, style: AppTextStyles.sectionTitle),
              subtitle: Text(
                'موجودی: ${formatNumber(row.stock)} ${row.unit}\n${row.lowStock ? 'موجودی کم • ' : ''}${row.salePrice == null ? 'قیمت تعیین نشده' : formatCurrency(row.salePrice!, row.currency)}',
              ),
              onTap: () async {
                final product = await ProductRepository().getProductById(
                  row.id,
                );
                if (!context.mounted || product == null) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailsScreen(product: product),
                  ),
                );
              },
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(height: 12),
      ),
    );
  }
}
