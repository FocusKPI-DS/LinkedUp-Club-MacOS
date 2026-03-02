import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized helper to find or create a 1:1 direct chat.
///
/// This prevents duplicate chats by using a single, consistent dedup
/// algorithm across all entry points (mobile, desktop, contacts, profile).
///
/// Dedup rules:
///   - Queries all non-group chats where the current user is a member
///   - Client-side filters for the target user with exactly 2 members
///   - Does NOT filter by workspace_ref (direct chats are unique per user pair)
///   - If multiple matches exist (legacy duplicates), returns the most recent one
///   - Includes a static in-progress set to prevent double-tap race conditions
class ChatHelpers {
  // Prevent concurrent creation for the same target user
  static final Set<String> _inProgress = <String>{};

  /// Returns an existing direct chat with [targetUserRef], or creates one.
  ///
  /// Throws if [currentUserReference] is null (user not logged in).
  static Future<ChatsRecord> findOrCreateDirectChat(
    DocumentReference targetUserRef,
  ) async {
    final currentRef = currentUserReference;
    if (currentRef == null) {
      throw Exception('Current user is not authenticated');
    }

    final targetId = targetUserRef.id;

    // Prevent double-tap: if already in progress for this user, wait and retry
    if (_inProgress.contains(targetId)) {
      // Wait briefly then try to find the chat that was just created
      await Future.delayed(const Duration(milliseconds: 500));
      final chat = await _findExistingChat(currentRef, targetUserRef);
      if (chat != null) return chat;
      // If still not found, fall through to normal flow
    }

    _inProgress.add(targetId);
    try {
      // 1. Try to find an existing chat
      final existing = await _findExistingChat(currentRef, targetUserRef);
      if (existing != null) {
        return existing;
      }

      // 2. No existing chat found — create one
      final newChatRef = await ChatsRecord.collection.add({
        ...createChatsRecordData(
          isGroup: false,
          title: '',
          createdAt: getCurrentTimestamp,
          lastMessageAt: getCurrentTimestamp,
          lastMessage: '',
          lastMessageSent: currentRef,
        ),
        'members': [currentRef, targetUserRef],
        'last_message_seen': [currentRef],
      });

      return await ChatsRecord.getDocumentOnce(newChatRef);
    } finally {
      _inProgress.remove(targetId);
    }
  }

  /// Queries Firestore for an existing 1:1 chat between [currentRef] and [targetRef].
  ///
  /// If multiple duplicates exist (from legacy code), returns the one with
  /// the most recent lastMessageAt, preferring chats that have actual messages.
  static Future<ChatsRecord?> _findExistingChat(
    DocumentReference currentRef,
    DocumentReference targetRef,
  ) async {
    final allDirectChats = await queryChatsRecordOnce(
      queryBuilder: (chatsRecord) => chatsRecord
          .where('members', arrayContains: currentRef)
          .where('is_group', isEqualTo: false),
    );

    // Client-side filter: target user must be a member, exactly 2 members
    final matches = allDirectChats.where((chat) {
      return chat.members.contains(targetRef) &&
          chat.members.length == 2 &&
          !chat.isGroup;
    }).toList();

    if (matches.isEmpty) return null;
    if (matches.length == 1) return matches.first;

    // Multiple duplicates exist — pick the best one:
    // Prefer the one with actual messages (non-empty lastMessage),
    // then the most recent lastMessageAt.
    matches.sort((a, b) {
      final aHasMessages = a.lastMessage.isNotEmpty ? 1 : 0;
      final bHasMessages = b.lastMessage.isNotEmpty ? 1 : 0;
      if (aHasMessages != bHasMessages) return bHasMessages - aHasMessages;
      final aTime = a.lastMessageAt ?? a.createdAt ?? DateTime(2000);
      final bTime = b.lastMessageAt ?? b.createdAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

    return matches.first;
  }
}
