import 'package:flutter/material.dart';

import '../models/asset_item.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/asset_card.dart';
import '../widgets/card_container.dart';
import '../widgets/status_badge.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  String category = 'All categories';
  String status = 'All status';

  @override
  Widget build(BuildContext context) {
    final filtered = demoAssets.where((asset) {
      final categoryMatch =
          category == 'All categories' || asset.category == category;

      final statusMatch =
          status == 'All status' || asset.status == status;

      return categoryMatch && statusMatch;
    }).toList();

    return Column(
      children: [
        const AppHeader(
          title: 'Inventory',
          subtitle: 'Manage assets and equipment',
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search assets...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),

        const SizedBox(height: 10),

        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterButton(
                label: category,
                onTap: _chooseCategory,
              ),
              const SizedBox(width: 8),
              _FilterButton(
                label: status,
                onTap: _chooseStatus,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              20,
            ),
            itemCount: filtered.length,
            itemBuilder: (_, index) {
              final asset = filtered[index];

              return AssetCard(
                asset: asset,
                onTap: () => _showAsset(asset),
              );
            },
          ),
        ),
      ],
    );
  }

  void _chooseCategory() {
    _showChoices(
      'Asset category',
      [
        'All categories',
        'Equipment',
        'Supplies',
        'Furniture',
      ],
      (value) {
        setState(() {
          category = value;
        });
      },
    );
  }

  void _chooseStatus() {
    _showChoices(
      'Asset status',
      [
        'All status',
        'Available',
        'In use',
        'Low stock',
      ],
      (value) {
        setState(() {
          status = value;
        });
      },
    );
  }

  void _showChoices(
    String title,
    List<String> choices,
    ValueChanged<String> callback,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...choices.map(
                  (choice) {
                    return ListTile(
                      title: Text(choice),
                      onTap: () {
                        callback(choice);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAsset(AssetItem asset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              30,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        asset.name,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    StatusBadge(
                      label: asset.status,
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                DetailItem(
                  title: 'Asset ID',
                  value: asset.id,
                ),

                DetailItem(
                  title: 'Category',
                  value: asset.category,
                ),

                DetailItem(
                  title: 'Quantity',
                  value: asset.quantity.toString(),
                ),

                DetailItem(
                  title: 'Location',
                  value: asset.location,
                ),

                const SizedBox(height: 4),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.qr_code),
                    label: const Text('View QR code'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(
        Icons.keyboard_arrow_down,
        size: 17,
      ),
      label: Text(label),
    );
  }
}

class DetailItem extends StatelessWidget {
  final String title;
  final String value;

  const DetailItem({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}