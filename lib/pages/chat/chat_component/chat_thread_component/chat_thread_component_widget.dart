import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/backend/push_notifications/push_notifications_util.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_media_display.dart';
import '/flutter_flow/flutter_flow_pdf_viewer.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_video_player.dart';
import '/flutter_flow/upload_data.dart';
import '/pages/chat/chat_component/chat_thread/chat_thread_widget.dart';
import '/pages/chat/chat_component/media_preview/media_preview_widget.dart';
import '/pages/chat/chat_component/file_preview/file_preview_widget.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/permissions_util.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '/app_state.dart';
import 'chat_thread_component_model.dart';
export 'chat_thread_component_model.dart';

///
///
class ChatThreadComponentWidget extends StatefulWidget {
  const ChatThreadComponentWidget({
    super.key,
    required this.chatReference,
    this.onMessageLongPress,
  });

  final ChatsRecord? chatReference;
  final Function(MessagesRecord)? onMessageLongPress;

  @override
  State<ChatThreadComponentWidget> createState() =>
      ChatThreadComponentWidgetState();
}

class ChatThreadComponentWidgetState extends State<ChatThreadComponentWidget>
    with TickerProviderStateMixin {
  late ChatThreadComponentModel _model;

  var hasContainerTriggered1 = false;
  var hasContainerTriggered2 = false;
  final animationsMap = <String, AnimationInfo>{};

  // Pagination state
  List<MessagesRecord> _loadedOlderMessages = [];
  DocumentSnapshot?
      _lastLoadedOlderMessageSnapshot; // Last document from older messages query
  bool _isLoadingOlderMessages = false;
  bool _hasMoreOlderMessages = true;
  String? _currentChatId; // Track current chat to reset pagination on change
  static const int _messagesPerPage = 50;
  bool _isDragging = false;
  Timer? _autoMarkReadDebounce;
  String? _lastAutoMarkedLatestMessageId;

  // Mention overlay using proper Overlay API
  final LayerLink _mentionLayerLink = LayerLink();
  OverlayEntry? _mentionOverlayEntry;

  // List of valid usernames for mention highlighting
  List<String> _mentionableUserNames = [];

  // Track total items for pagination triggers
  int _totalMessageCount = 0;

  // Blocked users state (UID based)
  Set<String> _blockedUserIds = {};
  StreamSubscription? _blockedUsersSubscription;

  // Store current messages for external scrolling access
  List<MessagesRecord> _currentMessages = [];

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChatThreadComponentModel());

    _model.messageTextController ??= TextEditingController();
    _model.messageFocusNode ??= FocusNode(
      onKeyEvent: (node, event) {
        // Handle Return/Enter key press
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          // Check if Return/Enter key is pressed
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            
            // CRITICAL FIX: Check for IME composition (active input method)
            // If composing range is valid (start != -1), it means user is navigating IME candidates
            if (_model.messageTextController?.value.composing.isValid == true) {
              return KeyEventResult.ignored; // Let the IME handle it
            }

            // Check if Shift or Command (Meta) is pressed
            final isShiftPressed =
                event.logicalKey == LogicalKeyboardKey.shiftLeft ||
                    event.logicalKey == LogicalKeyboardKey.shiftRight ||
                    HardwareKeyboard.instance.isShiftPressed;
            final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;

            // Get user preference: 0 = Enter sends, 1 = Shift+Enter sends, 2 = Command+Enter sends
            final shortcut = FFAppState().sendMessageShortcut;

            final shouldSend = shortcut == 0
                ? !isShiftPressed
                : shortcut == 1
                    ? isShiftPressed
                    : (shortcut == 2 && isMetaPressed);


            if (shouldSend) {
              // Send message based on preference
              final messageText =
                  _model.messageTextController?.text.trim() ?? '';
              final hasText = messageText.isNotEmpty;
              final hasImages = _model.images.isNotEmpty;
              final hasSingleImage =
                  _model.image != null && _model.image!.isNotEmpty;
              final hasFile = _model.file != null && _model.file!.isNotEmpty;
              final hasAudio =
                  _model.audiopath != null && _model.audiopath!.isNotEmpty;
              final hasVideo = _model.selectedVideoFile != null;
              final hasPendingAttachments = _model.pendingAttachments.isNotEmpty;

              // Check if there's anything to send
              if (hasText ||
                  hasImages ||
                  hasSingleImage ||
                  hasFile ||
                  hasAudio ||
                  hasVideo ||
                  hasPendingAttachments) {
                if (_model.editingMessage != null) {
                  _updateMessage();
                } else {
                  _sendMessage();
                }
                return KeyEventResult.handled; // PREVENT NEWLINE
              } else {
                // If nothing to send, we might want to return handled to prevent newline if we want "Enter does nothing if empty"
                // But usually Enter in empty field -> newline? Or do nothing? 
                // If user wants Enter to Send, then Enter in empty field probably should do nothing or newline.
                // Standard chat apps: Enter in empty field does nothing (no newline).
                return KeyEventResult.handled; 
              }
            }
          }
        }
        return KeyEventResult.ignored;
      },
    );
    _model.messageFocusNode!.addListener(() {
      if (_model.messageFocusNode!.hasFocus && _model.showEmojiPicker) {
        setState(() {
          _model.showEmojiPicker = false;
        });
      }
      if (!_model.messageFocusNode!.hasFocus) {
        // Don't close mention overlay immediately - let tap events process first
        // The overlay will be closed when a selection is made or user taps elsewhere
      }
    });
    _model.itemScrollController ??= ItemScrollController();
    _model.itemPositionsListener ??= ItemPositionsListener.create();

    // Add scroll listener for pagination
    _model.itemPositionsListener?.itemPositions.addListener(_onScroll);

    animationsMap.addAll({
      'containerOnActionTriggerAnimation1': AnimationInfo(
        trigger: AnimationTrigger.onActionTrigger,
        applyInitialState: false,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 300.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
        ],
      ),
      'containerOnActionTriggerAnimation2': AnimationInfo(
        trigger: AnimationTrigger.onActionTrigger,
        applyInitialState: false,
        effectsBuilder: () => [
          ScaleEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: const Offset(0.6, 0.6),
            end: const Offset(1.0, 1.0),
          ),
          ScaleEffect(
            curve: Curves.easeInOut,
            delay: 600.0.ms,
            duration: 600.0.ms,
            begin: const Offset(1.0, 1.0),
            end: const Offset(0.6, 0.6),
          ),
        ],
      ),
    });
    setupAnimations(
      animationsMap.values.where((anim) =>
          anim.trigger == AnimationTrigger.onActionTrigger ||
          !anim.applyInitialState),
      this,
    );

    // Register clipboard listener
    ClipboardEvents.instance?.registerPasteEventListener(_handleClipboardPaste);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      safeSetState(() {});
      // NOTE: Removed auto mark-as-read to prevent badge flickering
      // Messages should only be marked as read when user explicitly interacts
      // _markMessagesAsRead();

      _fetchMentionableUsers();

      // Listen to blocked users in real-time
      _blockedUsersSubscription = BlockedUsersRecord.collection
          .where('blocker_user', isEqualTo: currentUserReference)
          .snapshots()
          .listen((snapshot) {
        setState(() {
          _blockedUserIds = snapshot.docs
              .map((doc) => BlockedUsersRecord.fromSnapshot(doc).blockedUser?.id)
              .whereType<String>()
              .toSet();
          print('Debug: Updated blocked user IDs: $_blockedUserIds');
        });
      });
    });
  }

  @override
  void didUpdateWidget(ChatThreadComponentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // NOTE: Removed auto mark-as-read to prevent badge flickering
    // if (oldWidget.chatReference?.reference != widget.chatReference?.reference) {
    //   _markMessagesAsRead();
    // }
  }

  /// Marks messages as read for the current chat
  /// This marks both individual messages (isReadBy) and chat-level (lastMessageSeen)
  void _markMessagesAsRead() async {
    if (widget.chatReference == null || currentUserReference == null) {
      return;
    }

    final chat = widget.chatReference!;

    // Mark individual messages as read first
    await _markIndividualMessagesAsRead(chat);

    // Then update chat-level lastMessageSeen
    if (!chat.lastMessageSeen.contains(currentUserReference) &&
        chat.lastMessage.isNotEmpty &&
        chat.lastMessageSent != currentUserReference) {
      // Add current user to the lastMessageSeen list
      final updatedSeenList =
          List<DocumentReference>.from(chat.lastMessageSeen);
      if (!updatedSeenList.contains(currentUserReference)) {
        updatedSeenList.add(currentUserReference!);

        // Update Firestore
        chat.reference.update({
          'last_message_seen': updatedSeenList.map((ref) => ref).toList(),
        }).then((_) {
          print(
              '✅ Successfully marked messages as read for chat: ${chat.reference.id}');
        }).catchError((e) {
          print('❌ Error marking messages as read: $e');
        });
      }
    }
  }

  /// Mark individual messages as read by updating isReadBy field
  Future<void> _markIndividualMessagesAsRead(ChatsRecord chat) async {
    if (currentUserReference == null) return;

    try {
      // Get all messages
      final messages = await queryMessagesRecord(
        parent: chat.reference,
        queryBuilder: (messages) => messages
            .orderBy('created_at', descending: true)
            .limit(1000), // Process more messages
      ).first;

      // Batch update messages - Firestore batch limit is 500 operations
      final batch = FirebaseFirestore.instance.batch();
      int updateCount = 0;
      const maxBatchSize = 500;

      for (final message in messages) {
        // Only mark messages that are unread and not sent by current user
        if (message.senderRef != currentUserReference &&
            !message.isSystemMessage &&
            !message.isReadBy.contains(currentUserReference)) {
          final updatedReadBy = List<DocumentReference>.from(message.isReadBy);
          if (!updatedReadBy.contains(currentUserReference)) {
            updatedReadBy.add(currentUserReference!);
            batch.update(message.reference, {
              'is_read_by': updatedReadBy.map((ref) => ref).toList(),
            });
            updateCount++;

            // Commit batch if we reach the limit
            if (updateCount >= maxBatchSize) {
              await batch.commit();
              print(
                  '✅ Marked $updateCount messages as read in chat ${chat.reference.id} (batch)');
              break;
            }
          }
        }
      }

      // Commit batch update if there are changes
      if (updateCount > 0 && updateCount < maxBatchSize) {
        await batch.commit();
        print(
            '✅ Marked $updateCount messages as read in chat ${chat.reference.id}');
      }
    } catch (e) {
      print('❌ Error marking individual messages as read: $e');
    }
  }

  @override
  void dispose() {
    _autoMarkReadDebounce?.cancel();
    _removeMentionOverlay(); // Clean up mention overlay
    _model.itemPositionsListener?.itemPositions.removeListener(_onScroll);
    _blockedUsersSubscription?.cancel();
    _model.maybeDispose();

    // Unregister clipboard listener
    ClipboardEvents.instance?.unregisterPasteEventListener(_handleClipboardPaste);

    super.dispose();
  }

  Future<void> _fetchMentionableUsers() async {
    if (widget.chatReference == null) return;

    try {
      // Get members from chat reference
      final members = widget.chatReference!.members;
      print('DEBUG: Fetching mentionable users for ${members.length} members');
      if (members.isEmpty) return;

      // Fetch user documents
      final futures = members.map((ref) => ref.get()).toList();
      final snapshots = await Future.wait(futures);

      final names = <String>[];
      for (final snap in snapshots) {
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          if (data.containsKey('display_name')) {
            final name = data['display_name'] as String?;
            if (name != null && name.isNotEmpty) {
              names.add(name);
            }
          }
        }
      }

      print('DEBUG: Fetched mentionable users: $names');

      if (mounted) {
        setState(() {
          _mentionableUserNames = names;
        });
      }
    } catch (e) {
      print('Error fetching mentionable users: $e');
    }
  }

  // Reset pagination state when chat changes
  void _resetPagination() {
    setState(() {
      _loadedOlderMessages.clear();
      _lastLoadedOlderMessageSnapshot = null;
      _isLoadingOlderMessages = false;
      _hasMoreOlderMessages = true;
    });
  }

  // Scroll listener to detect when user scrolls to top (for loading older messages)
  void _onScroll() {
    if (_model.itemPositionsListener == null) return;

    final positions = _model.itemPositionsListener!.itemPositions.value;
    if (positions.isEmpty) return;

    // effective max index visible
    final maxIndex = positions
        .where((ItemPosition position) => position.itemTrailingEdge > 0)
        .fold(
            0, (max, position) => position.index > max ? position.index : max);

    // If we are near the end of the list (top of chat view in reverse mode)
    // Trigger load more. Threshold: within last 5 items
    if (maxIndex >= _totalMessageCount - 5) {
      if (!_isLoadingOlderMessages &&
          _hasMoreOlderMessages &&
          widget.chatReference != null) {
        _loadOlderMessages();
      }
    }
  }

  // Load older messages (messages before the currently loaded ones)
  Future<void> _loadOlderMessages() async {
    if (_isLoadingOlderMessages ||
        !_hasMoreOlderMessages ||
        widget.chatReference == null) {
      return;
    }

    setState(() {
      _isLoadingOlderMessages = true;
    });

    try {
      Query query = widget.chatReference!.reference
          .collection('messages')
          .orderBy('created_at', descending: true);

      // If we have a last loaded message snapshot, start after it
      if (_lastLoadedOlderMessageSnapshot != null) {
        query = query.startAfterDocument(_lastLoadedOlderMessageSnapshot!);
      } else {
        // First load: we need to get the oldest message from the stream
        // This will be set when the stream first loads
        setState(() {
          _isLoadingOlderMessages = false;
        });
        return;
      }

      query = query.limit(_messagesPerPage);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMoreOlderMessages = false;
          _isLoadingOlderMessages = false;
        });
        return;
      }

      // Convert to MessagesRecord
      final newMessages =
          snapshot.docs.map((doc) => MessagesRecord.fromSnapshot(doc)).toList();

      // Update state
      setState(() {
        _loadedOlderMessages.addAll(newMessages);
        if (snapshot.docs.length < _messagesPerPage) {
          _hasMoreOlderMessages = false;
        } else {
          _lastLoadedOlderMessageSnapshot = snapshot.docs.last;
        }
        _isLoadingOlderMessages = false;
      });
    } catch (e) {
      print('Error loading older messages: $e');
      setState(() {
        _isLoadingOlderMessages = false;
      });
    }
  }

  Future<void> scrollToMessage(String messageId, [List<MessagesRecord>? messages]) async {
    // 1. Try to find in current list
    if (_tryScrollToMessage(messageId, messages)) {
      return;
    }

    // 2. If not found, try loading older messages
    if (!_hasMoreOlderMessages) {
      print('DEBUG: Message $messageId not found and no more older messages.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Message not found in loaded history.',
            style: TextStyle(
              color: FlutterFlowTheme.of(context).primaryText,
            ),
          ),
          backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Locating message...',
          style: TextStyle(
            color: FlutterFlowTheme.of(context).primaryText,
          ),
        ),
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        duration: const Duration(seconds: 1),
      ),
    );

    int attempts = 0;
    bool found = false;

    // Try loading up to 5 batches (250 messages)
    while (!found && attempts < 5 && _hasMoreOlderMessages) {
      await _loadOlderMessages();
      
      // Give a small delay for UI rebuild to update _currentMessages
      await Future.delayed(const Duration(milliseconds: 200));

      if (_tryScrollToMessage(messageId)) {
        found = true;
      }
      attempts++;
    }

    if (!found) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Message is too far back in history.',
             style: TextStyle(
              color: FlutterFlowTheme.of(context).primaryText,
            ),
          ),
          backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        ),
      );
    }
  }

  bool _tryScrollToMessage(String messageId, [List<MessagesRecord>? messages]) {
    final targetMessages = messages ?? _currentMessages;
    
    print('DEBUG: _tryScrollToMessage for ID: $messageId');
    print('DEBUG: targetMessages length: ${targetMessages.length}');
    
    if (_model.itemScrollController == null) {
      print('DEBUG: itemScrollController is NULL');
      return false;
    }
    if (!_model.itemScrollController!.isAttached) {
      print('DEBUG: itemScrollController is NOT ATTACHED');
      return false;
    }

    int? targetIndex;
    for (int i = 0; i < targetMessages.length; i++) {
      if (targetMessages[i].reference.id == messageId) {
        targetIndex = i;
        print('DEBUG: Found message at index $i in targetMessages list');
        break;
      }
    }

    if (targetIndex != null) {
      // Logic from builder:
      // int messageIndex = _isLoadingOlderMessages ? listViewIndex - 1 : listViewIndex;
      // So listViewIndex = messageIndex + (_isLoadingOlderMessages ? 1 : 0)
      
      int scrollIndex = targetIndex + (_isLoadingOlderMessages ? 1 : 0);
      print('DEBUG: Scrolling to listViewIndex: $scrollIndex (isLoadingOlder: $_isLoadingOlderMessages)');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Found at index $scrollIndex. Scrolling...')),
      );

      _model.itemScrollController!.scrollTo(
        index: scrollIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        alignment: 0.5,
      ).then((_) {
         print('DEBUG: Scroll command sent successfully');
         safeSetState(() {
          _model.highlightedMessageId = messageId;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _model.highlightedMessageId == messageId) {
            safeSetState(() {
              _model.highlightedMessageId = null;
            });
          }
        });
      }).catchError((e) {
        print('DEBUG: Scroll failed with error: $e');
      });
      return true;
    }
    
    print('DEBUG: Message ID not found in current list scan');
    return false;
  }

  Future<void> _updateMessage() async {
    if (_model.editingMessage == null) return;

    try {
      _model.isSending = true;
      safeSetState(() {});

      // Update the existing message directly
      // Strip quotes from mentions before saving
      final editedContent = _stripQuotesFromMentions(
        _model.messageTextController?.text ?? '',
      );
      await _model.editingMessage!.reference.update({
        'content': editedContent,
        'is_edited': true,
        'edited_at': FieldValue.serverTimestamp(),
      });

      // Clear edit mode
      _model.editingMessage = null;
      _model.messageTextController?.clear();
      _model.replyingToMessage = null;
      _model.showEmojiPicker = false;
      safeSetState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update message: $e',
            style: TextStyle(
              color: FlutterFlowTheme.of(context).primaryText,
            ),
          ),
          duration: const Duration(milliseconds: 3000),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    } finally {
      _model.isSending = false;
      safeSetState(() {});
    }
  }

  void _cancelEdit() {
    _model.editingMessage = null;
    _model.messageTextController?.clear();
    _model.replyingToMessage = null;
    safeSetState(() {});
  }

  /// Send a new message to the chat.
  /// [contentOverride] when set (e.g. from file preview caption) is used as the message content instead of the text field.
  Future<void> _sendMessage({String? contentOverride}) async {
    if (widget.chatReference == null || currentUserReference == null) return;

    final messageText = contentOverride ?? (_model.messageTextController?.text.trim() ?? '');
    final hasText = messageText.isNotEmpty;
    final hasImages = _model.images.isNotEmpty;
    final hasSingleImage = _model.image != null && _model.image!.isNotEmpty;
    final hasFile = _model.file != null && _model.file!.isNotEmpty;
    final hasAudio = _model.audiopath != null && _model.audiopath!.isNotEmpty;
    final hasVideo = _model.selectedVideoFile != null;
    final hasPendingAttachments = _model.pendingAttachments.isNotEmpty;

    // Check if there's anything to send
    if (!hasText &&
        !hasImages &&
        !hasSingleImage &&
        !hasFile &&
        !hasAudio &&
        !hasVideo &&
        !hasPendingAttachments) {
      return;
    }

    try {
      _model.isSending = true;
      safeSetState(() {});

      // Upload all pending attachments
      if (hasPendingAttachments) {
        for (final att in List.from(_model.pendingAttachments)) {
          final url = await uploadData(att.file.storagePath, att.file.bytes);
          if (url != null && url.isNotEmpty) {
            switch (att.type) {
              case AttachmentType.image:
                // Collect all images into the images list
                _model.images.add(url);
                break;
              case AttachmentType.video:
                // Assign to selectedVideoFile for the existing video upload path
                _model.selectedVideoFile = att.file;
                break;
              case AttachmentType.file:
                _model.file = url;
                _model.uploadedLocalFile_uploadDataFile = FFUploadedFile(
                  name: att.fileName,
                  bytes: att.file.bytes,
                );
                break;
            }
          }
        }
        _model.clearPendingAttachments();
      }

      // Re-evaluate flags after pending uploads
      final hasImagesNow = _model.images.isNotEmpty;
      final hasImageNow = _model.image != null && _model.image!.isNotEmpty;
      final hasVideoNow = _model.selectedVideoFile != null;
      final hasFileNow = _model.file != null && _model.file!.isNotEmpty;

      // Upload video if selected
      String? videoUrl;
      if (hasVideoNow && _model.selectedVideoFile != null) {
        final selectedFile = _model.selectedVideoFile!;
        videoUrl =
            await uploadData(selectedFile.storagePath, selectedFile.bytes);
      }

      // Upload audio if recorded
      String? audioUrl;
      if (hasAudio) {
        audioUrl = await actions.uploadAudioToStorage(_model.audiopath!);
      }

      // Determine message type
      MessageType messageType = MessageType.text;
      if (hasImagesNow || hasImageNow) {
        messageType = MessageType.image;
      } else if (hasVideoNow && videoUrl != null) {
        messageType = MessageType.video;
      } else if (hasAudio && audioUrl != null) {
        messageType = MessageType.voice;
      } else if (hasFileNow) {
        messageType = MessageType.file;
      }

      // Build images list
      List<String> imagesList = [];
      if (hasImagesNow) {
        imagesList = List<String>.from(_model.images);
      }
      if (hasImageNow) {
        imagesList.add(_model.image!);
      }

      // Create message data
      // Strip quotes from mentions before sending (@"name" -> @name)
      String finalContent = _stripQuotesFromMentions(messageText);
      // For file messages with no caption, use the original filename as content
      if (hasFileNow && messageText.trim().isEmpty) {
        if (_model.uploadedLocalFile_uploadDataFile.name != null) {
          finalContent = _model.uploadedLocalFile_uploadDataFile.name!;
        }
      }

      final messageData = <String, dynamic>{
        'content': finalContent,
        'sender_ref': currentUserReference,
        'sender_name': currentUserDisplayName.isNotEmpty
            ? currentUserDisplayName
            : (currentUserDocument?.displayName ?? 'User'),
        'sender_photo': currentUserPhoto.isNotEmpty
            ? currentUserPhoto
            : (currentUserDocument?.photoUrl ?? ''),
        'created_at': getCurrentTimestamp,
        'message_type': messageType.serialize(),
        'is_read_by': [currentUserReference],
        'is_system_message': false,
      };

      // Add images if present
      if (imagesList.isNotEmpty) {
        messageData['images'] = imagesList;
      }

      // Add video if present
      if (videoUrl != null && videoUrl.isNotEmpty) {
        messageData['video'] = videoUrl;
      }

      // Add audio if present
      if (audioUrl != null && audioUrl.isNotEmpty) {
        messageData['audio'] = audioUrl;
      }

      // Add file if present
      if (hasFileNow) {
        messageData['attachment_url'] = _model.file;
        // Try to get original filename from uploaded file
        if (_model.uploadedLocalFile_uploadDataFile.name != null) {
          messageData['file_name'] =
              _model.uploadedLocalFile_uploadDataFile.name;
        }
      }

      // Add reply context if replying
      if (_model.replyingToMessage != null) {
        messageData['reply_to'] = _model.replyingToMessage!.reference.id;
        messageData['reply_to_content'] = _model.replyingToMessage!.content;
        messageData['reply_to_sender'] = _model.replyingToMessage!.senderName;
      }

      // Create the message document
      final messageRef =
          MessagesRecord.createDoc(widget.chatReference!.reference);
      await messageRef.set(messageData);

      // Check if message contains @linkai and call AI function
      if (functions.containsAIMention(finalContent)) {
        try {
          // Extract chat ID from reference path (chats/chatId -> chatId)
          final chatId = widget.chatReference!.reference.id;
          await actions.callAIAgent(
            chatId,
            finalContent,
          );
        } catch (e) {
          // Log error but don't block message sending
          print('Error calling AI agent: $e');
        }
      }

      // Determine last message text for chat metadata
      String lastMessageText = finalContent;
      if (lastMessageText.isEmpty) {
        if (hasImages || hasImageNow) {
          lastMessageText = '📷 Photo';
        } else if (hasVideoNow) {
          lastMessageText = '🎬 Video';
        } else if (hasAudio) {
          lastMessageText = '🎤 Voice message';
        } else if (hasFileNow) {
          lastMessageText = '📎 File';
        }
      }

      // Update chat's last message metadata
      await widget.chatReference!.reference.update({
        'last_message': lastMessageText,
        'last_message_at': getCurrentTimestamp,
        'last_message_sent': currentUserReference,
        'last_message_type': messageType.serialize(),
        'last_message_seen': [currentUserReference],
      });

      // Send push notifications to other members
      try {
        final chatDoc = widget.chatReference!;
        final otherMembers =
            chatDoc.members.where((m) => m != currentUserReference).toList();

        if (otherMembers.isNotEmpty) {
          final notificationTitle =
              chatDoc.isGroup ? chatDoc.title : currentUserDisplayName;
          print('🔍 DEBUG: Creating notification with:');
          print('   notificationTitle: "$notificationTitle"');
          print('   currentUserDisplayName: "$currentUserDisplayName"');
          print('   chatDoc.isGroup: ${chatDoc.isGroup}');
          print('   chatDoc.title: "${chatDoc.title}"');
          print('   lastMessageText: "$lastMessageText"');
          triggerPushNotification(
            notificationTitle: notificationTitle,
            notificationText: lastMessageText,
            userRefs: otherMembers,
            initialPageName: 'ChatDetail',
            parameterData: {
              'chatDoc': chatDoc.reference.path,
            },
          );
        }
      } catch (e) {
        print('Error sending push notifications: $e');
      }

      // Clear all input state
      _model.messageTextController?.clear();
      _model.images.clear();
      _model.image = null;
      _model.file = null;
      _model.audiopath = null;
      _model.selectedVideoFile = null;
      _model.replyingToMessage = null;
      _model.clearPendingAttachments();
      _model.uploadedFileUrls_uploadData.clear();
      _model.uploadedLocalFiles_uploadData.clear();
      _model.uploadedFileUrl_uploadDataCamera = '';
      _model.uploadedFileUrl_uploadDataFile = '';
      _model.uploadedLocalFile_uploadDataFile =
          FFUploadedFile(bytes: Uint8List.fromList([]));
      _model.showEmojiPicker = false;

      safeSetState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to send message: $e',
            style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
          ),
          duration: const Duration(milliseconds: 3000),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    } finally {
      _model.isSending = false;
      safeSetState(() {});
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MEDIA SELECTION HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _handleSelectImages() async {
    final selectedMedia = await selectMedia(
      context: context,
      mediaSource: MediaSource.photoGallery,
      multiImage: true,
    );
    if (selectedMedia != null && selectedMedia.isNotEmpty) {
      for (final media in selectedMedia) {
        if (!validateFileFormat(media.storagePath, context)) continue;
        final added = _model.addPendingAttachment(PendingAttachment(
          file: media,
          fileName: media.filePath?.split('/').last ?? 'image',
          type: AttachmentType.image,
        ));
        if (!added) {
          _showAttachmentLimitSnackbar();
          break;
        }
      }
      safeSetState(() {});
    }
  }

  void _showAttachmentLimitSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.warning, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text('Maximum 10 attachments allowed')),
          ],
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  /// Preview a pending attachment: fullscreen image, video player, or file download
  void _previewPendingAttachment(PendingAttachment att) {
    switch (att.type) {
      case AttachmentType.image:
        _showImagePreviewDialog(att);
        break;
      case AttachmentType.video:
        _showVideoPreviewDialog(att);
        break;
      case AttachmentType.file:
        _downloadPendingFile(att);
        break;
    }
  }

  /// Fullscreen image viewer with InteractiveViewer (pinch-to-zoom)
  void _showImagePreviewDialog(PendingAttachment att) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black87,
      pageBuilder: (ctx, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.memory(
                      att.file.bytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.xmark,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        att.fileName,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show a video player dialog for a pending video attachment
  void _showVideoPreviewDialog(PendingAttachment att) {
    if (kIsWeb) {
      // Web: use data URI from bytes (no dart:html needed)
      final videoUri = Uri.dataFromBytes(
        att.file.bytes,
        mimeType: 'video/mp4',
      );

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close',
        barrierColor: Colors.black87,
        pageBuilder: (ctx, anim1, anim2) {
          VideoPlayerController? vController;
          ChewieController? cController;
          vController = VideoPlayerController.networkUrl(videoUri);

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              if (cController == null) {
                vController!.initialize().then((_) {
                  cController = ChewieController(
                    videoPlayerController: vController!,
                    autoPlay: true,
                    looping: false,
                  );
                  setDialogState(() {});
                });
              }

              return Scaffold(
                backgroundColor: Colors.transparent,
                body: SafeArea(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: cController != null
                            ? AspectRatio(
                                aspectRatio: vController!.value.aspectRatio,
                                child: Chewie(controller: cController!),
                              )
                            : const CircularProgressIndicator(color: Colors.white),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: GestureDetector(
                          onTap: () {
                            cController?.dispose();
                            vController?.dispose();
                            Navigator.of(ctx).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.xmark,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } else {
      _showVideoFromTempFile(att);
    }
  }

  Future<void> _showVideoFromTempFile(PendingAttachment att) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/${att.fileName}');
    await tempFile.writeAsBytes(att.file.bytes);
    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black87,
      pageBuilder: (ctx, anim1, anim2) {
        final vController = VideoPlayerController.file(tempFile);
        ChewieController? cController;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            if (cController == null) {
              vController.initialize().then((_) {
                cController = ChewieController(
                  videoPlayerController: vController,
                  autoPlay: true,
                  looping: false,
                );
                setDialogState(() {});
              });
            }

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: cController != null
                          ? AspectRatio(
                              aspectRatio: vController.value.aspectRatio,
                              child: Chewie(controller: cController!),
                            )
                          : const CircularProgressIndicator(color: Colors.white),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: () {
                          cController?.dispose();
                          vController.dispose();
                          Navigator.of(ctx).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.xmark,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Download a pending file from memory bytes
  void _downloadPendingFile(PendingAttachment att) {
    if (kIsWeb) {
      // Use the existing cross-platform web download helper
      actions.downloadFileOnWeb('', att.fileName, att.file.bytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading ${att.fileName}...'),
          backgroundColor: FlutterFlowTheme.of(context).primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      _savePendingFileToDevice(att);
    }
  }

  Future<void> _savePendingFileToDevice(PendingAttachment att) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${att.fileName}');
      await file.writeAsBytes(att.file.bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File saved: ${att.fileName}'),
            backgroundColor: FlutterFlowTheme.of(context).primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving file: $e');
    }
  }

  Future<void> _handleCameraCapture() async {
    final selectedMedia = await selectMedia(
      context: context,
      isVideo: false,
      mediaSource: MediaSource.camera,
    );
    if (selectedMedia != null &&
        selectedMedia.isNotEmpty &&
        validateFileFormat(selectedMedia.first.storagePath, context)) {
      final added = _model.addPendingAttachment(PendingAttachment(
        file: selectedMedia.first,
        fileName: selectedMedia.first.filePath?.split('/').last ?? 'photo',
        type: AttachmentType.image,
      ));
      if (!added) _showAttachmentLimitSnackbar();
      safeSetState(() {});
    }
  }

  Future<void> _handleFilePicker() async {
    final pickedFiles = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
      allowMultiple: true,
    );

    if (pickedFiles == null || pickedFiles.files.isEmpty) return;

    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'];
    final videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'wmv', 'm4v', '3gp'];

    for (final pickedFile in pickedFiles.files) {
      if (pickedFile.bytes == null) continue;

      final originalFileName = pickedFile.name;
      final currentUserUid = currentUserReference?.id ?? '';
      final pathPrefix = 'users/$currentUserUid/uploads';
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final ext = originalFileName.contains('.')
          ? originalFileName.split('.').last.toLowerCase()
          : 'file';
      final storagePath = '$pathPrefix/$timestamp.$ext';

      final selectedFile = SelectedFile(
        storagePath: storagePath,
        filePath: kIsWeb ? originalFileName : (pickedFile.path ?? originalFileName),
        bytes: pickedFile.bytes!,
      );

      // Determine attachment type from extension
      AttachmentType type;
      if (imageExtensions.contains(ext)) {
        type = AttachmentType.image;
      } else if (videoExtensions.contains(ext)) {
        type = AttachmentType.video;
      } else {
        type = AttachmentType.file;
      }

      final added = _model.addPendingAttachment(PendingAttachment(
        file: selectedFile,
        fileName: originalFileName,
        type: type,
      ));
      if (!added) {
        _showAttachmentLimitSnackbar();
        break;
      }
    }
    safeSetState(() {});
  }
  Future<void> _handleVideoCapture() async {
    final selectedMedia = await selectMediaWithSourceBottomSheet(
      context: context,
      allowPhoto: false,
      allowVideo: true,
    );
    if (selectedMedia != null &&
        selectedMedia.isNotEmpty &&
        validateFileFormat(selectedMedia.first.storagePath, context)) {
      final added = _model.addPendingAttachment(PendingAttachment(
        file: selectedMedia.first,
        fileName: selectedMedia.first.filePath?.split('/').last ?? 'video',
        type: AttachmentType.video,
      ));
      if (!added) _showAttachmentLimitSnackbar();
      safeSetState(() {});
    }
  }





  /// Handle files dropped via drag-and-drop
  Future<void> _handleDroppedFiles(List<XFile> droppedFiles) async {
    if (droppedFiles.isEmpty) return;

    // Check if it's a service chat (read-only)
    if (_isServiceChatReadOnly()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Cannot send files in service chat')),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'];
    final videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'wmv', 'm4v', '3gp'];

    for (final file in droppedFiles) {
      try {
        final bytes = await file.readAsBytes();
        String fileName = file.name.isNotEmpty ? file.name : file.path.split('/').last;
        final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'file';

        final currentUserUid = currentUserReference?.id ?? '';
        final pathPrefix = 'users/$currentUserUid/uploads';
        final timestamp = DateTime.now().microsecondsSinceEpoch;
        final storagePath = '$pathPrefix/$timestamp.$ext';

        final selectedFile = SelectedFile(
          storagePath: storagePath,
          filePath: kIsWeb ? fileName : file.path,
          bytes: bytes,
        );

        AttachmentType type;
        if (imageExtensions.contains(ext)) {
          type = AttachmentType.image;
        } else if (videoExtensions.contains(ext)) {
          type = AttachmentType.video;
        } else {
          type = AttachmentType.file;
        }

        final added = _model.addPendingAttachment(PendingAttachment(
          file: selectedFile,
          fileName: fileName,
          type: type,
        ));
        if (!added) {
          _showAttachmentLimitSnackbar();
          break;
        }
      } catch (e) {
        debugPrint('Error processing dropped file: $e');
      }
    }
    safeSetState(() {});
  }

  /// Handle clipboard paste events
  void _handleClipboardPaste(ClipboardReadEvent event) async {
    final reader = await event.getClipboardReader();

    // 1. Check for Images
    if (reader.canProvide(Formats.png) ||
        reader.canProvide(Formats.jpeg) ||
        reader.canProvide(Formats.webp)) {
      
      reader.getFile(
        Formats.png,
        (file) async {
          final bytes = await file.readAll();
          final fileName = file.fileName ?? 'pasted_image.png';
          
          final currentUserUid = currentUserReference?.id ?? '';
          final pathPrefix = 'users/$currentUserUid/uploads';
          final timestamp = DateTime.now().microsecondsSinceEpoch;
          final storagePath = '$pathPrefix/$timestamp.png';

          final selectedFile = SelectedFile(
            storagePath: storagePath,
            filePath: fileName,
            bytes: bytes,
          );

          if (mounted) {
            final added = _model.addPendingAttachment(PendingAttachment(
              file: selectedFile,
              fileName: fileName,
              type: AttachmentType.image,
            ));
            if (!added) _showAttachmentLimitSnackbar();
            safeSetState(() {});
          }
        },
        onError: (error) {
           debugPrint('Error reading image from clipboard: $error');
        }
      );
      return;
    }

    // 2. Check for Videos (MP4, MOV, AVI, etc.)
    final videoFormats = [
      Formats.mp4,
      Formats.mov,
      Formats.avi,
      Formats.webm,
      Formats.mkv,
    ];

    for (final format in videoFormats) {
      if (reader.canProvide(format)) {
        reader.getFile(
          format,
          (file) async {
            final bytes = await file.readAll();
            final fileName = file.fileName ?? 'pasted_video.mp4';
            
            final currentUserUid = currentUserReference?.id ?? '';
            final pathPrefix = 'users/$currentUserUid/uploads';
            final timestamp = DateTime.now().microsecondsSinceEpoch;
            final ext = fileName.contains('.') ? fileName.split('.').last : 'mp4';
            final storagePath = '$pathPrefix/$timestamp.$ext';

            final selectedFile = SelectedFile(
              storagePath: storagePath,
              filePath: fileName,
              bytes: bytes,
            );

            if (mounted) {
              final added = _model.addPendingAttachment(PendingAttachment(
                file: selectedFile,
                fileName: fileName,
                type: AttachmentType.video,
              ));
              if (!added) _showAttachmentLimitSnackbar();
              safeSetState(() {});
            }
          },
          onError: (error) {
             debugPrint('Error reading video from clipboard: $error');
          }
        );
        return;
      }
    }

    // 3. Check for Files (PDF, ZIP, etc.)
    final fileFormats = [
      Formats.pdf,
      Formats.zip,
      Formats.plainTextFile, 
      Formats.doc,
      Formats.docx,
      Formats.xls,
      Formats.xlsx,
      Formats.ppt,
      Formats.pptx,
    ];

    for (final format in fileFormats) {
      if (reader.canProvide(format)) {
        reader.getFile(
          format,
          (file) async {
            final bytes = await file.readAll();
            final fileName = file.fileName ?? 'pasted_file';
            
            final currentUserUid = currentUserReference?.id ?? '';
            final pathPrefix = 'users/$currentUserUid/uploads';
            final timestamp = DateTime.now().microsecondsSinceEpoch;
            final ext = fileName.contains('.') ? fileName.split('.').last : 'file';
            final storagePath = '$pathPrefix/$timestamp.$ext';

            final selectedFile = SelectedFile(
              storagePath: storagePath,
              filePath: fileName,
              bytes: bytes,
            );

            if (mounted) {
              final added = _model.addPendingAttachment(PendingAttachment(
                file: selectedFile,
                fileName: fileName,
                type: AttachmentType.file,
              ));
              if (!added) _showAttachmentLimitSnackbar();
              safeSetState(() {});
            }
          },
          onError: (error) {
             debugPrint('Error reading file from clipboard: $error');
          }
        );
        return;
      }
    }
  }

  void _toggleEmojiPicker() {
    // Close keyboard if open
    if (_model.messageFocusNode?.hasFocus ?? false) {
      _model.messageFocusNode?.unfocus();
    }

    setState(() {
      _model.showEmojiPicker = !_model.showEmojiPicker;
    });
  }

  void _openMentionPopup() {
    // Only open if it's a group chat
    if (widget.chatReference == null || !widget.chatReference!.isGroup) {
      return;
    }

    // Insert @ symbol at cursor position
    final controller = _model.messageTextController;
    if (controller != null) {
      final text = controller.text;
      final selection = controller.selection;
      final cursorPosition =
          selection.start >= 0 ? selection.start : text.length;

      // Insert @ at cursor
      final newText = text.replaceRange(cursorPosition, cursorPosition, '@');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursorPosition + 1),
      );

      // Trigger mention detection to show popup
      _handleMentionDetection(newText);
    } else {
      // If no controller, just trigger mention detection with @
      _model.mentionQuery = '';
      _model.showMentionOverlay = true;
      _filterGroupMembers('');
    }
  }

  Widget _buildInlineEmojiPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 320,
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      child: Column(
        children: [
          // Emoji Picker - Full featured like WhatsApp
          Expanded(
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                _insertEmoji(emoji.emoji);
              },
              onBackspacePressed: () {
                final controller = _model.messageTextController;
                if (controller != null && controller.text.isNotEmpty) {
                  final text = controller.text;
                  final selection = controller.selection;
                  if (selection.start > 0) {
                    // Handle emoji deletion (emojis can be multiple chars)
                    final newText = text.substring(0, selection.start - 1) +
                        text.substring(selection.end);
                    controller.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(
                        offset: selection.start - 1,
                      ),
                    );
                  }
                }
              },
              config: Config(
                height: 320,
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
                  showBackspaceButton: true,
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
        ],
      ),
    );
  }

  void _insertEmoji(String emoji) {
    final controller = _model.messageTextController;
    if (controller == null) return;

    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, emoji);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: start + emoji.length,
      ),
    );
    safeSetState(() {});
  }

  /// Strip quotes from mentions in message text
  /// Converts @"name with spaces" to @name with spaces (without quotes)
  String _stripQuotesFromMentions(String text) {
    // Match quoted mentions: @"name with spaces"
    final quotedMentionRegex = RegExp(r'@"([^"]+)"');
    return text.replaceAllMapped(quotedMentionRegex, (match) {
      // Replace @"name" with @name
      return '@${match.group(1)}';
    });
  }

  // Handle mention detection and filtering
  void _handleMentionDetection(String text) {
    if (widget.chatReference == null || !widget.chatReference!.isGroup) {
      _removeMentionOverlay();
      _model.showMentionOverlay = false;
      return;
    }

    final mentionQuery = functions.extractMentionQuery(text);

    // Check if text ends with @ (user just typed @)
    final textTrimmed = text.trim();
    final hasActiveAt = textTrimmed.endsWith('@') ||
        (text.isNotEmpty &&
            text[text.length - 1] == '@' &&
            (text.length == 1 ||
                text[text.length - 2] == ' ' ||
                text[text.length - 2] == '\n'));

    if (mentionQuery != null || hasActiveAt) {
      _model.mentionQuery = mentionQuery ?? '';
      _model.showMentionOverlay = true;
      _filterGroupMembers(mentionQuery ?? '');
    } else {
      _removeMentionOverlay();
      _model.showMentionOverlay = false;
    }
  }

  // Filter group members based on mention query
  Future<void> _filterGroupMembers(String query) async {
    if (widget.chatReference == null || currentUserReference == null) {
      return;
    }

    try {
      final chat = widget.chatReference!;
      final members = chat.members;

      // Load all member user records
      final memberUsers = <UsersRecord>[];
      for (final memberRef in members) {
        if (memberRef.id == currentUserReference?.id) continue;
        try {
          final user = await UsersRecord.getDocumentOnce(memberRef);
          memberUsers.add(user);
        } catch (e) {
          // Skip if user not found
          continue;
        }
      }

      // Filter based on query
      final lowerQuery = query.toLowerCase();
      final filtered = memberUsers.where((user) {
        final name = user.displayName.toLowerCase();
        final email = user.email.toLowerCase();
        return name.contains(lowerQuery) || email.contains(lowerQuery);
      }).toList();

      _model.filteredMembers = filtered;

      // Show the overlay using proper Overlay API
      if (mounted && _model.showMentionOverlay) {
        _showMentionOverlay();
      }
    } catch (e) {
      // Error filtering members
    }
  }

  int _findLastAtIndex(String text, int cursorPosition) {
    for (int i = cursorPosition - 1; i >= 0; i--) {
      if (text[i] == '@') {
        if (i == 0 || text[i - 1] == ' ' || text[i - 1] == '\n') {
          return i;
        }
      } else if (text[i] == ' ' || text[i] == '\n') {
        break;
      }
    }
    return -1;
  }

  void _selectLinkAIMention() {
    final controller = _model.messageTextController;
    if (controller == null) return;

    final text = controller.text;
    final selection = controller.selection;
    final cursorPosition = selection.start >= 0 ? selection.start : text.length;

    // Find the @ symbol before the cursor
    int lastAtIndex = _findLastAtIndex(text, cursorPosition);

    final mentionText = '@linkai ';
    final newText = lastAtIndex == -1
        ? text.replaceRange(cursorPosition, cursorPosition, mentionText)
        : text.replaceRange(lastAtIndex, cursorPosition, mentionText);

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (lastAtIndex == -1 ? cursorPosition : lastAtIndex) +
            mentionText.length,
      ),
    );

    _model.showMentionOverlay = false;
    _model.mentionQuery = '';

    // Re-focus the text field and trigger mention detection to ensure overlay stays hidden
    _model.messageFocusNode?.requestFocus();

    // Trigger mention detection after a short delay to ensure overlay is hidden
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _model.messageTextController != null) {
        _handleMentionDetection(_model.messageTextController!.text);
      }
    });

    safeSetState(() {});
  }

  void _selectUserMention(UsersRecord user) {
    _insertMention(user);
    _removeMentionOverlay();
    _model.showMentionOverlay = false;

    // Re-focus the text field
    _model.messageFocusNode?.requestFocus();
  }

  // Insert mention into text
  void _insertMention(UsersRecord user) {
    final controller = _model.messageTextController;
    if (controller == null) return;

    final text = controller.text;
    final selection = controller.selection;
    final cursorPosition = selection.start >= 0 ? selection.start : text.length;

    // Find the @ symbol before the cursor
    int lastAtIndex = -1;
    for (int i = cursorPosition - 1; i >= 0; i--) {
      if (text[i] == '@') {
        // Check if @ is at start or preceded by whitespace
        if (i == 0 || text[i - 1] == ' ' || text[i - 1] == '\n') {
          lastAtIndex = i;
          break;
        }
      } else if (text[i] == ' ' || text[i] == '\n') {
        // Stop searching if we hit whitespace before finding @
        break;
      }
    }

    if (lastAtIndex == -1) {
      // If no @ found, just insert at cursor
      final mentionText = '@${user.displayName} ';
      final newText =
          text.replaceRange(cursorPosition, cursorPosition, mentionText);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: cursorPosition + mentionText.length,
        ),
      );
    } else {
      // Replace from @ to cursor position
      final mentionText = '@${user.displayName} ';
      final newText =
          text.replaceRange(lastAtIndex, cursorPosition, mentionText);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: lastAtIndex + mentionText.length,
        ),
      );
    }

    _model.showMentionOverlay = false;
    _model.mentionQuery = '';
    safeSetState(() {});
  }

  void _removeMentionOverlay() {
    _mentionOverlayEntry?.remove();
    _mentionOverlayEntry = null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MENTION OVERLAY - Using proper Overlay API for guaranteed tap handling
  // ═══════════════════════════════════════════════════════════════════════════

  void _showMentionOverlay() {
    _removeMentionOverlay(); // Remove any existing overlay first

    if (_model.filteredMembers.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    _mentionOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 80,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          child: Container(
            constraints: BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.at,
                        size: 16,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Mention',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      Spacer(),
                      // Close button
                      GestureDetector(
                        onTap: () {
                          _removeMentionOverlay();
                          _model.showMentionOverlay = false;
                          _model.mentionQuery = '';
                        },
                        child: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          size: 20,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
                // LinkAI option (if query matches "link" or empty)
                if (_model.mentionQuery.isEmpty ||
                    'linkai'.startsWith(_model.mentionQuery.toLowerCase()))
                  _buildMentionItem(
                    onTap: () => _selectLinkAIMention(),
                    avatar: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        ),
                      ),
                      child: Icon(CupertinoIcons.sparkles,
                          size: 18, color: Colors.white),
                    ),
                    name: 'LinkAI',
                    subtitle: 'AI Assistant',
                    isDark: isDark,
                  ),
                // Members list
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _model.filteredMembers.length,
                    itemBuilder: (context, index) {
                      final user = _model.filteredMembers[index];
                      return _buildMentionItem(
                        onTap: () => _selectUserMention(user),
                        avatar: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                          child: user.photoUrl.isNotEmpty
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: user.photoUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Center(
                                      child: Text(
                                        user.displayName.isNotEmpty
                                            ? user.displayName[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    user.displayName.isNotEmpty
                                        ? user.displayName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                        ),
                        name: user.displayName,
                        subtitle: user.email,
                        isDark: isDark,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_mentionOverlayEntry!);
  }

  Widget _buildMentionItem({
    required VoidCallback onTap,
    required Widget avatar,
    required String name,
    required String subtitle,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              avatar,
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reset pagination when chat changes
    final currentChatId = widget.chatReference?.reference.id;
    if (currentChatId != null && _currentChatId != currentChatId) {
      _currentChatId = currentChatId;
      _resetPagination();
    }

    // NOTE: Removed automatic mark-as-read during build to prevent badge flickering
    // Messages are only marked as read in initState and didUpdateWidget

    return DropTarget(
      onDragEntered: (details) {
        if (!_isServiceChatReadOnly()) {
          setState(() => _isDragging = true);
        }
      },
        onDragExited: (details) {
          setState(() => _isDragging = false);
        },
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        if (!_isServiceChatReadOnly()) {
          await _handleDroppedFiles(details.files);
        }
      },
      child: Stack(
        children: [
          GestureDetector(
            onTap: () async {
              _model.select = false;
              // Close emoji picker on tap outside
              if (_model.showEmojiPicker) {
                _model.showEmojiPicker = false;
              }
              safeSetState(() {});
            },
            child: Container(
              decoration: const BoxDecoration(),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: StreamBuilder<List<MessagesRecord>>(
                          stream: queryMessagesRecord(
                            parent: widget.chatReference?.reference,
                            queryBuilder: (messagesRecord) => messagesRecord
                                .orderBy('created_at', descending: true)
                                .limit(
                                    _messagesPerPage), // Load initial 50 messages
                          ),
                          builder: (context, snapshot) {
                            // NOTE: Removed automatic mark-as-read during stream update to prevent badge flickering
                            // Customize what your widget looks like when it's loading.
                            if (!snapshot.hasData) {
                              return Center(
                                child: SizedBox(
                                  width: 50.0,
                                  height: 50.0,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      FlutterFlowTheme.of(context).primary,
                                    ),
                                  ),
                                ),
                              );
                            }

                            // Get recent messages from stream (latest 50)
                            List<MessagesRecord> recentMessages =
                                snapshot.data!;

                            // Initialize pagination marker from stream's oldest message (first time only)
                            if (recentMessages.isNotEmpty &&
                                _lastLoadedOlderMessageSnapshot == null &&
                                _loadedOlderMessages.isEmpty) {
                              // Get the document snapshot for the oldest message in the stream
                              // This will be used to load messages older than the initial 50
                              final oldestMessage = recentMessages
                                  .last; // Last in descending order is oldest
                              oldestMessage.reference.get().then((docSnapshot) {
                                if (docSnapshot.exists && mounted) {
                                  setState(() {
                                    _lastLoadedOlderMessageSnapshot =
                                        docSnapshot;
                                  });
                                }
                              }).catchError((e) {
                                print(
                                    'Error getting oldest message snapshot: $e');
                              });
                            }

                            // Merge with loaded older messages
                            // Recent messages are newest first, older messages are also newest first
                            // We need to combine them: older messages go before recent messages
                            List<MessagesRecord> listViewMessagesRecordList =
                                [];

                            // Add older messages first (they're already in descending order)
                            listViewMessagesRecordList
                                .addAll(_loadedOlderMessages);

                            // Then add recent messages, avoiding duplicates
                            final olderMessageIds = _loadedOlderMessages
                                .map((m) => m.reference.id)
                                .toSet();
                            for (final message in recentMessages) {
                              if (!olderMessageIds
                                  .contains(message.reference.id)) {
                                listViewMessagesRecordList.add(message);
                              }
                            }

                            // Sort by created_at descending to ensure correct order
                            listViewMessagesRecordList.sort((a, b) {
                              final aTime = a.createdAt;
                              final bTime = b.createdAt;
                              if (aTime == null && bTime == null) return 0;
                              if (aTime == null) return 1;
                              if (bTime == null) return -1;
                              return bTime.compareTo(aTime);
                            });

                            // Filter out messages from blocked users (UID based)
                            listViewMessagesRecordList = listViewMessagesRecordList
                                .where((message) {
                                  final senderId = message.senderRef?.id;
                                  final isBlocked = senderId != null && _blockedUserIds.contains(senderId);
                                  if (isBlocked) {
                                    print('Debug: Filtering blocked message from $senderId');
                                  }
                                  return !isBlocked;
                                })
                                .toList();

                            // Update local state for external access
                            _currentMessages = listViewMessagesRecordList;

                            // Update total count for pagination and scroll logic
                            _totalMessageCount =
                                listViewMessagesRecordList.length +
                                    (_isLoadingOlderMessages ? 1 : 0);

                            return GestureDetector(
                              onTap: () async {
                                await actions.closekeyboard();
                              },
                              child: ScrollablePositionedList.builder(
                                itemScrollController:
                                    _model.itemScrollController,
                                itemPositionsListener:
                                    _model.itemPositionsListener,
                                padding: EdgeInsets.only(
                                  top: 120 + (_isLoadingOlderMessages ? 50 : 0),
                                  bottom:
                                      100 + (_model.showEmojiPicker ? 320 : 0),
                                ),
                                reverse: true,
                                shrinkWrap: false,
                                scrollDirection: Axis.vertical,
                                itemCount: _totalMessageCount,
                                itemBuilder: (context, listViewIndex) {
                                  // Show loading indicator at the top (first item in reversed list)
                                  if (_isLoadingOlderMessages &&
                                      listViewIndex == 0) {
                                    return Container(
                                      padding: EdgeInsets.all(16.0),
                                      alignment: Alignment.center,
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          FlutterFlowTheme.of(context).primary,
                                        ),
                                      ),
                                    );
                                  }

                                  // Adjust index if loading indicator is shown
                                  int messageIndex = _isLoadingOlderMessages
                                      ? listViewIndex - 1
                                      : listViewIndex;

                                  if (messageIndex < 0 ||
                                      messageIndex >=
                                          listViewMessagesRecordList.length) {
                                    return SizedBox.shrink();
                                  }

                                  final listViewMessagesRecord =
                                      listViewMessagesRecordList[messageIndex];
                                  return Container(
                                    child: wrapWithModel<ChatThreadModel>(
                                      model: _model.chatThreadModels.getModel(
                                        listViewMessagesRecord.reference.id,
                                        messageIndex,
                                      ),
                                      updateCallback: () => safeSetState(() {}),
                                      child: ChatThreadWidget(
                                        key: Key(
                                          'Key6sf_${listViewMessagesRecord.reference.id}',
                                        ),
                                        message: listViewMessagesRecord,
                                        senderImage:
                                            listViewMessagesRecord.senderPhoto,
                                        name: listViewMessagesRecord.senderName,
                                        chatRef:
                                            widget.chatReference!.reference,
                                        userRef:
                                            listViewMessagesRecord.senderRef!,
                                        mentionableUsers: _mentionableUserNames,
                                        action: () async {
                                          _model.select = false;
                                          safeSetState(() {});
                                        },
                                        onMessageLongPress:
                                            widget.onMessageLongPress,
                                        onReplyToMessage: (message) {
                                          _model.replyingToMessage = message;
                                          safeSetState(() {});
                                        },
                                        onScrollToMessage: (messageId) {
                                          scrollToMessage(messageId,
                                              listViewMessagesRecordList);
                                        },
                                        onEditMessage: (message) {
                                          _model.editingMessage = message;
                                          _model.messageTextController?.text =
                                              message.content;
                                          safeSetState(() {});
                                        },
                                        isHighlighted: _model
                                                .highlightedMessageId ==
                                            listViewMessagesRecord.reference.id,
                                        isGroup:
                                            widget.chatReference?.isGroup ??
                                                false,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  // ═══════════════════════════════════════════════════════════
                  // FLOATING INPUT BAR - OVERLAYS SCROLLING CONTENT
                  // Messages scroll BEHIND this, shadows visible through glass
                  // ═══════════════════════════════════════════════════════════
                  // Emoji Picker Panel (Bottom Layer)
                  if (_model.showEmojiPicker)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 320,
                      child: _buildInlineEmojiPicker(),
                    ),

                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _model.showEmojiPicker ? 320 : 0,
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Reply/Edit Preview Banner - Floating Liquid Glass
                          if (_model.replyingToMessage != null ||
                              _model.editingMessage != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0, vertical: 10.0),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          FlutterFlowTheme.of(context)
                                              .primary
                                              .withOpacity(0.15),
                                          FlutterFlowTheme.of(context)
                                              .primary
                                              .withOpacity(0.08),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: FlutterFlowTheme.of(context)
                                            .primary
                                            .withOpacity(0.2),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 3,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _model.editingMessage != null
                                                    ? 'Editing Message'
                                                    : 'Replying to ${_model.replyingToMessage?.senderName ?? 'User'}',
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .override(
                                                          fontFamily: 'Inter',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primary,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          letterSpacing: 0.0,
                                                        ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                (_model.editingMessage
                                                            ?.content ??
                                                        _model.replyingToMessage
                                                            ?.content ??
                                                        '')
                                                    .replaceAll('\n', ' '),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .override(
                                                          fontFamily: 'Inter',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          letterSpacing: 0.0,
                                                        ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: _cancelEdit,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText
                                                      .withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              CupertinoIcons.xmark,
                                              size: 16,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Preview moved inside the input container
                          // Main Input Row
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // ═══════════════════════════════════════════
                                // ADAPTIVE + BUTTON WITH POPUP MENU
                                // ═══════════════════════════════════════════
                                AdaptivePopupMenuButton.widget<String>(
                                  items: [
                                    AdaptivePopupMenuItem(
                                      label: 'Camera',
                                      icon: PlatformInfo.isIOS26OrHigher()
                                          ? 'camera'
                                          : Icons.camera_alt,
                                      value: 'camera',
                                    ),
                                    AdaptivePopupMenuItem(
                                      label: 'Images',
                                      icon: PlatformInfo.isIOS26OrHigher()
                                          ? 'photo.on.rectangle'
                                          : Icons.image_rounded,
                                      value: 'images',
                                    ),
                                    AdaptivePopupMenuItem(
                                      label: 'Video',
                                      icon: PlatformInfo.isIOS26OrHigher()
                                          ? 'video'
                                          : Icons.videocam,
                                      value: 'video',
                                    ),
                                    AdaptivePopupMenuItem(
                                      label: 'File',
                                      icon: PlatformInfo.isIOS26OrHigher()
                                          ? 'paperclip'
                                          : Icons.attach_file_rounded,
                                      value: 'file',
                                    ),
                                  ],
                                  onSelected: (index, item) async {
                                    if (_isServiceChatReadOnly()) {
                                      return; // Don't allow actions in service chat
                                    }
                                    switch (item.value) {
                                      case 'images':
                                        await _handleSelectImages();
                                        break;
                                      case 'camera':
                                        await _handleCameraCapture();
                                        break;
                                      case 'file':
                                        await _handleFilePicker();
                                        break;
                                      case 'video':
                                        await _handleVideoCapture();
                                        break;
                                    }
                                  },
                                  child: Opacity(
                                    opacity:
                                        _isServiceChatReadOnly() ? 0.3 : 1.0,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(22),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                            sigmaX: 20, sigmaY: 20),
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            // 🔮 Ultra Glass - very subtle
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                (Theme.of(context).brightness ==
                                                            Brightness.dark
                                                        ? Colors.white
                                                        : Colors.black)
                                                    .withOpacity(0.05),
                                                (Theme.of(context).brightness ==
                                                            Brightness.dark
                                                        ? Colors.white
                                                        : Colors.black)
                                                    .withOpacity(0.02),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(22),
                                            border: Border.all(
                                              color: (Theme.of(context)
                                                              .brightness ==
                                                          Brightness.dark
                                                      ? Colors.white
                                                      : Colors.black)
                                                  .withOpacity(0.08),
                                              width: 0.5,
                                            ),
                                          ),
                                          child: Icon(
                                            CupertinoIcons.plus,
                                            size: 22,
                                            color: CupertinoColors.systemBlue,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // ═══════════════════════════════════════════
                                // TEXT INPUT WITH INLINE SEND BUTTON (iMessage style)
                                // ═══════════════════════════════════════════
                                Expanded(
                                  child: _isServiceChatReadOnly()
                                      ? _buildServiceChatReadOnlyMessage()
                                      : ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(22),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                                sigmaX: 20, sigmaY: 20),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                // 🔮 Ultra Glass - very subtle
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    (Theme.of(context)
                                                                    .brightness ==
                                                                Brightness.dark
                                                            ? Colors.white
                                                            : Colors.black)
                                                        .withOpacity(0.05),
                                                    (Theme.of(context)
                                                                    .brightness ==
                                                                Brightness.dark
                                                            ? Colors.white
                                                            : Colors.black)
                                                        .withOpacity(0.02),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(22),
                                                border: Border.all(
                                                  color: (Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withOpacity(0.08),
                                                  width: 0.5,
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  // Attachment Previews (Inside Input Box)
                                                  _buildAttachmentPreviews(),

                                                  Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  // Emoji Button
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _toggleEmojiPicker(),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 12,
                                                              bottom: 10),
                                                      child: Icon(
                                                        CupertinoIcons.smiley,
                                                        size: 24,
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                      ),
                                                    ),
                                                  ),
                                                  // @ Mention Button (only show for group chats)
                                                  if (widget.chatReference !=
                                                          null &&
                                                      widget.chatReference!
                                                          .isGroup)
                                                    GestureDetector(
                                                      onTap: () =>
                                                          _openMentionPopup(),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 8,
                                                                bottom: 10),
                                                        child: Icon(
                                                          CupertinoIcons.at,
                                                          size: 24,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                        ),
                                                      ),
                                                    ),
                                                  // Text Input
                                                  Expanded(
                                                    child: CupertinoTextField(
                                                      controller: _model
                                                          .messageTextController,
                                                      focusNode: _model
                                                          .messageFocusNode,
                                                      placeholder: _model
                                                                  .editingMessage !=
                                                              null
                                                          ? 'Edit your message...'
                                                          : 'Message...',
                                                      placeholderStyle:
                                                          TextStyle(
                                                        color: FlutterFlowTheme
                                                                .of(context)
                                                            .secondaryText
                                                            .withOpacity(0.6),
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                      ),
                                                      style: TextStyle(
                                                        color: FlutterFlowTheme
                                                                .of(context)
                                                            .primaryText,
                                                        fontSize: 16,
                                                      ),
                                                      padding:
                                                          const EdgeInsets
                                                              .only(
                                                        left: 8,
                                                        right: 8,
                                                        top: 12,
                                                        bottom: 12,
                                                      ),
                                                      decoration:
                                                          const BoxDecoration(
                                                        color: Colors
                                                            .transparent,
                                                      ),
                                                      minLines: 1,
                                                      maxLines: 5,
                                                      textInputAction:
                                                          TextInputAction
                                                              .newline,
                                                      onChanged: (value) {
                                                        // Handle mention detection
                                                        _handleMentionDetection(
                                                            value);
                                                      },
                                                    ),
                                                  ),
                                                  // ═══════════════════════════════════════
                                                  // INLINE SEND BUTTON - System Blue, iMessage style
                                                  // ═══════════════════════════════════════
                                                  AnimatedOpacity(
                                                    opacity:
                                                        1.0, // Always visible
                                                    duration: const Duration(
                                                        milliseconds: 150),
                                                    child: AnimatedScale(
                                                      scale:
                                                          1.0, // Always full scale
                                                      duration: const Duration(
                                                          milliseconds: 150),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                right: 6,
                                                                bottom: 6),
                                                        child: GestureDetector(
                                                          onTap: () async {
                                                            if (_model
                                                                    .editingMessage !=
                                                                null) {
                                                              await _updateMessage();
                                                            } else {
                                                              await _sendMessage();
                                                            }
                                                          },
                                                          child: Container(
                                                            width: 32,
                                                            height: 32,
                                                            decoration:
                                                                BoxDecoration(
                                                              // System Blue
                                                              color:
                                                                  CupertinoColors
                                                                      .systemBlue,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                            child: _model
                                                                        .isSending ==
                                                                    true
                                                                ? const CupertinoActivityIndicator(
                                                                    color: Colors
                                                                        .white,
                                                                    radius: 8,
                                                                  )
                                                                : const Icon(
                                                                    CupertinoIcons
                                                                        .arrow_up,
                                                                    size: 18,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isDragging)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue.withOpacity(0.15),
                  border: Border.all(
                    color: CupertinoColors.systemBlue,
                    width: 3.0,
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.8)
                          : Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_upload_rounded,
                          size: 64,
                          color: CupertinoColors.systemBlue,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Drop files to upload',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Images, PDFs, and documents supported',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_model.isDataUploading_uploadData ||
              _model.isDataUploading_uploadDataFile ||
              _model.isDataUploading_uploadDataVideo ||
              _model.isDataUploading_uploadDataCamera ||
              _model.isSendingImage == true)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 30),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1E1E1E).withOpacity(0.9)
                          : Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Creative combined animation
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.cloud_fill,
                              size: 70,
                              color:
                                  CupertinoColors.systemBlue.withOpacity(0.2),
                            )
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .scale(
                                  begin: const Offset(0.9, 0.9),
                                  end: const Offset(1.1, 1.1),
                                  duration: 1000.ms,
                                  curve: Curves.easeInOut,
                                ),
                            Icon(
                              CupertinoIcons.arrow_up_circle_fill,
                              size: 40,
                              color: CupertinoColors.systemBlue,
                            )
                                .animate(onPlay: (c) => c.repeat())
                                .moveY(
                                  begin: 10,
                                  end: -10,
                                  duration: 800.ms,
                                  curve: Curves.easeInOut,
                                )
                                .fadeIn(duration: 400.ms)
                                .then()
                                .fadeOut(duration: 400.ms, delay: 400.ms),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Uploading...',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ).animate(onPlay: (c) => c.repeat()).shimmer(
                              duration: 1500.ms,
                              color:
                                  CupertinoColors.systemBlue.withOpacity(0.5),
                              size: 0.5,
                            ),
                        const SizedBox(height: 8),
                        Text(
                          'Just a moment',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white54
                                    : Colors.black45,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ).animate().scale(
                        duration: 400.ms,
                        curve: Curves.easeOutBack,
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1.0, 1.0),
                      ),
                ),
              ),
            ).animate().fadeIn(duration: 200.ms),
          // Mention Overlay is handled by OverlayEntry (_showMentionOverlay)
        ],
      ),
    );
  }

  // Check if chat is a service chat and current user is not lona-service
  bool _isServiceChatReadOnly() {
    if (widget.chatReference == null || currentUserReference == null) {
      return false;
    }

    final chat = widget.chatReference!;
    final isServiceChat = chat.isServiceChat;
    final isLonaService = currentUserReference?.id == 'lona-service';

    return isServiceChat && !isLonaService;
  }

  // Build read-only message for service chats
  Widget _buildServiceChatReadOnlyMessage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black)
                    .withOpacity(0.05),
                (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black)
                    .withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black)
                  .withOpacity(0.08),
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.info,
                size: 16,
                color:
                    FlutterFlowTheme.of(context).secondaryText.withOpacity(0.6),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Only Lona Service can send messages',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context)
                        .secondaryText
                        .withOpacity(0.6),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // Attachment Previews - Discord-Style Helper
  Widget _buildAttachmentPreviews() {
    // Check if we have any attachments
    bool hasAttachments = _model.images.isNotEmpty ||
        _model.image != null ||
        _model.file != null ||
        _model.audiopath != null ||
        _model.selectedVideoFile != null ||
        _model.pendingAttachments.isNotEmpty;

    if (!hasAttachments) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Multiple Images Preview (already uploaded URLs)
            ..._model.images.map((imageUrl) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            _model.removeFromImages(imageUrl);
                            safeSetState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.xmark,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            // Single Image Preview (uploaded URL)
            if (_model.image != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: _model.image!,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          _model.image = null;
                          safeSetState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.xmark,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // ═══ PENDING ATTACHMENTS (unified list) ═══
            ..._model.pendingAttachments.asMap().entries.map((entry) {
              final index = entry.key;
              final att = entry.value;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _previewPendingAttachment(att),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: att.type == AttachmentType.image
                                ? Image.memory(
                                    att.file.bytes,
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                    cacheWidth: 140,
                                    cacheHeight: 140,
                                  )
                                : Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .primaryBackground
                                          .withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: FlutterFlowTheme.of(context)
                                            .primary
                                            .withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      att.type == AttachmentType.video
                                          ? CupertinoIcons.play_circle_fill
                                          : CupertinoIcons.doc_fill,
                                      size: 32,
                                      color: FlutterFlowTheme.of(context).primary,
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              _model.removePendingAttachmentAt(index);
                              safeSetState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.xmark,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 70,
                      child: Text(
                        att.fileName,
                        style: TextStyle(
                          fontSize: 10,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            }),
            // Video Preview (existing - already selected video file)
            if (_model.selectedVideoFile != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context)
                              .primaryBackground
                              .withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context)
                                .primary
                                .withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          CupertinoIcons.play_circle_fill,
                          size: 32,
                          color: FlutterFlowTheme.of(context).primary,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          _model.selectedVideoFile = null;
                          safeSetState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.xmark,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // File Preview (existing - already uploaded URL)
            if (_model.file != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context)
                              .primaryBackground
                              .withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context)
                                .primary
                                .withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          CupertinoIcons.doc_fill,
                          size: 32,
                          color: FlutterFlowTheme.of(context).primary,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          _model.file = null;
                          _model.uploadedFileUrl_uploadDataFile = '';
                          _model.uploadedLocalFile_uploadDataFile =
                              FFUploadedFile(bytes: Uint8List.fromList([]));
                          safeSetState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.xmark,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Audio Preview
            if (_model.audiopath != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).primaryBackground.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).primary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          CupertinoIcons.waveform,
                          size: 32,
                          color: FlutterFlowTheme.of(context).primary,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          _model.audiopath = null;
                          safeSetState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.xmark,
                            size: 12,
                            color: Colors.white,
                          ),
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
}
