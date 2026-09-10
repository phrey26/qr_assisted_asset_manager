import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import '../widgets/add_asset_form.dart';
import '../widgets/brand_mark.dart';

/// Full-page "add asset" flow, used on mobile/narrow layouts where a modal
/// dialog would feel cramped. On desktop, [AddAssetDialog] is used instead
/// so the flow matches the QREMS hi-fi desktop mockups (a centered modal
/// over a dimmed inventory list).
class AddAssetScreen extends StatelessWidget {
  const AddAssetScreen({
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
              Row(
                children: [
                  const BrandMark(size: 84),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Text(
                      initialAsset == null ? 'Add new asset' : 'Edit asset',
                      style: const TextStyle(
                        color: AppTheme.darkGreen,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              AddAssetForm(
                categories: categories,
                existingBulk: existingBulk,
                initial: initialAsset,
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