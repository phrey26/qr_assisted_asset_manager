import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small pill warning shown wherever an IT equipment asset is displayed
/// past its expected [AssetItem.itEquipmentLifespanYears]-year lifespan.
/// Shared by the inventory card, the desktop table, and the asset detail
/// page so the warning looks the same everywhere it appears.
class LifespanWarningBadge extends StatelessWidget {
  const LifespanWarningBadge({super.key, this.compact = false});

  /// When true, renders as a smaller icon-only badge suited to tight
  /// spaces like a data table cell.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Tooltip(
        message: 'Past its 5-year expected lifespan',
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: AppTheme.redTint,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFC84040), size: 16),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.redTint,
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFC84040), size: 14),
          SizedBox(width: 5),
          Text(
            'Past lifespan',
            style: TextStyle(
              color: Color(0xFFC84040),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}