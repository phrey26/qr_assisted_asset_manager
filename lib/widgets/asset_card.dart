import 'package:flutter/material.dart';

import '../models/asset_item.dart';
import '../theme/app_theme.dart';
import 'card_container.dart';
import 'status_badge.dart';

class AssetCard extends StatelessWidget {
  final AssetItem asset;
  final VoidCallback onTap;

  const AssetCard({
    super.key,
    required this.asset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: CardContainer(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary
                            .withOpacity(.12),
                        borderRadius:
                            BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.primary,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            asset.name,
                            style: const TextStyle(
                              fontWeight:
                                  FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),

                          Text(
                            asset.id,
                            style: const TextStyle(
                              color:
                                  AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),

                    StatusBadge(
                      label: asset.status,
                    ),
                  ],
                ),

                const SizedBox(height: 13),

                Row(
                  children: [
                    Text(
                      asset.category,
                      style: const TextStyle(
                        color:
                            AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),

                    const Spacer(),

                    Text(
                      'Qty: ${asset.quantity}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    const SizedBox(width: 4),

                    const Icon(
                      Icons.chevron_right,
                      size: 17,
                      color:
                          AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}