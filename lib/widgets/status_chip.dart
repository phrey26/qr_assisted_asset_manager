import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// Displays an asset's status as a pill. When [onChanged] is provided, the
/// pill becomes tappable and opens a menu to change the status (e.g. flag
/// an asset as under maintenance); when null (the default), it's a
/// read-only label, unchanged from how every non-admin screen uses it.
///
/// The picker itself is responsive: desktop keeps the compact
/// [PopupMenuButton] (a dropdown anchored to the pill suits a mouse), while
/// mobile opens a themed bottom sheet instead — a stock [PopupMenuButton]
/// renders as a small floating card that can land anywhere on a phone
/// screen and doesn't pick up any of the app's rounded/color language,
/// which is what made it feel out of place on the inventory list.
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
    final scale = Responsive.uiScale(context);
    final pill = Container(
      padding: EdgeInsets.only(
        left: 16 * scale,
        right: (onChanged == null ? 16 : 8) * scale,
        top: 9 * scale,
        bottom: 9 * scale,
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
              fontSize: 14 * scale,
            ),
          ),
          if (onChanged != null) ...[
            SizedBox(width: 2 * scale),
            Icon(Icons.arrow_drop_down, color: foreground, size: 20 * scale),
          ],
        ],
      ),
    );

    if (onChanged == null) return pill;

    if (Responsive.isDesktop(context)) {
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

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => _openStatusSheet(context),
      child: pill,
    );
  }

  Future<void> _openStatusSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<AssetStatus>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _StatusSheet(status: status),
    );
    if (selected != null) onChanged!(selected);
  }
}

/// Mobile status picker, styled to match the rest of the app (rounded
/// card, [AppTheme] palette, generous touch targets) instead of the
/// default Material popup menu.
class _StatusSheet extends StatelessWidget {
  const _StatusSheet({required this.status});

  final AssetStatus status;

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Change status',
                  style: TextStyle(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 18 * scale,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                children: [
                  for (final option in AssetStatus.values)
                    _StatusOption(
                      option: option,
                      selected: option == status,
                      onTap: () => Navigator.pop(context, option),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AssetStatus option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = StatusChip._colorsFor(option);
    final scale = Responsive.uiScale(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 14 * scale),
          margin: EdgeInsets.symmetric(vertical: 3 * scale),
          decoration: BoxDecoration(
            color: selected ? background : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 12 * scale,
                height: 12 * scale,
                decoration: BoxDecoration(color: foreground, shape: BoxShape.circle),
              ),
              SizedBox(width: 14 * scale),
              Expanded(
                child: Text(
                  option.label,
                  style: TextStyle(
                    color: AppTheme.darkGreen,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 16 * scale,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: AppTheme.primary, size: 20 * scale),
            ],
          ),
        ),
      ),
    );
  }
}