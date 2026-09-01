import 'package:flutter/material.dart';

import '../models/category.dart';
import '../theme/app_theme.dart';

/// Shows a dialog listing every category so the admin can choose which one
/// to delete. Replaces the old per-card delete button — deletion is now
/// triggered from a single "Delete category" affordance (the desktop
/// toolbar button next to "Add category", or the mobile circular FAB),
/// which needs the admin to pick a target category first.
///
/// Returns the selected [AssetCategory], or null if the admin dismisses
/// the dialog without picking one. Validation (blocking deletion of a
/// category that still has assets, or the last remaining category) and the
/// final "are you sure" confirmation both happen afterwards, back in
/// [CategoriesScreenState] — this dialog is just the picker.
Future<AssetCategory?> showSelectCategoryToDeleteDialog(
  BuildContext context, {
  required List<AssetCategory> categories,
  required int Function(AssetCategory category) itemCountFor,
}) {
  return showDialog<AssetCategory>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: AppTheme.redTint,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
      ),
      title: const Text(
        'Delete a category',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.darkGreen, fontWeight: FontWeight.w800, fontSize: 20),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text(
                'Choose which category to remove.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted, fontSize: 14),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final category = categories[index];
                  return _CategoryTile(
                    category: category,
                    count: itemCountFor(category),
                    onTap: () => Navigator.pop(context, category),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.darkGreen,
              side: const BorderSide(color: AppTheme.border, width: 2),
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    ),
  );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.count, required this.onTap});

  final AssetCategory category;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: category.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(category.icon, size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGreen,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '$count ${count == 1 ? 'item' : 'items'}',
                      style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppTheme.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}