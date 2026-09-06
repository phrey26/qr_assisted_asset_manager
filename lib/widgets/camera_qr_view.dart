import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

import '../theme/app_theme.dart';

/// Live QR scanner backed by the `camera` package and an in-Dart `zxing2`
/// decoder, for the platforms `mobile_scanner` has no implementation for
/// (Windows). `camera_windows` has no image-stream support, so rather
/// than decoding a live frame buffer this grabs a still roughly every
/// [_scanInterval] with `takePicture()` and decodes it off the UI isolate
/// via [compute]. It's slower than the native scanners on mobile, but an
/// asset tag held still in frame resolves within a second or two.
class CameraQrView extends StatefulWidget {
  const CameraQrView({
    super.key,
    required this.onDetect,
    this.paused = false,
    this.overlay,
  });

  /// Called with the decoded text each time a QR code is read. May fire
  /// repeatedly for the same code — the caller is expected to debounce
  /// (the scanner screen already guards with `_isShowingResult`).
  final ValueChanged<String> onDetect;

  /// When true the camera is released and decoding stops. The scanner
  /// screen sets this while a scan result is on screen so the preview
  /// isn't running behind it.
  final bool paused;

  /// Painted over the preview (the corner-frame reticle).
  final Widget? overlay;

  @override
  State<CameraQrView> createState() => _CameraQrViewState();
}

class _CameraQrViewState extends State<CameraQrView> with WidgetsBindingObserver {
  static const _scanInterval = Duration(milliseconds: 700);

  CameraController? _controller;
  bool _starting = false;
  String? _error;
  Timer? _timer;
  bool _busy = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.paused) _start();
  }

  @override
  void didUpdateWidget(covariant CameraQrView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused && !oldWidget.paused) {
      _teardown();
    } else if (!widget.paused && oldWidget.paused) {
      _start();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.paused) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _teardown();
    } else if (state == AppLifecycleState.resumed) {
      _start();
    }
  }

  void _teardown() {
    _timer?.cancel();
    _timer = null;
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    if (_starting || _controller != null || _disposed) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
          'no_camera',
          'No camera was found on this device.',
        );
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        // 720p: enough detail to read a tag from across a desk without
        // making each takePicture()/decode cycle sluggish.
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (_disposed || widget.paused) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _starting = false;
      });
      _timer = Timer.periodic(_scanInterval, (_) => _scanOnce());
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = e.description?.trim().isNotEmpty == true
            ? e.description!
            : 'Could not open the camera (${e.code}).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = 'Could not open the camera on this device.';
      });
    }
  }

  Future<void> _scanOnce() async {
    final controller = _controller;
    if (_busy ||
        widget.paused ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }
    _busy = true;
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      // takePicture() writes a temp file we don't need once it's in memory.
      try {
        await File(file.path).delete();
      } catch (_) {}
      final text = await compute(_decodeQrFromImageBytes, bytes);
      if (text != null && text.isNotEmpty && mounted && !widget.paused) {
        widget.onDetect(text);
      }
    } catch (_) {
      // A single dropped/blurred frame is fine — the next tick retries.
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        color: AppTheme.redTint,
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined,
                  color: Color(0xFFC84040), size: 40),
              const SizedBox(height: 14),
              const Text(
                'Camera unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.darkGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.muted, fontSize: 14),
              ),
              const SizedBox(height: 6),
              const Text(
                'On Windows, check Settings › Privacy & security › Camera '
                'and allow desktop apps to use the camera, then try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                    fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: AppTheme.mint,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    final preview = controller.value.previewSize;
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: preview?.width ?? 4,
            height: preview?.height ?? 3,
            child: CameraPreview(controller),
          ),
        ),
        if (widget.overlay != null) IgnorePointer(child: widget.overlay!),
      ],
    );
  }
}

/// Decodes the first QR code found in an encoded image ([takePicture]
/// output). Runs on a background isolate via [compute]; returns null when
/// no code is present or the image can't be read.
String? _decodeQrFromImageBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  // Big frames only slow the decoder down without helping detection.
  final image =
      decoded.width > 1024 ? img.copyResize(decoded, width: 1024) : decoded;

  final rgba = image.getBytes(order: img.ChannelOrder.rgba);
  final pixels = Int32List(image.width * image.height);
  for (var i = 0; i < pixels.length; i++) {
    final o = i * 4;
    pixels[i] =
        0xFF000000 | (rgba[o] << 16) | (rgba[o + 1] << 8) | rgba[o + 2];
  }

  final source = RGBLuminanceSource(image.width, image.height, pixels);
  final bitmap = BinaryBitmap(HybridBinarizer(source));
  try {
    return QRCodeReader().decode(bitmap).text;
  } catch (_) {
    // NotFoundException / FormatReaderException / ChecksumException —
    // just means this frame had no readable code.
    return null;
  }
}
