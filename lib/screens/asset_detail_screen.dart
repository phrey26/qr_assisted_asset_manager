import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/status_chip.dart';

/// Full detail view for a single asset. Shows every field the admin
/// entered when the asset was created, plus the QR code generated for it
/// (with a "Download" action that saves/shares the QR as a PNG image).
class AssetDetailScreen extends StatefulWidget {
  const AssetDetailScreen({super.key, required this.asset, this.onDelete});

  final AssetItem asset;

  /// Invoked (after the "are you sure" dialog is confirmed) to remove this
  /// asset from the inventory once it's no longer usable. When null, no
  /// delete action is shown in the app bar.
  final VoidCallback? onDelete;

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  // Used to locate the rendered QR image so it can be captured as a PNG.
  final _qrBoundaryKey = GlobalKey();
  bool _saving = false;

  Future<void> _deleteAsset() async {
    final confirmed = await confirmAssetDeletion(context, widget.asset);
    if (!confirmed) return;
    widget.onDelete?.call();
    // Return to the inventory list now that the asset has been removed;
    // its detail page no longer has anything valid to show.
    if (mounted) Navigator.pop(context);
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

      final dir = await getTemporaryDirectory();
      final safeTag = widget.asset.tagId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final file = File('${dir.path}/qr_$safeTag.png');
      await file.writeAsBytes(bytes);

      // shareXFiles opens the native share/save sheet, letting the admin
      // save the QR to Photos/Files (mobile) or pick a save location
      // (desktop) rather than us guessing at storage permissions.
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'QR code for ${widget.asset.name} (${widget.asset.tagId})',
      );
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Asset details'),
        actions: [
          if (widget.onDelete != null)
            IconButton(
              onPressed: _deleteAsset,
              icon: const Icon(Icons.delete_outline),
              color: Colors.redAccent,
              tooltip: 'Remove from inventory',
            ),
        ],
      ),
      body: SafeArea(
        child: Responsive.isDesktop(context)
            ? _desktopBody(asset)
            : _mobileBody(asset),
      ),
    );
  }

  /// The mobile presentation remains a single column; this keeps its cards
  /// comfortably readable on a phone without desktop-only whitespace.
  Widget _mobileBody(AssetItem asset) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _assetHeading(asset),
            const SizedBox(height: 28),
            if (asset.isPastLifespan) ...[
              _lifespanWarningBanner(),
              const SizedBox(height: 20),
            ],
            if (asset.imageBytes != null) ...[
              _assetPhoto(asset),
              const SizedBox(height: 24),
            ],
            _infoCard(asset),
            const SizedBox(height: 24),
            _qrCard(),
          ],
        ),
      );

  /// Desktop uses a deliberately constrained, two-column layout rather than
  /// allowing the phone-sized information and QR cards to span the window.
  Widget _desktopBody(AssetItem asset) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(48, 42, 48, 56),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _assetHeading(asset, desktop: true),
                const SizedBox(height: 30),
                if (asset.isPastLifespan) ...[
                  _lifespanWarningBanner(),
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
                          _infoCard(asset, desktop: true),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                    SizedBox(width: 350, child: _qrCard(desktop: true)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _assetHeading(AssetItem asset, {bool desktop = false}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.name,
                  style: TextStyle(
                    color: AppTheme.darkGreen,
                    fontSize: desktop ? 32 : 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (desktop) ...[
                  const SizedBox(height: 6),
                  Text(
                    asset.tagId,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontFamily: 'monospace',
                      fontSize: 16,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          StatusChip(status: asset.status),
        ],
      );

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

  /// Banner shown when this asset is IT equipment past its expected
  /// [AssetItem.itEquipmentLifespanYears]-year lifespan, so the admin
  /// notices it during their review rather than having to check the
  /// purchase date by hand.
  Widget _lifespanWarningBanner() {
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
          Icon(Icons.warning_amber_rounded, color: Color(0xFFC84040)),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This asset is past its expected lifespan',
                  style: TextStyle(
                    color: Color(0xFFC84040),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'IT equipment is expected to last ${AssetItem.itEquipmentLifespanYears} years from its '
                  'date of purchase. Consider inspecting or replacing this item.',
                  style: TextStyle(color: Color(0xFFC84040), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(AssetItem asset, {bool desktop = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: desktop
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Asset information',
                  style: TextStyle(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _detailRow('Asset tag ID', asset.tagId, mono: true)),
                    Expanded(child: _detailRow('Category', asset.category)),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _detailRow('Date of purchase', asset.formattedPurchaseDate)),
                    Expanded(child: _detailRow('Status', asset.status.label)),
                  ],
                ),
                _detailRow(
                  'Description',
                  asset.description.isEmpty ? 'No description provided.' : asset.description,
                  isLast: true,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Asset tag ID', asset.tagId, mono: true),
                _detailRow('Category', asset.category),
                _detailRow('Date of purchase', asset.formattedPurchaseDate),
                _detailRow('Status', asset.status.label),
                _detailRow(
                  'Description',
                  asset.description.isEmpty ? 'No description provided.' : asset.description,
                  isLast: true,
                ),
              ],
            ),
    );
  }

  Widget _detailRow(String label, String value, {bool mono = false, bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
      child: Column(
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
          const Text(
            'Asset QR code',
            style: TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
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
              child: QrImageView(
                // The tag ID is what the scanner screen matches against,
                // so encoding it here keeps scan -> lookup consistent.
                data: widget.asset.tagId,
                version: QrVersions.auto,
                size: desktop ? 200 : 220,
                backgroundColor: Colors.white,
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
