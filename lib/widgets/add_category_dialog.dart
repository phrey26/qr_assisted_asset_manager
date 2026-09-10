import 'package:flutter/material.dart';

import '../models/category.dart';
import '../theme/app_theme.dart';
import 'add_category_form.dart';

/// Shows the "add new category" modal used on desktop/wide layouts — a
/// centered dialog over the dimmed Categories grid. Mobile pushes
/// [AddCategoryScreen] instead (see [CategoriesScreenState.openAddCategoryDialog]).
/// Returns the new [AssetCategory], or null if the admin cancels.
///
/// [existingNames] is used to reject duplicates (case-insensitively) so a
/// new category can never collide with one that already exists — that would
/// make assets impossible to tell apart by filter/dropdown.
Future<AssetCategory?> showAddCategoryDialog(
  BuildContext context, {
  required List<String> existingNames,
}) {
  return showDialog<AssetCategory>(
    context: context,
    builder: (_) => AddCategoryDialog(existingNames: existingNames),
  );
}

class AddCategoryDialog extends StatelessWidget {
  const AddCategoryDialog({super.key, required this.existingNames});

  final List<String> existingNames;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        // Wide enough that the icon grid and the tracking option cards sit
        // comfortably — the old 360-wide AlertDialog was cramped and, with
        // no scroll view, overflowed vertically. Matches AddAssetDialog.
        constraints: const BoxConstraints(maxWidth: 560),
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
                      'Add new category',
                      style: TextStyle(
                        color: AppTheme.darkGreen,
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
              const SizedBox(height: 6),
              AddCategoryForm(
                existingNames: existingNames,
                compact: true,
                onCancel: () => Navigator.pop(context),
                onSubmit: (category) =>
                    Navigator.pop<AssetCategory>(context, category),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
