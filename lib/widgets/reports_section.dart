import 'package:flutter/material.dart';

import '../models/report_data.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// The Home tab's "Reports" section — a handful of small charts built from
/// `reports.php`'s pre-aggregated counts (weekly request/stock trends,
/// current asset status breakdown, top borrowed assets, department demand).
///
/// Unlike [DashboardOverview] (pure presentation, fed data `AppShell`
/// already has), this section fetches its own data — the underlying counts
/// are grouped server-side from tables `AppShell` doesn't otherwise load in
/// full (weekly buckets, per-department totals) — the same
/// fetch-on-init/retry pattern as `RemovedAssetsScreen` /
/// `BulkDisposalsScreen`, just embedded inline instead of pushed as its own
/// page.
///
/// No third-party chart package is used — every bar here is plain
/// `Container`/`Expanded` sizing (the same technique [DashboardOverview]'s
/// stat-tile grid uses to guarantee it can't overflow), so nothing new is
/// added to `pubspec.yaml`.
class ReportsSection extends StatefulWidget {
  const ReportsSection({super.key});

  @override
  State<ReportsSection> createState() => _ReportsSectionState();
}

class _ReportsSectionState extends State<ReportsSection> {
  ReportsBundle? _bundle;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bundle = await ApiService.fetchReports();
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Reports',
                style: TextStyle(
                  fontSize: 19 * Responsive.fontScale(context),
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkGreen,
                ),
              ),
            ),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh reports',
              color: AppTheme.muted,
            ),
          ],
        ),
        SizedBox(height: 14 * scale),
        _body(),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border, width: 2),
        ),
        child: Column(
          children: [
            const Text(
              'Could not load reports.',
              style: TextStyle(color: AppTheme.muted, fontSize: 14),
            ),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    final bundle = _bundle!;
    if (bundle.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border, width: 2),
        ),
        child: const Text(
          'Not enough activity yet to chart.\nOnce requests and stock movements start coming in, '
          'trends will show up here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.muted, fontSize: 14, height: 1.5),
        ),
      );
    }
    return ReportsChartsView(bundle: bundle);
  }
}

/// Lays the 5 chart cards out with the same intrinsic-sizing [Wrap]
/// technique [DashboardOverview]'s stat-tile grid uses — each card is as
/// tall as its own content needs, so nothing can overflow. The two weekly
/// trend charts always take the full row width (they need the horizontal
/// room); the three breakdown/ranking cards go two-up on desktop/tablet and
/// stack one-per-row on a phone.
///
/// Public (unlike the rest of this file) so tests can pump it directly with
/// a hand-built [ReportsBundle] — [ReportsSection] itself has no seam to
/// inject one, since it always fetches from [ApiService.fetchReports].
class ReportsChartsView extends StatelessWidget {
  const ReportsChartsView({super.key, required this.bundle});

  final ReportsBundle bundle;

  static const _spacing = 16.0;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final cards = <_CardSpec>[
      _CardSpec(fullWidth: true, child: _RequestsTrendCard(rows: bundle.requestsByWeek)),
      _CardSpec(fullWidth: true, child: _StockTrendCard(rows: bundle.stockMovementSummary)),
      _CardSpec(fullWidth: false, child: _StatusBreakdownCard(entries: bundle.statusBreakdown)),
      _CardSpec(fullWidth: false, child: _TopAssetsCard(entries: bundle.topAssets)),
      _CardSpec(fullWidth: false, child: _DepartmentDemandCard(entries: bundle.departmentDemand)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final halfWidth = ((constraints.maxWidth - _spacing) / 2).clamp(200.0, double.infinity);
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final c in cards)
              SizedBox(
                width: (isMobile || c.fullWidth) ? constraints.maxWidth : halfWidth,
                child: c.child,
              ),
          ],
        );
      },
    );
  }
}

class _CardSpec {
  const _CardSpec({required this.fullWidth, required this.child});

  final bool fullWidth;
  final Widget child;
}

/// Shared card chrome — matches the white/bordered/rounded treatment
/// [DashboardOverview]'s stat tiles and the removal/disposal log tiles use.
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      padding: EdgeInsets.all(18 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15 * scale,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkGreen,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 2 * scale),
            Text(subtitle!, style: TextStyle(fontSize: 12 * scale, color: AppTheme.muted)),
          ],
          SizedBox(height: 16 * scale),
          child,
        ],
      ),
    );
  }
}

class _NoDataNote extends StatelessWidget {
  const _NoDataNote();

  @override
  Widget build(BuildContext context) =>
      const Text('No data yet.', style: TextStyle(color: AppTheme.muted, fontSize: 13));
}

// ---- status/department label + color helpers -----------------------------
//
// Covers both request statuses (pending/approved/checked_out/returned/
// rejected/withdrawn) and asset statuses (available/in_use/maintenance/
// in_stock) — the two sets don't overlap, so one map serves both charts.
// Both `requests.status` and `assets.status` are plain VARCHAR (no ENUM),
// so an unrecognized value falls back to a title-cased label and a neutral
// color instead of throwing.

String _statusLabel(String raw) {
  switch (raw) {
    case 'pending':
      return 'Pending';
    case 'approved':
      return 'Approved';
    case 'checked_out':
      return 'Checked out';
    case 'returned':
      return 'Returned';
    case 'rejected':
      return 'Rejected';
    case 'withdrawn':
      return 'Withdrawn';
    case 'available':
      return 'Available';
    case 'in_use':
      return 'In use';
    case 'maintenance':
      return 'Maintenance';
    case 'in_stock':
      return 'In stock';
    default:
      if (raw.isEmpty) return raw;
      return raw[0].toUpperCase() + raw.substring(1).replaceAll('_', ' ');
  }
}

Color _statusColor(String raw) {
  switch (raw) {
    case 'pending':
      return const Color(0xFF9A6512);
    case 'approved':
      return const Color(0xFF3C8C5E);
    case 'checked_out':
      return AppTheme.primary;
    case 'returned':
      return AppTheme.darkGreen;
    case 'rejected':
      return const Color(0xFFC84040);
    case 'withdrawn':
      return AppTheme.muted;
    case 'available':
      return const Color(0xFF3C8C5E);
    case 'in_use':
      return const Color(0xFF9A6512);
    case 'maintenance':
      return const Color(0xFFC84040);
    case 'in_stock':
      return AppTheme.muted;
    default:
      return AppTheme.primary;
  }
}

// ---- weekly stacked-bar chart (requests trend + stock trend) -------------

class _RequestsTrendCard extends StatelessWidget {
  const _RequestsTrendCard({required this.rows});

  final List<WeekCount> rows;

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Requests per week',
      subtitle: 'Last 12 weeks, by status',
      child: rows.isEmpty
          ? const _NoDataNote()
          : _WeeklyStackedChart(rows: rows, colorFor: _statusColor, labelFor: _statusLabel),
    );
  }
}

class _StockTrendCard extends StatelessWidget {
  const _StockTrendCard({required this.rows});

  final List<WeekCount> rows;

  static Color _directionColor(String d) =>
      d == 'in' ? const Color(0xFF3C8C5E) : const Color(0xFFC84040);
  static String _directionLabel(String d) => d == 'in' ? 'Received' : 'Removed';

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Stock movement',
      subtitle: 'Units received vs. removed, last 12 weeks',
      child: rows.isEmpty
          ? const _NoDataNote()
          : _WeeklyStackedChart(
              rows: rows,
              colorFor: _directionColor,
              labelFor: _directionLabel,
            ),
    );
  }
}

class _Segment {
  const _Segment({required this.value, required this.color});

  final int value;
  final Color color;
}

/// A horizontally-scrollable strip of stacked bars, one per week present in
/// [rows] (oldest to newest), each bar's height proportional to that week's
/// total against the tallest week in range, and internally split into
/// colored segments per [labelFor]/[colorFor]. Scrolls rather than
/// squeezing bars to fit a phone width — [reverse]d so the most recent week
/// is what's on screen without having to scroll.
class _WeeklyStackedChart extends StatelessWidget {
  const _WeeklyStackedChart({
    required this.rows,
    required this.colorFor,
    required this.labelFor,
  });

  final List<WeekCount> rows;
  final Color Function(String label) colorFor;
  final String Function(String label) labelFor;

  static const _barAreaHeight = 120.0;
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatWeek(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);

    final weekStarts = rows.map((r) => r.weekStart).toSet().toList()..sort();
    final labels = rows.map((r) => r.label).toSet().toList();
    final byWeek = <DateTime, Map<String, int>>{
      for (final w in weekStarts) w: {for (final l in labels) l: 0},
    };
    for (final r in rows) {
      byWeek[r.weekStart]![r.label] = r.count;
    }
    final totals = {for (final w in weekStarts) w: byWeek[w]!.values.fold<int>(0, (a, b) => a + b)};
    final maxTotal = totals.values.isEmpty
        ? 0
        : totals.values.reduce((a, b) => a > b ? a : b);
    final areaHeight = _barAreaHeight * scale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: areaHeight + 22 * scale,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final w in weekStarts) ...[
                  _WeekBar(
                    total: totals[w]!,
                    maxTotal: maxTotal,
                    areaHeight: areaHeight,
                    segments: [
                      for (final l in labels)
                        if (byWeek[w]![l]! > 0) _Segment(value: byWeek[w]![l]!, color: colorFor(l)),
                    ],
                    weekLabel: _formatWeek(w),
                  ),
                  SizedBox(width: 10 * scale),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: 10 * scale),
        Wrap(
          spacing: 14 * scale,
          runSpacing: 6 * scale,
          children: [for (final l in labels) _LegendChip(color: colorFor(l), label: labelFor(l))],
        ),
      ],
    );
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.total,
    required this.maxTotal,
    required this.areaHeight,
    required this.segments,
    required this.weekLabel,
  });

  final int total;
  final int maxTotal;
  final double areaHeight;
  final List<_Segment> segments;
  final String weekLabel;

  static const _barWidth = 26.0;

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);
    final barWidth = _barWidth * scale;
    final barHeight = maxTotal == 0 ? 0.0 : (areaHeight * (total / maxTotal)).clamp(2.0, areaHeight);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: areaHeight,
          width: barWidth,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: total == 0
                ? Container(height: 2, width: barWidth, color: const Color(0xFFE3E1D8))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: barHeight,
                      width: barWidth,
                      child: Column(
                        children: [
                          for (final s in segments)
                            Expanded(flex: s.value, child: Container(color: s.color)),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        SizedBox(height: 6 * scale),
        Text(weekLabel, style: TextStyle(fontSize: 10 * scale, color: AppTheme.muted)),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10 * scale,
          height: 10 * scale,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 6 * scale),
        Text(
          label,
          style: TextStyle(fontSize: 12 * scale, color: AppTheme.muted, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ---- horizontal ranking bars (status breakdown, top assets, department) --

class _Bar {
  const _Bar({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;
}

/// A vertical list of labeled horizontal bars, each sized against the
/// largest [value] in the list via [FractionallySizedBox] — proportional at
/// any width, never overflows.
class _BarListChart extends StatelessWidget {
  const _BarListChart({required this.bars});

  final List<_Bar> bars;

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);
    final maxValue = bars.map((b) => b.value).fold<int>(0, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (var i = 0; i < bars.length; i++) ...[
          if (i > 0) SizedBox(height: 10 * scale),
          _BarRow(
            label: bars[i].label,
            value: bars[i].value,
            fraction: maxValue == 0 ? 0 : bars[i].value / maxValue,
            color: bars[i].color,
          ),
        ],
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  final String label;
  final int value;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 96 * scale,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13 * scale, fontWeight: FontWeight.w600, color: AppTheme.darkGreen),
          ),
        ),
        SizedBox(width: 10 * scale),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 16 * scale,
              color: const Color(0xFFF0EFE9),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                child: Container(color: color),
              ),
            ),
          ),
        ),
        SizedBox(width: 8 * scale),
        SizedBox(
          width: 30 * scale,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13 * scale, fontWeight: FontWeight.w800, color: AppTheme.darkGreen),
          ),
        ),
      ],
    );
  }
}

class _StatusBreakdownCard extends StatelessWidget {
  const _StatusBreakdownCard({required this.entries});

  final List<NamedCount> entries;

  static const _order = ['available', 'in_use', 'maintenance', 'in_stock'];

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]..sort((a, b) {
      final ia = _order.indexOf(a.name);
      final ib = _order.indexOf(b.name);
      return (ia < 0 ? 999 : ia).compareTo(ib < 0 ? 999 : ib);
    });
    return _ChartCard(
      title: 'Asset status breakdown',
      child: entries.isEmpty
          ? const _NoDataNote()
          : _BarListChart(
              bars: [
                for (final e in sorted)
                  _Bar(label: _statusLabel(e.name), value: e.count, color: _statusColor(e.name)),
              ],
            ),
    );
  }
}

class _TopAssetsCard extends StatelessWidget {
  const _TopAssetsCard({required this.entries});

  final List<TopBorrowedAsset> entries;

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Top borrowed assets',
      child: entries.isEmpty
          ? const _NoDataNote()
          : _BarListChart(
              bars: [
                for (final e in entries)
                  _Bar(label: e.name, value: e.timesBorrowed, color: AppTheme.primary),
              ],
            ),
    );
  }
}

class _DepartmentDemandCard extends StatelessWidget {
  const _DepartmentDemandCard({required this.entries});

  final List<NamedCount> entries;

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Department demand',
      subtitle: 'Requests filed, all time',
      child: entries.isEmpty
          ? const _NoDataNote()
          : _BarListChart(
              bars: [
                for (final e in entries)
                  _Bar(label: e.name, value: e.count, color: const Color(0xFF9A6512)),
              ],
            ),
    );
  }
}
