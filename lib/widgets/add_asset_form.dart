import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/asset.dart';
import '../models/category.dart';
import '../screens/camera_capture_screen.dart';
import '../theme/app_theme.dart';
import '../utils/camera_support.dart';

/// The actual "add asset" form fields, shared between [AddAssetScreen]
/// (full page, used on mobile) and the desktop modal dialog. Keeping the
/// fields in one place means the mobile and desktop entry points can never
/// drift apart.
class AddAssetForm extends StatefulWidget {
  const AddAssetForm({
    super.key,
    required this.nextTagId,
    required this.categories,
    required this.onSave,
    this.onCancel,
    this.compact = false,
  });

  final String nextTagId;

  /// Categories offered in the "Category" dropdown below. Owned by
  /// [AppShell] and shared with the Categories and Inventory tabs, so a
  /// category added there immediately shows up here too. Must be
  /// non-empty.
  final List<AssetCategory> categories;

  final ValueChanged<AssetItem> onSave;

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
  late final tagController = TextEditingController(text: widget.nextTagId);
  final quantityController = TextEditingController();
  final unitController = TextEditingController();
  final reorderController = TextEditingController();
  late String category;
  DateTime? purchaseDate;
  Uint8List? imageBytes;

  /// Where this asset goes once saved. `false` -> an active asset that can
  /// be borrowed (status `available`); `true` -> a backup "stock item"
  /// that's kept off the borrowable pool (status `in_stock`). Defaults to
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
      }
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    tagController.dispose();
    quantityController.dispose();
    unitController.dispose();
    reorderController.dispose();
    super.dispose();
  }

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

  void _save() {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an asset name.')),
      );
      return;
    }
    if (purchaseDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add the date of purchase.')),
      );
      return;
    }
    int? quantity;
    int? reorder;
    if (_isBulk) {
      quantity = int.tryParse(quantityController.text.trim());
      if (quantity == null || quantity < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the quantity on hand (0 or more).')),
        );
        return;
      }
      final rawReorder = reorderController.text.trim();
      if (rawReorder.isNotEmpty) {
        reorder = int.tryParse(rawReorder);
        if (reorder == null || reorder < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The reorder point must be a whole number.')),
          );
          return;
        }
      }
    }
    widget.onSave(
      AssetItem(
        name: nameController.text.trim(),
        tagId: tagController.text.trim(),
        category: category,
        description: descriptionController.text.trim(),
        status: (!_isBulk && toStock) ? AssetStatus.inStock : AssetStatus.available,
        purchaseDate: purchaseDate!,
        imageBytes: imageBytes,
        tracking: tracking,
        quantityTotal: _isBulk ? quantity : null,
        reorderPoint: _isBulk ? reorder : null,
        unitLabel: _isBulk && unitController.text.trim().isNotEmpty
            ? unitController.text.trim()
            : null,
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
        _label('Asset name'),
        TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'e.g. Epson projector'),
        ),
        SizedBox(height: gap),
        _label('Asset tag ID'),
        TextField(
          controller: tagController,
          readOnly: true,
          style: const TextStyle(
            color: AppTheme.primary,
            fontFamily: 'monospace',
            fontSize: 19,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.mint,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
        ),
        SizedBox(height: gap),
        _label('Category'),
        DropdownButtonFormField<String>(
          // Options come from widget.categories, kept in sync with the
          // category filter chips on the inventory list and the cards on
          // the Categories tab, so every asset added here can actually be
          // found under one of those filters — including any category the
          // admin has added since. 'Maintenance' was previously offered
          // here too, but that's an asset *status* (see AssetStatus), not
          // a category, so it's been removed to avoid the two concepts
          // colliding.
          initialValue: category,
          items: [
            for (final c in widget.categories)
              DropdownMenuItem(value: c.value, child: Text(c.displayName)),
          ],
          onChanged: (value) => _selectCategory(value!),
        ),
        SizedBox(height: gap),
        _label('How is it tracked?'),
        _trackingSelector(),
        SizedBox(height: gap),
        if (_isBulk) ...[
          _label('Quantity on hand'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'e.g. 50'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: unitController,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(hintText: 'unit — pcs'),
                ),
              ),
            ],
          ),
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
        ] else ...[
          _label('Add to'),
          _destinationSelector(),
          SizedBox(height: gap),
        ],
        _label('Date of purchase'),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _pickPurchaseDate,
          child: InputDecorator(
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
            ),
            child: Text(
              purchaseDate == null
                  ? 'Select date'
                  : AssetItem.formatDate(purchaseDate!),
              style: TextStyle(
                color: purchaseDate == null ? AppTheme.muted : AppTheme.darkGreen,
                fontSize: 16,
              ),
            ),
          ),
        ),
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
        SizedBox(height: widget.compact ? 22 : 40),
        if (widget.onCancel != null)
          Row(
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
                  icon: const Icon(Icons.qr_code_2, size: 22),
                  label: const Text('Generate QR and save'),
                ),
              ),
            ],
          )
        else
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.qr_code_2, size: 26),
            label: const Text('Generate QR and save'),
          ),
      ],
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
  /// active, borrowable asset or as a backup "stock item" that stays off
  /// the borrowable pool. Persisted to the backend via the asset's
  /// `status` (`available` vs `in_stock`).
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
            title: 'Stock item',
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
            onTap: () => setState(() {
              tracking = AssetTracking.individual;
              _trackingTouched = true;
            }),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _destinationOption(
            selected: _isBulk,
            icon: Icons.inventory_2_outlined,
            title: 'Bulk quantity',
            subtitle: 'Counted stock',
            onTap: () => setState(() {
              tracking = AssetTracking.bulk;
              _trackingTouched = true;
            }),
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
                    const Icon(Icons.check_circle, size: 18, color: AppTheme.primary),
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
              child: Icon(Icons.image_outlined, color: AppTheme.primary, size: 38),
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