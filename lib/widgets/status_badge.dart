import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum BadgeTone { green, blue, orange, red }

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;

  const StatusBadge({super.key, required this.label, required this.tone});

  ({Color bg, Color fg}) get _colors {
    switch (tone) {
      case BadgeTone.green:
        return (bg: AppColors.greenBg, fg: AppColors.green);
      case BadgeTone.blue:
        return (bg: AppColors.blueBg, fg: AppColors.blue);
      case BadgeTone.orange:
        return (bg: AppColors.orangeBg, fg: AppColors.orange);
      case BadgeTone.red:
        return (bg: AppColors.redBg, fg: AppColors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c.fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
