import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

/// iOS-native Pinned Messages page — shows all pinned messages in a chat.
/// Tapping a message pops back and scrolls to that message in the chat thread.
class MobilePinnedMessagesWidget extends StatelessWidget {
  final ChatsRecord chatDoc;
  final void Function(String messageId)? onMessageTap;

  const MobilePinnedMessagesWidget({
    Key? key,
    required this.chatDoc,
    this.onMessageTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF2F2F7),
      appBar: CupertinoNavigationBar(
        backgroundColor: Color(0xFFF2F2F7),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
        middle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.pin_fill, size: 16, color: Color(0xFF007AFF)),
            SizedBox(width: 6),
            Text(
              'Pinned Messages',
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF000000),
              ),
            ),
          ],
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.chevron_left, size: 20, color: Color(0xFF007AFF)),
              Text(
                'Back',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontSize: 17,
                  color: Color(0xFF007AFF),
                ),
              ),
            ],
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<MessagesRecord>>(
          stream: queryMessagesRecord(
            parent: chatDoc.reference,
            queryBuilder: (q) => q.where('is_pinned', isEqualTo: true),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CupertinoActivityIndicator(radius: 14),
              );
            }

            final pinnedMessages = (snapshot.data ?? [])
              ..sort((a, b) {
                final aTime = a.createdAt;
                final bTime = b.createdAt;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime); // newest first
              });

            if (pinnedMessages.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              itemCount: pinnedMessages.length,
              itemBuilder: (context, index) {
                return _buildPinnedMessageCard(context, pinnedMessages[index]);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Color(0xFF007AFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.pin_slash,
              size: 36,
              color: Color(0xFF007AFF).withOpacity(0.5),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'No Pinned Messages',
            style: TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1D1F),
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Long-press a message and select "Pin" to pin it here for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                fontSize: 15,
                color: Color(0xFF8E8E93),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedMessageCard(BuildContext context, MessagesRecord msg) {
    final senderName = msg.senderName.isNotEmpty ? msg.senderName : 'Unknown';
    final content = msg.content.isNotEmpty
        ? msg.content
        : (msg.attachmentUrl.isNotEmpty
            ? '📎 Attachment'
            : (msg.image.isNotEmpty ? '🖼️ Image' : '💬 Message'));
    final timestamp = msg.createdAt;
    final timeStr = timestamp != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(timestamp)
        : '';

    // Check if current user is the sender
    final isMine = msg.senderRef == currentUserReference;

    return GestureDetector(
      onTap: () {
        if (onMessageTap != null) {
          Navigator.pop(context);
          onMessageTap!(msg.reference.id);
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: pin icon + sender name + timestamp
            Row(
              children: [
                Icon(
                  CupertinoIcons.pin_fill,
                  size: 12,
                  color: Color(0xFF007AFF),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isMine ? 'You' : senderName,
                    style: TextStyle(
                      fontFamily: 'SF Pro Text',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D1D1F),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            // Message content
            Text(
              content.length > 300 ? '${content.substring(0, 300)}...' : content,
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                fontSize: 15,
                color: Color(0xFF3C3C43),
                height: 1.4,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            // Image indicator
            if (msg.image.isNotEmpty || msg.images.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.photo, size: 14, color: Color(0xFF8E8E93)),
                    SizedBox(width: 4),
                    Text(
                      '${1 + msg.images.length} image(s)',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 13,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
            // Attachment indicator
            if (msg.attachmentUrl.isNotEmpty && msg.content.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.paperclip, size: 14, color: Color(0xFF8E8E93)),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        Uri.tryParse(msg.attachmentUrl)?.pathSegments.last ?? 'Attachment',
                        style: TextStyle(
                          fontFamily: 'SF Pro Text',
                          fontSize: 13,
                          color: Color(0xFF007AFF),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            // Tap hint
            if (onMessageTap != null)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Tap to view in chat',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 12,
                        color: Color(0xFF007AFF).withOpacity(0.6),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 12,
                      color: Color(0xFF007AFF).withOpacity(0.6),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
