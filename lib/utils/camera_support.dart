import 'package:flutter/foundation.dart';

/// Platform capability flags for the camera-based features. Kept in one
/// place so the QR scanner and the photo pickers agree on what the build
/// they're running in can actually do — the plugins involved each cover a
/// different subset of platforms.

/// Whether `mobile_scanner` (live ML Kit / AVFoundation / BarcodeDetector
/// scanning) has a platform implementation here. It ships for Android,
/// iOS, macOS and web only; on Windows/Linux it throws a
/// `MissingPluginException` the moment the controller starts, so those
/// fall back to [nativeCameraSupported] + an in-Dart decoder instead.
bool get mobileScannerSupported {
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return false;
  }
}

/// Whether `image_picker` can capture a photo straight from a camera
/// here. Android and iOS only — on desktop `image_picker` just opens a
/// file-open dialog and `ImageSource.camera` throws `UnimplementedError`.
bool get imagePickerCameraSupported {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return true;
    default:
      return false;
  }
}

/// Whether the `camera` package (with `camera_windows` pulled in
/// explicitly) can give us a live preview and still capture here. Used
/// for photo capture where `image_picker` can't reach a camera, and for
/// the QR scanner on Windows where `mobile_scanner` can't.
bool get nativeCameraSupported {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.windows:
      return true;
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return false;
  }
}

/// Whether a photo can be captured from a camera at all on this build, by
/// either route. When false, the photo pickers show only "upload".
bool get cameraCaptureSupported =>
    imagePickerCameraSupported || nativeCameraSupported;
