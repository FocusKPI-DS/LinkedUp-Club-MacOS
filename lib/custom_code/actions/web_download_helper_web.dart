import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:js' as js;
import 'package:flutter/foundation.dart' show debugPrint;

/// Web implementation for downloading files
Future<void> downloadFileOnWeb(String url, String fileName, Uint8List bytes) async {
  try {
    // Try using the JavaScript function we added to index.html first
    final downloadFunc = js.context['downloadFileFromBytes'];
    if (downloadFunc != null) {
      // Convert bytes to JavaScript array
      final jsBytes = js.JsArray.from(bytes);
      final result = downloadFunc.apply([jsBytes, fileName]);
      if (result == true) {
        return; // Success
      }
    }
  } catch (e) {
    debugPrint('JavaScript download function failed: $e, trying dart:html...');
  }
  
  // Fallback to dart:html implementation
  try {
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
          // Ignore cleanup errors
        }
      });
    } else {
      // Fallback if body is not available
      html.window.open(blobUrl, '_blank');
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          html.Url.revokeObjectUrl(blobUrl);
        } catch (e) {
          // Ignore cleanup errors
        }
      });
    }
  } catch (e) {
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
          anchor.remove();
        });
      } else {
        html.window.open(url, '_blank');
      }
    } catch (_) {
      // Last resort: just open URL
      html.window.open(url, '_blank');
    }
  }
}

