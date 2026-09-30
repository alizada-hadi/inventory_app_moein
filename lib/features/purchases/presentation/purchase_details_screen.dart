import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/jalali_date_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../products/data/product.dart';
import '../../products/data/product_conversion.dart';
import '../../../core/constants/app_constants.dart';
import '../data/purchase.dart';
import '../providers/purchase_provider.dart';
import 'purchase_form_screen.dart';

class PurchaseDetailsScreen extends ConsumerWidget {
  const PurchaseDetailsScreen({
    super.key,
    required this.purchase,
    this.product,
  });
  final Purchase purchase;
  final Product? product;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppScaffold(
    title: 'جزئیات خرید',
    body: ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product?.name ?? 'محصول حذف‌شده',
                  style: AppTextStyles.pageTitle,
                ),
                const SizedBox(height: AppSpacing.xl),
                _DetailRow(
                  'مقدار',
                  '${formatNumber(purchase.quantity)} ${purchase.unit.label}',
                ),
                _DetailRow(
                  'قیمت خرید هر واحد',
                  formatCurrency(purchase.unitCost, purchase.currency),
                ),
                _DetailRow(
                  'مجموع خرید',
                  formatCurrency(purchase.totalCost, purchase.currency),
                ),
                _DetailRow('ارز', purchase.currency.label),
                _DetailRow(
                  'تاریخ خرید',
                  JalaliDateUtils.format(purchase.purchaseDate),
                ),
                if (purchase.note != null)
                  _DetailRow('یادداشت', purchase.note!),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'ویرایش',
                icon: Icons.edit_outlined,
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PurchaseFormScreen(
                      purchase: purchase,
                      initialProduct: product,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                label: 'حذف',
                icon: Icons.delete_outline,
                variant: AppButtonVariant.destructive,
                onPressed: () => _delete(context, ref),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف خرید'),
        content: const Text(
          'آیا از حذف این خرید اطمینان دارید؟ موجودی نیز کاهش می‌یابد.',
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
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(purchaseControllerProvider.notifier)
          .deletePurchase(purchase.id!);
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

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.muted),
        Flexible(child: Text(value, style: AppTextStyles.label)),
      ],
    ),
  );
}
