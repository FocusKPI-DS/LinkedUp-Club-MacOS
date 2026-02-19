import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

// Conditional import for web
import 'web_download_helper_stub.dart'
    if (dart.library.html) 'web_download_helper_web.dart' as web_download;

/// Downloads a file on web platform using blob URL
Future<void> downloadFileOnWeb(String url, String fileName, List<int> bytes) async {
  if (!kIsWeb) {
    throw UnsupportedError('downloadFileOnWeb is only supported on web');
  }
  
  try {
    // Convert to Uint8List for web
    final uint8List = Uint8List.fromList(bytes);
    await web_download.downloadFileOnWeb(url, fileName, uint8List);
  } catch (e) {
    // If conditional import fails, throw a more descriptive error
    throw Exception('Failed to download file on web: $e');
  }
}

