import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/page_header.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, required this.assets, this.onCategoryTap});

  final List<AssetItem> assets;

  /// Invoked with the matching Inventory-page filter label (e.g. 'IT
  /// Equipment') when a category card is tapped. [AppShell] uses this to
  /// switch to the Inventory tab with that category already selected. When
  /// null, cards are shown but aren't tappable.
  final void Function(String inventoryCategory)? onCategoryTap;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final controller = TextEditingController();

  // $1: display name shown on the card. $2: the matching label in
  // InventoryScreen's category filter chips — kept as a separate field
  // since the two pages' labels don't match exactly (casing, "Vehicles"
  // vs "Vehicle") rather than relying on a fragile string transform.
  final categories = const [
    ('IT equipment', 'IT Equipment', Icons.devices_outlined, AppTheme.mint),
    ('Furniture', 'Furniture', Icons.chair_outlined, AppTheme.cream),
    ('Vehicles', 'Vehicle', Icons.directions_car_outlined, AppTheme.redTint),
    ('Tools', 'Tools', Icons.build_outlined, AppTheme.mint),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = controller.text.toLowerCase();
    final visible = categories
        .where((category) => category.$1.toLowerCase().contains(query))
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
                child: const PageHeader(
                  title: 'Categories',
                  subtitle: 'Browse assets by type',
                  showMark: false,
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
                    name: visible[index].$1,
                    icon: visible[index].$3,
                    color: visible[index].$4,
                    count: _countFor(visible[index].$1),
                    onTap: widget.onCategoryTap == null
                        ? null
                        : () => widget.onCategoryTap!(visible[index].$2),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
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