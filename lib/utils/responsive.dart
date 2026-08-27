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

  /// Size (width/height) of the icon tile on a categories grid card.
  ///
  /// The hi-fi desktop mockups use a 92px tile, but at 2 columns on a
  /// narrow phone that leaves the fixed-aspect-ratio cell too short for
  /// the tile plus two lines of label text, which is what was causing the
  /// "BOTTOM OVERFLOWED BY n PIXELS" errors on device. Scaling the tile
  /// down on narrower screens keeps the whole card inside its cell.
  static double categoryIconSize(BuildContext context) {
    final w = widthOf(context);
    if (w >= desktopMin) return 92;
    if (w >= mobileMax) return 84;
    return 64;
  }

  /// Aspect ratio (width / height) for each categories grid cell. Smaller
  /// values make the cell taller relative to its width, which is needed
  /// on phones where 2 columns produce a narrower (and otherwise
  /// proportionally shorter) cell than the desktop 4-column layout.
  static double categoryCardAspectRatio(BuildContext context) {
    final w = widthOf(context);
    if (w >= desktopMin) return .83;
    if (w >= mobileMax) return .86;
    return .78;
  }

  /// General type-scale multiplier so text sized for the desktop mockups
  /// (e.g. page titles, card labels) shrinks a bit on phones instead of
  /// crowding/overflowing narrower layouts.
  static double fontScale(BuildContext context) {
    final w = widthOf(context);
    if (w >= desktopMin) return 1.0;
    if (w >= mobileMax) return 0.94;
    return 0.86;
  }
}