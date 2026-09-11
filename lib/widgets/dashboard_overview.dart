import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// The Home tab's overview: at-a-glance inventory/request stats, plus an
/// "attention needed" list for anything that wants a look (overdue loans,
/// assets past their expected lifespan, damaged returns, low bulk stock).
/// Sits above the existing category grid on [CategoriesScreen] — see
/// `lib/screens/categories_screen.dart` — so the Home tab is an actual
/// dashboard rather than just a category browser.
///
/// Pure presentation: every inventory number is derived from [assets]
/// (owned by `AppShell`, the same list the Inventory tab renders).
/// [pendingRequestsCount] / [overdueRequestsCount] can't be derived the
/// same way — `AppShell` doesn't load requests itself, `RequestsScreen`
/// does — so those two are handed down already computed; see the
/// `onCountsChanged` wiring between `RequestsScreen` and `AppShell` in
/// `lib/main.dart`. No data is fetched here.
class DashboardOverview extends StatelessWidget {
  const DashboardOverview({
    super.key,
    required this.assets,
    required this.pendingRequestsCount,
    required this.overdueRequestsCount,
    this.onOpenInventory,
    this.onOpenRequests,
  });

  final List<AssetItem> assets;

  /// Requests awaiting a CSDO decision, and checked-out loans past their
  /// return date — mirrors [RequestsScreenState.pendingCount] /
  /// [RequestsScreenState.overdueCount] in requests_screen.dart.
  final int pendingRequestsCount;
  final int overdueRequestsCount;

  /// Switches to the Inventory tab. Wired up by [AppShell] the same way as
  /// [CategoriesScreen.onCategoryTap]. When null, the stat tiles and
  /// attention rows that would use it are shown but aren't tappable.
  final VoidCallback? onOpenInventory;

  /// Switches to the Requests tab with the given filter chip already
  /// selected — 'Pending' or 'Overdue' — via
  /// [RequestsScreenState.setFilter]. When null, the tiles that would use
  /// it are shown but aren't tappable.
  final void Function(String filter)? onOpenRequests;

  // ---- derived counts, all from `assets` (no extra fetch) ----

  List<AssetItem> get _active => assets.where((a) => a.isActiveInventory).toList();

  List<AssetItem> get _individualActive => _active.where((a) => !a.isBulk).toList();

  int get _availableCount =>
      _individualActive.where((a) => a.status == AssetStatus.available).length;

  int get _inUseCount =>
      _individualActive.where((a) => a.status == AssetStatus.inUse).length;

  /// Off the active, borrowable pool — Maintenance + In stock — the same
  /// set [InventoryScreenState._stockCount] shows on the "Stock items"
  /// button.
  int get _offActiveCount => assets.length - _active.length;

  /// In-use ÷ (available + in-use) for individually tracked assets. Bulk
  /// pools carry a quantity, not a status, so they're excluded rather than
  /// skewing this toward 0%. Null when there's nothing to measure yet.
  double? get _utilization {
    final total = _availableCount + _inUseCount;
    if (total == 0) return null;
    return _inUseCount / total;
  }

  int get _pastLifespanCount => assets.where((a) => a.isPastLifespan).length;

  int get _damagedCount => assets.where((a) => a.isDamaged).length;

  int get _lowStockCount => assets.where((a) => a.isLowStock).length;

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);
    final utilization = _utilization;

    final tiles = <_StatTileData>[
      _StatTileData(
        icon: Icons.inventory_2_outlined,
        background: AppTheme.mint,
        foreground: AppTheme.primary,
        value: '${_active.length}',
        label: 'Total assets',
        onTap: onOpenInventory,
      ),
      _StatTileData(
        icon: Icons.check_circle_outline,
        background: AppTheme.mint,
        foreground: AppTheme.primary,
        value: '$_availableCount',
        label: 'Available',
        onTap: onOpenInventory,
      ),
      _StatTileData(
        icon: Icons.swap_horiz,
        background: AppTheme.cream,
        foreground: const Color(0xFF9A6512),
        value: '$_inUseCount',
        label: 'In use',
        onTap: onOpenInventory,
      ),
      _StatTileData(
        icon: Icons.percent,
        background: AppTheme.cream,
        foreground: const Color(0xFF9A6512),
        value: utilization == null ? '—' : '${(utilization * 100).round()}%',
        label: 'Utilization',
        onTap: onOpenInventory,
      ),
      _StatTileData(
        icon: Icons.archive_outlined,
        background: AppTheme.slateTint,
        foreground: AppTheme.muted,
        value: '$_offActiveCount',
        label: 'Stock / maintenance',
        onTap: onOpenInventory,
      ),
      _StatTileData(
        icon: Icons.assignment_outlined,
        background: AppTheme.cream,
        foreground: const Color(0xFF9A6512),
        value: '$pendingRequestsCount',
        label: 'Pending requests',
        onTap: onOpenRequests == null ? null : () => onOpenRequests!('Pending'),
      ),
    ];

    final attentionRows = <_AttentionRowData>[
      if (overdueRequestsCount > 0)
        _AttentionRowData(
          icon: Icons.alarm_outlined,
          label: 'Overdue ${overdueRequestsCount == 1 ? 'loan' : 'loans'}',
          count: overdueRequestsCount,
          onTap: onOpenRequests == null ? null : () => onOpenRequests!('Overdue'),
        ),
      if (_pastLifespanCount > 0)
        _AttentionRowData(
          icon: Icons.warning_amber_rounded,
          label: '${_pastLifespanCount == 1 ? 'Asset' : 'Assets'} past expected lifespan',
          count: _pastLifespanCount,
          onTap: onOpenInventory,
        ),
      if (_damagedCount > 0)
        _AttentionRowData(
          icon: Icons.build_circle_outlined,
          label: '${_damagedCount == 1 ? 'Asset' : 'Assets'} returned damaged',
          count: _damagedCount,
          onTap: onOpenInventory,
        ),
      if (_lowStockCount > 0)
        _AttentionRowData(
          icon: Icons.inventory_2_outlined,
          label: 'Bulk ${_lowStockCount == 1 ? 'item' : 'items'} low on stock',
          count: _lowStockCount,
          onTap: onOpenInventory,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Overview'),
        SizedBox(height: 14 * scale),
        _StatTileGrid(tiles: tiles),
        SizedBox(height: 30 * scale),
        _SectionLabel('Needs attention'),
        SizedBox(height: 14 * scale),
        if (attentionRows.isEmpty)
          _AllClearBanner(scale: scale)
        else
          Column(
            children: [
              for (var i = 0; i < attentionRows.length; i++) ...[
                if (i > 0) SizedBox(height: 12 * scale),
                _AttentionRow(data: attentionRows[i]),
              ],
            ],
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.fontScale(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 19 * scale,
        fontWeight: FontWeight.w800,
        color: AppTheme.darkGreen,
      ),
    );
  }
}

/// Lays the stat tiles out itself (rather than handing that to
/// [GridView]) so each tile's height is whatever its own content needs
/// instead of a height forced from a fixed aspect ratio. A grid delegate
/// has to commit to a cell height before it knows how tall the content
/// actually renders — on desktop/web that content came in a few pixels
/// taller than the aspect ratio allowed for, which is what was clipping
/// the tiles ("BOTTOM OVERFLOWED"). [Wrap] sizes each child naturally
/// instead, so that can't happen at any width, font, or platform.
///
/// Column count is 2 up to the tablet breakpoint and 3 from there on —
/// two tidy rows of 3 for these 6 tiles on tablet/desktop, two rows of 3
/// (well, 3 rows of 2) on a phone — computed continuously off the actual
/// available width via [LayoutBuilder] rather than the device's overall
/// window size, so this also reflows correctly for a resized desktop
/// window, not just a handful of fixed device sizes.
class _StatTileGrid extends StatelessWidget {
  const _StatTileGrid({required this.tiles});

  final List<_StatTileData> tiles;

  static const _spacing = 16.0;

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.isMobile(context) ? 2 : 3;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = ((constraints.maxWidth - _spacing * (columns - 1)) / columns)
            .clamp(80.0, double.infinity);
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final tile in tiles)
              SizedBox(width: width, child: _StatTile(data: tile)),
          ],
        );
      },
    );
  }
}

class _StatTileData {
  const _StatTileData({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.value,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String value;
  final String label;
  final VoidCallback? onTap;
}

/// One "Overview" stat card — an icon chip, a big number, and a label.
/// Mirrors the visual language of the category cards this sits above:
/// same border/radius treatment, same `AppTheme` tokens. Sized entirely by
/// its own content (see [_StatTileGrid]) — never forced into a fixed
/// height — so it can't overflow regardless of font metrics or width.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.data});

  final _StatTileData data;

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 2),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: data.onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 18 * scale),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42 * scale,
                  height: 42 * scale,
                  decoration: BoxDecoration(
                    color: data.background,
                    borderRadius: BorderRadius.circular(12 * scale),
                  ),
                  child: Icon(data.icon, size: 22 * scale, color: data.foreground),
                ),
                SizedBox(height: 16 * scale),
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 30 * scale,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkGreen,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14 * scale, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttentionRowData {
  const _AttentionRowData({
    required this.icon,
    required this.label,
    required this.count,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback? onTap;
}

/// One row in the "Needs attention" list — a red-tinted icon (the same
/// treatment [LifespanWarningBadge] and its siblings use), the condition,
/// and a count. Only rendered for conditions that actually have a count
/// above zero — see [DashboardOverview.build].
class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.data});

  final _AttentionRowData data;

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border, width: 2),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: data.onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18 * scale, vertical: 16 * scale),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10 * scale),
                  decoration: const BoxDecoration(color: AppTheme.redTint, shape: BoxShape.circle),
                  child: Icon(data.icon, size: 20 * scale, color: const Color(0xFFC84040)),
                ),
                SizedBox(width: 14 * scale),
                Expanded(
                  child: Text(
                    data.label,
                    style: TextStyle(
                      fontSize: 15 * scale,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                ),
                Text(
                  '${data.count}',
                  style: TextStyle(
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFC84040),
                  ),
                ),
                if (data.onTap != null) ...[
                  SizedBox(width: 6 * scale),
                  Icon(Icons.chevron_right, size: 22 * scale, color: AppTheme.muted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown in place of the "Needs attention" list when nothing currently
/// needs one — overdue loans, past-lifespan assets, damaged returns and
/// low bulk stock are all at zero.
class _AllClearBanner extends StatelessWidget {
  const _AllClearBanner({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 18 * scale, vertical: 16 * scale),
      decoration: BoxDecoration(
        color: AppTheme.mint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 22 * scale),
          SizedBox(width: 14 * scale),
          Expanded(
            child: Text(
              'Nothing needs attention right now.',
              style: TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w700,
                fontSize: 15 * scale,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
