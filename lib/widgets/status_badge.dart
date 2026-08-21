import 'package:flutter/material.dart';

enum StatusType {
  available,
  approved,
  pending,
  rejected,
  lowStock,
  inUse,
  neutral,
}

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType? type;

  const StatusBadge({
    super.key,
    required this.label,
    this.type,
  });

  StatusType get resolvedType {
    if (type != null) {
      return type!;
    }

    switch (label.toLowerCase()) {
      case 'available':
      case 'returned':
      case 'approved':
        return StatusType.approved;

      case 'pending':
        return StatusType.pending;

      case 'rejected':
        return StatusType.rejected;

      case 'low stock':
        return StatusType.lowStock;

      case 'in use':
      case 'checked out':
        return StatusType.inUse;

      default:
        return StatusType.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    late Color background;
    late Color foreground;

    switch (resolvedType) {
      case StatusType.available:
      case StatusType.approved:
        background = const Color(0xFFE6F3D8);
        foreground = const Color(0xFF3D6825);

      case StatusType.pending:
        background = const Color(0xFFFFE8C7);
        foreground = const Color(0xFF81531A);

      case StatusType.rejected:
        background = const Color(0xFFF7DADA);
        foreground = const Color(0xFF8C2929);

      case StatusType.lowStock:
        background = const Color(0xFFFFE5E1);
        foreground = const Color(0xFF98382E);

      case StatusType.inUse:
        background = const Color(0xFFDCEAF8);
        foreground = const Color(0xFF285B88);

      case StatusType.neutral:
        background = const Color(0xFFE2E2DF);
        foreground = const Color(0xFF454542);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}