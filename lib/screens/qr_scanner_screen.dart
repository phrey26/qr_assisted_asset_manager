import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import '../utils/camera_support.dart';
import '../utils/responsive.dart';
import '../widgets/camera_qr_view.dart';
import '../widgets/status_chip.dart';
import 'qr_scan_result_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({
    super.key,
    required this.assets,
    this.isActive = true,
    this.onSighting,
  });

  /// The current inventory, including assets created during this session.
  final List<AssetItem> assets;

  /// Records that an admin scanned an asset and, optionally, where they
  /// found it — forwarded to the scan result (dialog on desktop, page on
  /// mobile) so a scan can update the asset's "last seen".
  final void Function(AssetItem asset, String? location)? onSighting;

  /// Whether the Scanner tab is the one currently on screen. This screen
  /// lives in [AppShell]'s IndexedStack, which keeps every tab mounted at
  /// once, so it can't just start the camera in initState — that would pop
  /// the OS permission prompt at app launch. The live-camera widget is
  /// only mounted while this is true (the admin actually opening the tab),
  /// and unmounting it when this goes false releases the camera.
  final bool isActive;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  // Which scanning backend this platform can use. mobile_scanner covers
  // Android/iOS/macOS/web; Windows has no mobile_scanner implementation so
  // it falls back to the camera + zxing2 decoder in [CameraQrView]; if
  // neither is available only manual tag entry is offered.
  late final bool _useMobileScanner = mobileScannerSupported;
  late final bool _useCameraFallback =
      !_useMobileScanner && nativeCameraSupported;

  // Only created on platforms that can actually use it. autoStart lets the
  // MobileScanner widget itself start the camera when it mounts and stop
  // it when it unmounts, so simply not rendering that widget (tab inactive,
  // or a result on screen) is what keeps the camera off.
  MobileScannerController? _scannerController;

  final tagController = TextEditingController();

  // True while a scan result is being shown (the desktop mini window, or
  // the mobile result page). Guards against onDetect firing repeatedly for
  // the same code — which it does many times a second while the tag is in
  // frame — from opening several dialogs/pages at once, and drops the
  // camera preview while the result is up.
  bool _isShowingResult = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_useMobileScanner) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController?.dispose();
    tagController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // [CameraQrView] handles its own lifecycle. For the mobile_scanner
    // path we own the controller (so the widget doesn't observe lifecycle
    // itself), so release the camera when the app is backgrounded and
    // bring it back on resume.
    final controller = _scannerController;
    if (controller == null || !widget.isActive || _isShowingResult) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _safe(controller.start);
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _safe(controller.stop);
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // start()/stop() races (already started / already stopped) are
      // surfaced through MobileScanner's own errorBuilder instead.
    }
  }

  String _messageFor(MobileScannerException e) {
    final code = e.errorCode.name.toLowerCase();
    if (code.contains('permission')) {
      return 'Camera access is turned off for this app. Please allow camera access to scan asset tags.';
    }
    if (code.contains('unsupported')) {
      return 'This device does not have a usable camera for scanning.';
    }
    return 'Could not access the camera. Please check your camera permission and try again.';
  }

  void _onBarcode(BarcodeCapture capture) {
    final code =
        capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (code != null) _handleTag(code);
  }

  /// Looks up [value] against the current inventory and shows the result —
  /// a "mini window" dialog on desktop, or a dedicated full page on mobile
  /// (see [QrScanResultScreen]). Called both from the camera's onDetect and
  /// from manual tag-ID entry.
  void _handleTag(String value) {
    final tag = value.trim();
    if (tag.isEmpty || _isShowingResult) return;

    AssetItem? found;
    for (final asset in widget.assets) {
      if (asset.tagId.toLowerCase() == tag.toLowerCase()) {
        found = asset;
        break;
      }
    }

    if (Responsive.isDesktop(context)) {
      _showScanResultDialog(tag, found);
    } else {
      _openScanResultPage(tag, found);
    }
  }

  /// Desktop: pops the "mini window" over the scan screen. Closing it (the
  /// X button, tapping outside, or Esc) returns straight back to a
  /// scanning-ready state.
  Future<void> _showScanResultDialog(String tag, AssetItem? asset) async {
    setState(() => _isShowingResult = true);
    await showDialog<void>(
      context: context,
      builder: (_) => _ScanResultDialog(
        tag: tag,
        asset: asset,
        onSighting: widget.onSighting,
      ),
    );
    if (!mounted) return;
    setState(() => _isShowingResult = false);
  }

  /// Mobile: pushes a full page with the asset's details. Coming back
  /// (the app-bar back arrow or the "Back to scanner" button) returns to a
  /// scanning-ready state.
  Future<void> _openScanResultPage(String tag, AssetItem? asset) async {
    setState(() => _isShowingResult = true);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QrScanResultScreen(
          tag: tag,
          asset: asset,
          onSighting: widget.onSighting,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _isShowingResult = false);
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
                child: Text(
                  'Scan asset',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.darkGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 32,
                      ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 24),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Text(
                  isDesktop
                      ? 'Point the camera at an asset tag, or enter its ID manually'
                      : 'Point the camera at an asset tag',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 19),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: isDesktop ? _desktopSplit() : _scanColumn(),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: isDesktop ? 40 : 100)),
      ],
    );
  }

  // --- Desktop: scanner + manual entry on the left, live details panel on
  // the right, matching the hi-fi desktop mockups' split layout. ---
  Widget _desktopSplit() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 11, child: _scanColumn()),
        const SizedBox(width: 24),
        Expanded(flex: 9, child: _detailsPanel()),
      ],
    );
  }

  bool get _canScan => _useMobileScanner || _useCameraFallback;

  Widget _scanColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: SizedBox(
            height: 340,
            width: double.infinity,
            // Only mount the live-camera widget once the tab is open — see
            // [QrScannerScreen.isActive].
            child: widget.isActive ? _cameraArea() : _cameraLoading(),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            _canScan
                ? 'Align the QR tag within the frame'
                : 'Enter the asset tag ID below to look one up',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.darkGreen, fontSize: 16),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(child: Divider(color: AppTheme.border, thickness: 2)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'or enter tag ID manually',
                style: TextStyle(color: AppTheme.muted, fontSize: 15),
              ),
            ),
            Expanded(child: Divider(color: AppTheme.border, thickness: 2)),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: tagController,
          textInputAction: TextInputAction.search,
          onSubmitted: _handleTag,
          decoration: InputDecoration(
            hintText: 'CSDO-IT1-0231',
            suffixIcon: IconButton(
              onPressed: () => _handleTag(tagController.text),
              icon: const Icon(Icons.arrow_forward),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cameraLoading() {
    return Container(
      color: AppTheme.mint,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(color: AppTheme.primary),
    );
  }

  /// Picks the right camera backend for this platform, or the manual-only
  /// notice when there's no camera path at all.
  Widget _cameraArea() {
    if (_useMobileScanner) return _mobileScannerArea();
    if (_useCameraFallback) {
      return CameraQrView(
        onDetect: _handleTag,
        paused: _isShowingResult,
        overlay: CustomPaint(painter: _ScannerOverlayPainter()),
      );
    }
    return _manualOnlyNotice();
  }

  Widget _mobileScannerArea() {
    final controller = _scannerController!;
    // While a result is on screen the MobileScanner widget is dropped so
    // the camera is released; it restarts (autoStart) when it remounts.
    if (_isShowingResult) {
      return const ColoredBox(color: AppTheme.mint);
    }
    return MobileScanner(
      controller: controller,
      onDetect: _onBarcode,
      placeholderBuilder: (context, child) => _cameraLoading(),
      errorBuilder: (context, error, child) =>
          _cameraAccessNeeded(_messageFor(error)),
      overlayBuilder: (context, constraints) => _scannerOverlay(controller),
    );
  }

  Widget _scannerOverlay(MobileScannerController controller) {
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(child: CustomPaint(painter: _ScannerOverlayPainter())),
        Positioned(
          top: 16,
          right: 16,
          child: ValueListenableBuilder<MobileScannerState>(
            valueListenable: controller,
            builder: (context, state, _) {
              if (state.torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              final on = state.torchState == TorchState.on;
              return IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _safe(controller.toggleTorch),
                icon: Icon(on ? Icons.flash_on : Icons.flash_off),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Shown by [MobileScanner]'s errorBuilder — most commonly camera
  /// permission not granted / denied. Offers a one-tap retry.
  Widget _cameraAccessNeeded(String message) {
    return Container(
      color: AppTheme.redTint,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined,
                color: Color(0xFFC84040), size: 40),
            const SizedBox(height: 14),
            const Text(
              'Camera access needed',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.darkGreen,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Check your device or browser settings for this app\'s camera permission, then try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _safe(_scannerController!.start),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ],
        ),
      ),
    );
  }

  /// No camera backend on this platform (e.g. Linux) — manual tag entry
  /// only. Neutral styling, not the red "access needed" panel.
  Widget _manualOnlyNotice() {
    return Container(
      color: AppTheme.mint,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.keyboard_alt_outlined, color: AppTheme.primary, size: 40),
          SizedBox(height: 14),
          Text(
            'Camera scanning isn\'t available on this platform',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Enter the asset tag ID in the field below instead.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Idle placeholder for the desktop details panel. Since a scan now pops
  /// the "mini window" ([_ScanResultDialog]) instead of filling this panel,
  /// it only ever needs to show this waiting state — closing the dialog
  /// returns [QrScannerScreen] to exactly this.
  Widget _detailsPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'Scan a tag or enter an ID — the asset details will pop up here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted),
          ),
        ),
      ),
    );
  }
}

/// Desktop's "mini window" — shown as a dialog over [QrScannerScreen] when
/// a tag is scanned or entered manually. Holds the same information as
/// [QrScanResultScreen] (the mobile equivalent), just presented as a
/// dismissible popup instead of a full page. Closing it (the X button,
/// tapping outside, or Esc) returns the scan screen to a fresh
/// scanning-ready state.
class _ScanResultDialog extends StatefulWidget {
  const _ScanResultDialog({
    required this.tag,
    required this.asset,
    this.onSighting,
  });

  final String tag;
  final AssetItem? asset;
  final void Function(AssetItem asset, String? location)? onSighting;

  @override
  State<_ScanResultDialog> createState() => _ScanResultDialogState();
}

class _ScanResultDialogState extends State<_ScanResultDialog> {
  final _location = TextEditingController();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _location.text = widget.asset?.lastLocation ?? '';
  }

  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  void _recordSighting() {
    final asset = widget.asset;
    if (asset == null || widget.onSighting == null) return;
    final loc = _location.text.trim();
    widget.onSighting!(asset, loc.isEmpty ? null : loc);
    setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      asset == null ? 'No asset found' : asset.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.darkGreen,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (asset != null) ...[
                    const SizedBox(width: 10),
                    if (asset.isBulk)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: asset.isLowStock ? AppTheme.redTint : AppTheme.mint,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          asset.stockLabel,
                          style: TextStyle(
                            color: asset.isLowStock
                                ? const Color(0xFFC84040)
                                : AppTheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      StatusChip(status: asset.status),
                  ],
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (asset == null)
                Text(
                  'No asset in the inventory matches the tag "${widget.tag}".',
                  style: const TextStyle(color: Color(0xFFC84040), fontWeight: FontWeight.w600),
                )
              else ...[
                if (asset.imageBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.memory(asset.imageBytes!, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _detailRow('Asset tag ID', asset.tagId, mono: true),
                _detailRow('Category', asset.category),
                _detailRow('Date of purchase', asset.formattedPurchaseDate),
                if (asset.homeLocation != null)
                  _detailRow('Home location', asset.homeLocation!),
                if (!asset.isBulk && asset.currentHolder != null)
                  _detailRow(
                    'Currently with',
                    asset.dueBack == null
                        ? asset.currentHolder!
                        : asset.isLoanOverdue
                            ? '${asset.currentHolder!} · due back ${asset.dueBack} · '
                                '${asset.overdueDays} day${asset.overdueDays == 1 ? '' : 's'} overdue'
                            : '${asset.currentHolder!} · due back ${asset.dueBack}',
                  ),
                _detailRow(
                  'Last seen',
                  asset.formattedLastScannedAt == null
                      ? 'Never scanned'
                      : '${asset.lastLocation ?? 'Location not recorded'} · ${asset.formattedLastScannedAt}',
                ),
                _detailRow(
                  'Description',
                  asset.description.isEmpty
                      ? 'No description provided.'
                      : asset.description,
                  isLast: true,
                ),
                if (widget.onSighting != null) ...[
                  const SizedBox(height: 4),
                  _sightingBox(asset),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sightingBox(AssetItem asset) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.mint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Found it? Note where you saw it.',
            style: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _location,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) {
                    if (_saved) setState(() => _saved = false);
                  },
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    hintText: 'e.g. AVR Room, Shelf 3',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _saved ? null : _recordSighting,
                icon: Icon(_saved ? Icons.check : Icons.save_outlined, size: 18),
                label: Text(_saved ? 'Saved' : 'Record'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool mono = false, bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkGreen,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.muted,
              fontFamily: mono ? 'monospace' : null,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE6A637)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.square;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * .58,
      height: size.width * .58,
    );

    const length = 48.0;
    final l = rect.left;
    final r = rect.right;
    final t = rect.top;
    final b = rect.bottom;

    canvas.drawLine(Offset(l, t + length), Offset(l, t), paint);
    canvas.drawLine(Offset(l, t), Offset(l + length, t), paint);
    canvas.drawLine(Offset(r - length, t), Offset(r, t), paint);
    canvas.drawLine(Offset(r, t), Offset(r, t + length), paint);
    canvas.drawLine(Offset(l, b - length), Offset(l, b), paint);
    canvas.drawLine(Offset(l, b), Offset(l + length, b), paint);
    canvas.drawLine(Offset(r - length, b), Offset(r, b), paint);
    canvas.drawLine(Offset(r, b - length), Offset(r, b), paint);

    canvas.drawLine(
      Offset(l + 25, size.height / 2),
      Offset(r - 25, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}