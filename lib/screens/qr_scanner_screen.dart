import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import '../widgets/status_chip.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key, required this.assets});

  /// The current inventory, including assets created during this session.
  final List<AssetItem> assets;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final controller = MobileScannerController();
  final tagController = TextEditingController();
  bool torchOn = false;
  String? scannedTag;
  AssetItem? scannedAsset;

  @override
  void dispose() {
    controller.dispose();
    tagController.dispose();
    super.dispose();
  }

  void _handleTag(String value) {
    final tag = value.trim();
    if (tag.isEmpty) return;
    setState(() {
      scannedTag = tag;
      scannedAsset = null;
      for (final asset in widget.assets) {
        if (asset.tagId.toLowerCase() == tag.toLowerCase()) {
          scannedAsset = asset;
          break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 42, 28, 0),
          sliver: SliverToBoxAdapter(
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
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(28, 4, 28, 24),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Point the camera at an asset tag',
              style: TextStyle(color: AppTheme.muted, fontSize: 19),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          sliver: SliverToBoxAdapter(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: SizedBox(
                height: 440,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: controller,
                      onDetect: (capture) {
                        final barcodes = capture.barcodes;
                        final code =
                            barcodes.isEmpty ? null : barcodes.first.rawValue;
                        if (code != null) _handleTag(code);
                      },
                    ),
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _ScannerOverlayPainter(),
                      ),
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
                ),
              ),
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(28, 22, 28, 12),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Text(
                'Align the QR tag within the frame',
                style: TextStyle(color: AppTheme.darkGreen, fontSize: 18),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: const [
                Expanded(child: Divider(color: AppTheme.border, thickness: 2)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'or enter tag ID manually',
                    style: TextStyle(color: AppTheme.muted, fontSize: 17),
                  ),
                ),
                Expanded(child: Divider(color: AppTheme.border, thickness: 2)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 14, 28, 20),
          sliver: SliverToBoxAdapter(
            child: TextField(
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
          ),
        ),
        if (scannedTag != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 110),
            sliver: SliverToBoxAdapter(child: _result()),
          )
        else
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _result() {
    if (scannedAsset == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.redTint,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          'No asset found for $scannedTag.',
          style: const TextStyle(
            color: Color(0xFFC84040),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.mint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            scannedAsset!.name,
            style: const TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            scannedAsset!.tagId,
            style: const TextStyle(
              color: AppTheme.muted,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 12),
          StatusChip(status: scannedAsset!.status),
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
