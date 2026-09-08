import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'asset.dart';

/// One movement on a bulk asset's stock ledger — the bulk equivalent of an
/// [AssetEvent]. Returned by `GET csdo_api/stock.php` under `movements`.
enum StockMovementKind {
  purchase,
  lent,
  returned,
  damaged,
  restored,
  disposed,
  adjusted,
  other,
}

extension StockMovementKindX on StockMovementKind {
  static StockMovementKind fromApi(String? value) {
    switch (value) {
      case 'purchase':
        return StockMovementKind.purchase;
      case 'lent':
        return StockMovementKind.lent;
      case 'returned':
        return StockMovementKind.returned;
      case 'damaged':
        return StockMovementKind.damaged;
      case 'restored':
        return StockMovementKind.restored;
      case 'disposed':
        return StockMovementKind.disposed;
      case 'adjusted':
        return StockMovementKind.adjusted;
      default:
        return StockMovementKind.other;
    }
  }

  String get label {
    switch (this) {
      case StockMovementKind.purchase:
        return 'Stock added';
      case StockMovementKind.lent:
        return 'Lent out';
      case StockMovementKind.returned:
        return 'Returned';
      case StockMovementKind.damaged:
        return 'Set aside damaged';
      case StockMovementKind.restored:
        return 'Repaired — back in stock';
      case StockMovementKind.disposed:
        return 'Disposed';
      case StockMovementKind.adjusted:
        return 'Count corrected';
      case StockMovementKind.other:
        return 'Movement';
    }
  }

  IconData get icon {
    switch (this) {
      case StockMovementKind.purchase:
        return Icons.add_shopping_cart_outlined;
      case StockMovementKind.lent:
        return Icons.outbound_outlined;
      case StockMovementKind.returned:
        return Icons.keyboard_return_outlined;
      case StockMovementKind.damaged:
        return Icons.report_gmailerrorred_outlined;
      case StockMovementKind.restored:
        return Icons.healing_outlined;
      case StockMovementKind.disposed:
        return Icons.delete_sweep_outlined;
      case StockMovementKind.adjusted:
        return Icons.tune_outlined;
      case StockMovementKind.other:
        return Icons.swap_vert;
    }
  }

  /// (background, foreground) tint pair for the ledger dot.
  (Color, Color) get colors {
    switch (this) {
      case StockMovementKind.purchase:
        return (AppTheme.mint, AppTheme.primary);
      case StockMovementKind.lent:
        return (AppTheme.cream, const Color(0xFF9A6512));
      case StockMovementKind.returned:
      case StockMovementKind.restored:
        return (AppTheme.mint, AppTheme.primary);
      case StockMovementKind.damaged:
      case StockMovementKind.disposed:
        return (AppTheme.redTint, const Color(0xFFC84040));
      case StockMovementKind.adjusted:
      case StockMovementKind.other:
        return (AppTheme.slateTint, AppTheme.muted);
    }
  }
}

class StockMovement {
  StockMovement({
    required this.id,
    required this.kind,
    required this.quantityDelta,
    required this.timestamp,
    this.balanceAfter,
    this.note,
    this.requestId,
  });

  final int id;
  final StockMovementKind kind;
  final int quantityDelta;
  final int? balanceAfter;
  final String? note;
  final int? requestId;
  final DateTime timestamp;

  /// "+12" / "−3" for display.
  String get deltaLabel =>
      '${quantityDelta >= 0 ? '+' : '−'}${quantityDelta.abs()}';

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
        id: (json['id'] as num?)?.toInt() ?? 0,
        kind: StockMovementKindX.fromApi(json['kind'] as String?),
        quantityDelta: (json['quantity_delta'] as num?)?.toInt() ?? 0,
        balanceAfter: (json['balance_after'] as num?)?.toInt(),
        note: (json['note'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['note'] as String).trim(),
        requestId: (json['request_id'] as num?)?.toInt(),
        timestamp: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

class StockPurchase {
  StockPurchase({
    required this.id,
    required this.quantity,
    required this.createdAt,
    this.unitCost,
    this.totalCost,
    this.supplier,
    this.note,
    this.purchasedAt,
  });

  final int id;
  final int quantity;
  final double? unitCost;
  final double? totalCost;
  final String? supplier;
  final String? note;
  final DateTime? purchasedAt;
  final DateTime createdAt;

  DateTime get whenObtained => purchasedAt ?? createdAt;
  String get formattedDate => AssetItem.formatDate(whenObtained);

  factory StockPurchase.fromJson(Map<String, dynamic> json) => StockPurchase(
        id: (json['id'] as num?)?.toInt() ?? 0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        unitCost: (json['unit_cost'] as num?)?.toDouble(),
        totalCost: (json['total_cost'] as num?)?.toDouble(),
        supplier: (json['supplier'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['supplier'] as String).trim(),
        note: (json['note'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['note'] as String).trim(),
        purchasedAt: DateTime.tryParse(json['purchased_at'] as String? ?? ''),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

class StockSummary {
  StockSummary({
    required this.total,
    required this.out,
    required this.available,
    required this.lowStock,
    this.damaged = 0,
    this.reorderPoint,
  });

  final int total;
  final int out;
  final int damaged;
  final int available;
  final bool lowStock;
  final int? reorderPoint;

  factory StockSummary.fromJson(Map<String, dynamic> json) => StockSummary(
        total: (json['total'] as num?)?.toInt() ?? 0,
        out: (json['out'] as num?)?.toInt() ?? 0,
        damaged: (json['damaged'] as num?)?.toInt() ?? 0,
        available: (json['available'] as num?)?.toInt() ?? 0,
        lowStock: json['low_stock'] == true,
        reorderPoint: (json['reorder_point'] as num?)?.toInt(),
      );
}

class StockHistory {
  StockHistory({
    required this.summary,
    required this.movements,
    required this.purchases,
  });

  final StockSummary summary;
  final List<StockMovement> movements;
  final List<StockPurchase> purchases;

  factory StockHistory.fromJson(Map<String, dynamic> json) => StockHistory(
        summary: StockSummary.fromJson(
          (json['summary'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        movements: (json['movements'] as List<dynamic>? ?? [])
            .map((e) => StockMovement.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        purchases: (json['purchases'] as List<dynamic>? ?? [])
            .map((e) => StockPurchase.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}
