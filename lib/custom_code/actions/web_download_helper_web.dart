import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;

/// Web implementation for downloading files
Future<void> downloadFileOnWeb(String url, String fileName, Uint8List bytes) async {
  try {
    // Use dart:html implementation (more reliable than dart:js)
    // Create blob from bytes
    final blob = html.Blob([bytes]);
    final blobUrl = html.Url.createObjectUrlFromBlob(blob);
    
    // Create anchor element
    final anchor = html.AnchorElement()
      ..href = blobUrl
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    
    // Add to DOM
    final body = html.document.body;
    if (body != null) {
      body.append(anchor);
      
      // Trigger download
      anchor.click();
      
      // Clean up after download starts
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          anchor.remove();
          html.Url.revokeObjectUrl(blobUrl);
        } catch (e) {
          debugPrint('Error cleaning up blob URL: $e');
        }
      });
    } else {
      // Fallback if body is not available
      html.window.open(blobUrl, '_blank');
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          html.Url.revokeObjectUrl(blobUrl);
        } catch (e) {
          debugPrint('Error revoking blob URL: $e');
        }
      });
    }
  } catch (e) {
    debugPrint('Blob download failed: $e, trying direct URL download...');
    // If blob download fails, try direct URL download
    try {
      final anchor = html.AnchorElement()
        ..href = url
        ..setAttribute('download', fileName)
        ..setAttribute('target', '_blank')
        ..style.display = 'none';
      
      final body = html.document.body;
      if (body != null) {
        body.append(anchor);
        anchor.click();
        Future.delayed(const Duration(milliseconds: 100), () {
          try {
            anchor.remove();
          } catch (e) {
            debugPrint('Error removing anchor: $e');
          }
        });
      } else {
        html.window.open(url, '_blank');
      }
    } catch (e2) {
      debugPrint('Direct URL download failed: $e2, opening in new tab...');
      // Last resort: just open URL
      html.window.open(url, '_blank');
    }
  }
}

