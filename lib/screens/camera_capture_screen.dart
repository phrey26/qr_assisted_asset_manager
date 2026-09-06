import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Full-screen camera view with a shutter button, pushed as a route and
/// returning the captured photo as `Uint8List` (or null if cancelled).
///
/// Used for taking asset / request-form photos on platforms where
/// `image_picker` can't reach a camera (Windows). Android and iOS keep
/// using `image_picker`'s own camera UI.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key, this.title = 'Take photo'});

  final String title;

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
          'no_camera',
          'No camera was found on this device.',
        );
      }
      _cameras = cameras;
      _cameraIndex = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_cameraIndex < 0) _cameraIndex = 0;
      await _bind(_cameras[_cameraIndex]);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = e.description?.trim().isNotEmpty == true
            ? e.description!
            : 'Could not open the camera (${e.code}).';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Could not open the camera on this device.';
      });
    }
  }

  Future<void> _bind(CameraDescription camera) async {
    final previous = _controller;
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    await previous?.dispose();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _initializing = false;
      _error = null;
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _initializing = true);
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    try {
      await _bind(_cameras[_cameraIndex]);
    } catch (_) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'Could not switch camera.';
        });
      }
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _capturing ||
        controller.value.isTakingPicture) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop<Uint8List>(bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not capture the photo. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined,
                  color: Colors.white70, size: 44),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 10),
              const Text(
                'On Windows, check Settings › Privacy & security › Camera '
                'and allow desktop apps to use the camera.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (_initializing || controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: CameraPreview(controller),
          ),
        ),
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                tooltip: 'Cancel',
              ),
              GestureDetector(
                onTap: _capturing ? null : _capture,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: AppTheme.primary, width: 4),
                  ),
                  child: _capturing
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppTheme.primary,
                          ),
                        )
                      : const Icon(Icons.camera_alt,
                          color: AppTheme.primary, size: 30),
                ),
              ),
              IconButton(
                onPressed: _cameras.length < 2 ? null : _switchCamera,
                icon: Icon(
                  Icons.cameraswitch_outlined,
                  color: _cameras.length < 2 ? Colors.white24 : Colors.white,
                  size: 28,
                ),
                tooltip: 'Switch camera',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
