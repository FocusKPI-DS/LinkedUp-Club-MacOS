import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Marks a Gmail email as read by removing the UNREAD label
///
/// [messageId] - The Gmail message ID to mark as read
///
/// Returns a Map with 'success' boolean and 'message' string
Future<Map<String, dynamic>?> gmailMarkAsRead(String messageId) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ User not authenticated');
      return {'success': false, 'error': 'User not authenticated'};
    }

    final functions = FirebaseFunctions.instance;
    final callable = functions.httpsCallable('gmailMarkAsRead');

    final result = await callable.call({
      'messageId': messageId,
    });

    final data = result.data as Map<String, dynamic>?;
    return data;
  } catch (e) {
    print('❌ Error marking email as read: $e');
    return {'success': false, 'error': e.toString()};
  }
}
