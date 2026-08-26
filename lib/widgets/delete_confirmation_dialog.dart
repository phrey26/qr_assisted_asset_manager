import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../theme/app_theme.dart';

/// Shows the "are you sure" confirmation dialog used whenever an admin
/// tries to delete an asset from the inventory (e.g. because it's broken,
/// lost, or otherwise no longer trackable). Returns `true` only if the
/// admin explicitly confirms the removal; `false`/`null` otherwise.
Future<bool> confirmAssetDeletion(BuildContext context, AssetItem asset) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: AppTheme.redTint,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
      ),
      title: const Text(
        'Remove this asset?',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppTheme.darkGreen,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      content: Text(
        'Are you sure you want to remove "${asset.name}" (${asset.tagId}) from the '
        'inventory? Use this once the asset is no longer usable — this action '
        'cannot be undone.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.muted, fontSize: 15, height: 1.4),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.darkGreen,
              side: const BorderSide(color: AppTheme.border, width: 2),
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Remove'),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}