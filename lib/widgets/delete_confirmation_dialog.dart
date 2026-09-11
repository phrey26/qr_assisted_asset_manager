import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// The two ways an asset leaves the active inventory, both of which ask the
/// admin for a reason that gets recorded.
enum AssetRemovalMode {
  /// From the active inventory: the asset isn't deleted, just moved to the
  /// "Backup items" list. Recorded on the asset's timeline. If the admin
  /// says it needs repair, it's filed under "Maintenance" instead of plain
  /// "Backup" (see [AssetRemovalChoice.needsMaintenance]).
  retireToStock,

  /// From the "Backup items" list: the asset row is permanently deleted.
  /// Recorded in the `asset_removals` audit log. Only possible once the
  /// asset has already been moved to backup.
  delete,
}

/// The admin's answer from [promptAssetRemoval].
class AssetRemovalChoice {
  const AssetRemovalChoice({
    required this.reason,
    this.needsMaintenance = false,
  });

  /// The trimmed reason text (always non-empty).
  final String reason;

  /// [AssetRemovalMode.retireToStock] only: the admin ticked "needs
  /// repair", so the asset should be filed under [AssetStatus.maintenance]
  /// rather than [AssetStatus.inStock] ("Backup"). Always false for a
  /// delete.
  final bool needsMaintenance;
}

/// Prompts the admin to confirm removing [asset] and to give a reason.
/// Returns the choice on confirm, or null if they cancelled.
///
/// [mode] chooses the copy and styling: [AssetRemovalMode.retireToStock] is
/// a neutral "move to backup", [AssetRemovalMode.delete] is a red,
/// irreversible "delete permanently".
Future<AssetRemovalChoice?> promptAssetRemoval(
  BuildContext context,
  AssetItem asset,
  AssetRemovalMode mode,
) {
  return showDialog<AssetRemovalChoice>(
    context: context,
    builder: (_) => _AssetRemovalDialog(asset: asset, mode: mode),
  );
}

/// Prompts the admin for the reason an asset is being put back into the
/// active, borrowable inventory from "Backup items". Returns the trimmed
/// reason on confirm, or null if they cancelled. Mirrors [promptAssetRemoval]
/// so moving an asset in and out of backup feels symmetric.
Future<String?> promptAssetActivation(BuildContext context, AssetItem asset) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AssetActivationDialog(asset: asset),
  );
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

  /// retire-to-backup only: whether to file the asset under "Maintenance"
  /// rather than plain "Backup". Ticked automatically by the "Needs
  /// repair" preset, but the admin can toggle it by hand too.
  bool _needsMaintenance = false;

  bool get _isDelete => widget.mode == AssetRemovalMode.delete;

  /// The preset that, when chosen, means the asset is going to backup
  /// because it needs fixing — so it should land in "Maintenance".
  static const _repairPreset = 'Needs repair';

  List<String> get _presetReasons => _isDelete
      ? const [
          'Beyond repair',
          'Lost',
          'Stolen',
          'Disposed / scrapped',
          'Donated / transferred',
        ]
      : const [
          'Worn out',
          'Damaged',
          'Obsolete / outdated',
          'Rarely used',
          _repairPreset,
        ];

  Color get _accent => _isDelete ? Colors.redAccent : AppTheme.primary;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectPreset(String preset) {
    setState(() {
      _controller.text = preset;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      if (!_isDelete) _needsMaintenance = preset == _repairPreset;
    });
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
        _isDelete
            ? 'Delete this asset permanently?'
            : 'Move this asset to backup?',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.darkGreen,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      content: SizedBox(
        // Wider on desktop for comfortable reading; full available width on
        // mobile (unchanged there).
        width: Responsive.isDesktop(context) ? 480 : double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isDelete
                  ? '"${asset.name}" (${asset.tagId}) will be permanently removed. '
                        'This can\'t be undone — the reason below is kept in the removal log.'
                  : '"${asset.name}" (${asset.tagId}) will be taken out of the active '
                        'inventory and kept in "Backup items". To delete it for good, remove '
                        'it from there afterwards.',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 14,
                height: 1.4,
              ),
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
                    onTap: () => _selectPreset(preset),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Add or edit the reason...',
              ),
            ),
            if (!_isDelete) ...[
              const SizedBox(height: 4),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () =>
                    setState(() => _needsMaintenance = !_needsMaintenance),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _needsMaintenance,
                        onChanged: (v) =>
                            setState(() => _needsMaintenance = v ?? false),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'This asset needs repair — file it under "Maintenance"',
                            style: TextStyle(
                              color: AppTheme.darkGreen,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: hasReason
                    ? () => Navigator.pop(
                        context,
                        AssetRemovalChoice(
                          reason: _controller.text.trim(),
                          needsMaintenance: !_isDelete && _needsMaintenance,
                        ),
                      )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _isDelete
                      ? 'Delete'
                      : (!_isDelete && _needsMaintenance)
                      ? 'Move to maintenance'
                      : 'Move to backup',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Move to active" — the counterpart to [_AssetRemovalDialog] for putting a
/// stock / maintenance asset back into the borrowable inventory.
class _AssetActivationDialog extends StatefulWidget {
  const _AssetActivationDialog({required this.asset});

  final AssetItem asset;

  @override
  State<_AssetActivationDialog> createState() => _AssetActivationDialogState();
}

class _AssetActivationDialogState extends State<_AssetActivationDialog> {
  final _controller = TextEditingController();

  static const _presetReasons = [
    'Repaired / serviced',
    'Back in service',
    'Needed for use',
    'Replacing another unit',
  ];

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
        decoration: const BoxDecoration(
          color: AppTheme.mint,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.unarchive_outlined,
          color: AppTheme.primary,
          size: 28,
        ),
      ),
      title: const Text(
        'Move this asset to active inventory?',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppTheme.darkGreen,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      content: SizedBox(
        width: Responsive.isDesktop(context) ? 480 : double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${asset.name}" (${asset.tagId}) will be marked Available and can be '
              'borrowed again. The reason below is recorded on its timeline.',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Why is it going back into service?',
              style: TextStyle(
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
                    accent: AppTheme.primary,
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
              decoration: const InputDecoration(
                hintText: 'Add or edit the reason...',
              ),
            ),
          ],
        ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: hasReason
                    ? () => Navigator.pop(context, _controller.text.trim())
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Move to active'),
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
            border: Border.all(
              color: selected ? accent : AppTheme.border,
              width: 2,
            ),
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
