import 'package:flutter/widgets.dart';

/// Centralised breakpoints so every screen agrees on what counts as
/// "desktop" vs "mobile". A tablet held in portrait mode is treated as
/// mobile (single column, bottom nav); once it's roughly laptop-width
/// or wider we switch to the desktop shell (sidebar nav, multi-column
/// layouts) to match the QREMS hi-fi desktop mockups.
class Responsive {
  Responsive._();

  /// Below this width: phone/narrow-tablet layout.
  static const double mobileMax = 700;

  /// From [mobileMax] to this width: a mid-size layout (e.g. a tablet or
  /// a split-view phone). Currently treated the same as desktop for nav,
  /// but grids use fewer columns.
  static const double desktopMin = 900;

  static double widthOf(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isMobile(BuildContext context) => widthOf(context) < mobileMax;

  static bool isTablet(BuildContext context) {
    final w = widthOf(context);
    return w >= mobileMax && w < desktopMin;
  }

  /// True for laptop/desktop-sized windows (or a maximized browser tab).
  static bool isDesktop(BuildContext context) => widthOf(context) >= desktopMin;

  /// Convenience for anywhere that just needs "wide enough for the
  /// sidebar + multi-column desktop layout" (tablet landscape counts too).
  static bool isWide(BuildContext context) => widthOf(context) >= mobileMax;

  /// Number of grid columns for the categories grid at the current width.
  static int categoryColumns(BuildContext context) {
    final w = widthOf(context);
    if (w >= desktopMin) return 4;
    if (w >= mobileMax) return 3;
    return 2;
  }
}
