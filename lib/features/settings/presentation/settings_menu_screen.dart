import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'تنظیمات',
    body: ListView(
      children: [
        const Text('تنظیمات برنامه', style: AppTextStyles.pageTitle),
        const SizedBox(height: AppSpacing.md),
        _item(
          context,
          icon: Icons.backup_outlined,
          title: 'پشتیبان‌گیری و بازیابی',
          subtitle: 'ذخیره، اشتراک‌گذاری یا بازیابی اطلاعات',
          route: '/backup',
        ),
        _item(
          context,
          icon: Icons.lock_outline,
          title: 'احراز هویت',
          subtitle: 'رمز عبور و ورود با اثر انگشت یا چهره',
          route: '/security',
        ),
        _item(
          context,
          icon: Icons.delete_sweep_outlined,
          title: 'مدیریت داده‌ها',
          subtitle: 'پاک‌سازی اطلاعات برنامه',
          route: '/data-management',
        ),
        _item(
          context,
          icon: Icons.account_balance_outlined,
          title: 'گزارش مالی',
          subtitle: 'ثبت و مقایسه وضعیت مالی دستی',
          route: '/financial-reports',
        ),
      ],
    ),
  );

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    child: ListTile(
      leading: Icon(icon),
      title: Text(title, style: AppTextStyles.sectionTitle),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    ),
  );
}
