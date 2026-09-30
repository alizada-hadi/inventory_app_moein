import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.leading,
    this.actions,
  });
  final String title;
  final Widget body;
  final Widget? leading;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, style: AppTextStyles.pageTitle),
      leading:
          leading ??
          (GoRouter.of(context).canPop() ? const BackButton() : null),
      actions: actions,
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          0,
        ),
        child: body,
      ),
    ),
  );
}
