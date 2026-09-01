import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// A single-select filter control: chips on desktop (where there's room to
/// lay every option out at once), and a compact dropdown on mobile.
///
/// On mobile this used to be the exact same [Wrap] of [ChoiceChip]s as
/// desktop. With four or five options that wrapped onto two or three
/// ragged, differently-wide lines — technically all visible and tappable,
/// but far from the clean single-line filter bar it looks like on a wider
/// screen. A dropdown collapses all of that into one tidy, full-width
/// control that always shows the current filter and never wraps, however
/// many/long the options are or however narrow the phone is.
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
    return Responsive.isMobile(context) ? _dropdown(context) : _chips();
  }

  Widget _chips() {
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

  Widget _dropdown(BuildContext context) {
    // Same scaling treatment as SortDropdown: padding/font/icon sizes now
    // shrink smoothly with the device instead of being fixed, so this
    // control (used here on Inventory, and reused as-is for the Requests
    // page status filter) doesn't run into the same kind of narrow-phone
    // overflow that hit the "Sort by" control next to it.
    final scale = Responsive.uiScale(context);
    return PopupMenuButton<String>(
      initialValue: selected,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border, width: 1.5),
      ),
      itemBuilder: (context) => [
        for (final item in options)
          PopupMenuItem<String>(
            value: item,
            child: Row(
              children: [
                SizedBox(
                  width: 22 * scale,
                  child: item == selected
                      ? Icon(Icons.check, size: 18 * scale, color: AppTheme.primary)
                      : null,
                ),
                SizedBox(width: 6 * scale),
                Flexible(
                  child: Text(
                    item,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.darkGreen,
                      fontWeight: item == selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 14 * scale,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 18 * scale, vertical: 16 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 2),
        ),
        child: Row(
          children: [
            Icon(Icons.filter_list, color: AppTheme.primary, size: 20 * scale),
            SizedBox(width: 12 * scale),
            Expanded(
              child: Text(
                selected,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 15 * scale,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: AppTheme.darkGreen, size: 24 * scale),
          ],
        ),
      ),
    );
  }
}