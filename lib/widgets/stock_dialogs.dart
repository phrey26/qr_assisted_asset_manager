import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// The admin's answer from [promptStockPurchase] — one "Add stock" (buying)
/// entry for a bulk asset.
class StockPurchaseInput {
  StockPurchaseInput({
    required this.quantity,
    this.supplier,
    this.note,
    this.purchasedAt,
  });

  final int quantity;
  final String? supplier;
  final String? note;

  /// ISO yyyy-MM-dd, or null.
  final String? purchasedAt;
}

/// "Add stock" — records units bought for a bulk asset, with supplier/date.
Future<StockPurchaseInput?> promptStockPurchase(
  BuildContext context,
  AssetItem asset,
) {
  return showDialog<StockPurchaseInput>(
    context: context,
    builder: (_) => _StockPurchaseDialog(asset: asset),
  );
}

/// "Dispose" — permanently writes off units of a bulk asset that are
/// currently set aside as backup. Returns `(quantity, reason)` or null.
/// Reason is required. Only offered from the Backup Items screen — units
/// must be moved to backup first (see [promptStockBackup]).
Future<({int quantity, String reason})?> promptStockDisposal(
  BuildContext context,
  AssetItem asset,
) {
  return showDialog<({int quantity, String reason})>(
    context: context,
    builder: (_) => _StockDisposalDialog(asset: asset),
  );
}

/// "Repair" — moves set-aside damaged units back into available stock.
/// Returns `(quantity, note)` or null.
Future<({int quantity, String? note})?> promptStockRestore(
  BuildContext context,
  AssetItem asset,
) {
  return showDialog<({int quantity, String? note})>(
    context: context,
    builder: (_) => _StockRestoreDialog(asset: asset),
  );
}

/// "Move to backup" — sets aside units of a bulk asset as backup, the bulk
/// counterpart to an individual asset's "Move to backup". Returns
/// `(quantity, reason)` or null. Reason is required. Shown on the asset
/// detail screen; reactivating or disposing of the backed-up units happens
/// from the Backup Items screen instead (see [promptStockReactivate] /
/// [promptStockDisposal]).
Future<({int quantity, String reason})?> promptStockBackup(
  BuildContext context,
  AssetItem asset,
) {
  return showDialog<({int quantity, String reason})>(
    context: context,
    builder: (_) => _StockBackupDialog(asset: asset),
  );
}

/// "Move to active" — moves backed-up units of a bulk asset back into
/// available stock. Returns `(quantity, reason)` or null. Reason is
/// required, mirroring the individual-asset "Move to active" flow. Only
/// offered from the Backup Items screen.
Future<({int quantity, String reason})?> promptStockReactivate(
  BuildContext context,
  AssetItem asset,
) {
  return showDialog<({int quantity, String reason})>(
    context: context,
    builder: (_) => _StockReactivateDialog(asset: asset),
  );
}

// ---------------------------------------------------------------------------

class _DialogShell extends StatelessWidget {
  const _DialogShell({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.child,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final Widget child;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 28),
      ),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.darkGreen,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      content: SizedBox(
        // Roomier on desktop; full available width on mobile (unchanged).
        width: Responsive.isDesktop(context) ? 460 : double.maxFinite,
        child: SingleChildScrollView(child: child),
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
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
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
                child: Text(confirmLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Widget _fieldLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6, top: 12),
  child: Text(
    text,
    style: const TextStyle(
      color: AppTheme.darkGreen,
      fontSize: 13,
      fontWeight: FontWeight.w800,
    ),
  ),
);

class _StockPurchaseDialog extends StatefulWidget {
  const _StockPurchaseDialog({required this.asset});

  final AssetItem asset;

  @override
  State<_StockPurchaseDialog> createState() => _StockPurchaseDialogState();
}

class _StockPurchaseDialogState extends State<_StockPurchaseDialog> {
  final _qty = TextEditingController();
  final _supplier = TextEditingController();
  final _note = TextEditingController();
  DateTime? _date;

  @override
  void dispose() {
    _qty.dispose();
    _supplier.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _quantity {
    final q = int.tryParse(_qty.text.trim());
    return (q != null && q > 0) ? q : null;
  }

  void _submit() {
    final q = _quantity;
    if (q == null) return;
    Navigator.pop(
      context,
      StockPurchaseInput(
        quantity: q,
        supplier: _supplier.text.trim().isEmpty ? null : _supplier.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        purchasedAt: _date == null
            ? null
            : '${_date!.year.toString().padLeft(4, '0')}-'
                  '${_date!.month.toString().padLeft(2, '0')}-'
                  '${_date!.day.toString().padLeft(2, '0')}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      icon: Icons.add_shopping_cart_outlined,
      iconBg: AppTheme.mint,
      iconColor: AppTheme.primary,
      title: 'Add stock',
      confirmLabel: 'Add stock',
      confirmColor: AppTheme.primary,
      onConfirm: _quantity == null ? null : _submit,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Record units bought for "${widget.asset.name}". They\'re added to the '
            'on-hand total right away.',
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          _fieldLabel('How many units?'),
          TextField(
            controller: _qty,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'e.g. 25'),
          ),
          _fieldLabel('Supplier (optional)'),
          TextField(
            controller: _supplier,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Where it was bought'),
          ),
          _fieldLabel('Date bought (optional)'),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _date ?? now,
                firstDate: DateTime(2000),
                lastDate: now,
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
              ),
              child: Text(
                _date == null ? 'Select date' : AssetItem.formatDate(_date!),
                style: TextStyle(
                  color: _date == null ? AppTheme.muted : AppTheme.darkGreen,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          _fieldLabel('Note (optional)'),
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'PO number, remarks...',
            ),
          ),
        ],
      ),
    );
  }
}

class _StockDisposalDialog extends StatefulWidget {
  const _StockDisposalDialog({required this.asset});

  final AssetItem asset;

  @override
  State<_StockDisposalDialog> createState() => _StockDisposalDialogState();
}

class _StockDisposalDialogState extends State<_StockDisposalDialog> {
  final _qty = TextEditingController();
  final _reason = TextEditingController();

  static const _presets = [
    'Broken',
    'Used up / consumed',
    'Lost',
    'Obsolete',
    'Expired',
  ];

  @override
  void dispose() {
    _qty.dispose();
    _reason.dispose();
    super.dispose();
  }

  /// Only units already set aside as backup can be disposed — dispose is
  /// only reachable from the Backup Items screen, and backup units get
  /// there via "Move to backup" on the asset detail screen first.
  int get _disposable => widget.asset.quantityBackup;

  int? get _quantity {
    final q = int.tryParse(_qty.text.trim());
    return (q != null && q > 0 && q <= _disposable) ? q : null;
  }

  bool get _valid => _quantity != null && _reason.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      icon: Icons.delete_sweep_outlined,
      iconBg: AppTheme.redTint,
      iconColor: const Color(0xFFC84040),
      title: 'Dispose of stock',
      confirmLabel: 'Dispose',
      confirmColor: Colors.redAccent,
      onConfirm: _valid
          ? () => Navigator.pop(context, (
              quantity: _quantity!,
              reason: _reason.text.trim(),
            ))
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Write off backed-up units of "${widget.asset.name}" that are gone for good. '
            '$_disposable in backup can be disposed of. This is kept in the permanent disposal log.',
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          _fieldLabel('How many units?'),
          TextField(
            controller: _qty,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: 'Up to $_disposable'),
          ),
          _fieldLabel('Reason'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _presets)
                _MiniChip(
                  label: p,
                  selected: _reason.text.trim() == p,
                  onTap: () => setState(() {
                    _reason.text = p;
                    _reason.selection = TextSelection.fromPosition(
                      TextPosition(offset: _reason.text.length),
                    );
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reason,
            minLines: 2,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Add or edit the reason...',
            ),
          ),
        ],
      ),
    );
  }
}

class _StockRestoreDialog extends StatefulWidget {
  const _StockRestoreDialog({required this.asset});

  final AssetItem asset;

  @override
  State<_StockRestoreDialog> createState() => _StockRestoreDialogState();
}

class _StockRestoreDialogState extends State<_StockRestoreDialog> {
  late final _qty = TextEditingController(
    text: widget.asset.quantityDamaged.toString(),
  );
  final _note = TextEditingController();

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _damaged => widget.asset.quantityDamaged;

  int? get _quantity {
    final q = int.tryParse(_qty.text.trim());
    return (q != null && q > 0 && q <= _damaged) ? q : null;
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      icon: Icons.healing_outlined,
      iconBg: AppTheme.mint,
      iconColor: AppTheme.primary,
      title: 'Repair back to stock',
      confirmLabel: 'Return to stock',
      confirmColor: AppTheme.primary,
      onConfirm: _quantity == null
          ? null
          : () => Navigator.pop(context, (
              quantity: _quantity!,
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            )),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_damaged unit(s) of "${widget.asset.name}" are set aside damaged. '
            'Move the repaired ones back into available stock.',
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          _fieldLabel('How many were repaired?'),
          TextField(
            controller: _qty,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: 'Up to $_damaged'),
          ),
          _fieldLabel('Note (optional)'),
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'What was fixed, who did it...',
            ),
          ),
        ],
      ),
    );
  }
}

class _StockBackupDialog extends StatefulWidget {
  const _StockBackupDialog({required this.asset});

  final AssetItem asset;

  @override
  State<_StockBackupDialog> createState() => _StockBackupDialogState();
}

class _StockBackupDialogState extends State<_StockBackupDialog> {
  final _qty = TextEditingController();
  final _reason = TextEditingController();

  static const _presets = [
    'Obsolete',
    'Unused',
    'Set aside for review',
    'Pending disposal',
  ];

  @override
  void dispose() {
    _qty.dispose();
    _reason.dispose();
    super.dispose();
  }

  int get _available => widget.asset.quantityAvailable;

  int? get _quantity {
    final q = int.tryParse(_qty.text.trim());
    return (q != null && q > 0 && q <= _available) ? q : null;
  }

  bool get _valid => _quantity != null && _reason.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      icon: Icons.archive_outlined,
      iconBg: AppTheme.slateTint,
      iconColor: AppTheme.muted,
      title: 'Move to backup',
      confirmLabel: 'Move to backup',
      confirmColor: AppTheme.primary,
      onConfirm: _valid
          ? () => Navigator.pop(context, (
              quantity: _quantity!,
              reason: _reason.text.trim(),
            ))
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set aside units of "${widget.asset.name}" as backup — kept out of the '
            'lendable pool but still owned. $_available available. Reactivate or '
            'dispose of them from the Backup Items screen.',
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          _fieldLabel('How many units?'),
          TextField(
            controller: _qty,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: 'Up to $_available'),
          ),
          _fieldLabel('Reason'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _presets)
                _MiniChip(
                  label: p,
                  selected: _reason.text.trim() == p,
                  onTap: () => setState(() {
                    _reason.text = p;
                    _reason.selection = TextSelection.fromPosition(
                      TextPosition(offset: _reason.text.length),
                    );
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reason,
            minLines: 2,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Add or edit the reason...',
            ),
          ),
        ],
      ),
    );
  }
}

class _StockReactivateDialog extends StatefulWidget {
  const _StockReactivateDialog({required this.asset});

  final AssetItem asset;

  @override
  State<_StockReactivateDialog> createState() => _StockReactivateDialogState();
}

class _StockReactivateDialogState extends State<_StockReactivateDialog> {
  late final _qty = TextEditingController(
    text: widget.asset.quantityBackup.toString(),
  );
  final _reason = TextEditingController();

  @override
  void dispose() {
    _qty.dispose();
    _reason.dispose();
    super.dispose();
  }

  int get _backup => widget.asset.quantityBackup;

  int? get _quantity {
    final q = int.tryParse(_qty.text.trim());
    return (q != null && q > 0 && q <= _backup) ? q : null;
  }

  bool get _valid => _quantity != null && _reason.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      icon: Icons.unarchive_outlined,
      iconBg: AppTheme.mint,
      iconColor: AppTheme.primary,
      title: 'Move to active',
      confirmLabel: 'Move to active',
      confirmColor: AppTheme.primary,
      onConfirm: _valid
          ? () => Navigator.pop(context, (
              quantity: _quantity!,
              reason: _reason.text.trim(),
            ))
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_backup unit(s) of "${widget.asset.name}" are set aside as backup. Move '
            'some back into available stock.',
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          _fieldLabel('How many units?'),
          TextField(
            controller: _qty,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: 'Up to $_backup'),
          ),
          _fieldLabel('Why is it going back into service?'),
          TextField(
            controller: _reason,
            minLines: 2,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Needed for use, no longer obsolete...',
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? Colors.redAccent.withValues(alpha: 0.12)
                : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? Colors.redAccent : AppTheme.border,
              width: 2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.redAccent : AppTheme.darkGreen,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
