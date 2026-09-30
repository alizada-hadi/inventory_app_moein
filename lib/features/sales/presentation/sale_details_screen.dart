import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/jalali_date_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../products/data/product.dart';
import '../../products/data/product_conversion.dart';
import '../data/sale.dart';
import '../providers/sale_provider.dart';
import 'sale_form_screen.dart';

class SaleDetailsScreen extends ConsumerWidget {
  const SaleDetailsScreen({super.key, required this.sale, this.product});
  final Sale sale;
  final Product? product;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppScaffold(
    title: 'جزئیات فروش',
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
                  '${formatNumber(sale.quantity)} ${sale.unit.label}',
                ),
                _DetailRow(
                  'قیمت فروش هر واحد',
                  formatCurrency(sale.unitPrice, sale.currency),
                ),
                _DetailRow(
                  'مجموع فروش',
                  formatCurrency(sale.totalAmount, sale.currency),
                ),
                _DetailRow('ارز', sale.currency.label),
                _DetailRow('تاریخ فروش', JalaliDateUtils.format(sale.saleDate)),
                if (sale.note != null) _DetailRow('یادداشت', sale.note!),
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
                    builder: (_) =>
                        SaleFormScreen(sale: sale, initialProduct: product),
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
        title: const Text('حذف فروش'),
        content: const Text(
          'آیا از حذف این فروش اطمینان دارید؟ موجودی نیز افزایش می‌یابد.',
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
      await ref.read(saleControllerProvider.notifier).deleteSale(sale.id!);
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
