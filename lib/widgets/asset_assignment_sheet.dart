import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../models/asset_request.dart';
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

/// Lower sorts first when ordering by "availability" — free assets float to
/// the top, already-borrowed ones sink.
int _availabilityRank(AssetStatus status) {
  switch (status) {
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
/// assets the admin chose, or null if they backed out. Desktop shows a
/// centered dialog; mobile pushes a full-screen page.
///
/// Every asset is listed (with its current status shown), sortable by
/// availability, name, or purchase date. Assets already marked `in_use`
/// can't be picked unless they were already assigned to this request
/// ([preselectedTagIds]).
Future<List<AssetItem>?> showAssetAssignmentPicker(
  BuildContext context, {
  required List<AssetItem> assets,
  required AssetRequest request,
  List<String> preselectedTagIds = const [],
}) {
  if (Responsive.isDesktop(context)) {
    return showDialog<List<AssetItem>>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
          child: _AssetAssignmentBody(
            assets: assets,
            request: request,
            preselectedTagIds: preselectedTagIds,
            inDialog: true,
          ),
        ),
      ),
    );
  }
  return Navigator.of(context).push<List<AssetItem>>(
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
    required this.inDialog,
  });

  final List<AssetItem> assets;
  final AssetRequest request;
  final List<String> preselectedTagIds;
  final bool inDialog;

  @override
  State<_AssetAssignmentBody> createState() => _AssetAssignmentBodyState();
}

class _AssetAssignmentBodyState extends State<_AssetAssignmentBody> {
  final _searchController = TextEditingController();
  late final Set<String> _selected = {...widget.preselectedTagIds};
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

  bool _isLocked(AssetItem asset) =>
      asset.status == AssetStatus.inUse &&
      !widget.preselectedTagIds.contains(asset.tagId);

  List<AssetItem> get _visible {
    final query = _searchController.text.toLowerCase();
    final list = widget.assets.where((a) {
      return a.name.toLowerCase().contains(query) ||
          a.tagId.toLowerCase().contains(query) ||
          a.category.toLowerCase().contains(query);
    }).toList();

    switch (_sort) {
      case AssetPickSort.availability:
        list.sort((a, b) {
          final byRank = _availabilityRank(a.status).compareTo(_availabilityRank(b.status));
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
      if (!_selected.remove(asset.tagId)) _selected.add(asset.tagId);
    });
  }

  void _confirm() {
    final picked =
        widget.assets.where((a) => _selected.contains(a.tagId)).toList();
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
                      onTap: () => _toggle(asset),
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
    required this.onTap,
  });

  final AssetItem asset;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                        const Text(
                          'Already borrowed — free it by cancelling its request',
                          style: TextStyle(color: Color(0xFFC84040), fontSize: 11.5),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                StatusChip(status: asset.status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
