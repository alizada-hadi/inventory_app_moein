import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/jalali_date_utils.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../products/data/product_conversion.dart';
import '../data/purchase.dart';
import '../providers/purchase_provider.dart';
import 'purchase_details_screen.dart';
import 'purchase_form_screen.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});
  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  final selected = <int>{};
  bool selecting = false;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'خریدها',
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
          MaterialPageRoute(builder: (_) => const PurchaseFormScreen()),
        ),
        icon: const Icon(Icons.add),
      ),
    ],
    body: _body(context, ref),
  );

  void _toggle(Purchase purchase) {
    final id = purchase.id;
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
        title: const Text('حذف خریدها'),
        content: Text(
          'آیا از حذف ${selected.length} خرید انتخاب‌شده اطمینان دارید؟',
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
      await ref
          .read(purchaseControllerProvider.notifier)
          .deletePurchases(selected);
      _cancel();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseControllerProvider);
    if (state.initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return Center(child: Text(state.error.toString()));
    }
    final purchases = state.items;
    return purchases.isEmpty
        ? const EmptyState(
            message: 'هیچ خریدی ثبت نشده است',
            icon: Icons.shopping_cart_outlined,
          )
        : RefreshIndicator(
            onRefresh: () =>
                ref.read(purchaseControllerProvider.notifier).loadPurchases(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 400) {
                  ref.read(purchaseControllerProvider.notifier).loadMore();
                }
                return false;
              },
              child: ListView.separated(
                itemCount:
                    purchases.length +
                    (state.loadingMore || state.error != null ? 1 : 0),
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  if (index == purchases.length) {
                    return state.loadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : TextButton(
                            onPressed: () => ref
                                .read(purchaseControllerProvider.notifier)
                                .loadMore(),
                            child: const Text('تلاش مجدد برای بارگذاری'),
                          );
                  }
                  final row = purchases[index];
                  final purchase = row.purchase;
                  return _PurchaseCard(
                    purchase: purchase,
                    productName: row.productName,
                    selecting: selecting,
                    selected: selected.contains(purchase.id),
                    onSelect: () => _toggle(purchase),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PurchaseDetailsScreen(
                          purchase: purchase,
                          product: null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
  }
}

class _PurchaseCard extends StatelessWidget {
  const _PurchaseCard({
    required this.purchase,
    required this.productName,
    required this.selecting,
    required this.selected,
    required this.onSelect,
    required this.onTap,
  });
  final Purchase purchase;
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
          '${formatNumber(purchase.quantity)} ${purchase.unit.label}\nهر واحد: ${formatCurrency(purchase.unitCost, purchase.currency)}\nمجموع: ${formatCurrency(purchase.totalCost, purchase.currency)}\n${JalaliDateUtils.format(purchase.purchaseDate)}',
          style: AppTextStyles.muted,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}
