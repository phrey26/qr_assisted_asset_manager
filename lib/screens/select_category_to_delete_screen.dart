import 'package:flutter/material.dart';

import '../models/category.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/delete_category_dialog.dart';

/// Full-page version of the "which category should I delete?" picker,
/// used on mobile in place of [showSelectCategoryToDeleteDialog]'s fixed-
/// width dialog. A dialog sized for one phone either clips or looks lost
/// on another; a page instead just takes the full screen and scales with
/// [Responsive.uiScale] like the rest of the mobile UI, so it holds up
/// from the smallest supported phone to the largest.
///
/// Returns the selected [AssetCategory] via [Navigator.pop] once the admin
/// has picked one *and* the delete has cleared validation and been
/// confirmed (via [validateAndConfirmCategoryDeletion]), or null if the
/// admin backs out without picking one, picks one that can't be deleted,
/// or declines the confirmation. Doing the whole warn/confirm flow here,
/// before this page ever pops, is what avoids the mouse-tracker crash
/// documented on [validateAndConfirmCategoryDeletion] — see that function
/// for the full explanation.
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

  // Leaving this page (AppBar back button, system back gesture, or the
  // hardware back button) while the "can't delete" SnackBar from a
  // previous tap is still showing hit the exact same mouse-tracker crash
  // documented on [validateAndConfirmCategoryDeletion]: the SnackBar's own
  // exit animation was still running its overlay mutation while this
  // page's pop transition started animating over it, and the two landed
  // on the same frame's mouse-device update. `removeCurrentSnackBar()` —
  // *not* `clearSnackBars()`, which despite the name still runs the
  // SnackBar's normal reverse animation — is what actually removes it
  // immediately with no animation to race the pop transition, so it's
  // always called right before this page actually pops, whichever way
  // that pop was triggered.
  void _dismissSnackBarsThenPop(BuildContext context, [AssetCategory? result]) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.uiScale(context);
    return PopScope(
      // System back gesture / hardware back button also need to clear the
      // SnackBar first — a plain Navigator.pop() call (as in the AppBar
      // button below) bypasses PopScope entirely, but the system back
      // gesture routes through it, so it needs its own handling here.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _dismissSnackBarsThenPop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Delete a category', style: TextStyle(fontWeight: FontWeight.w800)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () => _dismissSnackBarsThenPop(context),
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
                    final count = itemCountFor(category);
                    return _CategoryTile(
                      category: category,
                      count: count,
                      scale: scale,
                      onTap: () async {
                        final result = await validateAndConfirmCategoryDeletion(
                          context,
                          category,
                          itemCount: count,
                          totalCategoryCount: categories.length,
                        );
                        if (result != null && context.mounted) {
                          _dismissSnackBarsThenPop(context, result);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
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