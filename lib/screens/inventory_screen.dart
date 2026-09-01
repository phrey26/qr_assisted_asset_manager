import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/asset_card.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/lifespan_warning_badge.dart';
import '../widgets/page_header.dart';
import '../widgets/sort_dropdown.dart';
import '../widgets/status_chip.dart';
import 'asset_detail_screen.dart';

/// Sort orders available for the inventory list, selectable via the
/// "Sort by" dropdown.
enum InventorySortOption { nameAsc, dateAsc, dateDesc }

extension InventorySortOptionX on InventorySortOption {
  String get label {
    switch (this) {
      case InventorySortOption.nameAsc:
        return 'A-Z';
      case InventorySortOption.dateAsc:
        return 'Purchase date (Ascending)';
      case InventorySortOption.dateDesc:
        return 'Purchase date (Descending)';
    }
  }
}

/// Pushes [AssetDetailScreen] for the given asset. Shared by both the
/// mobile card list and the desktop table so tapping an asset behaves the
/// same way regardless of layout. [onDeleteAsset] is forwarded so the
/// admin can also remove the asset from the detail page.
void _openAssetDetail(
  BuildContext context,
  AssetItem asset, {
  void Function(AssetItem asset)? onDeleteAsset,
  void Function(AssetItem asset, AssetStatus status)? onUpdateStatus,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AssetDetailScreen(
        asset: asset,
        onDelete: onDeleteAsset == null ? null : () => onDeleteAsset(asset),
        onUpdateStatus: onUpdateStatus == null
            ? null
            : (status) => onUpdateStatus(asset, status),
      ),
    ),
  );
}

/// Shows the confirmation dialog, and only invokes [onDeleteAsset] if the
/// admin confirms. Shared by the mobile card list and the desktop table.
Future<void> _confirmAndDelete(
  BuildContext context,
  AssetItem asset,
  void Function(AssetItem asset) onDeleteAsset,
) async {
  final confirmed = await confirmAssetDeletion(context, asset);
  if (confirmed) onDeleteAsset(asset);
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    super.key,
    required this.assets,
    required this.categories,
    this.onAddAsset,
    this.onDeleteAsset,
    this.onUpdateStatus,
  });

  final List<AssetItem> assets;

  /// The categories offered as filter chips (in addition to 'All'). Owned
  /// by [AppShell] and shared with the Categories tab and Add Asset
  /// dropdown, so a category added there immediately shows up here too.
  final List<AssetCategory> categories;

  /// Invoked when the user wants to add a new asset. On mobile this is
  /// triggered by the FAB in [AppShell]; on desktop it's also wired to the
  /// inline "+ Add asset" button next to the page title, matching the
  /// hi-fi desktop mockups.
  final VoidCallback? onAddAsset;

  /// Invoked (after the admin confirms via the "are you sure" dialog) to
  /// remove an asset from the inventory once it's no longer usable. When
  /// null, no delete affordance is shown anywhere on this page.
  final void Function(AssetItem asset)? onDeleteAsset;

  /// Invoked when the admin changes an asset's status from its status
  /// chip's menu — e.g. flagging it as under maintenance, or marking it
  /// available again once it's fixed. When null, status chips throughout
  /// this page are read-only.
  final void Function(AssetItem asset, AssetStatus status)? onUpdateStatus;

  @override
  State<InventoryScreen> createState() => InventoryScreenState();
}

/// Public so [AppShell] can reach [setFilter] via a [GlobalKey] and jump
/// straight to a given category — e.g. when the admin taps a category
/// card on the home page — the same way it drives [RequestsScreenState]'s
/// "new request" flow.
class InventoryScreenState extends State<InventoryScreen> {
  final searchController = TextEditingController();

  /// Category filter selection. 'All' plus each entry in [_categories]
  /// (matched against [AssetItem.category] case-insensitively, since
  /// category is free text elsewhere in the app).
  String filter = 'All';

  InventorySortOption sortOption = InventorySortOption.nameAsc;

  /// 'All' plus the current [AssetCategory.value] for each entry in
  /// [InventoryScreen.categories], in order.
  List<String> get _categories => ['All', ...widget.categories.map((c) => c.value)];

  /// Jumps straight to [category] (one of [_categories]), replacing
  /// whatever filter was previously selected. Falls back to 'All' if given
  /// a category this page doesn't recognize.
  void setFilter(String category) {
    setState(() => filter = _categories.contains(category) ? category : 'All');
  }

  @override
  void initState() {
    super.initState();
    searchController.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(InventoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the category currently selected in the filter was just deleted
    // (widget.categories is owned by AppShell and can shrink), fall back
    // to 'All' rather than keep pointing at a filter that no longer
    // exists.
    if (!_categories.contains(filter)) {
      filter = 'All';
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<AssetItem> get filtered {
    final query = searchController.text.toLowerCase();
    final results = widget.assets.where((asset) {
      final matchesQuery = asset.name.toLowerCase().contains(query) ||
          asset.tagId.toLowerCase().contains(query);
      final matchesFilter =
          filter == 'All' || asset.category.toLowerCase() == filter.toLowerCase();
      return matchesQuery && matchesFilter;
    }).toList();

    switch (sortOption) {
      case InventorySortOption.nameAsc:
        results.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case InventorySortOption.dateAsc:
        results.sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));
      case InventorySortOption.dateDesc:
        results.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final maxWidth = isDesktop ? 1040.0 : double.infinity;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 42, 28, 0),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: PageHeader(
                        title: 'Inventory',
                        subtitle: '${widget.assets.length} assets tracked',
                        showMark: false,
                      ),
                    ),
                    if (isDesktop && widget.onAddAsset != null) ...[
                      const SizedBox(width: 16),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ElevatedButton.icon(
                          onPressed: widget.onAddAsset,
                          icon: const Icon(Icons.add),
                          label: const Text('Add asset'),
                          // Override the global button theme's
                          // Size.fromHeight(64), which sets an infinite
                          // minimum width intended for full-bleed buttons.
                          // Left as-is, a Row (which gives non-flex
                          // children unbounded width) can't lay this
                          // button out, which blanks the whole page.
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 18),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isDesktop ? 360 : double.infinity),
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search by name or tag ID',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _filterAndSortRow(isDesktop),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isDesktop)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 40),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: _InventoryTable(
                    assets: filtered,
                    onDeleteAsset: widget.onDeleteAsset,
                    onUpdateStatus: widget.onUpdateStatus,
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(28, 4, 28, Responsive.bottomScrollClearance(context)),
            sliver: SliverList.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final asset = filtered[index];
                return AssetCard(
                  asset: asset,
                  onTap: () => _openAssetDetail(
                    context,
                    asset,
                    onDeleteAsset: widget.onDeleteAsset,
                    onUpdateStatus: widget.onUpdateStatus,
                  ),
                  onDelete: widget.onDeleteAsset == null
                      ? null
                      : () => _confirmAndDelete(context, asset, widget.onDeleteAsset!),
                  onUpdateStatus: widget.onUpdateStatus == null
                      ? null
                      : (status) => widget.onUpdateStatus!(asset, status),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _filters() {
    return FilterChipRow(
      options: _categories,
      selected: filter,
      onSelected: (item) => setState(() => filter = item),
    );
  }

  Widget _sortDropdown() {
    return SortDropdown<InventorySortOption>(
      value: sortOption,
      options: InventorySortOption.values,
      labelBuilder: (option) => option.label,
      onChanged: (option) => setState(() => sortOption = option),
    );
  }

  /// Lays out the category filter chips and the "Sort by" dropdown
  /// together. On desktop there's enough horizontal room to keep them on
  /// one line (chips on the left, sort control pinned to the right); on
  /// narrower mobile widths they stack instead so the sort control never
  /// competes with the chips for space or gets squeezed off-screen.
  Widget _filterAndSortRow(bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _filters()),
          const SizedBox(width: 16),
          // SortDropdown stretches to `width: double.infinity` (it's built
          // to fill a full-width column slot on mobile). As a bare non-flex
          // child of this Row it's handed unbounded width, so it balloons
          // out, starves the Expanded filter chips beside it to zero width
          // (leaving just the selected chip's stray check mark visible) and
          // mangles its own internal layout. Pinning it to a fixed width
          // gives it — and the chips — a definite box to lay out in.
          SizedBox(width: 300, child: _sortDropdown()),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filters(),
        const SizedBox(height: 14),
        _sortDropdown(),
      ],
    );
  }
}

/// Desktop-only data-table presentation of the inventory list, matching the
/// hi-fi desktop mockups (a wide table reads better than stacked cards once
/// there's room for it).
class _InventoryTable extends StatelessWidget {
  const _InventoryTable({required this.assets, this.onDeleteAsset, this.onUpdateStatus});

  final List<AssetItem> assets;
  final void Function(AssetItem asset)? onDeleteAsset;
  final void Function(AssetItem asset, AssetStatus status)? onUpdateStatus;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 1.5),
        ),
        child: const Center(
          child: Text('No assets match your search.', style: TextStyle(color: AppTheme.muted)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF6F5F0)),
          // Rows are tappable to open the asset's detail page; we don't
          // want the selection checkboxes that onSelectChanged would
          // otherwise add, just the click-to-open behavior.
          showCheckboxColumn: false,
          columns: [
            const DataColumn(label: Text('Asset')),
            const DataColumn(label: Text('Tag ID')),
            const DataColumn(label: Text('Category')),
            const DataColumn(label: Text('Purchased')),
            const DataColumn(label: Text('Status')),
            if (onDeleteAsset != null) const DataColumn(label: Text('')),
          ],
          rows: assets
              .map(
                (asset) => DataRow(
                  onSelectChanged: (_) => _openAssetDetail(
                    context,
                    asset,
                    onDeleteAsset: onDeleteAsset,
                    onUpdateStatus: onUpdateStatus,
                  ),
                  cells: [
                    DataCell(Text(
                      asset.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.darkGreen),
                    )),
                    DataCell(Text(
                      asset.tagId,
                      style: const TextStyle(fontFamily: 'monospace', color: AppTheme.muted),
                    )),
                    DataCell(Text(asset.category)),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          asset.formattedPurchaseDate,
                          style: const TextStyle(color: AppTheme.muted),
                        ),
                        if (asset.isPastLifespan) ...[
                          const SizedBox(width: 8),
                          const LifespanWarningBadge(compact: true),
                        ],
                      ],
                    )),
                    DataCell(
                      StatusChip(
                        status: asset.status,
                        onChanged: onUpdateStatus == null
                            ? null
                            : (status) => onUpdateStatus!(asset, status),
                      ),
                    ),
                    if (onDeleteAsset != null)
                      DataCell(
                        IconButton(
                          onPressed: () => _confirmAndDelete(context, asset, onDeleteAsset!),
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.redAccent,
                          tooltip: 'Remove from inventory',
                        ),
                      ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}