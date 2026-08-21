import 'dart:typed_data';

/// Stub implementation for non-web platforms
Future<void> downloadFileOnWeb(String url, String fileName, Uint8List bytes) async {
  // This is a stub - should never be called on non-web platforms
  throw UnsupportedError('downloadFileOnWeb is only supported on web');
}

