import 'package:flutter/material.dart';

import '../models/category.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// Full-page version of the "which category should I delete?" picker,
/// used on mobile in place of [showSelectCategoryToDeleteDialog]'s fixed-
/// width dialog. A dialog sized for one phone either clips or looks lost
/// on another; a page instead just takes the full screen and scales with
/// [Responsive.uiScale] like the rest of the mobile UI, so it holds up
/// from the smallest supported phone to the largest.
///
/// Returns the selected [AssetCategory] via [Navigator.pop], or null if
/// the admin backs out without picking one. Validation and the final
/// "are you sure" confirmation both happen afterwards, back in
/// [CategoriesScreenState] — this page is just the picker, same division
/// of responsibility as the dialog it replaces.
Future<AssetCategory?> showSelectCategoryToDeleteScreen(
  BuildContext context, {
  required List<AssetCategory> categories,
  required int Function(AssetCategory category) itemCountFor,
}) {
  return Navigator.push<AssetCategory>(
    context,
    MaterialPageRoute(
      builder: (_) => SelectCategoryToDeleteScreen(
        categories: categories,
        itemCountFor: itemCountFor,
      ),
    ),
  );
}

class SelectCategoryToDeleteScreen extends StatelessWidget {
  const SelectCategoryToDeleteScreen({
    super.key,
    required this.categories,
    required this.itemCountFor,
  });

  final List<AssetCategory> categories;
  final int Function(AssetCategory category) itemCountFor;

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete a category', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20 * scale, 16 * scale, 20 * scale, 4 * scale),
              child: Row(
                children: [
                  Container(
                    width: 44 * scale,
                    height: 44 * scale,
                    decoration: const BoxDecoration(color: AppTheme.redTint, shape: BoxShape.circle),
                    child: Icon(Icons.delete_outline, color: Colors.redAccent, size: 22 * scale),
                  ),
                  SizedBox(width: 12 * scale),
                  Expanded(
                    child: Text(
                      'Choose which category to remove.',
                      style: TextStyle(color: AppTheme.muted, fontSize: 14 * scale),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(20 * scale, 12 * scale, 20 * scale, 20 * scale),
                itemCount: categories.length,
                separatorBuilder: (_, __) => SizedBox(height: 10 * scale),
                itemBuilder: (_, index) {
                  final category = categories[index];
                  return _CategoryTile(
                    category: category,
                    count: itemCountFor(category),
                    scale: scale,
                    onTap: () => Navigator.pop(context, category),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.count,
    required this.scale,
    required this.onTap,
  });

  final AssetCategory category;
  final int count;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14 * scale),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 12 * scale),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border, width: 2),
            borderRadius: BorderRadius.circular(14 * scale),
          ),
          child: Row(
            children: [
              Container(
                width: 44 * scale,
                height: 44 * scale,
                decoration: BoxDecoration(
                  color: category.color,
                  borderRadius: BorderRadius.circular(10 * scale),
                ),
                child: Icon(category.icon, size: 20 * scale, color: AppTheme.primary),
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGreen,
                        fontSize: 15.5 * scale,
                      ),
                    ),
                    Text(
                      '$count ${count == 1 ? 'item' : 'items'}',
                      style: TextStyle(color: AppTheme.muted, fontSize: 13 * scale),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8 * scale),
              Icon(Icons.chevron_right, color: AppTheme.muted, size: 20 * scale),
            ],
          ),
        ),
      ),
    );
  }
}