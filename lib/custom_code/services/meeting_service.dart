import 'package:cloud_firestore/cloud_firestore.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';
import '/flutter_flow/flutter_flow_util.dart';

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
      await fsPatchDocument(chatRef, {
        'active_meeting': {
          'url': meetUrl,
          'started_by': userRef,
          'started_at': getCurrentTimestamp,
          'participants': [userRef],
        },
      });
      print('📹 [MeetingService] ✅ active_meeting written to Firestore');
    } catch (e) {
      print('📹 [MeetingService] ❌ Failed to write active_meeting: $e');
    }

    try {
      await fsCreateMessage(chatRef, {
        'content': '📹 $name started a Google Meet\n$meetUrl',
        'sender': userRef,
        'sender_name': name,
        'created_at': getCurrentTimestamp,
        'message_type': 'system',
        'meeting_url': meetUrl,
      });
      print('📹 [MeetingService] ✅ System message sent');

      await fsPatchDocument(chatRef, {
        'last_message': '📹 $name started a Google Meet',
        'last_message_at': getCurrentTimestamp,
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
      await fsDeleteDocumentField(chatRef, 'active_meeting');
      print('📹 [MeetingService] ✅ active_meeting cleared');
    } catch (e) {
      print('📹 [MeetingService] ❌ Failed to clear active_meeting: $e');
    }

    try {
      await fsCreateMessage(chatRef, {
        'content': '📹 $name ended the meeting',
        'sender': currentUserReference,
        'sender_name': name,
        'created_at': getCurrentTimestamp,
        'message_type': 'system',
      });

      await fsPatchDocument(chatRef, {
        'last_message': '📹 $name ended the meeting',
        'last_message_at': getCurrentTimestamp,
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
      await fsArrayUnion(
        chatRef,
        'active_meeting.participants',
        [userRef],
      );
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
      await fsArrayRemove(
        chatRef,
        'active_meeting.participants',
        [userRef],
      );
      print('📹 [MeetingService] ✅ Left meeting');
    } catch (e) {
      print('📹 [MeetingService] ❌ Failed to leave meeting: $e');
    }
  }
}
