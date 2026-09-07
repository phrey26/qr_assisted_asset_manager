import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// How worn an asset was judged to be at a return inspection.
enum AssetCondition { good, fair, poor, damaged }

extension AssetConditionX on AssetCondition {
  String get label {
    switch (this) {
      case AssetCondition.good:
        return 'Good';
      case AssetCondition.fair:
        return 'Fair';
      case AssetCondition.poor:
        return 'Poor';
      case AssetCondition.damaged:
        return 'Damaged';
    }
  }

  String get apiValue => name;

  /// (background, foreground) tint, tracking the app's status palette:
  /// good reads like "available", damaged like "maintenance".
  (Color, Color) get colors {
    switch (this) {
      case AssetCondition.good:
        return (AppTheme.mint, AppTheme.primary);
      case AssetCondition.fair:
        return (AppTheme.cream, const Color(0xFF9A6512));
      case AssetCondition.poor:
        return (AppTheme.cream, const Color(0xFF9A6512));
      case AssetCondition.damaged:
        return (AppTheme.redTint, const Color(0xFFC84040));
    }
  }

  static AssetCondition fromApiValue(String? value) {
    switch (value) {
      case 'fair':
        return AssetCondition.fair;
      case 'poor':
        return AssetCondition.poor;
      case 'damaged':
        return AssetCondition.damaged;
      default:
        return AssetCondition.good;
    }
  }
}

/// One recorded return inspection: the condition the asset came back in,
/// optional notes, how long it was out, and photos taken at return.
class AssetInspection {
  AssetInspection({
    required this.id,
    required this.condition,
    required this.timestamp,
    this.requestTitle,
    this.borrowDate,
    this.returnDate,
    this.daysUsed,
    this.notes,
    this.photos = const [],
  });

  final int id;
  final AssetCondition condition;
  final DateTime timestamp;
  final String? requestTitle;
  final String? borrowDate;
  final String? returnDate;
  final int? daysUsed;
  final String? notes;
  final List<Uint8List> photos;

  factory AssetInspection.fromJson(Map<String, dynamic> json) {
    final rawPhotos = (json['photos'] as List<dynamic>? ?? []);
    return AssetInspection(
      id: (json['id'] as num?)?.toInt() ?? 0,
      condition: AssetConditionX.fromApiValue(json['asset_condition'] as String?),
      timestamp: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      requestTitle: (json['request_title'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['request_title'] as String,
      borrowDate: json['borrow_date'] as String?,
      returnDate: json['return_date'] as String?,
      daysUsed: (json['days_used'] as num?)?.toInt(),
      notes: (json['notes'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['notes'] as String,
      photos: [
        for (final p in rawPhotos)
          if (p is String && p.isNotEmpty) base64Decode(p),
      ],
    );
  }
}

/// Aggregate usage figures for an asset, shown at the top of its
/// "Condition & usage" card.
class AssetUsageSummary {
  AssetUsageSummary({
    required this.timesBorrowed,
    required this.daysUsed,
    required this.currentlyOut,
    this.currentCondition,
  });

  final int timesBorrowed;
  final int daysUsed;
  final bool currentlyOut;
  final AssetCondition? currentCondition;

  factory AssetUsageSummary.fromJson(Map<String, dynamic> json) => AssetUsageSummary(
        timesBorrowed: (json['times_borrowed'] as num?)?.toInt() ?? 0,
        daysUsed: (json['days_used'] as num?)?.toInt() ?? 0,
        currentlyOut: json['currently_out'] == true,
        currentCondition: json['current_condition'] == null
            ? null
            : AssetConditionX.fromApiValue(json['current_condition'] as String?),
      );
}

/// Full response of `GET csdo_api/asset_returns.php?tag_id=...`.
class AssetReturnHistory {
  AssetReturnHistory({required this.summary, required this.inspections});

  final AssetUsageSummary summary;
  final List<AssetInspection> inspections;

  factory AssetReturnHistory.fromJson(Map<String, dynamic> json) => AssetReturnHistory(
        summary: AssetUsageSummary.fromJson(
          (json['summary'] as Map<String, dynamic>?) ?? const {},
        ),
        inspections: (json['inspections'] as List<dynamic>? ?? [])
            .map((e) => AssetInspection.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
