import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
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

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 42, 28, 0),
          sliver: SliverToBoxAdapter(
            child: PageHeader(
              title: 'Categories',
              subtitle: 'Browse assets by type',
              showMark: false,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 26),
          sliver: SliverToBoxAdapter(
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
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, index) => _CategoryCard(
                name: visible[index].$1,
                icon: visible[index].$2,
                color: visible[index].$3,
                count: _countFor(visible[index].$1),
              ),
              childCount: visible.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
              childAspectRatio: .83,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 40, color: AppTheme.primary),
          ),
          const Spacer(),
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkGreen,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '$count items',
            style: const TextStyle(fontSize: 17, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}
