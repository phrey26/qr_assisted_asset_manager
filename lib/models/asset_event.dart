import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The kinds of things that can land on an asset's timeline. Mirrors the
/// `event_type` slugs written by `csdo_api` (see `db.php`'s
/// `log_asset_event` and `asset_events.php`).
enum AssetEventType {
  added,
  borrowed,
  returned,
  released,
  available,
  maintenance,
  inStock,
  edited,
  scanned,
  other,
}

/// One entry in an asset's history, as returned by
/// `GET csdo_api/asset_events.php?tag_id=...`.
class AssetEvent {
  AssetEvent({
    required this.type,
    required this.timestamp,
    this.detail,
    this.rawType,
    this.requestId,
    this.performedBy,
  });

  final AssetEventType type;
  final DateTime timestamp;

  /// Free-text context — usually a request title for borrow/return events.
  final String? detail;

  /// The original `event_type` string, kept so an unrecognised value can
  /// still be shown rather than silently dropped.
  final String? rawType;

  final int? requestId;

  /// The admin who did this, when known. Null for anything recorded before
  /// `asset_events.performed_by` existed, or from a write path that hasn't
  /// been updated to send one.
  final String? performedBy;

  static AssetEventType _parseType(String value) {
    switch (value) {
      case 'added':
        return AssetEventType.added;
      case 'borrowed':
        return AssetEventType.borrowed;
      case 'returned':
        return AssetEventType.returned;
      case 'released':
        return AssetEventType.released;
      case 'available':
        return AssetEventType.available;
      case 'maintenance':
        return AssetEventType.maintenance;
      case 'backup':
        return AssetEventType.inStock;
      case 'edited':
        return AssetEventType.edited;
      case 'scanned':
        return AssetEventType.scanned;
      default:
        return AssetEventType.other;
    }
  }

  static String? _cleanDetail(Object? value) {
    final text = (value as String?)?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  factory AssetEvent.fromJson(Map<String, dynamic> json) => AssetEvent(
        type: _parseType(json['event_type'] as String? ?? ''),
        rawType: json['event_type'] as String?,
        detail: _cleanDetail(json['detail']),
        requestId: (json['request_id'] as num?)?.toInt(),
        performedBy: _cleanDetail(json['performed_by']),
        timestamp: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );

  /// Headline shown for this event on the timeline.
  String get title {
    switch (type) {
      case AssetEventType.added:
        return 'Added to inventory';
      case AssetEventType.borrowed:
        return 'Borrowed';
      case AssetEventType.returned:
        return 'Returned';
      case AssetEventType.released:
        return 'Loan cancelled';
      case AssetEventType.available:
        return 'Marked available';
      case AssetEventType.maintenance:
        return 'Put under maintenance';
      case AssetEventType.inStock:
        return 'Moved to backup';
      case AssetEventType.edited:
        return 'Details edited';
      case AssetEventType.scanned:
        return 'Scanned';
      case AssetEventType.other:
        return rawType == null || rawType!.isEmpty ? 'Updated' : rawType!;
    }
  }

  IconData get icon {
    switch (type) {
      case AssetEventType.added:
        return Icons.add_circle_outline;
      case AssetEventType.borrowed:
        return Icons.logout;
      case AssetEventType.returned:
        return Icons.assignment_turned_in_outlined;
      case AssetEventType.released:
        return Icons.undo;
      case AssetEventType.available:
        return Icons.check_circle_outline;
      case AssetEventType.maintenance:
        return Icons.build_outlined;
      case AssetEventType.inStock:
        return Icons.archive_outlined;
      case AssetEventType.edited:
        return Icons.edit_outlined;
      case AssetEventType.scanned:
        return Icons.qr_code_scanner;
      case AssetEventType.other:
        return Icons.history;
    }
  }

  /// (circle tint, icon/foreground) for the timeline dot — reuses the
  /// app's status palette so a "Borrowed" dot reads like the "In use"
  /// chip, "Maintenance" like the maintenance chip, and so on.
  (Color, Color) get colors {
    switch (type) {
      case AssetEventType.added:
        return (AppTheme.mint, AppTheme.primary);
      case AssetEventType.borrowed:
        return (AppTheme.cream, const Color(0xFF9A6512));
      case AssetEventType.returned:
      case AssetEventType.available:
        return (AppTheme.mint, AppTheme.primary);
      case AssetEventType.released:
        return (AppTheme.slateTint, AppTheme.muted);
      case AssetEventType.maintenance:
        return (AppTheme.redTint, const Color(0xFFC84040));
      case AssetEventType.inStock:
        return (AppTheme.slateTint, AppTheme.muted);
      case AssetEventType.edited:
        return (AppTheme.slateTint, AppTheme.muted);
      case AssetEventType.scanned:
        return (AppTheme.mint, AppTheme.primary);
      case AssetEventType.other:
        return (AppTheme.border, AppTheme.muted);
    }
  }
}
