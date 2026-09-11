import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../models/stock.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/asset_card.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/page_header.dart';
import '../widgets/stock_dialogs.dart';
import 'asset_detail_screen.dart';
import 'removed_assets_screen.dart';

/// Assets that have been taken out of the active, borrowable inventory —
/// backups kept on hand as spares ([AssetStatus.inStock]) and anything
/// moved out because it needs repair ([AssetStatus.maintenance]). They're
/// filed here instead of the main [InventoryScreen] when an asset is added
/// with the "Backup item" destination, or later via "Move to backup".
///
/// Also lists bulk pools with units set aside as backup
/// ([AssetItem.quantityBackup]) — the bulk counterpart. Reactivating or
/// permanently disposing of those units only happens from this screen (see
/// [_BulkBackupCard]); the bulk asset's own detail page only offers "Move to
/// backup" (adding to this list), the same asymmetry the individual-asset
/// side already has between the Inventory tab and here.
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
    this.onBulkStockChanged,
  });

  /// The full asset list (active + stock). This screen shows only the
  /// entries that aren't in the active inventory (see
  /// [AssetItem.isActiveInventory]), plus any bulk pool with backup units.
  final List<AssetItem> assets;

  /// The signed-in admin's name, forwarded to [AssetDetailScreen] for the
  /// "who did this" attribution on stock actions taken directly from the
  /// detail page, and sent with the reactivate/dispose actions this screen
  /// runs directly for bulk backup units. See [InventoryScreen.adminName].
  final String? adminName;

  /// Permanently deletes the asset, given the admin's reason. Only offered
  /// here — an asset can't be deleted straight from the active inventory,
  /// it has to be moved to stock first.
  final void Function(AssetItem asset, String reason)? onDeleteAsset;

  /// Moves the asset back into the active, borrowable inventory, given the
  /// admin's reason (recorded on its timeline).
  final void Function(AssetItem asset, String reason)? onActivateAsset;

  /// Bulk assets only: invoked with the authoritative new stock totals after
  /// this screen reactivates or disposes of backed-up units, so the shared
  /// inventory list stays right without a reload. See
  /// `AppShell._applyBulkSummary`.
  final void Function(AssetItem asset, StockSummary summary)? onBulkStockChanged;

  @override
  State<StockItemsScreen> createState() => _StockItemsScreenState();
}

class _StockItemsScreenState extends State<StockItemsScreen> {
  final searchController = TextEditingController();

  /// Bulk pools with units set aside as backup, whose reactivate/dispose
  /// call is currently in flight — disables that card's buttons so a
  /// double-tap can't fire the same action twice.
  final Set<String> _bulkBusy = {};

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

  List<AssetItem> get _bulkBackupItems {
    final query = searchController.text.toLowerCase();
    return widget.assets.where((asset) {
      if (!asset.hasBackupStock) return false;
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

  Future<void> _reactivateBulk(AssetItem asset) async {
    final input = await promptStockReactivate(context, asset);
    if (input == null) return;
    setState(() => _bulkBusy.add(asset.tagId));
    try {
      final summary = await ApiService.reactivateStock(
        tagId: asset.tagId,
        quantity: input.quantity,
        reason: input.reason,
        performedBy: widget.adminName,
      );
      widget.onBulkStockChanged?.call(asset, StockSummary.fromJson(summary));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _bulkBusy.remove(asset.tagId));
    }
  }

  Future<void> _disposeBulk(AssetItem asset) async {
    final input = await promptStockDisposal(context, asset);
    if (input == null) return;
    setState(() => _bulkBusy.add(asset.tagId));
    try {
      final summary = await ApiService.disposeStock(
        tagId: asset.tagId,
        quantity: input.quantity,
        reason: input.reason,
        performedBy: widget.adminName,
      );
      widget.onBulkStockChanged?.call(asset, StockSummary.fromJson(summary));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _bulkBusy.remove(asset.tagId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final maxWidth = isDesktop ? 1040.0 : double.infinity;
    final items = _stockItems;
    final bulkItems = _bulkBackupItems;
    final totalStock = widget.assets.where((a) => !a.isActiveInventory).length;
    final everythingEmpty = items.isEmpty && bulkItems.isEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Backup items'),
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
                      title: 'Backup items',
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
            if (everythingEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 40),
                  child: Center(
                    child: Text(
                      totalStock == 0
                          ? 'Nothing here yet.\nAdd an asset as a "Backup item", or use "Move to backup" '
                              'on an asset in the inventory, to file it here.'
                          : 'No backup items match your search.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.muted, fontSize: 15),
                    ),
                  ),
                ),
              )
            else ...[
              if (items.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 4, 28, 12),
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
              if (bulkItems.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 10),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Bulk items in backup',
                            style: TextStyle(
                              fontSize: 16 * Responsive.fontScale(context),
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkGreen,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    28,
                    0,
                    28,
                    Responsive.bottomScrollClearance(context),
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          children: [
                            for (final asset in bulkItems)
                              _BulkBackupCard(
                                asset: asset,
                                busy: _bulkBusy.contains(asset.tagId),
                                onReactivate: () => _reactivateBulk(asset),
                                onDispose: () => _disposeBulk(asset),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ] else
                SliverToBoxAdapter(
                  child: SizedBox(height: Responsive.bottomScrollClearance(context)),
                ),
            ],
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
              'Use "Move to active" to put one back into the borrowable inventory. Bulk '
              'pools with units set aside as backup are listed separately below — '
              'reactivate or permanently dispose of them here.',
              style: TextStyle(color: AppTheme.darkGreen, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row for a bulk pool with units set aside as backup — the bulk
/// counterpart to [AssetCard]'s individual-asset row on this same screen.
/// Offers "Move to active" (reactivate) and "Dispose" (permanent), both
/// only reachable from here — see the class doc on [StockItemsScreen].
class _BulkBackupCard extends StatelessWidget {
  const _BulkBackupCard({
    required this.asset,
    required this.busy,
    required this.onReactivate,
    required this.onDispose,
  });

  final AssetItem asset;
  final bool busy;
  final VoidCallback onReactivate;
  final VoidCallback onDispose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppTheme.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      asset.tagId,
                      style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.slateTint,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '${asset.quantityBackup} in backup',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : onReactivate,
                icon: const Icon(Icons.unarchive_outlined, size: 18),
                label: const Text('Move to active'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onDispose,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Dispose'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC84040),
                  side: const BorderSide(color: Color(0xFFC84040), width: 2),
                  minimumSize: const Size(0, 40),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
