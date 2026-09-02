import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/asset.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/status_chip.dart';

/// Full detail view for a single asset. Shows every field the admin
/// entered when the asset was created, plus the QR code generated for it
/// (with a "Download" action that saves the QR as a PNG image).
class AssetDetailScreen extends StatefulWidget {
  const AssetDetailScreen({
    super.key,
    required this.asset,
    this.onDelete,
    this.onUpdateStatus,
  });

  final AssetItem asset;

  /// Invoked (after the "are you sure" dialog is confirmed) to remove this
  /// asset from the inventory once it's no longer usable. When null, no
  /// delete action is shown in the app bar.
  final VoidCallback? onDelete;

  /// Invoked with the newly-picked status when the admin changes it from
  /// the status chip's menu (e.g. flagging the asset as under
  /// maintenance). When null, the chip is a plain read-only label.
  final ValueChanged<AssetStatus>? onUpdateStatus;

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  // Used to locate the rendered QR image so it can be captured as a PNG.
  final _qrBoundaryKey = GlobalKey();
  bool _saving = false;

  /// Applies the status change and refreshes this page. [widget.asset] is
  /// the same mutable object held by the inventory list (matched by
  /// tagId), so [onUpdateStatus] mutates it in place; since this page is a
  /// separate pushed route, it won't pick that up on its own the way the
  /// inventory list does via its own setState, so a local setState is
  /// needed here too — mirroring how [RequestDetailScreen] refreshes after
  /// approve/reject.
  void _changeStatus(AssetStatus status) {
    widget.onUpdateStatus?.call(status);
    setState(() {});
  }

  Future<void> _deleteAsset() async {
    final confirmed = await confirmAssetDeletion(context, widget.asset);
    if (!confirmed) return;
    widget.onDelete?.call();
    // Return to the inventory list now that the asset has been removed;
    // its detail page no longer has anything valid to show.
    if (mounted) Navigator.pop(context);
  }

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
          // On desktop there's plenty of room in the app bar for a proper,
          // legible button instead of a bare icon that's easy to miss next
          // to the back arrow. Mobile drops this entirely in favour of a
          // full-width button at the bottom of the page (see
          // `_deleteButton`) — a small icon crammed into a narrow phone
          // app bar is both easy to miss and easy to mis-tap.
          if (widget.onDelete != null && desktop)
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: OutlinedButton.icon(
                onPressed: _deleteAsset,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete asset'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC84040),
                  side: const BorderSide(color: Color(0xFFC84040), width: 2),
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
            if (asset.imageBytes != null) ...[
              _assetPhoto(asset),
              const SizedBox(height: 24),
            ],
            _infoCard(asset, categoryColor, categoryIcon),
            const SizedBox(height: 24),
            _qrCard(),
            if (widget.onDelete != null) ...[
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

  /// Full-width danger button for mobile, styled to match the app's other
  /// destructive actions (e.g. "Reject" on the request detail screen): a
  /// red outline rather than a bare icon, plus a short caption so it's
  /// unambiguous this can't be undone. This replaces the old app-bar icon,
  /// which was small, easy to miss, and easy to mis-tap next to the back
  /// arrow on a narrow phone screen.
  Widget _deleteButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _deleteAsset,
            icon: const Icon(Icons.delete_outline, size: 20),
            label: const Text('Remove asset'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC84040),
              side: const BorderSide(color: Color(0xFFC84040), width: 2),
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'This removes the asset from inventory and can\'t be undone.',
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
        StatusChip(
          status: asset.status,
          onChanged: widget.onUpdateStatus == null ? null : _changeStatus,
        ),
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
                    'Status',
                    asset.status.label,
                    icon: Icons.flag_outlined,
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
              'Status',
              asset.status.label,
              icon: Icons.flag_outlined,
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