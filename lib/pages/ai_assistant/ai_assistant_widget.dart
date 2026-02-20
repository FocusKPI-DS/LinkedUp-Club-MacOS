import 'package:flutter/material.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'ai_assistant_controller.dart';

class AIAssistantWidget extends StatefulWidget {
  const AIAssistantWidget({super.key});

  static String routeName = 'AIAssistant';
  static String routePath = '/aiAssistant';

  @override
  _AIAssistantWidgetState createState() => _AIAssistantWidgetState();
}

class _AIAssistantWidgetState extends State<AIAssistantWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AIAssistantController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(AIAssistantController());

    // Listen for typing changes to scroll
    ever(controller.isAITyping, (_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    Get.delete<AIAssistantController>();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    await controller.sendMessage(messageText);
    _scrollToBottom();
  }

  Future<void> _handleDeleteConversation(String conversationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.warning_rounded,
                      color: Color(0xFFDC2626), size: 32),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Delete Conversation?',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This will permanently delete this conversation and all its messages. This action cannot be undone.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280))),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Delete',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await controller.deleteConversation(conversationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Conversation deleted'),
              duration: Duration(seconds: 2)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        border: Border.all(color: const Color(0xFF4B5563)),
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
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LonaAI',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                SizedBox(height: 4),
                Text(
                  'Your intelligent community helper - ask about events, rules, or membership benefits.',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFFE5E7EB)),
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
        _buildConversationList(),
        Expanded(child: _buildChatPanel()),
      ],
    );
  }

  Widget _buildConversationList() {
    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        border: Border.all(color: const Color(0xFF4B5563)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Text('Recent Conversations',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                const Spacer(),
                GestureDetector(
                  onTap: () => controller.createNewConversation(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(color: Color(0xFF3B82F6)),
                    child: const Icon(Icons.add, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              final conversations = controller.conversations;
              final currentId = controller.currentConversationId
                  .value; // Track currentConversationId changes

              if (conversations.isEmpty) {
                return const Center(
                  child: Text('No conversations yet',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xFF9CA3AF))),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  final data = conversation.data() as Map<String, dynamic>;
                  final conversationTitle =
                      data['title'] as String? ?? 'New Chat';
                  final lastMessage = data['last_message'] as String? ?? '';
                  final lastMessageAt = data['last_message_at'] as Timestamp?;
                  final isPinned = data['is_pinned'] as bool? ?? false;
                  final isCurrentConversation = conversation.id == currentId;

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
                    onTap: () => controller.switchConversation(conversation.id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isCurrentConversation
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF4B5563),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isCurrentConversation
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF6B7280)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isPinned) ...[
                                Icon(Icons.push_pin,
                                    color: isCurrentConversation
                                        ? const Color(0xFFBFDBFE)
                                        : const Color(0xFF9CA3AF),
                                    size: 14),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  conversationTitle,
                                  style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'pin') {
                                    await controller.togglePinConversation(
                                        conversation.id, isPinned);
                                  } else if (value == 'delete') {
                                    await _handleDeleteConversation(
                                        conversation.id);
                                  } else if (value == 'archive') {
                                    await controller
                                        .archiveConversation(conversation.id);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'pin',
                                    child: Row(
                                      children: [
                                        Icon(
                                            isPinned
                                                ? Icons.push_pin_outlined
                                                : Icons.push_pin,
                                            color: const Color(0xFF374151),
                                            size: 18),
                                        const SizedBox(width: 12),
                                        Text(isPinned ? 'Unpin' : 'Pin',
                                            style: const TextStyle(
                                                fontFamily: 'Inter',
                                                color: Color(0xFF111827),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'archive',
                                    child: Row(
                                      children: [
                                        Icon(Icons.archive,
                                            color: Color(0xFF374151), size: 18),
                                        SizedBox(width: 12),
                                        Text('Archive',
                                            style: TextStyle(
                                                fontFamily: 'Inter',
                                                color: Color(0xFF111827),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete,
                                            color: Color(0xFFDC2626), size: 18),
                                        SizedBox(width: 12),
                                        Text('Delete',
                                            style: TextStyle(
                                                fontFamily: 'Inter',
                                                color: Color(0xFFDC2626),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                ],
                                icon: Icon(Icons.more_vert,
                                    color: isCurrentConversation
                                        ? const Color(0xFFBFDBFE)
                                        : const Color(0xFF9CA3AF),
                                    size: 18),
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lastMessage.isNotEmpty
                                ? (lastMessage.length > 50
                                    ? '${lastMessage.substring(0, 50)}...'
                                    : lastMessage)
                                : 'Start a new conversation',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: isCurrentConversation
                                    ? const Color(0xFFE5E7EB)
                                    : const Color(0xFFD1D5DB)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            timeAgo,
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                color: isCurrentConversation
                                    ? const Color(0xFFBFDBFE)
                                    : const Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Expanded(child: _buildMessagesList()),
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return Obx(() {
      final messages = controller.messages;
      final isTyping = controller.isAITyping.value;

      if (messages.isEmpty && !isTyping) {
        return _buildSuggestionBubbles();
      }

      return Column(
        children: [
          Expanded(
            child: ListView.builder(
              key: ValueKey('messages_${messages.length}'),
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final data = message.data() as Map<String, dynamic>;
                final senderType = data['sender_type'] as String? ?? 'user';
                final content = data['content'] as String? ?? '';

                return Padding(
                  key: ValueKey(message.id),
                  padding: const EdgeInsets.only(bottom: 16),
                  child: senderType == 'user'
                      ? _buildUserMessage(content)
                      : _buildAIMessage(content),
                );
              },
            ),
          ),
          if (isTyping)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _buildTypingIndicator(),
            ),
        ],
      );
    });
  }

  Widget _buildSuggestionBubbles() {
    final suggestions = [
      {
        'icon': Icons.event,
        'title': 'Events',
        'description': 'Tell me about upcoming events',
        'query': 'What upcoming events are happening?'
      },
      {
        'icon': Icons.policy,
        'title': 'Policies',
        'description': 'Learn about community policies',
        'query': 'What are the community policies?'
      },
      {
        'icon': Icons.rule,
        'title': 'Rules',
        'description': 'Understand community rules',
        'query': 'What are the community rules?'
      },
      {
        'icon': Icons.campaign,
        'title': 'Announcements',
        'description': 'Check recent announcements',
        'query': 'What are the latest announcements?'
      },
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 64, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 16),
            const Text(
              'Start a conversation with LonaAI',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask me anything about your community',
              style: TextStyle(
                  fontFamily: 'Inter', fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: suggestions.map((suggestion) {
                return GestureDetector(
                  onTap: () {
                    _messageController.text = suggestion['query'] as String;
                    _sendMessage();
                  },
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            suggestion['icon'] as IconData,
                            color: const Color(0xFF3B82F6),
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          suggestion['title'] as String,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          suggestion['description'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserMessage(String content) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(content,
                style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 14, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildAIMessage(String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
              'assets/images/67b27b2cda06e9c69e5d000615c1153f80b09576.png',
              width: 32,
              height: 32,
              fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(content,
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF1F2937))),
          ),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
              'assets/images/67b27b2cda06e9c69e5d000615c1153f80b09576.png',
              width: 32,
              height: 32,
              fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTypingDot(0),
              const SizedBox(width: 4),
              _buildTypingDot(1),
              const SizedBox(width: 4),
              _buildTypingDot(2),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        final delay = index * 0.2;
        final animValue = ((value + delay) % 1.0);
        final scale = 0.5 + (0.5 * (1 - (animValue - 0.5).abs() * 2));

        return Transform.scale(
          scale: scale,
          child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Color(0xFF6B7280), shape: BoxShape.circle)),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Start typing here...',
                  hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF9CA3AF),
                      fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF1F2937),
                    fontSize: 14),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6), shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
