import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';
import '/auth/firebase_auth/auth_util.dart';

enum AIAssistantState { loading, success, error }

class AIAssistantController extends GetxController {
  // Observable variables
  final Rx<AIAssistantState> state = AIAssistantState.loading.obs;
  final RxList<DocumentSnapshot> conversations = <DocumentSnapshot>[].obs;
  final RxList<DocumentSnapshot> messages = <DocumentSnapshot>[].obs;
  final RxString currentConversationId = ''.obs;
  final RxBool isAITyping = false.obs;
  final RxString errorMessage = ''.obs;

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  @override
  void onInit() {
    super.onInit();
    initializeConversation();
  }

  // Initialize conversation
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

  // Create or get existing conversation
  Future<String> _createOrGetConversation() async {
    try {
      if (currentUserReference == null) {
        print('User not authenticated');
        return 'fallback_conversation';
      }

      // Check if user already has an active conversation
      final querySnapshot = await FirebaseFirestore.instance
          .collection('ai_assistant_conversations')
          .where('user_ref', isEqualTo: currentUserReference)
          .where('is_active', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }

      // Create new conversation
      final docRef = await FirebaseFirestore.instance
          .collection('ai_assistant_conversations')
          .add({
        'user_ref': currentUserReference,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'last_message': '',
        'last_message_at': FieldValue.serverTimestamp(),
        'message_count': 0,
        'is_active': true,
        'is_pinned': false,
        'title': 'New Chat',
        'context_data': {
          'workspace_id': null,
          'recent_events': [],
          'user_preferences': {}
        }
      });

      return docRef.id;
    } catch (e) {
      print('Error creating conversation: $e');
      return 'fallback_conversation';
    }
  }

  // Load conversations with real-time updates
  void loadConversations() {
    if (currentUserReference == null) return;

    FirebaseFirestore.instance
        .collection('ai_assistant_conversations')
        .where('user_ref', isEqualTo: currentUserReference)
        .orderBy('is_pinned', descending: true)
        .orderBy('last_message_at', descending: true)
        .snapshots()
        .listen((snapshot) {
      conversations.value = snapshot.docs;
      state.value = AIAssistantState.success;
    }, onError: (error) {
      print('Error loading conversations: $error');
      errorMessage.value = 'Error loading conversations: $error';
      state.value = AIAssistantState.error;
    });
  }

  // Load messages for current conversation
  void loadMessages() {
    if (currentConversationId.value.isEmpty ||
        currentConversationId.value == 'fallback_conversation') {
      return;
    }

    FirebaseFirestore.instance
        .collection('ai_assistant_conversations')
        .doc(currentConversationId.value)
        .collection('messages')
        .orderBy('created_at', descending: false)
        .snapshots()
        .listen((snapshot) {
      messages.value = snapshot.docs;
    }, onError: (error) {
      print('Error loading messages: $error');
    });
  }

  // Switch conversation
  void switchConversation(String conversationId) {
    currentConversationId.value = conversationId;
    loadMessages();
  }

  // Create new conversation
  Future<void> createNewConversation() async {
    try {
      final docRef = await FirebaseFirestore.instance
          .collection('ai_assistant_conversations')
          .add({
        'user_ref': currentUserReference,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'last_message': '',
        'last_message_at': FieldValue.serverTimestamp(),
        'message_count': 0,
        'is_active': true,
        'is_pinned': false,
        'title': 'New Chat',
        'context_data': {
          'workspace_id': null,
          'recent_events': [],
          'user_preferences': {}
        }
      });

      currentConversationId.value = docRef.id;
      loadMessages();
    } catch (e) {
      print('Error creating new conversation: $e');
    }
  }

  // Generate conversation title
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
    return '$truncated...';
  }

  // Send message
  Future<void> sendMessage(String messageText) async {
    if (messageText.trim().isEmpty) return;

    try {
      // Get conversation data for title generation
      final conversationDoc = await FirebaseFirestore.instance
          .collection('ai_assistant_conversations')
          .doc(currentConversationId.value)
          .get();

      final conversationData = conversationDoc.data();
      final messageCount = conversationData?['message_count'] as int? ?? 0;
      final currentTitle = conversationData?['title'] as String? ?? 'New Chat';

      // Add user message
      await FirebaseFirestore.instance
          .collection('ai_assistant_conversations')
          .doc(currentConversationId.value)
          .collection('messages')
          .add({
        'sender_type': 'user',
        'content': messageText,
        'created_at': FieldValue.serverTimestamp(),
        'message_type': 'text',
        'metadata': {}
      });

      // Prepare update data
      Map<String, dynamic> updateData = {
        'last_message': messageText,
        'last_message_at': FieldValue.serverTimestamp(),
        'message_count': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Generate title from first message
      if (messageCount == 0 || currentTitle == 'New Chat') {
        updateData['title'] = _generateConversationTitle(messageText);
      }

      // Update conversation
      await FirebaseFirestore.instance
          .collection('ai_assistant_conversations')
          .doc(currentConversationId.value)
          .update(updateData);

      // Show typing indicator
      isAITyping.value = true;

      // Call AI function
      await _callAIFunction(messageText);

      // Hide typing indicator
      isAITyping.value = false;
    } catch (e) {
      print('Error sending message: $e');
      isAITyping.value = false;
      errorMessage.value = 'Error sending message: $e';
    }
  }

  // Call AI function
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

  // Pin/Unpin conversation
  Future<void> togglePinConversation(
      String conversationId, bool currentPinStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('ai_assistant_conversations')
          .doc(conversationId)
          .update({
        'is_pinned': !currentPinStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error toggling pin: $e');
    }
  }

  // Delete conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('ai_assistant_conversations')
          .doc(conversationId)
          .delete();

      // If deleted current conversation, create new one
      if (currentConversationId.value == conversationId) {
        final newConversationId = await _createOrGetConversation();
        currentConversationId.value = newConversationId;
        loadMessages();
      }
    } catch (e) {
      print('Error deleting conversation: $e');
    }
  }

  // Archive conversation
  Future<void> archiveConversation(String conversationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('ai_assistant_conversations')
          .doc(conversationId)
          .update({
        'is_active': false,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // If archived current conversation, create new one
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
