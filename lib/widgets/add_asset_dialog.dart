import 'package:flutter/material.dart';

import '../models/asset.dart';
import 'add_asset_form.dart';

/// Centered modal used on desktop/wide layouts, matching the "Add new
/// asset" modal in the QREMS hi-fi desktop mockups.
class AddAssetDialog extends StatelessWidget {
  const AddAssetDialog({super.key, required this.nextTagId});

  final String nextTagId;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add new asset',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              AddAssetForm(
                nextTagId: nextTagId,
                compact: true,
                onCancel: () => Navigator.pop(context),
                onSave: (asset) => Navigator.pop<AssetItem>(context, asset),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
