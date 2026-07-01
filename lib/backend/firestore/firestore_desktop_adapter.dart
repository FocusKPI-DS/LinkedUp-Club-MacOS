import 'package:cloud_firestore/cloud_firestore.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'windows_firestore_rest.dart';
import 'fs_doc_snapshot.dart';

export 'windows_firestore_rest.dart' show useWindowsFirestoreRest;
export 'fs_doc_snapshot.dart' show FsDocSnapshot;

const _summerAiPhotoUrl =
    'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120';

/// AI/service refs under `users/` that are not real Firestore user profiles.
bool fsIsRealUserRef(DocumentReference ref) {
  final id = ref.id.toLowerCase();
  return !id.contains('ai_agent');
}

UsersRecord fsSyntheticAgentUser(DocumentReference ref) {
  final isSummer = ref.path.contains('ai_agent_summerai');
  return UsersRecord.getDocumentFromData(
    {
      'display_name': isSummer ? 'Summer' : 'Assistant',
      'photo_url': isSummer ? _summerAiPhotoUrl : '',
      'uid': ref.id,
    },
    ref,
  );
}

/// Routes chat Firestore reads/writes through REST on Windows/Linux desktop.
Future<List<MessagesRecord>> fsQueryChatMessages(
  DocumentReference chatRef, {
  int limit = 40,
  MessagesRecord? startAfter,
  Map<String, dynamic>? equalFilter,
}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryMessages(
      chatRef: chatRef,
      limit: limit,
      startAfter: startAfter,
      equalFilter: equalFilter,
    );
  }
  return queryMessagesRecordOnce(
    parent: chatRef,
    queryBuilder: (q) {
      var query = q.orderBy('created_at', descending: true);
      if (equalFilter != null) {
        equalFilter.forEach((field, value) {
          query = query.where(field, isEqualTo: value);
        });
      }
      if (startAfter?.createdAt != null) {
        query = query.startAfter([startAfter!.createdAt]);
      }
      return query.limit(limit);
    },
  );
}

Future<UsersRecord> fsGetUserOnce(DocumentReference ref) async {
  if (!fsIsRealUserRef(ref)) {
    return fsSyntheticAgentUser(ref);
  }
  if (useWindowsFirestoreRest) {
    final user = await WindowsFirestoreRest.getUsersRecord(ref);
    if (user == null) {
      throw StateError('User not found: ${ref.path}');
    }
    return user;
  }
  return UsersRecord.getDocumentOnce(ref);
}

Future<ChatsRecord> fsGetChatOnce(DocumentReference ref) async {
  if (useWindowsFirestoreRest) {
    final chat = await WindowsFirestoreRest.getChatsRecord(ref);
    if (chat == null) {
      throw StateError('Chat not found: ${ref.path}');
    }
    return chat;
  }
  return ChatsRecord.getDocumentOnce(ref);
}

Future<bool> fsDocumentExists(DocumentReference ref) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.documentExists(ref);
  }
  final snap = await ref.get();
  return snap.exists;
}

Future<void> fsCreateMessage(
  DocumentReference chatRef,
  Map<String, dynamic> messageData,
) async {
  if (useWindowsFirestoreRest) {
    await WindowsFirestoreRest.createMessage(
      chatRef: chatRef,
      data: messageData,
    );
    return;
  }
  await MessagesRecord.createDoc(chatRef).set(messageData);
}

Future<void> fsPatchDocument(
  DocumentReference ref,
  Map<String, dynamic> data,
) async {
  if (useWindowsFirestoreRest) {
    await WindowsFirestoreRest.patchDocument(ref: ref, data: data);
    return;
  }
  await ref.update(data);
}

Future<void> fsDeleteDocumentField(
  DocumentReference ref,
  String fieldPath,
) async {
  if (useWindowsFirestoreRest) {
    await WindowsFirestoreRest.deleteDocumentField(ref, fieldPath);
    return;
  }
  await ref.update({fieldPath: FieldValue.delete()});
}

Future<void> fsDeleteDocument(DocumentReference ref) async {
  if (useWindowsFirestoreRest) {
    await WindowsFirestoreRest.deleteDocument(ref);
    return;
  }
  await ref.delete();
}

Future<void> fsPatchMessageReactions(
  DocumentReference messageRef,
  Map<String, List<String>> reactionsByUser,
) async {
  await fsPatchDocument(messageRef, {'reactions_by_user': reactionsByUser});
}

Future<List<BlockedUsersRecord>> fsQueryBlockedUsers(
  DocumentReference blockerRef,
) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryBlockedUsers(blockerRef);
  }
  final snapshot = await BlockedUsersRecord.collection
      .where('blocker_user', isEqualTo: blockerRef)
      .get();
  return snapshot.docs
      .map((doc) => BlockedUsersRecord.fromSnapshot(doc))
      .toList();
}

Future<List<ActionItemsRecord>> fsQueryRecentActionItems({
  int limit = 200,
}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryRecentActionItems(limit: limit);
  }
  return queryActionItemsRecordOnce(
    queryBuilder: (q) => q.orderBy('created_time', descending: true).limit(limit),
  );
}

Future<List<PostsRecord>> fsQueryLatestNewsPosts({int limit = 1}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryPosts(
      equalFilter: {'post_type': 'News'},
      limit: limit,
    );
  }
  return queryPostsRecordOnce(
    queryBuilder: (posts) => posts
        .where('post_type', isEqualTo: 'News')
        .orderBy('created_at', descending: true)
        .limit(limit),
  );
}

Future<List<ChatsRecord>> fsQueryMemberChats(
  DocumentReference memberRef,
) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryMemberChats(memberRef);
  }
  return queryChatsRecordOnce(
    queryBuilder: (chatsRecord) => chatsRecord.where(
      'members',
      arrayContains: memberRef,
    ),
  );
}

Future<List<ChatsRecord>> fsQueryServiceChats() async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryServiceChats();
  }
  return queryChatsRecordOnce(
    queryBuilder: (chatsRecord) =>
        chatsRecord.where('is_service_chat', isEqualTo: true),
  );
}

Future<List<ChatsRecord>> fsQueryMemberDmChats({
  required DocumentReference memberRef,
  DocumentReference? workspaceRef,
}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryMemberDmChats(
      memberRef: memberRef,
      workspaceRef: workspaceRef,
    );
  }
  return queryChatsRecordOnce(
    queryBuilder: (chatsRecord) {
      var q = chatsRecord
          .where('members', arrayContains: memberRef)
          .where('is_group', isEqualTo: false);
      if (workspaceRef != null) {
        q = q.where('workspace_ref', isEqualTo: workspaceRef);
      }
      return q;
    },
  );
}

/// Delete a message and fix chat preview when it was the last sent message.
Future<void> fsUnsendMessage({
  required MessagesRecord message,
  required DocumentReference chatRef,
}) async {
  await fsDeleteDocument(message.reference);

  if (currentUserReference == null) return;

  DocumentReference? lastSent;
  if (useWindowsFirestoreRest) {
    final chatData = await WindowsFirestoreRest.fetchDocumentData(chatRef);
    if (chatData == null) return;
    lastSent = chatData['last_message_sent'] as DocumentReference?;
  } else {
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) return;
    lastSent =
        (chatDoc.data() as Map<String, dynamic>)['last_message_sent']
            as DocumentReference?;
  }
  if (lastSent != currentUserReference) return;

  final previous = await fsQueryChatMessages(chatRef, limit: 1);
  if (previous.isNotEmpty) {
    final p = previous.first;
    var preview = p.content;
    preview = preview.replaceAllMapped(
      RegExp(r'<@[^|]+\|([^>]+)>'),
      (m) => '@${m.group(1)}',
    );
    await fsPatchDocument(chatRef, {
      'last_message':
          preview.length > 100 ? preview.substring(0, 100) : preview,
      'last_message_at': p.createdAt,
      'last_message_sent': p.senderRef,
      'last_message_type': p.messageType?.serialize() ?? MessageType.text.serialize(),
    });
  } else {
    await fsPatchDocument(chatRef, {
      'last_message': '',
      'last_message_at': getCurrentTimestamp,
      'last_message_sent': currentUserReference,
      'last_message_type': MessageType.text.serialize(),
    });
  }
}

Future<void> fsMarkActionItemDone(DocumentReference actionItemRef) async {
  await fsPatchDocument(actionItemRef, {
    'status': 'completed',
    'completed_time': getCurrentTimestamp,
  });
}

/// Returns all action item docs that represent the same task (same chat + title).
Future<List<ActionItemsRecord>> fsActionItemsMatchingTask(
  ActionItemsRecord todo,
) async {
  if (todo.chatRef == null) {
    return [todo];
  }

  final titleKey = todo.title.toLowerCase().trim();
  final all = await fsQueryActionItemsByChat(todo.chatRef!);
  return all
      .where((t) => t.title.toLowerCase().trim() == titleKey)
      .toList();
}

/// Deletes every action item doc that matches [todo] (same chat + title).
Future<void> fsDeleteMatchingActionItems(ActionItemsRecord todo) async {
  final tasks = await fsActionItemsMatchingTask(todo);
  for (final task in tasks) {
    await fsDeleteDocument(task.reference);
  }
}

Future<DocumentReference> fsCreateChat(Map<String, dynamic> data) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.createDocument(
      collectionPath: 'chats',
      data: data,
    );
  }
  return ChatsRecord.collection.add(data);
}

Future<void> fsBlockUser({
  required DocumentReference blockerUser,
  required DocumentReference blockedUser,
}) async {
  final data = {
    ...createBlockedUsersRecordData(
      blockerUser: blockerUser,
      blockedUser: blockedUser,
      createdAt: getCurrentTimestamp,
    ),
  };
  if (useWindowsFirestoreRest) {
    await WindowsFirestoreRest.createDocument(
      collectionPath: 'blocked_users',
      data: data,
    );
    return;
  }
  await BlockedUsersRecord.collection.add(data);
}

Future<void> fsUnblockUser({
  required DocumentReference blockerUser,
  required DocumentReference blockedUser,
}) async {
  if (useWindowsFirestoreRest) {
    final records = await fsQueryBlockedUsers(blockerUser);
    for (final record in records) {
      if (record.blockedUser?.path == blockedUser.path) {
        await fsDeleteDocument(record.reference);
      }
    }
    return;
  }
  final blockedRecords = await BlockedUsersRecord.collection
      .where('blocker_user', isEqualTo: blockerUser)
      .where('blocked_user', isEqualTo: blockedUser)
      .get();
  for (final doc in blockedRecords.docs) {
    await doc.reference.delete();
  }
}

Future<UsersRecord?> fsTryGetUserOnce(DocumentReference ref) async {
  try {
    return await fsGetUserOnce(ref);
  } catch (_) {
    return null;
  }
}

bool _arrayContainsValue(List<dynamic> list, dynamic value) {
  if (value is DocumentReference) {
    return list.any(
      (e) => e is DocumentReference && e.path == value.path,
    );
  }
  return list.contains(value);
}

Future<void> fsArrayUnion(
  DocumentReference ref,
  String field,
  List<dynamic> values,
) async {
  if (useWindowsFirestoreRest) {
    final data = await WindowsFirestoreRest.fetchDocumentData(ref);
    final current = List<dynamic>.from(
      _readNestedField(data, field) as List? ?? [],
    );
    for (final value in values) {
      if (!_arrayContainsValue(current, value)) {
        current.add(value);
      }
    }
    await _writeNestedArrayField(ref, field, current);
    return;
  }
  await ref.update({field: FieldValue.arrayUnion(values)});
}

Future<void> fsArrayRemove(
  DocumentReference ref,
  String field,
  List<dynamic> values,
) async {
  if (useWindowsFirestoreRest) {
    final data = await WindowsFirestoreRest.fetchDocumentData(ref);
    final current = List<dynamic>.from(
      _readNestedField(data, field) as List? ?? [],
    );
    current.removeWhere((item) {
      for (final value in values) {
        if (value is DocumentReference && item is DocumentReference) {
          if (item.path == value.path) return true;
        } else if (item == value) {
          return true;
        }
      }
      return false;
    });
    await _writeNestedArrayField(ref, field, current);
    return;
  }
  await ref.update({field: FieldValue.arrayRemove(values)});
}

Future<List<AnnouncementsRecord>> fsQueryPinnedAnnouncements(
  DocumentReference chatRef, {
  int limit = 1,
}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryAnnouncements(
      chatRef: chatRef,
      equalFilter: {'is_pinned': true},
      limit: limit,
    );
  }
  return queryAnnouncementsRecordOnce(
    parent: chatRef,
    queryBuilder: (q) => q.where('is_pinned', isEqualTo: true).limit(limit),
  );
}

Future<List<AnnouncementsRecord>> fsQueryChatAnnouncements(
  DocumentReference chatRef, {
  int limit = 50,
}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryAnnouncements(
      chatRef: chatRef,
      orderField: 'created_at',
      descending: true,
      limit: limit,
    );
  }
  return queryAnnouncementsRecordOnce(
    parent: chatRef,
    queryBuilder: (q) => q.orderBy('created_at', descending: true).limit(limit),
  );
}

Future<List<ChatFoldersRecord>> fsQueryChatFolders(
  DocumentReference userRef,
) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryChatFolders(userRef);
  }
  return queryChatFoldersRecordOnce(
    parent: userRef,
    queryBuilder: (q) => q.orderBy('order'),
  );
}

Future<void> fsSetDocument(
  DocumentReference ref,
  Map<String, dynamic> data,
) async {
  if (useWindowsFirestoreRest) {
    await WindowsFirestoreRest.setDocument(ref: ref, data: data);
    return;
  }
  await ref.set(data);
}

Future<DocumentReference> fsCreateChatFolderDocument({
  required DocumentReference userRef,
  required Map<String, dynamic> data,
  String? id,
}) async {
  final docRef = ChatFoldersRecord.createDoc(userRef, id: id);
  await fsSetDocument(docRef, data);
  return docRef;
}

Future<DocumentReference> fsCreateSubcollectionDocument({
  required DocumentReference parentRef,
  required String collectionId,
  required Map<String, dynamic> data,
}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.createSubcollectionDocument(
      parentRef: parentRef,
      collectionId: collectionId,
      data: data,
    );
  }
  final ref = parentRef.collection(collectionId).doc();
  await ref.set(data);
  return ref;
}

Future<void> fsCreateMessageAndUpdateChat({
  required DocumentReference chatRef,
  required Map<String, dynamic> messageData,
  required Map<String, dynamic> chatUpdateData,
}) async {
  await fsCreateMessage(chatRef, messageData);
  await fsPatchDocument(chatRef, chatUpdateData);
}

Future<Map<String, dynamic>?> fsFetchDocumentData(
  DocumentReference ref,
) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.fetchDocumentData(ref);
  }
  final snap = await ref.get();
  if (!snap.exists) return null;
  return snap.data() as Map<String, dynamic>?;
}

dynamic _readNestedField(Map<String, dynamic>? data, String fieldPath) {
  if (data == null) return null;
  if (!fieldPath.contains('.')) return data[fieldPath];
  dynamic current = data;
  for (final part in fieldPath.split('.')) {
    if (current is! Map<String, dynamic>) return null;
    current = current[part];
  }
  return current;
}

Future<void> _writeNestedArrayField(
  DocumentReference ref,
  String fieldPath,
  List<dynamic> values,
) async {
  if (!fieldPath.contains('.')) {
    await fsPatchDocument(ref, {fieldPath: values});
    return;
  }
  final parts = fieldPath.split('.');
  final topKey = parts.first;
  final data = await fsFetchDocumentData(ref);
  final top = Map<String, dynamic>.from(
    (data?[topKey] as Map<String, dynamic>?) ?? {},
  );
  dynamic current = top;
  for (final part in parts.sublist(1, parts.length - 1)) {
    final next = Map<String, dynamic>.from(
      (current[part] as Map<String, dynamic>?) ?? {},
    );
    current[part] = next;
    current = next;
  }
  current[parts.last] = values;
  await fsPatchDocument(ref, {topKey: top});
}

Future<List<ActionItemsRecord>> fsQueryActionItemsByChat(
  DocumentReference chatRef, {
  int limit = 200,
}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryActionItemsByChat(
      chatRef: chatRef,
      limit: limit,
    );
  }
  return queryActionItemsRecordOnce(
    queryBuilder: (q) => q.where('chat_ref', isEqualTo: chatRef).limit(limit),
  );
}

Future<List<MessagesRecord>> fsQueryPinnedMessages(
  DocumentReference chatRef, {
  int limit = 50,
}) async {
  return fsQueryChatMessages(
    chatRef,
    limit: limit,
    equalFilter: {'is_pinned': true},
  );
}

Future<List<UsersRecord>> fsQueryUsers({
  int limit = 100,
  String? startAfterUserId,
}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryUsers(
      limit: limit,
      startAfterUserId: startAfterUserId,
    );
  }
  Query query = UsersRecord.collection.orderBy(FieldPath.documentId).limit(limit);
  if (startAfterUserId != null) {
    query = query.startAfter([UsersRecord.collection.doc(startAfterUserId)]);
  }
  final snapshot = await query.get();
  return snapshot.docs.map((doc) => UsersRecord.fromSnapshot(doc)).toList();
}

Future<List<DocumentReference>> fsQueryWorkspaceMemberUserRefs(
  DocumentReference workspaceRef,
) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryWorkspaceMemberUserRefs(
      workspaceRef: workspaceRef,
    );
  }
  final snapshot = await FirebaseFirestore.instance
      .collection('workspace_members')
      .where('workspace_ref', isEqualTo: workspaceRef)
      .where('status', isEqualTo: 'active')
      .get();
  return snapshot.docs
      .map((doc) {
        final data = doc.data();
        return data['user_ref'] as DocumentReference?;
      })
      .whereType<DocumentReference>()
      .toList();
}

Future<DocumentReference> fsCreateActionItem(Map<String, dynamic> data) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.createDocument(
      collectionPath: 'action_items',
      data: data,
    );
  }
  return ActionItemsRecord.collection.add(data);
}

Future<DocumentReference> fsCreateRootDocument({
  required String collectionPath,
  required Map<String, dynamic> data,
}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.createDocument(
      collectionPath: collectionPath,
      data: data,
    );
  }
  return FirebaseFirestore.instance.collection(collectionPath).add(data);
}

Future<void> fsCreateScheduledMessage(Map<String, dynamic> data) async {
  if (useWindowsFirestoreRest) {
    await WindowsFirestoreRest.createScheduledMessage(data);
    return;
  }
  await FirebaseFirestore.instance.collection('scheduled_messages').add(data);
}

Future<void> fsIncrementDocumentField(
  DocumentReference ref,
  String field,
  int delta,
) async {
  if (useWindowsFirestoreRest) {
    await WindowsFirestoreRest.incrementDocumentField(ref, field, delta);
    return;
  }
  await ref.update({field: FieldValue.increment(delta)});
}

Future<void> fsDeleteMultipleFields(
  DocumentReference ref,
  List<String> fieldPaths,
) async {
  for (final path in fieldPaths) {
    await fsDeleteDocumentField(ref, path);
  }
}

Future<List<ReportsRecord>> fsQueryReportsByChatGroup(
  DocumentReference chatRef,
) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryReportsByChatGroup(chatRef);
  }
  return queryReportsRecordOnce(
    queryBuilder: (q) => q.where('chat_group', isEqualTo: chatRef),
  );
}

Future<List<ParticipantRecord>> fsQueryParticipants(
  DocumentReference eventRef,
) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryParticipants(eventRef);
  }
  return queryParticipantRecordOnce(parent: eventRef);
}

Future<List<ActionItemsRecord>> fsQueryActionItemsByUser(
  DocumentReference userRef, {
  int limit = 200,
}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryActionItemsByUser(
      userRef: userRef,
      limit: limit,
    );
  }
  return queryActionItemsRecordOnce(
    queryBuilder: (q) => q
        .where('user_ref', isEqualTo: userRef)
        .orderBy('created_time', descending: true)
        .limit(limit),
  );
}

Future<List<EventsRecord>> fsQueryEvents({int limit = 50}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryEvents(limit: limit);
  }
  return queryEventsRecordOnce(
    queryBuilder: (q) =>
        q.orderBy('created_at', descending: true).limit(limit),
  );
}

Future<List<PostsRecord>> fsQueryAllPosts({int limit = 100}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryAllPosts(limit: limit);
  }
  return queryPostsRecordOnce(
    queryBuilder: (q) =>
        q.orderBy('created_at', descending: true).limit(limit),
  );
}

Future<List<WorkspaceMembersRecord>> fsQueryWorkspaceMembers(
  DocumentReference workspaceRef,
) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryWorkspaceMembers(
      workspaceRef: workspaceRef,
    );
  }
  return queryWorkspaceMembersRecordOnce(
    queryBuilder: (q) => q
        .where('workspace_ref', isEqualTo: workspaceRef)
        .where('status', isEqualTo: 'active'),
  );
}

Future<WorkspacesRecord> fsGetWorkspaceOnce(DocumentReference ref) async {
  if (useWindowsFirestoreRest) {
    final data = await WindowsFirestoreRest.fetchDocumentData(ref);
    if (data == null) {
      throw StateError('Workspace not found: ${ref.path}');
    }
    return WorkspacesRecord.getDocumentFromData(data, ref);
  }
  return WorkspacesRecord.getDocumentOnce(ref);
}

Future<List<FsDocSnapshot>> fsQueryAiConversations(
  DocumentReference userRef,
) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryAiConversations(userRef);
  }
  final snap = await FirebaseFirestore.instance
      .collection('ai_assistant_conversations')
      .where('user_ref', isEqualTo: userRef)
      .orderBy('is_pinned', descending: true)
      .orderBy('last_message_at', descending: true)
      .get();
  return snap.docs
      .map((d) => FsDocSnapshot.fromQuery(d))
      .toList();
}

Future<FsDocSnapshot?> fsQueryActiveAiConversation(
  DocumentReference userRef,
) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryActiveAiConversation(userRef);
  }
  final snap = await FirebaseFirestore.instance
      .collection('ai_assistant_conversations')
      .where('user_ref', isEqualTo: userRef)
      .where('is_active', isEqualTo: true)
      .limit(1)
      .get();
  if (snap.docs.isEmpty) return null;
  return FsDocSnapshot.fromQuery(snap.docs.first);
}

Future<List<FsDocSnapshot>> fsQueryAiMessages(String conversationId) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryAiMessages(conversationId: conversationId);
  }
  final snap = await FirebaseFirestore.instance
      .collection('ai_assistant_conversations')
      .doc(conversationId)
      .collection('messages')
      .orderBy('created_at', descending: false)
      .get();
  return snap.docs
      .map((d) => FsDocSnapshot.fromQuery(d))
      .toList();
}

Future<List<FsDocSnapshot>> fsQueryUserSubcollection({
  required DocumentReference userRef,
  required String collectionId,
  Map<String, dynamic>? equalFilter,
}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryUserSubcollection(
      userRef: userRef,
      collectionId: collectionId,
      equalFilter: equalFilter,
    );
  }
  Query<Map<String, dynamic>> q = userRef.collection(collectionId);
  if (equalFilter != null) {
    equalFilter.forEach((field, value) {
      q = q.where(field, isEqualTo: value);
    });
  }
  final snap = await q.get();
  return snap.docs.map((d) => FsDocSnapshot.fromQuery(d)).toList();
}

Future<bool> fsIsUserBlocked({
  required DocumentReference blockerRef,
  required DocumentReference blockedRef,
}) async {
  if (useWindowsFirestoreRest) {
    final records = await fsQueryBlockedUsers(blockerRef);
    return records.any((r) => r.blockedUser?.path == blockedRef.path);
  }
  final snap = await BlockedUsersRecord.collection
      .where('blocker_user', isEqualTo: blockerRef)
      .where('blocked_user', isEqualTo: blockedRef)
      .limit(1)
      .get();
  return snap.docs.isNotEmpty;
}

Future<PostsRecord?> fsGetPostOnce(DocumentReference ref) async {
  if (useWindowsFirestoreRest) {
    final data = await WindowsFirestoreRest.fetchDocumentData(ref);
    if (data == null) return null;
    return PostsRecord.getDocumentFromData(data, ref);
  }
  return PostsRecord.getDocumentOnce(ref);
}

Future<List<PostsRecord>> fsQueryPostsByAuthor(
  DocumentReference authorRef, {
  int limit = 50,
}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryPosts(
      equalFilter: {'author_ref': authorRef},
      limit: limit,
    );
  }
  return queryPostsRecordOnce(
    queryBuilder: (q) => q.where('author_ref', isEqualTo: authorRef).limit(limit),
  );
}

Future<List<CommentsRecord>> fsQueryComments(
  DocumentReference postRef, {
  int limit = 100,
}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryComments(postRef: postRef, limit: limit);
  }
  return queryCommentsRecordOnce(
    parent: postRef,
    queryBuilder: (q) =>
        q.orderBy('created_at', descending: true).limit(limit),
  );
}

Future<List<EventsRecord>> fsQueryEventsByEventId(String eventId) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryEventsByEventId(eventId);
  }
  return queryEventsRecordOnce(
    queryBuilder: (q) => q.where('event_id', isEqualTo: eventId),
  );
}

Future<List<ChatsRecord>> fsQueryGroupChats() async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryGroupChats();
  }
  return queryChatsRecordOnce(
    queryBuilder: (q) => q.where('is_group', isEqualTo: true),
  );
}

Future<List<ChatsRecord>> fsQueryEventGroupChats(
  DocumentReference eventRef,
) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryEventGroupChats(eventRef);
  }
  return queryChatsRecordOnce(
    queryBuilder: (q) => q
        .where('is_group', isEqualTo: true)
        .where('event_ref', isEqualTo: eventRef),
  );
}

Future<List<ChatsRecord>> fsQueryChatsByEventRef(
  DocumentReference eventRef,
) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryChatsByEventRef(eventRef);
  }
  return queryChatsRecordOnce(
    queryBuilder: (q) => q.where('event_ref', isEqualTo: eventRef).limit(1),
  );
}

Future<void> fsCreateAiMessage({
  required String conversationId,
  required Map<String, dynamic> data,
}) async {
  if (useWindowsFirestoreRest) {
    await WindowsFirestoreRest.createSubcollectionDocument(
      parentRef: FirebaseFirestore.instance
          .collection('ai_assistant_conversations')
          .doc(conversationId),
      collectionId: 'messages',
      data: data,
    );
    return;
  }
  await FirebaseFirestore.instance
      .collection('ai_assistant_conversations')
      .doc(conversationId)
      .collection('messages')
      .add(data);
}

Future<List<FsDocSnapshot>> fsQueryUserPushNotifications({
  required String userPath,
  int limit = 200,
}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryUserPushNotifications(
      userPath: userPath,
      limit: limit,
    );
  }
  final snap = await FirebaseFirestore.instance
      .collection('ff_user_push_notifications')
      .where('user_refs', arrayContains: userPath)
      .where('status', isEqualTo: 'succeeded')
      .get();
  return snap.docs.map((d) => FsDocSnapshot.fromQuery(d)).toList();
}

Future<List<FsDocSnapshot>> fsQueryAllUserPushNotifications({
  int limit = 50,
}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.queryAllUserPushNotifications(limit: limit);
  }
  final snap = await FirebaseFirestore.instance
      .collection('ff_user_push_notifications')
      .orderBy('timestamp', descending: true)
      .limit(limit)
      .get();
  return snap.docs.map((d) => FsDocSnapshot.fromQuery(d)).toList();
}

Future<List<FsDocSnapshot>> fsQuerySystemPushNotifications({
  int limit = 50,
}) async {
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.querySystemPushNotifications(limit: limit);
  }
  final snap = await FirebaseFirestore.instance
      .collection('ff_push_notifications')
      .where('target_audience', isEqualTo: 'All')
      .orderBy('timestamp', descending: true)
      .limit(limit)
      .get();
  return snap.docs.map((d) => FsDocSnapshot.fromQuery(d)).toList();
}
