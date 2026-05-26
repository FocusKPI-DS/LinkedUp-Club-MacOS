import 'package:cloud_firestore/cloud_firestore.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';

/// Service for managing active meetings in group chats.
///
/// Writes to `chats/{chatId}.active_meeting` and sends system messages
/// when meetings are started or ended.
class MeetingService {
  MeetingService._();

  /// Start a new meeting in [chatRef] with the given [meetUrl].
  ///
  /// - Writes `active_meeting` map to the chat document.
  /// - Sends a system message announcing the meeting.
  static Future<void> startMeeting({
    required DocumentReference chatRef,
    required String meetUrl,
    String? starterName,
  }) async {
    final userRef = currentUserReference;
    if (userRef == null) {
      print('📹 [MeetingService] ❌ Cannot start meeting: user not logged in');
      return;
    }

    final name = starterName ??
        currentUserDocument?.displayName ??
        'Someone';

    print('📹 [MeetingService] Starting meeting in ${chatRef.id}');
    print('📹 [MeetingService] URL: $meetUrl');
    print('📹 [MeetingService] Starter: $name');

    try {
      // Write active_meeting to chat doc
      await chatRef.update({
        'active_meeting': {
          'url': meetUrl,
          'started_by': userRef,
          'started_at': FieldValue.serverTimestamp(),
          'participants': [userRef],
        },
      });
      print('📹 [MeetingService] ✅ active_meeting written to Firestore');
    } catch (e) {
      print('📹 [MeetingService] ❌ Failed to write active_meeting: $e');
      // Don't return — try sending the message even if the meeting field failed
    }

    try {
      // Send system message
      final messagesRef = chatRef.collection('messages');
      await messagesRef.add({
        'content': '📹 $name started a Google Meet\n$meetUrl',
        'sender': userRef,
        'sender_name': name,
        'created_at': FieldValue.serverTimestamp(),
        'message_type': 'system',
        'meeting_url': meetUrl,
      });
      print('📹 [MeetingService] ✅ System message sent');

      // Update chat's last message
      await chatRef.update({
        'last_message': '📹 $name started a Google Meet',
        'last_message_at': FieldValue.serverTimestamp(),
        'last_message_sent': userRef,
      });
      print('📹 [MeetingService] ✅ Last message updated');
    } catch (e) {
      print('📹 [MeetingService] ❌ Failed to send system message: $e');
    }
  }

  /// End the active meeting in [chatRef].
  static Future<void> endMeeting({
    required DocumentReference chatRef,
    String? enderName,
  }) async {
    final name = enderName ??
        currentUserDocument?.displayName ??
        'Someone';

    print('📹 [MeetingService] Ending meeting in ${chatRef.id}');

    try {
      // Clear active_meeting
      await chatRef.update({
        'active_meeting': FieldValue.delete(),
      });
      print('📹 [MeetingService] ✅ active_meeting cleared');
    } catch (e) {
      print('📹 [MeetingService] ❌ Failed to clear active_meeting: $e');
    }

    try {
      // Send system message
      final messagesRef = chatRef.collection('messages');
      await messagesRef.add({
        'content': '📹 $name ended the meeting',
        'sender': currentUserReference,
        'sender_name': name,
        'created_at': FieldValue.serverTimestamp(),
        'message_type': 'system',
      });

      // Update chat's last message
      await chatRef.update({
        'last_message': '📹 $name ended the meeting',
        'last_message_at': FieldValue.serverTimestamp(),
        'last_message_sent': currentUserReference,
      });
      print('📹 [MeetingService] ✅ End message sent');
    } catch (e) {
      print('📹 [MeetingService] ❌ Failed to send end message: $e');
    }
  }

  /// Add the current user to the meeting's participant list.
  static Future<void> joinMeeting({
    required DocumentReference chatRef,
  }) async {
    final userRef = currentUserReference;
    if (userRef == null) return;

    try {
      await chatRef.update({
        'active_meeting.participants': FieldValue.arrayUnion([userRef]),
      });
      print('📹 [MeetingService] ✅ Joined meeting');
    } catch (e) {
      print('📹 [MeetingService] ❌ Failed to join meeting: $e');
    }
  }

  /// Remove the current user from the meeting's participant list.
  static Future<void> leaveMeeting({
    required DocumentReference chatRef,
  }) async {
    final userRef = currentUserReference;
    if (userRef == null) return;

    try {
      await chatRef.update({
        'active_meeting.participants': FieldValue.arrayRemove([userRef]),
      });
      print('📹 [MeetingService] ✅ Left meeting');
    } catch (e) {
      print('📹 [MeetingService] ❌ Failed to leave meeting: $e');
    }
  }
}
