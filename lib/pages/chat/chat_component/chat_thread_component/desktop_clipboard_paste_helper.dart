import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:super_clipboard/super_clipboard.dart';

/// One image or file read from the system clipboard (Windows/Linux desktop).
class DesktopClipboardPasteItem {
  const DesktopClipboardPasteItem({
    required this.bytes,
    required this.fileName,
    this.filePath,
  });

  final Uint8List bytes;
  final String fileName;
  final String? filePath;
}

/// Reads images and files from the clipboard.
/// Windows prefers the native pasteboard channel (Alt+PrintScreen DIB, Snipping Tool PNG).
class DesktopClipboardPasteHelper {
  static const _pasteboardChannel =
      MethodChannel('com.focuskpi.linkedup/pasteboard');

  static const _imageFormats = <FileFormat>[
    Formats.png,
    Formats.jpeg,
    Formats.gif,
    Formats.webp,
    Formats.bmp,
    Formats.tiff,
  ];

  static Future<List<DesktopClipboardPasteItem>> readAll() async {
    final results = <DesktopClipboardPasteItem>[];

    if (Platform.isWindows || Platform.isMacOS) {
      results.addAll(await _readFromNativePasteboard());
    }

    if (results.isEmpty) {
      results.addAll(await _readFromSuperClipboard());
    }

    final normalized = <DesktopClipboardPasteItem>[];
    for (final item in results) {
      normalized.add(await _normalizeImageItem(item));
    }
    return normalized;
  }

  static Future<DesktopClipboardPasteItem> _normalizeImageItem(
    DesktopClipboardPasteItem item,
  ) async {
    final ext = item.fileName.split('.').last.toLowerCase();
    final isImage = ext == 'png' ||
        ext == 'jpg' ||
        ext == 'jpeg' ||
        ext == 'gif' ||
        ext == 'webp' ||
        ext == 'bmp' ||
        ext == 'tiff' ||
        ext == 'heic';

    if (!isImage) return item;

    // Already a web-friendly PNG/JPEG that decodes cleanly.
    if ((ext == 'png' || ext == 'jpg' || ext == 'jpeg') &&
        img.decodeImage(item.bytes) != null) {
      return item;
    }

    try {
      final decoded = img.decodeImage(item.bytes);
      if (decoded == null) return item;
      final png = Uint8List.fromList(img.encodePng(decoded));
      final ts = DateTime.now().millisecondsSinceEpoch;
      debugPrint('📋 [paste] normalized $ext → png (${png.length} bytes)');
      return DesktopClipboardPasteItem(
        bytes: png,
        fileName: 'paste_$ts.png',
        filePath: item.filePath,
      );
    } catch (e) {
      debugPrint('📋 [paste] image normalize failed: $e');
      return item;
    }
  }

  static Future<List<DesktopClipboardPasteItem>> _readFromNativePasteboard() async {
    final results = <DesktopClipboardPasteItem>[];

    try {
      final filePaths =
          await _pasteboardChannel.invokeMethod<List>('getFileURLs');
      if (filePaths != null && filePaths.isNotEmpty) {
        for (final pathObj in filePaths) {
          final path = pathObj as String;
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            results.add(DesktopClipboardPasteItem(
              bytes: bytes,
              fileName: _fileNameFromPath(file.path),
              filePath: file.path,
            ));
          }
        }
        if (results.isNotEmpty) return results;
      }

      final rawImage =
          await _pasteboardChannel.invokeMethod<dynamic>('getImageData');
      final imageData = _coerceBytes(rawImage);
      if (imageData != null && imageData.isNotEmpty) {
        results.add(DesktopClipboardPasteItem(
          bytes: imageData,
          fileName: _fileNameForImageBytes(imageData),
        ));
        debugPrint(
            '📋 [paste] native image: ${imageData.length} bytes (${results.last.fileName})');
      }
    } catch (e, st) {
      debugPrint('📋 [paste] native clipboard error: $e\n$st');
    }

    return results;
  }

  static Future<List<DesktopClipboardPasteItem>> _readFromSuperClipboard() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      debugPrint('📋 [paste] super_clipboard unavailable');
      return const [];
    }

    try {
      final reader = await clipboard.read();
      final results = <DesktopClipboardPasteItem>[];

      if (reader.canProvide(Formats.fileUri)) {
        final uri = await reader.readValue(Formats.fileUri);
        if (uri != null && uri.scheme == 'file') {
          final file = File.fromUri(uri);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final name = _fileNameFromPath(file.path);
            results.add(DesktopClipboardPasteItem(
              bytes: bytes,
              fileName: name,
              filePath: file.path,
            ));
          }
        }
      }

      if (results.isNotEmpty) return results;

      for (final format in _imageFormats) {
        if (!reader.canProvide(format)) continue;
        final bytes = await _readFileFormat(reader, format);
        if (bytes != null && bytes.isNotEmpty) {
          final ext = format == Formats.jpeg
              ? 'jpg'
              : format == Formats.tiff
                  ? 'tiff'
                  : format == Formats.bmp
                      ? 'bmp'
                      : format == Formats.gif
                          ? 'gif'
                          : format == Formats.webp
                              ? 'webp'
                              : 'png';
          final suggested = await reader.getSuggestedName();
          final fileName = (suggested != null && suggested.isNotEmpty)
              ? suggested
              : 'paste_${DateTime.now().millisecondsSinceEpoch}.$ext';
          results.add(DesktopClipboardPasteItem(
            bytes: bytes,
            fileName: fileName,
          ));
          debugPrint(
              '📋 [paste] super_clipboard image: ${bytes.length} bytes ($fileName)');
          break;
        }
      }

      return results;
    } catch (e, st) {
      debugPrint('📋 [paste] super_clipboard error: $e\n$st');
      return const [];
    }
  }

  static Uint8List? _coerceBytes(Object? value) {
    if (value == null) return null;
    if (value is Uint8List) return value;
    if (value is List) {
      return Uint8List.fromList(value.cast<int>());
    }
    return null;
  }

  static Future<Uint8List?> _readFileFormat(
    ClipboardReader reader,
    FileFormat format,
  ) async {
    final completer = Completer<Uint8List?>();
    final progress = reader.getFile(format, (file) async {
      try {
        completer.complete(await file.readAll());
      } catch (_) {
        if (!completer.isCompleted) completer.complete(null);
      } finally {
        file.close();
      }
    });
    if (progress == null) return null;
    return completer.future;
  }

  static String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.split('/').last;
  }

  static String _fileNameForImageBytes(Uint8List bytes) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'paste_$ts.png';
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'paste_$ts.jpg';
    }
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return 'paste_$ts.bmp';
    }
    return 'paste_$ts.png';
  }
}
