// Automatic FlutterFlow imports
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

Future<bool> gmailSendEmail({
  required String to,
  String? cc,
  required String subject,
  required String body,
  bool isHtml = false,
  List<PlatformFile>? attachments,
  Function(int current, int total)? onUploadProgress,
}) async {
  try {
    print('🔵 Sending Gmail email...');

    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'gmailSendEmail',
      options: HttpsCallableOptions(
        timeout: const Duration(
            seconds: 30), // Reduced timeout since we upload to Storage first
      ),
    );

    // Upload attachments to Firebase Storage first
    List<Map<String, dynamic>> attachmentData = [];
    if (attachments != null && attachments.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ User not authenticated');
        return false;
      }

      int currentFile = 0;
      for (final file in attachments) {
        currentFile++;
        try {
          // Update progress
          if (onUploadProgress != null) {
            onUploadProgress(currentFile, attachments.length);
          }

          // Sanitize filename - remove special characters that might cause issues
          final sanitizedFileName = file.name
              .replaceAll(RegExp(r'[^\w\s\-\.]'),
                  '_') // Replace special chars with underscore
              .replaceAll(RegExp(r'\s+'), '_') // Replace spaces with underscore
              .replaceAll(RegExp(r'_+'),
                  '_'); // Replace multiple underscores with single

          // Upload to Firebase Storage
          final fileName =
              'gmail_attachments/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_$sanitizedFileName';
          final storageRef = FirebaseStorage.instance.ref().child(fileName);

          UploadTask uploadTask;
          if (file.bytes != null) {
            // File was picked from memory
            uploadTask = storageRef.putData(
              file.bytes!,
              SettableMetadata(
                contentType: _getMimeType(file.name),
              ),
            );
          } else if (file.path != null) {
            // File was picked from file system
            // Clean the path (remove file:// prefix if present)
            String cleanedPath = file.path!.replaceFirst('file://', '');
            final fileObj = File(cleanedPath);

            if (!await fileObj.exists()) {
              throw Exception('File does not exist: $cleanedPath');
            }

            // Check file size
            final fileSize = await fileObj.length();
            if (fileSize == 0) {
              throw Exception('File is empty: ${file.name}');
            }

            print(
                '📤 Uploading ${file.name} ($fileSize bytes) from file system...');
            print('📁 File path: $cleanedPath');

            try {
              // Try to upload using file path first
              uploadTask = storageRef.putFile(
                fileObj,
                SettableMetadata(
                  contentType: _getMimeType(file.name),
                  customMetadata: {
                    'originalName': file.name,
                  },
                ),
              );
            } catch (e) {
              print('⚠️ File path upload failed, trying bytes instead: $e');
              // Fallback: read file as bytes and upload
              try {
                final fileBytes = await fileObj.readAsBytes();
                print(
                    '📤 Uploading ${file.name} (${fileBytes.length} bytes) from memory (fallback)...');
                uploadTask = storageRef.putData(
                  fileBytes,
                  SettableMetadata(
                    contentType: _getMimeType(file.name),
                    customMetadata: {
                      'originalName': file.name,
                    },
                  ),
                );
              } catch (e2) {
                print(
                    '❌ Error creating upload task (both methods failed): $e2');
                throw Exception(
                    'Failed to create upload task for ${file.name}: $e2');
              }
            }
          } else {
            throw Exception('File has neither bytes nor path');
          }

          // Wait for upload to complete with timeout
          print('⏳ Waiting for upload to complete...');

          // Listen for errors during upload
          uploadTask.snapshotEvents.listen(
            (snapshot) {
              if (snapshot.state == TaskState.error) {
                print('❌ Upload error detected: ${snapshot.state}');
              } else if (snapshot.state == TaskState.running) {
                final progress =
                    (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
                print('📊 Upload progress: ${progress.toStringAsFixed(1)}%');
              }
            },
            onError: (error) {
              print('❌ Upload stream error: $error');
            },
          );

          TaskSnapshot snapshot;
          try {
            snapshot = await uploadTask.timeout(
              Duration(minutes: 5), // 5 minute timeout per file
              onTimeout: () {
                uploadTask.cancel();
                throw Exception('Upload timeout for ${file.name}');
              },
            );
          } catch (e) {
            print('❌ Upload task error: $e');
            print('❌ Error type: ${e.runtimeType}');
            if (e.toString().contains('timeout')) {
              throw Exception('Upload timeout for ${file.name}');
            }
            // Check if it's a Firebase Storage error
            if (e.toString().contains('firebase_storage')) {
              throw Exception('Firebase Storage error for ${file.name}: $e');
            }
            rethrow;
          }

          // Check upload state
          if (snapshot.state != TaskState.success) {
            print('❌ Upload failed. State: ${snapshot.state}');
            throw Exception(
                'Upload failed for ${file.name}. State: ${snapshot.state}');
          }

          print('✅ Upload completed successfully');
          final downloadUrl = await snapshot.ref.getDownloadURL();

          // Store Storage URL instead of base64 data
          attachmentData.add({
            'filename': file.name, // Keep original filename for email
            'mimeType': _getMimeType(file.name),
            'storageUrl': downloadUrl,
            'size': file.size,
          });

          print('✅ Uploaded ${file.name} to Storage: $downloadUrl');
        } catch (e) {
          print('⚠️ Error uploading attachment ${file.name}: $e');
          print('⚠️ Error details: ${e.toString()}');
          // Re-throw to stop the process if upload fails
          throw Exception('Failed to upload attachment ${file.name}: $e');
        }
      }
    }

    // Ensure all required fields are present
    final Map<String, dynamic> callData = {
      'to': to.trim(),
      'subject': subject.trim(),
      'body': body.trim(),
      'isHtml': isHtml,
    };

    if (cc != null && cc.trim().isNotEmpty) {
      callData['cc'] = cc.trim();
    }

    if (attachmentData.isNotEmpty) {
      callData['attachments'] = attachmentData;
    }

    final result = await callable.call(callData);

    if (result.data != null && result.data['success'] == true) {
      print('✅ Gmail email sent successfully');
      return true;
    } else {
      print('❌ Failed to send Gmail email');
      return false;
    }
  } catch (e) {
    print('❌ Error sending Gmail email: $e');
    return false;
  }
}

String _getMimeType(String filename) {
  final extension = filename.split('.').last.toLowerCase();
  final mimeTypes = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'zip': 'application/zip',
    'rar': 'application/x-rar-compressed',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'bmp': 'image/bmp',
    'webp': 'image/webp',
    'txt': 'text/plain',
    'html': 'text/html',
    'css': 'text/css',
    'js': 'text/javascript',
    'json': 'application/json',
    'xml': 'application/xml',
    'mp3': 'audio/mpeg',
    'mp4': 'video/mp4',
    'avi': 'video/x-msvideo',
    'mov': 'video/quicktime',
  };

  return mimeTypes[extension] ?? 'application/octet-stream';
}
