import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

/// iOS-native Group Files page — shows all file attachments shared in a group chat.
/// Files are sorted newest-first, with file type icons and expiration badges.
class MobileGroupFilesWidget extends StatelessWidget {
  final ChatsRecord chatDoc;

  const MobileGroupFilesWidget({
    Key? key,
    required this.chatDoc,
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
            Icon(CupertinoIcons.folder_fill, size: 16, color: Color(0xFF007AFF)),
            SizedBox(width: 6),
            Text(
              'Group Files',
              style: TextStyle(
                fontFamily: '.SF Pro Text',
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
                  fontFamily: '.SF Pro Text',
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
            queryBuilder: (q) => q.orderBy('created_at', descending: true),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CupertinoActivityIndicator(radius: 14),
              );
            }

            // Strict filter: must have attachment_url, exclude images/audio/video
            final fileMessages = (snapshot.data ?? []).where((msg) {
              if (msg.attachmentUrl.isEmpty) return false;
              if (msg.messageType == MessageType.image ||
                  msg.messageType == MessageType.voice ||
                  msg.messageType == MessageType.video) return false;
              if (msg.image.isNotEmpty || msg.images.isNotEmpty) return false;
              if (msg.audio.isNotEmpty || msg.video.isNotEmpty) return false;
              return true;
            }).toList();

            if (fileMessages.isEmpty) {
              return _buildEmptyState();
            }

            return Column(
              children: [
                // Count bar
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${fileMessages.length} file${fileMessages.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontFamily: '.SF Pro Text',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Files expire after 30 days',
                        style: TextStyle(
                          fontFamily: '.SF Pro Text',
                          fontSize: 12,
                          color: Color(0xFFAEAEB2),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    itemCount: fileMessages.length,
                    itemBuilder: (context, index) {
                      return _buildFileCard(context, fileMessages[index]);
                    },
                  ),
                ),
              ],
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
              CupertinoIcons.folder_open,
              size: 36,
              color: Color(0xFF007AFF).withOpacity(0.5),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'No Files Shared',
            style: TextStyle(
              fontFamily: '.SF Pro Text',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1D1F),
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Files shared in this group will appear here for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: '.SF Pro Text',
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

  Widget _buildFileCard(BuildContext context, MessagesRecord msg) {
    final senderName = msg.senderName.isNotEmpty ? msg.senderName : 'Unknown';
    final timestamp = msg.createdAt;
    final daysAgo = timestamp != null
        ? DateTime.now().difference(timestamp).inDays
        : 0;
    final daysAgoStr = daysAgo == 0
        ? 'Today'
        : (daysAgo == 1 ? 'Yesterday' : '$daysAgo days ago');
    final isExpired = daysAgo > 30;

    // Resolve file name
    final fileUrl = msg.attachmentUrl;
    String fileName;
    final storedFileName = msg.snapshotData['file_name'];
    if (storedFileName is String && storedFileName.trim().isNotEmpty) {
      fileName = storedFileName.trim();
    } else if (msg.content.isNotEmpty &&
        msg.content.contains('.') &&
        msg.content.length < 150 &&
        !msg.content.contains('/') &&
        msg.content.split(' ').length < 8) {
      fileName = msg.content;
    } else {
      // Extract from URL and strip timestamp prefix
      try {
        final decodedPath = Uri.decodeComponent(fileUrl);
        final match = RegExp(r'\/([^\/\?]+)\?').firstMatch(decodedPath);
        String raw = '';
        if (match != null) {
          raw = match.group(1)!;
        } else {
          final uri = Uri.parse(fileUrl);
          raw = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'file';
          if (raw.contains('/')) raw = raw.split('/').last;
          if (raw.contains('?')) raw = raw.split('?').first;
        }
        raw = Uri.decodeComponent(raw);
        // Strip leading timestamp prefix: "1775578299259_filename.ext" → "filename.ext"
        final stripped = raw.replaceFirst(RegExp(r'^\d{10,}_'), '');
        fileName = (stripped.isNotEmpty && stripped.contains('.'))
            ? stripped
            : (raw.isNotEmpty ? raw : 'File');
      } catch (_) {
        fileName = 'File';
      }
    }

    final ext = fileName.split('.').last.toLowerCase();
    IconData fileIcon;
    Color fileIconColor;
    if (['pdf'].contains(ext)) {
      fileIcon = CupertinoIcons.doc_fill;
      fileIconColor = Color(0xFFDC2626);
    } else if (['doc', 'docx'].contains(ext)) {
      fileIcon = CupertinoIcons.doc_text_fill;
      fileIconColor = Color(0xFF2563EB);
    } else if (['xls', 'xlsx', 'csv'].contains(ext)) {
      fileIcon = CupertinoIcons.table_fill;
      fileIconColor = Color(0xFF059669);
    } else if (['ppt', 'pptx'].contains(ext)) {
      fileIcon = CupertinoIcons.play_rectangle_fill;
      fileIconColor = Color(0xFFEA580C);
    } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      fileIcon = CupertinoIcons.archivebox_fill;
      fileIconColor = Color(0xFF7C3AED);
    } else if (['env', 'txt', 'json', 'yml', 'yaml', 'md', 'js', 'dart', 'py']
        .contains(ext)) {
      fileIcon = CupertinoIcons.chevron_left_slash_chevron_right;
      fileIconColor = Color(0xFF475569);
    } else {
      fileIcon = CupertinoIcons.doc_fill;
      fileIconColor = Color(0xFF6B7280);
    }

    return GestureDetector(
      onTap: isExpired
          ? null
          : () async {
              if (fileUrl.isNotEmpty) {
                final uri = Uri.parse(fileUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(14),
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
        child: Row(
          children: [
            // File type icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isExpired
                    ? Color(0xFFF2F2F7)
                    : fileIconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  fileIcon,
                  size: 22,
                  color: isExpired ? Color(0xFFD1D1D6) : fileIconColor,
                ),
              ),
            ),
            SizedBox(width: 14),
            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      fontFamily: '.SF Pro Text',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isExpired ? Color(0xFF8E8E93) : Color(0xFF1D1D1F),
                      decoration:
                          isExpired ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(CupertinoIcons.person, size: 12, color: Color(0xFFAEAEB2)),
                      SizedBox(width: 4),
                      Text(
                        senderName,
                        style: TextStyle(
                          fontFamily: '.SF Pro Text',
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(CupertinoIcons.clock, size: 12, color: Color(0xFFAEAEB2)),
                      SizedBox(width: 4),
                      Text(
                        daysAgoStr,
                        style: TextStyle(
                          fontFamily: '.SF Pro Text',
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            // Status badge
            if (isExpired)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFFECACA)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.xmark_circle, size: 12, color: Color(0xFFEF4444)),
                    SizedBox(width: 4),
                    Text(
                      'Expired',
                      style: TextStyle(
                        fontFamily: '.SF Pro Text',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.arrow_down_to_line, size: 12, color: Color(0xFF007AFF)),
                    SizedBox(width: 4),
                    Text(
                      'Open',
                      style: TextStyle(
                        fontFamily: '.SF Pro Text',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF007AFF),
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
}
