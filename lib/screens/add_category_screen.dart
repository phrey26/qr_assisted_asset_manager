import 'package:flutter/material.dart';

import '../models/category.dart';
import '../utils/responsive.dart';
import '../widgets/add_category_form.dart';

/// Full-page "add new category" flow, used on mobile/narrow layouts in
/// place of [showAddCategoryDialog]'s centered modal — the same reasoning
/// as [AddAssetScreen] vs [AddAssetDialog]: a dialog sized for one phone
/// either clips or looks lost on another, whereas a page takes the whole
/// screen and scales with [Responsive.uiScale] like the rest of the mobile
/// UI. Returns the new [AssetCategory] via [Navigator.pop], or null if the
/// admin backs out.
Future<AssetCategory?> showAddCategoryScreen(
  BuildContext context, {
  required List<String> existingNames,
}) {
  return Navigator.push<AssetCategory>(
    context,
    MaterialPageRoute(
      builder: (_) => AddCategoryScreen(existingNames: existingNames),
    ),
  );
}

class AddCategoryScreen extends StatelessWidget {
  const AddCategoryScreen({super.key, required this.existingNames});

  final List<String> existingNames;

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add new category',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20 * scale,
            16 * scale,
            20 * scale,
            28 * scale,
          ),
          child: AddCategoryForm(
            existingNames: existingNames,
            onSubmit: (category) =>
                Navigator.pop<AssetCategory>(context, category),
          ),
        ),
      ),
    );
  }
}
