/// Web-specific paste handler using dart:html.
/// This file is only imported on web via conditional import.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

typedef WebPasteCallback = void Function(List<WebPastedFile> files);

class WebPastedFile {
  final String fileName;
  final Uint8List bytes;
  final String mimeType;
  WebPastedFile({required this.fileName, required this.bytes, required this.mimeType});
}

/// Registers a global paste event listener on the document.
/// Returns a function to unregister the listener.
Function registerWebPasteHandler(WebPasteCallback onPaste) {
  void handler(html.Event event) {
    final clipboardEvent = event as html.ClipboardEvent;
    final items = clipboardEvent.clipboardData?.items;
    if (items == null || items.length == 0) return;

    final files = <WebPastedFile>[];
    for (int i = 0; i < items.length!; i++) {
      final item = items[i];
      if (item.kind == 'file') {
        final file = item.getAsFile();
        if (file != null) {
          // Prevent default so the filename doesn't get pasted as text
          event.preventDefault();
          
          final reader = html.FileReader();
          reader.onLoadEnd.listen((_) {
            final result = reader.result;
            if (result is Uint8List) {
              files.add(WebPastedFile(
                fileName: file.name,
                bytes: result,
                mimeType: item.type ?? '',
              ));
              // Call callback after reading all files
              if (files.length == _countFileItems(items)) {
                onPaste(files);
              }
            }
          });
          reader.readAsArrayBuffer(file);
        }
      }
    }
  }

  html.document.addEventListener('paste', handler);
  return () => html.document.removeEventListener('paste', handler);
}

int _countFileItems(html.DataTransferItemList items) {
  int count = 0;
  for (int i = 0; i < items.length!; i++) {
    if (items[i].kind == 'file') count++;
  }
  return count;
}
