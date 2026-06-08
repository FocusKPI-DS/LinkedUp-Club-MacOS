import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '/backend/backend.dart';
import '/backend/cloud_functions/callable_functions.dart';
import '/backend/schema/util/firestore_util.dart';
import 'fs_doc_snapshot.dart';

/// Bypass [cloud_firestore] native reads/writes on Windows/Linux (plugin threading crash).
bool get useWindowsFirestoreRest =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux);

class WindowsFirestoreRest {
  WindowsFirestoreRest._();

  static const _databaseRoot =
      'projects/$kFirebaseFunctionsProjectId/databases/(default)/documents';

  static Uri _runQueryUri({String? parentPath}) {
    if (parentPath == null || parentPath.isEmpty) {
      return Uri.parse(
        'https://firestore.googleapis.com/v1/$_databaseRoot:runQuery',
      );
    }
    return Uri.parse(
      'https://firestore.googleapis.com/v1/$_databaseRoot/$parentPath:runQuery',
    );
  }

  static Uri _documentUri(String documentPath) => Uri.parse(
        'https://firestore.googleapis.com/v1/$_databaseRoot/$documentPath',
      );

  static Future<String> _idToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Must be signed in for Firestore REST');
    }
    return (await user.getIdToken())!;
  }

  /// Chats where [memberRef] is in `members`.
  static Future<List<ChatsRecord>> queryMemberChats(
    DocumentReference memberRef,
  ) async {
    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'chats'},
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'members'},
            'op': 'ARRAY_CONTAINS',
            'value': {
              'referenceValue': '$_databaseRoot/${memberRef.path}',
            },
          },
        },
      },
      label: 'REST chats:members',
      mapRecord: (data, ref) => ChatsRecord.getDocumentFromData(data, ref),
    );
  }

  /// Service / Summer AI chats.
  static Future<List<ChatsRecord>> queryServiceChats() async {
    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'chats'},
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'is_service_chat'},
            'op': 'EQUAL',
            'value': {'booleanValue': true},
          },
        },
      },
      label: 'REST chats:service',
      mapRecord: (data, ref) => ChatsRecord.getDocumentFromData(data, ref),
    );
  }

  /// Messages in `chats/{chatId}/messages`.
  ///
  /// With [startAfter] (oldest message already loaded), returns the next page of
  /// older messages when ordered by `created_at` descending.
  static Future<List<MessagesRecord>> queryMessages({
    required DocumentReference chatRef,
    int limit = 80,
    bool descending = true,
    Map<String, dynamic>? equalFilter,
    MessagesRecord? startAfter,
  }) async {
    final orderBy = [
      {
        'field': {'fieldPath': 'created_at'},
        'direction': descending ? 'DESCENDING' : 'ASCENDING',
      },
      {
        'field': {'fieldPath': '__name__'},
        'direction': descending ? 'DESCENDING' : 'ASCENDING',
      },
    ];

    final structuredQuery = <String, dynamic>{
      'from': [
        {'collectionId': 'messages'},
      ],
      if (equalFilter != null)
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': equalFilter.keys.first},
            'op': 'EQUAL',
            'value': _encodeRestValue(equalFilter.values.first),
          },
        },
      'orderBy': orderBy,
      'limit': limit,
    };

    if (startAfter != null && startAfter.createdAt != null) {
      structuredQuery['startAfter'] = {
        'values': [
          _encodeRestValue(startAfter.createdAt!),
          _encodeRestValue(startAfter.reference),
        ],
      };
    }

    final pageLabel = startAfter != null ? ' (older)' : '';
    return _runQuery(
      parentPath: chatRef.path,
      structuredQuery: structuredQuery,
      label: 'REST messages:${chatRef.id}$pageLabel',
      mapRecord: (data, ref) => MessagesRecord.getDocumentFromData(data, ref),
    );
  }

  /// `users/{userId}/chat_folders` ordered by `order`.
  static Future<List<ChatFoldersRecord>> queryChatFolders(
    DocumentReference userRef,
  ) async {
    return _runQuery(
      parentPath: userRef.path,
      structuredQuery: {
        'from': [
          {'collectionId': 'chat_folders'},
        ],
        'orderBy': [
          {
            'field': {'fieldPath': 'order'},
            'direction': 'ASCENDING',
          },
        ],
      },
      label: 'REST chat_folders:${userRef.id}',
      mapRecord: (data, ref) =>
          ChatFoldersRecord.getDocumentFromData(data, ref),
    );
  }

  /// Announcements in `chats/{chatId}/announcements`.
  static Future<List<AnnouncementsRecord>> queryAnnouncements({
    required DocumentReference chatRef,
    Map<String, dynamic>? equalFilter,
    int limit = 10,
    String? orderField,
    bool descending = true,
  }) async {
    final structuredQuery = <String, dynamic>{
      'from': [
        {'collectionId': 'announcements'},
      ],
      if (equalFilter != null)
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': equalFilter.keys.first},
            'op': 'EQUAL',
            'value': _encodeRestValue(equalFilter.values.first),
          },
        },
      if (orderField != null)
        'orderBy': [
          {
            'field': {'fieldPath': orderField},
            'direction': descending ? 'DESCENDING' : 'ASCENDING',
          },
        ],
      'limit': limit,
    };

    return _runQuery(
      parentPath: chatRef.path,
      structuredQuery: structuredQuery,
      label: 'REST announcements:${chatRef.id}',
      mapRecord: (data, ref) =>
          AnnouncementsRecord.getDocumentFromData(data, ref),
    );
  }

  /// Action items for a specific chat.
  static Future<List<ActionItemsRecord>> queryActionItemsByChat({
    required DocumentReference chatRef,
    int limit = 200,
  }) async {
    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'action_items'},
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'chat_ref'},
            'op': 'EQUAL',
            'value': {
              'referenceValue': '$_databaseRoot/${chatRef.path}',
            },
          },
        },
        'limit': limit,
      },
      label: 'REST action_items:${chatRef.id}',
      mapRecord: (data, ref) =>
          ActionItemsRecord.getDocumentFromData(data, ref),
    );
  }

  /// Comments under `posts/{postId}/comments`.
  static Future<List<CommentsRecord>> queryComments({
    required DocumentReference postRef,
    int limit = 100,
  }) async {
    return _runQuery(
      parentPath: postRef.path,
      structuredQuery: {
        'from': [
          {'collectionId': 'comments'},
        ],
        'orderBy': [
          {
            'field': {'fieldPath': 'created_at'},
            'direction': 'DESCENDING',
          },
        ],
        'limit': limit,
      },
      label: 'REST comments:${postRef.id}',
      mapRecord: (data, ref) =>
          CommentsRecord.getDocumentFromData(data, ref),
    );
  }

  /// Events matching a business `event_id` field.
  static Future<List<EventsRecord>> queryEventsByEventId(String eventId) async {
    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'events'},
        ],
        'where': _fieldEqualFilter('event_id', eventId),
        'limit': 1,
      },
      label: 'REST events:event_id',
      mapRecord: (data, ref) => EventsRecord.getDocumentFromData(data, ref),
    );
  }

  /// Group chats (`is_group == true`).
  static Future<List<ChatsRecord>> queryGroupChats() async {
    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'chats'},
        ],
        'where': _fieldEqualFilter('is_group', true),
      },
      label: 'REST chats:group',
      mapRecord: (data, ref) => ChatsRecord.getDocumentFromData(data, ref),
    );
  }

  /// Group chats tied to an event.
  static Future<List<ChatsRecord>> queryEventGroupChats(
    DocumentReference eventRef,
  ) async {
    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'chats'},
        ],
        'where': _compositeAnd([
          _fieldEqualFilter('is_group', true),
          _fieldEqualFilter('event_ref', eventRef),
        ]),
      },
      label: 'REST chats:event_group',
      mapRecord: (data, ref) => ChatsRecord.getDocumentFromData(data, ref),
    );
  }

  /// Any chat linked to an event (first match).
  static Future<List<ChatsRecord>> queryChatsByEventRef(
    DocumentReference eventRef,
  ) async {
    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'chats'},
        ],
        'where': _fieldEqualFilter('event_ref', eventRef),
        'limit': 1,
      },
      label: 'REST chats:event_ref',
      mapRecord: (data, ref) => ChatsRecord.getDocumentFromData(data, ref),
    );
  }

  /// Latest news posts (root `posts` collection).
  static Future<List<PostsRecord>> queryPosts({
    Map<String, dynamic>? equalFilter,
    String orderField = 'created_at',
    bool descending = true,
    int limit = 10,
  }) async {
    final structuredQuery = <String, dynamic>{
      'from': [
        {'collectionId': 'posts'},
      ],
      if (equalFilter != null)
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': equalFilter.keys.first},
            'op': 'EQUAL',
            'value': _encodeRestValue(equalFilter.values.first),
          },
        },
      'orderBy': [
        {
          'field': {'fieldPath': orderField},
          'direction': descending ? 'DESCENDING' : 'ASCENDING',
        },
      ],
      'limit': limit,
    };

    return _runQuery(
      structuredQuery: structuredQuery,
      label: 'REST posts',
      mapRecord: (data, ref) => PostsRecord.getDocumentFromData(data, ref),
    );
  }

  /// Users collection (paginated by document id).
  static Future<List<UsersRecord>> queryUsers({
    int limit = 100,
    String? startAfterUserId,
  }) async {
    final structuredQuery = <String, dynamic>{
      'from': [
        {'collectionId': 'users'},
      ],
      'orderBy': [
        {
          'field': {'fieldPath': '__name__'},
          'direction': 'ASCENDING',
        },
      ],
      'limit': limit,
      if (startAfterUserId != null)
        'startAt': {
          'values': [
            {
              'referenceValue': '$_databaseRoot/users/$startAfterUserId',
            },
          ],
          'before': false,
        },
    };

    return _runQuery(
      structuredQuery: structuredQuery,
      label: 'REST users',
      mapRecord: (data, ref) => UsersRecord.getDocumentFromData(data, ref),
    );
  }

  /// Active workspace members — returns each member's `user_ref`.
  static Future<List<DocumentReference>> queryWorkspaceMemberUserRefs({
    required DocumentReference workspaceRef,
  }) async {
    final rows = await _runQuery<Map<String, dynamic>>(
      structuredQuery: {
        'from': [
          {'collectionId': 'workspace_members'},
        ],
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'workspace_ref'},
                  'op': 'EQUAL',
                  'value': {
                    'referenceValue': '$_databaseRoot/${workspaceRef.path}',
                  },
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'status'},
                  'op': 'EQUAL',
                  'value': {'stringValue': 'active'},
                },
              },
            ],
          },
        },
      },
      label: 'REST workspace_members:${workspaceRef.id}',
      mapRecord: (data, ref) => data,
    );

    return rows
        .map((data) => data['user_ref'] as DocumentReference?)
        .whereType<DocumentReference>()
        .toList();
  }

  static Map<String, dynamic> _fieldEqualFilter(String field, dynamic value) => {
        'fieldFilter': {
          'field': {'fieldPath': field},
          'op': 'EQUAL',
          'value': _encodeRestValue(value),
        },
      };

  static Map<String, dynamic> _compositeAnd(
    List<Map<String, dynamic>> filters,
  ) =>
      {'compositeFilter': {'op': 'AND', 'filters': filters}};

  static Map<String, dynamic> _arrayContainsFilter(
    String field,
    dynamic value,
  ) =>
      {
        'fieldFilter': {
          'field': {'fieldPath': field},
          'op': 'ARRAY_CONTAINS',
          'value': _encodeRestValue(value),
        },
      };

  /// User push notifications for badge / settings (arrayContains + succeeded).
  static Future<List<FsDocSnapshot>> queryUserPushNotifications({
    required String userPath,
    int limit = 200,
  }) async {
    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'ff_user_push_notifications'},
        ],
        'where': _compositeAnd([
          _arrayContainsFilter('user_refs', userPath),
          _fieldEqualFilter('status', 'succeeded'),
        ]),
        'limit': limit,
      },
      label: 'REST ff_user_push_notifications:$userPath',
      mapRecord: (data, ref) =>
          FsDocSnapshot.fromRecord(reference: ref, data: data),
    );
  }

  /// All user push notifications ordered by timestamp (client filters by user).
  static Future<List<FsDocSnapshot>> queryAllUserPushNotifications({
    int limit = 50,
  }) async {
    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'ff_user_push_notifications'},
        ],
        'orderBy': [
          {
            'field': {'fieldPath': 'timestamp'},
            'direction': 'DESCENDING',
          },
        ],
        'limit': limit,
      },
      label: 'REST ff_user_push_notifications:all',
      mapRecord: (data, ref) =>
          FsDocSnapshot.fromRecord(reference: ref, data: data),
    );
  }

  /// System-wide push notifications (target_audience = All).
  static Future<List<FsDocSnapshot>> querySystemPushNotifications({
    int limit = 50,
  }) async {
    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'ff_push_notifications'},
        ],
        'where': _fieldEqualFilter('target_audience', 'All'),
        'orderBy': [
          {
            'field': {'fieldPath': 'timestamp'},
            'direction': 'DESCENDING',
          },
        ],
        'limit': limit,
      },
      label: 'REST ff_push_notifications:system',
      mapRecord: (data, ref) =>
          FsDocSnapshot.fromRecord(reference: ref, data: data),
    );
  }

  /// Reports for a chat group.
  static Future<List<ReportsRecord>> queryReportsByChatGroup(
    DocumentReference chatRef,
  ) async {
    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'reports'},
        ],
        'where': _fieldEqualFilter('chat_group', chatRef),
      },
      label: 'REST reports:${chatRef.id}',
      mapRecord: (data, ref) => ReportsRecord.getDocumentFromData(data, ref),
    );
  }

  /// Event participants subcollection.
  static Future<List<ParticipantRecord>> queryParticipants(
    DocumentReference eventRef,
  ) async {
    return _runQuery(
      parentPath: eventRef.path,
      structuredQuery: {
        'from': [
          {'collectionId': 'participant'},
        ],
      },
      label: 'REST participant:${eventRef.id}',
      mapRecord: (data, ref) =>
          ParticipantRecord.getDocumentFromData(data, ref),
    );
  }

  /// Action items assigned to a user.
  static Future<List<ActionItemsRecord>> queryActionItemsByUser({
    required DocumentReference userRef,
    int limit = 200,
  }) async {
    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'action_items'},
        ],
        'where': _fieldEqualFilter('user_ref', userRef),
        'orderBy': [
          {
            'field': {'fieldPath': 'created_time'},
            'direction': 'DESCENDING',
          },
        ],
        'limit': limit,
      },
      label: 'REST action_items:user:${userRef.id}',
      mapRecord: (data, ref) =>
          ActionItemsRecord.getDocumentFromData(data, ref),
    );
  }

  /// Root events collection ordered by date.
  static Future<List<EventsRecord>> queryEvents({int limit = 50}) async {
    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'events'},
        ],
        'orderBy': [
          {
            'field': {'fieldPath': 'created_at'},
            'direction': 'DESCENDING',
          },
        ],
        'limit': limit,
      },
      label: 'REST events',
      mapRecord: (data, ref) => EventsRecord.getDocumentFromData(data, ref),
    );
  }

  /// All posts (feed), ordered by created_at.
  static Future<List<PostsRecord>> queryAllPosts({int limit = 100}) async {
    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'posts'},
        ],
        'orderBy': [
          {
            'field': {'fieldPath': 'created_at'},
            'direction': 'DESCENDING',
          },
        ],
        'limit': limit,
      },
      label: 'REST posts:all',
      mapRecord: (data, ref) => PostsRecord.getDocumentFromData(data, ref),
    );
  }

  /// Workspace member records for a workspace.
  static Future<List<WorkspaceMembersRecord>> queryWorkspaceMembers({
    required DocumentReference workspaceRef,
  }) async {
    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'workspace_members'},
        ],
        'where': _compositeAnd([
          _fieldEqualFilter('workspace_ref', workspaceRef),
          _fieldEqualFilter('status', 'active'),
        ]),
      },
      label: 'REST workspace_members:${workspaceRef.id}',
      mapRecord: (data, ref) =>
          WorkspaceMembersRecord.getDocumentFromData(data, ref),
    );
  }

  /// AI assistant conversations for a user.
  static Future<List<FsDocSnapshot>> queryAiConversations(
    DocumentReference userRef,
  ) async {
    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'ai_assistant_conversations'},
        ],
        'where': _fieldEqualFilter('user_ref', userRef),
        'orderBy': [
          {
            'field': {'fieldPath': 'is_pinned'},
            'direction': 'DESCENDING',
          },
          {
            'field': {'fieldPath': 'last_message_at'},
            'direction': 'DESCENDING',
          },
        ],
      },
      label: 'REST ai_conversations:${userRef.id}',
      mapRecord: (data, ref) =>
          FsDocSnapshot.fromRecord(reference: ref, data: data),
    );
  }

  /// First active AI conversation for a user (if any).
  static Future<FsDocSnapshot?> queryActiveAiConversation(
    DocumentReference userRef,
  ) async {
    final rows = await _runQuery<FsDocSnapshot>(
      structuredQuery: {
        'from': [
          {'collectionId': 'ai_assistant_conversations'},
        ],
        'where': _compositeAnd([
          _fieldEqualFilter('user_ref', userRef),
          _fieldEqualFilter('is_active', true),
        ]),
        'limit': 1,
      },
      label: 'REST ai_conversations:active:${userRef.id}',
      mapRecord: (data, ref) =>
          FsDocSnapshot.fromRecord(reference: ref, data: data),
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Messages in an AI assistant conversation.
  static Future<List<FsDocSnapshot>> queryAiMessages({
    required String conversationId,
  }) async {
    return _runQuery(
      parentPath: 'ai_assistant_conversations/$conversationId',
      structuredQuery: {
        'from': [
          {'collectionId': 'messages'},
        ],
        'orderBy': [
          {
            'field': {'fieldPath': 'created_at'},
            'direction': 'ASCENDING',
          },
        ],
      },
      label: 'REST ai_messages:$conversationId',
      mapRecord: (data, ref) =>
          FsDocSnapshot.fromRecord(reference: ref, data: data),
    );
  }

  /// Documents in a user subcollection (e.g. api_keys).
  static Future<List<FsDocSnapshot>> queryUserSubcollection({
    required DocumentReference userRef,
    required String collectionId,
    Map<String, dynamic>? equalFilter,
  }) async {
    return _runQuery(
      parentPath: userRef.path,
      structuredQuery: {
        'from': [
          {'collectionId': collectionId},
        ],
        if (equalFilter != null)
          'where': _fieldEqualFilter(
            equalFilter.keys.first,
            equalFilter.values.first,
          ),
      },
      label: 'REST $collectionId:${userRef.id}',
      mapRecord: (data, ref) =>
          FsDocSnapshot.fromRecord(reference: ref, data: data),
    );
  }

  /// Scheduled message create (root collection).
  static Future<void> createScheduledMessage(
    Map<String, dynamic> data,
  ) async {
    await createDocument(collectionPath: 'scheduled_messages', data: data);
  }

  /// Read-modify-write increment for integer fields.
  static Future<void> incrementDocumentField(
    DocumentReference ref,
    String field,
    int delta,
  ) async {
    final current = await fetchDocumentData(ref);
    final value = (current?[field] as num?)?.toInt() ?? 0;
    await patchDocument(ref: ref, data: {field: value + delta});
  }

  /// Create a document in a root collection (auto-generated id).
  static Future<DocumentReference> createDocument({
    required String collectionPath,
    required Map<String, dynamic> data,
  }) async {
    final token = await _idToken();
    final label = 'REST create:$collectionPath';
    // ignore: avoid_print
    print('[WindowsFirestoreRest] → $label');

    final firestoreData = mapToFirestore(data);
    final response = await http
        .post(
          _documentUri(collectionPath),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'fields': _encodeRestFields(firestoreData)}),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode >= 400) {
      throw Exception(
        'Firestore REST $label failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Firestore REST $label: unexpected response shape');
    }
    final name = decoded['name'] as String?;
    if (name == null) {
      throw Exception('Firestore REST $label: missing document name');
    }

    // ignore: avoid_print
    print('[WindowsFirestoreRest] ✓ $label');
    return _documentReferenceFromRestName(name);
  }

  /// Create a document in a subcollection under [parentRef] (auto-generated id).
  static Future<DocumentReference> createSubcollectionDocument({
    required DocumentReference parentRef,
    required String collectionId,
    required Map<String, dynamic> data,
  }) async {
    final token = await _idToken();
    final label = 'REST create:$collectionId@${parentRef.path}';
    // ignore: avoid_print
    print('[WindowsFirestoreRest] → $label');

    final firestoreData = mapToFirestore(data);
    final response = await http
        .post(
          _documentUri('${parentRef.path}/$collectionId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'fields': _encodeRestFields(firestoreData)}),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode >= 400) {
      throw Exception(
        'Firestore REST $label failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Firestore REST $label: unexpected response shape');
    }
    final name = decoded['name'] as String?;
    if (name == null) {
      throw Exception('Firestore REST $label: missing document name');
    }

    // ignore: avoid_print
    print('[WindowsFirestoreRest] ✓ $label');
    return _documentReferenceFromRestName(name);
  }

  /// Create or overwrite a document at a known [ref] (POST with documentId).
  static Future<void> setDocument({
    required DocumentReference ref,
    required Map<String, dynamic> data,
  }) async {
    final token = await _idToken();
    final firestoreData = mapToFirestore(data);
    final label = 'REST set:${ref.path}';
    // ignore: avoid_print
    print('[WindowsFirestoreRest] → $label');

    final pathParts = ref.path.split('/');
    if (pathParts.length < 2) {
      throw ArgumentError('Invalid document path: ${ref.path}');
    }
    final docId = pathParts.last;
    final parentPath = pathParts.sublist(0, pathParts.length - 1).join('/');

    final response = await http
        .post(
          Uri.parse(
            '${_documentUri(parentPath)}?documentId=${Uri.encodeQueryComponent(docId)}',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'fields': _encodeRestFields(firestoreData)}),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode >= 400) {
      throw Exception(
        'Firestore REST $label failed (${response.statusCode}): ${response.body}',
      );
    }

    // ignore: avoid_print
    print('[WindowsFirestoreRest] ✓ $label');
  }

  /// Create a message under [chatRef] via REST (returns new doc ref).
  static Future<DocumentReference> createMessage({
    required DocumentReference chatRef,
    required Map<String, dynamic> data,
  }) async {
    final token = await _idToken();
    final label = 'REST create message:${chatRef.id}';
    // ignore: avoid_print
    print('[WindowsFirestoreRest] → $label');

    final firestoreData = mapToFirestore(data);
    final response = await http
        .post(
          _documentUri('${chatRef.path}/messages'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'fields': _encodeRestFields(firestoreData)}),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode >= 400) {
      throw Exception(
        'Firestore REST $label failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Firestore REST $label: unexpected response shape');
    }
    final name = decoded['name'] as String?;
    if (name == null) {
      throw Exception('Firestore REST $label: missing document name');
    }

    // ignore: avoid_print
    print('[WindowsFirestoreRest] ✓ $label');
    return _documentReferenceFromRestName(name);
  }

  /// Patch fields on any document (chat last_message, seen state, etc.).
  static Future<void> patchDocument({
    required DocumentReference ref,
    required Map<String, dynamic> data,
  }) async {
    final token = await _idToken();
    final firestoreData = mapToFirestore(data);
    if (firestoreData.isEmpty) return;

    final label = 'REST patch:${ref.path}';
    // ignore: avoid_print
    print('[WindowsFirestoreRest] → $label');

    final query = firestoreData.keys
        .map((k) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(k)}')
        .join('&');

    final response = await http
        .patch(
          Uri.parse('${_documentUri(ref.path)}?$query'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'fields': _encodeRestFields(firestoreData)}),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode >= 400) {
      throw Exception(
        'Firestore REST $label failed (${response.statusCode}): ${response.body}',
      );
    }

    // ignore: avoid_print
    print('[WindowsFirestoreRest] ✓ $label');
  }

  /// GET a single document's field map (null if missing).
  static Future<Map<String, dynamic>?> fetchDocumentData(
    DocumentReference ref,
  ) async {
    final token = await _idToken();
    final label = 'REST get:${ref.path}';
    // ignore: avoid_print
    print('[WindowsFirestoreRest] → $label');

    final response = await http
        .get(
          _documentUri(ref.path),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 404) {
      // ignore: avoid_print
      print('[WindowsFirestoreRest] ✓ $label (missing)');
      return null;
    }
    if (response.statusCode >= 400) {
      throw Exception(
        'Firestore REST $label failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    final rawFields = decoded['fields'];
    if (rawFields is! Map) return {};
    final fields = _jsonMap(rawFields);
    // ignore: avoid_print
    print('[WindowsFirestoreRest] ✓ $label');
    return _restFieldsToMap(fields);
  }

  static Future<bool> documentExists(DocumentReference ref) async {
    final data = await fetchDocumentData(ref);
    return data != null;
  }

  static Future<void> deleteDocument(DocumentReference ref) async {
    final token = await _idToken();
    final label = 'REST delete:${ref.path}';
    // ignore: avoid_print
    print('[WindowsFirestoreRest] → $label');

    final response = await http
        .delete(
          _documentUri(ref.path),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode >= 400 && response.statusCode != 404) {
      throw Exception(
        'Firestore REST $label failed (${response.statusCode}): ${response.body}',
      );
    }
    // ignore: avoid_print
    print('[WindowsFirestoreRest] ✓ $label');
  }

  /// Clear a single field (Firestore field delete).
  static Future<void> deleteDocumentField(
    DocumentReference ref,
    String fieldPath,
  ) async {
    final token = await _idToken();
    final label = 'REST delete-field:$fieldPath@${ref.path}';
    // ignore: avoid_print
    print('[WindowsFirestoreRest] → $label');

    final query =
        'updateMask.fieldPaths=${Uri.encodeQueryComponent(fieldPath)}';
    final response = await http
        .patch(
          Uri.parse('${_documentUri(ref.path)}?$query'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'fields': {
              fieldPath: {'nullValue': null},
            },
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode >= 400) {
      throw Exception(
        'Firestore REST $label failed (${response.statusCode}): ${response.body}',
      );
    }
    // ignore: avoid_print
    print('[WindowsFirestoreRest] ✓ $label');
  }

  static Future<UsersRecord?> getUsersRecord(DocumentReference ref) async {
    final data = await fetchDocumentData(ref);
    if (data == null) return null;
    return UsersRecord.getDocumentFromData(data, ref);
  }

  static Future<ChatsRecord?> getChatsRecord(DocumentReference ref) async {
    final data = await fetchDocumentData(ref);
    if (data == null) return null;
    return ChatsRecord.getDocumentFromData(data, ref);
  }

  static Future<List<BlockedUsersRecord>> queryBlockedUsers(
    DocumentReference blockerRef,
  ) async {
    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'blocked_users'},
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'blocker_user'},
            'op': 'EQUAL',
            'value': {
              'referenceValue': '$_databaseRoot/${blockerRef.path}',
            },
          },
        },
      },
      label: 'REST blocked_users',
      mapRecord: (data, ref) =>
          BlockedUsersRecord.getDocumentFromData(data, ref),
    );
  }

  static Future<List<ActionItemsRecord>> queryRecentActionItems({
    int limit = 200,
  }) async {
    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'action_items'},
        ],
        'orderBy': [
          {
            'field': {'fieldPath': 'created_time'},
            'direction': 'DESCENDING',
          },
        ],
        'limit': limit,
      },
      label: 'REST action_items',
      mapRecord: (data, ref) =>
          ActionItemsRecord.getDocumentFromData(data, ref),
    );
  }

  /// DM chats for a member, optionally scoped to [workspaceRef].
  static Future<List<ChatsRecord>> queryMemberDmChats({
    required DocumentReference memberRef,
    DocumentReference? workspaceRef,
  }) async {
    final filters = <Map<String, dynamic>>[
      {
        'fieldFilter': {
          'field': {'fieldPath': 'members'},
          'op': 'ARRAY_CONTAINS',
          'value': {
            'referenceValue': '$_databaseRoot/${memberRef.path}',
          },
        },
      },
      {
        'fieldFilter': {
          'field': {'fieldPath': 'is_group'},
          'op': 'EQUAL',
          'value': {'booleanValue': false},
        },
      },
    ];
    if (workspaceRef != null) {
      filters.add({
        'fieldFilter': {
          'field': {'fieldPath': 'workspace_ref'},
          'op': 'EQUAL',
          'value': {
            'referenceValue': '$_databaseRoot/${workspaceRef.path}',
          },
        },
      });
    }

    return _runQuery(
      structuredQuery: {
        'from': [
          {'collectionId': 'chats'},
        ],
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': filters,
          },
        },
      },
      label: 'REST chats:dm',
      mapRecord: (data, ref) => ChatsRecord.getDocumentFromData(data, ref),
    );
  }

  static Future<List<T>> _runQuery<T>({
    String? parentPath,
    required Map<String, dynamic> structuredQuery,
    required String label,
    required T Function(Map<String, dynamic> data, DocumentReference ref)
        mapRecord,
  }) async {
    final token = await _idToken();
    // ignore: avoid_print
    print('[WindowsFirestoreRest] → $label');

    final response = await http
        .post(
          _runQueryUri(parentPath: parentPath),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'structuredQuery': structuredQuery}),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode >= 400) {
      throw Exception(
        'Firestore REST $label failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Firestore REST $label: unexpected response shape');
    }

    final records = <T>[];
    for (final row in decoded) {
      if (row is! Map) continue;
      final doc = row['document'];
      if (doc is! Map) continue;
      final name = doc['name'] as String?;
      final rawFields = doc['fields'];
      if (name == null || rawFields is! Map) continue;
      final fields = _jsonMap(rawFields);

      final ref = _documentReferenceFromRestName(name);
      final data = _restFieldsToMap(fields);
      records.add(mapRecord(data, ref));
    }

    // ignore: avoid_print
    print('[WindowsFirestoreRest] ✓ $label (${records.length} docs)');
    return records;
  }

  /// jsonDecode returns nested [Map<dynamic, dynamic>]; normalize for schema casts.
  static Map<String, dynamic> _jsonMap(Map map) => Map<String, dynamic>.from(
        map.map((k, v) => MapEntry(k.toString(), _normalizeJsonValue(v))),
      );

  static dynamic _normalizeJsonValue(dynamic value) {
    if (value is Map) return _jsonMap(value);
    if (value is List) return value.map(_normalizeJsonValue).toList();
    return value;
  }

  static DocumentReference _documentReferenceFromRestName(String name) {
    const marker = '/documents/';
    final i = name.indexOf(marker);
    if (i < 0) {
      throw FormatException('Bad Firestore document name: $name');
    }
    final path = name.substring(i + marker.length);
    return FirebaseFirestore.instance.doc(path);
  }

  static Map<String, dynamic> _restFieldsToMap(Map<String, dynamic> fields) {
    final out = <String, dynamic>{};
    fields.forEach((key, value) {
      if (value is Map) {
        out[key] = _decodeRestValue(_jsonMap(value));
      }
    });
    return out;
  }

  static Map<String, dynamic> _encodeRestFields(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    data.forEach((key, value) {
      if (value == null) return;
      out[key] = _encodeRestValue(value);
    });
    return out;
  }

  static Map<String, dynamic> _encodeRestValue(dynamic value) {
    if (value is String) {
      return {'stringValue': value};
    }
    if (value is bool) {
      return {'booleanValue': value};
    }
    if (value is int) {
      return {'integerValue': value.toString()};
    }
    if (value is double) {
      return {'doubleValue': value};
    }
    if (value is DateTime) {
      return {'timestampValue': value.toUtc().toIso8601String()};
    }
    if (value is Timestamp) {
      return {'timestampValue': value.toDate().toUtc().toIso8601String()};
    }
    if (value is DocumentReference) {
      return {'referenceValue': '$_databaseRoot/${value.path}'};
    }
    if (value is GeoPoint) {
      return {
        'geoPointValue': {
          'latitude': value.latitude,
          'longitude': value.longitude,
        },
      };
    }
    if (value is List) {
      return {
        'arrayValue': {
          'values': value.map(_encodeRestValue).toList(),
        },
      };
    }
    if (value is Map) {
      final nested = <String, dynamic>{};
      value.forEach((k, v) {
        if (v != null) nested[k.toString()] = _encodeRestValue(v);
      });
      return {
        'mapValue': {'fields': nested},
      };
    }
    return {'stringValue': value.toString()};
  }

  static dynamic _decodeRestValue(Map<String, dynamic> value) {
    if (value.containsKey('stringValue')) {
      return value['stringValue'];
    }
    if (value.containsKey('booleanValue')) {
      return value['booleanValue'];
    }
    if (value.containsKey('integerValue')) {
      return int.tryParse(value['integerValue'].toString());
    }
    if (value.containsKey('doubleValue')) {
      return value['doubleValue'];
    }
    if (value.containsKey('timestampValue')) {
      return _parseRestTimestamp(value['timestampValue'] as String);
    }
    if (value.containsKey('referenceValue')) {
      return _documentReferenceFromRestName(value['referenceValue'] as String);
    }
    if (value.containsKey('arrayValue')) {
      final arr = value['arrayValue'];
      final values =
          (arr is Map ? arr['values'] as List<dynamic>? : null) ?? const [];
      return values
          .whereType<Map>()
          .map((entry) => _decodeRestValue(_jsonMap(entry)))
          .toList();
    }
    if (value.containsKey('mapValue')) {
      final mapValue = value['mapValue'];
      if (mapValue is! Map) return {};
      final rawFields = mapValue['fields'];
      if (rawFields is! Map) return {};
      return _restFieldsToMap(_jsonMap(rawFields));
    }
    if (value.containsKey('nullValue')) {
      return null;
    }
    return null;
  }

  /// Firestore REST timestamps are UTC. Parse explicitly so UI can call [DateTime.toLocal].
  static DateTime? _parseRestTimestamp(String raw) {
    if (raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    if (parsed.isUtc) return parsed;
    // Naive ISO (no Z) — treat as UTC per Firestore convention.
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }
}
