import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../models/category.dart';
import '../models/stock.dart';
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
import 'stock_items_screen.dart';

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
/// same way regardless of layout. [onRetireAsset] is forwarded so the admin
/// can also retire the asset (to backup, with a reason) from the detail
/// page.
void _openAssetDetail(
  BuildContext context,
  AssetItem asset, {
  String? adminName,
  void Function(AssetItem asset)? onEditAsset,
  void Function(AssetItem asset, String reason, bool needsMaintenance)? onRetireAsset,
  void Function(AssetItem asset, String reason)? onDeleteAsset,
  void Function(AssetItem asset, StockSummary summary)? onBulkStockChanged,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AssetDetailScreen(
        asset: asset,
        adminName: adminName,
        onEdit: onEditAsset == null ? null : () => onEditAsset(asset),
        // A bulk pool is deleted (once run down to zero), never retired to
        // backup; an individual asset is retired to backup.
        removalMode:
            asset.isBulk ? AssetRemovalMode.delete : AssetRemovalMode.retireToStock,
        onDelete: asset.isBulk
            ? (onDeleteAsset == null ? null : (reason, _) => onDeleteAsset(asset, reason))
            : (onRetireAsset == null
                ? null
                : (reason, needsMaintenance) =>
                    onRetireAsset(asset, reason, needsMaintenance)),
        onStockChanged: onBulkStockChanged == null
            ? null
            : (summary) => onBulkStockChanged(asset, summary),
      ),
    ),
  );
}

/// Asks the admin why the asset is being moved to backup, and only invokes
/// [onRetireAsset] (with that reason, and whether it needs maintenance) if
/// they confirm. Shared by the mobile card list and the desktop table.
Future<void> _confirmAndRetire(
  BuildContext context,
  AssetItem asset,
  void Function(AssetItem asset, String reason, bool needsMaintenance) onRetireAsset,
) async {
  final choice = await promptAssetRemoval(context, asset, AssetRemovalMode.retireToStock);
  if (choice != null) onRetireAsset(asset, choice.reason, choice.needsMaintenance);
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    super.key,
    required this.assets,
    required this.categories,
    this.adminName,
    this.onAddAsset,
    this.onEditAsset,
    this.onRetireAsset,
    this.onDeleteAsset,
    this.onActivateAsset,
    this.onBulkStockChanged,
  });

  final List<AssetItem> assets;

  /// The categories offered as filter chips (in addition to 'All'). Owned
  /// by [AppShell] and shared with the Categories tab and Add Asset
  /// dropdown, so a category added there immediately shows up here too.
  final List<AssetCategory> categories;

  /// The signed-in admin's name, threaded down to [AssetDetailScreen] (via
  /// [StockItemsScreen] too) for the "who did this" attribution on stock
  /// actions taken directly from the detail page. Edit/retire/delete/
  /// activate go through [AppShell]'s own callbacks instead, which already
  /// apply this centrally — see `_adminName` in `main.dart`.
  final String? adminName;

  /// Invoked when the user wants to add a new asset. On mobile this is
  /// triggered by the FAB in [AppShell]; on desktop it's also wired to the
  /// inline "+ Add asset" button next to the page title, matching the
  /// hi-fi desktop mockups.
  final VoidCallback? onAddAsset;

  /// Invoked with an asset the admin wants to edit — opens the prefilled
  /// Add Asset form in "edit" mode. Forwarded to [AssetDetailScreen]'s Edit
  /// button. When null, no edit affordance is shown.
  final void Function(AssetItem asset)? onEditAsset;

  /// Invoked (with the admin's reason, and whether the asset needs repair —
  /// which files it under "Maintenance" rather than plain "Backup") to
  /// retire an asset from the active inventory into "Backup items". This is
  /// the only "remove" action on this page — assets are never deleted
  /// straight from here. When null, no retire affordance is shown.
  final void Function(AssetItem asset, String reason, bool needsMaintenance)? onRetireAsset;

  /// Permanent-delete handler, forwarded to [StockItemsScreen] for
  /// individual assets (deletable once they're backup items), and used here
  /// for bulk pools (deletable once run down to zero).
  final void Function(AssetItem asset, String reason)? onDeleteAsset;

  /// Bulk assets only: invoked with the authoritative new stock totals
  /// after a stock action on the asset detail screen, so this list's
  /// readouts stay right without a reload.
  final void Function(AssetItem asset, StockSummary summary)? onBulkStockChanged;

  /// Invoked (with the admin's reason) to move a backup / maintenance asset
  /// back into the active, borrowable inventory. Forwarded to
  /// [StockItemsScreen]. Not used directly on this page.
  final void Function(AssetItem asset, String reason)? onActivateAsset;

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

  /// Opens the "backup items" list. Forwards the activate and delete
  /// handlers so an item can be moved back into the main inventory or
  /// removed straight from there, and [InventoryScreen.onBulkStockChanged]
  /// so bulk pools' reactivate/dispose actions there stay in sync too.
  Future<void> _openStockItems(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockItemsScreen(
          assets: widget.assets,
          adminName: widget.adminName,
          onDeleteAsset: widget.onDeleteAsset,
          onActivateAsset: widget.onActivateAsset,
          onBulkStockChanged: widget.onBulkStockChanged,
        ),
      ),
    );
    // The stock screen mutates the shared asset list in place; rebuild so
    // the inventory count / list pick up anything that was activated.
    if (mounted) setState(() {});
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

  /// Only the active, borrowable assets. "Backup items" — backups, plus
  /// anything moved out needing repair (Maintenance) — are kept out of the
  /// main inventory and shown on their own screen instead, see
  /// [StockItemsScreen].
  List<AssetItem> get _activeAssets =>
      widget.assets.where((asset) => asset.isActiveInventory).toList();

  int get _stockCount => widget.assets.length - _activeAssets.length;

  List<AssetItem> get filtered {
    final query = searchController.text.toLowerCase();
    final results = _activeAssets.where((asset) {
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
                        subtitle: '${_activeAssets.length} active '
                            '${_activeAssets.length == 1 ? 'asset' : 'assets'}',
                        showMark: false,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: OutlinedButton.icon(
                        onPressed: () => _openStockItems(context),
                        icon: const Icon(Icons.archive_outlined, size: 20),
                        label: Text(
                          isDesktop
                              ? 'Backup items ($_stockCount)'
                              : 'Backup ($_stockCount)',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary, width: 2),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    if (isDesktop && widget.onAddAsset != null) ...[
                      const SizedBox(width: 12),
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
                    adminName: widget.adminName,
                    onEditAsset: widget.onEditAsset,
                    onRetireAsset: widget.onRetireAsset,
                    onDeleteAsset: widget.onDeleteAsset,
                    onBulkStockChanged: widget.onBulkStockChanged,
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
                  removeIcon: Icons.archive_outlined,
                  removeTooltip: 'Move to backup',
                  removeColor: AppTheme.primary,
                  onTap: () => _openAssetDetail(
                    context,
                    asset,
                    adminName: widget.adminName,
                    onEditAsset: widget.onEditAsset,
                    onRetireAsset: widget.onRetireAsset,
                    onDeleteAsset: widget.onDeleteAsset,
                    onBulkStockChanged: widget.onBulkStockChanged,
                  ),
                  // Bulk pools aren't retired to backup — they're managed
                  // from the detail screen. Only individual assets get the
                  // inline "move to backup" button.
                  onDelete: (asset.isBulk || widget.onRetireAsset == null)
                      ? null
                      : () => _confirmAndRetire(context, asset, widget.onRetireAsset!),
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
  const _InventoryTable({
    required this.assets,
    this.adminName,
    this.onEditAsset,
    this.onRetireAsset,
    this.onDeleteAsset,
    this.onBulkStockChanged,
  });

  final List<AssetItem> assets;
  final String? adminName;
  final void Function(AssetItem asset)? onEditAsset;
  final void Function(AssetItem asset, String reason, bool needsMaintenance)? onRetireAsset;
  final void Function(AssetItem asset, String reason)? onDeleteAsset;
  final void Function(AssetItem asset, StockSummary summary)? onBulkStockChanged;

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
            if (onRetireAsset != null) const DataColumn(label: Text('')),
          ],
          rows: assets
              .map(
                (asset) => DataRow(
                  onSelectChanged: (_) => _openAssetDetail(
                    context,
                    asset,
                    adminName: adminName,
                    onEditAsset: onEditAsset,
                    onRetireAsset: onRetireAsset,
                    onDeleteAsset: onDeleteAsset,
                    onBulkStockChanged: onBulkStockChanged,
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
                        if (asset.isLoanOverdue) ...[
                          const SizedBox(width: 8),
                          OverdueLoanBadge(compact: true, days: asset.overdueDays),
                        ],
                        if (asset.isPastLifespan) ...[
                          const SizedBox(width: 8),
                          LifespanWarningBadge(
                              compact: true, years: asset.lifespanYears),
                        ],
                        if (asset.isDamaged || asset.hasDamagedStock) ...[
                          const SizedBox(width: 8),
                          const DamagedWarningBadge(compact: true),
                        ],
                        if (asset.isLowStock) ...[
                          const SizedBox(width: 8),
                          const LowStockBadge(compact: true),
                        ],
                      ],
                    )),
                    DataCell(
                      asset.isBulk
                          ? Text(
                              asset.stockLabel,
                              style: TextStyle(
                                color: asset.isLowStock
                                    ? const Color(0xFFC84040)
                                    : AppTheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : StatusChip(status: asset.status),
                    ),
                    if (onRetireAsset != null)
                      DataCell(
                        asset.isBulk
                            ? const SizedBox.shrink()
                            : IconButton(
                                onPressed: () =>
                                    _confirmAndRetire(context, asset, onRetireAsset!),
                                icon: const Icon(Icons.archive_outlined),
                                color: AppTheme.primary,
                                tooltip: 'Move to backup',
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