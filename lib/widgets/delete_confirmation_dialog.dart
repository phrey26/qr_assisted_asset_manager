import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';

/// The two ways an asset leaves the active inventory, both of which now ask
/// the admin for a reason that gets recorded.
enum AssetRemovalMode {
  /// From the active inventory: the asset isn't deleted, just moved to the
  /// "Stock items" list. Recorded on the asset's timeline.
  retireToStock,

  /// From the "Stock items" list: the asset row is permanently deleted.
  /// Recorded in the `asset_removals` audit log. Only possible once the
  /// asset is already a stock item.
  delete,
}

/// Prompts the admin to confirm removing [asset] and to give a reason.
/// Returns the trimmed reason on confirm, or null if they cancelled.
///
/// [mode] chooses the copy and styling: [AssetRemovalMode.retireToStock] is
/// a neutral "move to stock", [AssetRemovalMode.delete] is a red,
/// irreversible "delete permanently".
Future<String?> promptAssetRemoval(
  BuildContext context,
  AssetItem asset,
  AssetRemovalMode mode,
) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AssetRemovalDialog(asset: asset, mode: mode),
  );
}

/// Kept for older call sites: a plain yes/no delete confirm with no reason.
@Deprecated('Use promptAssetRemoval, which also collects a reason.')
Future<bool> confirmAssetDeletion(BuildContext context, AssetItem asset) async {
  final reason = await promptAssetRemoval(context, asset, AssetRemovalMode.delete);
  return reason != null;
}

class _AssetRemovalDialog extends StatefulWidget {
  const _AssetRemovalDialog({required this.asset, required this.mode});

  final AssetItem asset;
  final AssetRemovalMode mode;

  @override
  State<_AssetRemovalDialog> createState() => _AssetRemovalDialogState();
}

class _AssetRemovalDialogState extends State<_AssetRemovalDialog> {
  final _controller = TextEditingController();

  bool get _isDelete => widget.mode == AssetRemovalMode.delete;

  List<String> get _presetReasons => _isDelete
      ? const ['Beyond repair', 'Lost', 'Stolen', 'Disposed / scrapped', 'Donated / transferred']
      : const ['Worn out', 'Damaged', 'Obsolete / outdated', 'Rarely used', 'Needs repair'];

  Color get _accent => _isDelete ? Colors.redAccent : AppTheme.primary;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final hasReason = _controller.text.trim().isNotEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _isDelete ? AppTheme.redTint : AppTheme.mint,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _isDelete ? Icons.delete_outline : Icons.archive_outlined,
          color: _accent,
          size: 28,
        ),
      ),
      title: Text(
        _isDelete ? 'Delete this asset permanently?' : 'Move this asset to stock?',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.darkGreen,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isDelete
                ? '"${asset.name}" (${asset.tagId}) will be permanently removed. '
                    'This can\'t be undone — the reason below is kept in the removal log.'
                : '"${asset.name}" (${asset.tagId}) will be taken out of the active '
                    'inventory and kept in "Stock items". To delete it for good, remove '
                    'it from there afterwards.',
            style: const TextStyle(color: AppTheme.muted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 16),
          Text(
            _isDelete ? 'Reason for removal' : 'Why is it being moved?',
            style: const TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _presetReasons)
                _ReasonChip(
                  label: preset,
                  selected: _controller.text.trim() == preset,
                  accent: _accent,
                  onTap: () => setState(() {
                    _controller.text = preset;
                    _controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: _controller.text.length),
                    );
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            onChanged: (_) => setState(() {}),
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Add or edit the reason...'),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.darkGreen,
                  side: const BorderSide(color: AppTheme.border, width: 2),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: hasReason
                    ? () => Navigator.pop(context, _controller.text.trim())
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(_isDelete ? 'Delete' : 'Move to stock'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: selected ? accent : AppTheme.border, width: 2),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? accent : AppTheme.darkGreen,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}
