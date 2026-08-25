import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';

class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({super.key, required this.nextTagId});

  final String nextTagId;

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
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
    Navigator.pop(
      context,
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  BrandMark(size: 84),
                  SizedBox(width: 28),
                  Expanded(
                    child: Text(
                      'Add new asset',
                      style: TextStyle(
                        color: AppTheme.darkGreen,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              _label('Asset name'),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Epson projector',
                ),
              ),
              const SizedBox(height: 28),
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
                    borderSide: const BorderSide(
                      color: AppTheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
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
              const SizedBox(height: 28),
              _label('Description'),
              TextField(
                controller: descriptionController,
                minLines: 3,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Serial no., condition, accessories included...',
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.qr_code_2, size: 26),
                label: const Text('Generate QR and save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          value,
          style: const TextStyle(
            color: AppTheme.darkGreen,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
