import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/jalali_date_utils.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/dashboard_repository.dart';
import '../providers/dashboard_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) => SafeArea(child: _dashboard(context));

  Widget _dashboard(BuildContext context) {
    final asyncSummary = ref.watch(dashboardProvider);
    final summary = asyncSummary.valueOrNull;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
        await ref.read(dashboardProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            const SizedBox(height: AppSpacing.lg),
            if (asyncSummary.isLoading && summary == null)
              const LinearProgressIndicator(minHeight: 2),
            if (summary != null) ...[
              _summaryCards(summary),
              if (summary.latestFinancialNet != null) ...[
                const SizedBox(height: AppSpacing.md),
                _financialCard(context, summary),
              ],
              const SizedBox(height: AppSpacing.xl),
              _sectionHeader('دسترسی سریع'),
              const SizedBox(height: AppSpacing.md),
              _quickActions(context),
              const SizedBox(height: AppSpacing.xl),
              _sectionHeader('آخرین فعالیت‌ها'),
              const SizedBox(height: AppSpacing.md),
              _recentActivities(summary),
            ],
            if (asyncSummary.hasError && summary == null)
              _errorCard(() => ref.invalidate(dashboardProvider)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Row(
      children: [
        const CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.infoSurface,
          child: Icon(Icons.person, color: AppColors.primary, size: 30),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سلام',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: AppTextStyles.pageTitle.copyWith(fontSize: 18),
              ),
              Text(
                'به سیستم Bromand خوش آمدید',
                softWrap: true,
                textAlign: TextAlign.right,
                style: AppTextStyles.muted.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
        // const Spacer(),
        _notificationButton(context),
        const SizedBox(width: AppSpacing.sm),
        _roundHeaderButton(
          icon: Icons.menu,
          onTap: () => context.push('/settings'),
        ),
      ],
    ),
  );

  Widget _notificationButton(BuildContext context) {
    final count = ref.watch(dashboardProvider).valueOrNull?.lowStockCount ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _roundHeaderButton(
          icon: Icons.notifications_none_rounded,
          onTap: () => context.push('/notifications'),
        ),
        if (count > 0)
          PositionedDirectional(
            top: -4,
            end: -4,
            child: SizedBox(
              width: 20,
              height: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 9 ? '۹+' : formatNumber(count),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _roundHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
  }) => Material(
    color: AppColors.surface,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(icon, color: AppColors.text, size: 25),
      ),
    ),
  );

  Widget _summaryCards(DashboardSummary summary) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 500;
      final cards = [
        _SummaryCard(
          title: 'کل محصولات',
          value: formatNumber(summary.productCount),
          icon: Icons.inventory_2_outlined,
          color: const Color(0xFFE0F6EC),
          iconColor: AppColors.success,
        ),
        _SummaryCard(
          title: 'فروش امروز',
          value: formatNumber(summary.salesToday),
          detail: _amounts(summary.salesTodayAfn, summary.salesTodayUsd),
          icon: Icons.shopping_cart_outlined,
          color: const Color(0xFFE5F0FF),
          iconColor: AppColors.primary,
        ),
        _SummaryCard(
          title: 'خرید امروز',
          value: formatNumber(summary.purchasesToday),
          detail: _amounts(
            summary.purchasesTodayAfn,
            summary.purchasesTodayUsd,
          ),
          icon: Icons.download_outlined,
          color: const Color(0xFFFFF1DD),
          iconColor: const Color(0xFFE58A00),
        ),
        _SummaryCard(
          title: 'اقلام کم موجودی',
          value: formatNumber(summary.lowStockCount),
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFFFE7E7),
          iconColor: AppColors.error,
        ),
      ];
      return GridView.count(
        crossAxisCount: compact ? 2 : 4,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: compact ? 1.45 : 0.72,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: cards,
      );
    },
  );

  Widget _financialCard(BuildContext context, DashboardSummary summary) => Card(
    child: ListTile(
      leading: const Icon(Icons.account_balance_outlined),
      title: const Text('آخرین گزارش مالی'),
      subtitle: Text(
        'خالص دارایی: ${formatCurrency(summary.latestFinancialNet!, summary.latestFinancialCurrency!)}\nتاریخ: ${JalaliDateUtils.format(summary.latestFinancialDate!)}',
      ),
      trailing: summary.latestFinancialChange == null
          ? null
          : Text(
              '${summary.latestFinancialChange! >= 0 ? '+' : ''}${formatCurrency(summary.latestFinancialChange!, summary.latestFinancialCurrency!)}',
            ),
      onTap: () => context.push('/financial-reports'),
    ),
  );

  String? _amounts(num afn, num usd) {
    final values = <String>[];
    if (afn > 0) values.add(formatCurrency(afn, Currency.afn));
    if (usd > 0) values.add(formatCurrency(usd, Currency.usd));
    return values.isEmpty ? null : values.join('\n');
  }

  Widget _quickActions(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          _ActionTile(
            label: 'خرید',
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFFFFF1DD),
            onTap: () => context.push('/purchase-form'),
          ),
          _ActionTile(
            label: 'فروش',
            icon: Icons.shopping_cart_outlined,
            color: const Color(0xFFE5F0FF),
            onTap: () => context.push('/sale-form'),
          ),
          _ActionTile(
            label: 'موجودی',
            icon: Icons.inventory_outlined,
            color: const Color(0xFFE7F8F0),
            onTap: () => context.push('/products'),
          ),
          _ActionTile(
            label: 'گزارش‌ها',
            icon: Icons.bar_chart_rounded,
            color: const Color(0xFFF3E9FF),
            onTap: () => context.push('/reports'),
          ),
        ],
      ),
    ),
  );

  Widget _sectionHeader(String title, {VoidCallback? onTap}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: AppTextStyles.sectionTitle),
      if (onTap != null)
        TextButton(onPressed: onTap, child: const Text('مشاهده همه')),
    ],
  );

  Widget _recentActivities(DashboardSummary summary) {
    if (summary.activities.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: EmptyState(message: 'هنوز فعالیتی ثبت نشده است'),
      );
    }
    return Card(
      child: Column(
        children: summary.activities.take(5).map(_activityTile).toList(),
      ),
    );
  }

  Widget _activityTile(ActivityItem item) {
    final isPurchase = item.type == 'purchase';
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: isPurchase
            ? const Color(0xFFFFF1DD)
            : const Color(0xFFE5F0FF),
        child: Icon(
          isPurchase ? Icons.inventory_2_outlined : Icons.shopping_cart,
          color: isPurchase ? const Color(0xFFE58A00) : AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        isPurchase
            ? 'خرید • ${item.productName}'
            : 'فروش • ${item.productName}',
      ),
      subtitle: Text(
        '${formatNumber(item.amount)} • ${JalaliDateUtils.format(DateTime.parse(item.date))}',
      ),
    );
  }

  Widget _errorCard(VoidCallback onRetry) => Card(
    child: ListTile(
      leading: const Icon(Icons.error_outline, color: AppColors.error),
      title: const Text('بارگذاری داشبورد ناموفق بود'),
      trailing: TextButton(onPressed: onRetry, child: const Text('تلاش مجدد')),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.iconColor,
    this.detail,
  });
  final String title, value;
  final String? detail;
  final IconData icon;
  final Color color, iconColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 26),
        const Spacer(),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.muted.copyWith(color: AppColors.text),
        ),
        Text(value, style: AppTextStyles.display.copyWith(fontSize: 22)),
        if (detail != null)
          Text(
            detail!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.muted.copyWith(fontSize: 9),
          ),
      ],
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Column(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: color,
              child: Icon(icon, color: AppColors.primary, size: 25),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label,
            ),
          ],
        ),
      ),
    ),
  );
}
