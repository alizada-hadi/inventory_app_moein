import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/product.dart';
import '../providers/product_provider.dart';
import 'product_form_screen.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});
  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final search = TextEditingController();
  final selected = <int>{};
  bool selecting = false;
  @override
  void dispose() {
    _searchDebounce?.cancel();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'محصولات',
    actions: [
      if (selecting)
        IconButton(onPressed: _cancelSelection, icon: const Icon(Icons.close)),
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
      IconButton(onPressed: () => _openForm(), icon: const Icon(Icons.add)),
    ],
    body: Column(
      children: [
        TextField(
          controller: search,
          onChanged: (value) => _onSearch(value),
          decoration: const InputDecoration(
            hintText: 'جستجوی محصول',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(child: _content()),
      ],
    ),
  );
  Widget _content() {
    final state = ref.watch(productControllerProvider);
    if (state.initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return Center(child: Text(state.error.toString()));
    }
    final products = state.items;
    return products.isEmpty
        ? const EmptyState(message: 'هیچ محصولی ثبت نشده است')
        : RefreshIndicator(
            onRefresh: () =>
                ref.read(productControllerProvider.notifier).refresh(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 400) {
                  ref.read(productControllerProvider.notifier).loadMore();
                }
                return false;
              },
              child: ListView.separated(
                itemCount:
                    products.length +
                    (state.loadingMore || state.error != null ? 1 : 0),
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, index) {
                  if (index == products.length) {
                    return state.loadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : TextButton(
                            onPressed: () => ref
                                .read(productControllerProvider.notifier)
                                .loadMore(),
                            child: const Text('تلاش مجدد برای بارگذاری'),
                          );
                  }
                  return _ProductCard(
                    product: products[index],
                    selecting: selecting,
                    selected: selected.contains(products[index].id),
                    onSelect: () => _toggle(products[index]),
                    onTap: () => context.push(
                      '/product-details',
                      extra: products[index],
                    ),
                  );
                },
              ),
            ),
          );
  }

  void _onSearch(String value) {
    // The debounce is handled by the input timer so SQLite is not queried per keystroke.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(productControllerProvider.notifier).loadProducts(value);
      }
    });
  }

  Timer? _searchDebounce;

  void _toggle(Product product) {
    final id = product.id;
    if (id == null) return;
    setState(() {
      if (!selected.add(id)) selected.remove(id);
    });
  }

  void _cancelSelection() => setState(() {
    selecting = false;
    selected.clear();
  });

  Future<void> _bulkDelete() async {
    final confirmed = await _confirmDelete(selected.length, 'محصول');
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(productControllerProvider.notifier)
          .deleteProducts(selected);
      _cancelSelection();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<bool?> _confirmDelete(int count, String type) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('حذف $type‌ها'),
      content: Text('آیا از حذف $count مورد انتخاب‌شده اطمینان دارید؟'),
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

  Future<void> _openForm([Product? product]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
    if (mounted) {
      ref.read(productControllerProvider.notifier).loadProducts(search.text);
    }
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.selecting,
    required this.selected,
    required this.onSelect,
    required this.onTap,
  });
  final Product product;
  final bool selecting, selected;
  final VoidCallback onSelect;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final stockText =
        '${formatNumber(product.currentStockBase)} ${product.unit.label}';
    final primary = product.unit.label;
    final primaryPrice =
        product.salePrice ??
        switch (product.unit) {
          InventoryUnit.carton => product.cartonSalePrice,
          InventoryUnit.package => product.packageSalePrice,
          InventoryUnit.pocket => product.pocketSalePrice,
          InventoryUnit.item => product.itemSalePrice,
        };
    final needsRestock = product.currentStockBase <= product.restockLevel;
    final costPriceText = product.costPrice == null
        ? 'تعیین نشده'
        : formatCurrency(product.costPrice!, product.priceCurrency);
    final salePriceText = primaryPrice == null
        ? 'تعیین نشده'
        : formatCurrency(primaryPrice, product.priceCurrency);
    return Card(
      child: ListTile(
        onTap: selecting ? onSelect : onTap,
        title: Text(product.name, style: AppTextStyles.sectionTitle),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'موجودی: $stockText\n${needsRestock ? '⚠️ موجودی کم است؛ لطفاً خرید مجدد کنید\n' : ''}قیمت خرید: $costPriceText\nقیمت فروش: $salePriceText / $primary',
            style: AppTextStyles.muted,
          ),
        ),
        leading: selecting
            ? Checkbox(value: selected, onChanged: (_) => onSelect())
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [if (!selecting) const Icon(Icons.chevron_right)],
        ),
      ),
    );
  }
}
