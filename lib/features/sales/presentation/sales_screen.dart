import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/jalali_date_utils.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../products/data/product_conversion.dart';
import '../data/sale.dart';
import '../providers/sale_provider.dart';
import 'sale_details_screen.dart';
import 'sale_form_screen.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});
  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final selected = <int>{};
  bool selecting = false;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'فروش‌ها',
    actions: [
      if (selecting)
        IconButton(onPressed: _cancel, icon: const Icon(Icons.close)),
      if (selecting)
        IconButton(
          onPressed: selected.isEmpty ? null : _bulkDelete,
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
      if (!selecting)
        IconButton(
          onPressed: () => setState(() => selecting = true),
          icon: const Icon(Icons.checklist_outlined),
        ),
      IconButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SaleFormScreen()),
        ),
        icon: const Icon(Icons.add),
      ),
    ],
    body: _body(context, ref),
  );

  void _toggle(Sale sale) {
    final id = sale.id;
    if (id == null) return;
    setState(
      () => selected.contains(id) ? selected.remove(id) : selected.add(id),
    );
  }

  void _cancel() => setState(() {
    selecting = false;
    selected.clear();
  });

  Future<void> _bulkDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف فروش‌ها'),
        content: Text(
          'آیا از حذف ${selected.length} فروش انتخاب‌شده اطمینان دارید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(saleControllerProvider.notifier).deleteSales(selected);
      _cancel();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    final state = ref.watch(saleControllerProvider);
    if (state.initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return Center(child: Text(state.error.toString()));
    }
    final sales = state.items;
    return sales.isEmpty
        ? const EmptyState(
            message: 'هیچ فروشی ثبت نشده است',
            icon: Icons.point_of_sale_outlined,
          )
        : RefreshIndicator(
            onRefresh: () =>
                ref.read(saleControllerProvider.notifier).loadSales(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 400) {
                  ref.read(saleControllerProvider.notifier).loadMore();
                }
                return false;
              },
              child: ListView.separated(
                itemCount:
                    sales.length +
                    (state.loadingMore || state.error != null ? 1 : 0),
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  if (index == sales.length) {
                    return state.loadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : TextButton(
                            onPressed: () => ref
                                .read(saleControllerProvider.notifier)
                                .loadMore(),
                            child: const Text('تلاش مجدد برای بارگذاری'),
                          );
                  }
                  final row = sales[index];
                  final sale = row.sale;
                  return _SaleCard(
                    sale: sale,
                    productName: row.productName,
                    selecting: selecting,
                    selected: selected.contains(sale.id),
                    onSelect: () => _toggle(sale),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SaleDetailsScreen(sale: sale),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({
    required this.sale,
    required this.productName,
    required this.selecting,
    required this.selected,
    required this.onSelect,
    required this.onTap,
  });
  final Sale sale;
  final String productName;
  final bool selecting, selected;
  final VoidCallback onSelect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: selecting ? onSelect : onTap,
      leading: selecting
          ? Checkbox(value: selected, onChanged: (_) => onSelect())
          : null,
      title: Text(productName, style: AppTextStyles.sectionTitle),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          '${formatNumber(sale.quantity)} ${sale.unit.label}\nهر واحد: ${formatCurrency(sale.unitPrice, sale.currency)}\nمجموع: ${formatCurrency(sale.totalAmount, sale.currency)}\n${JalaliDateUtils.format(sale.saleDate)}',
          style: AppTextStyles.muted,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}
