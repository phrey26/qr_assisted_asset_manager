import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/asset.dart';
import '../models/category.dart';
import '../screens/camera_capture_screen.dart';
import '../theme/app_theme.dart';
import '../utils/camera_support.dart';

/// What the Add Asset flow produced — either a brand-new asset to insert, or
/// a restock against a bulk pool that already exists.
sealed class AddAssetResult {
  const AddAssetResult();
}

/// A brand-new asset row (individual, or a new bulk pool).
class NewAssetResult extends AddAssetResult {
  const NewAssetResult(this.asset);
  final AssetItem asset;
}

/// An edit to an existing asset — [asset] carries the original's tag,
/// status, tracking and quantities with the admin-editable fields (name,
/// category, description, purchase date, photo, home location, person
/// responsible, and — bulk only — reorder point) overwritten.
class EditAssetResult extends AddAssetResult {
  const EditAssetResult(this.asset, {this.correctedTotal, this.countReason});
  final AssetItem asset;

  /// Bulk only: set when the admin corrected the on-hand total via the
  /// "On-hand total" field (the old "Correct count" stock action, now part
  /// of editing). When non-null, [countReason] is also non-null (required)
  /// and the caller must additionally call `ApiService.adjustStock` — this
  /// is separate from the regular field edit because it's audited on the
  /// stock ledger, not the asset timeline.
  final int? correctedTotal;
  final String? countReason;
}

/// "We bought more" — add units to an existing bulk item, with the same
/// supplier paperwork as the "Add stock" action on the asset detail screen.
class BulkRestockResult extends AddAssetResult {
  const BulkRestockResult({
    required this.tagId,
    required this.quantity,
    this.supplier,
    this.note,
    this.purchasedAt,
  });

  final String tagId;
  final int quantity;
  final String? supplier;
  final String? note;

  /// ISO yyyy-MM-dd, or null.
  final String? purchasedAt;
}

/// The actual "add asset" form fields, shared between [AddAssetScreen]
/// (full page, used on mobile) and the desktop modal dialog. Keeping the
/// fields in one place means the mobile and desktop entry points can never
/// drift apart.
class AddAssetForm extends StatefulWidget {
  const AddAssetForm({
    super.key,
    required this.categories,
    required this.onSubmit,
    this.existingBulk = const [],
    this.initial,
    this.onCancel,
    this.compact = false,
  });

  /// When set, the form runs in "edit" mode: fields are prefilled from this
  /// asset, the tracking selector and bulk-restock path are hidden, the tag
  /// ID is shown read-only, and submitting produces an [EditAssetResult].
  final AssetItem? initial;

  /// Categories offered in the "Category" dropdown below. Owned by
  /// [AppShell] and shared with the Categories and Inventory tabs, so a
  /// category added there immediately shows up here too. Must be
  /// non-empty.
  final List<AssetCategory> categories;

  /// Bulk items already in the inventory. When non-empty and the admin
  /// picks "Bulk quantity", they can choose to top up one of these instead
  /// of creating a new pool.
  final List<AssetItem> existingBulk;

  final ValueChanged<AddAssetResult> onSubmit;

  /// Shown as a "Cancel" button next to the save button when provided
  /// (desktop dialog). When null, only the save button is shown full width
  /// (mobile full-page screen, which already has a back arrow).
  final VoidCallback? onCancel;

  /// Tightens vertical spacing for use inside a modal dialog.
  final bool compact;

  @override
  State<AddAssetForm> createState() => _AddAssetFormState();
}

class _AddAssetFormState extends State<AddAssetForm> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final quantityController = TextEditingController();
  final reorderController = TextEditingController();
  final countReasonController = TextEditingController();
  final supplierController = TextEditingController();
  final homeLocationController = TextEditingController();
  final custodianController = TextEditingController();
  late String category;
  DateTime? purchaseDate;
  Uint8List? imageBytes;

  bool get _isEdit => widget.initial != null;

  /// Bulk only: when true, the form tops up an existing pool ([_restockTag])
  /// instead of creating a new asset. Only reachable when
  /// [AddAssetForm.existingBulk] is non-empty.
  bool _restock = false;
  late String? _restockTag = widget.existingBulk.isEmpty
      ? null
      : widget.existingBulk.first.tagId;

  /// Where this asset goes once saved. `false` -> an active asset that can
  /// be borrowed (status `available`); `true` -> a "backup item" that's
  /// kept off the borrowable pool (status `backup`). Defaults to
  /// an active asset. Not used for bulk assets.
  bool toStock = false;

  /// How this asset is tracked. Seeded from the selected category's default
  /// and re-seeded when the category changes, unless the admin has flipped
  /// it by hand (then [_trackingTouched] keeps their choice).
  AssetTracking tracking = AssetTracking.individual;
  bool _trackingTouched = false;

  bool get _isBulk => tracking == AssetTracking.bulk;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      nameController.text = initial.name;
      descriptionController.text = initial.description;
      homeLocationController.text = initial.homeLocation ?? '';
      custodianController.text = initial.custodian ?? '';
      reorderController.text = initial.reorderPoint?.toString() ?? '';
      quantityController.text = initial.quantityTotal?.toString() ?? '';
      category = widget.categories.any((c) => c.value == initial.category)
          ? initial.category
          : widget.categories.first.value;
      purchaseDate = initial.purchaseDate;
      imageBytes = initial.imageBytes;
      tracking = initial.tracking;
      _trackingTouched = true; // never re-seed from the category in edit mode
      return;
    }
    category = widget.categories.first.value;
    tracking = widget.categories.first.defaultTracking;
  }

  /// Applies the picked category and, unless the admin has overridden it,
  /// switches the tracking mode to that category's default.
  void _selectCategory(String value) {
    setState(() {
      category = value;
      if (!_trackingTouched) {
        final match = widget.categories.firstWhere(
          (c) => c.value == value,
          orElse: () => widget.categories.first,
        );
        tracking = match.defaultTracking;
        if (!_isBulk) _restock = false;
      }
    });
  }

  void _setTracking(AssetTracking value) {
    setState(() {
      tracking = value;
      _trackingTouched = true;
      if (value != AssetTracking.bulk) _restock = false;
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    quantityController.dispose();
    reorderController.dispose();
    countReasonController.dispose();
    supplierController.dispose();
    homeLocationController.dispose();
    custodianController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickPurchaseDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: purchaseDate ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => purchaseDate = picked);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (mounted) setState(() => imageBytes = bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access the selected image.')),
        );
      }
    }
  }

  /// "Take photo": uses `image_picker`'s camera UI on Android/iOS, and the
  /// in-app [CameraCaptureScreen] (camera package) on desktop where
  /// `image_picker` can't reach a camera.
  Future<void> _takePhoto() async {
    if (imagePickerCameraSupported) {
      await _pickImage(ImageSource.camera);
      return;
    }
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => const CameraCaptureScreen(title: 'Asset photo'),
      ),
    );
    if (bytes != null && mounted) setState(() => imageBytes = bytes);
  }

  /// Trims a controller's text, returning null when it's blank.
  String? _nullable(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  void _save() {
    if (_restock) {
      _submitRestock();
      return;
    }
    if (nameController.text.trim().isEmpty) {
      _toast('Please enter an asset name.');
      return;
    }
    if (purchaseDate == null) {
      _toast('Please add the date of purchase.');
      return;
    }
    int? quantity;
    int? reorder;
    int? correctedTotal;
    String? countReason;
    if (_isBulk) {
      if (!_isEdit) {
        quantity = int.tryParse(quantityController.text.trim());
        if (quantity == null || quantity < 0) {
          _toast('Enter the quantity on hand (0 or more).');
          return;
        }
      } else {
        // The old "Correct count" stock action, now folded into editing.
        // Only sent along (as correctedTotal/countReason) when the admin
        // actually changed the number — otherwise this is a no-op, same as
        // any other untouched field.
        final initial = widget.initial!;
        final entered = int.tryParse(quantityController.text.trim());
        final minTotal =
            initial.quantityOut + initial.quantityDamaged + initial.quantityBackup;
        if (entered == null || entered < minTotal) {
          _toast(
            "The on-hand total can't go below the $minTotal unit(s) currently on "
            'loan, set aside damaged, or set aside as backup.',
          );
          return;
        }
        if (entered != (initial.quantityTotal ?? 0)) {
          final reason = countReasonController.text.trim();
          if (reason.isEmpty) {
            _toast('Enter a reason for the count correction.');
            return;
          }
          correctedTotal = entered;
          countReason = reason;
        }
      }
      final rawReorder = reorderController.text.trim();
      if (rawReorder.isNotEmpty) {
        reorder = int.tryParse(rawReorder);
        if (reorder == null || reorder < 0) {
          _toast('The reorder point must be a whole number.');
          return;
        }
      }
    }

    if (_isEdit) {
      final initial = widget.initial!;
      widget.onSubmit(
        EditAssetResult(
          AssetItem(
            name: nameController.text.trim(),
            tagId: initial.tagId,
            category: category,
            description: descriptionController.text.trim(),
            status: initial.status,
            purchaseDate: purchaseDate!,
            imageBytes: imageBytes,
            lastConditionRaw: initial.lastConditionRaw,
            tracking: initial.tracking,
            quantityTotal: correctedTotal ?? initial.quantityTotal,
            quantityOut: initial.quantityOut,
            quantityDamaged: initial.quantityDamaged,
            quantityBackup: initial.quantityBackup,
            reorderPoint: initial.isBulk ? reorder : initial.reorderPoint,
            lifespanYears: initial.lifespanYears,
            homeLocation: _nullable(homeLocationController),
            custodian: _nullable(custodianController),
            lastLocation: initial.lastLocation,
            lastScannedAt: initial.lastScannedAt,
            currentHolder: initial.currentHolder,
            currentHolderDepartment: initial.currentHolderDepartment,
            dueBack: initial.dueBack,
          ),
          correctedTotal: correctedTotal,
          countReason: countReason,
        ),
      );
      return;
    }

    widget.onSubmit(
      NewAssetResult(
        AssetItem(
          name: nameController.text.trim(),
          // The backend allocates the tag ID on insert; the caller stamps it
          // back onto this asset from the POST response.
          tagId: '',
          category: category,
          description: descriptionController.text.trim(),
          status: (!_isBulk && toStock)
              ? AssetStatus.inStock
              : AssetStatus.available,
          purchaseDate: purchaseDate!,
          imageBytes: imageBytes,
          tracking: tracking,
          quantityTotal: _isBulk ? quantity : null,
          reorderPoint: _isBulk ? reorder : null,
          homeLocation: _nullable(homeLocationController),
          custodian: _nullable(custodianController),
        ),
      ),
    );
  }

  void _submitRestock() {
    if (_restockTag == null) {
      _toast('Pick a bulk item to add stock to.');
      return;
    }
    final qty = int.tryParse(quantityController.text.trim());
    if (qty == null || qty <= 0) {
      _toast('Enter how many units were added.');
      return;
    }
    widget.onSubmit(
      BulkRestockResult(
        tagId: _restockTag!,
        quantity: qty,
        supplier: supplierController.text.trim().isEmpty
            ? null
            : supplierController.text.trim(),
        note: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        purchasedAt: purchaseDate == null ? null : _ymd(purchaseDate!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gap = widget.compact ? 18.0 : 28.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tracking mode and the restock path are create-only. Editing an
        // existing asset never changes how it's tracked.
        if (!_isEdit) ...[
          _label('How is it tracked?'),
          _trackingSelector(),
          SizedBox(height: gap),
          if (_isBulk && widget.existingBulk.isNotEmpty) ...[
            _label('Add stock to'),
            _bulkModeSelector(),
            SizedBox(height: gap),
          ],
        ],
        if (_restock) ..._restockFields(gap) else ..._newAssetFields(gap),
        SizedBox(height: widget.compact ? 22 : 40),
        _saveRow(),
      ],
    );
  }

  // --- "Add to an existing bulk item" ------------------------------------

  Widget _bulkModeSelector() {
    return Row(
      children: [
        Expanded(
          child: _destinationOption(
            selected: !_restock,
            icon: Icons.add_box_outlined,
            title: 'A new bulk item',
            subtitle: 'Create a new pool',
            onTap: () => setState(() => _restock = false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _destinationOption(
            selected: _restock,
            icon: Icons.add_shopping_cart_outlined,
            title: 'An existing one',
            subtitle: 'Bought more of it',
            onTap: () => setState(() => _restock = true),
          ),
        ),
      ],
    );
  }

  List<Widget> _restockFields(double gap) {
    return [
      _label('Which item?'),
      DropdownButtonFormField<String>(
        initialValue: _restockTag,
        items: [
          for (final a in widget.existingBulk)
            DropdownMenuItem(
              value: a.tagId,
              child: Text('${a.name}  (${a.stockLabel})'),
            ),
        ],
        onChanged: (value) => setState(() => _restockTag = value),
      ),
      SizedBox(height: gap),
      _label('Quantity to add'),
      TextField(
        controller: quantityController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: 'e.g. 25'),
      ),
      SizedBox(height: gap),
      _label('Supplier (optional)'),
      TextField(
        controller: supplierController,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Where it was bought'),
      ),
      SizedBox(height: gap),
      _label('Date bought (optional)'),
      _datePickerField(optional: true),
      SizedBox(height: gap),
      _label('Note (optional)'),
      TextField(
        controller: descriptionController,
        minLines: 2,
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'PO number, remarks...'),
      ),
    ];
  }

  // --- new asset (individual, or a new bulk pool) ----------------------

  List<Widget> _newAssetFields(double gap) {
    return [
      _label('Asset name'),
      TextField(
        controller: nameController,
        decoration: const InputDecoration(hintText: 'e.g. Epson projector'),
      ),
      SizedBox(height: gap),
      _label('Asset tag ID'),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.mint,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.primary, width: 2),
        ),
        child: Row(
          children: [
            const Icon(Icons.qr_code_2, color: AppTheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isEdit
                    ? widget.initial!.tagId
                    : 'Assigned automatically when you save',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  fontFamily: _isEdit ? 'monospace' : null,
                ),
              ),
            ),
            if (_isEdit)
              const Icon(Icons.lock_outline, color: AppTheme.primary, size: 16),
          ],
        ),
      ),
      SizedBox(height: gap),
      _label('Category'),
      DropdownButtonFormField<String>(
        initialValue: category,
        items: [
          for (final c in widget.categories)
            DropdownMenuItem(value: c.value, child: Text(c.displayName)),
        ],
        onChanged: (value) => _selectCategory(value!),
      ),
      SizedBox(height: gap),
      if (_isBulk) ...[
        _label(_isEdit ? 'On-hand total' : 'Quantity on hand'),
        TextField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          onChanged: _isEdit ? (_) => setState(() {}) : null,
          decoration: InputDecoration(
            hintText: _isEdit ? 'Counted units' : 'e.g. 50',
          ),
        ),
        if (_isEdit &&
            int.tryParse(quantityController.text.trim()) !=
                (widget.initial!.quantityTotal ?? 0)) ...[
          SizedBox(height: gap),
          _label('Reason for the correction'),
          TextField(
            controller: countReasonController,
            minLines: 2,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Stock-take correction, found extras, ...',
            ),
          ),
        ],
        SizedBox(height: gap),
        _label('Reorder point (optional)'),
        TextField(
          controller: reorderController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Warn when available stock drops to this',
          ),
        ),
        SizedBox(height: gap),
      ] else if (!_isEdit) ...[
        _label('Add to'),
        _destinationSelector(),
        SizedBox(height: gap),
      ],
      _label('Date of purchase'),
      _datePickerField(optional: false),
      SizedBox(height: gap),
      _label('Asset photo (optional)'),
      _photoPicker(),
      SizedBox(height: gap),
      _label('Description'),
      TextField(
        controller: descriptionController,
        minLines: 3,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'Serial no., condition, accessories included...',
        ),
      ),
      SizedBox(height: gap),
      _label('Home location (optional)'),
      TextField(
        controller: homeLocationController,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'Where it normally lives, e.g. AVR Room',
        ),
      ),
      SizedBox(height: gap),
      _label('Person responsible (optional)'),
      TextField(
        controller: custodianController,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'Who looks after it, e.g. J. Cruz',
        ),
      ),
    ];
  }

  Widget _datePickerField({required bool optional}) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _pickPurchaseDate,
      child: InputDecorator(
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
        ),
        child: Text(
          purchaseDate == null
              ? (optional ? 'Select date (optional)' : 'Select date')
              : AssetItem.formatDate(purchaseDate!),
          style: TextStyle(
            color: purchaseDate == null ? AppTheme.muted : AppTheme.darkGreen,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _saveRow() {
    final label = _isEdit
        ? 'Save changes'
        : _restock
        ? 'Add to stock'
        : 'Generate QR and save';
    final icon = _isEdit
        ? Icons.check
        : _restock
        ? Icons.add_shopping_cart_outlined
        : Icons.qr_code_2;
    if (widget.onCancel != null) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onCancel,
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: Icon(icon, size: 22),
              label: Text(label),
            ),
          ),
        ],
      );
    }
    return ElevatedButton.icon(
      onPressed: _save,
      icon: Icon(icon, size: 26),
      label: Text(label),
    );
  }

  Widget _label(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      value,
      style: TextStyle(
        color: AppTheme.darkGreen,
        fontSize: widget.compact ? 15 : 20,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  /// Two-way selector letting the admin file a new asset either as an
  /// active, borrowable asset or as a "backup item" that stays off the
  /// borrowable pool. Persisted to the backend via the asset's `status`
  /// (`available` vs `backup`).
  Widget _destinationSelector() {
    return Row(
      children: [
        Expanded(
          child: _destinationOption(
            selected: !toStock,
            icon: Icons.inventory_2_outlined,
            title: 'Active asset',
            subtitle: 'Can be borrowed',
            onTap: () => setState(() => toStock = false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _destinationOption(
            selected: toStock,
            icon: Icons.archive_outlined,
            title: 'Backup item',
            subtitle: 'Backup, not borrowable',
            onTap: () => setState(() => toStock = true),
          ),
        ),
      ],
    );
  }

  /// Individual (one QR-tagged unit) vs Bulk (a counted quantity). Seeded
  /// from the category's default; flipping it here sticks for this asset.
  Widget _trackingSelector() {
    return Row(
      children: [
        Expanded(
          child: _destinationOption(
            selected: !_isBulk,
            icon: Icons.qr_code_2,
            title: 'Individual',
            subtitle: 'One tagged unit',
            onTap: () => _setTracking(AssetTracking.individual),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _destinationOption(
            selected: _isBulk,
            icon: Icons.inventory_2_outlined,
            title: 'Bulk quantity',
            subtitle: 'Counted stock',
            onTap: () => _setTracking(AssetTracking.bulk),
          ),
        ),
      ],
    );
  }

  Widget _destinationOption({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppTheme.mint : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected ? AppTheme.primary : AppTheme.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: selected ? AppTheme.primary : AppTheme.darkGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPicker() {
    final preview = imageBytes == null
        ? Container(
            color: AppTheme.mint,
            child: const Center(
              child: Icon(
                Icons.image_outlined,
                color: AppTheme.primary,
                size: 38,
              ),
            ),
          )
        : Image.memory(imageBytes!, fit: BoxFit.cover);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(width: 150, height: 112, child: preview),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            if (cameraCaptureSupported)
              OutlinedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take photo'),
              ),
            OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload image'),
            ),
            if (imageBytes != null)
              TextButton.icon(
                onPressed: () => setState(() => imageBytes = null),
                icon: const Icon(Icons.close),
                label: const Text('Remove'),
              ),
          ],
        ),
      ],
    );
  }
}
