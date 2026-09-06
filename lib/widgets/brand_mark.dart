import 'package:flutter/material.dart';

/// The QREMS app mark: a deep-green rounded tile with three white
/// capsule "bars" of stepped heights and a red-orange dot floating above
/// the right bar (reading as a bar chart / a lowercase "i").
///
/// Drawn rather than shipped as an image so it stays crisp at every size
/// it's used (34 px in the sidebar up to 120 px on the login screen). The
/// same proportions and colours are reproduced by `tool/generate_app_icon.dart`
/// for the platform launcher icons — keep the two in sync.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 84});

  final double size;

  /// Tile background — the deep forest green of the logo.
  static const Color green = Color(0xFF123C2D);

  /// The three bars.
  static const Color bar = Color(0xFFEEF1EC);

  /// The dot above the right bar.
  static const Color dot = Color(0xFFE9503A);

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _BrandMarkPainter()),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;

    // Background tile.
    final tile = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, s, s),
      Radius.circular(s * 0.235),
    );
    canvas.drawRRect(tile, Paint()..color = BrandMark.green);

    // Bars share a baseline; each is a full capsule (corner radius = half
    // its width). Centres and tops as fractions of the tile size.
    const baseline = 0.665;
    final barWidth = s * 0.108;
    final barPaint = Paint()..color = BrandMark.bar;
    void drawBar(double centreX, double top) {
      final rect = Rect.fromLTRB(
        s * centreX - barWidth / 2,
        s * top,
        s * centreX + barWidth / 2,
        s * baseline,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2)),
        barPaint,
      );
    }

    drawBar(0.353, 0.400); // left — tall
    drawBar(0.500, 0.520); // middle — short
    drawBar(0.647, 0.380); // right — tallest, carries the dot

    // Dot above the right bar.
    canvas.drawCircle(
      Offset(s * 0.647, s * 0.298),
      s * 0.060,
      Paint()..color = BrandMark.dot,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
