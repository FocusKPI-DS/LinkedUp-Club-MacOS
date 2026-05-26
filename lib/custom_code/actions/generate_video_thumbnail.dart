// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

Future<String> generateVideoThumbnail(String? videoPath) async {
  print("📥 [generateVideoThumbnail] Called with path: $videoPath");

  if (videoPath == null || videoPath.isEmpty) {
    print("❌ Error: No video path provided.");
    throw Exception("No video path provided.");
  }

  final cleanedPath = videoPath.replaceFirst("file://", "");
  final file = File(cleanedPath);
  print("🧼 Cleaned path: $cleanedPath");

  if (!await file.exists()) {
    print("❌ Error: Video file does not exist at path: $cleanedPath");
    throw Exception("Video file does not exist at: $videoPath");
  }

  try {
    // For now, return a placeholder thumbnail URL
    // TODO: Implement actual thumbnail generation when video_thumbnail package is available
    final fileName = path.basenameWithoutExtension(cleanedPath);
    final thumbnailRef = FirebaseStorage.instance
        .ref()
        .child('video_thumbnails/${fileName}_thumb.jpg');

    // Create a simple placeholder thumbnail (1x1 pixel)
    final placeholderBytes = Uint8List.fromList([
      0xFF,
      0xD8,
      0xFF,
      0xE0,
      0x00,
      0x10,
      0x4A,
      0x46,
      0x49,
      0x46,
      0x00,
      0x01,
      0x01,
      0x01,
      0x00,
      0x48,
      0x00,
      0x48,
      0x00,
      0x00,
      0xFF,
      0xDB,
      0x00,
      0x43,
      0x00,
      0x08,
      0x06,
      0x06,
      0x07,
      0x06,
      0x05,
      0x08,
      0x07,
      0x07,
      0x07,
      0x09,
      0x09,
      0x08,
      0x0A,
      0x0C,
      0x14,
      0x0D,
      0x0C,
      0x0B,
      0x0B,
      0x0C,
      0x19,
      0x12,
      0x13,
      0x0F,
      0x14,
      0x1D,
      0x1A,
      0x1F,
      0x1E,
      0x1D,
      0x1A,
      0x1C,
      0x1C,
      0x20,
      0x24,
      0x2E,
      0x27,
      0x20,
      0x22,
      0x2C,
      0x23,
      0x1C,
      0x1C,
      0x28,
      0x37,
      0x29,
      0x2C,
      0x30,
      0x31,
      0x34,
      0x34,
      0x34,
      0x1F,
      0x27,
      0x39,
      0x3D,
      0x38,
      0x32,
      0x3C,
      0x2E,
      0x33,
      0x34,
      0x32,
      0xFF,
      0xC0,
      0x00,
      0x11,
      0x08,
      0x00,
      0x01,
      0x00,
      0x01,
      0x01,
      0x01,
      0x11,
      0x00,
      0x02,
      0x11,
      0x01,
      0x03,
      0x11,
      0x01,
      0xFF,
      0xC4,
      0x00,
      0x14,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x08,
      0xFF,
      0xC4,
      0x00,
      0x14,
      0x10,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0xFF,
      0xDA,
      0x00,
      0x0C,
      0x03,
      0x01,
      0x00,
      0x02,
      0x11,
      0x03,
      0x11,
      0x00,
      0x3F,
      0x00,
      0x2A,
      0xFF,
      0xD9
    ]);

    print("🚀 Uploading placeholder thumbnail to Firebase Storage...");
    final uploadTask = thumbnailRef.putData(placeholderBytes);
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    print(
        "✅ Placeholder thumbnail upload successful! Download URL: $downloadUrl");
    return downloadUrl;
  } catch (e) {
    print("❌ Thumbnail generation/upload failed: $e");
    throw Exception("Thumbnail generation failed: $e");
  }
}
