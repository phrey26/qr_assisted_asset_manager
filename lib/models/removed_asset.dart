import '../models/asset.dart';

/// One entry in the permanent-removal audit log — an asset that was
/// deleted for good from the Stock Items screen, with the reason the admin
/// gave. Returned by `GET csdo_api/asset_removals.php`.
class RemovedAsset {
  RemovedAsset({
    required this.id,
    required this.tagId,
    required this.name,
    required this.reason,
    required this.removedAt,
    this.category,
    this.removedByName,
  });

  final int id;
  final String tagId;
  final String name;
  final String? category;
  final String reason;
  final DateTime removedAt;

  /// The admin who deleted it, when known. Null for a removal recorded
  /// before `asset_removals.removed_by_name` existed.
  final String? removedByName;

  /// e.g. "Jun 12, 2024" — reuses the app's shared date formatter.
  String get formattedDate => AssetItem.formatDate(removedAt);

  factory RemovedAsset.fromJson(Map<String, dynamic> json) => RemovedAsset(
        id: (json['id'] as num?)?.toInt() ?? 0,
        tagId: (json['tag_id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        category: (json['category'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['category'] as String,
        reason: (json['reason'] as String?) ?? '',
        removedByName: (json['removed_by_name'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['removed_by_name'] as String,
        removedAt: DateTime.tryParse(json['removed_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}
