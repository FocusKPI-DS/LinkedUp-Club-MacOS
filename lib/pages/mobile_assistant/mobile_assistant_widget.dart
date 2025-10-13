import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';

class MobileAssistantWidget extends StatefulWidget {
  const MobileAssistantWidget({Key? key}) : super(key: key);

  static String routeName = 'MobileAssistant';
  static String routePath = '/mobileAssistant';

  @override
  _MobileAssistantWidgetState createState() => _MobileAssistantWidgetState();
}

class _MobileAssistantWidgetState extends State<MobileAssistantWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _currentConversationId;
  bool _isLoading = false;
  bool _isMenuOpen = false;
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main Content
          Column(
            children: [
              // iOS-style Header
              _buildIOSHeader(),
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
                                    Color(0xFF007AFF),
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Initializing AI Assistant...',
                                  style: TextStyle(
                                    fontFamily: 'System',
                                    fontSize: 16,
                                    color: Color(0xFF8E8E93),
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ],
          ),
          // Side Menu Overlay
          if (_isMenuOpen) _buildSideMenuOverlay(),
          // Side Menu
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: _isMenuOpen ? 0 : -MediaQuery.of(context).size.width * 0.8,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.8,
            child: _buildSideMenu(),
          ),
        ],
      ),
    );
  }

  Widget _buildIOSHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Menu Button
          GestureDetector(
            onTap: () {
              setState(() {
                _isMenuOpen = !_isMenuOpen;
              });
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.menu_rounded,
                color: Color(0xFF1D1D1F),
                size: 20,
              ),
            ),
          ),
          SizedBox(width: 12),
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
          SizedBox(width: 12),
          // Title and Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LinkAI',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your intelligent community helper',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 14,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackContent() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.smart_toy_rounded,
              size: 64,
              color: Color(0xFF007AFF),
            ),
            SizedBox(height: 16),
            Text(
              'AI Assistant Ready!',
              style: TextStyle(
                fontFamily: 'System',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D1D1F),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start chatting with LinkAI below',
              style: TextStyle(
                fontFamily: 'System',
                fontSize: 14,
                color: Color(0xFF8E8E93),
              ),
            ),
            SizedBox(height: 24),
            // Simple chat input for fallback
            Container(
              width: double.infinity,
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
                        hintStyle: TextStyle(
                          fontFamily: 'System',
                          color: Color(0xFF8E8E93),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                      ),
                      style: TextStyle(
                        fontFamily: 'System',
                        fontSize: 16,
                        color: Color(0xFF1D1D1F),
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
                        color: Color(0xFF007AFF),
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
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Quick Action Buttons (only show for first message)
        _buildQuickActionButtons(),
        // Chat Messages Area
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('ai_assistant_conversations')
                .doc(_currentConversationId)
                .collection('messages')
                .orderBy('created_at', descending: false)
                .snapshots(),
            builder: (context, messageSnapshot) {
              final messages = messageSnapshot.data?.docs ?? [];

              if (messageSnapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                  ),
                );
              }

              if (messageSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading messages: ${messageSnapshot.error}',
                    style: TextStyle(
                      fontFamily: 'System',
                      color: Color(0xFF8E8E93),
                    ),
                  ),
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
                          color: Color(0xFFF2F2F7),
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
                padding: EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final data = message.data() as Map<String, dynamic>;
                  final senderType = data['sender_type'] as String? ?? 'user';
                  final content = data['content'] as String? ?? '';

                  return Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: senderType == 'user'
                        ? _buildUserMessageWidget(content)
                        : _buildAIMessageWidget(content),
                  );
                },
              );
            },
          ),
        ),
        // Chat Input Area
        _buildChatInput(),
      ],
    );
  }

  Widget _buildUserMessageWidget(String content) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: 240),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFF007AFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            content,
            style: TextStyle(
              fontFamily: 'System',
              fontSize: 14,
              color: Colors.white,
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
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/images/67b27b2cda06e9c69e5d000615c1153f80b09576.png',
            width: 28,
            height: 28,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Container(
            constraints: BoxConstraints(maxWidth: 240),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              content,
              style: TextStyle(
                fontFamily: 'System',
                fontSize: 14,
                color: Color(0xFF1D1D1F),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButtons() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildQuickActionButton('Events', Icons.calendar_today),
            SizedBox(width: 8),
            _buildQuickActionButton('Rules', Icons.description),
            SizedBox(width: 8),
            _buildQuickActionButton('Benefits', Icons.star),
            SizedBox(width: 8),
            _buildQuickActionButton('Help', Icons.help_outline),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(String text, IconData icon) {
    return GestureDetector(
      onTap: () {
        // Send the quick action as a message
        _messageController.text = text;
        _sendMessage();
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Color(0xFF007AFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Color(0xFF007AFF),
              size: 16,
            ),
            SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontFamily: 'System',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF007AFF),
              ),
            ),
          ],
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
              color: Color(0xFF8E8E93),
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Text Input
          Expanded(
            child: Container(
              constraints: BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText:
                      _isLoading ? 'AI is thinking...' : 'Message LinkAI...',
                  hintStyle: TextStyle(
                    fontFamily: 'System',
                    color: Color(0xFF8E8E93),
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: TextStyle(
                  fontFamily: 'System',
                  color: Color(0xFF1D1D1F),
                  fontSize: 16,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: 12),
          // Send Button
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isLoading ? Color(0xFF8E8E93) : Color(0xFF007AFF),
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

  Widget _buildSideMenuOverlay() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isMenuOpen = false;
        });
      },
      child: Container(
        color: Colors.black.withOpacity(0.3),
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  Widget _buildSideMenu() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              color: Color(0xFFF2F2F7),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/67b27b2cda06e9c69e5d000615c1153f80b09576.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LinkAI',
                        style: TextStyle(
                          fontFamily: 'System',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                      Text(
                        'LinkAI',
                        style: TextStyle(
                          fontFamily: 'System',
                          fontSize: 14,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isMenuOpen = false;
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.close,
                      color: Color(0xFF1D1D1F),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // New Chat Button
          Padding(
            padding: EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () {
                _createNewConversation();
                setState(() {
                  _isMenuOpen = false;
                });
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'New Chat',
                      style: TextStyle(
                        fontFamily: 'System',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Conversations List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ai_assistant_conversations')
                  .where('user_ref', isEqualTo: currentUserReference)
                  .orderBy('last_message_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading conversations',
                      style: TextStyle(
                        fontFamily: 'System',
                        fontSize: 14,
                        color: Color(0xFF8E8E93),
                      ),
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
                          color: Color(0xFF8E8E93),
                          size: 48,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: TextStyle(
                            fontFamily: 'System',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start chatting with LinkAI!',
                          style: TextStyle(
                            fontFamily: 'System',
                            fontSize: 14,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    final data = conversation.data() as Map<String, dynamic>;
                    final lastMessage = data['last_message'] as String? ?? '';
                    final lastMessageAt = data['last_message_at'] as Timestamp?;
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
                        setState(() {
                          _isMenuOpen = false;
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.only(bottom: 8),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isCurrentConversation
                              ? Color(0xFFF2F2F7)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isCurrentConversation
                              ? Border.all(color: Color(0xFF007AFF), width: 1)
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lastMessage.isNotEmpty
                                  ? 'AI Assistant Chat'
                                  : 'New Conversation',
                              style: TextStyle(
                                fontFamily: 'System',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1D1D1F),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (lastMessage.isNotEmpty) ...[
                              SizedBox(height: 4),
                              Text(
                                lastMessage.length > 50
                                    ? '${lastMessage.substring(0, 50)}...'
                                    : lastMessage,
                                style: TextStyle(
                                  fontFamily: 'System',
                                  fontSize: 14,
                                  color: Color(0xFF8E8E93),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            SizedBox(height: 8),
                            Text(
                              timeAgo,
                              style: TextStyle(
                                fontFamily: 'System',
                                fontSize: 12,
                                color: Color(0xFF8E8E93),
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
    );
  }
}
