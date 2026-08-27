import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A small "Sort by" control styled to match the filter chips, usable with
/// any option type [T] (an enum, typically). Kept generic and separate
/// from any one screen so it can be reused wherever a sortable list needs
/// this control (currently the inventory list).
class SortDropdown<T> extends StatelessWidget {
  const SortDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.onChanged,
  });

  /// The currently-selected sort option.
  final T value;

  /// All selectable sort options, in menu order.
  final List<T> options;

  /// Renders an option (both the selected value and each menu item) as
  /// display text, e.g. `(SortOption.nameAsc) => 'A-Z'`.
  final String Function(T option) labelBuilder;

  /// Invoked with the newly-selected option.
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Sort by',
            style: TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.darkGreen),
              borderRadius: BorderRadius.circular(14),
              style: const TextStyle(
                color: AppTheme.darkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
              items: options
                  .map(
                    (option) => DropdownMenuItem<T>(
                      value: option,
                      child: Text(labelBuilder(option)),
                    ),
                  )
                  .toList(),
              onChanged: (selected) {
                if (selected != null) onChanged(selected);
              },
            ),
          ),
        ],
      ),
    );
  }
}