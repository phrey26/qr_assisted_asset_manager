import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../models/category.dart';
import 'add_asset_form.dart';

/// Centered modal used on desktop/wide layouts, matching the "Add new
/// asset" modal in the QREMS hi-fi desktop mockups. Also serves the "Edit
/// asset" flow when [initialAsset] is set.
class AddAssetDialog extends StatelessWidget {
  const AddAssetDialog({
    super.key,
    required this.categories,
    this.existingBulk = const [],
    this.initialAsset,
  });

  final List<AssetCategory> categories;
  final List<AssetItem> existingBulk;
  final AssetItem? initialAsset;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      initialAsset == null ? 'Add new asset' : 'Edit asset',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              AddAssetForm(
                categories: categories,
                existingBulk: existingBulk,
                initial: initialAsset,
                compact: true,
                onCancel: () => Navigator.pop(context),
                onSubmit: (result) =>
                    Navigator.pop<AddAssetResult>(context, result),
              ),
            ],
          ),
        ),
      ),
    );
  }
}