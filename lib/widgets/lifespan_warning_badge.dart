import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';

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
    final scale = Responsive.uiScale(context);

    if (compact) {
      return Tooltip(
        message: 'Past its 5-year expected lifespan',
        child: Container(
          padding: EdgeInsets.all(6 * scale),
          decoration: const BoxDecoration(
            color: AppTheme.redTint,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.warning_amber_rounded, color: const Color(0xFFC84040), size: 16 * scale),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 5 * scale),
      decoration: BoxDecoration(
        color: AppTheme.redTint,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: const Color(0xFFC84040), size: 14 * scale),
          SizedBox(width: 5 * scale),
          Text(
            'Past lifespan',
            style: TextStyle(
              color: const Color(0xFFC84040),
              fontWeight: FontWeight.w800,
              fontSize: 12 * scale,
            ),
          ),
        ],
      ),
    );
  }
}