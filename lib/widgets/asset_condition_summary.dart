import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import 'lifespan_warning_badge.dart';

/// The condition warning badges for [asset] — overdue, damaged, past
/// lifespan, low stock — the same badges already used on the Inventory
/// list and desktop table (see [LifespanWarningBadge] and its siblings).
///
/// Shown on the QR scan result (mobile page and desktop "mini window"
/// dialog — see qr_scan_result_screen.dart and qr_scanner_screen.dart) so
/// scanning an asset answers "what state is it in" without opening the box
/// to look. Before this, the scan result surfaced identity and whereabouts
/// (tag, category, location, who has it) but never any of the condition
/// signals — even though the data and the badge widgets themselves already
/// existed elsewhere in the app.
class AssetConditionSummary extends StatelessWidget {
  const AssetConditionSummary({super.key, required this.asset});

  final AssetItem asset;

  bool get _hasWarning =>
      asset.isLoanOverdue || asset.isDamaged || asset.isPastLifespan || asset.isLowStock;

  @override
  Widget build(BuildContext context) {
    if (!_hasWarning) {
      // The absence of a warning shown as a deliberate "checked, nothing
      // to flag" rather than a blank space that could just as easily mean
      // the data was never loaded.
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 18),
          SizedBox(width: 8),
          Text(
            'No issues flagged',
            style: TextStyle(
              color: AppTheme.darkGreen,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (asset.isLoanOverdue) OverdueLoanBadge(days: asset.overdueDays),
        if (asset.isDamaged) const DamagedWarningBadge(),
        if (asset.isPastLifespan) LifespanWarningBadge(years: asset.lifespanYears),
        if (asset.isLowStock) const LowStockBadge(),
      ],
    );
  }
}
