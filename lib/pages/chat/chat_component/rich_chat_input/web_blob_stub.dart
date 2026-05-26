import 'dart:typed_data';

/// Stub implementation for non-web platforms.
/// This file is used when dart:html is not available.
Future<Uint8List> fetchBlobUrlBytes(String blobUrl) async {
  throw UnsupportedError('fetchBlobUrlBytes is only supported on web');
}
