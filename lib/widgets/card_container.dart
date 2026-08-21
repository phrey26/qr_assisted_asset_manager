import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CardContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const CardContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: child,
    );
  }
}