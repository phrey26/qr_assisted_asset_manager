import 'package:flutter/material.dart';

import '../models/category.dart';
import '../theme/app_theme.dart';

/// Shows the "are you sure" confirmation dialog used whenever an admin
/// deletes a category. Only ever shown for a category with no assets in
/// it — [CategoriesScreen] blocks the delete (with an explanatory message,
/// no dialog) before this is reached if any assets are still filed under
/// it. Returns `true` only if the admin explicitly confirms the removal;
/// `false`/`null` otherwise.
Future<bool> confirmCategoryDeletion(BuildContext context, AssetCategory category) async {
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
      title: Text(
        'Delete "${category.displayName}"?',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.darkGreen,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      content: const Text(
        'This category has no assets in it. This action cannot be undone.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.muted, fontSize: 15, height: 1.4),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        // `actions` is laid out by an internal OverflowBar, not a Row/Flex,
        // so Expanded can't be a direct child here (that's what was
        // throwing "Incorrect use of ParentDataWidget"). Wrapping the
        // buttons in an explicit Row gives Expanded the Flex ancestor it
        // needs while still splitting the width evenly between them.
        Row(
          children: [
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
                child: const Text('Delete'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Runs the full "can this be deleted?" flow for [category]: refuses
/// outright with a [SnackBar] (no confirmation dialog) if any assets are
/// still filed under it or if it's the last remaining category, otherwise
/// shows [confirmCategoryDeletion]'s "are you sure" dialog. Returns
/// [category] only if the admin should actually go ahead and delete it;
/// `null` if the delete was refused or the admin backed out of the
/// confirmation.
///
/// Deliberately called from inside the category picker (the mobile full
/// page or the desktop dialog) *before* that picker's own [Navigator.pop],
/// rather than back in [CategoriesScreenState] afterwards. Showing a
/// SnackBar/dialog right after popping the picker used to race Flutter's
/// mouse tracker: on mobile, the picker is a full [MaterialPageRoute], and
/// its slide-away pop transition runs over several frames, each of which
/// re-hit-tests every newly-revealed hoverable widget on the Categories
/// tab underneath. Inserting a SnackBar into that Scaffold's overlay while
/// the transition was still animating landed the mutation mid mouse-device
/// update, throwing "'!_debugDuringDeviceUpdate': is not true" and
/// crashing the app right as the "still has assets" warning appeared.
/// Running the whole warn/confirm flow first and popping only once, with a
/// final go/no-go answer, means the picker's pop is the very last thing
/// that happens — nothing else touches the overlay while its transition is
/// still in flight.
Future<AssetCategory?> validateAndConfirmCategoryDeletion(
  BuildContext context,
  AssetCategory category, {
  required int itemCount,
  required int totalCategoryCount,
}) async {
  if (itemCount > 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Can\'t delete "${category.displayName}" — $itemCount '
          '${itemCount == 1 ? 'asset is' : 'assets are'} still filed under it. '
          'Reassign or remove ${itemCount == 1 ? 'it' : 'them'} first.',
        ),
      ),
    );
    return null;
  }
  if (totalCategoryCount <= 1) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('At least one category is required.')),
    );
    return null;
  }
  final confirmed = await confirmCategoryDeletion(context, category);
  return confirmed ? category : null;
}