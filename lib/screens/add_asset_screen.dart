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
  const AddAssetScreen({super.key, required this.nextTagId, required this.categories});

  final String nextTagId;
  final List<AssetCategory> categories;

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
              AddAssetForm(
                nextTagId: nextTagId,
                categories: categories,
                onSave: (asset) => Navigator.pop<AssetItem>(context, asset),
              ),
            ],
          ),
        ),
      ),
    );
  }
}