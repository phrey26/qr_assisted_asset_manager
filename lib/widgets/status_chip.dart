import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';

/// Displays an asset's status as a pill. When [onChanged] is provided, the
/// pill becomes tappable and opens a menu to change the status (e.g. flag
/// an asset as under maintenance); when null (the default), it's a
/// read-only label, unchanged from how every non-admin screen uses it.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.onChanged});

  final AssetStatus status;

  /// Invoked with the newly-selected status when the admin picks a
  /// different one from the menu. Passing this makes the chip tappable.
  final ValueChanged<AssetStatus>? onChanged;

  static (Color background, Color foreground) _colorsFor(AssetStatus status) {
    switch (status) {
      case AssetStatus.available:
        return (AppTheme.mint, AppTheme.primary);
      case AssetStatus.inUse:
        return (AppTheme.cream, const Color(0xFF9A6512));
      case AssetStatus.maintenance:
        return (AppTheme.redTint, const Color(0xFFC84040));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _colorsFor(status);
    final pill = Container(
      padding: EdgeInsets.only(
        left: 16,
        right: onChanged == null ? 16 : 8,
        top: 9,
        bottom: 9,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status.label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          if (onChanged != null) ...[
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, color: foreground, size: 20),
          ],
        ],
      ),
    );

    if (onChanged == null) return pill;

    return PopupMenuButton<AssetStatus>(
      tooltip: 'Change status',
      initialValue: status,
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) => [
        for (final option in AssetStatus.values)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                if (option == status)
                  const Icon(Icons.check, size: 18, color: AppTheme.primary)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 10),
                Text(option.label),
              ],
            ),
          ),
      ],
      child: pill,
    );
  }
}