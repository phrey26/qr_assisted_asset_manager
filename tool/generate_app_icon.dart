// Regenerates the brand PNGs that `flutter_launcher_icons` fans out into
// the per-platform launcher icons:
//
//   assets/branding/app_icon.png             1024x1024, green tile + mark
//   assets/branding/app_icon_foreground.png  1024x1024, transparent, mark
//                                            only, inset for Android's
//                                            adaptive-icon safe zone
//
// Run after changing the mark:
//   dart run tool/generate_app_icon.dart
//   dart run flutter_launcher_icons
//
// The geometry and colours below mirror `lib/widgets/brand_mark.dart` —
// keep the two in sync. This is a plain Dart script (no Flutter) so it
// can't import that widget directly.

import 'dart:io';

import 'package:image/image.dart' as img;

// --- Brand constants (mirror BrandMark) ---------------------------------
const _green = (r: 0x12, g: 0x3C, b: 0x2D);
const _bar = (r: 0xEE, g: 0xF1, b: 0xEC);
const _dot = (r: 0xE9, g: 0x50, b: 0x3A);

const _output = 1024;
const _supersample = 4; // render big, shrink down = cheap anti-aliasing

void main() {
  final dir = Directory('assets/branding')..createSync(recursive: true);

  _write('${dir.path}/app_icon.png', _render(withBackground: true, inset: 1.0));
  // flutter_launcher_icons adds its own ~16% inset on top of this when it
  // builds the adaptive foreground, so 0.90 here lands the mark at roughly
  // the 60%-of-icon size Android recommends for adaptive foregrounds.
  _write(
    '${dir.path}/app_icon_foreground.png',
    _render(withBackground: false, inset: 0.90),
  );

  stdout.writeln('Wrote assets/branding/app_icon.png and app_icon_foreground.png');
  stdout.writeln('Next: dart run flutter_launcher_icons');
}

void _write(String path, img.Image image) {
  File(path).writeAsBytesSync(img.encodePng(image));
}

/// Draws the mark on a transparent canvas and returns it downscaled to
/// [_output]. [inset] (0..1) scales the whole composition about the
/// centre — 1.0 fills the tile, smaller values pull it into the middle
/// for the adaptive-icon safe zone.
img.Image _render({required bool withBackground, required double inset}) {
  final s = _output * _supersample;
  final canvas = img.Image(width: s, height: s, numChannels: 4);

  final scale = s * inset;
  final origin = (s - scale) / 2;
  double px(double u) => origin + u * scale;
  double len(double u) => u * scale;

  if (withBackground) {
    img.fillRect(
      canvas,
      x1: px(0).round(),
      y1: px(0).round(),
      x2: px(1).round(),
      y2: px(1).round(),
      radius: len(0.235),
      color: img.ColorUint8.rgba(_green.r, _green.g, _green.b, 255),
    );
  }

  const baseline = 0.665;
  final barWidth = len(0.108);
  final barColor = img.ColorUint8.rgba(_bar.r, _bar.g, _bar.b, 255);

  void bar(double centreX, double top) {
    img.fillRect(
      canvas,
      x1: (px(centreX) - barWidth / 2).round(),
      y1: px(top).round(),
      x2: (px(centreX) + barWidth / 2).round(),
      y2: px(baseline).round(),
      radius: barWidth / 2,
      color: barColor,
    );
  }

  bar(0.353, 0.400); // left — tall
  bar(0.500, 0.520); // middle — short
  bar(0.647, 0.380); // right — tallest, carries the dot

  img.fillCircle(
    canvas,
    x: px(0.647).round(),
    y: px(0.298).round(),
    radius: len(0.060).round(),
    color: img.ColorUint8.rgba(_dot.r, _dot.g, _dot.b, 255),
    antialias: true,
  );

  return img.copyResize(
    canvas,
    width: _output,
    height: _output,
    interpolation: img.Interpolation.average,
  );
}
