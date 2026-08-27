import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A row of single-select filter chips (All / Available / In use / ...).
///
/// Previously each screen scrolled these horizontally inside a
/// [SingleChildScrollView], which meant the last chip (e.g. "Maintenance"
/// or "Rejected") got clipped by the screen edge on narrow phones with no
/// visual hint that more content was scrollable off-screen. Using [Wrap]
/// instead lets chips flow onto a second line when they don't fit, so
/// every option stays fully visible and tappable on any mobile width.
class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  /// The filter labels to display, in order (e.g. `['All', 'Available']`).
  final List<String> options;

  /// The currently-selected label. Should be one of [options].
  final String selected;

  /// Invoked with the tapped label when the user selects a different chip.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((item) {
        final isSelected = selected == item;
        return ChoiceChip(
          label: Text(item),
          selected: isSelected,
          onSelected: (_) => onSelected(item),
          selectedColor: AppTheme.darkGreen,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppTheme.border, width: 2),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppTheme.darkGreen,
            fontWeight: FontWeight.w800,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        );
      }).toList(),
    );
  }
}