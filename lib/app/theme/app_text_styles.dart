import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const pageTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const body = TextStyle(
    fontSize: 14,
    height: 1.6,
    color: AppColors.text,
  );
  static const smallBody = TextStyle(
    fontSize: 12,
    height: 1.5,
    color: AppColors.text,
  );
  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );
  static const button = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
  static const muted = TextStyle(
    fontSize: 12,
    height: 1.5,
    color: AppColors.mutedText,
  );
}
