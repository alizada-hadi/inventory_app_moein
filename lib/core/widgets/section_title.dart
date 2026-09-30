import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) =>
      Text(title, style: AppTextStyles.sectionTitle);
}
