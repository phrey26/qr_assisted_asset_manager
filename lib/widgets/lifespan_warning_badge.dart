import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// Small pill warning shown wherever an asset is displayed past the
/// expected lifespan set on its category. Shared by the inventory card, the
/// desktop table, and the asset detail page so the warning looks the same
/// everywhere it appears.
class LifespanWarningBadge extends StatelessWidget {
  const LifespanWarningBadge({super.key, this.compact = false, this.years});

  /// When true, renders as a smaller icon-only badge suited to tight
  /// spaces like a data table cell.
  final bool compact;

  /// The category's expected lifespan in years, shown in the tooltip. Null
  /// falls back to a number-less message.
  final int? years;

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);

    if (compact) {
      return Tooltip(
        message: years == null
            ? 'Past its expected lifespan'
            : 'Past its $years-year expected lifespan',
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

/// Twin of [LifespanWarningBadge] for an asset whose most recent return
/// inspection marked it **damaged** — shown in the same places (inventory
/// card, desktop table, asset detail) so "this needs looking at" reads the
/// same whether the cause is age or wear.
class DamagedWarningBadge extends StatelessWidget {
  const DamagedWarningBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);

    if (compact) {
      return Tooltip(
        message: 'Last returned damaged — needs inspection',
        child: Container(
          padding: EdgeInsets.all(6 * scale),
          decoration: const BoxDecoration(
            color: AppTheme.redTint,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.build_circle_outlined, color: const Color(0xFFC84040), size: 16 * scale),
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
          Icon(Icons.build_circle_outlined, color: const Color(0xFFC84040), size: 14 * scale),
          SizedBox(width: 5 * scale),
          Text(
            'Damaged',
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

/// Twin of [LifespanWarningBadge] for an asset whose active loan is past
/// its return date — shown in the same places so "this needs chasing"
/// reads the same wherever the asset appears.
class OverdueLoanBadge extends StatelessWidget {
  const OverdueLoanBadge({super.key, this.compact = false, this.days});

  final bool compact;

  /// Days overdue, shown on the full badge ("Overdue · 4d") and in the
  /// compact tooltip. Null falls back to a plain "Overdue".
  final int? days;

  String get _label => days == null || days! <= 0 ? 'Overdue' : 'Overdue · ${days}d';

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);

    if (compact) {
      return Tooltip(
        message: days == null || days! <= 0
            ? 'Loan is past its return date'
            : 'Loan is $days day${days == 1 ? '' : 's'} overdue',
        child: Container(
          padding: EdgeInsets.all(6 * scale),
          decoration: const BoxDecoration(color: AppTheme.redTint, shape: BoxShape.circle),
          child: Icon(Icons.alarm_outlined, color: const Color(0xFFC84040), size: 16 * scale),
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
          Icon(Icons.alarm_outlined, color: const Color(0xFFC84040), size: 14 * scale),
          SizedBox(width: 5 * scale),
          Text(
            _label,
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

/// Twin of [LifespanWarningBadge] for a **bulk** asset whose available
/// stock has fallen to or below its reorder point — shown in the same
/// places so "this needs restocking" reads consistently.
class LowStockBadge extends StatelessWidget {
  const LowStockBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);

    if (compact) {
      return Tooltip(
        message: 'Low stock — at or below the reorder point',
        child: Container(
          padding: EdgeInsets.all(6 * scale),
          decoration: const BoxDecoration(
            color: AppTheme.redTint,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.inventory_2_outlined, color: const Color(0xFFC84040), size: 16 * scale),
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
          Icon(Icons.inventory_2_outlined, color: const Color(0xFFC84040), size: 14 * scale),
          SizedBox(width: 5 * scale),
          Text(
            'Low stock',
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