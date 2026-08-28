import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import '../widgets/status_chip.dart';

/// Full-page scan result shown on mobile after a QR code is scanned or a
/// tag ID is entered manually on [QrScannerScreen]. Unlike the desktop
/// "mini window" dialog (which pops over the scan screen and dismisses
/// back to it), mobile pushes this as its own page so the asset's full
/// details have room to breathe on a small screen, with an explicit "Back
/// to scanner" button in addition to the normal app-bar back arrow.
class QrScanResultScreen extends StatelessWidget {
  const QrScanResultScreen({super.key, required this.tag, required this.asset});

  /// The raw tag ID that was scanned or typed in.
  final String tag;

  /// The matching asset from the inventory, or null if [tag] didn't match
  /// anything.
  final AssetItem? asset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Scan result'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (asset == null) _notFound() else _assetInfo(asset!),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Back to scanner'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notFound() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.redTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3C6C4), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: Color(0xFFC84040)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No asset found',
                  style: TextStyle(
                    color: Color(0xFFC84040),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'No asset in the inventory matches the tag "$tag".',
            style: const TextStyle(color: Color(0xFFC84040)),
          ),
        ],
      ),
    );
  }

  Widget _assetInfo(AssetItem asset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (asset.imageBytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(
                asset.imageBytes!,
                fit: BoxFit.cover,
                semanticLabel: 'Photo of ${asset.name}',
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                asset.name,
                style: const TextStyle(
                  color: AppTheme.darkGreen,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            StatusChip(status: asset.status),
          ],
        ),
        const SizedBox(height: 20),
        Container(
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
              _detailRow('Asset tag ID', asset.tagId, mono: true),
              _detailRow('Category', asset.category),
              _detailRow('Date of purchase', asset.formattedPurchaseDate),
              _detailRow(
                'Description',
                asset.description.isEmpty ? 'No description provided.' : asset.description,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
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
}