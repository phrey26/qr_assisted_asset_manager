import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A read-only request-period field that opens the platform date-range
/// picker. Both dates are shown explicitly so administrators can review the
/// asset's expected borrow and return dates before submitting a request.
class RequestDateRangeField extends StatelessWidget {
  const RequestDateRangeField({
    super.key,
    required this.borrowDate,
    required this.returnDate,
    required this.onTap,
    required this.formatDate,
  });

  final DateTime? borrowDate;
  final DateTime? returnDate;
  final VoidCallback onTap;
  final String Function(DateTime date) formatDate;

  @override
  Widget build(BuildContext context) {
    final hasRange = borrowDate != null && returnDate != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Borrowing period',
            style: TextStyle(
              color: AppTheme.darkGreen,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: InputDecorator(
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.date_range_outlined, size: 20),
              ),
              child: Text(
                hasRange
                    ? 'Borrow: ${formatDate(borrowDate!)}\nReturn: ${formatDate(returnDate!)}'
                    : 'Select borrow and return dates',
                style: TextStyle(
                  color: hasRange ? AppTheme.darkGreen : AppTheme.muted,
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
