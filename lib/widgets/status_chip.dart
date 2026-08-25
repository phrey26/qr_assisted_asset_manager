import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final AssetStatus status;

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;
    switch (status) {
      case AssetStatus.available:
        background = AppTheme.mint;
        foreground = AppTheme.primary;
      case AssetStatus.inUse:
        background = AppTheme.cream;
        foreground = const Color(0xFF9A6512);
      case AssetStatus.maintenance:
        background = AppTheme.redTint;
        foreground = const Color(0xFFC84040);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}
