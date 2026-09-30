import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/backup/backup_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../products/providers/product_price_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../purchases/providers/purchase_provider.dart';
import '../../reports/providers/report_providers.dart';
import '../../sales/providers/sale_provider.dart';
import '../providers/backup_provider.dart';

class DataManagementScreen extends ConsumerStatefulWidget {
  const DataManagementScreen({super.key});
  @override
  ConsumerState<DataManagementScreen> createState() =>
      _DataManagementScreenState();
}

class _DataManagementScreenState extends ConsumerState<DataManagementScreen> {
  bool busy = false;
  String? message;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'مدیریت داده‌ها',
    body: ListView(
      children: [
        const Text('پاک‌سازی پایگاه داده'),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'برای جلوگیری از حذف ناخواسته، قبل از پاک‌سازی نسخه پشتیبان بگیرید.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: busy ? 'در حال پاک‌سازی...' : 'پاک‌سازی همه اطلاعات',
          icon: Icons.delete_sweep_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: busy ? null : _clear,
        ),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(message!, style: const TextStyle(color: Colors.green)),
        ],
      ],
    ),
  );

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('پاک‌سازی اطلاعات'),
        content: const Text(
          'همه محصولات، خریدها، فروش‌ها و تاریخچه قیمت حذف می‌شوند. ادامه می‌دهید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف همه'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await ref.read(backupServiceProvider).clearData();
      _invalidateData();
      if (mounted) setState(() => message = 'همه اطلاعات با موفقیت پاک شد.');
    } on BackupException catch (e) {
      if (mounted) setState(() => message = e.userMessage);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _invalidateData() {
    // Refresh every data source that can be visible on another page. This
    // also resets paginated controllers and report summaries, not just the
    // dashboard counters.
    ref.invalidate(dashboardProvider);
    ref.invalidate(lowStockItemsProvider);
    ref.invalidate(productControllerProvider);
    ref.invalidate(productPriceHistoryProvider);
    ref.invalidate(productPriceHistoryAllProvider);
    ref.invalidate(purchaseControllerProvider);
    ref.invalidate(productPurchasesProvider);
    ref.invalidate(saleControllerProvider);
    ref.invalidate(productSalesProvider);
    ref.invalidate(salesReportProvider);
    ref.invalidate(purchasesReportProvider);
    ref.invalidate(inventoryReportProvider);
  }
}
