import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';

/// The actual "add asset" form fields, shared between [AddAssetScreen]
/// (full page, used on mobile) and the desktop modal dialog. Keeping the
/// fields in one place means the mobile and desktop entry points can never
/// drift apart.
class AddAssetForm extends StatefulWidget {
  const AddAssetForm({
    super.key,
    required this.nextTagId,
    required this.onSave,
    this.onCancel,
    this.compact = false,
  });

  final String nextTagId;
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
  String category = 'IT equipment';

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    tagController.dispose();
    super.dispose();
  }

  void _save() {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an asset name.')),
      );
      return;
    }
    widget.onSave(
      AssetItem(
        name: nameController.text.trim(),
        tagId: tagController.text.trim(),
        category: category,
        description: descriptionController.text.trim(),
        status: AssetStatus.available,
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
          initialValue: category,
          items: const [
            DropdownMenuItem(value: 'IT equipment', child: Text('IT equipment')),
            DropdownMenuItem(value: 'Furniture', child: Text('Furniture')),
            DropdownMenuItem(value: 'Vehicles', child: Text('Vehicles')),
            DropdownMenuItem(value: 'Tools', child: Text('Tools')),
            DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
          ],
          onChanged: (value) => setState(() => category = value!),
        ),
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
}
