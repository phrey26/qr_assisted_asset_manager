import 'asset.dart';

/// One entry in the permanent bulk-stock disposal log — units of a bulk
/// asset written off (broken, used up, lost, obsolete) with the reason the
/// admin gave. Returned by `GET csdo_api/bulk_disposals.php`.
class BulkDisposal {
  BulkDisposal({
    required this.id,
    required this.tagId,
    required this.name,
    required this.quantity,
    required this.reason,
    required this.disposedAt,
    this.category,
    this.disposedByName,
  });

  final int id;
  final String tagId;
  final String name;
  final String? category;
  final int quantity;
  final String reason;
  final DateTime disposedAt;

  /// The admin who disposed of it, when known. Null for a disposal
  /// recorded before `bulk_disposals.disposed_by_name` existed.
  final String? disposedByName;

  String get formattedDate => AssetItem.formatDate(disposedAt);

  factory BulkDisposal.fromJson(Map<String, dynamic> json) => BulkDisposal(
        id: (json['id'] as num?)?.toInt() ?? 0,
        tagId: (json['tag_id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        category: (json['category'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['category'] as String,
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        reason: (json['reason'] as String?) ?? '',
        disposedByName: (json['disposed_by_name'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['disposed_by_name'] as String,
        disposedAt: DateTime.tryParse(json['disposed_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}
