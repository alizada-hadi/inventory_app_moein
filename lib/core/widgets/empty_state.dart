import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inventory_2_outlined,
  });
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: AppColors.mutedText),
        const SizedBox(height: AppSpacing.md),
        Text(message, style: AppTextStyles.muted),
      ],
    ),
  );
}
