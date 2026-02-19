// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

Future<String> uploadAudioToStorage(String? localAudioPath) async {
  print("📥 [uploadAudioToStorage] Called with path: $localAudioPath");

  if (localAudioPath == null || localAudioPath.isEmpty) {
    print("❌ Error: No audio path provided.");
    throw Exception("No audio path provided.");
  }

  final cleanedPath = localAudioPath.replaceFirst("file://", "");
  final file = File(cleanedPath);
  print("🧼 Cleaned path: $cleanedPath");

  if (!await file.exists()) {
    print("❌ Error: File does not exist at path: $cleanedPath");
    throw Exception("Audio file does not exist at: $localAudioPath");
  }

  try {
    final fileName = path.basename(cleanedPath);
    final storageRef =
        FirebaseStorage.instance.ref().child('audio_uploads/$fileName');

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
