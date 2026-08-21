import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';
import '/flutter_flow/flutter_flow_util.dart';

enum AIAssistantState { loading, success, error }

class AIAssistantController extends GetxController {
  final Rx<AIAssistantState> state = AIAssistantState.loading.obs;
  final RxList<FsDocSnapshot> conversations = <FsDocSnapshot>[].obs;
  final RxList<FsDocSnapshot> messages = <FsDocSnapshot>[].obs;
  final RxString currentConversationId = ''.obs;
  final RxBool isAITyping = false.obs;
  final RxString errorMessage = ''.obs;

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _conversationsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesSub;
  Timer? _conversationsPoll;
  Timer? _messagesPoll;

  DocumentReference get _conversationRef => FirebaseFirestore.instance
      .collection('ai_assistant_conversations')
      .doc(currentConversationId.value);

  Map<String, dynamic> _serverTimestampFields({
    required List<String> fields,
  }) {
    if (useWindowsFirestoreRest) {
      return {for (final f in fields) f: getCurrentTimestamp};
    }
    return {for (final f in fields) f: FieldValue.serverTimestamp()};
  }

  @override
  void onInit() {
    super.onInit();
    initializeConversation();
  }

  @override
  void onClose() {
    _conversationsSub?.cancel();
    _messagesSub?.cancel();
    _conversationsPoll?.cancel();
    _messagesPoll?.cancel();
    super.onClose();
  }

  Future<void> initializeConversation() async {
    if (currentConversationId.value.isEmpty) {
      try {
        final conversationId = await _createOrGetConversation();
        currentConversationId.value = conversationId;
        loadConversations();
        loadMessages();
      } catch (e) {
        print('Error initializing conversation: $e');
        currentConversationId.value = 'fallback_conversation';
        state.value = AIAssistantState.error;
        errorMessage.value = 'Error initializing conversation: $e';
      }
    }
  }

  Future<String> _createOrGetConversation() async {
    try {
      if (currentUserReference == null) {
        print('User not authenticated');
        return 'fallback_conversation';
      }

      final active = await fsQueryActiveAiConversation(currentUserReference!);
      if (active != null) {
        return active.id;
      }

      final docRef = await fsCreateRootDocument(
        collectionPath: 'ai_assistant_conversations',
        data: {
          'user_ref': currentUserReference,
          ..._serverTimestampFields(
            fields: ['created_at', 'updated_at', 'last_message_at'],
          ),
          'last_message': '',
          'message_count': 0,
          'is_active': true,
          'is_pinned': false,
          'title': 'New Chat',
          'context_data': {
            'workspace_id': null,
            'recent_events': [],
            'user_preferences': {},
          },
        },
      );

      return docRef.id;
    } catch (e) {
      print('Error creating conversation: $e');
      return 'fallback_conversation';
    }
  }

  void loadConversations() {
    if (currentUserReference == null) return;

    _conversationsSub?.cancel();
    _conversationsPoll?.cancel();

    if (useWindowsFirestoreRest) {
      _pollConversations();
      _conversationsPoll = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _pollConversations(),
      );
      return;
    }

    _conversationsSub = FirebaseFirestore.instance
        .collection('ai_assistant_conversations')
        .where('user_ref', isEqualTo: currentUserReference)
        .orderBy('is_pinned', descending: true)
        .orderBy('last_message_at', descending: true)
        .snapshots()
        .listen((snapshot) {
      conversations.value =
          snapshot.docs.map((d) => FsDocSnapshot.fromQuery(d)).toList();
      state.value = AIAssistantState.success;
    }, onError: (error) {
      print('Error loading conversations: $error');
      errorMessage.value = 'Error loading conversations: $error';
      state.value = AIAssistantState.error;
    });
  }

  Future<void> _pollConversations() async {
    if (currentUserReference == null) return;
    try {
      conversations.value =
          await fsQueryAiConversations(currentUserReference!);
      state.value = AIAssistantState.success;
    } catch (error) {
      print('Error loading conversations: $error');
      errorMessage.value = 'Error loading conversations: $error';
      state.value = AIAssistantState.error;
    }
  }

  void loadMessages() {
    if (currentConversationId.value.isEmpty ||
        currentConversationId.value == 'fallback_conversation') {
      return;
    }

    _messagesSub?.cancel();
    _messagesPoll?.cancel();

    if (useWindowsFirestoreRest) {
      _pollMessages();
      _messagesPoll = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _pollMessages(),
      );
      return;
    }

    _messagesSub = FirebaseFirestore.instance
        .collection('ai_assistant_conversations')
        .doc(currentConversationId.value)
        .collection('messages')
        .orderBy('created_at', descending: false)
        .snapshots()
        .listen((snapshot) {
      messages.value =
          snapshot.docs.map((d) => FsDocSnapshot.fromQuery(d)).toList();
    }, onError: (error) {
      print('Error loading messages: $error');
    });
  }

  Future<void> _pollMessages() async {
    if (currentConversationId.value.isEmpty ||
        currentConversationId.value == 'fallback_conversation') {
      return;
    }
    try {
      messages.value =
          await fsQueryAiMessages(currentConversationId.value);
    } catch (error) {
      print('Error loading messages: $error');
    }
  }

  void switchConversation(String conversationId) {
    currentConversationId.value = conversationId;
    loadMessages();
  }

  Future<void> createNewConversation() async {
    try {
      final docRef = await fsCreateRootDocument(
        collectionPath: 'ai_assistant_conversations',
        data: {
          'user_ref': currentUserReference,
          ..._serverTimestampFields(
            fields: ['created_at', 'updated_at', 'last_message_at'],
          ),
          'last_message': '',
          'message_count': 0,
          'is_active': true,
          'is_pinned': false,
          'title': 'New Chat',
          'context_data': {
            'workspace_id': null,
            'recent_events': [],
            'user_preferences': {},
          },
        },
      );

      currentConversationId.value = docRef.id;
      loadMessages();
    } catch (e) {
      print('Error creating new conversation: $e');
    }
  }

  String _generateConversationTitle(String firstMessage) {
    String cleaned = firstMessage.trim();
    if (cleaned.length <= 40) {
      return cleaned;
    }
    String truncated = cleaned.substring(0, 40);
    int lastSpace = truncated.lastIndexOf(' ');
    if (lastSpace > 20) {
      return '${truncated.substring(0, lastSpace)}...';
    }
    return '${truncated}...';
  }

  Future<void> sendMessage(String messageText) async {
    if (messageText.trim().isEmpty) return;

    try {
      final conversationData =
          await fsFetchDocumentData(_conversationRef);
      final messageCount = conversationData?['message_count'] as int? ?? 0;
      final currentTitle =
          conversationData?['title'] as String? ?? 'New Chat';

      await fsCreateAiMessage(
        conversationId: currentConversationId.value,
        data: {
          'sender_type': 'user',
          'content': messageText,
          'created_at': useWindowsFirestoreRest
              ? getCurrentTimestamp
              : FieldValue.serverTimestamp(),
          'message_type': 'text',
          'metadata': {},
        },
      );

      final updateData = <String, dynamic>{
        'last_message': messageText,
        ..._serverTimestampFields(
          fields: ['last_message_at', 'updated_at'],
        ),
      };

      if (messageCount == 0 || currentTitle == 'New Chat') {
        updateData['title'] = _generateConversationTitle(messageText);
      }

      await fsPatchDocument(_conversationRef, updateData);
      await fsIncrementDocumentField(_conversationRef, 'message_count', 1);

      isAITyping.value = true;
      await _callAIFunction(messageText);
      isAITyping.value = false;

      if (useWindowsFirestoreRest) {
        await _pollMessages();
        await _pollConversations();
      }
    } catch (e) {
      print('Error sending message: $e');
      isAITyping.value = false;
      errorMessage.value = 'Error sending message: $e';
    }
  }

  Future<void> _callAIFunction(String message) async {
    try {
      if (currentConversationId.value.isEmpty ||
          currentConversationId.value == 'fallback_conversation') {
        print('Cannot call AI function: Invalid conversation ID');
        return;
      }

      final chatRef =
          'ai_assistant_conversations/${currentConversationId.value}';
      final HttpsCallable callable =
          _functions.httpsCallable('processAIMention');

      await callable.call({
        'chatRef': chatRef,
        'messageContent': '@linkai $message',
        'senderName': 'User',
      });

      print('AI function called successfully');
    } catch (e) {
      print('Error calling AI function: $e');
    }
  }

  Future<void> togglePinConversation(
      String conversationId, bool currentPinStatus) async {
    try {
      await fsPatchDocument(
        FirebaseFirestore.instance
            .collection('ai_assistant_conversations')
            .doc(conversationId),
        {
          'is_pinned': !currentPinStatus,
          ..._serverTimestampFields(fields: ['updated_at']),
        },
      );
    } catch (e) {
      print('Error toggling pin: $e');
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await fsDeleteDocument(
        FirebaseFirestore.instance
            .collection('ai_assistant_conversations')
            .doc(conversationId),
      );

      if (currentConversationId.value == conversationId) {
        final newConversationId = await _createOrGetConversation();
        currentConversationId.value = newConversationId;
        loadMessages();
      }
    } catch (e) {
      print('Error deleting conversation: $e');
    }
  }

  Future<void> archiveConversation(String conversationId) async {
    try {
      await fsPatchDocument(
        FirebaseFirestore.instance
            .collection('ai_assistant_conversations')
            .doc(conversationId),
        {
          'is_active': false,
          ..._serverTimestampFields(fields: ['updated_at']),
        },
      );

      if (currentConversationId.value == conversationId) {
        final newConversationId = await _createOrGetConversation();
        currentConversationId.value = newConversationId;
        loadMessages();
      }
    } catch (e) {
      print('Error archiving conversation: $e');
    }
  }
}
