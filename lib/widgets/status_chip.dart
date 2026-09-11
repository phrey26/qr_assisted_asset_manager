import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// Read-only pill showing an asset's [AssetStatus].
///
/// Status isn't hand-picked anywhere any more — it's driven entirely by the
/// borrow / return / "Move to backup" / "Move to active" flows — so this is
/// always just a label.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final AssetStatus status;

  /// Background/foreground tint pair for [status], shared with the detail
  /// row on [AssetDetailScreen] so a status reads with the same color
  /// there as it does on this chip.
  static (Color background, Color foreground) colorsFor(AssetStatus status) {
    switch (status) {
      case AssetStatus.available:
        return (AppTheme.mint, AppTheme.primary);
      case AssetStatus.inUse:
        return (AppTheme.cream, const Color(0xFF9A6512));
      case AssetStatus.maintenance:
        return (AppTheme.redTint, const Color(0xFFC84040));
      case AssetStatus.inStock:
        return (AppTheme.slateTint, AppTheme.muted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = colorsFor(status);
    final scale = Responsive.uiScale(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 9 * scale),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: 14 * scale,
        ),
      ),
    );
  }
}
