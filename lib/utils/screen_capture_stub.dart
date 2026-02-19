import 'dart:typed_data';

/// Stub implementation of ScreenCaptureWeb for non-web platforms (iOS, macOS, etc.).
/// These methods are no-ops since screen capture via browser API is web-only.
class ScreenCaptureWeb {
  static bool get isRecording => false;

  static Future<Uint8List?> captureScreenshot() async => null;

  static Future<bool> startScreenRecording() async => false;

  static Future<Uint8List?> stopScreenRecording() async => null;
}
