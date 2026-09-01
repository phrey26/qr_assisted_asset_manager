import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';

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
    // Previous attempt wrapped the *whole* DropdownButton (text + its own
    // built-in arrow) in a Flexible. That let the outer Row compress it,
    // but a plain DropdownButton lays its own text+icon out internally
    // with MainAxisSize.min — squeezing it from outside doesn't make that
    // inner layout shrink gracefully, it just overflows *inside* the
    // button instead (which is the tiny "RIGHT OVERFLOWED" sliver visible
    // right at the arrow), and the arrow ends up rendered past the
    // button's now-too-small hit area, i.e. exactly the "arrow gets left
    // behind, hard to press" symptom.
    //
    // The fix is `isExpanded: true` on the DropdownButton itself: that
    // tells it to fill whatever width its parent (the Expanded below)
    // gives it, keeping the arrow pinned at a fixed, always-tappable
    // position on the right and letting the *text* (not the arrow) shrink
    // via ellipsis if it's ever the constrained part. Pairing that with
    // `width: double.infinity` on the outer pill (matching the filter
    // dropdown right above it) means this control always has a definite,
    // generous width to lay out in — on any device — instead of trying to
    // shrink-wrap to its own content and running out of room.
    final scale = Responsive.uiScale(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Row(
        children: [
          Text(
            'Sort by',
            style: TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              fontSize: 13 * scale,
            ),
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isDense: true,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: AppTheme.darkGreen,
                  size: 24 * scale,
                ),
                borderRadius: BorderRadius.circular(14),
                style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 14 * scale,
                ),
                items: options
                    .map(
                      (option) => DropdownMenuItem<T>(
                        value: option,
                        child: Text(
                          labelBuilder(option),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                // Without this, the closed (unopened) button centers its
                // selected-item text; with isExpanded's extra width now
                // available, that reads oddly far from the "Sort by"
                // label. Left-aligning keeps the value sitting right next
                // to its label the way it did before this fix.
                selectedItemBuilder: (context) => options
                    .map(
                      (option) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          labelBuilder(option),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (selected) {
                  if (selected != null) onChanged(selected);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}