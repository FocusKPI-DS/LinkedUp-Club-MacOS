import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Web implementation: fetches bytes from a blob: URL using XMLHttpRequest.
Future<Uint8List> fetchBlobUrlBytes(String blobUrl) async {
  final xhr = web.XMLHttpRequest();
  xhr.open('GET', blobUrl);
  xhr.responseType = 'arraybuffer';
  
  final completer = Completer<Uint8List>();
  
  xhr.onload = ((web.Event event) {
    final buffer = (xhr.response as JSArrayBuffer).toDart;
    completer.complete(buffer.asUint8List());
  }).toJS;
  
  xhr.onerror = ((web.Event event) {
    completer.completeError('Failed to fetch blob URL: $blobUrl');
  }).toJS;
  
  xhr.send();
  
  return completer.future;
}
