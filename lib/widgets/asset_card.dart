import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import 'status_chip.dart';

class AssetCard extends StatelessWidget {
  const AssetCard({super.key, required this.asset, this.onTap, this.onDelete});

  final AssetItem asset;

  /// Invoked when the card is tapped. Wired up by [InventoryScreen] to
  /// open the asset's detail page.
  final VoidCallback? onTap;

  /// Invoked when the admin confirms they want to remove this asset from
  /// the inventory (e.g. it's broken or otherwise unusable). When null, no
  /// delete affordance is shown — used to keep this widget reusable for
  /// non-admin contexts if they're added later.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    color: AppTheme.mint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _iconFor(asset.category),
                    color: AppTheme.primary,
                    size: 42,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.darkGreen,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        asset.tagId,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 16,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Purchased ${asset.formattedPurchaseDate}',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                StatusChip(status: asset.status),
                if (onDelete != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.redAccent,
                    tooltip: 'Remove from inventory',
                  ),
                ],
                if (onTap != null) ...[
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right, color: AppTheme.muted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String category) {
    final value = category.toLowerCase();
    if (value.contains('furniture')) return Icons.chair_outlined;
    if (value.contains('vehicle')) return Icons.directions_car_outlined;
    if (value.contains('tool')) return Icons.build_outlined;
    return Icons.devices_outlined;
  }
}