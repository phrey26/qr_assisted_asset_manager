import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'lifespan_warning_badge.dart';
import 'status_chip.dart';

class AssetCard extends StatelessWidget {
  const AssetCard({
    super.key,
    required this.asset,
    this.onTap,
    this.onDelete,
    this.onUpdateStatus,
  });

  final AssetItem asset;

  /// Invoked when the card is tapped. Wired up by [InventoryScreen] to
  /// open the asset's detail page.
  final VoidCallback? onTap;

  /// Invoked when the admin confirms they want to remove this asset from
  /// the inventory (e.g. it's broken or otherwise unusable). When null, no
  /// delete affordance is shown — used to keep this widget reusable for
  /// non-admin contexts if they're added later.
  final VoidCallback? onDelete;

  /// Invoked with the newly-picked status when the admin changes it from
  /// the status chip's menu (e.g. flagging the asset as under
  /// maintenance). When null, the chip is a plain read-only label.
  final ValueChanged<AssetStatus>? onUpdateStatus;

  @override
  Widget build(BuildContext context) {
    // On phones the image tile, status chip, delete button and chevron were
    // all fixed-width siblings in the same Row as the text column. Added
    // together they could exceed the available card width, squeezing the
    // Expanded text column down to almost nothing — which is what made
    // Flutter wrap the tag ID one character per line in testing. Scaling
    // the tile/text down and moving the status chip into the text column
    // (instead of the trailing Row) on mobile keeps the text column wide
    // enough to lay out normally on any device.
    final isMobile = Responsive.isMobile(context);
    final imageSize = isMobile ? 68.0 : 108.0;
    final imageSpacing = isMobile ? 14.0 : 24.0;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
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
            padding: EdgeInsets.all(isMobile ? 14 : 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: imageSize,
                  height: imageSize,
                  decoration: BoxDecoration(
                    color: AppTheme.mint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: asset.imageBytes == null
                      ? Icon(
                          _iconFor(asset.category),
                          color: AppTheme.primary,
                          size: imageSize * .39,
                        )
                      : Image.memory(asset.imageBytes!, fit: BoxFit.cover),
                ),
                SizedBox(width: imageSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.darkGreen,
                          fontSize: isMobile ? 17 : 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: isMobile ? 6 : 8),
                      Text(
                        asset.tagId,
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: isMobile ? 13 : 16,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Purchased ${asset.formattedPurchaseDate}',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: isMobile ? 12 : 13,
                        ),
                      ),
                      if (asset.isPastLifespan) ...[
                        const SizedBox(height: 8),
                        const LifespanWarningBadge(),
                      ],
                      if (isMobile) ...[
                        const SizedBox(height: 8),
                        StatusChip(status: asset.status, onChanged: onUpdateStatus),
                      ],
                    ],
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 10),
                  StatusChip(status: asset.status, onChanged: onUpdateStatus),
                ],
                if (onDelete != null) ...[
                  SizedBox(width: isMobile ? 0 : 4),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.redAccent,
                    tooltip: 'Remove from inventory',
                  ),
                ],
                if (onTap != null) ...[
                  SizedBox(width: isMobile ? 0 : 2),
                  Padding(
                    padding: EdgeInsets.only(top: isMobile ? 12 : 0),
                    child: const Icon(Icons.chevron_right, color: AppTheme.muted),
                  ),
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