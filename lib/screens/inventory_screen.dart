import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import '../widgets/asset_card.dart';
import '../widgets/page_header.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, required this.assets});

  final List<AssetItem> assets;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final searchController = TextEditingController();
  String filter = 'All';

  @override
  void initState() {
    super.initState();
    searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<AssetItem> get filtered {
    final query = searchController.text.toLowerCase();
    return widget.assets.where((asset) {
      final matchesQuery = asset.name.toLowerCase().contains(query) ||
          asset.tagId.toLowerCase().contains(query);
      final matchesFilter = filter == 'All' ||
          (filter == 'Available' && asset.status == AssetStatus.available) ||
          (filter == 'In use' && asset.status == AssetStatus.inUse) ||
          (filter == 'Maintenance' && asset.status == AssetStatus.maintenance);
      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 42, 28, 0),
          sliver: SliverToBoxAdapter(
            child: PageHeader(
              title: 'Inventory',
              subtitle: '${widget.assets.length} assets tracked',
              showMark: false,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 18),
          sliver: SliverToBoxAdapter(
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Search by name or tag ID',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          sliver: SliverToBoxAdapter(child: _filters()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 110),
          sliver: SliverList.builder(
            itemCount: filtered.length,
            itemBuilder: (_, index) => AssetCard(asset: filtered[index]),
          ),
        ),
      ],
    );
  }

  Widget _filters() {
    const filters = ['All', 'Available', 'In use', 'Maintenance'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((item) {
          final selected = filter == item;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(item),
              selected: selected,
              onSelected: (_) => setState(() => filter = item),
              selectedColor: AppTheme.darkGreen,
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppTheme.border, width: 2),
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppTheme.darkGreen,
                fontWeight: FontWeight.w800,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          );
        }).toList(),
      ),
    );
  }
}
