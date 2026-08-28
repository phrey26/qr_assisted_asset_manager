import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/status_chip.dart';
import 'qr_scan_result_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key, required this.assets});

  /// The current inventory, including assets created during this session.
  final List<AssetItem> assets;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with WidgetsBindingObserver {
  // autoStart is off so we can request/check camera access ourselves and
  // show a clear message instead of a blank camera preview when it fails.
  final controller = MobileScannerController(autoStart: false);
  final tagController = TextEditingController();
  bool torchOn = false;

  // True while a scan result is being shown (the desktop mini window, or
  // the mobile result page). Guards against the camera's onDetect firing
  // repeatedly for the same code — which it does many times a second while
  // the tag is in frame — from opening several dialogs/pages at once.
  bool _isShowingResult = false;

  // Camera access state. This works the same way regardless of platform
  // (Android, iOS, desktop, or web) since mobile_scanner requests the
  // native/browser camera permission under the hood when controller.start()
  // is called; we just react to whether that succeeded.
  bool _checkingPermission = true;
  bool _cameraGranted = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestCameraAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    tagController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the admin left the app to grant camera access from device
    // Settings and comes back, retry automatically instead of making them
    // tap "Try again".
    if (state == AppLifecycleState.resumed && !_cameraGranted && !_checkingPermission) {
      _requestCameraAccess();
    }
  }

  Future<void> _requestCameraAccess() async {
    setState(() {
      _checkingPermission = true;
      _cameraError = null;
    });
    try {
      // Starting the controller is what actually triggers the OS/browser
      // camera permission prompt the first time this runs.
      await controller.start();
      if (!mounted) return;
      setState(() {
        _cameraGranted = true;
        _checkingPermission = false;
      });
    } on MobileScannerException catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraGranted = false;
        _checkingPermission = false;
        _cameraError = _messageFor(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraGranted = false;
        _checkingPermission = false;
        _cameraError = 'Could not access the camera on this device.';
      });
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
      builder: (_) => _ScanResultDialog(tag: tag, asset: asset),
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
      MaterialPageRoute(builder: (_) => QrScanResultScreen(tag: tag, asset: asset)),
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

  Widget _scanColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: SizedBox(
            height: 340,
            width: double.infinity,
            child: _checkingPermission
                ? _cameraLoading()
                : _cameraGranted
                    ? _cameraPreview()
                    : _cameraAccessNeeded(),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            _cameraGranted
                ? 'Align the QR tag within the frame'
                : 'Camera unavailable — you can still enter the tag ID below',
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
            hintText: 'CSDO-IT-0231',
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

  Widget _cameraPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: controller,
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            final code = barcodes.isEmpty ? null : barcodes.first.rawValue;
            if (code != null) _handleTag(code);
          },
        ),
        IgnorePointer(
          child: CustomPaint(painter: _ScannerOverlayPainter()),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await controller.toggleTorch();
              setState(() => torchOn = !torchOn);
            },
            icon: Icon(torchOn ? Icons.flash_on : Icons.flash_off),
          ),
        ),
      ],
    );
  }

  /// Shown whenever the camera isn't available — most commonly because the
  /// admin hasn't granted camera permission yet, or denied it. Reminds
  /// them to enable it and offers a one-tap retry once they have.
  Widget _cameraAccessNeeded() {
    return Container(
      color: AppTheme.redTint,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, color: Color(0xFFC84040), size: 40),
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
              _cameraError ?? 'Please allow camera access to scan asset tags.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Check your device or browser settings for this app\'s camera permission, then try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted, fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _requestCameraAccess,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ],
        ),
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
class _ScanResultDialog extends StatelessWidget {
  const _ScanResultDialog({required this.tag, required this.asset});

  final String tag;
  final AssetItem? asset;

  @override
  Widget build(BuildContext context) {
    final asset = this.asset;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
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
                  'No asset in the inventory matches the tag "$tag".',
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
                _detailRow(
                  'Description',
                  asset.description.isEmpty ? 'No description provided.' : asset.description,
                  isLast: true,
                ),
              ],
            ],
          ),
        ),
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