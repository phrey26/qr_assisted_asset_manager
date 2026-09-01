import 'package:flutter/widgets.dart';

/// Centralised breakpoints so every screen agrees on what counts as
/// "desktop" vs "mobile". A tablet held in portrait mode is treated as
/// mobile (single column, bottom nav); once it's roughly laptop-width
/// or wider we switch to the desktop shell (sidebar nav, multi-column
/// layouts) to match the QREMS hi-fi desktop mockups.
///
/// [isMobile]/[isTablet]/[isDesktop] are still used for *structural*
/// decisions (which layout/nav shell to show). For *sizing* — fonts, card
/// paddings, icon tiles — use [uiScale] (or the [fontScale] alias) instead
/// of those booleans. A 3-step "mobile vs desktop" switch treats a 320px
/// "skinny" phone the same as a 430px phone, and doesn't account for
/// usable *height* at all, which is what was causing the size/overflow
/// problems described for narrow phones and phones with a tall on-screen
/// nav bar eating into the available height: [uiScale] scales continuously
/// with the device's actual width and usable height instead.
class Responsive {
  Responsive._();

  /// Below this width: phone/narrow-tablet layout.
  static const double mobileMax = 700;

  /// From [mobileMax] to this width: a mid-size layout (e.g. a tablet or
  /// a split-view phone). Currently treated the same as desktop for nav,
  /// but grids use fewer columns.
  static const double desktopMin = 900;

  // ---- reference ("design") metrics ----
  // The hi-fi mockups were built against a normal ~390x844 phone. Devices
  // narrower than a small ~320px phone, or with less than ~560px of
  // *usable* height once the system status/nav bars are subtracted, are
  // rare enough that scaling stops getting smaller past that point rather
  // than shrinking text unreadably small.
  static const double _refWidth = 320;
  static const double _refHeight = 844;
  static const double _shortHeight = 560;
  static const double _minScale = 0.78;
  static const double _maxScale = 1.05;

  static double widthOf(BuildContext context) => MediaQuery.sizeOf(context).width;

  static double heightOf(BuildContext context) => MediaQuery.sizeOf(context).height;

  /// Height actually available for content: full screen height minus the
  /// system status bar and — crucially — the bottom system inset (the
  /// on-screen 3-button nav bar or gesture-handle strip). That inset
  /// varies a lot between devices/manufacturers and otherwise wasn't
  /// accounted for anywhere in this app, which is what let the bottom nav
  /// and the content just above it collide with it on some phones.
  static double usableHeightOf(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.size.height - mq.padding.vertical;
  }

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

  /// True once there's little enough vertical room — a short phone, or a
  /// tall on-screen nav bar/notch eating into a normal-height one — that
  /// list rows, cards and the bottom nav should switch to their more
  /// compact spacing.
  static bool isShort(BuildContext context) => usableHeightOf(context) < 640;

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
  /// down on narrower/shorter screens (via [uiScale]) keeps the whole
  /// card inside its cell on any device, not just the two or three sizes
  /// that used to be tested.
  static double categoryIconSize(BuildContext context) {
    final w = widthOf(context);
    final base = w >= desktopMin
        ? 92.0
        : w >= mobileMax
            ? 84.0
            : 64.0;
    return w >= desktopMin ? base : base * uiScale(context);
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

  /// Continuous, device-size-aware scale multiplier for fonts, icons,
  /// padding and card metrics — the main entry point for sizing anything
  /// in this app.
  ///
  /// Two devices can both be "mobile" under [mobileMax] and still need
  /// very different sizing: a 360px-wide phone vs. a 430px-wide one, or
  /// two 390px-wide phones where one has a slim gesture indicator and the
  /// other a tall 3-button system nav bar eating into its usable height.
  /// This scales smoothly with the device's *actual* width and usable
  /// height instead of snapping between a couple of fixed breakpoints, so
  /// every device gets sizing tuned to it rather than being lumped into
  /// "mobile" or "desktop".
  ///
  /// Returns 1.0 at/above the desktop breakpoint (desktop sizing is
  /// unaffected), and scales down from there — driven by width, and
  /// additionally by usable height on phone/tablet-width devices — down
  /// to [_minScale] on the smallest/shortest screens this app supports.
  static double uiScale(BuildContext context) {
    final w = widthOf(context);
    final h = usableHeightOf(context);

    // Width component: 1.0 at/after desktopMin, sliding down to
    // _minScale as width shrinks toward a small ~320px phone.
    final double widthScale;
    if (w >= desktopMin) {
      widthScale = 1.0;
    } else {
      final t = ((w - _refWidth) / (desktopMin - _refWidth)).clamp(0.0, 1.0).toDouble();
      widthScale = _minScale + t * (1.0 - _minScale);
    }

    // Height component only applies at mobile/tablet widths — a short
    // desktop/browser window has scroll room a phone screen doesn't, so
    // it isn't penalised here. On phones it's what makes a device with a
    // tall on-screen nav bar (less usable height than its raw screen size
    // suggests) scale down a bit further than a same-width device without
    // one.
    double heightScale = 1.0;
    if (w < desktopMin) {
      final t = ((h - _shortHeight) / (_refHeight - _shortHeight)).clamp(0.0, 1.0).toDouble();
      heightScale = 0.88 + t * (1.0 - 0.88);
    }

    return (widthScale * heightScale).clamp(_minScale, _maxScale).toDouble();
  }

  /// Back-compat alias — every existing call site sizes text off
  /// [fontScale], which is just [uiScale] under a more specific name.
  static double fontScale(BuildContext context) => uiScale(context);

  /// Content height (icons + labels, *before* the bottom system inset is
  /// added on top) for the mobile bottom navigation bar. Previously fixed
  /// at 88 regardless of device: that either wasted space on tall-screen
  /// phones with just a slim gesture indicator, or — on phones with a
  /// tall 3-button system nav bar — left too little clearance above it,
  /// which is the "nav buttons ... having the height and width completely
  /// different" collision this fixes. Callers should add
  /// `MediaQuery.paddingOf(context).bottom` on top of this for the actual
  /// bar height, and inset the bar's content by that same amount (e.g. via
  /// `SafeArea(top: false, ...)`).
  static double bottomNavContentHeight(BuildContext context) {
    final base = isShort(context) ? 68.0 : 80.0;
    return base * uiScale(context).clamp(0.85, 1.0).toDouble();
  }

  /// Bottom padding a scrollable mobile screen needs so its last item
  /// isn't hidden behind the bottom nav bar (and, on tabs with one, the
  /// floating "add" button above it). Was previously a single fixed value
  /// (110) used on every device; that under-clears the bar on phones with
  /// a large bottom system inset (a tall 3-button nav bar) since it didn't
  /// account for that inset at all, and over-clears it on phones with
  /// none. Combines the actual current nav bar height (content + system
  /// inset) with a scaled margin for the FAB that floats above it.
  static double bottomScrollClearance(BuildContext context) {
    final navBarHeight = bottomNavContentHeight(context) + MediaQuery.paddingOf(context).bottom;
    return navBarHeight + 30 * uiScale(context);
  }
}