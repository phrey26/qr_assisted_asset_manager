import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/asset.dart';
import '../models/asset_event.dart';
import '../models/asset_return.dart';
import '../models/category.dart';
import '../models/stock.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/asset_timeline.dart';
import '../widgets/asset_usage_view.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/status_chip.dart';
import '../widgets/stock_dialogs.dart';
import 'bulk_disposals_screen.dart';

/// Full detail view for a single asset. Shows every field the admin
/// entered when the asset was created, plus the QR code generated for it
/// (with a "Download" action that saves the QR as a PNG image).
class AssetDetailScreen extends StatefulWidget {
  const AssetDetailScreen({
    super.key,
    required this.asset,
    this.onEdit,
    this.onDelete,
    this.onActivate,
    this.onStockChanged,
    this.removalMode = AssetRemovalMode.retireToStock,
  });

  final AssetItem asset;

  /// Invoked when the admin taps "Edit" — opens the prefilled Add Asset
  /// form in edit mode. When null, no Edit action is shown.
  final VoidCallback? onEdit;

  /// Bulk assets only: invoked after a stock action (Add stock / Dispose /
  /// Correct count) succeeds, with the authoritative new totals so the
  /// inventory list can be updated without a reload.
  final void Function(StockSummary summary)? onStockChanged;

  /// Invoked with the admin's reason (and, for a retire-to-stock, whether
  /// it needs maintenance) once the removal dialog is confirmed. What it
  /// does depends on [removalMode] — retire to stock, or delete
  /// permanently. When null, no remove action is shown.
  final void Function(String reason, bool needsMaintenance)? onDelete;

  /// Invoked with the admin's reason to move a stock / maintenance asset
  /// back into the active, borrowable inventory. Wired up only when this
  /// page is opened from the stock-items list. When null, no "move to
  /// active" action is shown.
  final void Function(String reason)? onActivate;

  /// Whether the remove action on this page retires the asset to stock
  /// (opened from the inventory) or permanently deletes it (opened from the
  /// stock-items list).
  final AssetRemovalMode removalMode;

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  // Used to locate the rendered QR image so it can be captured as a PNG.
  final _qrBoundaryKey = GlobalKey();
  bool _saving = false;

  /// The asset's history, loaded lazily when this page opens (and refreshed
  /// after a status change made from here). Null while the first load is in
  /// flight; an error string if it failed.
  List<AssetEvent>? _events;
  String? _eventsError;
  bool _loadingEvents = true;

  /// The asset's condition & usage history (return inspections + summary),
  /// loaded lazily alongside the timeline.
  AssetReturnHistory? _usage;
  String? _usageError;
  bool _loadingUsage = true;

  /// Bulk assets only: stock state + ledger, loaded from `stock.php`.
  StockHistory? _stock;
  String? _stockError;
  bool _loadingStock = true;
  bool _stockBusy = false;

  bool get _isBulk => widget.asset.isBulk;

  @override
  void initState() {
    super.initState();
    if (_isBulk) {
      _loadStock();
    } else {
      _loadEvents();
      _loadUsage();
    }
  }

  Future<void> _loadStock() async {
    setState(() {
      _loadingStock = true;
      _stockError = null;
    });
    try {
      final data = await ApiService.fetchStockHistory(widget.asset.tagId);
      if (!mounted) return;
      setState(() {
        _stock = StockHistory.fromJson(data);
        _loadingStock = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stockError = '$e';
        _loadingStock = false;
      });
    }
  }

  Future<void> _runStockAction(Future<StockSummary> Function() action) async {
    setState(() => _stockBusy = true);
    try {
      final summary = await action();
      if (!mounted) return;
      widget.onStockChanged?.call(summary);
      await _loadStock();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _stockBusy = false);
    }
  }

  Future<void> _addStock() async {
    final input = await promptStockPurchase(context, widget.asset);
    if (input == null) return;
    await _runStockAction(() async {
      final s = await ApiService.addStock(
        tagId: widget.asset.tagId,
        quantity: input.quantity,
        supplier: input.supplier,
        note: input.note,
        purchasedAt: input.purchasedAt,
      );
      return StockSummary.fromJson(s);
    });
  }

  Future<void> _disposeStock() async {
    final input = await promptStockDisposal(context, widget.asset);
    if (input == null) return;
    await _runStockAction(() async {
      final s = await ApiService.disposeStock(
        tagId: widget.asset.tagId,
        quantity: input.quantity,
        reason: input.reason,
      );
      return StockSummary.fromJson(s);
    });
  }

  Future<void> _repairStock() async {
    final input = await promptStockRestore(context, widget.asset);
    if (input == null) return;
    await _runStockAction(() async {
      final s = await ApiService.restoreStock(
        tagId: widget.asset.tagId,
        quantity: input.quantity,
        note: input.note,
      );
      return StockSummary.fromJson(s);
    });
  }

  Future<void> _adjustStock() async {
    final input = await promptStockAdjust(context, widget.asset);
    if (input == null) return;
    await _runStockAction(() async {
      final s = await ApiService.adjustStock(
        tagId: widget.asset.tagId,
        newTotal: input.newTotal,
        reason: input.reason,
      );
      return StockSummary.fromJson(s);
    });
  }

  Future<void> _loadUsage() async {
    setState(() {
      _loadingUsage = true;
      _usageError = null;
    });
    try {
      final data = await ApiService.fetchAssetReturns(widget.asset.tagId);
      if (!mounted) return;
      setState(() {
        _usage = AssetReturnHistory.fromJson(data);
        _loadingUsage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usageError = '$e';
        _loadingUsage = false;
      });
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loadingEvents = true;
      _eventsError = null;
    });
    try {
      final rows = await ApiService.fetchAssetEvents(widget.asset.tagId);
      if (!mounted) return;
      setState(() {
        _events = rows.map(AssetEvent.fromJson).toList();
        _loadingEvents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _eventsError = '$e';
        _loadingEvents = false;
      });
    }
  }

  Future<void> _removeAsset() async {
    final choice = await promptAssetRemoval(context, widget.asset, widget.removalMode);
    if (choice == null) return;
    widget.onDelete?.call(choice.reason, choice.needsMaintenance);
    // Return to the previous list now that the asset has moved/gone — its
    // detail page no longer has anything valid to show.
    if (mounted) Navigator.pop(context);
  }

  Future<void> _activateAsset() async {
    final reason = await promptAssetActivation(context, widget.asset);
    if (reason == null) return;
    widget.onActivate?.call(reason);
    // The asset has left the stock list for the active inventory — this
    // page was pushed from the stock list, so pop back to it.
    if (mounted) Navigator.pop(context);
  }

  bool get _isDeleteMode => widget.removalMode == AssetRemovalMode.delete;

  /// The tint/icon pair to show for [category] — matched against the
  /// app's built-in categories first (covers every default category with
  /// its actual icon/color, the same as the Categories tab), and falling
  /// back to a color deterministically picked from the same tint palette
  /// for a custom category an admin added, so this page always reads with
  /// a category color instead of defaulting to something blank/gray.
  (Color, IconData) _categoryVisual(String category) {
    for (final c in AssetCategory.defaults) {
      if (c.matches(category)) return (c.color, c.icon);
    }
    final palette = AssetCategory.colorChoices;
    final index = category.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % palette.length;
    return (palette[index], Icons.category_outlined);
  }

  Future<void> _downloadQr() async {
    setState(() => _saving = true);
    try {
      final boundary = _qrBoundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      // pixelRatio 3 keeps the exported PNG crisp enough to print on a
      // physical asset label, not just view on-screen.
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final safeTag = widget.asset.tagId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final fileName = 'qr_$safeTag.png';

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        // The OS's own "Save file" flow — Android's Storage Access
        // Framework / iOS's document picker — rather than
        // `Share.shareXFiles`, which was opening the share sheet (Messages,
        // Gmail, AirDrop, ...) instead of actually saving anything. This
        // lets the admin pick a folder and writes the PNG straight there,
        // and needs no storage permission since the OS itself brokers the
        // write.
        final savedPath = await FlutterFileDialog.saveFile(
          params: SaveFileDialogParams(data: bytes, fileName: fileName),
        );
        if (mounted && savedPath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR code saved.')),
          );
        }
      } else {
        // Desktop: write straight to the user's Downloads folder, the same
        // way a browser download would — no share sheet or dialog needed.
        final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
        final file = File('${dir.path}${Platform.pathSeparator}$fileName');
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('QR code saved to ${file.path}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save QR code: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final desktop = Responsive.isDesktop(context);
    final (categoryColor, categoryIcon) = _categoryVisual(asset.category);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Asset details'),
        actions: [
          if (widget.onEdit != null)
            Padding(
              padding: EdgeInsets.only(right: desktop ? 12 : 4),
              child: desktop
                  ? OutlinedButton.icon(
                      onPressed: widget.onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70, width: 2),
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: widget.onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit asset',
                    ),
            ),
          // On desktop there's plenty of room in the app bar for proper,
          // legible buttons instead of bare icons that are easy to miss next
          // to the back arrow. Mobile drops these entirely in favour of
          // full-width buttons at the bottom of the page (see
          // `_deleteButton` / `_activateButton`) — a small icon crammed into
          // a narrow phone app bar is both easy to miss and easy to mis-tap.
          if (widget.onActivate != null && desktop && !asset.isActiveInventory)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton.icon(
                onPressed: _activateAsset,
                icon: const Icon(Icons.unarchive_outlined, size: 18),
                label: const Text('Move to active'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary, width: 2),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
          if (_canRemove && desktop)
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: OutlinedButton.icon(
                onPressed: _removeAsset,
                icon: Icon(
                  _isDeleteMode ? Icons.delete_outline : Icons.archive_outlined,
                  size: 18,
                ),
                label: Text(_isDeleteMode ? 'Delete asset' : 'Move to stock'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _isDeleteMode ? const Color(0xFFC84040) : AppTheme.primary,
                  side: BorderSide(
                    color: _isDeleteMode ? const Color(0xFFC84040) : AppTheme.primary,
                    width: 2,
                  ),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: desktop
            ? _desktopBody(asset, categoryColor, categoryIcon)
            : _mobileBody(asset, categoryColor, categoryIcon),
      ),
    );
  }

  /// The mobile presentation remains a single column; this keeps its cards
  /// comfortably readable on a phone without desktop-only whitespace. It
  /// keeps the category avatar compact (no hero banner) — that
  /// richer treatment is desktop-only, in [_desktopBody] — so the two
  /// platforms carry a related but distinctly different look, not just a
  /// different column count.
  Widget _mobileBody(AssetItem asset, Color categoryColor, IconData categoryIcon) =>
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _assetHeading(asset, categoryColor, categoryIcon),
            const SizedBox(height: 28),
            if (asset.isPastLifespan) ...[
              _lifespanWarningBanner(),
              const SizedBox(height: 20),
            ],
            if (asset.isDamaged) ...[
              _damagedWarningBanner(),
              const SizedBox(height: 20),
            ],
            if (_isBulk && asset.hasDamagedStock) ...[
              _damagedStockBanner(),
              const SizedBox(height: 20),
            ],
            if (_isBulk && asset.isLowStock) ...[
              _lowStockBanner(),
              const SizedBox(height: 20),
            ],
            if (asset.imageBytes != null) ...[
              _assetPhoto(asset),
              const SizedBox(height: 24),
            ],
            _infoCard(asset, categoryColor, categoryIcon),
            const SizedBox(height: 24),
            _custodyCard(asset),
            const SizedBox(height: 24),
            if (_isBulk) _stockCard() else _usageCard(),
            const SizedBox(height: 24),
            _qrCard(),
            const SizedBox(height: 24),
            if (_isBulk) _stockLedgerCard() else _timelineCard(),
            if (widget.onActivate != null && !asset.isActiveInventory) ...[
              const SizedBox(height: 24),
              _activateButton(),
            ],
            if (_canRemove) ...[
              const SizedBox(height: 24),
              _deleteButton(),
            ],
          ],
        ),
      );

  /// Desktop uses a deliberately constrained, two-column layout rather than
  /// allowing the phone-sized information and QR cards to span the window.
  /// The heading also gets a soft category-tinted "hero" treatment
  /// here that mobile intentionally skips (see [_mobileBody]).
  Widget _desktopBody(AssetItem asset, Color categoryColor, IconData categoryIcon) =>
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(48, 42, 48, 56),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _assetHeading(asset, categoryColor, categoryIcon, desktop: true),
                const SizedBox(height: 30),
                if (asset.isPastLifespan) ...[
                  _lifespanWarningBanner(),
                  const SizedBox(height: 24),
                ],
                if (asset.isDamaged) ...[
                  _damagedWarningBanner(),
                  const SizedBox(height: 24),
                ],
                if (_isBulk && asset.hasDamagedStock) ...[
                  _damagedStockBanner(),
                  const SizedBox(height: 24),
                ],
                if (_isBulk && asset.isLowStock) ...[
                  _lowStockBanner(),
                  const SizedBox(height: 24),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (asset.imageBytes != null) ...[
                            _assetPhoto(asset, desktop: true),
                            const SizedBox(height: 24),
                          ],
                          _infoCard(asset, categoryColor, categoryIcon, desktop: true),
                          const SizedBox(height: 24),
                          _custodyCard(asset, desktop: true),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                    SizedBox(width: 350, child: _qrCard(desktop: true)),
                  ],
                ),
                const SizedBox(height: 24),
                if (_isBulk) _stockCard(desktop: true) else _usageCard(desktop: true),
                const SizedBox(height: 24),
                if (_isBulk)
                  _stockLedgerCard(desktop: true)
                else
                  _timelineCard(desktop: true),
              ],
            ),
          ),
        ),
      );

  /// Whether the remove button should show. A bulk pool can only be removed
  /// once it's been fully run down (nothing owned, nothing out).
  bool get _canRemove {
    if (widget.onDelete == null) return false;
    if (!_isBulk) return true;
    return (widget.asset.quantityTotal ?? 0) == 0 && widget.asset.quantityOut == 0;
  }

  Widget _stockPill(AssetItem asset) {
    final low = asset.isLowStock || asset.quantityAvailable <= 0;
    final (bg, fg) = low
        ? (AppTheme.redTint, const Color(0xFFC84040))
        : (AppTheme.mint, AppTheme.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
      child: Text(
        asset.stockLabel,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 14),
      ),
    );
  }

  Widget _damagedStockBanner() {
    final asset = widget.asset;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.redTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3C6C4), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.report_gmailerrorred_outlined, color: Color(0xFFC84040)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${asset.quantityDamaged} unit(s) set aside damaged',
                  style: const TextStyle(
                    color: Color(0xFFC84040),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'These came back from a loan damaged and aren\'t lendable. In the '
                  'Stock card below, use "Repair" to return the fixed ones to stock, '
                  'or "Dispose" to write them off.',
                  style: TextStyle(color: Color(0xFFC84040), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lowStockBanner() {
    final asset = widget.asset;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.redTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3C6C4), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.inventory_2_outlined, color: Color(0xFFC84040)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Running low on stock',
                  style: TextStyle(
                    color: Color(0xFFC84040),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Only ${asset.quantityAvailable} available'
                  '${asset.reorderPoint == null ? '' : ', at or below the reorder point of ${asset.reorderPoint}'}'
                  '. Use "Add stock" once more has been bought.',
                  style: const TextStyle(color: Color(0xFFC84040), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The bulk counterpart to [_usageCard]: current levels, the buy / dispose
  /// / correct actions, and a link to the permanent disposal log.
  Widget _stockCard({bool desktop = false}) {
    final asset = widget.asset;
    final summary = _stock?.summary;
    final total = summary?.total ?? asset.quantityTotal ?? 0;
    final out = summary?.out ?? asset.quantityOut;
    final damaged = summary?.damaged ?? asset.quantityDamaged;
    final available = summary?.available ?? asset.quantityAvailable;

    Widget stat(String label, String value, Color color) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 22),
              ),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
            ],
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionHeader(
                  'Stock',
                  icon: Icons.inventory_2_outlined,
                  tint: AppTheme.mint,
                  iconColor: AppTheme.primary,
                  desktop: desktop,
                ),
              ),
              IconButton(
                onPressed: _loadingStock ? null : _loadStock,
                icon: const Icon(Icons.refresh, size: 20),
                color: AppTheme.muted,
                tooltip: 'Refresh',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          SizedBox(height: desktop ? 16 : 12),
          if (_stockError != null && _stock == null)
            Text(_stockError!, style: const TextStyle(color: Color(0xFFC84040), fontSize: 13))
          else
            Row(
              children: [
                stat('Owned', '$total', AppTheme.darkGreen),
                stat('On loan', '$out', const Color(0xFF9A6512)),
                if (damaged > 0) stat('Damaged', '$damaged', const Color(0xFFC84040)),
                stat('Available', '$available',
                    asset.isLowStock ? const Color(0xFFC84040) : AppTheme.primary),
              ],
            ),
          if (asset.reorderPoint != null) ...[
            const SizedBox(height: 10),
            Text(
              'Reorder point: ${asset.reorderPoint}',
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _stockBusy ? null : _addStock,
                icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
                label: const Text('Add stock'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
              if (damaged > 0)
                OutlinedButton.icon(
                  onPressed: _stockBusy ? null : _repairStock,
                  icon: const Icon(Icons.healing_outlined, size: 18),
                  label: Text('Repair ($damaged)'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                ),
              OutlinedButton.icon(
                onPressed: _stockBusy || (available <= 0 && damaged <= 0)
                    ? null
                    : _disposeStock,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Dispose'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC84040),
                  side: const BorderSide(color: Color(0xFFC84040), width: 2),
                  minimumSize: const Size(0, 44),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _stockBusy ? null : _adjustStock,
                icon: const Icon(Icons.tune_outlined, size: 18),
                label: const Text('Correct count'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BulkDisposalsScreen()),
                ),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Disposal log'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The bulk counterpart to [_timelineCard]: the stock ledger (purchases,
  /// loans, returns, disposals) newest first.
  Widget _stockLedgerCard({bool desktop = false}) {
    final movements = _stock?.movements ?? const <StockMovement>[];
    final Widget body;
    if (_loadingStock && _stock == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_stockError != null && _stock == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Could not load the stock history.',
              style: TextStyle(color: AppTheme.muted, fontSize: 14)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loadStock,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try again'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
          ),
        ],
      );
    } else if (movements.isEmpty) {
      body = const Text('No stock movements yet.',
          style: TextStyle(color: AppTheme.muted, fontSize: 14));
    } else {
      body = Column(
        children: [for (final m in movements) _LedgerRow(movement: m)],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionHeader(
                  'Stock history',
                  icon: Icons.history,
                  tint: AppTheme.mint,
                  iconColor: AppTheme.primary,
                  desktop: desktop,
                ),
              ),
              IconButton(
                onPressed: _loadingStock ? null : _loadStock,
                icon: const Icon(Icons.refresh, size: 20),
                color: AppTheme.muted,
                tooltip: 'Refresh',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          SizedBox(height: desktop ? 18 : 14),
          body,
        ],
      ),
    );
  }

  /// Full-width remove button for mobile. In stock-items ("delete") mode it
  /// carries the app's danger styling (red outline, "can't be undone"
  /// caption); from the inventory it's the calmer "move to stock" action.
  Widget _deleteButton() {
    final danger = _isDeleteMode;
    final color = danger ? const Color(0xFFC84040) : AppTheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _removeAsset,
            icon: Icon(danger ? Icons.delete_outline : Icons.archive_outlined, size: 20),
            label: Text(danger ? 'Delete asset' : 'Move to stock'),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color, width: 2),
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          danger
              ? 'This permanently removes the asset and can\'t be undone.'
              : 'This moves the asset out of active inventory into stock. '
                  'You\'ll be asked why.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
      ],
    );
  }

  /// Full-width "move to active" button for mobile — the counterpart to
  /// [_deleteButton], shown only when this page was opened from the stock
  /// list for an asset that isn't in the active inventory.
  Widget _activateButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _activateAsset,
            icon: const Icon(Icons.unarchive_outlined, size: 20),
            label: const Text('Move to active inventory'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'This puts the asset back into the borrowable inventory. You\'ll be asked why.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
      ],
    );
  }

  /// Desktop gets a full "hero" card — a soft, flat category-tinted
  /// wash behind a larger category avatar, the name, and the tag ID —
  /// while mobile keeps a plain background with just a compact avatar, so
  /// the two platforms read as related but visually distinct rather than
  /// the same row simply resized.
  Widget _assetHeading(
    AssetItem asset,
    Color categoryColor,
    IconData categoryIcon, {
    bool desktop = false,
  }) {
    final avatar = Container(
      width: desktop ? 64 : 48,
      height: desktop ? 64 : 48,
      decoration: BoxDecoration(color: categoryColor, shape: BoxShape.circle),
      child: Icon(categoryIcon, color: AppTheme.primary, size: desktop ? 28 : 22),
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        avatar,
        SizedBox(width: desktop ? 20 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                asset.name,
                style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontSize: desktop ? 32 : 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                asset.tagId,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontFamily: 'monospace',
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (_isBulk) _stockPill(asset) else StatusChip(status: asset.status),
      ],
    );

    if (!desktop) return row;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: categoryColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: row,
    );
  }

  Widget _assetPhoto(AssetItem asset, {bool desktop = false}) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: desktop ? 16 / 9 : 4 / 3,
          child: Image.memory(
            asset.imageBytes!,
            fit: BoxFit.cover,
            semanticLabel: 'Photo of ${asset.name}',
          ),
        ),
      );

  /// Banner shown when this asset is past the expected lifespan set on its
  /// category, so the admin notices it during their review rather than
  /// having to check the purchase date by hand.
  Widget _lifespanWarningBanner() {
    final years = widget.asset.lifespanYears;
    final detail = years == null
        ? 'This asset is past the expected lifespan set for its category. '
            'Consider inspecting or replacing it.'
        : '${widget.asset.category} assets are expected to last $years years from their '
            'date of purchase. Consider inspecting or replacing this item.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.redTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3C6C4), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFC84040)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This asset is past its expected lifespan',
                  style: TextStyle(
                    color: Color(0xFFC84040),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(color: Color(0xFFC84040), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Banner shown when this asset's most recent return inspection marked it
  /// damaged — mirrors [_lifespanWarningBanner] so both "needs attention"
  /// cases read the same on this page. The full inspection (photos, notes)
  /// is in the "Condition & usage" card below.
  Widget _damagedWarningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.redTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3C6C4), width: 2),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.build_circle_outlined, color: Color(0xFFC84040)),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This asset was last returned damaged',
                  style: TextStyle(
                    color: Color(0xFFC84040),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Inspect it against the return photos below before lending it out again, '
                  'or send it for maintenance.',
                  style: TextStyle(color: Color(0xFFC84040), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Where the asset is: its home location, who's responsible for it, who
  /// currently has it on loan, and where it was last physically seen (from
  /// the scan "sighting" flow). This is the "help me find it" card.
  Widget _custodyCard(AssetItem asset, {bool desktop = false}) {
    String orDash(String? v) => (v == null || v.isEmpty) ? 'Not recorded' : v;

    final holderParts = <String>[
      if (asset.currentHolder != null) asset.currentHolder!,
      if (asset.currentHolderDepartment != null) asset.currentHolderDepartment!,
    ];
    var holderText = holderParts.join(' · ');
    if (asset.dueBack != null) holderText += '\nDue back ${asset.dueBack}';

    final seenAt = asset.formattedLastScannedAt;
    final String lastSeenText;
    if (seenAt == null) {
      lastSeenText = 'Never scanned';
    } else {
      final where = asset.lastLocation ?? 'Location not recorded';
      lastSeenText = '$where\n$seenAt';
    }

    final rows = <Widget>[
      _detailRow(
        'Home location',
        orDash(asset.homeLocation),
        icon: Icons.place_outlined,
        tint: AppTheme.mint,
        iconColor: AppTheme.primary,
      ),
      _detailRow(
        'Person responsible',
        orDash(asset.custodian),
        icon: Icons.person_outline,
        tint: AppTheme.cream,
        iconColor: const Color(0xFF9A6512),
      ),
      if (!asset.isBulk && asset.currentHolder != null)
        _detailRow(
          'Currently with',
          holderText,
          icon: Icons.assignment_ind_outlined,
          tint: AppTheme.cream,
          iconColor: const Color(0xFF9A6512),
        ),
      _detailRow(
        'Last seen',
        lastSeenText,
        icon: Icons.qr_code_scanner,
        tint: AppTheme.mint,
        iconColor: AppTheme.primary,
        isLast: true,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Location & custody',
            icon: Icons.travel_explore,
            tint: AppTheme.mint,
            iconColor: AppTheme.primary,
            desktop: desktop,
          ),
          SizedBox(height: desktop ? 22 : 16),
          ...rows,
        ],
      ),
    );
  }

  Widget _infoCard(
    AssetItem asset,
    Color categoryColor,
    IconData categoryIcon, {
    bool desktop = false,
  }) {
    final (statusBg, statusFg) = StatusChip.colorsFor(asset.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Asset information',
            icon: Icons.info_outline,
            tint: AppTheme.mint,
            iconColor: AppTheme.primary,
            desktop: desktop,
          ),
          SizedBox(height: desktop ? 22 : 16),
          if (desktop) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _detailRow(
                    'Asset tag ID',
                    asset.tagId,
                    mono: true,
                    icon: Icons.confirmation_number_outlined,
                    tint: AppTheme.mint,
                    iconColor: AppTheme.primary,
                  ),
                ),
                Expanded(
                  child: _detailRow(
                    'Category',
                    asset.category,
                    icon: categoryIcon,
                    tint: categoryColor,
                    iconColor: AppTheme.primary,
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _detailRow(
                    'Date of purchase',
                    asset.formattedPurchaseDate,
                    icon: Icons.event_outlined,
                    tint: AppTheme.cream,
                    iconColor: const Color(0xFF9A6512),
                  ),
                ),
                Expanded(
                  child: _detailRow(
                    _isBulk ? 'Stock' : 'Status',
                    _isBulk ? asset.stockLabel : asset.status.label,
                    icon: _isBulk ? Icons.inventory_2_outlined : Icons.flag_outlined,
                    tint: statusBg,
                    iconColor: statusFg,
                  ),
                ),
              ],
            ),
            _detailRow(
              'Description',
              asset.description.isEmpty ? 'No description provided.' : asset.description,
              icon: Icons.notes_outlined,
              tint: AppTheme.border,
              iconColor: AppTheme.muted,
              isLast: true,
            ),
          ] else ...[
            _detailRow(
              'Asset tag ID',
              asset.tagId,
              mono: true,
              icon: Icons.confirmation_number_outlined,
              tint: AppTheme.mint,
              iconColor: AppTheme.primary,
            ),
            _detailRow(
              'Category',
              asset.category,
              icon: categoryIcon,
              tint: categoryColor,
              iconColor: AppTheme.primary,
            ),
            _detailRow(
              'Date of purchase',
              asset.formattedPurchaseDate,
              icon: Icons.event_outlined,
              tint: AppTheme.cream,
              iconColor: const Color(0xFF9A6512),
            ),
            _detailRow(
              _isBulk ? 'Stock' : 'Status',
              _isBulk ? asset.stockLabel : asset.status.label,
              icon: _isBulk ? Icons.inventory_2_outlined : Icons.flag_outlined,
              tint: statusBg,
              iconColor: statusFg,
            ),
            _detailRow(
              'Description',
              asset.description.isEmpty ? 'No description provided.' : asset.description,
              icon: Icons.notes_outlined,
              tint: AppTheme.border,
              iconColor: AppTheme.muted,
              isLast: true,
            ),
          ],
        ],
      ),
    );
  }

  /// A small colored icon badge next to a card's title — the same
  /// "icon-on-a-tint-circle" language used for the category avatar and
  /// each detail row, so a section header reads as part of the same
  /// design rather than a plain label. Mobile uses a slightly smaller
  /// badge/title than desktop.
  Widget _sectionHeader(
    String title, {
    required IconData icon,
    required Color tint,
    required Color iconColor,
    bool desktop = false,
  }) {
    final size = desktop ? 34.0 : 30.0;
    return Row(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: desktop ? 18 : 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: AppTheme.darkGreen,
            fontWeight: FontWeight.w800,
            fontSize: desktop ? 18 : 16,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool mono = false,
    bool isLast = false,
    IconData? icon,
    Color? tint,
    Color? iconColor,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkGreen,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.muted,
            fontFamily: mono ? 'monospace' : null,
            fontSize: 16,
          ),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 18, right: 10),
      child: icon == null
          ? content
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: tint ?? AppTheme.mint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: iconColor ?? AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(child: content),
              ],
            ),
    );
  }

  /// The asset's condition & usage: how many times it's been borrowed,
  /// total days out, its latest inspected condition, plus each return
  /// inspection with its photos — so wear from real use is visible, not
  /// just the fixed 5-year lifespan warning.
  Widget _usageCard({bool desktop = false}) {
    final Widget body;
    if (_loadingUsage && _usage == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_usageError != null && _usage == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Could not load the usage history.',
            style: TextStyle(color: AppTheme.muted, fontSize: 14),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loadUsage,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try again'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
          ),
        ],
      );
    } else {
      body = AssetUsageView(
        history: _usage ??
            AssetReturnHistory(
              summary: AssetUsageSummary(
                timesBorrowed: 0,
                daysUsed: 0,
                currentlyOut: false,
              ),
              inspections: const [],
            ),
        asset: widget.asset,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionHeader(
                  'Condition & usage',
                  icon: Icons.timeline,
                  tint: AppTheme.cream,
                  iconColor: const Color(0xFF9A6512),
                  desktop: desktop,
                ),
              ),
              IconButton(
                onPressed: _loadingUsage ? null : _loadUsage,
                icon: _loadingUsage && _usage != null
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 20),
                color: AppTheme.muted,
                tooltip: 'Refresh',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          SizedBox(height: desktop ? 18 : 14),
          body,
        ],
      ),
    );
  }

  /// The asset's history — every recorded change (added, borrowed,
  /// returned, maintenance, moved to stock, …) with its date. Loaded from
  /// `asset_events.php` when the page opens; can be pulled again with the
  /// refresh button in the header.
  Widget _timelineCard({bool desktop = false}) {
    final Widget body;
    if (_loadingEvents && _events == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_eventsError != null && _events == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Could not load the timeline.',
            style: TextStyle(color: AppTheme.muted, fontSize: 14),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loadEvents,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try again'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
          ),
        ],
      );
    } else {
      body = AssetTimeline(events: _events ?? const []);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionHeader(
                  'Timeline',
                  icon: Icons.history,
                  tint: AppTheme.mint,
                  iconColor: AppTheme.primary,
                  desktop: desktop,
                ),
              ),
              IconButton(
                onPressed: _loadingEvents ? null : _loadEvents,
                icon: _loadingEvents && _events != null
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 20),
                color: AppTheme.muted,
                tooltip: 'Refresh timeline',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          SizedBox(height: desktop ? 18 : 14),
          body,
        ],
      ),
    );
  }

  Widget _qrCard({bool desktop = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.mint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_2, size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              const Text(
                'Asset QR code',
                style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Scan this tag to look up the asset, or download it to print on a physical label.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted, fontSize: 14),
          ),
          const SizedBox(height: 20),
          RepaintBoundary(
            key: _qrBoundaryKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // The tag ID printed above the QR in the exported image
                  // too, as a fallback for when a scanner can't read the
                  // code and the ID has to be typed in by hand instead.
                  Text(
                    widget.asset.tagId,
                    style: const TextStyle(
                      color: AppTheme.darkGreen,
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  QrImageView(
                    // The tag ID is what the scanner screen matches against,
                    // so encoding it here keeps scan -> lookup consistent.
                    data: widget.asset.tagId,
                    version: QrVersions.auto,
                    size: desktop ? 200 : 220,
                    backgroundColor: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _downloadQr,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download),
              label: Text(_saving ? 'Preparing...' : 'Download QR code'),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row in a bulk asset's stock ledger — a dot with the movement's icon,
/// its label + note, the signed quantity, and the date.
class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.movement});

  final StockMovement movement;

  String _formatTimestamp(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $h:$m $ap';
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = movement.kind.colors;
    final positive = movement.quantityDelta >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(movement.kind.icon, size: 18, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        movement.kind.label,
                        style: const TextStyle(
                          color: AppTheme.darkGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      movement.deltaLabel,
                      style: TextStyle(
                        color: positive ? AppTheme.primary : const Color(0xFFC84040),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTimestamp(movement.timestamp) +
                      (movement.balanceAfter == null
                          ? ''
                          : '  ·  ${movement.balanceAfter} on hand'),
                  style: const TextStyle(color: AppTheme.muted, fontSize: 11.5),
                ),
                if (movement.note != null && movement.note!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    movement.note!,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 12.5, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}