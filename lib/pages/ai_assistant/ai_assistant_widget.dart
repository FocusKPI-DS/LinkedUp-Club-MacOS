import 'package:flutter/material.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';

class AIAssistantWidget extends StatefulWidget {
  const AIAssistantWidget({Key? key}) : super(key: key);

  static String routeName = 'AIAssistant';
  static String routePath = '/aiAssistant';

  @override
  _AIAssistantWidgetState createState() => _AIAssistantWidgetState();
}

class _AIAssistantWidgetState extends State<AIAssistantWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _currentConversationId;
  bool _isLoading = false;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  @override
  void initState() {
    super.initState();
    _initializeConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeConversation() async {
    if (_currentConversationId == null) {
      try {
        _currentConversationId = await _createOrGetConversation();
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        print('Error initializing conversation: $e');
        // Set a fallback conversation ID to prevent infinite loading
        _currentConversationId = 'fallback_conversation';
        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  Future<String> _createOrGetConversation() async {
    try {
      // Check if user is authenticated
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

  Future<void> _createNewConversation() async {
    try {
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
        'context_data': {
          'workspace_id': null,
          'recent_events': [],
          'user_preferences': {}
        }
      });

      // Switch to the new conversation
      _currentConversationId = docRef.id;
      if (mounted) {
        setState(() {});
      }

      // Clear the message input
      _messageController.clear();

      // Send welcome message from AI
      _sendWelcomeMessage();
    } catch (e) {
      print('Error creating new conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating new conversation: $e')),
      );
    }
  }

  Future<void> _sendWelcomeMessage() async {
    try {
      // Show typing indicator
      _isLoading = true;
      if (mounted) {
        setState(() {});
      }

      // Wait 1 second for typing effect
      await Future.delayed(Duration(seconds: 1));

      // Add welcome message to Firestore
      await FirebaseFirestore.instance
          .collection('ai_assistant_conversations')
          .doc(_currentConversationId)
          .collection('messages')
          .add({
        'sender_type': 'ai',
        'content':
            'Hello! I\'m LinkAI, your community helper. Ask me about events, rules, or anything else!',
        'created_at': FieldValue.serverTimestamp(),
        'message_type': 'text',
        'ai_context': {
          'model_used': 'gpt-4o-mini',
          'tokens_used': 0,
          'response_time': 1000,
        },
        'metadata': {}
      });

      // Update conversation
      await FirebaseFirestore.instance
          .collection('ai_assistant_conversations')
          .doc(_currentConversationId)
          .update({
        'last_message':
            'Hello! I\'m LinkAI, your community helper. Ask me about events, rules, or anything else!',
        'last_message_at': FieldValue.serverTimestamp(),
        'message_count': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Hide loading indicator
      _isLoading = false;
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error sending welcome message: $e');
      _isLoading = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isLoading) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _isLoading = true;
    });

    try {
      // Add user message to Firestore
      await FirebaseFirestore.instance
          .collection('ai_assistant_conversations')
          .doc(_currentConversationId)
          .collection('messages')
          .add({
        'sender_type': 'user',
        'content': messageText,
        'created_at': FieldValue.serverTimestamp(),
        'message_type': 'text',
        'metadata': {}
      });

      // Update conversation
      await FirebaseFirestore.instance
          .collection('ai_assistant_conversations')
          .doc(_currentConversationId)
          .update({
        'last_message': messageText,
        'last_message_at': FieldValue.serverTimestamp(),
        'message_count': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Call your existing processAIMention function
      await _callAIFunction(messageText);
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _callAIFunction(String message) async {
    try {
      // Safety check: Ensure we have a valid conversation ID
      if (_currentConversationId == null ||
          _currentConversationId == 'fallback_conversation') {
        print('Cannot call AI function: Invalid conversation ID');
        return;
      }

      // Create a chat reference for the AI function
      final chatRef = 'ai_assistant_conversations/$_currentConversationId';

      final HttpsCallable callable =
          _functions.httpsCallable('processAIMention');
      final result = await callable.call({
        'chatRef': chatRef,
        'messageContent': '@linkai $message', // Add @linkai mention
        'senderName': 'User',
      });

      print('AI function called successfully');
      if (result.data != null && result.data['success'] == true) {
        print('AI response received successfully');
      }
    } catch (e) {
      print('Error calling AI function: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting AI response: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      body: Column(
        children: [
          // Header
          _buildHeader(),
          // Main Content
          Expanded(
            child: _currentConversationId != null &&
                    _currentConversationId != 'fallback_conversation'
                ? _buildMainContent()
                : _currentConversationId == 'fallback_conversation'
                    ? _buildFallbackContent()
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                FlutterFlowTheme.of(context).primary,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Initializing AI Assistant...',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Color(0xFF374151), // Matching chat navbar grey
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Color(0xFF4B5563)),
      ),
      child: Row(
        children: [
          // LinkAI Logo
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/67b27b2cda06e9c69e5d000615c1153f80b09576.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 16),
          // Title and Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LinkAI',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your intelligent community helper - ask about events, rules, or membership benefits.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFFE5E7EB),
                  ),
                ),
              ],
            ),
          ),
          // Notification Bell
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFFE5E7EB)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.notifications_outlined,
                    color: Color(0xFF6B7280),
                    size: 20,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          // Menu Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFFE5E7EB)),
            ),
            child: Icon(
              Icons.more_vert,
              color: Color(0xFF6B7280),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.smart_toy_rounded,
            size: 64,
            color: Color(0xFF3B82F6),
          ),
          SizedBox(height: 16),
          Text(
            'AI Assistant Ready!',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start chatting with LinkAI below',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 24),
          // Simple chat input for fallback
          Container(
            width: 400,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message here...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Row(
      children: [
        // Left Panel - Recent Conversations
        Container(
          width: 350,
          decoration: BoxDecoration(
            color: Color(0xFF374151), // Grey navbar as before
            borderRadius: BorderRadius.zero,
            border: Border.all(color: Color(0xFF4B5563)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(24),
                child: Row(
                  children: [
                    Text(
                      'Recent Conversations',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white, // White text for dark background
                      ),
                    ),
                    Spacer(),
                    GestureDetector(
                      onTap: _createNewConversation,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(0xFF3B82F6), // Balanced blue
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Search Bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(0xFF4B5563), // Grey search bar
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFF6B7280)),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search conversations...',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
              // Conversation Cards - Real Data from Firestore
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('ai_assistant_conversations')
                      .where('user_ref', isEqualTo: currentUserReference)
                      .orderBy('last_message_at', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    print('=== CONVERSATION STREAM DEBUG ===');
                    print('Connection State: ${snapshot.connectionState}');
                    print('Has Error: ${snapshot.hasError}');
                    print('Error: ${snapshot.error}');
                    print('Has Data: ${snapshot.hasData}');
                    print('Data Length: ${snapshot.data?.docs.length ?? 0}');
                    print('Current User Reference: $currentUserReference');
                    print('================================');

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      print('🚨 FIRESTORE ERROR: ${snapshot.error}');
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Color(0xFFEF4444),
                              size: 48,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Error loading conversations',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '${snapshot.error}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    final conversations = snapshot.data?.docs ?? [];

                    if (conversations.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              color: Color(0xFF9CA3AF),
                              size: 48,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No conversations yet',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Start chatting with LinkAI!',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        final data =
                            conversation.data() as Map<String, dynamic>;
                        final lastMessage =
                            data['last_message'] as String? ?? '';
                        final lastMessageAt =
                            data['last_message_at'] as Timestamp?;
                        final isActive = data['is_active'] as bool? ?? false;
                        final isCurrentConversation =
                            conversation.id == _currentConversationId;

                        // Format timestamp
                        String timeAgo = 'Just now';
                        if (lastMessageAt != null) {
                          final now = DateTime.now();
                          final messageTime = lastMessageAt.toDate();
                          final difference = now.difference(messageTime);

                          if (difference.inMinutes < 1) {
                            timeAgo = 'Just now';
                          } else if (difference.inMinutes < 60) {
                            timeAgo = '${difference.inMinutes}m ago';
                          } else if (difference.inHours < 24) {
                            timeAgo = '${difference.inHours}h ago';
                          } else {
                            timeAgo = '${difference.inDays}d ago';
                          }
                        }

                        return GestureDetector(
                          onTap: () {
                            _currentConversationId = conversation.id;
                            setState(() {});
                          },
                          child: Container(
                            margin: EdgeInsets.only(bottom: 12),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isCurrentConversation
                                  ? Color(0xFF3B82F6) // Blue for active
                                  : Color(0xFF4B5563), // Grey for inactive
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCurrentConversation
                                    ? Color(0xFF2563EB)
                                    : Color(0xFF6B7280),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lastMessage.isNotEmpty
                                      ? 'AI Assistant Chat'
                                      : 'New Conversation',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  lastMessage.isNotEmpty
                                      ? lastMessage.length > 50
                                          ? '${lastMessage.substring(0, 50)}...'
                                          : lastMessage
                                      : 'Start a new conversation',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: isCurrentConversation
                                        ? Color(0xFFE5E7EB)
                                        : Color(0xFFD1D5DB),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  timeAgo,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    color: isCurrentConversation
                                        ? Color(0xFFBFDBFE)
                                        : Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Right Panel - Main Chat Interface
        Expanded(
          child: Container(
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: Color(0xFFE5E7EB)),
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ai_assistant_conversations')
                  .doc(_currentConversationId)
                  .collection('messages')
                  .orderBy('created_at', descending: false)
                  .snapshots(),
              builder: (context, messageSnapshot) {
                final messages = messageSnapshot.data?.docs ?? [];

                return Column(
                  children: [
                    // Chat Messages Area
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (messageSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  FlutterFlowTheme.of(context).primary,
                                ),
                              ),
                            );
                          }

                          if (messageSnapshot.hasError) {
                            return Center(
                              child: Text(
                                  'Error loading messages: ${messageSnapshot.error}'),
                            );
                          }

                          if (messages.isEmpty) {
                            return Padding(
                              padding: EdgeInsets.all(24),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.asset(
                                      'assets/images/67b27b2cda06e9c69e5d000615c1153f80b09576.png',
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildTypingDot(0),
                                        SizedBox(width: 4),
                                        _buildTypingDot(1),
                                        SizedBox(width: 4),
                                        _buildTypingDot(2),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.all(24),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final data =
                                  message.data() as Map<String, dynamic>;
                              final senderType =
                                  data['sender_type'] as String? ?? 'user';
                              final content = data['content'] as String? ?? '';

                              return Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: senderType == 'user'
                                    ? _buildUserMessageWidget(content)
                                    : _buildAIMessageWidget(content),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    // Quick Action Buttons (only show for first message)
                    if (messages.length <= 1) _buildQuickActionButtons(),
                    // Chat Input Area
                    _buildChatInput(),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAIMessage() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/images/67b27b2cda06e9c69e5d000615c1153f80b09576.png',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'LinkAI',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Bot',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Hello! I\'m your AI-powered community helper. I can assist you with:',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              SizedBox(height: 12),
              // Feature Cards
              Row(
                children: [
                  Expanded(
                    child: _buildFeatureCard(
                      'Event Information',
                      'Upcoming events, schedules, locations',
                      Icons.calendar_today,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildFeatureCard(
                      'Rules & Policies',
                      'Community guidelines, procedures',
                      Icons.description,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildFeatureCard(
                      'Member Benefits',
                      'Perks, discounts, exclusive access',
                      Icons.star,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildFeatureCard(
                      'General Help',
                      'Any questions about our community',
                      Icons.help_outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserMessageWidget(String content) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: 300),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFF3B82F6), // Blue background like DesktopChatWidget
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            content,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Colors.white, // White text on blue background
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAIMessageWidget(String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/images/67b27b2cda06e9c69e5d000615c1153f80b09576.png',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Container(
            constraints: BoxConstraints(maxWidth: 400),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(
                  0xFFF3F4F6), // Light grey background like DesktopChatWidget
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              content,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF1F2937), // Dark text on light background
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(String title, String subtitle, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFF3F4F6), // Light grey background
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFE5E7EB)), // Light border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Color(0xFF3B82F6), // Blue icon
            size: 20,
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3B82F6), // Blue text
            ),
          ),
          SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: Color(0xFF6B7280), // Grey subtitle
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserMessage() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: 300),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'When\'s the next yoga class?',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAIResponse() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/images/67b27b2cda06e9c69e5d000615c1153f80b09576.png',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'LinkAI',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Great question! Here are the upcoming yoga classes:',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              SizedBox(height: 12),
              // Event Card
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.fitness_center,
                          color: Color(0xFF3B82F6),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Hatha Yoga Session',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        Spacer(),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Today',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildEventDetail('Location:', 'Studio Room A'),
                    SizedBox(height: 4),
                    _buildEventDetail('Instructor:', 'Sarah Chen'),
                    SizedBox(height: 4),
                    _buildEventDetail('Level:', 'Beginner-Friendly'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventDetail(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
        SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButtons() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          _buildQuickActionButton('Event Information', Icons.calendar_today),
          SizedBox(width: 8),
          _buildQuickActionButton('Rules & Policies', Icons.description),
          SizedBox(width: 8),
          _buildQuickActionButton('Member Benefits', Icons.star),
          SizedBox(width: 8),
          _buildQuickActionButton('General Help', Icons.help_outline),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String text, IconData icon) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // Send the quick action as a message
          _messageController.text = text;
          _sendMessage();
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0xFF3B82F6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: Color(0xFF3B82F6),
                size: 20,
              ),
              SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF3B82F6),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600),
      builder: (context, value, child) {
        final delay = index * 0.2;
        final animValue = ((value + delay) % 1.0);
        final scale = 0.5 + (0.5 * (1 - (animValue - 0.5).abs() * 2));

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Color(0xFF6B7280),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          // Add Button (like DesktopChatWidget)
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: Color(0xFFE5E7EB)),
            ),
            child: Icon(
              Icons.add,
              color: Color(0xFF6B7280),
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          // Text Input (like DesktopChatWidget)
          Expanded(
            child: Container(
              constraints: BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText:
                      _isLoading ? 'AI is thinking...' : 'Start typing here...',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF1F2937),
                  fontSize: 14,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: 12),
          // Send Button (like DesktopChatWidget)
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isLoading ? Color(0xFF9CA3AF) : Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
