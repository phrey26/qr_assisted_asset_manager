import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/status_badge.dart';

class _AssetItem {
  final String name;
  final String id;
  final String category;
  final int qty;
  final String status;
  final BadgeTone tone;

  const _AssetItem({
    required this.name,
    required this.id,
    required this.category,
    required this.qty,
    required this.status,
    required this.tone,
  });
}

const _assets = [
  _AssetItem(
    name: 'Projector',
    id: 'CSDO-2024-0031',
    category: 'Equipment',
    qty: 3,
    status: 'Available',
    tone: BadgeTone.green,
  ),
  _AssetItem(
    name: 'Laptop',
    id: 'CSDO-2024-0007',
    category: 'Equipment',
    qty: 8,
    status: 'In use',
    tone: BadgeTone.blue,
  ),
  _AssetItem(
    name: 'Bond paper (A4)',
    id: 'CSDO-2024-0055',
    category: 'Supplies',
    qty: 3,
    status: 'Low stock',
    tone: BadgeTone.red,
  ),
  _AssetItem(
    name: 'Whiteboard marker',
    id: 'CSDO-2024-0019',
    category: 'Supplies',
    qty: 5,
    status: 'Low stock',
    tone: BadgeTone.orange,
  ),
];

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildCsdoAppBar(
        leadingIcon: Icons.inventory_2_outlined,
        title: 'Inventory',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add asset'),
                ),
              ),
              const SizedBox(width: 10),
              _IconSquareButton(icon: Icons.file_download_outlined, onTap: () {}),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search assets...',
              prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Expanded(child: _FilterDropdown(label: 'All categories')),
              SizedBox(width: 10),
              Expanded(child: _FilterDropdown(label: 'All status')),
            ],
          ),
          const SizedBox(height: 16),
          for (final asset in _assets) ...[
            _AssetCard(item: asset),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Showing 4 of 284 assets',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
              Row(
                children: [
                  _IconSquareButton(icon: Icons.chevron_left, onTap: () {}, size: 34),
                  const SizedBox(width: 8),
                  _IconSquareButton(icon: Icons.chevron_right, onTap: () {}, size: 34),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  const _FilterDropdown({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _IconSquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _IconSquareButton({required this.icon, required this.onTap, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  final _AssetItem item;
  const _AssetCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 10),
                child: Icon(Icons.check_box_outline_blank,
                    size: 18, color: AppColors.textMuted),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(item.id,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              StatusBadge(label: item.status, tone: item.tone),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${item.category} · Qty ${item.qty}',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary)),
              Row(
                children: const [
                  Icon(Icons.edit_outlined, size: 17, color: AppColors.textMuted),
                  SizedBox(width: 14),
                  Icon(Icons.qr_code_2, size: 17, color: AppColors.textMuted),
                  SizedBox(width: 14),
                  Icon(Icons.delete_outline, size: 17, color: AppColors.red),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
