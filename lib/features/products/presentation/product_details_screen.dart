import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/jalali_date_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/section_title.dart';
import '../../purchases/presentation/purchase_form_screen.dart';
import '../../purchases/presentation/purchase_details_screen.dart';
import '../../purchases/presentation/purchases_screen.dart';
import '../../purchases/providers/purchase_provider.dart';
import '../../sales/presentation/sale_form_screen.dart';
import '../../sales/presentation/sale_details_screen.dart';
import '../../sales/presentation/sales_screen.dart';
import '../../sales/providers/sale_provider.dart';
import '../data/product.dart';
import '../data/product_conversion.dart';
import '../data/product_price_history.dart';
import '../providers/product_provider.dart';
import '../providers/product_price_provider.dart';
import 'product_form_screen.dart';
import 'product_price_screen.dart';

class ProductDetailsScreen extends ConsumerWidget {
  const ProductDetailsScreen({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayedProduct =
        ref
            .watch(productControllerProvider)
            .items
            .where((item) => item.id == product.id)
            .firstOrNull ??
        product;
    final stockText =
        '${formatNumber(displayedProduct.currentStockBase)} ${displayedProduct.unit.label}';
    final latestPurchase = ref
        .watch(productPurchasesProvider(displayedProduct.id!))
        .valueOrNull
        ?.firstOrNull;
    final latestSale = ref
        .watch(productSalesProvider(displayedProduct.id!))
        .valueOrNull
        ?.firstOrNull;
    final history =
        ref
            .watch(productPriceHistoryProvider(displayedProduct.id!))
            .valueOrNull ??
        const [];
    return AppScaffold(
      title: 'جزئیات محصول',
      actions: [
        IconButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductFormScreen(product: displayedProduct),
              ),
            );
            ref.invalidate(productControllerProvider);
          },
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          onPressed: () => _deleteProduct(context, ref, displayedProduct),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          children: [
            _productHeader(displayedProduct),
            const SizedBox(height: AppSpacing.lg),
            _stockCard(displayedProduct, stockText),
            const SizedBox(height: AppSpacing.lg),
            _priceCard(context, displayedProduct),
            const SizedBox(height: AppSpacing.xl),
            const SectionTitle('دسترسی سریع'),
            const SizedBox(height: AppSpacing.md),
            _quickActions(context, displayedProduct),
            const SizedBox(height: AppSpacing.xl),
            _transactionSection(
              context,
              title: 'آخرین خرید',
              empty: 'هنوز خریدی ثبت نشده است',
              content: latestPurchase == null
                  ? null
                  : '${formatNumber(latestPurchase.quantity)} ${latestPurchase.unit.label} × ${formatCurrency(latestPurchase.unitCost, latestPurchase.currency)}\n${JalaliDateUtils.format(latestPurchase.purchaseDate)}',
              icon: Icons.shopping_cart_outlined,
              onTap: latestPurchase == null
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PurchaseDetailsScreen(
                          purchase: latestPurchase,
                          product: displayedProduct,
                        ),
                      ),
                    ),
              onView: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PurchasesScreen()),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _transactionSection(
              context,
              title: 'آخرین فروش',
              empty: 'هنوز فروشی ثبت نشده است',
              content: latestSale == null
                  ? null
                  : '${formatNumber(latestSale.quantity)} ${latestSale.unit.label} × ${formatCurrency(latestSale.unitPrice, latestSale.currency)}\n${JalaliDateUtils.format(latestSale.saleDate)}',
              icon: Icons.point_of_sale_outlined,
              onTap: latestSale == null
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SaleDetailsScreen(
                          sale: latestSale,
                          product: displayedProduct,
                        ),
                      ),
                    ),
              onView: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SalesScreen()),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _priceHistory(context, product, history),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _productHeader(Product product) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: AppTextStyles.pageTitle),
            const SizedBox(height: AppSpacing.xs),
            Text('محصولات ${product.unit.label}', style: AppTextStyles.muted),
            if (product.barcode != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.infoSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('کد محصول: ${product.barcode}'),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(width: AppSpacing.lg),
    ],
  );

  Widget _stockCard(Product product, String stockText) {
    final low = product.currentStockBase <= product.restockLevel;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                const Text('موجودی فعلی', style: AppTextStyles.sectionTitle),
                const Spacer(),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(stockText, style: AppTextStyles.display),
            ),
            if (low) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4DC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('⚠️ موجودی به حد خرید مجدد رسیده است'),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              'حد خرید مجدد: ${formatNumber(product.restockLevel)} ${product.unit.label}',
              style: AppTextStyles.muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceCard(BuildContext context, Product product) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              const Text('قیمت فروش', style: AppTextStyles.sectionTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(product.unit.label, style: AppTextStyles.muted),
              Text(
                _salePriceForRegisteredUnit(product) == null
                    ? 'تعیین نشده'
                    : formatCurrency(
                        _salePriceForRegisteredUnit(product)!,
                        product.priceCurrency,
                      ),
                style: AppTextStyles.display.copyWith(fontSize: 24),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'تغییر قیمت',
              icon: Icons.edit_outlined,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductPriceScreen(product: product),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _quickActions(BuildContext context, Product product) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: AppButton(
              label: 'ثبت خرید',
              icon: Icons.add_shopping_cart_outlined,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PurchaseFormScreen(initialProduct: product),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AppButton(
              label: 'ثبت فروش',
              icon: Icons.point_of_sale_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SaleFormScreen(initialProduct: product),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _priceHistory(
    BuildContext context,
    Product product,
    List<ProductPriceHistory> history,
  ) => Card(
    child: ListTile(
      leading: const Icon(Icons.bar_chart_rounded, color: AppColors.primary),
      title: const Text('تاریخچه قیمت', style: AppTextStyles.sectionTitle),
      subtitle: Text(
        history.isEmpty
            ? 'هنوز تغییر قیمتی ثبت نشده است'
            : '${history.length} تغییر قیمت ثبت شده است',
        style: AppTextStyles.muted,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: history.isEmpty
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductPriceHistoryScreen(product: product),
              ),
            ),
    ),
  );

  Widget _transactionSection(
    BuildContext context, {
    required String title,
    required String empty,
    required String? content,
    required IconData icon,
    VoidCallback? onTap,
    required VoidCallback onView,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionTitle(title),
      const SizedBox(height: AppSpacing.md),
      if (content == null)
        Text(empty, style: AppTextStyles.muted)
      else
        SizedBox(
          width: double.infinity,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Icon(
                        icon,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Text(content, style: AppTextStyles.body)),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        ),
      const SizedBox(height: AppSpacing.sm),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(onPressed: onView, child: const Text('مشاهده همه')),
      ),
    ],
  );
  num? _salePriceForRegisteredUnit(Product product) => switch (product.unit) {
    InventoryUnit.carton => product.salePrice ?? product.cartonSalePrice,
    InventoryUnit.package => product.salePrice ?? product.packageSalePrice,
    InventoryUnit.pocket => product.salePrice ?? product.pocketSalePrice,
    InventoryUnit.item => product.salePrice ?? product.itemSalePrice,
  };

  Future<void> _deleteProduct(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف محصول'),
        content: const Text('آیا از حذف این محصول اطمینان دارید؟'),
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
    if (confirmed != true || !context.mounted || product.id == null) return;
    try {
      await ref
          .read(productControllerProvider.notifier)
          .deleteProduct(product.id!);
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}
