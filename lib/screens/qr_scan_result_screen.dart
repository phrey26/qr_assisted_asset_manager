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
///
/// Scanning isn't just a lookup: the admin can record *where they found the
/// asset* here ([onSighting]), which stamps its "last seen" so the next
/// search starts from a real location instead of the record's guess.
class QrScanResultScreen extends StatefulWidget {
  const QrScanResultScreen({
    super.key,
    required this.tag,
    required this.asset,
    this.onSighting,
  });

  /// The raw tag ID that was scanned or typed in.
  final String tag;

  /// The matching asset from the inventory, or null if [tag] didn't match
  /// anything.
  final AssetItem? asset;

  /// Records that this asset was just scanned, and (optionally) where.
  final void Function(AssetItem asset, String? location)? onSighting;

  @override
  State<QrScanResultScreen> createState() => _QrScanResultScreenState();
}

class _QrScanResultScreenState extends State<QrScanResultScreen> {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          loc.isEmpty
              ? 'Recorded — ${asset.name} seen just now.'
              : 'Recorded — ${asset.name} seen at $loc.',
        ),
      ),
    );
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
        title: const Text('Scan result'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (asset == null) _notFound() else _assetInfo(asset),
              if (asset != null && widget.onSighting != null) ...[
                const SizedBox(height: 20),
                _sightingCard(asset),
              ],
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
            'No asset in the inventory matches the tag "${widget.tag}".',
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
            if (asset.isBulk)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
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
                    fontSize: 14,
                  ),
                ),
              )
            else
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
              if (asset.homeLocation != null)
                _detailRow('Home location', asset.homeLocation!),
              if (!asset.isBulk && asset.currentHolder != null)
                _detailRow(
                  'Currently with',
                  asset.dueBack == null
                      ? asset.currentHolder!
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
            ],
          ),
        ),
      ],
    );
  }

  /// "I found it here" — records a sighting so the asset's last-seen
  /// location updates for the next person who goes looking for it.
  Widget _sightingCard(AssetItem asset) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.mint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.travel_explore, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Found it? Note where.',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Records that you scanned this asset just now. Adding a location '
            'updates its "last seen" so it\'s easier to find next time.',
            style: TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _location,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              if (_saved) setState(() => _saved = false);
            },
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'e.g. AVR Room, Shelf 3',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saved ? null : _recordSighting,
              icon: Icon(_saved ? Icons.check : Icons.save_outlined),
              label: Text(_saved ? 'Recorded' : 'Record sighting'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool mono = false,
    bool isLast = false,
  }) {
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
