import '/backend/backend.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '/pages/desktop_chat/chat_controller.dart';
import '/auth/firebase_auth/auth_util.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ForwardChatPickerDialog extends StatefulWidget {
  const ForwardChatPickerDialog({super.key});

  @override
  State<ForwardChatPickerDialog> createState() =>
      _ForwardChatPickerDialogState();
}

class _ForwardChatPickerDialogState extends State<ForwardChatPickerDialog> {
  final ChatController chatController = Get.find<ChatController>();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 400,
        height: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Forward to...',
              style: FlutterFlowTheme.of(context).headlineSmall.override(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            // Search Bar
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: FlutterFlowTheme.of(context).secondaryBackground,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Obx(() {
                final chats = chatController.chats.where((chat) {
                  // Use the helper to properly resolve DM names
                  final title = _getChatTitle(chat).toLowerCase();
                  if (_searchQuery.isEmpty) return true;
                  return title.contains(_searchQuery.toLowerCase());
                }).toList();

                if (chats.isEmpty) {
                  return const Center(child: Text('No chats found'));
                }

                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    return ListTile(
                      leading: _buildChatAvatar(chat),
                      title: Text(
                        _getChatTitle(chat),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlutterFlowTheme.of(context).bodyLarge.override(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      onTap: () => Navigator.pop(context, chat),
                    );
                  },
                );
              }),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style:
                        TextStyle(color: FlutterFlowTheme.of(context).primary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatAvatar(ChatsRecord chat) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CachedNetworkImage(
          imageUrl: chat.chatImageUrl.isNotEmpty
              ? chat.chatImageUrl
              : 'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdiv.png?alt=media&token=85d5445a-3d2d-4dd5-879e-c4000b1fefd5',
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: Colors.grey[200]),
          errorWidget: (context, url, error) => const Icon(Icons.person),
        ),
      ),
    );
  }

  String _getChatTitle(ChatsRecord chat) {
    if (chat.title.isNotEmpty) return chat.title;
    
    // For DMs, find the other user's name
    if (chat.members.length == 2 && currentUserReference != null) {
      final otherUserId = chat.members
          .firstWhere((m) => m != currentUserReference, orElse: () => chat.members.first)
          .id;
      final cachedName = chatController.getCachedDisplayName(otherUserId);
      if (cachedName != null && cachedName.isNotEmpty) {
        return cachedName;
      }
      return 'Direct Message';
    }
    
    return 'Chat';
  }
}
