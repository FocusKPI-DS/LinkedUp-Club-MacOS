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
import 'package:flutter_animate/flutter_animate.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
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
      _ChatThreadComponentWidgetState();
}

class _ChatThreadComponentWidgetState extends State<ChatThreadComponentWidget>
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
    _model.messageFocusNode ??= FocusNode();
    _model.scrollController ??= ScrollController();

    // Add scroll listener for pagination
    _model.scrollController?.addListener(_onScroll);

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      safeSetState(() {});
      // Mark messages as read when chat thread is displayed
      _markMessagesAsRead();
    });
  }

  @override
  void didUpdateWidget(ChatThreadComponentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If chat reference changed, mark messages as read
    if (oldWidget.chatReference?.reference != widget.chatReference?.reference) {
      _markMessagesAsRead();
    }
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
    _model.scrollController?.removeListener(_onScroll);
    _model.scrollController?.dispose();
    _model.maybeDispose();

    super.dispose();
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
    if (_model.scrollController == null ||
        !_model.scrollController!.hasClients) {
      return;
    }

    // For reversed ListView, maxScrollExtent is at the top (oldest messages)
    // When user scrolls near the top (within 200px), load more older messages
    final position = _model.scrollController!.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
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

  void _scrollToMessage(String messageId, List<MessagesRecord> messages) {
    if (_model.scrollController == null ||
        !_model.scrollController!.hasClients) {
      return;
    }

    // Find the message in the list
    int? targetIndex;
    for (int i = 0; i < messages.length; i++) {
      if (messages[i].reference.id == messageId) {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex == null) return;

    final scrollController = _model.scrollController!;
    final finalTargetIndex =
        targetIndex; // Capture non-nullable value for use in callback

    // Wait for the next frame to ensure layout is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;

      final maxScrollExtent = scrollController.position.maxScrollExtent;
      final minScrollExtent = scrollController.position.minScrollExtent;
      final viewportHeight = scrollController.position.viewportDimension;
      final currentPosition = scrollController.position.pixels;

      // For reversed ListView:
      // - Index 0 is at the bottom (scroll position 0)
      // - Higher indices are at the top (higher scroll positions)
      // - Scroll position = how far we've scrolled from the bottom

      // Calculate the position where the target message starts (from bottom)
      double heightBeforeTarget = 0.0;
      for (int j = 0; j < finalTargetIndex && j < messages.length; j++) {
        heightBeforeTarget += _estimateMessageHeight(messages[j]);
      }

      // Calculate the center of the target message (from bottom)
      final targetMessageHeight =
          _estimateMessageHeight(messages[finalTargetIndex]);
      final messageCenterFromBottom =
          heightBeforeTarget + (targetMessageHeight / 2);

      // Capture for use in fine-tuning callback
      final capturedMessageCenter = messageCenterFromBottom;

      // To center the message with equal space above and below:
      // Scroll so that messageCenterFromBottom is at viewportHeight/2 from top
      // This means: scrollPosition = messageCenterFromBottom - (viewportHeight / 2)
      double targetPosition = messageCenterFromBottom - (viewportHeight / 2);

      // Critical: Ensure we don't scroll beyond bounds
      targetPosition = targetPosition.clamp(minScrollExtent, maxScrollExtent);

      // Additional safety: never scroll to more than 90% of maxScrollExtent
      // This prevents scrolling to the very top
      if (targetPosition > maxScrollExtent * 0.9) {
        targetPosition = maxScrollExtent * 0.9;
      }

      // Also ensure we don't go negative (for messages near the bottom)
      if (targetPosition < 0) {
        targetPosition = 0;
      }

      // Only scroll if the target is significantly different from current position
      if ((targetPosition - currentPosition).abs() > 50.0) {
        scrollController
            .animateTo(
          targetPosition,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        )
            .then((_) {
          // Wait a bit for layout to stabilize, then fine-tune centering
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!scrollController.hasClients) return;

            // Recalculate to ensure perfect centering after layout
            final currentScrollPosition = scrollController.position.pixels;
            final newViewportHeight =
                scrollController.position.viewportDimension;

            // Fine-tune: Recalculate the exact center position
            // This ensures perfect centering with equal space above and below
            final fineTunePosition =
                capturedMessageCenter - (newViewportHeight / 2);
            final adjustment = fineTunePosition - currentScrollPosition;

            // Make adjustment to center the message perfectly
            // Allow larger adjustments (up to 200px) to ensure proper centering
            if (adjustment.abs() > 5) {
              final clampedPosition = fineTunePosition.clamp(
                scrollController.position.minScrollExtent,
                scrollController.position.maxScrollExtent,
              );
              scrollController.animateTo(
                clampedPosition,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });

          // After scrolling completes, highlight the message
          safeSetState(() {
            _model.highlightedMessageId = messageId;
          });

          // Clear highlight after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _model.highlightedMessageId == messageId) {
              safeSetState(() {
                _model.highlightedMessageId = null;
              });
            }
          });
        });
      } else {
        // Even if we don't scroll, still highlight the message
        safeSetState(() {
          _model.highlightedMessageId = messageId;
        });

        // Clear highlight after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _model.highlightedMessageId == messageId) {
            safeSetState(() {
              _model.highlightedMessageId = null;
            });
          }
        });
      }
    });
  }

  Future<void> _updateMessage() async {
    if (_model.editingMessage == null) return;

    try {
      _model.isSending = true;
      safeSetState(() {});

      // Update the existing message directly
      await _model.editingMessage!.reference.update({
        'content': _model.messageTextController?.text ?? '',
        'is_edited': true,
        'edited_at': FieldValue.serverTimestamp(),
      });

      // Clear edit mode
      _model.editingMessage = null;
      _model.messageTextController?.clear();
      _model.replyingToMessage = null;
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

  /// Send a new message to the chat
  Future<void> _sendMessage() async {
    if (widget.chatReference == null || currentUserReference == null) return;

    final messageText = _model.messageTextController?.text.trim() ?? '';
    final hasText = messageText.isNotEmpty;
    final hasImages = _model.images.isNotEmpty;
    final hasSingleImage = _model.image != null && _model.image!.isNotEmpty;
    final hasFile = _model.file != null && _model.file!.isNotEmpty;
    final hasAudio = _model.audiopath != null && _model.audiopath!.isNotEmpty;
    final hasVideo = _model.selectedVideoFile != null;

    // Check if there's anything to send
    if (!hasText &&
        !hasImages &&
        !hasSingleImage &&
        !hasFile &&
        !hasAudio &&
        !hasVideo) {
      return;
    }

    try {
      _model.isSending = true;
      safeSetState(() {});

      // Upload video if selected
      String? videoUrl;
      if (hasVideo && _model.selectedVideoFile != null) {
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
      if (hasImages || hasSingleImage) {
        messageType = MessageType.image;
      } else if (hasVideo && videoUrl != null) {
        messageType = MessageType.video;
      } else if (hasAudio && audioUrl != null) {
        messageType = MessageType.voice;
      } else if (hasFile) {
        messageType = MessageType.file;
      }

      // Build images list
      List<String> imagesList = [];
      if (hasImages) {
        imagesList = List<String>.from(_model.images);
      }
      if (hasSingleImage) {
        imagesList.add(_model.image!);
      }

      // Create message data
      final messageData = <String, dynamic>{
        'content': messageText,
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
      if (hasFile) {
        messageData['file'] = _model.file;
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

      // Determine last message text for chat metadata
      String lastMessageText = messageText;
      if (lastMessageText.isEmpty) {
        if (hasImages || hasSingleImage) {
          lastMessageText = '📷 Photo';
        } else if (hasVideo) {
          lastMessageText = '🎬 Video';
        } else if (hasAudio) {
          lastMessageText = '🎤 Voice message';
        } else if (hasFile) {
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
      _model.uploadedFileUrls_uploadData.clear();
      _model.uploadedLocalFiles_uploadData.clear();
      _model.uploadedFileUrl_uploadDataCamera = '';
      _model.uploadedFileUrl_uploadDataFile = '';

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
    _model.isSendingImage = true;
    safeSetState(() {});
    final selectedMedia = await selectMedia(
      mediaSource: MediaSource.photoGallery,
      multiImage: true,
    );
    if (selectedMedia != null &&
        selectedMedia
            .every((m) => validateFileFormat(m.storagePath, context))) {
      // Check if more than 10 images selected
      if (selectedMedia.length > 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('You can only select up to 10 images at once'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
          ),
        );
        _model.isSendingImage = false;
        safeSetState(() {});
        return;
      }
      safeSetState(() => _model.isDataUploading_uploadData = true);
      var selectedUploadedFiles = <FFUploadedFile>[];

      var downloadUrls = <String>[];
      try {
        selectedUploadedFiles = selectedMedia
            .map((m) => FFUploadedFile(
                  name: m.storagePath.split('/').last,
                  bytes: m.bytes,
                  height: m.dimensions?.height,
                  width: m.dimensions?.width,
                  blurHash: m.blurHash,
                ))
            .toList();

        downloadUrls = (await Future.wait(
          selectedMedia.map(
            (m) async => await uploadData(m.storagePath, m.bytes),
          ),
        ))
            .where((u) => u != null)
            .map((u) => u!)
            .toList();
      } finally {
        _model.isDataUploading_uploadData = false;
      }
      if (selectedUploadedFiles.length == selectedMedia.length &&
          downloadUrls.length == selectedMedia.length) {
        safeSetState(() {
          _model.uploadedLocalFiles_uploadData = selectedUploadedFiles;
          _model.uploadedFileUrls_uploadData = downloadUrls;
        });
      } else {
        safeSetState(() {});
        _model.isSendingImage = false;
        return;
      }
    }

    if ((_model.uploadedFileUrls_uploadData.isNotEmpty) == true) {
      _model.images = _model.uploadedFileUrls_uploadData
          .map((url) => url.toString())
          .toList();
      safeSetState(() {});
    }
    _model.isSendingImage = false;
    safeSetState(() {});
  }

  Future<void> _handleCameraCapture() async {
    _model.isSendingImage = true;
    safeSetState(() {});
    final selectedMedia = await selectMediaWithSourceBottomSheet(
      context: context,
      allowPhoto: true,
      allowVideo: true,
    );
    if (selectedMedia != null &&
        selectedMedia
            .every((m) => validateFileFormat(m.storagePath, context))) {
      safeSetState(() => _model.isDataUploading_uploadDataCamera = true);
      var selectedUploadedFiles = <FFUploadedFile>[];

      var downloadUrls = <String>[];
      try {
        selectedUploadedFiles = selectedMedia
            .map((m) => FFUploadedFile(
                  name: m.storagePath.split('/').last,
                  bytes: m.bytes,
                  height: m.dimensions?.height,
                  width: m.dimensions?.width,
                  blurHash: m.blurHash,
                ))
            .toList();

        downloadUrls = (await Future.wait(
          selectedMedia.map(
            (m) async => await uploadData(m.storagePath, m.bytes),
          ),
        ))
            .where((u) => u != null)
            .map((u) => u!)
            .toList();
      } finally {
        _model.isDataUploading_uploadDataCamera = false;
      }
      if (selectedUploadedFiles.length == selectedMedia.length &&
          downloadUrls.length == selectedMedia.length) {
        safeSetState(() {
          _model.uploadedLocalFile_uploadDataCamera =
              selectedUploadedFiles.first;
          _model.uploadedFileUrl_uploadDataCamera = downloadUrls.first;
        });
      } else {
        safeSetState(() {});
        _model.isSendingImage = false;
        return;
      }
    }

    if (_model.uploadedFileUrl_uploadDataCamera != '') {
      _model.image = _model.uploadedFileUrl_uploadDataCamera;
      safeSetState(() {});
    }
    _model.isSendingImage = false;
    safeSetState(() {});
  }

  Future<void> _handleFilePicker() async {
    // Get original filename from file picker
    final pickedFiles = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
      allowMultiple: false,
    );

    if (pickedFiles == null || pickedFiles.files.isEmpty) {
      return;
    }

    final pickedFile = pickedFiles.files.first;
    if (pickedFile.bytes == null) {
      return;
    }

    final originalFileName = pickedFile.name;

    safeSetState(() => _model.isDataUploading_uploadDataFile = true);
    var selectedUploadedFiles = <FFUploadedFile>[];

    var downloadUrls = <String>[];
    try {
      // Generate storage path (similar to selectFiles)
      // Format: users/{uid}/uploads/{timestamp}.{ext}
      final currentUserUid = currentUserReference?.id ?? '';
      final pathPrefix = 'users/$currentUserUid/uploads';
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final ext = originalFileName.contains('.')
          ? originalFileName.split('.').last
          : 'file';
      final storagePath = '$pathPrefix/$timestamp.$ext';

      // Use the original filename instead of storage path
      selectedUploadedFiles = [
        FFUploadedFile(
          name: originalFileName,
          bytes: pickedFile.bytes!,
        )
      ];

      downloadUrls = [(await uploadData(storagePath, pickedFile.bytes!)) ?? '']
          .where((u) => u.isNotEmpty)
          .toList();
    } finally {
      _model.isDataUploading_uploadDataFile = false;
    }
    if (selectedUploadedFiles.length == 1 && downloadUrls.length == 1) {
      safeSetState(() {
        _model.uploadedLocalFile_uploadDataFile = selectedUploadedFiles.first;
        _model.uploadedFileUrl_uploadDataFile = downloadUrls.first;
      });
    } else {
      safeSetState(() {});
      return;
    }

    if (_model.uploadedFileUrl_uploadDataFile != '') {
      _model.file = _model.uploadedFileUrl_uploadDataFile;
      safeSetState(() {});
    }
  }

  Future<void> _handleVideoCapture() async {
    _model.isSendingImage = true;
    safeSetState(() {});
    final selectedMedia = await selectMediaWithSourceBottomSheet(
      context: context,
      allowPhoto: false,
      allowVideo: true,
    );
    if (selectedMedia != null &&
        selectedMedia
            .every((m) => validateFileFormat(m.storagePath, context))) {
      // Store the selected video file locally for preview
      _model.selectedVideoFile = selectedMedia.first;
      safeSetState(() {});
    }
    _model.isSendingImage = false;
    safeSetState(() {});
  }

  void _showEmojiPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
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
            // Emoji Picker - Full featured like WhatsApp
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                    bottom: 20.0,
                    left:
                        8.0), // Add bottom padding to move buttons up, left padding for search button
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
                    height: MediaQuery.of(context).size.height * 0.38,
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
            ),
          ],
        ),
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

  double _estimateMessageHeight(MessagesRecord message) {
    // Estimate message height based on content
    double baseHeight = 60.0; // Base height for message container

    // Add height for text content
    if (message.content.isNotEmpty) {
      final textLength = message.content.length;
      final lines = (textLength / 50).ceil(); // Approximate 50 chars per line
      baseHeight += lines * 20.0; // 20 pixels per line
    }

    // Add height for images
    if (message.images.isNotEmpty) {
      baseHeight += 200.0; // Approximate height for images
    }

    // Add height for video
    if (message.video.isNotEmpty) {
      baseHeight += 250.0; // Approximate height for video
    }

    // Add height for audio
    if (message.audio.isNotEmpty) {
      baseHeight += 80.0; // Approximate height for audio player
    }

    // Add height for reply context
    if (message.replyTo.isNotEmpty) {
      baseHeight += 60.0; // Height for reply context
    }

    return baseHeight;
  }

  @override
  Widget build(BuildContext context) {
    // Reset pagination when chat changes
    final currentChatId = widget.chatReference?.reference.id;
    if (currentChatId != null && _currentChatId != currentChatId) {
      _currentChatId = currentChatId;
      _resetPagination();
    }

    // Mark messages as read when widget is built/displayed - debounced to avoid multiple calls
    WidgetsBinding.instance.addPostFrameCallback((_) {
      EasyDebounce.debounce(
        'markMessagesAsRead',
        const Duration(milliseconds: 500),
        () => _markMessagesAsRead(),
      );
    });

    return GestureDetector(
      onTap: () async {
        _model.select = false;
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
                          .limit(_messagesPerPage), // Load initial 50 messages
                    ),
                    builder: (context, snapshot) {
                      // Mark messages as read when messages are loaded - debounced to avoid multiple calls
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        EasyDebounce.debounce(
                          'markMessagesAsRead',
                          const Duration(milliseconds: 500),
                          () => _markMessagesAsRead(),
                        );
                      }
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
                      List<MessagesRecord> recentMessages = snapshot.data!;

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
                              _lastLoadedOlderMessageSnapshot = docSnapshot;
                            });
                          }
                        }).catchError((e) {
                          print('Error getting oldest message snapshot: $e');
                        });
                      }

                      // Merge with loaded older messages
                      // Recent messages are newest first, older messages are also newest first
                      // We need to combine them: older messages go before recent messages
                      List<MessagesRecord> listViewMessagesRecordList = [];

                      // Add older messages first (they're already in descending order)
                      listViewMessagesRecordList.addAll(_loadedOlderMessages);

                      // Then add recent messages, avoiding duplicates
                      final olderMessageIds = _loadedOlderMessages
                          .map((m) => m.reference.id)
                          .toSet();
                      for (final message in recentMessages) {
                        if (!olderMessageIds.contains(message.reference.id)) {
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

                      // Calculate unread messages using isReadBy field on each message
                      final chat = widget.chatReference;
                      int unreadCount = 0;
                      int? unreadSeparatorIndex;

                      if (chat != null && currentUserReference != null) {
                        // Find unread messages and determine separator position
                        // Messages are in descending order (newest first, index 0 = newest)
                        // ListView has reverse: true, so:
                        // - Index 0 (newest) appears at bottom of screen
                        // - Last index (oldest) appears at top of screen
                        // We want separator above unread messages (which are at bottom)

                        int?
                            firstUnreadIndex; // Index of the newest unread message

                        // Iterate through messages from newest to oldest
                        // Count ALL unread messages and find where to place the separator
                        for (int i = 0;
                            i < listViewMessagesRecordList.length;
                            i++) {
                          final message = listViewMessagesRecordList[i];

                          // Message is unread if:
                          // 1. Current user is NOT in the isReadBy list
                          // 2. It wasn't sent by the current user (don't count own messages)
                          // 3. It's not a system message
                          final isUnread = message.senderRef !=
                                  currentUserReference &&
                              !message.isSystemMessage &&
                              !message.isReadBy.contains(currentUserReference);

                          if (isUnread) {
                            unreadCount++;
                            // Track the first (newest) unread message index
                            if (firstUnreadIndex == null) {
                              firstUnreadIndex = i;
                            }
                          }
                        }

                        // The separator should appear right before the first (newest) unread message
                        // Since ListView has reverse: true, this will appear above unread messages
                        // Insert separator at firstUnreadIndex (right before first unread)
                        if (firstUnreadIndex != null && unreadCount > 0) {
                          unreadSeparatorIndex = firstUnreadIndex;
                        }
                      }

                      return GestureDetector(
                        onTap: () async {
                          await actions.closekeyboard();
                        },
                        child: ListView.builder(
                          controller: _model.scrollController,
                          // Top padding for floating top bar, bottom for floating input bar
                          // Add extra padding at top when loading older messages
                          padding: EdgeInsets.only(
                            top: 120 + (_isLoadingOlderMessages ? 50 : 0),
                            bottom: 100,
                          ),
                          reverse: true,
                          shrinkWrap: false, // Better performance when false
                          scrollDirection: Axis.vertical,
                          cacheExtent:
                              500, // Cache more items for smoother scrolling
                          addAutomaticKeepAlives:
                              false, // Don't keep items alive unnecessarily
                          addRepaintBoundaries:
                              true, // Add repaint boundaries for better performance
                          itemCount: listViewMessagesRecordList.length +
                              (unreadSeparatorIndex != null ? 1 : 0) +
                              (_isLoadingOlderMessages ? 1 : 0),
                          itemBuilder: (context, listViewIndex) {
                            // Show loading indicator at the top (first item in reversed list)
                            if (_isLoadingOlderMessages && listViewIndex == 0) {
                              return Container(
                                padding: EdgeInsets.all(16.0),
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    FlutterFlowTheme.of(context).primary,
                                  ),
                                ),
                              );
                            }

                            // Adjust index if loading indicator is shown
                            int adjustedIndex = _isLoadingOlderMessages
                                ? listViewIndex - 1
                                : listViewIndex;

                            // Calculate the actual message index accounting for separator
                            // The separator is inserted right before the first (newest) unread message
                            int messageIndex = adjustedIndex;

                            // Insert separator right before first unread message
                            if (unreadSeparatorIndex != null &&
                                listViewIndex == unreadSeparatorIndex) {
                              return Container(
                                margin: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12.0, vertical: 6.0),
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .primary
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20.0),
                                      border: Border.all(
                                        color: FlutterFlowTheme.of(context)
                                            .primary
                                            .withOpacity(0.3),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Text(
                                      unreadCount == 1
                                          ? '1 unread message'
                                          : '$unreadCount unread messages',
                                      style: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .override(
                                            fontFamily: 'Inter',
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                            fontSize: 12.0,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.0,
                                          ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            // Adjust message index if separator was inserted before this position
                            if (unreadSeparatorIndex != null &&
                                listViewIndex > unreadSeparatorIndex) {
                              messageIndex = listViewIndex - 1;
                            }

                            if (messageIndex < 0 ||
                                messageIndex >=
                                    listViewMessagesRecordList.length) {
                              return SizedBox.shrink();
                            }

                            final listViewMessagesRecord =
                                listViewMessagesRecordList[messageIndex];
                            return Container(
                              child: wrapWithModel(
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
                                  chatRef: widget.chatReference!.reference,
                                  userRef: listViewMessagesRecord.senderRef!,
                                  action: () async {
                                    _model.select = false;
                                    safeSetState(() {});
                                  },
                                  onMessageLongPress: widget.onMessageLongPress,
                                  onReplyToMessage: (message) {
                                    _model.replyingToMessage = message;
                                    safeSetState(() {});
                                  },
                                  onScrollToMessage: (messageId) {
                                    _scrollToMessage(
                                        messageId, listViewMessagesRecordList);
                                  },
                                  onEditMessage: (message) {
                                    _model.editingMessage = message;
                                    _model.messageTextController?.text =
                                        message.content;
                                    safeSetState(() {});
                                  },
                                  isHighlighted: _model.highlightedMessageId ==
                                      listViewMessagesRecord.reference.id,
                                  isGroup:
                                      widget.chatReference?.isGroup ?? false,
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
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
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
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
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
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      borderRadius: BorderRadius.circular(2),
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
                                          style: FlutterFlowTheme.of(context)
                                              .labelSmall
                                              .override(
                                                fontFamily: 'Inter',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primary,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          (_model.editingMessage?.content ??
                                                  _model.replyingToMessage
                                                      ?.content ??
                                                  '')
                                              .replaceAll('\n', ' '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: FlutterFlowTheme.of(context)
                                              .bodySmall
                                              .override(
                                                fontFamily: 'Inter',
                                                color:
                                                    FlutterFlowTheme.of(context)
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
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText
                                            .withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.xmark,
                                        size: 16,
                                        color: FlutterFlowTheme.of(context)
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
                    // Attachment Previews - Floating Style
                    if (_model.images.isNotEmpty ||
                        _model.image != null ||
                        _model.file != null ||
                        _model.audiopath != null ||
                        _model.selectedVideoFile != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // Multiple Images Preview
                              ..._model.images.map((imageUrl) => Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
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
                                                color: Colors.black
                                                    .withOpacity(0.6),
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
                              // Single Image Preview
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
                                              color:
                                                  Colors.black.withOpacity(0.6),
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
                              // Video Preview - Liquid Glass
                              if (_model.selectedVideoFile != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                              sigmaX: 15, sigmaY: 15),
                                          child: Container(
                                            width: 70,
                                            height: 70,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  (Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withOpacity(0.12),
                                                  (Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withOpacity(0.06),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: (Theme.of(context)
                                                                .brightness ==
                                                            Brightness.dark
                                                        ? Colors.white
                                                        : Colors.black)
                                                    .withOpacity(0.1),
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Icon(
                                              CupertinoIcons.play_circle_fill,
                                              size: 32,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                            ),
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
                                              color:
                                                  Colors.black.withOpacity(0.6),
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
                              // File Preview - Liquid Glass
                              if (_model.file != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                              sigmaX: 15, sigmaY: 15),
                                          child: Container(
                                            width: 70,
                                            height: 70,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  (Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withOpacity(0.12),
                                                  (Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withOpacity(0.06),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: (Theme.of(context)
                                                                .brightness ==
                                                            Brightness.dark
                                                        ? Colors.white
                                                        : Colors.black)
                                                    .withOpacity(0.1),
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Icon(
                                              CupertinoIcons.doc_fill,
                                              size: 32,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () {
                                            _model.file = null;
                                            safeSetState(() {});
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.black.withOpacity(0.6),
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
                              // Audio Preview - Liquid Glass
                              if (_model.audiopath != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                              sigmaX: 15, sigmaY: 15),
                                          child: Container(
                                            width: 70,
                                            height: 70,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  (Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withOpacity(0.12),
                                                  (Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withOpacity(0.06),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: (Theme.of(context)
                                                                .brightness ==
                                                            Brightness.dark
                                                        ? Colors.white
                                                        : Colors.black)
                                                    .withOpacity(0.1),
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Icon(
                                              CupertinoIcons.waveform,
                                              size: 32,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                            ),
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
                                              color:
                                                  Colors.black.withOpacity(0.6),
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
                      ),
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
                                label: 'Images',
                                icon: PlatformInfo.isIOS26OrHigher()
                                    ? 'photo.on.rectangle'
                                    : Icons.image_rounded,
                                value: 'images',
                              ),
                              AdaptivePopupMenuItem(
                                label: 'Camera',
                                icon: PlatformInfo.isIOS26OrHigher()
                                    ? 'camera'
                                    : Icons.camera_alt,
                                value: 'camera',
                              ),
                              AdaptivePopupMenuItem(
                                label: 'File',
                                icon: PlatformInfo.isIOS26OrHigher()
                                    ? 'paperclip'
                                    : Icons.attach_file_rounded,
                                value: 'file',
                              ),
                              AdaptivePopupMenuItem(
                                label: 'Video',
                                icon: PlatformInfo.isIOS26OrHigher()
                                    ? 'video'
                                    : Icons.videocam,
                                value: 'video',
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
                              opacity: _isServiceChatReadOnly() ? 0.3 : 1.0,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 20, sigmaY: 20),
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
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: (Theme.of(context).brightness ==
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
                                    borderRadius: BorderRadius.circular(22),
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
                                            color:
                                                (Theme.of(context).brightness ==
                                                            Brightness.dark
                                                        ? Colors.white
                                                        : Colors.black)
                                                    .withOpacity(0.08),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            // Emoji Button
                                            GestureDetector(
                                              onTap: () => _showEmojiPicker(),
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 12, bottom: 10),
                                                child: Icon(
                                                  CupertinoIcons.smiley,
                                                  size: 24,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                ),
                                              ),
                                            ),
                                            // Text Input
                                            Expanded(
                                              child: CupertinoTextField(
                                                controller: _model
                                                    .messageTextController,
                                                focusNode:
                                                    _model.messageFocusNode,
                                                placeholder:
                                                    _model.editingMessage !=
                                                            null
                                                        ? 'Edit your message...'
                                                        : 'Message...',
                                                placeholderStyle: TextStyle(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText
                                                      .withOpacity(0.6),
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                                style: TextStyle(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  fontSize: 16,
                                                ),
                                                padding: const EdgeInsets.only(
                                                  left: 8,
                                                  right: 8,
                                                  top: 12,
                                                  bottom: 12,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Colors.transparent,
                                                ),
                                                minLines: 1,
                                                maxLines: 5,
                                                textInputAction:
                                                    TextInputAction.newline,
                                                onChanged: (value) {
                                                  // Remove unnecessary setState - text field updates automatically
                                                  // Only update if we need to show/hide send button or adjust UI
                                                  // The debounce is not needed here as TextField handles updates efficiently
                                                },
                                              ),
                                            ),
                                            // ═══════════════════════════════════════
                                            // INLINE SEND BUTTON - System Blue, iMessage style
                                            // ═══════════════════════════════════════
                                            AnimatedOpacity(
                                              opacity: 1.0, // Always visible
                                              duration: const Duration(
                                                  milliseconds: 150),
                                              child: AnimatedScale(
                                                scale: 1.0, // Always full scale
                                                duration: const Duration(
                                                    milliseconds: 150),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 6, bottom: 6),
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
                                                      decoration: BoxDecoration(
                                                        // System Blue
                                                        color: CupertinoColors
                                                            .systemBlue,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: _model.isSending ==
                                                              true
                                                          ? const CupertinoActivityIndicator(
                                                              color:
                                                                  Colors.white,
                                                              radius: 8,
                                                            )
                                                          : const Icon(
                                                              CupertinoIcons
                                                                  .arrow_up,
                                                              size: 18,
                                                              color:
                                                                  Colors.white,
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
}
