import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/add_category_dialog.dart';
import '../widgets/page_header.dart';
import '../widgets/select_category_to_delete_dialog.dart';
import 'select_category_to_delete_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({
    super.key,
    required this.assets,
    required this.categories,
    this.onCategoryTap,
    this.onAddCategory,
    this.onDeleteCategory,
  });

  final List<AssetItem> assets;

  /// The categories to show as cards. Owned by [AppShell] and shared with
  /// the Inventory filter chips and Add Asset dropdown, so a category
  /// added here immediately shows up there too.
  final List<AssetCategory> categories;

  /// Invoked with the matching Inventory-page filter label (e.g. 'IT
  /// Equipment') when a category card is tapped. [AppShell] uses this to
  /// switch to the Inventory tab with that category already selected. When
  /// null, cards are shown but aren't tappable.
  final void Function(String inventoryCategory)? onCategoryTap;

  /// Invoked with the new category once the admin fills in and confirms
  /// the "Add new category" dialog. When null, no add affordance is shown
  /// (the desktop inline button is hidden; [CategoriesScreenState]'s
  /// dialog opener still works for a FAB wired up elsewhere, but simply
  /// won't add anything).
  final void Function(AssetCategory category)? onAddCategory;

  /// Invoked when the admin confirms (via the "are you sure" dialog) that
  /// they want to remove a category. When null, no delete affordance is
  /// shown at all (the desktop "Delete category" toolbar button is
  /// hidden; [CategoriesScreenState]'s dialog opener still works for a
  /// FAB wired up elsewhere, but simply won't remove anything).
  /// [CategoriesScreenState] only ever calls this for a category with no
  /// assets currently filed under it — deletion is blocked (with an
  /// explanatory message) otherwise, so this never has to reassign or
  /// orphan any asset's category.
  final void Function(AssetCategory category)? onDeleteCategory;

  @override
  State<CategoriesScreen> createState() => CategoriesScreenState();
}

/// Public so [AppShell] can reach [openAddCategoryDialog] and
/// [openDeleteCategoryDialog] via a [GlobalKey] and trigger them from the
/// shared mobile FABs, the same way it drives [InventoryScreenState]'s
/// "add asset" flow.
class CategoriesScreenState extends State<CategoriesScreen> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Opens the "add new category" dialog and, if the admin confirms,
  /// forwards the result to [CategoriesScreen.onAddCategory].
  Future<void> openAddCategoryDialog() async {
    if (widget.onAddCategory == null) return;
    final category = await showAddCategoryDialog(
      context,
      existingNames: widget.categories.map((c) => c.displayName).toList(),
    );
    if (category != null) widget.onAddCategory!(category);
  }

  /// Opens the "which category should I delete?" picker; the picker
  /// itself runs the validation/confirmation flow
  /// ([validateAndConfirmCategoryDeletion]) and only returns a category
  /// once the admin has picked one that's actually deletable and
  /// confirmed the removal. This is the single delete entry point now —
  /// the desktop toolbar button and the mobile circular FAB both call
  /// this instead of each card having its own delete button, so there's
  /// one consistent "choose a category, then confirm" flow regardless of
  /// platform.
  ///
  /// The picker itself differs by platform: desktop keeps the centered
  /// dialog (it's already comfortably sized there), while mobile pushes a
  /// full page instead — a dialog sized for one phone either clips or
  /// looks lost on another, whereas a page scales with the rest of the
  /// mobile UI on any screen size.
  Future<void> openDeleteCategoryDialog() async {
    if (widget.onDeleteCategory == null) return;
    // Both pickers now run the full "can this be deleted?" validation and
    // the "are you sure" confirmation themselves — see
    // [validateAndConfirmCategoryDeletion] — before ever popping. So a
    // non-null result here means the admin has already explicitly
    // confirmed removing this category; there's nothing left to check.
    final category = Responsive.isDesktop(context)
        ? await showSelectCategoryToDeleteDialog(
            context,
            categories: widget.categories,
            itemCountFor: (c) => _countFor(c.value),
          )
        : await showSelectCategoryToDeleteScreen(
            context,
            categories: widget.categories,
            itemCountFor: (c) => _countFor(c.value),
          );
    if (category == null) return;
    // Still deferred to the next frame, same as [AppShell._setIndex]: this
    // removes a card from the Categories grid, and on mobile the picker's
    // pop transition may still be animating when we get here, so mutating
    // the tree immediately risks the same mouse-tracker reentrancy that
    // [validateAndConfirmCategoryDeletion]'s doc comment explains in
    // detail. Waiting a frame lets that transition settle first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDeleteCategory?.call(category);
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = controller.text.toLowerCase();
    final visible = widget.categories
        .where((category) => category.displayName.toLowerCase().contains(query))
        .toList();

    final isDesktop = Responsive.isDesktop(context);
    final maxWidth = isDesktop ? 1040.0 : double.infinity;
    final columns = Responsive.categoryColumns(context);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 42, 28, 0),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: PageHeader(
                        title: 'Categories',
                        subtitle: 'Browse assets by type',
                        showMark: false,
                      ),
                    ),
                    if (isDesktop && widget.onDeleteCategory != null) ...[
                      const SizedBox(width: 16),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: OutlinedButton.icon(
                          onPressed: openDeleteCategoryDialog,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete category'),
                          // Same override as the "Add category" button
                          // below — see its comment for why this is
                          // needed.
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent, width: 2),
                            minimumSize: const Size(0, 48),
                          ),
                        ),
                      ),
                    ],
                    if (isDesktop && widget.onAddCategory != null) ...[
                      const SizedBox(width: 16),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ElevatedButton.icon(
                          onPressed: openAddCategoryDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add category'),
                          // Override the global button theme's
                          // Size.fromHeight(64), which sets an infinite
                          // minimum width intended for full-bleed buttons.
                          // Left as-is, a Row (which gives non-flex
                          // children unbounded width) can't lay this
                          // button out, which blanks the whole page.
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 26),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isDesktop ? 360 : double.infinity),
                    child: TextField(
                      controller: controller,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search categories',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visible.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: Responsive.categoryCardAspectRatio(context),
                  ),
                  itemBuilder: (_, index) => _CategoryCard(
                    name: visible[index].displayName,
                    icon: visible[index].icon,
                    color: visible[index].color,
                    count: _countFor(visible[index].value),
                    onTap: widget.onCategoryTap == null
                        ? null
                        : () => widget.onCategoryTap!(visible[index].value),
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: Responsive.bottomScrollClearance(context))),
      ],
    );
  }

  int _countFor(String category) {
    return widget.assets.where((a) => a.category.toLowerCase() == category.toLowerCase()).length;
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.name,
    required this.icon,
    required this.color,
    required this.count,
    this.onTap,
  });

  final String name;
  final IconData icon;
  final Color color;
  final int count;

  /// Invoked when the card is tapped. Wired up by [CategoriesScreen] to
  /// jump to the Inventory tab with this category already selected.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconSize = Responsive.categoryIconSize(context);
    final scale = Responsive.fontScale(context);
    final isMobile = Responsive.isMobile(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(iconSize * .22),
                  ),
                  child: Icon(icon, size: iconSize * .43, color: AppTheme.primary),
                ),
                const Spacer(),
                Text(
                  name,
                  // Keep the label to a single line on every breakpoint: with a
                  // fixed-aspect-ratio grid cell, letting a long name wrap to a
                  // second line is what previously pushed the card's content
                  // past the cell's bottom edge on narrow phones.
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20 * scale,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkGreen,
                  ),
                ),
                SizedBox(height: isMobile ? 4 : 7),
                Text(
                  '$count items',
                  style: TextStyle(fontSize: 17 * scale, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}