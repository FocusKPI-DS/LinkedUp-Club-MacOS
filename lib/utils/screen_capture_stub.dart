import 'dart:io';
import 'dart:typed_data';

/// Native implementation of screen capture for non-web platforms.
/// On macOS, uses the built-in `screencapture` CLI tool for interactive selection.
/// On other platforms (iOS, Android), these are no-ops.
class ScreenCaptureWeb {
  static bool _isRecording = false;
  static bool get isRecording => _isRecording;

  /// Capture a screenshot using macOS native `screencapture` tool.
  /// Opens the interactive selection UI (crosshair cursor).
  /// Returns the captured image bytes, or null if cancelled/unsupported.
  static Future<Uint8List?> captureScreenshot() async {
    if (!Platform.isMacOS) return null;

    try {
      // Create a temporary file path for the screenshot
      final tempDir = await Directory.systemTemp.createTemp('screenshot_');
      final tempFile = File('${tempDir.path}/screenshot.png');

      // Run macOS screencapture with interactive selection mode (-i)
      // -i = interactive (user selects area)
      // -x = no sound
      final result = await Process.run(
        'screencapture',
        ['-i', '-x', tempFile.path],
      );

      if (result.exitCode != 0) {
        // User cancelled or error
        print('Screenshot cancelled or failed: ${result.stderr}');
        // Clean up temp directory
        await tempDir.delete(recursive: true);
        return null;
      }

      // Check if file was created (user might cancel with Escape)
      if (!await tempFile.exists()) {
        print('Screenshot file not created (user cancelled)');
        await tempDir.delete(recursive: true);
        return null;
      }

      // Read the screenshot bytes
      final bytes = await tempFile.readAsBytes();

      // Clean up temp file
      await tempDir.delete(recursive: true);

      if (bytes.isEmpty) {
        print('Screenshot file is empty');
        return null;
      }

      print('✅ Screenshot captured: ${bytes.length} bytes');
      return Uint8List.fromList(bytes);
    } catch (e) {
      print('Screenshot capture error: $e');
      return null;
    }
  }

  static Future<bool> startScreenRecording() async => false;

  static Future<Uint8List?> stopScreenRecording() async => null;
}
