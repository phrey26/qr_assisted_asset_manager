import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Full-screen image viewing mode: a black backdrop with the image
/// centered and pinch/drag-to-zoom via [InteractiveViewer], plus a close
/// button. Pushed on top of whatever screen the image was tapped from.
class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({super.key, required this.imageBytes, this.heroTag, this.title});

  final Uint8List imageBytes;

  /// Optional [Hero] tag to animate from the thumbnail that was tapped.
  final Object? heroTag;

  /// Optional label shown in the app bar (e.g. "CSDO Request Form").
  final String? title;

  /// Pushes an [ImageViewerScreen] for [imageBytes] on top of the
  /// current screen.
  static void open(
    BuildContext context, {
    required Uint8List imageBytes,
    Object? heroTag,
    String? title,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: ImageViewerScreen(imageBytes: imageBytes, heroTag: heroTag, title: title),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.memory(imageBytes, fit: BoxFit.contain);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: title == null
            ? null
            : Text(title!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: heroTag == null ? image : Hero(tag: heroTag!, child: image),
          ),
        ),
      ),
    );
  }
}