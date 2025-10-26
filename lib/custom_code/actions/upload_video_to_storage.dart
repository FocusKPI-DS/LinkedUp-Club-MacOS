// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

Future<String> uploadVideoToStorage(String? localVideoPath) async {
  print("📥 [uploadVideoToStorage] Called with path: $localVideoPath");

  if (localVideoPath == null || localVideoPath.isEmpty) {
    print("❌ Error: No video path provided.");
    throw Exception("No video path provided.");
  }

  final cleanedPath = localVideoPath.replaceFirst("file://", "");
  final file = File(cleanedPath);
  print("🧼 Cleaned path: $cleanedPath");

  if (!await file.exists()) {
    print("❌ Error: File does not exist at path: $cleanedPath");
    throw Exception("Video file does not exist at: $localVideoPath");
  }

  // Check file size (limit to 50MB)
  final fileSize = await file.length();
  const maxSize = 50 * 1024 * 1024; // 50MB
  if (fileSize > maxSize) {
    print("❌ Error: Video file too large: ${fileSize / (1024 * 1024)}MB");
    throw Exception("Video file too large. Maximum size is 50MB.");
  }

  try {
    final fileName = path.basename(cleanedPath);
    final storageRef =
        FirebaseStorage.instance.ref().child('video_uploads/$fileName');

    print("🚀 Uploading $fileName to Firebase Storage...");
    final uploadTask = storageRef.putFile(file);

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    print("✅ Upload successful! Download URL: $downloadUrl");
    return downloadUrl;
  } catch (e) {
    print("❌ Firebase upload failed: $e");
    throw Exception("Firebase upload failed: $e");
  }
}
