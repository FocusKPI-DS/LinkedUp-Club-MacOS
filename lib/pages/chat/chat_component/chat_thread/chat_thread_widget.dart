import 'package:translator/translator.dart';
import 'wechat_voice_bubble.dart';
import 'dart:convert';
import '/pages/chat/forwarded_history_viewer/forwarded_history_viewer_widget.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/pages/user_summary/user_summary_widget.dart';
import '/flutter_flow/flutter_flow_audio_player.dart';
import '/flutter_flow/flutter_flow_expanded_image_view.dart';
import '/custom_code/widgets/video_message_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
// import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/chat/chat_component/p_d_f_view/p_d_f_view_widget.dart';
import '/pages/chat/chat_component/report_component/report_component_widget.dart';
import '/pages/chat/chat_component/task_reminder_digest_card.dart';
import '../chat_thread_component/chat_thread_component_widget.dart';
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
import '/utils/qurio_url_launcher.dart';
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
    this.mentionableUsers = const [],
    this.isConsecutive = false,
    this.showTimestamp = true,
    this.onMessageAction,
    this.activeSelectionId,
    this.isSelectionMode = false,
    this.selectedMessages,
    this.onMessageToggled,
  });

  final MessagesRecord? message;
  final String? senderImage;
  final String? name;
  final DocumentReference? chatRef;
  final DocumentReference? userRef;
  final Future Function()? action;
  final Function(MessagesRecord, Offset?, ChatThreadComponentWidgetState?,
      {bool clearSelection})? onMessageLongPress;
  final Function(MessagesRecord)? onReplyToMessage;
  final Function(String)? onScrollToMessage;
  final Function(MessagesRecord)? onEditMessage;
  final bool isHighlighted;
  final bool isGroup; // Show profile photos only in group chats
  final List<UsersRecord> mentionableUsers;
  final bool
      isConsecutive; // Whether this message is part of a streak by the exact same sender
  final bool showTimestamp; // Whether to show the in-bubble timestamp
  final Function(String, MessagesRecord)? onMessageAction;
  final ValueNotifier<String?>? activeSelectionId;
  final bool isSelectionMode;
  final Set<MessagesRecord>? selectedMessages;
  final Function(MessagesRecord)? onMessageToggled;

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

  // Static overlay entry to ensure only one grid menu is open across all message widgets
  static OverlayEntry? _activeGridOverlay;
  static _ChatThreadWidgetState? _activeMenuOwner;
  bool _isSummarySectionExpanded = false;
  // Cache for file info results to prevent unnecessary rebuilds
  Map<String, dynamic>? _cachedFileInfo;
  // Stable futures for "reacted by" names so tooltip doesn't show "…" on every rebuild.
  // Global cache survives widget dispose so switching chats and coming back shows names immediately.
  static final Map<String, String> _globalReactionNamesCache = {};
  final Map<String, Future<String>> _reactionNamesFutureCache = {};
  ScaffoldMessengerState? _scaffoldMessenger;
  String? _translatedContent;
  bool _isTranslating = false;
  bool _isPreviewOpen = false;

  Future<void> _translateMessage() async {
    if (_isTranslating) return;
    final content = widget.message?.content;
    if (content == null || content.trim().isEmpty) return;

    setState(() => _isTranslating = true);
    try {
      final translator = GoogleTranslator();
      // Use translateLanguage (incoming translation preference), NOT aiTranslationTargetLanguage (outgoing)
      var targetLang = FFAppState().translateLanguage;
      // Handle 'system' by detecting device locale
      if (targetLang == 'system' || targetLang.isEmpty) {
        final locale = WidgetsBinding.instance.platformDispatcher.locale;
        targetLang = locale.languageCode;
        if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
          targetLang = '$targetLang-${locale.countryCode!.toLowerCase()}';
        }
      }
      final translation = await translator.translate(
        content,
        to: targetLang,
      );
      setState(() {
        _translatedContent = translation.text;
        _isTranslating = false;
      });
    } catch (e) {
      print('Translation error: $e');
      setState(() => _isTranslating = false);
    }
  }

  Widget _withPinnedIndicator(
      {required Widget bubble, required bool isPinned}) {
    if (!isPinned) return bubble;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        bubble,
        Positioned(
          top: -6,
          left: -4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black12, blurRadius: 4, spreadRadius: 1),
              ],
            ),
            child: const Icon(
              CupertinoIcons.star_fill,
              color: Color(0xFFFFD700),
              size: 11,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void setState(VoidCallback callback) {
    if (!mounted) return;
    super.setState(callback);
    _model.onUpdate();
  }

  ChatThreadComponentWidgetState? _chatThreadComponentState;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChatThreadModel());
    // Auto-translate if enabled
    if (FFAppState().autoTranslate) {
      _translateMessage();
    }
    _chatThreadComponentState = ChatThreadComponentWidget.of(context);
    _chatThreadComponentState?.translateNotifier
        .addListener(_onTranslateTriggered);
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _chatThreadComponentState?.translateNotifier
        .removeListener(_onTranslateTriggered);
    _model.maybeDispose();
    _scaffoldMessenger = null;
    super.dispose();
  }

  void _onTranslateTriggered() {
    if (ChatThreadComponentWidget.of(context)?.translateNotifier.value ==
        widget.message?.reference.id) {
      if (_translatedContent == null) {
        _translateMessage();
      }
    }
  }

  @override
  void didUpdateWidget(ChatThreadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When auto-translate is on, translate if content changed or not yet translated
    if (FFAppState().autoTranslate) {
      if (widget.message?.content != oldWidget.message?.content) {
        _translatedContent = null;
        _translateMessage();
      } else if (_translatedContent == null &&
          widget.message?.content != null &&
          widget.message!.content.trim().isNotEmpty) {
        _translateMessage();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store ScaffoldMessenger reference for safe use after async operations
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  }

  Future<void> _launchURL(String url) async {
    await qurioLaunchUrl(url);
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
    final fileName = fileInfo['fileName'] as String? ?? 'document';
    final ext =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    // Same as Vertin-Dev: preview PDF, images, text, and Office docs in one viewer
    final isPreviewable = fileInfo['isPdf'] == true ||
        [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'bmp',
          'txt',
          'md',
          'json',
          'xml',
          'csv',
          'log',
          'dart',
          'js',
          'html',
          'css',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
        ].contains(ext);

    return GestureDetector(
      onLongPressStart: (details) {
        if (widget.isSelectionMode) return;
        widget.onMessageLongPress?.call(
          widget.message!,
          details.globalPosition,
          null,
        );
      },
      onTap: () async {
        if (isPreviewable) {
          if (_isPreviewOpen) return;
          _isPreviewOpen = true;
          final url = attachmentUrl;
          final name = fileName;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!context.mounted) {
              _isPreviewOpen = false;
              return;
            }
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
                    url: url,
                    fileName: name,
                  ),
                );
              },
            );
            _isPreviewOpen = false;
          });
        } else {
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

  /// Extract a human-readable filename from a Firebase Storage URL.
  /// Handles URL-encoded paths and strips leading timestamp prefixes
  /// (e.g. '1775578299259_MyDocument.docx' → 'MyDocument.docx').
  String _extractFileNameFromUrl(Uri uri, String rawUrl) {
    try {
      // Firebase Storage URLs encode the path in a single segment after /o/
      // e.g. /o/users%2Fuid%2Fuploads%2F1775578299259_MyDoc.docx
      final decodedPath = Uri.decodeComponent(rawUrl);
      // Try to find the last path component after the last '/'
      final match = RegExp(r'\/([^\/\?]+)\?').firstMatch(decodedPath);
      String raw = '';
      if (match != null) {
        raw = match.group(1)!;
      } else {
        // Fallback: use URI path segments
        final pathSegments = uri.pathSegments;
        if (pathSegments.isEmpty) return 'file';
        raw = pathSegments.last.split('?').first;
        if (raw.contains('/')) raw = raw.split('/').last;
      }

      // URL-decode once more in case of double encoding
      raw = Uri.decodeComponent(raw);

      // Strip leading timestamp prefix: "1775578299259_filename.ext" → "filename.ext"
      // Pattern: one or more digits followed by underscore(s) at the start
      final stripped = raw.replaceFirst(RegExp(r'^\d{10,}_'), '');
      if (stripped.isNotEmpty && stripped.contains('.')) {
        return stripped;
      }
      // If stripping removed everything or there's no extension, return raw
      return raw.isNotEmpty ? raw : 'file';
    } catch (e) {
      return 'file';
    }
  }

  Future<Map<String, dynamic>> _fetchFileInfo(String fileUrl) async {
    try {
      final uri = Uri.parse(fileUrl);

      // Prefer stored file_name from Firestore (set when sending from file preview)
      String fileName = 'file';
      final storedFileName = widget.message?.snapshotData['file_name'];
      if (storedFileName is String && storedFileName.trim().isNotEmpty) {
        fileName = storedFileName.trim();
      } else {
        // Fallback: try to get filename from message content or URL
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
            fileName = _extractFileNameFromUrl(uri, fileUrl);
          }
        } else {
          // Extract from URL if no content
          fileName = _extractFileNameFromUrl(uri, fileUrl);
        }
      } // end else (no stored file_name)

      // Extension from fileName; fallback: detect from URL path (e.g. Firebase Storage encoded paths)
      String extension =
          fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
      if (extension.isEmpty || extension.length > 5) {
        final decodedPath = Uri.decodeComponent(fileUrl);
        final urlExtMatch = RegExp(r'\.(pdf|docx?|pptx?|xlsx?|txt|csv)(?:\?|$)',
                caseSensitive: false)
            .firstMatch(decodedPath);
        if (urlExtMatch != null) {
          extension = urlExtMatch.group(1)!.toLowerCase();
          if (!fileName.contains('.'))
            fileName =
                fileName == 'file' ? 'file.$extension' : '$fileName.$extension';
        }
      }

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

      // Try to get file size and optional filename from Content-Disposition
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
        // Use Content-Disposition filename when we still don't have a proper extension
        if (extension.isEmpty || extension.length > 5) {
          final disposition = response.headers['content-disposition'];
          if (disposition != null) {
            final filenameMatch = RegExp(
                    r'filename\*?=(?:UTF-8' ')?"?([^";\s]+)"?',
                    caseSensitive: false)
                .firstMatch(disposition);
            if (filenameMatch != null) {
              final suggestedName =
                  Uri.decodeComponent(filenameMatch.group(1)!.trim());
              if (suggestedName.contains('.')) {
                final ext = suggestedName.split('.').last.toLowerCase();
                if ([
                  'pdf',
                  'doc',
                  'docx',
                  'ppt',
                  'pptx',
                  'xls',
                  'xlsx',
                  'txt',
                  'csv'
                ].contains(ext)) {
                  extension = ext;
                  if (fileName == 'file' || !fileName.contains('.'))
                    fileName = suggestedName;
                }
              }
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
        'isDocx': extension == 'docx' || extension == 'doc',
        'isPpt': extension == 'pptx' || extension == 'ppt',
      };
    } catch (e) {
      return {
        'fileName': 'file',
        'fileType': 'FILE',
        'fileSize': '',
        'fileIcon': Icons.insert_drive_file,
        'iconColor': FlutterFlowTheme.of(context).primary,
        'isPdf': false,
        'isDocx': false,
        'isPpt': false,
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

  /// Normalize path to full "action_items/xyz" so update hits the right doc.
  static String _normalizeActionItemPath(String path) {
    if (path.isEmpty) return path;
    if (path.contains('/')) return path;
    return 'action_items/$path';
  }

  Future<void> _markActionItemDone(String actionItemRefPath) async {
    final path = _normalizeActionItemPath(actionItemRefPath);
    try {
      final ref = FirebaseFirestore.instance.doc(path);
      final snap = await ref.get();
      if (!snap.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Task already completed or removed',
              style: GoogleFonts.inter(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                fontWeight: FontWeight.w500,
              ),
            ),
            duration: const Duration(milliseconds: 2000),
            backgroundColor: FlutterFlowTheme.of(context).secondaryText,
          ),
        );
        return;
      }
      await ref.update({
        'status': 'completed',
        'completed_time': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final isNotFound = e.code == 'not-found';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNotFound
                ? 'Task already completed or removed'
                : 'Failed to update: ${e.message}',
          ),
          backgroundColor: isNotFound
              ? FlutterFlowTheme.of(context).secondaryText
              : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _remindAgain(String actionItemRefPath) async {
    final path = _normalizeActionItemPath(actionItemRefPath);
    try {
      final ref = FirebaseFirestore.instance.doc(path);
      final snap = await ref.get();
      if (!snap.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Task no longer found',
              style: GoogleFonts.inter(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: FlutterFlowTheme.of(context).secondaryText,
          ),
        );
        return;
      }
      await ref.update({'last_reminder_at': FieldValue.delete()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reminder will be sent again on the next run',
            style: GoogleFonts.inter(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              fontWeight: FontWeight.w500,
            ),
          ),
          duration: const Duration(milliseconds: 2000),
          backgroundColor: FlutterFlowTheme.of(context).secondaryText,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final isNotFound = e.code == 'not-found';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNotFound
                ? 'Task no longer found'
                : 'Failed to reset reminder: ${e.message}',
          ),
          backgroundColor: isNotFound
              ? FlutterFlowTheme.of(context).secondaryText
              : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reset reminder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  Future<void> _pinMessage() async {
    if (widget.message == null) return;
    try {
      await widget.message!.reference.update({'is_pinned': true});
      if (mounted) {
        _showSuccessPopup('Message Pinned');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(SnackBar(
          content: Text('Failed to pin message: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _unpinMessage() async {
    if (widget.message == null) return;
    try {
      await widget.message!.reference.update({'is_pinned': false});
      if (mounted) {
        _showSuccessPopup('Message Unpinned');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(SnackBar(
          content: Text('Failed to unpin message: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // Unified grid-style message action menu — matches iOS design on all platforms
  Widget _messageMenuButton() {
    final isIOS = !kIsWeb && Platform.isIOS;
    return GestureDetector(
      onTap: () => _showGridMenu(),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: KeyedSubtree(
          key: _menuIconKey,
          child: Container(
            decoration: BoxDecoration(
              color: isIOS ? Colors.black.withOpacity(0.1) : Colors.white,
              borderRadius: isIOS ? null : BorderRadius.circular(8),
              shape: isIOS ? BoxShape.circle : BoxShape.rectangle,
              boxShadow: isIOS
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 1,
                        offset: Offset(0, 0),
                      ),
                    ],
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isIOS ? 6 : 6,
              vertical: isIOS ? 6 : 4,
            ),
            child: Icon(
              isIOS ? Icons.more_vert_rounded : Icons.more_horiz_rounded,
              size: isIOS ? 16 : 14,
              color: isIOS ? Colors.black54 : Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  void _showGridMenuAtPosition(Offset globalPosition) {
    _showGridMenu(position: globalPosition);
  }

  void _showGridMenu({Offset? position}) {
    // Dismiss any existing grid menu from another message
    if (_activeGridOverlay != null) {
      _activeGridOverlay!.remove();
      _activeMenuOwner?._isMenuOpen = false;
      _activeMenuOwner?.setState(() {});
      _activeGridOverlay = null;
      _activeMenuOwner = null;
    }

    if (!kIsWeb && Platform.isIOS) {
      HapticFeedback.mediumImpact();
    }
    setState(() => _isMenuOpen = true);

    final isOwnMessage = widget.message?.senderRef == currentUserReference;
    final hasMedia = (widget.message?.image != null && widget.message!.image.isNotEmpty) ||
        (widget.message?.images != null && widget.message!.images.isNotEmpty) ||
        (widget.message?.video != null && widget.message!.video!.isNotEmpty);

    final menuItems = <Map<String, dynamic>>[
      {'label': 'Copy', 'icon': CupertinoIcons.doc_on_doc, 'action': _MsgAction.copy},
      {'label': 'Select', 'icon': CupertinoIcons.checkmark_circle, 'action': _MsgAction.select},
      {'label': 'React', 'icon': CupertinoIcons.smiley, 'action': _MsgAction.react},
      {'label': 'Reply', 'icon': CupertinoIcons.arrow_turn_up_left, 'action': _MsgAction.reply},
      {'label': 'Translate', 'icon': CupertinoIcons.book, 'action': _MsgAction.translate},
      {'label': 'Forward', 'icon': CupertinoIcons.arrow_turn_up_right, 'action': _MsgAction.forward},
      if (isOwnMessage) {'label': 'Edit', 'icon': CupertinoIcons.pencil, 'action': _MsgAction.edit},
      if (isOwnMessage) {'label': 'Unsend', 'icon': CupertinoIcons.arrow_counterclockwise, 'action': _MsgAction.unsend},
      if (hasMedia) {'label': 'Save', 'icon': CupertinoIcons.arrow_down_circle, 'action': _MsgAction.save},
      {'label': widget.message?.isPinned == true ? 'Unpin' : 'Pin', 'icon': CupertinoIcons.pin, 'action': widget.message?.isPinned == true ? _MsgAction.unpin : _MsgAction.pin},
      {'label': 'Report', 'icon': CupertinoIcons.exclamationmark_triangle, 'action': _MsgAction.report},
    ];

    // Grid layout constants
    const int itemsPerRow = 5;
    const double itemSize = 52.0;
    const double horizontalPadding = 8.0;
    const double verticalPadding = 8.0;
    final int actualItemsInWidestRow = menuItems.length < itemsPerRow ? menuItems.length : itemsPerRow;
    final double menuWidth = (itemSize * actualItemsInWidestRow) + (horizontalPadding * 2) + 2.0;

    // Get position — use provided position (right-click) or fall back to menu icon
    final screenSize = MediaQuery.of(context).size;
    final int rowCount = (menuItems.length / itemsPerRow).ceil();
    final double menuHeight = (itemSize * rowCount) + (verticalPadding * 2) + (rowCount > 1 ? (rowCount - 1) * 4 : 0);

    double left;
    double top;
    if (position != null) {
      // Right-click: center menu horizontally on click, above click point
      left = position.dx - menuWidth / 2;
      top = position.dy - menuHeight - 8;
    } else {
      // Icon button: position relative to icon
      final RenderBox? iconBox = _menuIconKey.currentContext?.findRenderObject() as RenderBox?;
      if (iconBox == null) {
        setState(() => _isMenuOpen = false);
        return;
      }
      final iconPosition = iconBox.localToGlobal(Offset.zero);
      left = iconPosition.dx - menuWidth + iconBox.size.width;
      top = iconPosition.dy - menuHeight - 8;
    }
    if (left < 10) left = 10;
    if (left + menuWidth > screenSize.width - 10) left = screenSize.width - menuWidth - 10;
    if (top < 10) top = (position?.dy ?? 100) + 8;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          // Dismiss layer
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (_) {
                entry.remove();
                _activeGridOverlay = null;
                _activeMenuOwner = null;
                if (mounted) setState(() => _isMenuOpen = false);
              },
            ),
          ),
          // Grid menu
          Positioned(
            left: left,
            top: top,
            child: Material(
              color: Colors.transparent,
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: menuWidth,
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.97),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.06),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Wrap(
                  spacing: 0,
                  runSpacing: 4,
                  alignment: WrapAlignment.start,
                  children: menuItems.map((item) {
                    final String label = item['label'] as String;
                    final IconData icon = item['icon'] as IconData;
                    final _MsgAction action = item['action'] as _MsgAction;
                    final isDestructive = action == _MsgAction.report || action == _MsgAction.unsend;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        entry.remove();
                        _activeGridOverlay = null;
                        _activeMenuOwner = null;
                        if (mounted) setState(() => _isMenuOpen = false);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _handleMenuAction(action);
                        });
                      },
                      child: SizedBox(
                        width: itemSize,
                        height: itemSize,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: 18,
                              color: isDestructive ? const Color(0xFFFF3B30) : const Color(0xFF1C1C1E),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'SF Pro Text',
                                fontSize: 9.5,
                                color: isDestructive
                                    ? const Color(0xFFFF3B30)
                                    : const Color(0xFF1C1C1E).withOpacity(0.8),
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(entry);
    _activeGridOverlay = entry;
    _activeMenuOwner = this;
  }

  Future<void> _handleMenuAction(_MsgAction action) async {
    switch (action) {
      case _MsgAction.react:
        await actions.closekeyboard();
        await widget.action?.call();
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
        if (widget.message?.video != null && widget.message!.video!.isNotEmpty) {
          await _saveVideo();
        } else {
          await _saveImage();
        }
        break;
      case _MsgAction.translate:
        await _translateMessage();
        break;
      case _MsgAction.pin:
        await _pinMessage();
        break;
      case _MsgAction.unpin:
        await _unpinMessage();
        break;
      case _MsgAction.forward:
        // Delegate to parent via onMessageAction callback
        if (widget.message != null) {
          widget.onMessageAction?.call('forward', widget.message!);
        }
        break;
      case _MsgAction.select:
        // Delegate to parent via onMessageAction callback
        if (widget.message != null) {
          widget.onMessageAction?.call('select', widget.message!);
        }
        break;
      case _MsgAction.delete:
        // Delegate to parent via onMessageAction callback
        if (widget.message != null) {
          widget.onMessageAction?.call('delete', widget.message!);
        }
        break;
      case _MsgAction.download:
        if (widget.message?.video != null && widget.message!.video!.isNotEmpty) {
          await _saveVideo();
        } else {
          await _saveImage();
        }
        break;
    }
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
                    bottom: 20.0,
                    left:
                        8.0), // Add bottom padding to move buttons up, left padding for search button
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
      // iOS: Do not use SelectionArea or GestureDetector here!
      // SelectableText and MarkdownBody inside MessageContentWidget
      // will handle text selection natively. We will trigger the menu
      // by hooking into their contextMenuBuilder.
      return Column(
        crossAxisAlignment:
            isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          bubble,
          if (reactionsBadge != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: reactionsBadge,
            ),
        ],
      );
    } else {
      // macOS: Use hover detection with dropdown + right-click to open grid menu
      return GestureDetector(
        onSecondaryTapDown: (details) {
          // Right-click triggers the grid menu positioned near the click
          _showGridMenuAtPosition(details.globalPosition);
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHoveredForMenu = true),
          onExit: (_) => setState(() => _isHoveredForMenu = false),
          child: Column(
            crossAxisAlignment:
                isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  bubble,
                  if (_isHoveredForMenu || _isMenuOpen)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _messageMenuButton(),
                    ),
                ],
              ),
              if (reactionsBadge != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: reactionsBadge,
                ),
            ],
          ),
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
              // Reuse the same future across rebuilds; global cache survives dispose so names persist when switching chats
              final cacheKey =
                  '${emoji}_${(List<String>.from(uids)..sort()).join(",")}';
              final nameFuture = _reactionNamesFutureCache.putIfAbsent(
                cacheKey,
                () async {
                  final cached = _globalReactionNamesCache[cacheKey];
                  if (cached != null) return cached;
                  final names = await _formatUsernames(uids);
                  _globalReactionNamesCache[cacheKey] = names;
                  return names;
                },
              );
              return FutureBuilder<String>(
                future: nameFuture,
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

  String? _formatFirefliesDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      final dt = DateTime.parse(dateString);
      final local = dt.toLocal();
      return '${_monthShort(local.month)} ${local.day}, ${local.year} · ${local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour)}:${local.minute.toString().padLeft(2, '0')} ${local.hour >= 12 ? 'PM' : 'AM'}';
    } catch (_) {
      return dateString;
    }
  }

  String _monthShort(int month) {
    const m = [
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
    return m[month - 1];
  }

  static const List<Color> _actionItemCardColors = [
    Color(0xFF1A73E8), // blue
    Color(0xFF0D9488), // teal/green
    Color(0xFF7C3AED), // purple
    Color(0xFFEA580C), // orange
  ];

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1)
      return parts[0].isNotEmpty ? parts[0].substring(0, 1).toUpperCase() : '?';
    final a = parts[0].isNotEmpty ? parts[0].substring(0, 1).toUpperCase() : '';
    final b = parts[1].isNotEmpty ? parts[1].substring(0, 1).toUpperCase() : '';
    return a + b;
  }

  Color _getColorForName(String name) {
    var hash = 0;
    for (var i = 0; i < name.length; i++)
      hash = (hash * 31 + name.codeUnitAt(i)) & 0x7FFFFFFF;
    return _actionItemCardColors[hash % _actionItemCardColors.length];
  }

  /// Parses Fireflies action_items string (e.g. " **Name** task1 (06:35) task2 **Name2** ...") into by-person structure.
  static List<Map<String, dynamic>> _parseFirefliesActionItemsByPerson(
      String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    final list = <Map<String, dynamic>>[];
    final namePattern = RegExp(r'\*\*([^*]+)\*\*');
    final matches = namePattern.allMatches(raw).toList();
    if (matches.isEmpty) return [];
    for (var i = 0; i < matches.length; i++) {
      final name = matches[i].group(1)?.trim() ?? '';
      if (name.isEmpty) continue;
      final start = matches[i].end;
      final end = i + 1 < matches.length ? matches[i + 1].start : raw.length;
      final block = raw.substring(start, end).trim();
      if (block.isEmpty) continue;
      // Split block into individual tasks by (MM:SS) or (M:SS) timestamp pattern
      final taskStrings = block.split(RegExp(r'\s*\(\d{1,2}:\d{2}\)\s*'));
      final tasks = taskStrings
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((title) => <String, dynamic>{'title': title})
          .toList();
      if (tasks.isEmpty) tasks.add(<String, dynamic>{'title': block});
      list.add(<String, dynamic>{'person': name, 'tasks': tasks});
    }
    return list;
  }

  Widget _buildFirefliesSummaryCard(
    BuildContext context,
    Map<String, dynamic> summary, {
    bool isSummaryExpanded = true,
    VoidCallback? onSummaryToggle,
  }) {
    final title = summary['title'] as String? ?? 'Meeting summary';
    final dateString = summary['dateString'] as String?;
    final duration = summary['duration'];
    final actionItems = summary['action_items'];
    final actionList = actionItems is List
        ? actionItems.map((e) => e is String ? e : e.toString()).toList()
        : <String>[];
    final actionItemsByPersonRaw = summary['action_items_by_person'];
    var actionItemsByPerson = actionItemsByPersonRaw is List
        ? actionItemsByPersonRaw
            .map((e) => e is Map ? Map<String, dynamic>.from(e as Map) : null)
            .whereType<Map<String, dynamic>>()
            .toList()
        : <Map<String, dynamic>>[];
    if (actionItemsByPerson.isEmpty && actionItems is String) {
      actionItemsByPerson =
          _parseFirefliesActionItemsByPerson(actionItems as String);
    }
    final useByPerson = actionItemsByPerson.isNotEmpty;
    final overview = summary['overview'] as String?;
    final bulletGist = summary['bullet_gist'] as String?;
    final shortSummary = summary['short_summary'] as String?;
    final bodyText = overview?.isNotEmpty == true
        ? overview
        : (bulletGist?.isNotEmpty == true ? bulletGist : shortSummary);
    final formattedDate = _formatFirefliesDate(dateString?.toString());
    final durationStr =
        (duration != null && duration is num && (duration as num) > 0)
            ? '${(duration as num).toStringAsFixed(1)} min'
            : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth * 0.82;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.15),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 22,
                  color: Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE8EAED),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header strip: LonaAI pill (Google-style chip)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: const Color(0xFF5F6368),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'LonaAI',
                                style: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .override(
                                      fontFamily: 'Inter',
                                      color: const Color(0xFF5F6368),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        // Title
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          child: Text(
                            title,
                            style: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  fontFamily: 'Inter',
                                  color: const Color(0xFF202124),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        // Meta: date · duration
                        if (formattedDate != null || durationStr != null) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                            child: Text(
                              [
                                if (formattedDate != null) formattedDate,
                                if (durationStr != null) durationStr,
                              ].join(' · '),
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    fontFamily: 'Inter',
                                    color: const Color(0xFF5F6368),
                                    fontSize: 12,
                                  ),
                            ),
                          ),
                        ],
                        // Divider (Google-style subtle separator)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFE8EAED),
                          ),
                        ),
                        // Action items section (by-person format for manual transcript, else flat list)
                        if (useByPerson || actionList.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.fromLTRB(14, 14, 14, 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFFE8EAED)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Action items',
                                    style: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .override(
                                          fontFamily: 'Inter',
                                          color: const Color(0xFF202124),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.1,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (useByPerson)
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final cardWidth =
                                            (constraints.maxWidth - 10) / 2;
                                        return Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: actionItemsByPerson
                                              .map((personBlock) {
                                            final personName =
                                                personBlock['person']
                                                        as String? ??
                                                    'Unassigned';
                                            final tasksRaw =
                                                personBlock['tasks'];
                                            final tasks = tasksRaw is List
                                                ? tasksRaw
                                                    .map((e) => e is Map
                                                        ? Map<String,
                                                                dynamic>.from(
                                                            e as Map)
                                                        : null)
                                                    .whereType<
                                                        Map<String, dynamic>>()
                                                    .toList()
                                                : <Map<String, dynamic>>[];
                                            final color =
                                                _getColorForName(personName);
                                            const cardHeight = 220.0;
                                            return SizedBox(
                                              width: cardWidth,
                                              height: cardHeight,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                      color: const Color(
                                                          0xFFE8EAED)),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.04),
                                                      blurRadius: 6,
                                                      offset:
                                                          const Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        CircleAvatar(
                                                          radius: 16,
                                                          backgroundColor: color
                                                              .withOpacity(0.2),
                                                          child: Text(
                                                            _getInitials(
                                                                personName),
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  'Inter',
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: color,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            personName,
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodyMedium
                                                                .override(
                                                                  fontFamily:
                                                                      'Inter',
                                                                  color: const Color(
                                                                      0xFF202124),
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Expanded(
                                                      child:
                                                          SingleChildScrollView(
                                                        physics:
                                                            const BouncingScrollPhysics(),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: tasks
                                                              .asMap()
                                                              .entries
                                                              .map((entry) {
                                                            final index =
                                                                entry.key + 1;
                                                            final t =
                                                                entry.value;
                                                            final taskTitle = t[
                                                                        'title']
                                                                    as String? ??
                                                                '';
                                                            final dueDate =
                                                                t['due_date']
                                                                    as String?;
                                                            final priority = t[
                                                                        'priority']
                                                                    as String? ??
                                                                '';
                                                            final line = dueDate !=
                                                                        null &&
                                                                    dueDate
                                                                        .isNotEmpty
                                                                ? '$taskTitle: Due $dueDate, $priority'
                                                                : priority
                                                                        .isNotEmpty
                                                                    ? '$taskTitle ($priority)'
                                                                    : taskTitle;
                                                            return Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      bottom:
                                                                          6),
                                                              child: Row(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Container(
                                                                    width: 20,
                                                                    height: 20,
                                                                    alignment:
                                                                        Alignment
                                                                            .center,
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: color
                                                                          .withOpacity(
                                                                              0.2),
                                                                      shape: BoxShape
                                                                          .circle,
                                                                    ),
                                                                    child: Text(
                                                                      '$index',
                                                                      style:
                                                                          TextStyle(
                                                                        fontFamily:
                                                                            'Inter',
                                                                        fontSize:
                                                                            11,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                        color:
                                                                            color,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      width: 8),
                                                                  Expanded(
                                                                    child: Text(
                                                                      line,
                                                                      style: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodySmall
                                                                          .override(
                                                                            fontFamily:
                                                                                'Inter',
                                                                            color:
                                                                                const Color(0xFF202124),
                                                                            fontSize:
                                                                                13,
                                                                          ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          }).toList(),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        );
                                      },
                                    )
                                  else
                                    ...actionList.asMap().entries.map((entry) {
                                      final index = entry.key + 1;
                                      final item = entry.value;
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 2),
                                              child: Container(
                                                width: 22,
                                                height: 22,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1A73E8)
                                                      .withOpacity(0.12),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  '$index',
                                                  style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF1A73E8),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                item,
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .override(
                                                          fontFamily: 'Inter',
                                                          color: const Color(
                                                              0xFF202124),
                                                          fontSize: 13,
                                                        ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ),
                        ],
                        // Summary / bullet gist: collapsible section
                        if (bodyText != null && bodyText.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.fromLTRB(14, 14, 14, 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFFE8EAED)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: onSummaryToggle,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Summary',
                                            style: FlutterFlowTheme.of(context)
                                                .titleSmall
                                                .override(
                                                  fontFamily: 'Inter',
                                                  color:
                                                      const Color(0xFF202124),
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.1,
                                                ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(
                                            isSummaryExpanded
                                                ? Icons
                                                    .keyboard_arrow_up_rounded
                                                : Icons
                                                    .keyboard_arrow_down_rounded,
                                            size: 20,
                                            color: const Color(0xFF5F6368),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isSummaryExpanded) ...[
                                    const SizedBox(height: 10),
                                    ...bodyText
                                        .split(RegExp(r'\n'))
                                        .where((s) => s.trim().isNotEmpty)
                                        .map((line) {
                                      final trimmed = line.trim();
                                      final bullet = trimmed.startsWith('- ')
                                          ? trimmed.substring(2)
                                          : trimmed;
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Padding(
                                              padding: EdgeInsets.only(top: 5),
                                              child: Icon(
                                                Icons.fiber_manual_record,
                                                size: 6,
                                                color: Color(0xFF1A73E8),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: MarkdownBody(
                                                data: bullet,
                                                styleSheet: MarkdownStyleSheet(
                                                  p: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    color: Color(0xFF202124),
                                                    fontSize: 13,
                                                  ),
                                                  strong: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    color: Color(0xFF202124),
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                shrinkWrap: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static const Color _taskReminderBlue = Color(0xFF0EA5E9);
  static const Color _taskReminderBlueDark = Color(0xFF0284C7);
  static const Color _taskReminderBubbleBlue = Color(0xFFE3F2FD);

  /// Picks digest (structured) vs legacy (content) so content is never empty.
  Widget _buildTaskReminderBubble(
    BuildContext context, {
    Map<String, dynamic>? taskReminders,
    required String content,
  }) {
    final tasksRaw = taskReminders?['tasks'];
    final hasStructuredTasks = tasksRaw is List && tasksRaw.isNotEmpty;
    if (hasStructuredTasks && taskReminders != null) {
      return TaskReminderDigestCard.fromPayload(
        taskReminders,
        onMarkDone: _markActionItemDone,
        onRemindAgain: _remindAgain,
      );
    }
    return _buildTaskRemindersLegacyCard(
      context,
      content.isNotEmpty ? content : 'Task reminders – no details available.',
    );
  }

  /// Same aesthetic card for old reminder messages that only have content (no task_reminders payload).
  Widget _buildTaskRemindersLegacyCard(BuildContext context, String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _taskReminderBlue.withOpacity(0.15),
            child: const Icon(
              Icons.notification_important_outlined,
              size: 22,
              color: _taskReminderBlueDark,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: _taskReminderBubbleBlue,
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left:
                      const BorderSide(color: _taskReminderBlueDark, width: 4),
                  top: BorderSide(color: _taskReminderBlue.withOpacity(0.3)),
                  right: BorderSide(color: _taskReminderBlue.withOpacity(0.3)),
                  bottom: BorderSide(color: _taskReminderBlue.withOpacity(0.3)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.notification_important_outlined,
                            size: 16,
                            color: _taskReminderBlueDark,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Urgent Digest',
                            style: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  fontFamily: 'Inter',
                                  color: _taskReminderBlueDark,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Divider(
                          height: 1, thickness: 1, color: Color(0xFFBBDEFB)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 60),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBDEFB)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: SelectableText(
                          content,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0xFF202124),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            'AI INSIGHT • ACTION REQUIRED',
                            style:
                                FlutterFlowTheme.of(context).bodySmall.override(
                                      fontFamily: 'Inter',
                                      color: const Color(0xFF5F6368),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {},
                            child: Text(
                              'View Thread Summary >',
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    fontFamily: 'Inter',
                                    color: _taskReminderBlueDark,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build the chat history preview UI
  Widget _buildChatHistoryPreview(String jsonString) {
    try {
      final List<dynamic> historyList = jsonDecode(jsonString);
      if (historyList.isEmpty) return const SizedBox.shrink();

      return GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => ForwardedHistoryViewerWidget(
                historyJson: jsonString,
              ),
            ),
          );
        },
        child: Container(
          width: 260.0,
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: const [
                  Icon(Icons.history, size: 16.0, color: Colors.black87),
                  SizedBox(width: 6.0),
                  Text(
                    'Chat History',
                    style: TextStyle(
                      fontFamily: 'SF Pro Text',
                      fontSize: 15.0,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Divider(height: 1.0, color: Colors.black.withOpacity(0.08)),
              const SizedBox(height: 8.0),
              ...historyList.take(3).map((item) {
                final msg = item as Map<String, dynamic>;
                final senderName = msg['sender_name'] ?? 'Unknown';
                final content = msg['content'] ?? '';
                final messageType = msg['message_type'] ?? 'text';
                final image = msg['image']?.toString();
                final imagesList = msg['images'] as List<dynamic>?;
                final video = msg['video']?.toString();
                final audio = msg['audio']?.toString();
                final attachment = msg['attachment_url']?.toString();
                
                final hasImage = (image != null && image.isNotEmpty) || (imagesList != null && imagesList.isNotEmpty);
                final hasVideo = video != null && video.isNotEmpty;
                final hasAudio = audio != null && audio.isNotEmpty;
                final hasAttachment = attachment != null && attachment.isNotEmpty;

                String displayContent = content;
                if (displayContent.isEmpty) {
                  if (hasImage || messageType == 'image') {
                    displayContent = '[Image]';
                  } else if (hasVideo || messageType == 'video') {
                    displayContent = '[Video]';
                  } else if (hasAudio || messageType == 'audio') {
                    displayContent = '[Audio]';
                  } else if (hasAttachment || messageType == 'file') {
                    displayContent = '[File]';
                  } else {
                    displayContent = '[$messageType]';
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    '$senderName: $displayContent',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'SF Pro Text',
                      fontSize: 13.0,
                      color: Color(0xFF666666),
                    ),
                  ),
                );
              }).toList(),
              if (historyList.length > 3)
                const Text(
                  '...',
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontSize: 13.0,
                    color: Color(0xFF666666),
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('Error parsing forwarded history: $e');
      return const Text('Error loading history');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.message?.senderRef == currentUserReference;
    final isSystemMessage = widget.message?.isSystemMessage ?? false;

    // System message - centered, no profile picture
    if (isSystemMessage) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
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
            ),
          ],
        ),
      );
    }

    // Fireflies summary card from LonaAI – same layout as received messages so "Message options" dropdown appears
    final firefliesSummary = widget.message?.firefliesSummary;
    if (firefliesSummary != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: const AlignmentDirectional(-1.0, 0.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: availableWidth * 0.82,
                          ),
                          child: Align(
                            alignment: const AlignmentDirectional(-1.0, -1.0),
                            child: Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  12.0, 0.0, 12.0, 0.0),
                              child: _withMessageMenu(
                                bubble: _buildFirefliesSummaryCard(
                                  context,
                                  firefliesSummary,
                                  isSummaryExpanded: _isSummarySectionExpanded,
                                  onSummaryToggle: () => setState(() =>
                                      _isSummarySectionExpanded =
                                          !_isSummarySectionExpanded),
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
            ],
          );
        },
      );
    }

    // Task reminder from LonaAI – show as card (structured payload or content fallback)
    // BUT skip if the message has message_format == 'text' (regular message via API)
    final messageFormat = widget.message?.snapshotData['message_format'] as String?;
    final taskReminders = widget.message?.taskReminders;
    final content = widget.message?.content ?? '';
    if (messageFormat != 'text' && taskReminders != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: const AlignmentDirectional(-1.0, 0.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: _withMessageMenu(
                          bubble: taskReminders != null
                              ? TaskReminderDigestCard.fromPayload(
                                  taskReminders,
                                  onMarkDone: _markActionItemDone,
                                  onRemindAgain: _remindAgain,
                                )
                              : _buildTaskRemindersLegacyCard(
                                  context,
                                  content.isNotEmpty
                                      ? content
                                      : 'Task reminders – no details available.',
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showTimestamp && widget.message?.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                child: Center(
                  child: Text(
                    dateTimeFormat('MMM d, h:mm a', widget.message!.createdAt!),
                    style: const TextStyle(
                      fontFamily: 'SF Pro Text',
                      color: Color(0xFF8E8E93),
                      fontSize: 12.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            if (isMe)
              Align(
                alignment: const AlignmentDirectional(1.0, 0.0),
                child: Builder(
                  builder: (context) {
                    final bool isSelected = widget.isSelectionMode &&
                        widget.selectedMessages != null &&
                        widget.message != null &&
                        widget.selectedMessages!.any((m) =>
                            m.reference.id == widget.message!.reference.id);

                    Widget bubbleContent = GestureDetector(
                      onTap: widget.isSelectionMode &&
                              widget.onMessageToggled != null &&
                              widget.message != null
                          ? () => widget.onMessageToggled!(widget.message!)
                          : null,
                      // Removed onTap here because it swallows native text selection gestures on iOS
                      // Removed onLongPressStart here to completely disable the old custom pop-up menu as requested
                      child: Container(
                        width: double.infinity,
                        color: isSelected
                            ? const Color(0xFF007AFF).withOpacity(0.05)
                            : Colors.transparent,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // For sender, selection checkbox goes on the left side of the bubble
                              if (widget.isSelectionMode)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: AbsorbPointer(
                                    child: Checkbox(
                                      value: isSelected,
                                      onChanged: (_) {},
                                      shape: const CircleBorder(),
                                      activeColor: const Color(0xFF007AFF),
                                    ),
                                  ),
                                ),
                              Row(
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Align(
                                            alignment:
                                                const AlignmentDirectional(
                                                    1.0, -1.0),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsetsDirectional
                                                      .fromSTEB(
                                                      12.0, 0.0, 12.0, 0.0),
                                              child: Builder(
                                                builder: (context) {
                                                  final content =
                                                      widget.message?.content ??
                                                          '';
                                                  final isOnlyEmojis = _containsOnlyEmojis(
                                                          content) &&
                                                      (widget.message
                                                                  ?.image ==
                                                              null ||
                                                          widget.message
                                                                  ?.image ==
                                                              '') &&
                                                      (widget.message
                                                                  ?.video ==
                                                              null ||
                                                          widget.message
                                                                  ?.video ==
                                                              '') &&
                                                      (widget.message
                                                                  ?.audio ==
                                                              null ||
                                                          widget.message
                                                                  ?.audio ==
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
                                                    return _withPinnedIndicator(
                                                      isPinned: widget.message
                                                              ?.isPinned ??
                                                          false,
                                                      bubble: _withMessageMenu(
                                                        bubble: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      8.0,
                                                                  vertical:
                                                                      4.0),
                                                          child: Text(
                                                            content,
                                                            style:
                                                                const TextStyle(
                                                              fontSize:
                                                                  48.0, // Larger size for emojis
                                                              height: 1.2,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }

                                                  // Regular message with bubble
                                                  // If message has image or video, use fixed width like WhatsApp
                                                  final hasImage =
                                                      widget.message?.image !=
                                                              null &&
                                                          widget.message!.image
                                                              .isNotEmpty;
                                                  final hasVideo =
                                                      widget.message?.video !=
                                                              null &&
                                                          widget.message!.video!
                                                              .isNotEmpty;
                                                  final hasMedia =
                                                      hasImage || hasVideo;
                                                  return _withPinnedIndicator(
                                                    isPinned: widget.message
                                                            ?.isPinned ??
                                                        false,
                                                    bubble: _withMessageMenu(
                                                      bubble: AnimatedContainer(
                                                        duration:
                                                            const Duration(
                                                                milliseconds:
                                                                    300),
                                                        constraints:
                                                            BoxConstraints(
                                                          maxWidth: hasMedia
                                                              ? 320.0
                                                              : availableWidth *
                                                                  0.7,
                                                        ),
                                                        width: hasMedia
                                                            ? 320.0
                                                            : null, // Fixed width when has image or video
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      18.0),
                                                          border: Border.all(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    0.08),
                                                            width: 1.0,
                                                          ),
                                                          boxShadow: widget
                                                                  .isHighlighted
                                                              ? [
                                                                  BoxShadow(
                                                                    color: const Color(
                                                                            0xFF007AFF)
                                                                        .withOpacity(
                                                                            0.4),
                                                                    blurRadius:
                                                                        8.0,
                                                                    spreadRadius:
                                                                        2.0,
                                                                  ),
                                                                ]
                                                              : null,
                                                        ),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      14.0,
                                                                  vertical:
                                                                      10.0),
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
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
                                                                  child:
                                                                      Container(
                                                                    constraints:
                                                                        const BoxConstraints(
                                                                      maxWidth:
                                                                          320.0,
                                                                    ),
                                                                    margin: const EdgeInsets
                                                                        .only(
                                                                        bottom:
                                                                            8.0),
                                                                    padding: const EdgeInsets
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
                                                                          BorderRadius.circular(
                                                                              10.0),
                                                                      border:
                                                                          const Border(
                                                                        left:
                                                                            BorderSide(
                                                                          color:
                                                                              Color(0xFF007AFF),
                                                                          width:
                                                                              3.0,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    child: Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        Expanded(
                                                                          child:
                                                                              Column(
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            mainAxisSize:
                                                                                MainAxisSize.min,
                                                                            children: [
                                                                              Text(
                                                                                widget.message?.replyToSender ?? 'Unknown',
                                                                                style: const TextStyle(
                                                                                  fontFamily: 'SF Pro Text',
                                                                                  color: Color(0xFF007AFF),
                                                                                  fontSize: 13.0,
                                                                                  fontWeight: FontWeight.w600,
                                                                                ),
                                                                              ),
                                                                              const SizedBox(height: 2.0),
                                                                              Text(
                                                                                widget.message?.replyToContent ?? '',
                                                                                style: const TextStyle(
                                                                                  fontFamily: 'SF Pro Text',
                                                                                  color: Color(0xFF667781),
                                                                                  fontSize: 13.0,
                                                                                ),
                                                                                maxLines: 1,
                                                                                overflow: TextOverflow.ellipsis,
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              // Show content (caption/text) whenever present, including with file attachment
                                                              if (widget.message?.forwardedHistory != null && widget.message!.forwardedHistory!.isNotEmpty)
                                                                _buildChatHistoryPreview(widget.message!.forwardedHistory!)
                                                              else if (widget.message?.content != null && widget.message?.content != '')
                                                                Container(
                                                                    constraints:
                                                                        BoxConstraints(
                                                                      maxWidth: hasMedia
                                                                          ? 320.0
                                                                          : double
                                                                              .infinity,
                                                                    ),
                                                                    child:
                                                                        Column(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        custom_widgets
                                                                            .MessageContentWidget(
                                                                          isOwnMessage: isMe,
                                                                          selectable:
                                                                              true,
                                                                          onSelectionMenuRequest:
                                                                              (String? action) {
                                                                            if (action == null ||
                                                                                widget.message == null)
                                                                              return;
                                                                            if (action ==
                                                                                'translate') {
                                                                              _translateMessage();
                                                                            } else {
                                                                              widget.onMessageAction?.call(action, widget.message!);
                                                                            }
                                                                          },
                                                                          onToolbarShown: () {
                                                                            // Dismiss any active media overlay when text toolbar appears
                                                                            widget.onMessageLongPress?.call(
                                                                              widget.message!,
                                                                              null,
                                                                              null,
                                                                              clearSelection: false,
                                                                            );
                                                                          },
                                                                          content:
                                                                              valueOrDefault<String>(
                                                                            widget.message?.content,
                                                                            'I\'m at the venue now. Here\'s the map with the room highlighted:',
                                                                          ),
                                                                          senderName:
                                                                              widget.name,
                                                                          mentionableUsers: widget
                                                                              .mentionableUsers
                                                                              .map((u) => u.displayName)
                                                                              .toList(),
                                                                          onTapLink: (text,
                                                                              url,
                                                                              title) async {
                                                                            if (url !=
                                                                                null) {
                                                                              await _launchURL(url);
                                                                            }
                                                                          },
                                                                          styleSheet:
                                                                              MarkdownStyleSheet(
                                                                            textScaler: TextScaler.noScaling,
                                                                            // iOS native text styling
                                                                            p: TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              letterSpacing: -0.4,
                                                                              fontWeight: FontWeight.w400,
                                                                              height: 1.3,
                                                                            ),
                                                                            h1: TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              fontWeight: FontWeight.w700,
                                                                            ),
                                                                            h2: TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              fontWeight: FontWeight.w700,
                                                                            ),
                                                                            h3: TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              fontWeight: FontWeight.w600,
                                                                            ),
                                                                            h4: TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              fontWeight: FontWeight.w600,
                                                                            ),
                                                                            h5: TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              fontWeight: FontWeight.w600,
                                                                            ),
                                                                            h6: TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              fontWeight: FontWeight.w500,
                                                                            ),
                                                                            a: TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF007AFF),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              letterSpacing: -0.4,
                                                                              fontWeight: FontWeight.w400,
                                                                              decoration: TextDecoration.underline,
                                                                            ),
                                                                            code:
                                                                                TextStyle(
                                                                              fontFamily: 'SF Mono',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize - 1.0,
                                                                            ),
                                                                            listBullet:
                                                                                TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                            ),
                                                                            blockquote:
                                                                                TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF667781),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                            ),
                                                                            codeblockDecoration:
                                                                                BoxDecoration(
                                                                              color: const Color(0xFFE5E7EB),
                                                                              borderRadius: BorderRadius.circular(6),
                                                                            ),
                                                                            strong:
                                                                                TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              fontWeight: FontWeight.w600,
                                                                            ),
                                                                            em: TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              fontStyle: FontStyle.italic,
                                                                              fontWeight: FontWeight.w400,
                                                                            ),
                                                                            tableBody:
                                                                                TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize - 1.0,
                                                                              fontWeight: FontWeight.w400,
                                                                            ),
                                                                            tableHead:
                                                                                TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize - 1.0,
                                                                              fontWeight: FontWeight.w600,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        if (_translatedContent !=
                                                                            null) ...[
                                                                          const SizedBox(
                                                                              height: 8.0),
                                                                          const Divider(
                                                                              height: 1.0,
                                                                              color: Color(0x33000000)),
                                                                          const SizedBox(
                                                                              height: 8.0),
                                                                          SelectableText(
                                                                            _translatedContent!,
                                                                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                  fontFamily: 'Inter',
                                                                                  fontStyle: FontStyle.italic,
                                                                                  color: Colors.black87,
                                                                                  fontSize: FFAppState().chatFontSize,
                                                                                ),
                                                                          ),
                                                                        ],
                                                                        if (_isTranslating)
                                                                          const Padding(
                                                                            padding:
                                                                                EdgeInsets.only(top: 8.0),
                                                                            child:
                                                                                SizedBox(
                                                                              width: 16,
                                                                              height: 16,
                                                                              child: CircularProgressIndicator(strokeWidth: 2),
                                                                            ),
                                                                          ),
                                                                      ],
                                                                    )),
                                                              // Via Qurio AI badge
                                                              if (widget.message?.sentVia == 'qurio_ai')
                                                                Padding(
                                                                  padding: const EdgeInsetsDirectional.fromSTEB(0.0, 4.0, 0.0, 0.0),
                                                                  child: Row(
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    children: [
                                                                      Icon(Icons.smart_toy_outlined, size: 12, color: Color(0xFF0077B5)),
                                                                      SizedBox(width: 3),
                                                                      Text(
                                                                        'via Qurio AI',
                                                                        style: TextStyle(
                                                                          fontFamily: 'SF Pro Text',
                                                                          color: Color(0xFF0077B5),
                                                                          fontSize: 11.0,
                                                                          fontWeight: FontWeight.w500,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              // Edited indicator
                                                              if (widget.message
                                                                      ?.isEdited ==
                                                                  true)
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsetsDirectional
                                                                          .fromSTEB(
                                                                          0.0,
                                                                          4.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Row(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      Text(
                                                                        'edited',
                                                                        style:
                                                                            TextStyle(
                                                                          fontFamily:
                                                                              'SF Pro Text',
                                                                          color:
                                                                              const Color(0xFF8E8E93),
                                                                          fontSize:
                                                                              11.0,
                                                                          fontStyle:
                                                                              FontStyle.italic,
                                                                        ),
                                                                      ),
                                                                      if (widget
                                                                              .message
                                                                              ?.editedAt !=
                                                                          null) ...[
                                                                        Text(
                                                                          ' • ',
                                                                          style:
                                                                              const TextStyle(
                                                                            fontFamily:
                                                                                'SF Pro Text',
                                                                            color:
                                                                                Color(0xFF8E8E93),
                                                                            fontSize:
                                                                                11.0,
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          dateTimeFormat(
                                                                              'MMM d, h:mm a',
                                                                              widget.message!.editedAt!),
                                                                          style:
                                                                              const TextStyle(
                                                                            fontFamily:
                                                                                'SF Pro Text',
                                                                            color:
                                                                                Color(0xFF8E8E93),
                                                                            fontSize:
                                                                                11.0,
                                                                            fontStyle:
                                                                                FontStyle.italic,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ],
                                                                  ),
                                                                ),
                                                              if (widget.message
                                                                          ?.image !=
                                                                      null &&
                                                                  widget.message
                                                                          ?.image !=
                                                                      '')
                                                                SizedBox(
                                                                  width: 240.0,
                                                                  child: Align(
                                                                  alignment:
                                                                      AlignmentDirectional
                                                                          .centerStart,
                                                                  child:
                                                                      Padding(
                                                                    padding: const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            40.0),
                                                                    child:
                                                                        Stack(
                                                                      clipBehavior:
                                                                          Clip.none,
                                                                      children: [
                                                                        // Image bubble container (reduced size)
                                                                        Container(
                                                                          constraints:
                                                                              BoxConstraints(
                                                                            maxWidth:
                                                                                200.0,
                                                                            maxHeight:
                                                                                260.0,
                                                                          ),
                                                                          width:
                                                                              200.0,
                                                                          margin:
                                                                              const EdgeInsets.only(
                                                                            bottom:
                                                                                4.0,
                                                                          ),
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            color:
                                                                                const Color(0xFFE5E7EB),
                                                                            borderRadius:
                                                                                BorderRadius.only(
                                                                              topLeft: Radius.circular(8.0),
                                                                              topRight: Radius.circular(8.0),
                                                                              bottomLeft: Radius.circular(8.0),
                                                                              bottomRight: Radius.circular((widget.message?.content != null && widget.message!.content.isNotEmpty && (widget.message?.attachmentUrl == null || widget.message?.attachmentUrl == '')) ? 0.0 : 8.0),
                                                                            ),
                                                                          ),
                                                                          child:
                                                                              GestureDetector(
                                                                            onLongPressStart: (details) {
                                                                              if (widget.isSelectionMode) return;
                                                                              widget.onMessageLongPress?.call(
                                                                                widget.message!,
                                                                                details.globalPosition,
                                                                                null,
                                                                              );
                                                                            },
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
                                                                                        widget.message?.image,
                                                                                        'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                                      ),
                                                                                      fit: BoxFit.contain,
                                                                                    ),
                                                                                    allowRotation: false,
                                                                                    tag: '${valueOrDefault<String>(
                                                                                      widget.message?.image,
                                                                                      'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                                    )}_${widget.message?.reference.id ?? ''}',
                                                                                    useHeroAnimation: true,
                                                                                    imageUrl: valueOrDefault<String>(
                                                                                      widget.message?.image,
                                                                                      '',
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              );
                                                                            },
                                                                            child:
                                                                                Hero(
                                                                              tag: '${valueOrDefault<String>(
                                                                                widget.message?.image,
                                                                                'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                              )}_${widget.message?.reference.id ?? ''}',
                                                                              transitionOnUserGestures: true,
                                                                              child: ClipRRect(
                                                                                borderRadius: BorderRadius.only(
                                                                                  topLeft: Radius.circular(8.0),
                                                                                  topRight: Radius.circular(8.0),
                                                                                  bottomLeft: Radius.circular(8.0),
                                                                                  bottomRight: Radius.circular((widget.message?.content != null && widget.message!.content.isNotEmpty && (widget.message?.attachmentUrl == null || widget.message?.attachmentUrl == '')) ? 0.0 : 8.0),
                                                                                ),
                                                                                child: CachedNetworkImage(
                                                                                  fadeInDuration: const Duration(milliseconds: 300),
                                                                                  fadeOutDuration: const Duration(milliseconds: 300),
                                                                                  imageUrl: valueOrDefault<String>(
                                                                                    widget.message?.image,
                                                                                    'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                                  ),
                                                                                  width: 200.0,
                                                                                  height: 200.0,
                                                                                  fit: BoxFit.cover,
                                                                                  errorWidget: (context, error, stackTrace) => Container(
                                                                                    width: 200.0,
                                                                                    height: 200.0,
                                                                                    color: const Color(0xFFE5E7EB),
                                                                                    child: Icon(
                                                                                      Icons.broken_image,
                                                                                      color: Colors.grey,
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
                                                                ),
                                                              if (widget.message
                                                                          ?.video !=
                                                                      null &&
                                                                  widget.message
                                                                          ?.video !=
                                                                      '')
                                                                GestureDetector(
                                                                  onLongPressStart: (details) {
                                                                    if (widget.isSelectionMode) return;
                                                                    widget.onMessageLongPress?.call(
                                                                      widget.message!,
                                                                      details.globalPosition,
                                                                      null,
                                                                    );
                                                                  },
                                                                  child: Container(
                                                                  constraints:
                                                                      BoxConstraints(
                                                                    maxWidth:
                                                                        320.0,
                                                                    maxHeight:
                                                                        400.0,
                                                                  ),
                                                                  width:
                                                                      320.0, // Min width so Chewie controls don't overflow
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
                                                                      topRight:
                                                                          Radius.circular(
                                                                              8.0),
                                                                      bottomLeft:
                                                                          Radius.circular(
                                                                              8.0),
                                                                      bottomRight: Radius.circular((widget.message?.content != null &&
                                                                              widget.message!.content.isNotEmpty &&
                                                                              (widget.message?.attachmentUrl == null || widget.message?.attachmentUrl == ''))
                                                                          ? 0.0
                                                                          : 8.0),
                                                                    ),
                                                                  ),
                                                                  child:
                                                                      ClipRRect(
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .only(
                                                                      topLeft: Radius
                                                                          .circular(
                                                                              8.0),
                                                                      topRight:
                                                                          Radius.circular(
                                                                              8.0),
                                                                      bottomLeft:
                                                                          Radius.circular(
                                                                              8.0),
                                                                      bottomRight: Radius.circular((widget.message?.content != null &&
                                                                              widget.message!.content.isNotEmpty &&
                                                                              (widget.message?.attachmentUrl == null || widget.message?.attachmentUrl == ''))
                                                                          ? 0.0
                                                                          : 8.0),
                                                                    ),
                                                                    child:
                                                                        VideoMessageWidget(
                                                                      videoUrl:
                                                                          widget.message?.video ??
                                                                              '',
                                                                      width:
                                                                          320.0,
                                                                      height:
                                                                          200.0,
                                                                      isOwnMessage:
                                                                          isMe,
                                                                    ),
                                                                  ),
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
                                                                  color: Colors
                                                                      .transparent,
                                                                  elevation:
                                                                      0.0,
                                                                  shape:
                                                                      RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            8.0),
                                                                  ),
                                                                  child:
                                                                      Container(
                                                                    width:
                                                                        200.0,
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: Colors
                                                                          .transparent,
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              8.0),
                                                                    ),
                                                                    child:
                                                                        Builder(
                                                                      builder:
                                                                          (context) {
                                                                        final multipleImages =
                                                                            widget.message?.images.toList() ??
                                                                                [];
                                                                        return Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.min,
                                                                          children: List
                                                                              .generate(
                                                                            multipleImages.length,
                                                                            (multipleImagesIndex) {
                                                                              final multipleImagesItem = multipleImages[multipleImagesIndex];
                                                                              return Stack(
                                                                                clipBehavior: Clip.none,
                                                                                children: [
                                                                                  // Image container
                                                                                  GestureDetector(
                                                                                    onLongPressStart: (details) {
                                                                                      if (widget.isSelectionMode) return;
                                                                                      widget.onMessageLongPress?.call(
                                                                                        widget.message!,
                                                                                        details.globalPosition,
                                                                                        null,
                                                                                      );
                                                                                    },
                                                                                    onTap: () async {
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
                                                                                            tag: '${valueOrDefault<String>(
                                                                                              multipleImagesItem,
                                                                                              'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683$multipleImagesIndex',
                                                                                            )}_${widget.message?.reference.id ?? ''}',
                                                                                            useHeroAnimation: true,
                                                                                            imageUrl: valueOrDefault<String>(
                                                                                              multipleImagesItem,
                                                                                              '',
                                                                                            ),
                                                                                          ),
                                                                                        ),
                                                                                      );
                                                                                    },
                                                                                    child: Hero(
                                                                                      tag: '${valueOrDefault<String>(
                                                                                        multipleImagesItem,
                                                                                        'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683$multipleImagesIndex',
                                                                                      )}_${widget.message?.reference.id ?? ''}',
                                                                                      transitionOnUserGestures: true,
                                                                                      child: ClipRRect(
                                                                                        borderRadius: BorderRadius.circular(8.0),
                                                                                        child: CachedNetworkImage(
                                                                                          fadeInDuration: const Duration(milliseconds: 300),
                                                                                          fadeOutDuration: const Duration(milliseconds: 300),
                                                                                          imageUrl: valueOrDefault<String>(
                                                                                            multipleImagesItem,
                                                                                            'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                                          ),
                                                                                          width: double.infinity,
                                                                                          height: 150.0,
                                                                                          fit: BoxFit.cover,
                                                                                          errorWidget: (context, error, stackTrace) => Image.asset(
                                                                                            'assets/images/error_image.png',
                                                                                            width: double.infinity,
                                                                                            height: 150.0,
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
                                                                              const SizedBox(height: 8.0)),
                                                                        );
                                                                      },
                                                                    ),
                                                                  ),
                                                                ),
                                                              if (widget.message
                                                                          ?.audio !=
                                                                      null &&
                                                                  widget.message
                                                                          ?.audio !=
                                                                      '')
                                                                WeChatVoiceBubble(
                                                                  audioUrl: widget.message!.audioPath,
                                                                  isMe: true,
                                                                ),
                                                              if (widget.message
                                                                          ?.attachmentUrl !=
                                                                      null &&
                                                                  widget.message
                                                                          ?.attachmentUrl !=
                                                                      '')
                                                                _buildFileAttachment(
                                                                    widget
                                                                        .message!
                                                                        .attachmentUrl),
                                                              // Timestamp inside bubble (bottom right for sent messages)
                                                              if (widget
                                                                  .showTimestamp)
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsetsDirectional
                                                                          .fromSTEB(
                                                                          0.0,
                                                                          4.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .end,
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      if (widget
                                                                              .message
                                                                              ?.isPinned ==
                                                                          true)
                                                                        Padding(
                                                                          padding: const EdgeInsets
                                                                              .only(
                                                                              right: 4.0),
                                                                          child:
                                                                              Icon(
                                                                            Icons.star_rounded,
                                                                            color:
                                                                                const Color(0xFFFFD700),
                                                                            size:
                                                                                14.0,
                                                                          ),
                                                                        ),
                                                                    ],
                                                                  ),
                                                                ),
                                                            ].divide(
                                                                const SizedBox(
                                                                    height:
                                                                        8.0)),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                    if (widget.isSelectionMode) {
                      return bubbleContent;
                    }

                    // For sender's messages, add a tooltip indicating swipe to reply
                    return GestureDetector(
                      onLongPressStart: (details) {
                        if (widget.isSelectionMode) return;
                        widget.onMessageLongPress?.call(
                          widget.message!,
                          details.globalPosition,
                          null,
                        );
                      },
                      child: bubbleContent,
                    );
                  },
                ),
              ),
            if (!isMe)
              Align(
                alignment: const AlignmentDirectional(-1.0, 0.0),
                child: Builder(
                  builder: (context) {
                    final bool isSelected = widget.isSelectionMode &&
                        widget.selectedMessages != null &&
                        widget.message != null &&
                        widget.selectedMessages!.any((m) =>
                            m.reference.id == widget.message!.reference.id);

                    Widget bubbleContent = GestureDetector(
                      onTap: widget.isSelectionMode &&
                              widget.onMessageToggled != null &&
                              widget.message != null
                          ? () => widget.onMessageToggled!(widget.message!)
                          : () async {
                              await actions.closekeyboard();
                              await widget.action?.call();
                            },
                      // Removed onLongPressStart here to completely disable the old custom pop-up menu as requested
                      child: Container(
                        width: double.infinity,
                        color: isSelected
                            ? const Color(0xFF007AFF).withOpacity(0.05)
                            : Colors.transparent,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              8.0, widget.isConsecutive ? 2.0 : 8.0, 8.0, 8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.isSelectionMode)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: AbsorbPointer(
                                    child: Checkbox(
                                      value: isSelected,
                                      onChanged: (_) {},
                                      shape: const CircleBorder(),
                                      activeColor: const Color(0xFF007AFF),
                                    ),
                                  ),
                                ),
                              // Show profile photo (tappable to open user summary)
                              if (!widget.isConsecutive)
                                GestureDetector(
                                  onTap: widget.userRef != null
                                      ? () {
                                          context.pushNamed(
                                            UserSummaryWidget.routeName,
                                            queryParameters: {
                                              'userRef': serializeParam(
                                                widget.userRef,
                                                ParamType.DocumentReference,
                                              ),
                                            }.withoutNulls,
                                            extra: <String, dynamic>{
                                              'userRef': widget.userRef,
                                            },
                                          );
                                        }
                                      : null,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16.0),
                                    child: CachedNetworkImage(
                                      fadeInDuration:
                                          const Duration(milliseconds: 300),
                                      fadeOutDuration:
                                          const Duration(milliseconds: 300),
                                      imageUrl: (widget.senderImage != null &&
                                              widget.senderImage!.isNotEmpty)
                                          ? widget.senderImage!
                                          : 'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdiv.png?alt=media&token=85d5445a-3d2d-4dd5-879e-c4000b1fefd5',
                                      width: 36.0,
                                      height: 36.0,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(width: 36.0, height: 36.0),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxWidth: availableWidth * 0.7,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Align(
                                            alignment:
                                                const AlignmentDirectional(
                                                    -1.0, -1.0),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsetsDirectional
                                                      .fromSTEB(
                                                      12.0, 0.0, 12.0, 0.0),
                                              child: Builder(
                                                builder: (context) {
                                                  final content =
                                                      widget.message?.content ??
                                                          '';
                                                  final isOnlyEmojis = _containsOnlyEmojis(
                                                          content) &&
                                                      (widget.message
                                                                  ?.image ==
                                                              null ||
                                                          widget.message
                                                                  ?.image ==
                                                              '') &&
                                                      (widget.message
                                                                  ?.video ==
                                                              null ||
                                                          widget.message
                                                                  ?.video ==
                                                              '') &&
                                                      (widget.message
                                                                  ?.audio ==
                                                              null ||
                                                          widget.message
                                                                  ?.audio ==
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
                                                    return _withPinnedIndicator(
                                                      isPinned: widget.message
                                                              ?.isPinned ??
                                                          false,
                                                      bubble: _withMessageMenu(
                                                        bubble: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      8.0,
                                                                  vertical:
                                                                      4.0),
                                                          child: Text(
                                                            content,
                                                            style:
                                                                const TextStyle(
                                                              fontSize:
                                                                  48.0, // Larger size for emojis
                                                              height: 1.2,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }

                                                  // Regular message with bubble
                                                  // If message has image or video, use fixed width like WhatsApp
                                                  final hasImage =
                                                      widget.message?.image !=
                                                              null &&
                                                          widget.message!.image
                                                              .isNotEmpty;
                                                  final hasVideo =
                                                      widget.message?.video !=
                                                              null &&
                                                          widget.message!.video!
                                                              .isNotEmpty;
                                                  final hasMedia =
                                                      hasImage || hasVideo;
                                                  return _withPinnedIndicator(
                                                    isPinned: widget.message
                                                            ?.isPinned ??
                                                        false,
                                                    bubble: _withMessageMenu(
                                                      bubble: AnimatedContainer(
                                                        duration:
                                                            const Duration(
                                                                milliseconds:
                                                                    300),
                                                        constraints:
                                                            BoxConstraints(
                                                          maxWidth: hasMedia
                                                              ? 320.0
                                                              : availableWidth *
                                                                  0.7,
                                                        ),
                                                        width: hasMedia
                                                            ? 320.0
                                                            : null, // Fixed width when has image or video
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      18.0),
                                                          border: Border.all(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    0.08),
                                                            width: 1.0,
                                                          ),
                                                          boxShadow: widget
                                                                  .isHighlighted
                                                              ? [
                                                                  BoxShadow(
                                                                    color: const Color(
                                                                            0xFF007AFF)
                                                                        .withOpacity(
                                                                            0.4),
                                                                    blurRadius:
                                                                        8.0,
                                                                    spreadRadius:
                                                                        2.0,
                                                                  ),
                                                                ]
                                                              : null,
                                                        ),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      14.0,
                                                                  vertical:
                                                                      10.0),
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
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
                                                                  child:
                                                                      Container(
                                                                    constraints:
                                                                        const BoxConstraints(
                                                                      maxWidth:
                                                                          320.0,
                                                                    ),
                                                                    margin: const EdgeInsets
                                                                        .only(
                                                                        bottom:
                                                                            8.0),
                                                                    padding: const EdgeInsets
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
                                                                          BorderRadius.circular(
                                                                              10.0),
                                                                      border:
                                                                          const Border(
                                                                        left:
                                                                            BorderSide(
                                                                          color:
                                                                              Color(0xFF007AFF),
                                                                          width:
                                                                              3.0,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    child: Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        Expanded(
                                                                          child:
                                                                              Column(
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            mainAxisSize:
                                                                                MainAxisSize.min,
                                                                            children: [
                                                                              Text(
                                                                                widget.message?.replyToSender ?? 'Unknown',
                                                                                style: const TextStyle(
                                                                                  fontFamily: 'SF Pro Text',
                                                                                  color: Color(0xFF007AFF),
                                                                                  fontSize: 13.0,
                                                                                  fontWeight: FontWeight.w600,
                                                                                ),
                                                                              ),
                                                                              const SizedBox(height: 2.0),
                                                                              Text(
                                                                                widget.message?.replyToContent ?? '',
                                                                                style: const TextStyle(
                                                                                  fontFamily: 'SF Pro Text',
                                                                                  color: Color(0xFF667781),
                                                                                  fontSize: 13.0,
                                                                                ),
                                                                                maxLines: 1,
                                                                                overflow: TextOverflow.ellipsis,
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              // Show content (caption/text) whenever present, including with file attachment
                                                              if (widget.message?.forwardedHistory != null && widget.message!.forwardedHistory!.isNotEmpty)
                                                                _buildChatHistoryPreview(widget.message!.forwardedHistory!)
                                                              else if (widget.message?.content != null && widget.message?.content != '')
                                                                Container(
                                                                    constraints:
                                                                        BoxConstraints(
                                                                      maxWidth: hasMedia
                                                                          ? 320.0
                                                                          : double
                                                                              .infinity,
                                                                    ),
                                                                    child:
                                                                        Column(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        custom_widgets
                                                                            .MessageContentWidget(
                                                                          isOwnMessage: isMe,
                                                                          selectable:
                                                                              true,
                                                                          onSelectionMenuRequest:
                                                                              (String? action) {
                                                                            if (action == null ||
                                                                                widget.message == null)
                                                                              return;
                                                                            if (action ==
                                                                                'translate') {
                                                                              _translateMessage();
                                                                            } else {
                                                                              widget.onMessageAction?.call(action, widget.message!);
                                                                            }
                                                                          },
                                                                          onToolbarShown: () {
                                                                            // Dismiss any active media overlay when text toolbar appears
                                                                            widget.onMessageLongPress?.call(
                                                                              widget.message!,
                                                                              null,
                                                                              null,
                                                                              clearSelection: false,
                                                                            );
                                                                          },
                                                                          content:
                                                                              valueOrDefault<String>(
                                                                            widget.message?.content,
                                                                            'I\'m at the venue now. Here\'s the map with the room highlighted:',
                                                                          ),
                                                                          senderName:
                                                                              widget.name,
                                                                          mentionableUsers: widget
                                                                              .mentionableUsers
                                                                              .map((u) => u.displayName)
                                                                              .toList(),
                                                                          onTapLink: (text,
                                                                              url,
                                                                              title) async {
                                                                            if (url !=
                                                                                null) {
                                                                              await _launchURL(url);
                                                                            }
                                                                          },
                                                                          styleSheet:
                                                                              MarkdownStyleSheet(
                                                                            textScaler: TextScaler.noScaling,
                                                                            // iMessage received bubble: dark text on gray
                                                                            p: TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              letterSpacing: -0.4,
                                                                              fontWeight: FontWeight.w400,
                                                                              height: 1.3,
                                                                            ),
                                                                            h1: TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              fontWeight: FontWeight.w700,
                                                                            ),
                                                                            h2: TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              fontWeight: FontWeight.w700,
                                                                            ),
                                                                            h3: TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              fontWeight: FontWeight.w600,
                                                                            ),
                                                                            h4: TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              fontWeight: FontWeight.w600,
                                                                            ),
                                                                            h5: TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              fontWeight: FontWeight.w600,
                                                                            ),
                                                                            h6: TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              fontWeight: FontWeight.w500,
                                                                            ),
                                                                            a: TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF007AFF),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              letterSpacing: -0.4,
                                                                              fontWeight: FontWeight.w400,
                                                                              decoration: TextDecoration.underline,
                                                                            ),
                                                                            code:
                                                                                TextStyle(
                                                                              fontFamily: 'SF Mono',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize - 1.0,
                                                                            ),
                                                                            listBullet:
                                                                                TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                            ),
                                                                            blockquote:
                                                                                TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF667781),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                            ),
                                                                            codeblockDecoration:
                                                                                BoxDecoration(
                                                                              color: const Color(0xFFD1D1D6),
                                                                              borderRadius: BorderRadius.circular(6),
                                                                            ),
                                                                            strong:
                                                                                TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              fontWeight: FontWeight.w600,
                                                                            ),
                                                                            em: TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize,
                                                                              fontStyle: FontStyle.italic,
                                                                              fontWeight: FontWeight.w400,
                                                                            ),
                                                                            tableBody:
                                                                                TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize - 1.0,
                                                                              fontWeight: FontWeight.w400,
                                                                            ),
                                                                            tableHead:
                                                                                TextStyle(
                                                                              fontFamily: 'SF Pro Text',
                                                                              color: const Color(0xFF000000),
                                                                              fontSize: FFAppState().chatFontSize - 1.0,
                                                                              fontWeight: FontWeight.w600,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        if (_translatedContent !=
                                                                            null) ...[
                                                                          const SizedBox(
                                                                              height: 8.0),
                                                                          const Divider(
                                                                              height: 1.0,
                                                                              color: Color(0x33000000)),
                                                                          const SizedBox(
                                                                              height: 8.0),
                                                                          SelectableText(
                                                                            _translatedContent!,
                                                                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                  fontFamily: 'Inter',
                                                                                  fontStyle: FontStyle.italic,
                                                                                  color: Colors.black87,
                                                                                  fontSize: FFAppState().chatFontSize,
                                                                                ),
                                                                          ),
                                                                        ],
                                                                        if (_isTranslating)
                                                                          const Padding(
                                                                            padding:
                                                                                EdgeInsets.only(top: 8.0),
                                                                            child:
                                                                                SizedBox(
                                                                              width: 16,
                                                                              height: 16,
                                                                              child: CircularProgressIndicator(strokeWidth: 2),
                                                                            ),
                                                                          ),
                                                                      ],
                                                                    )),
                                                              // Via Qurio AI badge for received messages
                                                              if (widget.message?.sentVia == 'qurio_ai')
                                                                Padding(
                                                                  padding: const EdgeInsetsDirectional.fromSTEB(0.0, 4.0, 0.0, 0.0),
                                                                  child: Row(
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    children: [
                                                                      Icon(Icons.smart_toy_outlined, size: 12, color: Color(0xFF0077B5)),
                                                                      SizedBox(width: 3),
                                                                      Text(
                                                                        'via Qurio AI',
                                                                        style: TextStyle(
                                                                          fontFamily: 'SF Pro Text',
                                                                          color: Color(0xFF0077B5),
                                                                          fontSize: 11.0,
                                                                          fontWeight: FontWeight.w500,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              // Edited indicator for received messages
                                                              if (widget.message
                                                                      ?.isEdited ==
                                                                  true)
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsetsDirectional
                                                                          .fromSTEB(
                                                                          0.0,
                                                                          4.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Row(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      Text(
                                                                        'edited',
                                                                        style: FlutterFlowTheme.of(context)
                                                                            .bodySmall
                                                                            .override(
                                                                              color: FlutterFlowTheme.of(context).secondaryText,
                                                                              fontSize: 11.0,
                                                                              fontStyle: FontStyle.italic,
                                                                            ),
                                                                      ),
                                                                      if (widget
                                                                              .message
                                                                              ?.editedAt !=
                                                                          null) ...[
                                                                        Text(
                                                                          ' • ',
                                                                          style: FlutterFlowTheme.of(context)
                                                                              .bodySmall
                                                                              .override(
                                                                                color: FlutterFlowTheme.of(context).secondaryText,
                                                                                fontSize: 11.0,
                                                                              ),
                                                                        ),
                                                                        Text(
                                                                          dateTimeFormat(
                                                                              'MMM d, h:mm a',
                                                                              widget.message!.editedAt!),
                                                                          style: FlutterFlowTheme.of(context)
                                                                              .bodySmall
                                                                              .override(
                                                                                color: FlutterFlowTheme.of(context).secondaryText,
                                                                                fontSize: 11.0,
                                                                                fontStyle: FontStyle.italic,
                                                                              ),
                                                                        ),
                                                                      ],
                                                                    ],
                                                                  ),
                                                                ),
                                                              if (widget.message
                                                                          ?.image !=
                                                                      null &&
                                                                  widget.message
                                                                          ?.image !=
                                                                      '')
                                                                SizedBox(
                                                                  width: 240.0,
                                                                  child: Align(
                                                                  alignment:
                                                                      AlignmentDirectional
                                                                          .centerStart,
                                                                  child:
                                                                      Padding(
                                                                    padding: const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            40.0),
                                                                    child:
                                                                        Stack(
                                                                      clipBehavior:
                                                                          Clip.none,
                                                                      children: [
                                                                        // Image bubble container (reduced size)
                                                                        Container(
                                                                          constraints:
                                                                              BoxConstraints(
                                                                            maxWidth:
                                                                                200.0,
                                                                            maxHeight:
                                                                                260.0,
                                                                          ),
                                                                          width:
                                                                              200.0,
                                                                          margin:
                                                                              const EdgeInsets.only(
                                                                            bottom:
                                                                                4.0,
                                                                          ),
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            color:
                                                                                const Color(0xFFE5E7EB),
                                                                            borderRadius:
                                                                                BorderRadius.circular(8.0),
                                                                          ),
                                                                          child:
                                                                              GestureDetector(
                                                                            onLongPressStart: (details) {
                                                                              if (widget.isSelectionMode) return;
                                                                              widget.onMessageLongPress?.call(
                                                                                widget.message!,
                                                                                details.globalPosition,
                                                                                null,
                                                                              );
                                                                            },
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
                                                                                        widget.message?.image,
                                                                                        'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                                      ),
                                                                                      fit: BoxFit.contain,
                                                                                      errorWidget: (context, error, stackTrace) => Image.asset(
                                                                                        'assets/images/error_image.png',
                                                                                        fit: BoxFit.contain,
                                                                                      ),
                                                                                    ),
                                                                                    allowRotation: false,
                                                                                    tag: '${valueOrDefault<String>(
                                                                                      widget.message?.image,
                                                                                      'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                                    )}_${widget.message?.reference.id ?? ''}',
                                                                                    useHeroAnimation: true,
                                                                                    imageUrl: valueOrDefault<String>(
                                                                                      widget.message?.image,
                                                                                      '',
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              );
                                                                            },
                                                                            child:
                                                                                Hero(
                                                                              tag: '${valueOrDefault<String>(
                                                                                widget.message?.image,
                                                                                'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                              )}_${widget.message?.reference.id ?? ''}',
                                                                              transitionOnUserGestures: true,
                                                                              child: ClipRRect(
                                                                                borderRadius: BorderRadius.circular(8.0),
                                                                                child: CachedNetworkImage(
                                                                                  fadeInDuration: const Duration(milliseconds: 300),
                                                                                  fadeOutDuration: const Duration(milliseconds: 300),
                                                                                  imageUrl: valueOrDefault<String>(
                                                                                    widget.message?.image,
                                                                                    'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                                  ),
                                                                                  width: 200.0,
                                                                                  height: 200.0,
                                                                                  fit: BoxFit.cover,
                                                                                  errorWidget: (context, error, stackTrace) => Image.asset(
                                                                                    'assets/images/error_image.png',
                                                                                    fit: BoxFit.cover,
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
                                                                ),
                                                              if (widget.message
                                                                          ?.video !=
                                                                      null &&
                                                                  widget.message
                                                                          ?.video !=
                                                                      '')
                                                                GestureDetector(
                                                                  onLongPressStart: (details) {
                                                                    if (widget.isSelectionMode) return;
                                                                    widget.onMessageLongPress?.call(
                                                                      widget.message!,
                                                                      details.globalPosition,
                                                                      null,
                                                                    );
                                                                  },
                                                                  child: Container(
                                                                  constraints:
                                                                      BoxConstraints(
                                                                    maxWidth:
                                                                        320.0,
                                                                    maxHeight:
                                                                        400.0,
                                                                  ),
                                                                  width:
                                                                      320.0, // Min width so Chewie controls don't overflow
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
                                                                      topRight:
                                                                          Radius.circular(
                                                                              8.0),
                                                                      bottomLeft:
                                                                          Radius.circular(
                                                                              8.0),
                                                                      bottomRight: Radius.circular((widget.message?.content != null &&
                                                                              widget.message!.content.isNotEmpty &&
                                                                              (widget.message?.attachmentUrl == null || widget.message?.attachmentUrl == ''))
                                                                          ? 0.0
                                                                          : 8.0),
                                                                    ),
                                                                  ),
                                                                  child:
                                                                      ClipRRect(
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .only(
                                                                      topLeft: Radius
                                                                          .circular(
                                                                              8.0),
                                                                      topRight:
                                                                          Radius.circular(
                                                                              8.0),
                                                                      bottomLeft:
                                                                          Radius.circular(
                                                                              8.0),
                                                                      bottomRight: Radius.circular((widget.message?.content != null &&
                                                                              widget.message!.content.isNotEmpty &&
                                                                              (widget.message?.attachmentUrl == null || widget.message?.attachmentUrl == ''))
                                                                          ? 0.0
                                                                          : 8.0),
                                                                    ),
                                                                    child:
                                                                        VideoMessageWidget(
                                                                      videoUrl:
                                                                          widget.message?.video ??
                                                                              '',
                                                                      width:
                                                                          320.0,
                                                                      height:
                                                                          200.0,
                                                                      isOwnMessage:
                                                                          isMe,
                                                                    ),
                                                                  ),
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
                                                                  color: Colors
                                                                      .transparent,
                                                                  elevation:
                                                                      0.0,
                                                                  shape:
                                                                      RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            8.0),
                                                                  ),
                                                                  child:
                                                                      Container(
                                                                    width:
                                                                        200.0,
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: Colors
                                                                          .transparent,
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              8.0),
                                                                    ),
                                                                    child:
                                                                        Builder(
                                                                      builder:
                                                                          (context) {
                                                                        final multipleImages =
                                                                            widget.message?.images.toList() ??
                                                                                [];
                                                                        return Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.min,
                                                                          children: List
                                                                              .generate(
                                                                            multipleImages.length,
                                                                            (multipleImagesIndex) {
                                                                              final multipleImagesItem = multipleImages[multipleImagesIndex];
                                                                              return Stack(
                                                                                clipBehavior: Clip.none,
                                                                                children: [
                                                                                  // Image container
                                                                                  GestureDetector(
                                                                                    onLongPressStart: (details) {
                                                                                      if (widget.isSelectionMode) return;
                                                                                      widget.onMessageLongPress?.call(
                                                                                        widget.message!,
                                                                                        details.globalPosition,
                                                                                        null,
                                                                                      );
                                                                                    },
                                                                                    onTap: () async {
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
                                                                                            tag: '${valueOrDefault<String>(
                                                                                              multipleImagesItem,
                                                                                              'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683$multipleImagesIndex',
                                                                                            )}_${widget.message?.reference.id ?? ''}',
                                                                                            useHeroAnimation: true,
                                                                                            imageUrl: valueOrDefault<String>(
                                                                                              multipleImagesItem,
                                                                                              '',
                                                                                            ),
                                                                                          ),
                                                                                        ),
                                                                                      );
                                                                                    },
                                                                                    child: Hero(
                                                                                      tag: '${valueOrDefault<String>(
                                                                                        multipleImagesItem,
                                                                                        'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683$multipleImagesIndex',
                                                                                      )}_${widget.message?.reference.id ?? ''}',
                                                                                      transitionOnUserGestures: true,
                                                                                      child: ClipRRect(
                                                                                        borderRadius: BorderRadius.circular(8.0),
                                                                                        child: CachedNetworkImage(
                                                                                          fadeInDuration: const Duration(milliseconds: 300),
                                                                                          fadeOutDuration: const Duration(milliseconds: 300),
                                                                                          imageUrl: valueOrDefault<String>(
                                                                                            multipleImagesItem,
                                                                                            'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                                          ),
                                                                                          width: double.infinity,
                                                                                          height: 150.0,
                                                                                          fit: BoxFit.cover,
                                                                                          errorWidget: (context, error, stackTrace) => Image.asset(
                                                                                            'assets/images/error_image.png',
                                                                                            width: double.infinity,
                                                                                            height: 150.0,
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
                                                                              const SizedBox(height: 8.0)),
                                                                        );
                                                                      },
                                                                    ),
                                                                  ),
                                                                ),
                                                              if (widget.message
                                                                          ?.audio !=
                                                                      null &&
                                                                  widget.message
                                                                          ?.audio !=
                                                                      '')
                                                                WeChatVoiceBubble(
                                                                  audioUrl: widget.message!.audioPath,
                                                                  isMe: false,
                                                                ),
                                                              if (widget.message
                                                                          ?.attachmentUrl !=
                                                                      null &&
                                                                  widget.message
                                                                          ?.attachmentUrl !=
                                                                      '')
                                                                _buildFileAttachment(
                                                                    widget
                                                                        .message!
                                                                        .attachmentUrl),
                                                              // Sender name inside bubble (bottom left for received messages)
                                                              if (widget
                                                                      .isGroup &&
                                                                  !widget
                                                                      .isConsecutive)
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsetsDirectional
                                                                          .fromSTEB(
                                                                          0.0,
                                                                          4.0,
                                                                          0.0,
                                                                          0.0),
                                                                  child: Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .start,
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      Text(
                                                                        valueOrDefault<
                                                                            String>(
                                                                          widget
                                                                              .name,
                                                                          'No One',
                                                                        ),
                                                                        style: FlutterFlowTheme.of(context)
                                                                            .bodySmall
                                                                            .override(
                                                                              font: GoogleFonts.inter(),
                                                                              color: const Color(0xFF6B7280),
                                                                              fontSize: 11.0,
                                                                              letterSpacing: 0.0,
                                                                              fontWeight: FontWeight.w600,
                                                                            ),
                                                                      ),
                                                                      if (widget
                                                                              .message
                                                                              ?.isPinned ==
                                                                          true)
                                                                        Padding(
                                                                          padding: const EdgeInsets
                                                                              .only(
                                                                              left: 4.0),
                                                                          child:
                                                                              Icon(
                                                                            Icons.star_rounded,
                                                                            color:
                                                                                const Color(0xFFFFD700),
                                                                            size:
                                                                                14.0,
                                                                          ),
                                                                        ),
                                                                    ],
                                                                  ),
                                                                ),
                                                            ].divide(
                                                                const SizedBox(
                                                                    height:
                                                                        8.0)),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    if (widget.isSelectionMode) {
                      return bubbleContent;
                    }

                    return GestureDetector(
                      onLongPressStart: (details) {
                        if (widget.isSelectionMode) return;
                        widget.onMessageLongPress?.call(
                          widget.message!,
                          details.globalPosition,
                          null,
                        );
                      },
                      child: bubbleContent,
                    );
                  },
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

  // Save video from message
  Future<void> _saveVideo() async {
    debugPrint('========================================');
    debugPrint('=== SAVE VIDEO FROM MENU ===');
    debugPrint('========================================');

    final videoUrl = valueOrDefault<String>(
      widget.message?.video,
      '',
    );

    if (videoUrl.isNotEmpty) {
      // Extract filename from URL, default to .mp4 if no extension found
      String fileName = _getFileNameFromUrl(videoUrl);
      // Ensure it has .mp4 extension if no extension found
      if (!fileName.contains('.')) {
        fileName = '$fileName.mp4';
      } else if (!fileName.toLowerCase().endsWith('.mp4') &&
          !fileName.toLowerCase().endsWith('.mov') &&
          !fileName.toLowerCase().endsWith('.avi') &&
          !fileName.toLowerCase().endsWith('.mkv')) {
        // If it has an extension but not a video extension, add .mp4
        fileName = '${fileName.split('.').first}.mp4';
      }
      debugPrint('Saving video: $fileName');
      await _downloadFile(videoUrl, fileName);
    } else {
      debugPrint('No video found in message!');
      _showSnackBar(
        const SnackBar(
          content: Text('No video found in this message'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadFile(String url, String fileName) async {
    debugPrint('_downloadFile called with URL: $url, fileName: $fileName');

    try {
      // Handle web platform FIRST
      if (kIsWeb) {
        debugPrint('Platform is Web, starting download...');
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
            safeFileName = '$safeFileName.$extension';
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
        return; // ALWAYS return for web
      }

      // Native platforms only below this point
      // macOS - Handle separately to avoid any fallthrough
      if (Platform.isMacOS) {
        debugPrint('Platform is macOS, starting download...');
        try {
          // Sanitize filename
          String safeFileName = fileName;
          safeFileName =
              safeFileName.replaceAll('/', '_').replaceAll('\\', '_');
          safeFileName = safeFileName.split('/').last.split('\\').last;
          if (!safeFileName.contains('.')) {
            safeFileName = '$safeFileName.jpg';
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
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () async {
                  await launchURL('file://${file.path}');
                },
              ),
            ),
          );
        } else {
          throw Exception('Failed to download: ${response.statusCode}');
        }
        return;
      }

      // For mobile platforms (Android/iOS)
      // iOS: Use FilePicker to save to Files app
      if (Platform.isIOS) {
        try {
          // Sanitize filename
          String safeFileName = fileName;
          safeFileName =
              safeFileName.replaceAll('/', '_').replaceAll('\\', '_');
          safeFileName = safeFileName.split('/').last.split('\\').last;

          // Ensure filename has extension
          if (!safeFileName.contains('.')) {
            // Try to detect from URL or default to generic
            final uri = Uri.parse(url);
            final pathSegments = uri.pathSegments;
            if (pathSegments.isNotEmpty) {
              final lastSegment = pathSegments.last;
              if (lastSegment.contains('.')) {
                final ext = lastSegment.split('.').last;
                safeFileName = '$safeFileName.$ext';
              } else {
                safeFileName = '$safeFileName.file';
              }
            } else {
              safeFileName = '$safeFileName.file';
            }
          }

          // Download the file first
          final response = await http.get(Uri.parse(url));
          if (response.statusCode != 200) {
            throw Exception('Failed to download file: ${response.statusCode}');
          }

          // Get file extension for FilePicker
          final fileExtension = safeFileName.contains('.')
              ? safeFileName.split('.').last.toLowerCase()
              : 'file';

          // Determine file type based on extension
          FileType fileType = FileType.any;
          List<String>? allowedExtensions;

          // Map common extensions to file types
          if (['pdf'].contains(fileExtension)) {
            fileType = FileType.custom;
            allowedExtensions = ['pdf'];
          } else if (['xlsx', 'xls'].contains(fileExtension)) {
            fileType = FileType.custom;
            allowedExtensions = ['xlsx', 'xls'];
          } else if (['docx', 'doc'].contains(fileExtension)) {
            fileType = FileType.custom;
            allowedExtensions = ['docx', 'doc'];
          } else if (['pptx', 'ppt'].contains(fileExtension)) {
            fileType = FileType.custom;
            allowedExtensions = ['pptx', 'ppt'];
          } else if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg']
              .contains(fileExtension)) {
            fileType = FileType.custom;
            allowedExtensions = [fileExtension];
          } else {
            // For other file types, use any type
            fileType = FileType.any;
          }

          // Use FilePicker to save file (this makes it accessible in Files app)
          // On iOS/Android, bytes parameter is required
          final result = await FilePicker.platform.saveFile(
            dialogTitle: 'Save File',
            fileName: safeFileName,
            type: fileType,
            allowedExtensions: allowedExtensions,
            bytes: response.bodyBytes, // Required on iOS/Android
          );

          if (result != null && result.isNotEmpty) {
            debugPrint('File saved successfully to: $result');
            _showSuccessPopup('Downloaded');
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
        return; // ALWAYS return for iOS
      }

      // For Android
      if (Platform.isAndroid) {
        // Request storage permission
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
          // Permission handler not available
          // Continue without permission check
        }

        // Download the file
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          // Get the downloads directory
          Directory? directory;
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }

          if (directory != null) {
            // Create unique filename if file already exists
            String finalFileName = fileName;
            int counter = 1;
            while (await File('${directory.path}/$finalFileName').exists()) {
              final extension = fileName.split('.').last;
              final nameWithoutExtension =
                  fileName.replaceAll('.$extension', '');
              finalFileName = '${nameWithoutExtension}_$counter.$extension';
              counter++;
            }

            final file = File('${directory.path}/$finalFileName');
            await file.writeAsBytes(response.bodyBytes);

            _showSuccessPopup('Downloaded');
          }
        } else {
          throw Exception('Failed to download file: ${response.statusCode}');
        }
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

enum _MsgAction {
  react,
  copy,
  report,
  unsend,
  reply,
  edit,
  save,
  translate,
  pin,
  unpin,
  forward,
  select,
  delete,
  download,
}

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
