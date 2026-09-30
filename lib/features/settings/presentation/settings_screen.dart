import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/backup/backup_service.dart';
import '../../../core/utils/jalali_date_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../products/providers/product_price_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../purchases/providers/purchase_provider.dart';
import '../../reports/providers/report_providers.dart';
import '../../sales/providers/sale_provider.dart';
import '../providers/backup_provider.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});
  @override
  ConsumerState<BackupScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<BackupScreen> {
  BackupFile? backup;
  bool busy = false;
  String? message;
  String? error;

  @override
  Widget build(BuildContext context) {
    final last = ref.watch(lastBackupProvider).valueOrNull;
    return AppScaffold(
      title: 'تنظیمات',
      body: ListView(
        children: [
          const Text('پشتیبان‌گیری و بازیابی', style: AppTextStyles.pageTitle),
          const SizedBox(height: AppSpacing.sm),
          Text(
            last == null
                ? 'هنوز نسخه پشتیبان ایجاد نشده است.'
                : 'آخرین نسخه پشتیبان: ${JalaliDateUtils.format(last.createdAt)}، ${last.createdAt.hour.toString().padLeft(2, '0')}:${last.createdAt.minute.toString().padLeft(2, '0')}',
            style: AppTextStyles.muted,
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: busy ? 'در حال پردازش...' : 'ایجاد نسخه پشتیبان',
                      icon: Icons.backup_outlined,
                      onPressed: busy ? null : _createBackup,
                    ),
                  ),
                  if (backup != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'نسخه پشتیبان با موفقیت ایجاد شد.',
                      style: const TextStyle(color: Colors.green),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            label: 'اشتراک‌گذاری',
                            icon: Icons.share_outlined,
                            variant: AppButtonVariant.secondary,
                            onPressed: _share,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            label: 'ذخیره فایل',
                            icon: Icons.save_alt_outlined,
                            variant: AppButtonVariant.secondary,
                            onPressed: _saveFile,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'بازیابی نسخه پشتیبان',
                  icon: Icons.restore_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: busy ? null : _restore,
                ),
              ),
            ),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: Text(
                message!,
                style: const TextStyle(color: Colors.green),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    setState(() {
      busy = true;
      message = null;
      error = null;
    });
    try {
      final result = await ref.read(backupServiceProvider).createBackup();
      if (mounted) {
        setState(() {
          backup = result;
          message = 'نسخه پشتیبان با موفقیت ایجاد شد.';
        });
      }
      ref.invalidate(lastBackupProvider);
    } catch (_) {
      if (mounted) setState(() => error = 'ایجاد نسخه پشتیبان موفق نشد.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _share() async {
    final value = backup;
    if (value == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(value.file.path)],
          text: 'نسخه پشتیبان مدیریت موجودی',
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => error = 'اشتراک‌گذاری نسخه پشتیبان موفق نشد.');
      }
    }
  }

  Future<void> _saveFile() async {
    final value = backup;
    if (value == null) return;
    try {
      await FilePicker.platform.saveFile(
        dialogTitle: 'ذخیره نسخه پشتیبان',
        fileName: value.filename,
        type: FileType.custom,
        allowedExtensions: ['db'],
        bytes: await value.file.readAsBytes(),
      );
    } catch (_) {
      if (mounted) setState(() => error = 'ذخیره فایل موفق نشد.');
    }
  }

  Future<void> _restore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db', 'inventorybackup'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    setState(() {
      busy = true;
      message = null;
      error = null;
    });
    try {
      await ref.read(backupServiceProvider).validateBackup(file);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('بازیابی نسخه پشتیبان'),
          content: const Text(
            'با بازیابی این فایل، اطلاعات فعلی برنامه جایگزین خواهد شد.\n\nاین عملیات قابل برگشت نیست مگر اینکه از اطلاعات فعلی نسخه پشتیبان داشته باشید.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لغو'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('بازیابی'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await ref.read(backupServiceProvider).restoreBackup(file);
      _invalidateData();
      if (mounted) {
        setState(() => message = 'بازیابی نسخه پشتیبان با موفقیت انجام شد.');
      }
    } on BackupException catch (exception) {
      if (mounted) setState(() => error = exception.userMessage);
    } catch (_) {
      if (mounted) setState(() => error = 'بازیابی نسخه پشتیبان موفق نشد.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _invalidateData() {
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
    ref.invalidate(lastBackupProvider);
  }
}
