/// Stub for non-web platforms. The real implementation is in web_paste_handler.dart.
import 'dart:typed_data';

typedef WebPasteCallback = void Function(List<WebPastedFile> files);

class WebPastedFile {
  final String fileName;
  final Uint8List bytes;
  final String mimeType;
  WebPastedFile({required this.fileName, required this.bytes, required this.mimeType});
}

/// No-op on non-web platforms.
Function registerWebPasteHandler(WebPasteCallback onPaste) {
  return () {};
}
