import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/asset_card.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/page_header.dart';
import 'asset_detail_screen.dart';
import 'removed_assets_screen.dart';

/// Assets that have been taken out of the active, borrowable inventory —
/// backups kept on hand as spares ([AssetStatus.inStock]) and anything
/// moved out because it needs repair ([AssetStatus.maintenance]). They're
/// filed here instead of the main [InventoryScreen] when an asset is added
/// with the "Stock item" destination, or later via "Move to stock".
///
/// The screen shares [InventoryScreen]'s asset list (owned by `AppShell`)
/// and its activate / delete handlers, so an item can be moved back into
/// the main inventory ("Move to active") or removed straight from here.
/// Both actions are persisted to the backend by those handlers.
class StockItemsScreen extends StatefulWidget {
  const StockItemsScreen({
    super.key,
    required this.assets,
    this.adminName,
    this.onDeleteAsset,
    this.onActivateAsset,
  });

  /// The full asset list (active + stock). This screen shows only the
  /// entries that aren't in the active inventory (see
  /// [AssetItem.isActiveInventory]).
  final List<AssetItem> assets;

  /// The signed-in admin's name, forwarded to [AssetDetailScreen] for the
  /// "who did this" attribution on stock actions taken directly from the
  /// detail page. See [InventoryScreen.adminName].
  final String? adminName;

  /// Permanently deletes the asset, given the admin's reason. Only offered
  /// here — an asset can't be deleted straight from the active inventory,
  /// it has to be moved to stock first.
  final void Function(AssetItem asset, String reason)? onDeleteAsset;

  /// Moves the asset back into the active, borrowable inventory, given the
  /// admin's reason (recorded on its timeline).
  final void Function(AssetItem asset, String reason)? onActivateAsset;

  @override
  State<StockItemsScreen> createState() => _StockItemsScreenState();
}

class _StockItemsScreenState extends State<StockItemsScreen> {
  final searchController = TextEditingController();

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

  List<AssetItem> get _stockItems {
    final query = searchController.text.toLowerCase();
    return widget.assets.where((asset) {
      if (asset.isActiveInventory) return false;
      return asset.name.toLowerCase().contains(query) ||
          asset.tagId.toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Moves an asset back into the active inventory through the shared
  /// handler, then rebuilds so it drops out of this list.
  void _activateAsset(AssetItem asset, String reason) {
    widget.onActivateAsset?.call(asset, reason);
    setState(() {});
  }

  void _deleteAsset(AssetItem asset, String reason) {
    widget.onDeleteAsset?.call(asset, reason);
    setState(() {});
  }

  Future<void> _openDetail(AssetItem asset) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssetDetailScreen(
          asset: asset,
          adminName: widget.adminName,
          removalMode: AssetRemovalMode.delete,
          onDelete: widget.onDeleteAsset == null
              ? null
              : (reason, _) => _deleteAsset(asset, reason),
          onActivate: widget.onActivateAsset == null
              ? null
              : (reason) => _activateAsset(asset, reason),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _confirmAndDelete(AssetItem asset) async {
    final choice = await promptAssetRemoval(context, asset, AssetRemovalMode.delete);
    if (choice != null) _deleteAsset(asset, choice.reason);
  }

  Future<void> _confirmAndActivate(AssetItem asset) async {
    final reason = await promptAssetActivation(context, asset);
    if (reason != null) _activateAsset(asset, reason);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final maxWidth = isDesktop ? 1040.0 : double.infinity;
    final items = _stockItems;
    final totalStock = widget.assets.where((a) => !a.isActiveInventory).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Stock items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Removed assets log',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RemovedAssetsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: PageHeader(
                      title: 'Stock items',
                      subtitle: '$totalStock '
                          '${totalStock == 1 ? 'item' : 'items'} held out of active '
                          'inventory — not available to borrow',
                      showMark: false,
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: _infoBanner(),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isDesktop ? 360 : maxWidth),
                    child: TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search by name or tag ID',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 40),
                  child: Center(
                    child: Text(
                      totalStock == 0
                          ? 'Nothing here yet.\nAdd an asset as a "Stock item", or use "Move to stock" '
                              'on an asset in the inventory, to file it here.'
                          : 'No stock items match your search.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.muted, fontSize: 15),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  28,
                  4,
                  28,
                  Responsive.bottomScrollClearance(context),
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        children: [
                          for (final asset in items)
                            AssetCard(
                              asset: asset,
                              removeTooltip: 'Delete permanently',
                              onTap: () => _openDetail(asset),
                              onActivate: widget.onActivateAsset == null
                                  ? null
                                  : () => _confirmAndActivate(asset),
                              onDelete: widget.onDeleteAsset == null
                                  ? null
                                  : () => _confirmAndDelete(asset),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.slateTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppTheme.muted, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'These assets are held out of the active inventory — spare backups, and '
              'items moved out needing repair (Maintenance). They can\'t be borrowed. '
              'Use "Move to active" to put one back into the borrowable inventory.',
              style: TextStyle(color: AppTheme.darkGreen, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
