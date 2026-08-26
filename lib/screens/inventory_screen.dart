import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/asset_card.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/page_header.dart';
import '../widgets/status_chip.dart';
import 'asset_detail_screen.dart';

/// Pushes [AssetDetailScreen] for the given asset. Shared by both the
/// mobile card list and the desktop table so tapping an asset behaves the
/// same way regardless of layout. [onDeleteAsset] is forwarded so the
/// admin can also remove the asset from the detail page.
void _openAssetDetail(
  BuildContext context,
  AssetItem asset, {
  void Function(AssetItem asset)? onDeleteAsset,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AssetDetailScreen(
        asset: asset,
        onDelete: onDeleteAsset == null ? null : () => onDeleteAsset(asset),
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
    this.onAddAsset,
    this.onDeleteAsset,
  });

  final List<AssetItem> assets;

  /// Invoked when the user wants to add a new asset. On mobile this is
  /// triggered by the FAB in [AppShell]; on desktop it's also wired to the
  /// inline "+ Add asset" button next to the page title, matching the
  /// hi-fi desktop mockups.
  final VoidCallback? onAddAsset;

  /// Invoked (after the admin confirms via the "are you sure" dialog) to
  /// remove an asset from the inventory once it's no longer usable. When
  /// null, no delete affordance is shown anywhere on this page.
  final void Function(AssetItem asset)? onDeleteAsset;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final searchController = TextEditingController();
  String filter = 'All';

  @override
  void initState() {
    super.initState();
    searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<AssetItem> get filtered {
    final query = searchController.text.toLowerCase();
    return widget.assets.where((asset) {
      final matchesQuery = asset.name.toLowerCase().contains(query) ||
          asset.tagId.toLowerCase().contains(query);
      final matchesFilter = filter == 'All' ||
          (filter == 'Available' && asset.status == AssetStatus.available) ||
          (filter == 'In use' && asset.status == AssetStatus.inUse) ||
          (filter == 'Maintenance' && asset.status == AssetStatus.maintenance);
      return matchesQuery && matchesFilter;
    }).toList();
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
                    _filters(),
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
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 4, 28, 110),
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
                  ),
                  onDelete: widget.onDeleteAsset == null
                      ? null
                      : () => _confirmAndDelete(context, asset, widget.onDeleteAsset!),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _filters() {
    const filters = ['All', 'Available', 'In use', 'Maintenance'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((item) {
          final selected = filter == item;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(item),
              selected: selected,
              onSelected: (_) => setState(() => filter = item),
              selectedColor: AppTheme.darkGreen,
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppTheme.border, width: 2),
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppTheme.darkGreen,
                fontWeight: FontWeight.w800,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Desktop-only data-table presentation of the inventory list, matching the
/// hi-fi desktop mockups (a wide table reads better than stacked cards once
/// there's room for it).
class _InventoryTable extends StatelessWidget {
  const _InventoryTable({required this.assets, this.onDeleteAsset});

  final List<AssetItem> assets;
  final void Function(AssetItem asset)? onDeleteAsset;

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
                    DataCell(Text(
                      asset.formattedPurchaseDate,
                      style: const TextStyle(color: AppTheme.muted),
                    )),
                    DataCell(StatusChip(status: asset.status)),
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