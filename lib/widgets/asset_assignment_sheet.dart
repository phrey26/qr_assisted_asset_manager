import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../models/asset_request.dart';
import '../models/availability.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'sort_dropdown.dart';
import 'status_chip.dart';

/// Sort orders for the asset assignment picker.
enum AssetPickSort { availability, nameAsc, dateDesc, dateAsc }

extension AssetPickSortX on AssetPickSort {
  String get label {
    switch (this) {
      case AssetPickSort.availability:
        return 'Availability';
      case AssetPickSort.nameAsc:
        return 'Name (A–Z)';
      case AssetPickSort.dateDesc:
        return 'Purchase date (newest)';
      case AssetPickSort.dateAsc:
        return 'Purchase date (oldest)';
    }
  }
}

/// One line the admin chose to hand out: an [AssetItem] plus how many units
/// (always 1 for an individual asset, N for a bulk pool).
class AssetAssignment {
  const AssetAssignment({required this.asset, required this.quantity});

  final AssetItem asset;
  final int quantity;

  Map<String, dynamic> toBody() => {'tag_id': asset.tagId, 'quantity': quantity};
}

/// Lower sorts first when ordering by "availability" — free assets float to
/// the top, already-borrowed / out-of-stock ones sink.
int _availabilityRank(AssetItem asset) {
  if (asset.isBulk) return asset.quantityAvailable > 0 ? 0 : 3;
  switch (asset.status) {
    case AssetStatus.available:
      return 0;
    case AssetStatus.inStock:
      return 1;
    case AssetStatus.maintenance:
      return 2;
    case AssetStatus.inUse:
      return 3;
  }
}

/// Opens the "assign assets" picker for approving [request]. Returns the
/// lines the admin chose (each an [AssetAssignment] — asset + quantity), or
/// null if they backed out. Desktop shows a centered dialog; mobile pushes
/// a full-screen page.
///
/// Every asset is listed (individual assets with their status, bulk pools
/// with their available stock), sortable by availability, name, or purchase
/// date. Individual assets already `in_use` can't be picked unless they
/// were already on this request ([preselectedTagIds]); bulk pools with no
/// stock free can't be picked. [preselectedQuantities] pre-fills the
/// per-line count when re-opening the picker for an already-approved
/// request.
Future<List<AssetAssignment>?> showAssetAssignmentPicker(
  BuildContext context, {
  required List<AssetItem> assets,
  required AssetRequest request,
  List<String> preselectedTagIds = const [],
  Map<String, int> preselectedQuantities = const {},
  Map<String, AssetWindowAvailability>? windowAvailability,
}) {
  if (Responsive.isDesktop(context)) {
    return showDialog<List<AssetAssignment>>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
          child: _AssetAssignmentBody(
            assets: assets,
            request: request,
            preselectedTagIds: preselectedTagIds,
            preselectedQuantities: preselectedQuantities,
            windowAvailability: windowAvailability,
            inDialog: true,
          ),
        ),
      ),
    );
  }
  return Navigator.of(context).push<List<AssetAssignment>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('Assign assets', style: TextStyle(fontWeight: FontWeight.w800)),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: _AssetAssignmentBody(
            assets: assets,
            request: request,
            preselectedTagIds: preselectedTagIds,
            preselectedQuantities: preselectedQuantities,
            windowAvailability: windowAvailability,
            inDialog: false,
          ),
        ),
      ),
    ),
  );
}

class _AssetAssignmentBody extends StatefulWidget {
  const _AssetAssignmentBody({
    required this.assets,
    required this.request,
    required this.preselectedTagIds,
    required this.preselectedQuantities,
    required this.windowAvailability,
    required this.inDialog,
  });

  final List<AssetItem> assets;
  final AssetRequest request;
  final List<String> preselectedTagIds;
  final Map<String, int> preselectedQuantities;

  /// tag ID → how much of that asset is free for [request]'s loan window, as
  /// loaded from `availability.php` just before the picker opened. Null when
  /// the request has no comparable dates or the lookup failed — the picker
  /// then falls back to the point-in-time "free right now" figures.
  final Map<String, AssetWindowAvailability>? windowAvailability;

  final bool inDialog;

  @override
  State<_AssetAssignmentBody> createState() => _AssetAssignmentBodyState();
}

class _AssetAssignmentBodyState extends State<_AssetAssignmentBody> {
  final _searchController = TextEditingController();
  late final Set<String> _selected = {...widget.preselectedTagIds};
  // For bulk pools that are selected: how many units to take.
  late final Map<String, int> _bulkQty = {...widget.preselectedQuantities};
  AssetPickSort _sort = AssetPickSort.availability;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Window availability for [asset], or null when none was loaded.
  AssetWindowAvailability? _availOf(AssetItem asset) =>
      widget.windowAvailability?[asset.tagId];

  /// The most units of [asset] that can actually be handed to this request:
  /// the smaller of what's physically free now and what's still uncommitted
  /// for the request's loan window. Falls back to the plain point-in-time
  /// figure when no window availability was loaded. Never negative.
  int _bulkCap(AssetItem asset) {
    // Re-opening the picker for an already-approved request: this request's
    // own units are still counted in `quantity_out` (so already netted out
    // of `quantityAvailable`), but they're re-offerable to it, so add them
    // back. `windowFree` from the backend already excludes this request.
    final ownTake = widget.preselectedQuantities[asset.tagId] ?? 0;
    final now = asset.quantityAvailable + ownTake;
    final avail = _availOf(asset);
    final cap = avail == null
        ? now
        : (now < avail.windowFree ? now : avail.windowFree);
    return cap < 0 ? 0 : cap;
  }

  bool _isLocked(AssetItem asset) {
    if (widget.preselectedTagIds.contains(asset.tagId)) return false;
    if (asset.isBulk) return _bulkCap(asset) <= 0;
    // Maintenance / in-stock — filed out of the active, borrowable pool
    // (see AssetItem.isActiveInventory) and never lendable, regardless of
    // the loan window. Checked before the window-conflict lookup below so
    // it can never be reported as "booked"/"already borrowed" instead.
    if (!asset.isActiveInventory) return true;
    if (asset.status == AssetStatus.inUse) return true;
    // Free right now, but already claimed by another approved request whose
    // dates overlap this one.
    final avail = _availOf(asset);
    return avail != null && avail.windowFree < 1;
  }

  /// A sensible starting count for a freshly-selected bulk pool: the amount
  /// asked for on a matching request line, capped at what can be taken for
  /// the loan window.
  int _defaultBulkQty(AssetItem asset) {
    final cap = _bulkCap(asset) < 1 ? 1 : _bulkCap(asset);
    final preset = widget.preselectedQuantities[asset.tagId];
    if (preset != null) return preset.clamp(1, cap);
    for (final item in widget.request.allItems) {
      if (item.name.toLowerCase().trim() == asset.name.toLowerCase().trim()) {
        return item.quantity.clamp(1, cap);
      }
    }
    return 1;
  }

  void _setBulkQty(AssetItem asset, int qty) {
    final cap = _bulkCap(asset) < 1 ? 1 : _bulkCap(asset);
    setState(() => _bulkQty[asset.tagId] = qty.clamp(1, cap));
  }

  List<AssetItem> get _visible {
    final query = _searchController.text.toLowerCase();
    final list = widget.assets.where((a) {
      // Maintenance / in-stock assets are filed out of the active,
      // borrowable pool and can never be lent — they don't belong in a
      // "pick what to hand out" list at all. Without this they showed up
      // here locked with "Already borrowed", which was simply false:
      // nobody has them, they're a backup or awaiting repair. The
      // preselected exception mirrors [_isLocked]'s own — it can't
      // actually trigger today (an assigned individual asset is always
      // 'in_use', never maintenance/in-stock) but keeps this in lockstep
      // with that method instead of assuming it never will.
      if (!a.isBulk &&
          !a.isActiveInventory &&
          !widget.preselectedTagIds.contains(a.tagId)) {
        return false;
      }
      return a.name.toLowerCase().contains(query) ||
          a.tagId.toLowerCase().contains(query) ||
          a.category.toLowerCase().contains(query);
    }).toList();

    switch (_sort) {
      case AssetPickSort.availability:
        list.sort((a, b) {
          final byRank = _availabilityRank(a).compareTo(_availabilityRank(b));
          return byRank != 0 ? byRank : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      case AssetPickSort.nameAsc:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case AssetPickSort.dateDesc:
        list.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
      case AssetPickSort.dateAsc:
        list.sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));
    }
    return list;
  }

  void _toggle(AssetItem asset) {
    if (_isLocked(asset)) return;
    setState(() {
      if (_selected.remove(asset.tagId)) {
        _bulkQty.remove(asset.tagId);
      } else {
        _selected.add(asset.tagId);
        if (asset.isBulk) _bulkQty[asset.tagId] = _defaultBulkQty(asset);
      }
    });
  }

  void _confirm() {
    final picked = <AssetAssignment>[
      for (final a in widget.assets)
        if (_selected.contains(a.tagId))
          AssetAssignment(
            asset: a,
            quantity: a.isBulk
                ? (_bulkQty[a.tagId] ?? 1).clamp(1, _bulkCap(a) < 1 ? 1 : _bulkCap(a))
                : 1,
          ),
    ];
    Navigator.pop(context, picked);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final equipment = widget.request.equipment;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, widget.inDialog ? 20 : 14, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.inDialog)
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Assign assets',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              Text(
                'Pick the assets to hand out for "${widget.request.title}". '
                'They\'ll be marked In use until the approval is cancelled.',
                style: const TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.event_outlined, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.windowAvailability != null
                          ? 'Availability shown is for the loan window ${widget.request.dateRangeLabel}.'
                          : 'Loan window ${widget.request.dateRangeLabel} — this request has no '
                              'comparable dates, so figures below are "free right now".',
                      style: const TextStyle(
                        color: AppTheme.darkGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              if (equipment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Requested equipment: ${equipment.map((e) => e.label).join(', ')}',
                  style: const TextStyle(
                    color: AppTheme.darkGreen,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search by name, tag ID or category',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 10),
              SortDropdown<AssetPickSort>(
                value: _sort,
                options: AssetPickSort.values,
                labelBuilder: (o) => o.label,
                onChanged: (o) => setState(() => _sort = o),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.border),
        Flexible(
          child: visible.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No assets match your search.',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final asset = visible[i];
                    return _AssetRow(
                      asset: asset,
                      selected: _selected.contains(asset.tagId),
                      locked: _isLocked(asset),
                      quantity: _bulkQty[asset.tagId] ?? 1,
                      maxQuantity: _bulkCap(asset),
                      availability: _availOf(asset),
                      windowLabel: widget.request.dateRangeLabel,
                      onTap: () => _toggle(asset),
                      onQuantityChanged: (q) => _setBulkQty(asset, q),
                    );
                  },
                ),
        ),
        const Divider(height: 1, color: AppTheme.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selected.isEmpty ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  child: Text(
                    _selected.isEmpty
                        ? 'Select assets'
                        : 'Assign ${_selected.length} asset${_selected.length == 1 ? '' : 's'}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.asset,
    required this.selected,
    required this.locked,
    required this.quantity,
    required this.maxQuantity,
    required this.availability,
    required this.windowLabel,
    required this.onTap,
    required this.onQuantityChanged,
  });

  final AssetItem asset;
  final bool selected;
  final bool locked;
  final int quantity;

  /// The most units that may be taken for the request's window (bulk only).
  final int maxQuantity;

  /// Window availability for this asset, or null when none was loaded.
  final AssetWindowAvailability? availability;

  /// The request's loan window, e.g. "Sep 15, 2026 – Sep 16, 2026".
  final String windowLabel;

  final VoidCallback onTap;
  final ValueChanged<int> onQuantityChanged;

  /// Why this row is disabled — window conflicts take priority over the
  /// point-in-time reasons.
  String get _lockedNote {
    final avail = availability;
    if (asset.isBulk) {
      if (avail != null && avail.windowCommitted > 0) {
        return 'No units free for $windowLabel — ${avail.windowCommitted} booked by '
            '${_conflictNames(avail.conflicts)}';
      }
      return 'Out of stock — nothing available to lend';
    }
    if (!asset.isActiveInventory) {
      return '${asset.status.label} — not part of the active pool, so it can\'t be lent';
    }
    if (avail != null && avail.conflicts.isNotEmpty) {
      return 'Booked for an overlapping period by ${_conflictNames(avail.conflicts)}';
    }
    return 'Already borrowed — free it by cancelling its request';
  }

  static String _conflictNames(List<WindowConflict> conflicts) {
    if (conflicts.isEmpty) return 'another approved request';
    final names = conflicts.take(2).map((c) => '"${c.title}"').join(', ');
    final extra = conflicts.length - 2;
    return extra > 0 ? '$names +$extra more' : names;
  }

  @override
  Widget build(BuildContext context) {
    final avail = availability;
    final showWindowHint = !locked &&
        avail != null &&
        (asset.isBulk || avail.conflicts.isNotEmpty);
    return Opacity(
      opacity: locked ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: locked ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: selected ? AppTheme.primary : AppTheme.muted,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.darkGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${asset.tagId} · ${asset.category}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (locked) ...[
                        const SizedBox(height: 3),
                        Text(
                          _lockedNote,
                          style: const TextStyle(color: Color(0xFFC84040), fontSize: 11.5),
                        ),
                      ] else if (showWindowHint) ...[
                        const SizedBox(height: 3),
                        Text(
                          asset.isBulk
                              ? '${avail.windowFree} free for $windowLabel'
                              : 'Free for $windowLabel',
                          style: const TextStyle(color: AppTheme.primary, fontSize: 11.5),
                        ),
                      ],
                      if (asset.isBulk && selected && !locked) ...[
                        const SizedBox(height: 8),
                        _QtyStepper(
                          value: quantity,
                          // Never show a ceiling below the current pick — a
                          // re-approval of a now-oversubscribed window can
                          // leave the cap under the existing quantity; the
                          // backend guard then reports the real shortfall.
                          max: maxQuantity < quantity ? quantity : maxQuantity,
                          onChanged: onQuantityChanged,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (asset.isBulk)
                  _StockPill(asset: asset, windowFree: avail?.windowFree)
                else
                  StatusChip(status: asset.status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact "12 / 50" pill for a bulk pool in the picker. When [windowFree]
/// is given it shows that (units free for the request's dates) as the
/// numerator instead of the point-in-time count.
class _StockPill extends StatelessWidget {
  const _StockPill({required this.asset, this.windowFree});

  final AssetItem asset;
  final int? windowFree;

  @override
  Widget build(BuildContext context) {
    final free = windowFree ?? asset.quantityAvailable;
    final low = asset.isLowStock || free <= 0;
    final (bg, fg) = low
        ? (AppTheme.redTint, const Color(0xFFC84040))
        : (AppTheme.mint, AppTheme.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
      child: Text(
        '$free / ${asset.quantityTotal ?? 0}',
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12.5),
      ),
    );
  }
}

/// − N + stepper for choosing how many units of a bulk pool to hand out.
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(icon: Icons.remove, onTap: value > 1 ? () => onChanged(value - 1) : null),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '$value',
            style: const TextStyle(
              color: AppTheme.darkGreen,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
        _StepBtn(icon: Icons.add, onTap: value < max ? () => onChanged(value + 1) : null),
        const SizedBox(width: 8),
        Text('of $max', style: const TextStyle(color: AppTheme.muted, fontSize: 11.5)),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.mint : AppTheme.slateTint,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: enabled ? AppTheme.primary : AppTheme.muted),
      ),
    );
  }
}
