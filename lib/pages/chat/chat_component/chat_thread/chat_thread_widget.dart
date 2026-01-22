import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_audio_player.dart';
import '/flutter_flow/flutter_flow_expanded_image_view.dart';
import '/custom_code/widgets/video_message_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
// import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/chat/chat_component/p_d_f_view/p_d_f_view_widget.dart';
import '/pages/chat/chat_component/report_component/report_component_widget.dart';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import '/custom_code/actions/web_download_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aligned_dialog/aligned_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:page_transition/page_transition.dart';
// import 'package:provider/provider.dart';
import 'chat_thread_model.dart';
export 'chat_thread_model.dart';

class ChatThreadWidget extends StatefulWidget {
  const ChatThreadWidget({
    super.key,
    required this.message,
    required this.senderImage,
    required this.name,
    required this.chatRef,
    required this.userRef,
    required this.action,
    this.onMessageLongPress,
    this.onReplyToMessage,
    this.onScrollToMessage,
    this.onEditMessage,
    this.isHighlighted = false,
    this.isGroup = false,
  });

  final MessagesRecord? message;
  final String? senderImage;
  final String? name;
  final DocumentReference? chatRef;
  final DocumentReference? userRef;
  final Future Function()? action;
  final Function(MessagesRecord)? onMessageLongPress;
  final Function(MessagesRecord)? onReplyToMessage;
  final Function(String)? onScrollToMessage;
  final Function(MessagesRecord)? onEditMessage;
  final bool isHighlighted;
  final bool isGroup; // Show profile photos only in group chats

  @override
  State<ChatThreadWidget> createState() => _ChatThreadWidgetState();
}

class _ChatThreadWidgetState extends State<ChatThreadWidget> {
  late ChatThreadModel _model;
  final GlobalKey _menuIconKey = GlobalKey();
  String? _selectedReaction;
  final Set<String> _locallyRemovedReactions = <String>{};
  bool _isHoveredForMenu = false;
  bool _isMenuOpen = false;
  // Cache for file info results to prevent unnecessary rebuilds
  Map<String, dynamic>? _cachedFileInfo;
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChatThreadModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store ScaffoldMessenger reference for safe use after async operations
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    _model.maybeDispose();
    _scaffoldMessenger = null;
    super.dispose();
  }

  String _formatMessageTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'N/A';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(timestamp.year, timestamp.month, timestamp.day);

    // Format hour, minute, and period
    final hour = timestamp.hour == 0
        ? 12
        : (timestamp.hour > 12 ? timestamp.hour - 12 : timestamp.hour);
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour < 12 ? 'AM' : 'PM';
    final timeString = '$hour:$minute $period';

    // If same calendar day (today), show only time
    if (messageDate == today) {
      return timeString;
    } else {
      // Format as date and time (e.g., "Nov 21, 3:45 PM")
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final month = months[timestamp.month - 1];
      final day = timestamp.day;
      return '$month $day, $timeString';
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildFileAttachment(String attachmentUrl) {
    // Check static cache first
    if (_staticFileInfoCache.containsKey(attachmentUrl)) {
      final fileInfo = _staticFileInfoCache[attachmentUrl]!;
      return _buildFileAttachmentCard(fileInfo, attachmentUrl);
    }

    // If not cached, use FutureBuilder but ensure it only builds once
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(attachmentUrl),
      future: _getFileInfo(attachmentUrl),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            constraints: const BoxConstraints(maxWidth: 280.0),
            height: 70.0,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: FlutterFlowTheme.of(context).primary,
              ),
            ),
          );
        }

        final fileInfo = snapshot.data!;
        return _buildFileAttachmentCard(fileInfo, attachmentUrl);
      },
    );
  }

  Widget _buildFileAttachmentCard(
      Map<String, dynamic> fileInfo, String attachmentUrl) {
    final isPdf = fileInfo['isPdf'] == true;

    return GestureDetector(
      onTap: () async {
        if (isPdf) {
          await showDialog(
            context: context,
            builder: (dialogContext) {
              return Dialog(
                elevation: 0,
                insetPadding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                alignment: const AlignmentDirectional(0.0, 0.0)
                    .resolve(Directionality.of(context)),
                child: PDFViewWidget(
                  url: attachmentUrl,
                ),
              );
            },
          );
        } else {
          // Download file directly instead of opening in browser
          final fileName = fileInfo['fileName'] as String;
          await _downloadFile(attachmentUrl, fileName);
        }
      },
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 280.0,
        ),
        padding: EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48.0,
              height: 48.0,
              decoration: BoxDecoration(
                color: (fileInfo['iconColor'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Icon(
                fileInfo['fileIcon'] as IconData,
                color: fileInfo['iconColor'] as Color,
                size: 28.0,
              ),
            ),
            SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileInfo['fileName'] as String,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'Inter',
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.0),
                  Text(
                    (fileInfo['fileSize'] as String).isNotEmpty
                        ? '${fileInfo['fileType']} • ${fileInfo['fileSize']}'
                        : '${fileInfo['fileType']} File',
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          fontFamily: 'Inter',
                          fontSize: 12.0,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.0),
            GestureDetector(
              onTap: () async {
                final fileName = fileInfo['fileName'] as String;
                await _downloadFile(attachmentUrl, fileName);
              },
              child: Container(
                width: 36.0,
                height: 36.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).alternate,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.download_rounded,
                  color: FlutterFlowTheme.of(context).secondaryText,
                  size: 20.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Static cache shared across all widget instances
  static final Map<String, Map<String, dynamic>> _staticFileInfoCache = {};
  static final Map<String, Future<Map<String, dynamic>>>
      _staticFileInfoFutures = {};

  Future<Map<String, dynamic>> _getFileInfo(String fileUrl) async {
    // Return cached result if available
    if (_staticFileInfoCache.containsKey(fileUrl)) {
      return _staticFileInfoCache[fileUrl]!;
    }

    // Return cached future if already fetching
    if (_staticFileInfoFutures.containsKey(fileUrl)) {
      return _staticFileInfoFutures[fileUrl]!;
    }

    // Create and cache the future
    final future = _fetchFileInfo(fileUrl);
    _staticFileInfoFutures[fileUrl] = future;

    // Cache the result when it completes
    future.then((result) {
      _staticFileInfoCache[fileUrl] = result;
      _staticFileInfoFutures.remove(fileUrl);
    });

    return future;
  }

  Future<Map<String, dynamic>> _fetchFileInfo(String fileUrl) async {
    try {
      final uri = Uri.parse(fileUrl);

      // First, try to get the original file name from message content
      // When there's an attachment, content is likely the original filename (if no caption was sent)
      String fileName = 'file';
      final hasAttachment = widget.message?.attachmentUrl != null &&
          widget.message!.attachmentUrl.isNotEmpty;

      if (widget.message?.content != null &&
          widget.message!.content.isNotEmpty) {
        final content = widget.message!.content;
        // Check if content looks like a file name
        final hasExtension = content.contains('.');
        final noPathSeparators =
            !content.contains('/') && !content.contains('\\');
        final notStoragePath =
            !content.contains('users/') && !content.contains('uploads/');
        final reasonableLength = content.length < 200 && content.length > 0;

        // If there's an attachment, be more lenient - content is likely the filename
        // Allow spaces in filenames (e.g., "test data.csv", "test_data.csv")
        // Exclude if it looks like a full sentence (too many words or too long)
        final wordCount = content.split(' ').length;
        final looksLikeFilename = hasExtension &&
            noPathSeparators &&
            notStoragePath &&
            reasonableLength &&
            // If there's an attachment, prioritize treating content as filename
            // unless it's clearly a sentence (many words or very long)
            (hasAttachment
                ? (content.length < 150 && wordCount < 8)
                : (content.length < 100 && wordCount < 5));

        if (looksLikeFilename) {
          fileName = content;
        } else {
          // If content is not a file name, extract from URL
          final pathSegments = uri.pathSegments;
          if (pathSegments.isNotEmpty) {
            final lastSegment = pathSegments.last.split('?').first;
            // If it's a Firebase Storage path, try to extract just the filename part
            // Format: users/.../uploads/timestamp.ext -> extract timestamp.ext
            if (lastSegment.contains('/')) {
              fileName = lastSegment.split('/').last;
            } else {
              fileName = lastSegment;
            }
          } else {
            fileName = 'file';
          }
        }
      } else {
        // Extract from URL if no content
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          final lastSegment = pathSegments.last.split('?').first;
          // If it's a Firebase Storage path, try to extract just the filename part
          if (lastSegment.contains('/')) {
            fileName = lastSegment.split('/').last;
          } else {
            fileName = lastSegment;
          }
        } else {
          fileName = 'file';
        }
      }

      final extension =
          fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

      IconData fileIcon;
      String fileType;
      Color iconColor;

      switch (extension) {
        case 'pdf':
          fileIcon = Icons.picture_as_pdf;
          fileType = 'PDF';
          iconColor = Colors.red;
          break;
        case 'csv':
        case 'xls':
        case 'xlsx':
          fileIcon = Icons.table_chart;
          fileType = extension.toUpperCase();
          iconColor = Colors.green;
          break;
        case 'doc':
        case 'docx':
          fileIcon = Icons.description;
          fileType = 'DOC';
          iconColor = Colors.blue;
          break;
        case 'txt':
          fileIcon = Icons.text_snippet;
          fileType = 'TXT';
          iconColor = Colors.grey;
          break;
        case 'zip':
        case 'rar':
        case '7z':
          fileIcon = Icons.folder_zip;
          fileType = extension.toUpperCase();
          iconColor = Colors.orange;
          break;
        case 'ppt':
        case 'pptx':
          fileIcon = Icons.slideshow;
          fileType = 'PPT';
          iconColor = Colors.orange;
          break;
        default:
          fileIcon = Icons.insert_drive_file;
          fileType = extension.isNotEmpty ? extension.toUpperCase() : 'FILE';
          iconColor = FlutterFlowTheme.of(context).primary;
      }

      // Try to get file size
      String fileSizeText = '';
      try {
        final response = await http.head(uri).timeout(Duration(seconds: 3));
        final contentLength = response.headers['content-length'];
        if (contentLength != null) {
          final size = int.tryParse(contentLength) ?? 0;
          if (size > 0) {
            if (size < 1024) {
              fileSizeText = '$size B';
            } else if (size < 1024 * 1024) {
              fileSizeText = '${(size / 1024).toStringAsFixed(1)} KB';
            } else {
              fileSizeText = '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
            }
          }
        }
      } catch (e) {
        // If we can't get file size, just show file type
      }

      return {
        'fileName': fileName,
        'fileType': fileType,
        'fileSize': fileSizeText,
        'fileIcon': fileIcon,
        'iconColor': iconColor,
        'isPdf': extension == 'pdf',
      };
    } catch (e) {
      return {
        'fileName': 'file',
        'fileType': 'FILE',
        'fileSize': '',
        'fileIcon': Icons.insert_drive_file,
        'iconColor': FlutterFlowTheme.of(context).primary,
        'isPdf': false,
      };
    }
  }

  /// Check if content contains only emojis (no regular text)
  bool _containsOnlyEmojis(String? content) {
    if (content == null || content.trim().isEmpty) return false;

    // Remove whitespace and check if all characters are emojis
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;

    // Regex to match emojis and emoji-related characters
    // This includes emojis, variation selectors, zero-width joiners, etc.
    final emojiRegex = RegExp(
      r'^[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{200D}\u{20E3}\u{FE0F}\s]*$',
      unicode: true,
    );

    // Check if the content matches emoji pattern and has at least one emoji
    final hasEmoji = RegExp(
      r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}]',
      unicode: true,
    ).hasMatch(trimmed);

    return hasEmoji && emojiRegex.hasMatch(trimmed);
  }

  Future<void> _copyContentIfAny() async {
    final text = widget.message?.content.trim();
    if (text == null || text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied to clipboard',
          style: GoogleFonts.inter(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            fontWeight: FontWeight.w500,
          ),
        ),
        duration: const Duration(milliseconds: 1600),
        backgroundColor: FlutterFlowTheme.of(context).secondaryText,
      ),
    );
  }

  Future<void> _openReportDialog() async {
    if (widget.message == null ||
        widget.chatRef == null ||
        widget.userRef == null) return;
    await showAlignedDialog(
      context: context,
      isGlobal: false,
      avoidOverflow: false,
      targetAnchor: const AlignmentDirectional(0.0, 0.0)
          .resolve(Directionality.of(context)),
      followerAnchor: const AlignmentDirectional(0.0, 0.0)
          .resolve(Directionality.of(context)),
      builder: (dialogContext) {
        return Material(
          color: Colors.transparent,
          child: ReportComponentWidget(
            messageRef: widget.message!,
            chatRef: widget.chatRef!,
            reportedRef: widget.userRef!,
          ),
        );
      },
    );
  }

  Future<void> _unsendMessage() async {
    if (widget.message == null || widget.chatRef == null) return;

    // Check if the message was sent by the current user
    if (widget.message!.senderRef != currentUserReference) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You can only unsend your own messages',
            style: GoogleFonts.inter(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              fontWeight: FontWeight.w500,
            ),
          ),
          duration: const Duration(milliseconds: 2000),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        title: Text(
          'Unsend Message',
          style: FlutterFlowTheme.of(context).headlineSmall.override(
                color: FlutterFlowTheme.of(context).primaryText,
              ),
        ),
        content: Text(
          'Are you sure you want to unsend this message? This action cannot be undone.',
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    color: FlutterFlowTheme.of(context).secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Unsend',
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    color: FlutterFlowTheme.of(context).error,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete the message
        await widget.message!.reference.delete();

        // Update chat's last message if this was the last message
        final chatDoc = await widget.chatRef!.get();
        if (chatDoc.exists) {
          final chatData = chatDoc.data() as Map<String, dynamic>;
          final lastMessageSent =
              chatData['last_message_sent'] as DocumentReference?;

          // If this was the last message, update chat
          if (lastMessageSent == currentUserReference) {
            // Get the previous message
            final previousMessages = await widget.chatRef!
                .collection('messages')
                .orderBy('created_at', descending: true)
                .limit(1)
                .get();

            if (previousMessages.docs.isNotEmpty) {
              final previousMessage = previousMessages.docs.first;
              final previousData = previousMessage.data();

              // Update chat with previous message info
              await widget.chatRef!.update({
                'last_message': previousData['content'] ?? '',
                'last_message_at': previousData['created_at'],
                'last_message_sent': previousData['sender_ref'],
                'last_message_type': previousData['message_type'],
              });
            } else {
              // No previous messages, reset chat
              await widget.chatRef!.update({
                'last_message': '',
                'last_message_at': getCurrentTimestamp,
                'last_message_sent': currentUserReference,
                'last_message_type': MessageType.text,
              });
            }
          }
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Message unsent successfully',
                style: GoogleFonts.inter(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  fontWeight: FontWeight.w500,
                ),
              ),
              duration: const Duration(milliseconds: 2000),
              backgroundColor: FlutterFlowTheme.of(context).success,
            ),
          );
        }
      } catch (e) {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to unsend message: $e',
                style: GoogleFonts.inter(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  fontWeight: FontWeight.w500,
                ),
              ),
              duration: const Duration(milliseconds: 3000),
              backgroundColor: FlutterFlowTheme.of(context).error,
            ),
          );
        }
      }
    }
  }

  Future<void> _replyToMessage() async {
    if (widget.message == null) return;

    // Call the parent callback to handle reply
    widget.onReplyToMessage?.call(widget.message!);
  }

  Future<void> _editMessage() async {
    if (widget.message == null) return;

    // Call the parent callback to handle edit
    widget.onEditMessage?.call(widget.message!);
  }

  void _scrollToRepliedMessage() {
    if (widget.message?.replyTo != null && widget.message!.replyTo.isNotEmpty) {
      widget.onScrollToMessage?.call(widget.message!.replyTo);
    }
  }

  // Platform-specific dropdown menu - WhatsApp style for macOS, iOS native style for iOS
  Widget _messageMenuButton() {
    return PopupMenuButton<_MsgAction>(
      tooltip: 'Message options',
      padding: EdgeInsets.zero,
      elevation: (!kIsWeb && Platform.isIOS) ? 8 : 6,
      position: PopupMenuPosition.under,
      offset: Offset(0, (!kIsWeb && Platform.isIOS) ? 16 : 12),
      constraints: BoxConstraints(
        minWidth: (!kIsWeb && Platform.isIOS) ? 120 : 100,
      ),
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular((!kIsWeb && Platform.isIOS) ? 12 : 10),
      ),
      color: (!kIsWeb && Platform.isIOS) ? Colors.white : Colors.black,
      onOpened: () {
        if (!kIsWeb && Platform.isIOS) {
          HapticFeedback.mediumImpact();
        }
        setState(() => _isMenuOpen = true);
      },
      onCanceled: () => setState(() => _isMenuOpen = false),
      icon: KeyedSubtree(
        key: _menuIconKey,
        child: Container(
          decoration: BoxDecoration(
            color: (!kIsWeb && Platform.isIOS)
                ? Colors.black.withOpacity(0.1)
                : const Color.fromARGB(255, 242, 239, 239).withOpacity(0.04),
            shape: BoxShape.circle,
          ),
          padding: EdgeInsets.all((!kIsWeb && Platform.isIOS) ? 6 : 4),
          child: Icon(
            (!kIsWeb && Platform.isIOS)
                ? Icons.more_vert_rounded // iOS style: vertical dots
                : Icons.keyboard_arrow_down_rounded, // macOS/Web style: arrow
            size: (!kIsWeb && Platform.isIOS) ? 16 : 12,
            color: (!kIsWeb && Platform.isIOS)
                ? Colors.black54
                : Color(0xFF4B5563),
          ),
        ),
      ),
      onSelected: (value) async {
        if (!kIsWeb && Platform.isIOS) {
          HapticFeedback.lightImpact();
        }
        setState(() => _isMenuOpen = false);
        switch (value) {
          case _MsgAction.react:
            await actions.closekeyboard();
            await widget.action?.call();
            // ignore: avoid_print
            print('React button clicked');
            await _showEmojiMenu();
            break;
          case _MsgAction.copy:
            await _copyContentIfAny();
            break;
          case _MsgAction.report:
            await _openReportDialog();
            break;
          case _MsgAction.unsend:
            await _unsendMessage();
            break;
          case _MsgAction.reply:
            await _replyToMessage();
            break;
          case _MsgAction.edit:
            await _editMessage();
            break;
          case _MsgAction.save:
            await _saveImage();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _MsgAction.react,
          child: _MenuRow(
            icon: Icons.emoji_emotions_rounded,
            label: 'React',
            textColor:
                (!kIsWeb && Platform.isIOS) ? Colors.black : Colors.white,
          ),
        ),
        PopupMenuItem(
          value: _MsgAction.copy,
          child: _MenuRow(
            icon: Icons.copy_rounded,
            label: 'Copy',
            textColor:
                (!kIsWeb && Platform.isIOS) ? Colors.black : Colors.white,
          ),
        ),
        PopupMenuItem(
          value: _MsgAction.report,
          child: _MenuRow(
            icon: Icons.report_gmailerrorred_rounded,
            label: 'Report',
            textColor:
                (!kIsWeb && Platform.isIOS) ? Colors.black : Colors.white,
          ),
        ),
        PopupMenuItem(
          value: _MsgAction.reply,
          child: _MenuRow(
            icon: Icons.reply_rounded,
            label: 'Reply',
            textColor:
                (!kIsWeb && Platform.isIOS) ? Colors.black : Colors.white,
          ),
        ),
        // Show Save option for messages with images (single or multiple)
        if ((widget.message?.image != null &&
                widget.message!.image.isNotEmpty) ||
            (widget.message?.images != null &&
                widget.message!.images.isNotEmpty)) ...[
          PopupMenuItem(
            value: _MsgAction.save,
            child: _MenuRow(
              icon: Icons.download_rounded,
              label: 'Save',
              textColor:
                  (!kIsWeb && Platform.isIOS) ? Colors.black : Colors.white,
            ),
          ),
        ],
        // Only show edit and unsend options for messages sent by current user
        if (widget.message?.senderRef == currentUserReference) ...[
          PopupMenuItem(
            value: _MsgAction.edit,
            child: _MenuRow(
              icon: Icons.edit_rounded,
              label: 'Edit',
              textColor:
                  (!kIsWeb && Platform.isIOS) ? Colors.black : Colors.white,
            ),
          ),
          PopupMenuItem(
            value: _MsgAction.unsend,
            child: _MenuRow(
              icon: Icons.undo_rounded,
              label: 'Unsend',
              textColor:
                  (!kIsWeb && Platform.isIOS) ? Colors.black : Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showEmojiMenu() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.45,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Add Reaction',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: isDark ? Colors.white38 : Colors.black26,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            // Emoji Picker - Full featured
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                    bottom: 20.0, left: 8.0), // Add bottom padding to move buttons up, left padding for search button
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    Navigator.pop(context, emoji.emoji);
                  },
                  config: Config(
                  height: MediaQuery.of(context).size.height * 0.35,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    emojiSizeMax: 28,
                    verticalSpacing: 0,
                    horizontalSpacing: 0,
                    gridPadding: EdgeInsets.zero,
                    recentsLimit: 28,
                    replaceEmojiOnLimitExceed: true,
                    noRecents: Text(
                      'No Recents',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    loadingIndicator: const Center(
                      child: CupertinoActivityIndicator(),
                    ),
                    buttonMode: ButtonMode.CUPERTINO,
                    backgroundColor:
                        isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  ),
                  skinToneConfig: const SkinToneConfig(
                    enabled: true,
                    dialogBackgroundColor: Colors.white,
                    indicatorColor: Colors.grey,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    initCategory: Category.RECENT,
                    backgroundColor:
                        isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    indicatorColor: FlutterFlowTheme.of(context).primary,
                    iconColor: isDark ? Colors.white54 : Colors.black45,
                    iconColorSelected: FlutterFlowTheme.of(context).primary,
                    categoryIcons: const CategoryIcons(
                      recentIcon: CupertinoIcons.clock,
                      smileyIcon: CupertinoIcons.smiley,
                      animalIcon: CupertinoIcons.tortoise,
                      foodIcon: CupertinoIcons.cart,
                      activityIcon: CupertinoIcons.sportscourt,
                      travelIcon: CupertinoIcons.car,
                      objectIcon: CupertinoIcons.lightbulb,
                      symbolIcon: CupertinoIcons.heart,
                      flagIcon: CupertinoIcons.flag,
                    ),
                  ),
                  bottomActionBarConfig: BottomActionBarConfig(
                    backgroundColor:
                        isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    buttonColor: isDark ? Colors.white54 : Colors.black45,
                    buttonIconColor: isDark ? Colors.white : Colors.black87,
                    showBackspaceButton: false,
                    showSearchViewButton: true,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF2F2F7),
                    buttonIconColor: isDark ? Colors.white54 : Colors.black54,
                    hintText: 'Search emoji...',
                  ),
                ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (selected != null && selected.isNotEmpty) {
      setState(() {
        _selectedReaction = selected;
        _locallyRemovedReactions.remove(selected);
      });
      await _saveReaction(selected);
    }
  }

  Future<void> _saveReaction(String emoji) async {
    try {
      final userId = currentUserUid;
      final msgRef = widget.message?.reference;
      if (userId.isEmpty || msgRef == null) return;
      if (mounted) {
        setState(() {
          _locallyRemovedReactions.remove(emoji);
        });
      }
      await msgRef.update({
        'reactions_by_user.$userId': FieldValue.arrayUnion([emoji])
      });
    } catch (_) {
      // no-op: best effort
    }
  }

  // Wrap a bubble in a Stack and pin the menu in its top-right corner.
  // Reactions badge overlaps the bottom of the bubble (WhatsApp style)
  Widget _withMessageMenu({required Widget bubble}) {
    final reactionsBadge = _buildReactionsBadge();
    final bool isSentByMe = widget.message?.senderRef == currentUserReference;

    if (!kIsWeb && Platform.isIOS) {
      // iOS: Call parent callback for fixed top menu
      return GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          widget.onMessageLongPress?.call(widget.message!);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Add bottom padding to make room for reaction badge
            Padding(
              padding: EdgeInsets.only(
                bottom: reactionsBadge != null ? 10 : 0,
              ),
              child: bubble,
            ),
            // Reactions badge at OPPOSITE corner to avoid timestamp
            // Received messages: reaction on RIGHT, Sent messages: reaction on LEFT
            if (reactionsBadge != null)
              Positioned(
                bottom: -15,
                right: isSentByMe ? null : -4,
                left: isSentByMe ? -4 : null,
                child: reactionsBadge,
              ),
          ],
        ),
      );
    } else {
      // macOS: Use hover detection with dropdown
      return MouseRegion(
        onEnter: (_) => setState(() => _isHoveredForMenu = true),
        onExit: (_) => setState(() => _isHoveredForMenu = false),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Add bottom padding to make room for reaction badge
            Padding(
              padding: EdgeInsets.only(
                bottom: reactionsBadge != null ? 10 : 0,
              ),
              child: bubble,
            ),
            if (_isHoveredForMenu || _isMenuOpen)
              Positioned(
                top: -4,
                right: -5,
                child: _messageMenuButton(),
              ),
            // Reactions badge at OPPOSITE corner to avoid timestamp
            // Received messages: reaction on RIGHT, Sent messages: reaction on LEFT
            if (reactionsBadge != null)
              Positioned(
                bottom: 0,
                right: isSentByMe ? null : -4,
                left: isSentByMe ? -4 : null,
                child: reactionsBadge,
              ),
          ],
        ),
      );
    }
  }

  Widget? _buildReactionsBadge() {
    // Merge persisted reactions with optimistic local selection
    final Map<String, List<String>> byUser = Map<String, List<String>>.from(
        widget.message?.reactionsByUser ?? const {});
    final userId = currentUserUid;
    // Remove any emojis the user has just removed locally
    if (userId.isNotEmpty && byUser.containsKey(userId)) {
      byUser[userId] = byUser[userId]!
          .where((e) => !_locallyRemovedReactions.contains(e))
          .toList();
    }
    // Add optimistic selection if any (and not marked removed)
    if (_selectedReaction != null &&
        _selectedReaction!.isNotEmpty &&
        userId.isNotEmpty &&
        !_locallyRemovedReactions.contains(_selectedReaction)) {
      final existing = byUser[userId] ?? <String>[];
      if (!existing.contains(_selectedReaction)) {
        byUser[userId] = [...existing, _selectedReaction!];
      }
    }

    if (byUser.isEmpty) return null;

    final Map<String, int> counts = <String, int>{};
    final Map<String, List<String>> emojiToUserIds = <String, List<String>>{};
    byUser.forEach((uid, list) {
      for (final e in list) {
        final em = e.trim();
        if (em.isEmpty) continue;
        counts[em] = (counts[em] ?? 0) + 1;
        final arr = emojiToUserIds.putIfAbsent(em, () => <String>[]);
        if (!arr.contains(uid)) arr.add(uid);
      }
    });
    if (counts.isEmpty) return null;

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // WhatsApp-style reaction badge - clean, no border
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2C2C2E).withOpacity(0.9)
            : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            Builder(builder: (context) {
              final emoji = entries[i].key;
              final count = entries[i].value;
              final uids = emojiToUserIds[emoji] ?? const <String>[];
              return FutureBuilder<String>(
                future: _formatUsernames(uids),
                builder: (context, snapshot) {
                  final message =
                      '${emoji} reacted by: ' + (snapshot.data ?? '…');
                  return Tooltip(
                    message: message,
                    waitDuration: const Duration(milliseconds: 250),
                    child: _ReactionChip(
                      emoji: emoji,
                      count: count,
                      onTap: _removeReaction,
                    ),
                  );
                },
              );
            }),
            if (i != entries.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  Future<void> _removeReaction(String emoji) async {
    try {
      final userId = currentUserUid;
      final msgRef = widget.message?.reference;
      if (userId.isEmpty || msgRef == null) return;
      // Optimistic UI update first
      if (mounted) {
        setState(() {
          _locallyRemovedReactions.add(emoji);
          if (_selectedReaction == emoji) {
            _selectedReaction = null;
          }
        });
      }
      // Persist
      await msgRef.update({
        'reactions_by_user.$userId': FieldValue.arrayRemove([emoji])
      });
    } catch (_) {
      // no-op
    }
  }

  Future<String> _formatUsernames(List<String> userIds) async {
    if (userIds.isEmpty) return '';
    try {
      final futures = userIds.map((uid) async {
        final snap = await UsersRecord.collection
            .where('uid', isEqualTo: uid)
            .limit(1)
            .get();
        if (snap.docs.isEmpty) return uid;
        final user = UsersRecord.fromSnapshot(snap.docs.first);
        return user.displayName.isNotEmpty ? user.displayName : uid;
      });
      final names = await Future.wait(futures);
      return names.join(', ');
    } catch (_) {
      return userIds.join(', ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.message?.senderRef == currentUserReference;
    final isSystemMessage = widget.message?.isSystemMessage ?? false;

    // System message - centered, no profile picture
    if (isSystemMessage) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Text(
            widget.message?.content ?? '',
            textAlign: TextAlign.center,
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  color: const Color(0xFF6B7280),
                  fontSize: 13.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
        if (isMe)
          Align(
            alignment: const AlignmentDirectional(1.0, 0.0),
            child: Builder(
              builder: (context) => GestureDetector(
                onTap: () async {
                  await actions.closekeyboard();
                  await widget.action?.call();
                },
                onLongPress: _openReportDialog,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: availableWidth * 0.7,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Align(
                                  alignment:
                                      const AlignmentDirectional(1.0, -1.0),
                                  child: Padding(
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 12.0, 0.0),
                                    child: GestureDetector(
                                      onLongPress: _copyContentIfAny,
                                      child: Builder(
                                        builder: (context) {
                                          final content =
                                              widget.message?.content ?? '';
                                          final isOnlyEmojis =
                                              _containsOnlyEmojis(content) &&
                                                  (widget.message?.image ==
                                                          null ||
                                                      widget.message?.image ==
                                                          '') &&
                                                  (widget.message?.video ==
                                                          null ||
                                                      widget.message?.video ==
                                                          '') &&
                                                  (widget.message?.audio ==
                                                          null ||
                                                      widget.message?.audio ==
                                                          '') &&
                                                  (widget.message
                                                              ?.attachmentUrl ==
                                                          null ||
                                                      widget.message
                                                              ?.attachmentUrl ==
                                                          '') &&
                                                  (widget.message?.images
                                                          .isEmpty ??
                                                      true);

                                          if (isOnlyEmojis &&
                                              content.isNotEmpty) {
                                            // WhatsApp style: Just emojis in bigger size, no bubble
                                            return _withMessageMenu(
                                              bubble: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8.0,
                                                        vertical: 4.0),
                                                child: Text(
                                                  content,
                                                  style: const TextStyle(
                                                    fontSize:
                                                        48.0, // Larger size for emojis
                                                    height: 1.2,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }

                                          // Regular message with bubble
                                          // If message has image, use fixed width like WhatsApp
                                          final hasImage = widget.message?.image != null && 
                                                          widget.message!.image.isNotEmpty;
                                          return _withMessageMenu(
                                            bubble: AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              constraints: BoxConstraints(
                                                maxWidth: hasImage ? 280.0 : availableWidth * 0.7,
                                              ),
                                              width: hasImage ? 280.0 : null, // Fixed width when has image
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(18.0),
                                                border: Border.all(
                                                  color: Colors.black
                                                      .withOpacity(0.08),
                                                  width: 1.0,
                                                ),
                                                boxShadow: widget.isHighlighted
                                                    ? [
                                                        BoxShadow(
                                                          color: const Color(
                                                                  0xFF007AFF)
                                                              .withOpacity(0.4),
                                                          blurRadius: 8.0,
                                                          spreadRadius: 2.0,
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 14.0,
                                                        vertical: 10.0),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    // Reply indicator
                                                    if (widget.message
                                                                ?.replyTo !=
                                                            null &&
                                                        widget.message
                                                                ?.replyTo !=
                                                            '')
                                                      GestureDetector(
                                                        onTap: () =>
                                                            _scrollToRepliedMessage(),
                                                        child: Container(
                                                          constraints:
                                                              const BoxConstraints(
                                                            maxWidth: 280.0,
                                                          ),
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  bottom: 8.0),
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      10.0,
                                                                  vertical:
                                                                      6.0),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: const Color(
                                                                0xFFF0F2F5),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10.0),
                                                            border:
                                                                const Border(
                                                              left: BorderSide(
                                                                color: Color(
                                                                    0xFF007AFF),
                                                                width: 3.0,
                                                              ),
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Text(
                                                                      widget.message
                                                                              ?.replyToSender ??
                                                                          'Unknown',
                                                                      style:
                                                                          const TextStyle(
                                                                        fontFamily:
                                                                            'SF Pro Text',
                                                                        color: Color(
                                                                            0xFF007AFF),
                                                                        fontSize:
                                                                            13.0,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            2.0),
                                                                    Text(
                                                                      widget.message
                                                                              ?.replyToContent ??
                                                                          '',
                                                                      style:
                                                                          const TextStyle(
                                                                        fontFamily:
                                                                            'SF Pro Text',
                                                                        color: Color(
                                                                            0xFF667781),
                                                                        fontSize:
                                                                            13.0,
                                                                      ),
                                                                      maxLines:
                                                                          1,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    // Only show content if there's no file attachment (file name is shown in the file card)
                                                    if (widget.message
                                                                ?.content !=
                                                            null &&
                                                        widget.message
                                                                ?.content !=
                                                            '' &&
                                                        (widget.message
                                                                    ?.attachmentUrl ==
                                                                null ||
                                                            widget.message
                                                                    ?.attachmentUrl ==
                                                                ''))
                                                      custom_widgets
                                                          .MessageContentWidget(
                                                        content: valueOrDefault<
                                                            String>(
                                                          widget
                                                              .message?.content,
                                                          'I\'m at the venue now. Here\'s the map with the room highlighted:',
                                                        ),
                                                        senderName: widget.name,
                                                        onTapLink: (text, url,
                                                            title) async {
                                                          if (url != null) {
                                                            await _launchURL(
                                                                url);
                                                          }
                                                        },
                                                        styleSheet:
                                                            MarkdownStyleSheet(
                                                          // iOS native text styling
                                                          p: const TextStyle(
                                                            fontFamily:
                                                                'SF Pro Text',
                                                            color: Color(
                                                                0xFF000000),
                                                            fontSize: 17.0,
                                                            letterSpacing: -0.4,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            height: 1.3,
                                                          ),
                                                          a: const TextStyle(
                                                            fontFamily:
                                                                'SF Pro Text',
                                                            color: Color(
                                                                0xFF007AFF),
                                                            fontSize: 17.0,
                                                            letterSpacing: -0.4,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            decoration:
                                                                TextDecoration
                                                                    .underline,
                                                          ),
                                                          code: const TextStyle(
                                                            fontFamily:
                                                                'SF Mono',
                                                            color: Color(
                                                                0xFF000000),
                                                            fontSize: 15.0,
                                                          ),
                                                          codeblockDecoration:
                                                              BoxDecoration(
                                                            color: const Color(
                                                                0xFFE5E7EB),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                          ),
                                                          strong:
                                                              const TextStyle(
                                                            fontFamily:
                                                                'SF Pro Text',
                                                            color: Color(
                                                                0xFF000000),
                                                            fontSize: 17.0,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                          em: const TextStyle(
                                                            fontFamily:
                                                                'SF Pro Text',
                                                            color: Color(
                                                                0xFF000000),
                                                            fontSize: 17.0,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                          tableBody:
                                                              const TextStyle(
                                                            fontFamily:
                                                                'SF Pro Text',
                                                            color: Color(
                                                                0xFF000000),
                                                            fontSize: 15.0,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                          tableHead:
                                                              const TextStyle(
                                                            fontFamily:
                                                                'SF Pro Text',
                                                            color: Color(
                                                                0xFF000000),
                                                            fontSize: 15.0,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    // Edited indicator
                                                    if (widget.message
                                                            ?.isEdited ==
                                                        true)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsetsDirectional
                                                                .fromSTEB(0.0,
                                                                4.0, 0.0, 0.0),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              'edited',
                                                              style: TextStyle(
                                                                fontFamily:
                                                                    'SF Pro Text',
                                                                color: const Color(
                                                                    0xFF8E8E93),
                                                                fontSize: 11.0,
                                                                fontStyle:
                                                                    FontStyle
                                                                        .italic,
                                                              ),
                                                            ),
                                                            if (widget.message
                                                                    ?.editedAt !=
                                                                null) ...[
                                                              Text(
                                                                ' • ',
                                                                style:
                                                                    const TextStyle(
                                                                  fontFamily:
                                                                      'SF Pro Text',
                                                                  color: Color(
                                                                      0xFF8E8E93),
                                                                  fontSize:
                                                                      11.0,
                                                                ),
                                                              ),
                                                              Text(
                                                                dateTimeFormat(
                                                                    'MMM d, h:mm a',
                                                                    widget
                                                                        .message!
                                                                        .editedAt!),
                                                                style:
                                                                    const TextStyle(
                                                                  fontFamily:
                                                                      'SF Pro Text',
                                                                  color: Color(
                                                                      0xFF8E8E93),
                                                                  fontSize:
                                                                      11.0,
                                                                  fontStyle:
                                                                      FontStyle
                                                                          .italic,
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                    if (widget.message?.image !=
                                                            null &&
                                                        widget.message?.image !=
                                                            '')
                                                      OverflowBox(
                                                        maxWidth:
                                                            double.infinity,
                                                        alignment:
                                                            AlignmentDirectional
                                                                .centerStart,
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 40.0),
                                                          child: Stack(
                                                            clipBehavior:
                                                                Clip.none,
                                                            children: [
                                                              // Image bubble container (WhatsApp style: fixed width)
                                                              Container(
                                                                    constraints:
                                                                    BoxConstraints(
                                                                  maxWidth: 280.0, // Fixed width like WhatsApp
                                                                  maxHeight:
                                                                      400.0,
                                                                ),
                                                                width: 280.0, // Fixed width
                                                                margin:
                                                                    const EdgeInsets
                                                                        .only(
                                                                  bottom: 4.0,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: const Color(
                                                                      0xFFE5E7EB),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .only(
                                                                    topLeft: Radius
                                                                        .circular(
                                                                            8.0),
                                                                    topRight: Radius
                                                                        .circular(
                                                                            8.0),
                                                                    bottomLeft:
                                                                        Radius.circular(
                                                                            8.0),
                                                                    bottomRight: Radius.circular((widget.message?.content !=
                                                                                null &&
                                                                            widget
                                                                                .message!.content.isNotEmpty &&
                                                                            (widget.message?.attachmentUrl == null ||
                                                                                widget.message?.attachmentUrl == ''))
                                                                        ? 0.0
                                                                        : 8.0),
                                                                  ),
                                                                ),
                                                                child:
                                                                    GestureDetector(
                                                                  onTap:
                                                                      () async {
                                                                    await Navigator
                                                                        .push(
                                                                      context,
                                                                      PageTransition(
                                                                        type: PageTransitionType
                                                                            .fade,
                                                                        child:
                                                                            FlutterFlowExpandedImageView(
                                                                          image:
                                                                              CachedNetworkImage(
                                                                            fadeInDuration:
                                                                                const Duration(milliseconds: 300),
                                                                            fadeOutDuration:
                                                                                const Duration(milliseconds: 300),
                                                                            imageUrl:
                                                                                valueOrDefault<String>(
                                                                              widget.message?.image,
                                                                              'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                            ),
                                                                            fit:
                                                                                BoxFit.contain,
                                                                          ),
                                                                          allowRotation:
                                                                              false,
                                                                          tag: valueOrDefault<
                                                                              String>(
                                                                            widget.message?.image,
                                                                            'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                          ),
                                                                          useHeroAnimation:
                                                                              true,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                  child: Hero(
                                                                    tag: valueOrDefault<
                                                                        String>(
                                                                      widget
                                                                          .message
                                                                          ?.image,
                                                                      'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                    ),
                                                                    transitionOnUserGestures:
                                                                        true,
                                                                    child:
                                                                        ClipRRect(
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .only(
                                                                        topLeft:
                                                                            Radius.circular(8.0),
                                                                        topRight:
                                                                            Radius.circular(8.0),
                                                                        bottomLeft:
                                                                            Radius.circular(8.0),
                                                                        bottomRight: Radius.circular((widget.message?.content != null &&
                                                                                widget.message!.content.isNotEmpty &&
                                                                                (widget.message?.attachmentUrl == null || widget.message?.attachmentUrl == ''))
                                                                            ? 0.0
                                                                            : 8.0),
                                                                      ),
                                                                      child:
                                                                          CachedNetworkImage(
                                                                        fadeInDuration:
                                                                            const Duration(milliseconds: 300),
                                                                        fadeOutDuration:
                                                                            const Duration(milliseconds: 300),
                                                                        imageUrl:
                                                                            valueOrDefault<String>(
                                                                          widget
                                                                              .message
                                                                              ?.image,
                                                                          'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                        ),
                                                                        width: double
                                                                            .infinity,
                                                                        height:
                                                                            double.infinity,
                                                                        fit: BoxFit
                                                                            .cover,
                                                                        errorWidget: (context,
                                                                                error,
                                                                                stackTrace) =>
                                                                            Container(
                                                                          width:
                                                                              double.infinity,
                                                                          height:
                                                                              200.0,
                                                                          color:
                                                                              const Color(0xFFE5E7EB),
                                                                          child:
                                                                              Icon(
                                                                            Icons.broken_image,
                                                                            color:
                                                                                Colors.grey,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    if (widget.message?.video !=
                                                            null &&
                                                        widget.message?.video !=
                                                            '')
                                                      Container(
                                                        width: 265.0,
                                                        height: 200.0,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                              0xFFE5E7EB),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                        ),
                                                        child:
                                                            VideoMessageWidget(
                                                          videoUrl: widget
                                                                  .message
                                                                  ?.video ??
                                                              '',
                                                          width: 265.0,
                                                          height: 200.0,
                                                          isOwnMessage: isMe,
                                                        ),
                                                      ),
                                                    if ((widget.message
                                                                    ?.images !=
                                                                null &&
                                                            (widget.message
                                                                    ?.images)!
                                                                .isNotEmpty) ==
                                                        true)
                                                      Material(
                                                        color:
                                                            Colors.transparent,
                                                        elevation: 0.0,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                        ),
                                                        child: Container(
                                                          width: 265.0,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .transparent,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8.0),
                                                          ),
                                                          child: Builder(
                                                            builder: (context) {
                                                              final multipleImages =
                                                                  widget.message
                                                                          ?.images
                                                                          .toList() ??
                                                                      [];
                                                              return Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: List
                                                                    .generate(
                                                                  multipleImages
                                                                      .length,
                                                                  (multipleImagesIndex) {
                                                                    final multipleImagesItem =
                                                                        multipleImages[
                                                                            multipleImagesIndex];
                                                                    return Stack(
                                                                      clipBehavior:
                                                                          Clip.none,
                                                                      children: [
                                                                        // Image container
                                                                        GestureDetector(
                                                                          onTap:
                                                                              () async {
                                                                            await Navigator.push(
                                                                              context,
                                                                              PageTransition(
                                                                                type: PageTransitionType.fade,
                                                                                child: FlutterFlowExpandedImageView(
                                                                                  image: CachedNetworkImage(
                                                                                    fadeInDuration: const Duration(milliseconds: 300),
                                                                                    fadeOutDuration: const Duration(milliseconds: 300),
                                                                                    imageUrl: valueOrDefault<String>(
                                                                                      multipleImagesItem,
                                                                                      'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                                    ),
                                                                                    fit: BoxFit.contain,
                                                                                    errorWidget: (context, error, stackTrace) => Image.asset(
                                                                                      'assets/images/error_image.png',
                                                                                      fit: BoxFit.contain,
                                                                                    ),
                                                                                  ),
                                                                                  allowRotation: false,
                                                                                  tag: valueOrDefault<String>(
                                                                                    multipleImagesItem,
                                                                                    'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683$multipleImagesIndex',
                                                                                  ),
                                                                                  useHeroAnimation: true,
                                                                                ),
                                                                              ),
                                                                            );
                                                                          },
                                                                          child:
                                                                              Hero(
                                                                            tag:
                                                                                valueOrDefault<String>(
                                                                              multipleImagesItem,
                                                                              'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683$multipleImagesIndex',
                                                                            ),
                                                                            transitionOnUserGestures:
                                                                                true,
                                                                            child:
                                                                                ClipRRect(
                                                                              borderRadius: BorderRadius.circular(8.0),
                                                                              child: CachedNetworkImage(
                                                                                fadeInDuration: const Duration(milliseconds: 300),
                                                                                fadeOutDuration: const Duration(milliseconds: 300),
                                                                                imageUrl: valueOrDefault<String>(
                                                                                  multipleImagesItem,
                                                                                  'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                                ),
                                                                                width: double.infinity,
                                                                                height: 207.2,
                                                                                fit: BoxFit.cover,
                                                                                errorWidget: (context, error, stackTrace) => Image.asset(
                                                                                  'assets/images/error_image.png',
                                                                                  width: double.infinity,
                                                                                  height: 207.2,
                                                                                  fit: BoxFit.cover,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    );
                                                                  },
                                                                ).divide(
                                                                    const SizedBox(
                                                                        height:
                                                                            8.0)),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    if (widget.message?.audio !=
                                                            null &&
                                                        widget.message?.audio !=
                                                            '')
                                                      Container(
                                                        width: double.infinity,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                              0xFFE5E7EB),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                        ),
                                                        child:
                                                            FlutterFlowAudioPlayer(
                                                          audio: Audio.network(
                                                            widget.message!
                                                                .audioPath,
                                                            metas: Metas(
                                                              title: 'Voice',
                                                            ),
                                                          ),
                                                          titleTextStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleLarge
                                                                  .override(
                                                                    font: GoogleFonts
                                                                        .inter(
                                                                      fontWeight: FlutterFlowTheme.of(
                                                                              context)
                                                                          .titleLarge
                                                                          .fontWeight,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .titleLarge
                                                                          .fontStyle,
                                                                    ),
                                                                    fontSize:
                                                                        16.0,
                                                                    letterSpacing:
                                                                        0.0,
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .titleLarge
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .titleLarge
                                                                        .fontStyle,
                                                                  ),
                                                          playbackDurationTextStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .override(
                                                                    font: GoogleFonts
                                                                        .inter(
                                                                      fontWeight: FlutterFlowTheme.of(
                                                                              context)
                                                                          .labelMedium
                                                                          .fontWeight,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .labelMedium
                                                                          .fontStyle,
                                                                    ),
                                                                    letterSpacing:
                                                                        0.0,
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontStyle,
                                                                  ),
                                                          fillColor: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          playbackButtonColor:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .primary,
                                                          activeTrackColor:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .primary,
                                                          inactiveTrackColor:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .alternate,
                                                          elevation: 0.0,
                                                          playInBackground:
                                                              PlayInBackground
                                                                  .enabled,
                                                        ),
                                                      ),
                                                    if (widget.message
                                                                ?.attachmentUrl !=
                                                            null &&
                                                        widget.message
                                                                ?.attachmentUrl !=
                                                            '')
                                                      _buildFileAttachment(
                                                          widget.message!
                                                              .attachmentUrl),
                                                    // Timestamp inside bubble (bottom right for sent messages)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsetsDirectional
                                                              .fromSTEB(0.0,
                                                              4.0, 0.0, 0.0),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .end,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            _formatMessageTimestamp(
                                                                widget.message
                                                                    ?.createdAt),
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodySmall
                                                                .override(
                                                                  font: GoogleFonts
                                                                      .inter(),
                                                                  color: const Color(
                                                                      0xFF6B7280),
                                                                  fontSize:
                                                                      11.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w400,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ].divide(const SizedBox(
                                                      height: 8.0)),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ].divide(const SizedBox(height: 4.0)),
                            ),
                          ),
                        ),
                        // Only show profile photo in group chats
                        if (widget.isGroup)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16.0),
                            child: CachedNetworkImage(
                              fadeInDuration: const Duration(milliseconds: 300),
                              fadeOutDuration:
                                  const Duration(milliseconds: 300),
                              imageUrl: valueOrDefault<String>(
                                widget.senderImage,
                                'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdiv.png?alt=media&token=85d5445a-3d2d-4dd5-879e-c4000b1fefd5',
                              ),
                              width: 36.0,
                              height: 36.0,
                              fit: BoxFit.cover,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (!isMe)
          Align(
            alignment: const AlignmentDirectional(-1.0, 0.0),
            child: Builder(
              builder: (context) => GestureDetector(
                onTap: () async {
                  await actions.closekeyboard();
                  await widget.action?.call();
                },
                onLongPress: _openReportDialog,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Only show profile photo in group chats
                        if (widget.isGroup)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16.0),
                            child: CachedNetworkImage(
                              fadeInDuration: const Duration(milliseconds: 300),
                              fadeOutDuration:
                                  const Duration(milliseconds: 300),
                              imageUrl: valueOrDefault<String>(
                                widget.senderImage,
                                'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdiv.png?alt=media&token=85d5445a-3d2d-4dd5-879e-c4000b1fefd5',
                              ),
                              width: 36.0,
                              height: 36.0,
                              fit: BoxFit.cover,
                            ),
                          ),
                        Flexible(
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: availableWidth * 0.7,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Align(
                                  alignment:
                                      const AlignmentDirectional(-1.0, -1.0),
                                  child: Padding(
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 12.0, 0.0),
                                    child: GestureDetector(
                                      onLongPress: _copyContentIfAny,
                                      child: Builder(
                                        builder: (context) {
                                          final content =
                                              widget.message?.content ?? '';
                                          final isOnlyEmojis =
                                              _containsOnlyEmojis(content) &&
                                                  (widget.message?.image ==
                                                          null ||
                                                      widget.message?.image ==
                                                          '') &&
                                                  (widget.message?.video ==
                                                          null ||
                                                      widget.message?.video ==
                                                          '') &&
                                                  (widget.message?.audio ==
                                                          null ||
                                                      widget.message?.audio ==
                                                          '') &&
                                                  (widget.message
                                                              ?.attachmentUrl ==
                                                          null ||
                                                      widget.message
                                                              ?.attachmentUrl ==
                                                          '') &&
                                                  (widget.message?.images
                                                          .isEmpty ??
                                                      true);

                                          if (isOnlyEmojis &&
                                              content.isNotEmpty) {
                                            // WhatsApp style: Just emojis in bigger size, no bubble
                                            return _withMessageMenu(
                                              bubble: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8.0,
                                                        vertical: 4.0),
                                                child: Text(
                                                  content,
                                                  style: const TextStyle(
                                                    fontSize:
                                                        48.0, // Larger size for emojis
                                                    height: 1.2,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }

                                          // Regular message with bubble
                                          // If message has image, use fixed width like WhatsApp
                                          final hasImage = widget.message?.image != null && 
                                                          widget.message!.image.isNotEmpty;
                                          return _withMessageMenu(
                                            bubble: AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              constraints: BoxConstraints(
                                                maxWidth: hasImage ? 280.0 : availableWidth * 0.7,
                                              ),
                                              width: hasImage ? 280.0 : null, // Fixed width when has image
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(18.0),
                                                border: Border.all(
                                                  color: Colors.black
                                                      .withOpacity(0.08),
                                                  width: 1.0,
                                                ),
                                                boxShadow: widget.isHighlighted
                                                    ? [
                                                        BoxShadow(
                                                          color: const Color(
                                                                  0xFF007AFF)
                                                              .withOpacity(0.4),
                                                          blurRadius: 8.0,
                                                          spreadRadius: 2.0,
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 14.0,
                                                        vertical: 10.0),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    // Reply indicator for received messages
                                                    if (widget.message
                                                                ?.replyTo !=
                                                            null &&
                                                        widget.message
                                                                ?.replyTo !=
                                                            '')
                                                      GestureDetector(
                                                        onTap: () =>
                                                            _scrollToRepliedMessage(),
                                                        child: Container(
                                                          constraints:
                                                              const BoxConstraints(
                                                            maxWidth: 280.0,
                                                          ),
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  bottom: 8.0),
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      10.0,
                                                                  vertical:
                                                                      6.0),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: const Color(
                                                                0xFFF0F2F5),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10.0),
                                                            border:
                                                                const Border(
                                                              left: BorderSide(
                                                                color: Color(
                                                                    0xFF007AFF),
                                                                width: 3.0,
                                                              ),
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Text(
                                                                      widget.message
                                                                              ?.replyToSender ??
                                                                          'Unknown',
                                                                      style:
                                                                          const TextStyle(
                                                                        fontFamily:
                                                                            'SF Pro Text',
                                                                        color: Color(
                                                                            0xFF007AFF),
                                                                        fontSize:
                                                                            13.0,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            2.0),
                                                                    Text(
                                                                      widget.message
                                                                              ?.replyToContent ??
                                                                          '',
                                                                      style:
                                                                          const TextStyle(
                                                                        fontFamily:
                                                                            'SF Pro Text',
                                                                        color: Color(
                                                                            0xFF667781),
                                                                        fontSize:
                                                                            13.0,
                                                                      ),
                                                                      maxLines:
                                                                          1,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    // Only show content if there's no file attachment (file name is shown in the file card)
                                                    if (widget.message
                                                                ?.content !=
                                                            null &&
                                                        widget.message
                                                                ?.content !=
                                                            '' &&
                                                        (widget.message
                                                                    ?.attachmentUrl ==
                                                                null ||
                                                            widget.message
                                                                    ?.attachmentUrl ==
                                                                ''))
                                                      custom_widgets
                                                          .MessageContentWidget(
                                                        content: valueOrDefault<
                                                            String>(
                                                          widget
                                                              .message?.content,
                                                          'I\'m at the venue now. Here\'s the map with the room highlighted:',
                                                        ),
                                                        senderName: widget.name,
                                                        onTapLink: (text, url,
                                                            title) async {
                                                          if (url != null) {
                                                            await _launchURL(
                                                                url);
                                                          }
                                                        },
                                                        styleSheet:
                                                            MarkdownStyleSheet(
                                                          // iMessage received bubble: dark text on gray
                                                          p: const TextStyle(
                                                            fontFamily:
                                                                'SF Pro Text',
                                                            color: Color(
                                                                0xFF000000),
                                                            fontSize: 17.0,
                                                            letterSpacing: -0.4,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            height: 1.3,
                                                          ),
                                                          a: const TextStyle(
                                                            fontFamily:
                                                                'SF Pro Text',
                                                            color: Color(
                                                                0xFF007AFF),
                                                            fontSize: 17.0,
                                                            letterSpacing: -0.4,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            decoration:
                                                                TextDecoration
                                                                    .underline,
                                                          ),
                                                          code: const TextStyle(
                                                            fontFamily:
                                                                'SF Mono',
                                                            color: Color(
                                                                0xFF000000),
                                                            fontSize: 15.0,
                                                          ),
                                                          codeblockDecoration:
                                                              BoxDecoration(
                                                            color: const Color(
                                                                0xFFD1D1D6),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                          ),
                                                          strong:
                                                              const TextStyle(
                                                            fontFamily:
                                                                'SF Pro Text',
                                                            color: Color(
                                                                0xFF000000),
                                                            fontSize: 17.0,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                          em: const TextStyle(
                                                            fontFamily:
                                                                'SF Pro Text',
                                                            color: Color(
                                                                0xFF000000),
                                                            fontSize: 17.0,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                          tableBody:
                                                              const TextStyle(
                                                            fontFamily:
                                                                'SF Pro Text',
                                                            color: Color(
                                                                0xFF000000),
                                                            fontSize: 15.0,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                          tableHead:
                                                              const TextStyle(
                                                            fontFamily:
                                                                'SF Pro Text',
                                                            color: Color(
                                                                0xFF000000),
                                                            fontSize: 15.0,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    // Edited indicator for received messages
                                                    if (widget.message
                                                            ?.isEdited ==
                                                        true)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsetsDirectional
                                                                .fromSTEB(0.0,
                                                                4.0, 0.0, 0.0),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              'edited',
                                                              style: FlutterFlowTheme
                                                                      .of(context)
                                                                  .bodySmall
                                                                  .override(
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryText,
                                                                    fontSize:
                                                                        11.0,
                                                                    fontStyle:
                                                                        FontStyle
                                                                            .italic,
                                                                  ),
                                                            ),
                                                            if (widget.message
                                                                    ?.editedAt !=
                                                                null) ...[
                                                              Text(
                                                                ' • ',
                                                                style: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .override(
                                                                      color: FlutterFlowTheme.of(
                                                                              context)
                                                                          .secondaryText,
                                                                      fontSize:
                                                                          11.0,
                                                                    ),
                                                              ),
                                                              Text(
                                                                dateTimeFormat(
                                                                    'MMM d, h:mm a',
                                                                    widget
                                                                        .message!
                                                                        .editedAt!),
                                                                style: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .override(
                                                                      color: FlutterFlowTheme.of(
                                                                              context)
                                                                          .secondaryText,
                                                                      fontSize:
                                                                          11.0,
                                                                      fontStyle:
                                                                          FontStyle
                                                                              .italic,
                                                                    ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                    if (widget.message?.image !=
                                                            null &&
                                                        widget.message?.image !=
                                                            '')
                                                      OverflowBox(
                                                        maxWidth:
                                                            double.infinity,
                                                        alignment:
                                                            AlignmentDirectional
                                                                .centerStart,
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 40.0),
                                                          child: Stack(
                                                            clipBehavior:
                                                                Clip.none,
                                                            children: [
                                                              // Image bubble container (WhatsApp style: fixed width)
                                                              Container(
                                                                constraints:
                                                                    BoxConstraints(
                                                                  maxWidth: 280.0, // Fixed width like WhatsApp
                                                                  maxHeight:
                                                                      400.0,
                                                                ),
                                                                width: 280.0, // Fixed width
                                                                margin:
                                                                    const EdgeInsets
                                                                        .only(
                                                                  bottom: 4.0,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: const Color(
                                                                      0xFFE5E7EB),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8.0),
                                                                ),
                                                                child:
                                                                    GestureDetector(
                                                                  onTap:
                                                                      () async {
                                                                    await Navigator
                                                                        .push(
                                                                      context,
                                                                      PageTransition(
                                                                        type: PageTransitionType
                                                                            .fade,
                                                                        child:
                                                                            FlutterFlowExpandedImageView(
                                                                          image:
                                                                              CachedNetworkImage(
                                                                            fadeInDuration:
                                                                                const Duration(milliseconds: 300),
                                                                            fadeOutDuration:
                                                                                const Duration(milliseconds: 300),
                                                                            imageUrl:
                                                                                valueOrDefault<String>(
                                                                              widget.message?.image,
                                                                              'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                            ),
                                                                            fit:
                                                                                BoxFit.contain,
                                                                            errorWidget: (context, error, stackTrace) =>
                                                                                Image.asset(
                                                                              'assets/images/error_image.png',
                                                                              fit: BoxFit.contain,
                                                                            ),
                                                                          ),
                                                                          allowRotation:
                                                                              false,
                                                                          tag: valueOrDefault<
                                                                              String>(
                                                                            widget.message?.image,
                                                                            'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                          ),
                                                                          useHeroAnimation:
                                                                              true,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                  child: Hero(
                                                                    tag: valueOrDefault<
                                                                        String>(
                                                                      widget
                                                                          .message
                                                                          ?.image,
                                                                      'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                    ),
                                                                    transitionOnUserGestures:
                                                                        true,
                                                                    child:
                                                                        ClipRRect(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              8.0),
                                                                      child:
                                                                          CachedNetworkImage(
                                                                        fadeInDuration:
                                                                            const Duration(milliseconds: 300),
                                                                        fadeOutDuration:
                                                                            const Duration(milliseconds: 300),
                                                                        imageUrl:
                                                                            valueOrDefault<String>(
                                                                          widget
                                                                              .message
                                                                              ?.image,
                                                                          'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                        ),
                                                                        fit: BoxFit
                                                                            .cover,
                                                                        errorWidget: (context,
                                                                                error,
                                                                                stackTrace) =>
                                                                            Image.asset(
                                                                          'assets/images/error_image.png',
                                                                          fit: BoxFit
                                                                              .cover,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    if (widget.message?.video !=
                                                            null &&
                                                        widget.message?.video !=
                                                            '')
                                                      Container(
                                                        width: 265.0,
                                                        height: 200.0,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                              0xFFE5E7EB),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                        ),
                                                        child:
                                                            VideoMessageWidget(
                                                          videoUrl: widget
                                                                  .message
                                                                  ?.video ??
                                                              '',
                                                          width: 265.0,
                                                          height: 200.0,
                                                          isOwnMessage: isMe,
                                                        ),
                                                      ),
                                                    if ((widget.message
                                                                    ?.images !=
                                                                null &&
                                                            (widget.message
                                                                    ?.images)!
                                                                .isNotEmpty) ==
                                                        true)
                                                      Material(
                                                        color:
                                                            Colors.transparent,
                                                        elevation: 0.0,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                        ),
                                                        child: Container(
                                                          width: 265.0,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .transparent,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8.0),
                                                          ),
                                                          child: Builder(
                                                            builder: (context) {
                                                              final multipleImages =
                                                                  widget.message
                                                                          ?.images
                                                                          .toList() ??
                                                                      [];
                                                              return Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: List
                                                                    .generate(
                                                                  multipleImages
                                                                      .length,
                                                                  (multipleImagesIndex) {
                                                                    final multipleImagesItem =
                                                                        multipleImages[
                                                                            multipleImagesIndex];
                                                                    return Stack(
                                                                      clipBehavior:
                                                                          Clip.none,
                                                                      children: [
                                                                        // Image container
                                                                        GestureDetector(
                                                                          onTap:
                                                                              () async {
                                                                            await Navigator.push(
                                                                              context,
                                                                              PageTransition(
                                                                                type: PageTransitionType.fade,
                                                                                child: FlutterFlowExpandedImageView(
                                                                                  image: CachedNetworkImage(
                                                                                    fadeInDuration: const Duration(milliseconds: 300),
                                                                                    fadeOutDuration: const Duration(milliseconds: 300),
                                                                                    imageUrl: valueOrDefault<String>(
                                                                                      multipleImagesItem,
                                                                                      'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                                    ),
                                                                                    fit: BoxFit.contain,
                                                                                    errorWidget: (context, error, stackTrace) => Image.asset(
                                                                                      'assets/images/error_image.png',
                                                                                      fit: BoxFit.contain,
                                                                                    ),
                                                                                  ),
                                                                                  allowRotation: false,
                                                                                  tag: valueOrDefault<String>(
                                                                                    multipleImagesItem,
                                                                                    'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683$multipleImagesIndex',
                                                                                  ),
                                                                                  useHeroAnimation: true,
                                                                                ),
                                                                              ),
                                                                            );
                                                                          },
                                                                          child:
                                                                              Hero(
                                                                            tag:
                                                                                valueOrDefault<String>(
                                                                              multipleImagesItem,
                                                                              'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683$multipleImagesIndex',
                                                                            ),
                                                                            transitionOnUserGestures:
                                                                                true,
                                                                            child:
                                                                                ClipRRect(
                                                                              borderRadius: BorderRadius.circular(8.0),
                                                                              child: CachedNetworkImage(
                                                                                fadeInDuration: const Duration(milliseconds: 300),
                                                                                fadeOutDuration: const Duration(milliseconds: 300),
                                                                                imageUrl: valueOrDefault<String>(
                                                                                  multipleImagesItem,
                                                                                  'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                                ),
                                                                                width: double.infinity,
                                                                                height: 207.2,
                                                                                fit: BoxFit.cover,
                                                                                errorWidget: (context, error, stackTrace) => Image.asset(
                                                                                  'assets/images/error_image.png',
                                                                                  width: double.infinity,
                                                                                  height: 207.2,
                                                                                  fit: BoxFit.cover,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    );
                                                                  },
                                                                ).divide(
                                                                    const SizedBox(
                                                                        height:
                                                                            8.0)),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    if (widget.message?.audio !=
                                                            null &&
                                                        widget.message?.audio !=
                                                            '')
                                                      Container(
                                                        width: double.infinity,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                              0xFFE5E7EB),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                        ),
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          children: [
                                                            FlutterFlowAudioPlayer(
                                                              audio:
                                                                  Audio.network(
                                                                widget.message!
                                                                    .audioPath,
                                                                metas: Metas(
                                                                  title:
                                                                      'Voice',
                                                                ),
                                                              ),
                                                              titleTextStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleLarge
                                                                      .override(
                                                                        font: GoogleFonts
                                                                            .inter(
                                                                          fontWeight: FlutterFlowTheme.of(context)
                                                                              .titleLarge
                                                                              .fontWeight,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .titleLarge
                                                                              .fontStyle,
                                                                        ),
                                                                        fontSize:
                                                                            16.0,
                                                                        letterSpacing:
                                                                            0.0,
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .titleLarge
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .titleLarge
                                                                            .fontStyle,
                                                                      ),
                                                              playbackDurationTextStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .override(
                                                                        font: GoogleFonts
                                                                            .inter(
                                                                          fontWeight: FlutterFlowTheme.of(context)
                                                                              .labelMedium
                                                                              .fontWeight,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .labelMedium
                                                                              .fontStyle,
                                                                        ),
                                                                        letterSpacing:
                                                                            0.0,
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .labelMedium
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .labelMedium
                                                                            .fontStyle,
                                                                      ),
                                                              fillColor: FlutterFlowTheme
                                                                      .of(context)
                                                                  .secondaryBackground,
                                                              playbackButtonColor:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .primary,
                                                              activeTrackColor:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .primary,
                                                              inactiveTrackColor:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .alternate,
                                                              elevation: 0.0,
                                                              playInBackground:
                                                                  PlayInBackground
                                                                      .enabled,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    if (widget.message
                                                                ?.attachmentUrl !=
                                                            null &&
                                                        widget.message
                                                                ?.attachmentUrl !=
                                                            '')
                                                      _buildFileAttachment(
                                                          widget.message!
                                                              .attachmentUrl),
                                                    // Sender name and timestamp inside bubble (bottom left for received messages)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsetsDirectional
                                                              .fromSTEB(0.0,
                                                              4.0, 0.0, 0.0),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .start,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            valueOrDefault<
                                                                String>(
                                                              widget.name,
                                                              'No One',
                                                            ),
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodySmall
                                                                .override(
                                                                  font: GoogleFonts
                                                                      .inter(),
                                                                  color: const Color(
                                                                      0xFF6B7280),
                                                                  fontSize:
                                                                      11.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                          Text(
                                                            ' • ',
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodySmall
                                                                .override(
                                                                  font: GoogleFonts
                                                                      .inter(),
                                                                  color: const Color(
                                                                      0xFF6B7280),
                                                                  fontSize:
                                                                      11.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                ),
                                                          ),
                                                          Text(
                                                            _formatMessageTimestamp(
                                                                widget.message
                                                                    ?.createdAt),
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodySmall
                                                                .override(
                                                                  font: GoogleFonts
                                                                      .inter(),
                                                                  color: const Color(
                                                                      0xFF6B7280),
                                                                  fontSize:
                                                                      11.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w400,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ].divide(const SizedBox(
                                                      height: 8.0)),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ].divide(const SizedBox(height: 4.0)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]
          .divide(const SizedBox(height: 2.0))
          .addToStart(const SizedBox(height: 8.0))
          .addToEnd(const SizedBox(height: 8.0)),
    );
      },
    );
  }

  // Helper method to safely show SnackBar
  void _showSnackBar(SnackBar snackBar) {
    if (!mounted || _scaffoldMessenger == null) return;
    try {
      _scaffoldMessenger!.showSnackBar(snackBar);
    } catch (e) {
      // Widget was disposed or context invalid, silently ignore
    }
  }

  // Helper method to safely hide current SnackBar
  void _hideSnackBar() {
    if (!mounted || _scaffoldMessenger == null) return;
    try {
      _scaffoldMessenger!.hideCurrentSnackBar();
    } catch (e) {
      // Widget was disposed or context invalid, silently ignore
    }
  }

  // Show subtle popup notification with tick icon
  void _showSuccessPopup(String message) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 80,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-remove after 2 seconds with fade out
    Future.delayed(const Duration(seconds: 2), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  // Helper method to save file and reveal in Finder
  Future<void> _saveFileToPath(String url, String path, String fileName) async {
    try {
      final file = File(path);

      // Ensure parent directory exists before writing
      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        debugPrint('Creating directory: ${parentDir.path}');
        await parentDir.create(recursive: true);
      }

      // Download and save
      debugPrint('Downloading from URL: $url');
      final res = await http.get(Uri.parse(url));
      debugPrint('Download response status: ${res.statusCode}');

      if (res.statusCode == 200) {
        debugPrint('Saving file to: $path');
        await file.writeAsBytes(res.bodyBytes);
        debugPrint('File saved successfully!');

        // Reveal in Finder
        debugPrint('Revealing file in Finder...');
        try {
          await Process.run('open', ['-R', path]);
          debugPrint('Download complete!');

          _showSnackBar(
            SnackBar(
              content: Text('Downloaded: $fileName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } catch (e) {
          debugPrint('Error revealing file in Finder: $e');
          _showSnackBar(
            SnackBar(
              content: Text('File saved to: $path'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        debugPrint('Download failed with status: ${res.statusCode}');
        _showSnackBar(
          SnackBar(
            content: Text('Failed to download file. Status: ${res.statusCode}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving file: $e');
      _showSnackBar(
        SnackBar(
          content: Text('Error saving file: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Save image from message
  Future<void> _saveImage() async {
    debugPrint('========================================');
    debugPrint('=== SAVE IMAGE FROM MENU ===');
    debugPrint('========================================');

    // Try single image first
    final imageUrl = valueOrDefault<String>(
      widget.message?.image,
      '',
    );

    if (imageUrl.isNotEmpty) {
      final fileName = _getFileNameFromUrl(imageUrl);
      debugPrint('Saving single image: $fileName');
      await _downloadFile(imageUrl, fileName);
    } else if (widget.message?.images != null &&
        widget.message!.images!.isNotEmpty) {
      // Save all images in the multiple images array
      debugPrint('Saving ${widget.message!.images!.length} images');
      for (final imgUrl in widget.message!.images!) {
        if (imgUrl.isNotEmpty) {
          final fileName = _getFileNameFromUrl(imgUrl);
          debugPrint('Saving image: $fileName');
          await _downloadFile(imgUrl, fileName);
        }
      }
    } else {
      debugPrint('No images found in message!');
      _showSnackBar(
        const SnackBar(
          content: Text('No images found in this message'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Download function for images
  Future<void> _downloadFile(String url, String fileName) async {
    debugPrint('_downloadFile called with URL: $url, fileName: $fileName');
    // macOS - Handle separately to avoid any fallthrough
    if (Platform.isMacOS) {
      debugPrint('Platform is macOS, starting download...');
      try {
        // Sanitize filename
        String safeFileName = fileName;
        safeFileName = safeFileName.replaceAll('/', '_').replaceAll('\\', '_');
        safeFileName = safeFileName.split('/').last.split('\\').last;
        if (!safeFileName.contains('.')) {
          safeFileName = '${safeFileName}.jpg';
        }

        // Download the file first
        debugPrint('Downloading from URL: $url');
        final response = await http.get(Uri.parse(url));
        debugPrint('Download response status: ${response.statusCode}');

        if (response.statusCode != 200) {
          throw Exception('Failed to download file: ${response.statusCode}');
        }

        // Use file_picker's saveFile to handle macOS sandboxing properly
        // This will show a save dialog and handle permissions correctly
        final fileExtension = safeFileName.contains('.')
            ? safeFileName.split('.').last.toLowerCase()
            : 'jpg';

        // Determine file type based on extension
        FileType fileType = FileType.any;
        List<String>? allowedExtensions;

        // For common image types, use custom type with specific extension
        if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg']
            .contains(fileExtension)) {
          fileType = FileType.custom;
          allowedExtensions = [fileExtension];
        } else if (['pdf'].contains(fileExtension)) {
          fileType = FileType.custom;
          allowedExtensions = [fileExtension];
        }

        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save File',
          fileName: safeFileName,
          type: fileType,
          allowedExtensions: allowedExtensions,
        );

        if (result != null && result.isNotEmpty) {
          try {
            final file = File(result);
            await file.writeAsBytes(response.bodyBytes);
            debugPrint('File saved successfully to: $result');

            // Reveal in Finder
            try {
              await Process.run('open', ['-R', result]);
              debugPrint('Download complete!');

              _showSuccessPopup('Downloaded');
            } catch (e) {
              debugPrint('Error revealing file in Finder: $e');
              _showSuccessPopup('File saved');
            }
          } catch (e) {
            debugPrint('Error saving file: $e');
            _showSnackBar(
              SnackBar(
                content: Text('Error saving file: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          debugPrint('User cancelled file save dialog');
        }
      } catch (e) {
        debugPrint('Error during download: $e');
        _showSnackBar(
          SnackBar(
            content: Text('Error downloading file: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return; // ALWAYS return for macOS
    }

    // Rest of the code for other platforms
    try {
      if (kIsWeb) {
        // For web, download the file using blob URL
        try {
          _showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 16),
                  Text('Downloading $fileName...'),
                ],
              ),
              duration: const Duration(seconds: 30),
            ),
          );

          // Fetch the file
          final response = await http.get(Uri.parse(url));
          if (response.statusCode != 200) {
            throw Exception('Failed to download file: ${response.statusCode}');
          }

          // Sanitize filename for web
          String safeFileName = fileName;
          safeFileName =
              safeFileName.replaceAll('/', '_').replaceAll('\\', '_');
          safeFileName = safeFileName.split('/').last.split('\\').last;
          if (!safeFileName.contains('.')) {
            // Try to detect file type from content type or default to jpg
            final contentType =
                response.headers['content-type'] ?? 'image/jpeg';
            String extension = 'jpg';
            if (contentType.contains('png')) {
              extension = 'png';
            } else if (contentType.contains('gif')) {
              extension = 'gif';
            } else if (contentType.contains('webp')) {
              extension = 'webp';
            } else if (contentType.contains('pdf')) {
              extension = 'pdf';
            }
            safeFileName = '${safeFileName}.$extension';
          }

          // Create blob and download using helper (only works on web)
          await downloadFileOnWeb(url, safeFileName, response.bodyBytes);

          _hideSnackBar();
          _showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text('Downloaded: $safeFileName'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } catch (e) {
          debugPrint('Error downloading file on web: $e');
          _hideSnackBar();
          _showSnackBar(
            SnackBar(
              content: Text('Failed to download file: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // For other desktop platforms
      if (Platform.isLinux || Platform.isWindows) {
        _showSnackBar(
          SnackBar(
            content: Text('Downloading $fileName...'),
            duration: const Duration(seconds: 30),
          ),
        );

        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          Directory? directory;
          if (Platform.isLinux) {
            final homeDir = Platform.environment['HOME'];
            if (homeDir != null) {
              directory = Directory('$homeDir/Downloads');
            }
          } else if (Platform.isWindows) {
            final userProfile = Platform.environment['USERPROFILE'];
            if (userProfile != null) {
              directory = Directory('$userProfile/Downloads');
            }
          }

          if (directory == null || !await directory.exists()) {
            directory = await getApplicationDocumentsDirectory();
          }

          String finalFileName = fileName;
          int counter = 1;
          while (await File('${directory.path}/$finalFileName').exists()) {
            final extension = fileName.split('.').last;
            final nameWithoutExtension = fileName.replaceAll('.$extension', '');
            finalFileName = '${nameWithoutExtension}_$counter.$extension';
            counter++;
          }

          final file = File('${directory.path}/$finalFileName');
          await file.writeAsBytes(response.bodyBytes);

          _hideSnackBar();
          _showSnackBar(
            SnackBar(
              content: Text('Downloaded: $finalFileName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          throw Exception('Failed to download: ${response.statusCode}');
        }
        return;
      }

      // For mobile platforms (Android/iOS), download to device storage
      // Request storage permission (wrapped in try-catch for platforms that don't support it)
      try {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            _showSnackBar(
              const SnackBar(
                content:
                    Text('Storage permission is required to download files'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
      } catch (e) {
        // Permission handler not available (e.g., on some platforms)
        // Continue without permission check
      }

      // Show loading indicator
      _showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Text('Downloading $fileName...'),
            ],
          ),
          duration: const Duration(seconds: 30),
        ),
      );

      // Download the file
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // Get the downloads directory
        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          directory = await getApplicationDocumentsDirectory();
        }

        if (directory != null) {
          // Create unique filename if file already exists
          String finalFileName = fileName;
          int counter = 1;
          while (await File('${directory.path}/$finalFileName').exists()) {
            final extension = fileName.split('.').last;
            final nameWithoutExtension = fileName.replaceAll('.$extension', '');
            finalFileName = '${nameWithoutExtension}_$counter.$extension';
            counter++;
          }

          final file = File('${directory.path}/$finalFileName');
          await file.writeAsBytes(response.bodyBytes);

          _hideSnackBar();
          _showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text('Downloaded: $finalFileName'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () async {
                  await launchURL(file.path);
                },
              ),
            ),
          );
        }
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      _hideSnackBar();
      _showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Text('Download failed: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Extract filename from URL
  String _getFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        String fileName = segments.last;
        // Remove Firebase storage tokens and parameters
        if (fileName.contains('?')) {
          fileName = fileName.split('?').first;
        }
        // Decode URL encoding
        fileName = Uri.decodeComponent(fileName);
        return fileName;
      }
    } catch (e) {
      // Fallback filename
    }

    // Generate filename based on content type
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (url.contains('image') ||
        url.contains('.jpg') ||
        url.contains('.png') ||
        url.contains('.jpeg')) {
      return 'image_$timestamp.jpg';
    } else if (url.contains('video') ||
        url.contains('.mp4') ||
        url.contains('.mov')) {
      return 'video_$timestamp.mp4';
    } else {
      return 'file_$timestamp';
    }
  }
}

enum _MsgAction { react, copy, report, unsend, reply, edit, save }

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? textColor;

  const _MenuRow({
    required this.icon,
    required this.label,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: textColor ?? Colors.white,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final void Function(String emoji) onTap;

  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        onTap(emoji);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 16),
          ),
          if (count > 1)
            Padding(
              padding: const EdgeInsets.only(left: 2.0),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
