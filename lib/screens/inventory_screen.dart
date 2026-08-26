import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/asset_card.dart';
import '../widgets/page_header.dart';
import '../widgets/status_chip.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, required this.assets, this.onAddAsset});

  final List<AssetItem> assets;

  /// Invoked when the user wants to add a new asset. On mobile this is
  /// triggered by the FAB in [AppShell]; on desktop it's also wired to the
  /// inline "+ Add asset" button next to the page title, matching the
  /// hi-fi desktop mockups.
  final VoidCallback? onAddAsset;

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
    final isDesktop = Responsive.isDesktop(context);
    final maxWidth = isDesktop ? 1040.0 : double.infinity;

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
                    Expanded(
                      child: PageHeader(
                        title: 'Inventory',
                        subtitle: '${widget.assets.length} assets tracked',
                        showMark: false,
                      ),
                    ),
                    if (isDesktop && widget.onAddAsset != null) ...[
                      const SizedBox(width: 16),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ElevatedButton.icon(
                          onPressed: widget.onAddAsset,
                          icon: const Icon(Icons.add),
                          label: const Text('Add asset'),
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
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 18),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isDesktop ? 360 : double.infinity),
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search by name or tag ID',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _filters(),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isDesktop)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 40),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: _InventoryTable(assets: filtered),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 4, 28, 110),
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

/// Desktop-only data-table presentation of the inventory list, matching the
/// hi-fi desktop mockups (a wide table reads better than stacked cards once
/// there's room for it).
class _InventoryTable extends StatelessWidget {
  const _InventoryTable({required this.assets});

  final List<AssetItem> assets;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 1.5),
        ),
        child: const Center(
          child: Text('No assets match your search.', style: TextStyle(color: AppTheme.muted)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF6F5F0)),
          columns: const [
            DataColumn(label: Text('Asset')),
            DataColumn(label: Text('Tag ID')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Status')),
          ],
          rows: assets
              .map(
                (asset) => DataRow(
                  cells: [
                    DataCell(Text(
                      asset.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.darkGreen),
                    )),
                    DataCell(Text(
                      asset.tagId,
                      style: const TextStyle(fontFamily: 'monospace', color: AppTheme.muted),
                    )),
                    DataCell(Text(asset.category)),
                    DataCell(StatusChip(status: asset.status)),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
