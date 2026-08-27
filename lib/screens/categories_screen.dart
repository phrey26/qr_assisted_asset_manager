import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/page_header.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, required this.assets});

  final List<AssetItem> assets;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final controller = TextEditingController();

  final categories = const [
    ('IT equipment', Icons.devices_outlined, AppTheme.mint),
    ('Furniture', Icons.chair_outlined, AppTheme.cream),
    ('Vehicles', Icons.directions_car_outlined, AppTheme.redTint),
    ('Tools', Icons.build_outlined, AppTheme.mint),
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
                    icon: visible[index].$2,
                    color: visible[index].$3,
                    count: _countFor(visible[index].$1),
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
  });

  final String name;
  final IconData icon;
  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    final iconSize = Responsive.categoryIconSize(context);
    final scale = Responsive.fontScale(context);
    final isMobile = Responsive.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
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
    );
  }
}