import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../products/providers/product_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppScaffold(
    title: 'اعلان‌ها',
    body: ref
        .watch(lowStockItemsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (items) => items.isEmpty
              ? const Center(child: Text('اعلان جدیدی وجود ندارد'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        onTap: () async {
                          final product = await ref
                              .read(productRepositoryProvider)
                              .getProductById(item.productId);
                          if (context.mounted && product != null) {
                            context.push('/purchase-form', extra: product);
                          }
                        },
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFE7E7),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.error,
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: AppTextStyles.sectionTitle,
                        ),
                        subtitle: Text(
                          'موجودی فعلی: ${formatNumber(item.amount)} ${item.unit.label}\nبرای خرید مجدد نیاز به بررسی دارد.',
                        ),
                      ),
                    );
                  },
                ),
        ),
  );
}
