import '/backend/backend.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class ChatHistoryDetailWidget extends StatelessWidget {
  final List<dynamic> messages;
  final String title;

  const ChatHistoryDetailWidget({
    super.key,
    required this.messages,
    this.title = 'Chat History',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        title: Text(
          title,
          style: FlutterFlowTheme.of(context).headlineSmall.override(
                fontFamily: 'Inter',
                color: FlutterFlowTheme.of(context).primaryText,
              ),
        ),
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: FlutterFlowTheme.of(context).primaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final msg = messages[index];
          return _buildHistoryItem(context, msg);
        },
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, dynamic msg) {
    final senderName = msg['sender_name'] ?? 'Unknown';
    final senderPhoto = msg['sender_photo'];
    final content = msg['content'] ?? '';
    final type = msg['message_type'] ?? 'text';

    DateTime? createdAt;
    if (msg['created_at'] is Timestamp) {
      createdAt = (msg['created_at'] as Timestamp).toDate();
    } else if (msg['created_at'] is DateTime) {
      createdAt = msg['created_at'] as DateTime;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CachedNetworkImage(
                imageUrl: senderPhoto != null && senderPhoto.isNotEmpty
                    ? senderPhoto
                    : 'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdiv.png?alt=media&token=85d5445a-3d2d-4dd5-879e-c4000b1fefd5',
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: Colors.grey[200]),
                errorWidget: (context, url, error) => const Icon(Icons.person),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      senderName,
                      style: FlutterFlowTheme.of(context).bodyLarge.override(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (createdAt != null)
                      Text(
                        DateFormat('MMM d, h:mm a').format(createdAt),
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              fontFamily: 'Inter',
                              color: FlutterFlowTheme.of(context).secondaryText,
                            ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildContent(context, type, content, msg),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, String type, String content, dynamic msg) {
    if (type == 'image') {
      final imageUrl = msg['image'] ?? '';
      if (imageUrl.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: 200,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 200,
              height: 150,
              color: Colors.grey[200],
            ),
          ),
        );
      }
    } else if (type == 'video') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_fill,
                color: FlutterFlowTheme.of(context).primary),
            const SizedBox(width: 8),
            const Text('Video Message'),
          ],
        ),
      );
    } else if (type == 'file') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlutterFlowTheme.of(context).alternate),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file,
                color: FlutterFlowTheme.of(context).primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                content.isNotEmpty ? content : 'File attachment',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else if (type == 'audio' || type == 'voice') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic, color: FlutterFlowTheme.of(context).primary),
            const SizedBox(width: 8),
            const Text('Voice Message'),
          ],
        ),
      );
    }

    // Default to text
    return Text(
      content,
      style: FlutterFlowTheme.of(context).bodyMedium.override(
            fontFamily: 'Inter',
          ),
    );
  }
}
