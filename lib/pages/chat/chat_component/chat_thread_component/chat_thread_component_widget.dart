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
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
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
          print('✅ Successfully marked messages as read for chat: ${chat.reference.id}');
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
          final updatedReadBy =
              List<DocumentReference>.from(message.isReadBy);
          if (!updatedReadBy.contains(currentUserReference)) {
            updatedReadBy.add(currentUserReference!);
            batch.update(message.reference, {
              'is_read_by': updatedReadBy.map((ref) => ref).toList(),
            });
            updateCount++;
            
            // Commit batch if we reach the limit
            if (updateCount >= maxBatchSize) {
              await batch.commit();
              print('✅ Marked $updateCount messages as read in chat ${chat.reference.id} (batch)');
              break;
            }
          }
        }
      }

      // Commit batch update if there are changes
      if (updateCount > 0 && updateCount < maxBatchSize) {
        await batch.commit();
        print('✅ Marked $updateCount messages as read in chat ${chat.reference.id}');
      }
    } catch (e) {
      print('❌ Error marking individual messages as read: $e');
    }
  }

  @override
  void dispose() {
    _model.scrollController?.dispose();
    _model.maybeDispose();

    super.dispose();
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
    // Mark messages as read when widget is built/displayed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead();
    });

    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
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
                          .orderBy('created_at', descending: true),
                    ),
                    builder: (context, snapshot) {
                      // Mark messages as read when messages are loaded
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _markMessagesAsRead();
                        });
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
                      List<MessagesRecord> listViewMessagesRecordList =
                          snapshot.data!;

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
                        
                        int? firstUnreadIndex; // Index of the newest unread message
                        
                        // Iterate through messages from newest to oldest
                        // Count ALL unread messages and find where to place the separator
                        for (int i = 0; i < listViewMessagesRecordList.length; i++) {
                          final message = listViewMessagesRecordList[i];
                          
                          // Message is unread if:
                          // 1. Current user is NOT in the isReadBy list
                          // 2. It wasn't sent by the current user (don't count own messages)
                          // 3. It's not a system message
                          final isUnread = message.senderRef != currentUserReference &&
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

                      return InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          await actions.closekeyboard();
                        },
                        child: ListView.builder(
                          controller: _model.scrollController,
                          padding: EdgeInsets.zero,
                          reverse: true,
                          shrinkWrap: true,
                          scrollDirection: Axis.vertical,
                          itemCount: listViewMessagesRecordList.length + (unreadSeparatorIndex != null ? 1 : 0),
                          itemBuilder: (context, listViewIndex) {
                            // Calculate the actual message index accounting for separator
                            // The separator is inserted right before the first (newest) unread message
                            int messageIndex = listViewIndex;
                            
                            // Insert separator right before first unread message
                            if (unreadSeparatorIndex != null && listViewIndex == unreadSeparatorIndex) {
                              return Container(
                                margin: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context).primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20.0),
                                      border: Border.all(
                                        color: FlutterFlowTheme.of(context).primary.withOpacity(0.3),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Text(
                                      unreadCount == 1 
                                          ? '1 unread message'
                                          : '$unreadCount unread messages',
                                      style: FlutterFlowTheme.of(context).bodySmall.override(
                                            fontFamily: 'Inter',
                                            color: FlutterFlowTheme.of(context).primary,
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
                            if (unreadSeparatorIndex != null && listViewIndex > unreadSeparatorIndex) {
                              messageIndex = listViewIndex - 1;
                            }
                            
                            if (messageIndex < 0 || messageIndex >= listViewMessagesRecordList.length) {
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
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Divider(
                      height: 1.0,
                      thickness: 1.0,
                      color: FlutterFlowTheme.of(context).alternate,
                    ),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            0.0, 0.0, 0.0, 16.0),
                        child: InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            _model.select = false;
                            safeSetState(() {});
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            16.0, 12.0, 0.0, 0.0),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if ((_model
                                                  .uploadedFileUrls_uploadData
                                                  .isNotEmpty) ==
                                              true)
                                            Builder(
                                              builder: (context) {
                                                final uploadedImages =
                                                    _model.images.toList();

                                                return Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    if (uploadedImages.length > 1)
                                                      Padding(
                                                        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                                          decoration: BoxDecoration(
                                                            color: FlutterFlowTheme.of(context).primary.withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(12.0),
                                                            border: Border.all(
                                                              color: FlutterFlowTheme.of(context).primary,
                                                              width: 1.0,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            '${uploadedImages.length} images selected',
                                                            style: TextStyle(
                                                              color: FlutterFlowTheme.of(context).primary,
                                                              fontSize: 12.0,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    SingleChildScrollView(
                                                      scrollDirection: Axis.horizontal,
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: List.generate(
                                                      uploadedImages.length,
                                                      (uploadedImagesIndex) {
                                                    final uploadedImagesItem =
                                                        uploadedImages[
                                                            uploadedImagesIndex];
                                                    return SizedBox(
                                                      width: 140.0,
                                                      height: 120.0,
                                                      child: Stack(
                                                        alignment:
                                                            const AlignmentDirectional(
                                                                0.0, 0.0),
                                                        children: [
                                                          FlutterFlowMediaDisplay(
                                                              path:
                                                                  uploadedImagesItem,
                                                              imageBuilder:
                                                                  (path) =>
                                                                      ClipRRect(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8.0),
                                                                child:
                                                                    CachedNetworkImage(
                                                                  fadeInDuration:
                                                                      const Duration(
                                                                          milliseconds:
                                                                              500),
                                                                  fadeOutDuration:
                                                                      const Duration(
                                                                          milliseconds:
                                                                              500),
                                                                  imageUrl: path,
                                                                  width: 120.0,
                                                                  height: 100.0,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                ),
                                                              ),
                                                              videoPlayerBuilder:
                                                                  (path) =>
                                                                      FlutterFlowVideoPlayer(
                                                                path: path,
                                                                width: 300.0,
                                                                autoPlay: false,
                                                                looping: true,
                                                                showControls:
                                                                    true,
                                                                allowFullScreen:
                                                                    true,
                                                                allowPlaybackSpeedMenu:
                                                                    false,
                                                              ),
                                                            ),
                                                          Align(
                                                            alignment:
                                                                const AlignmentDirectional(
                                                                    1.12,
                                                                    -0.95),
                                                            child:
                                                                FlutterFlowIconButton(
                                                              borderColor:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .error,
                                                              borderRadius:
                                                                  20.0,
                                                              borderWidth: 2.0,
                                                              buttonSize: 40.0,
                                                              fillColor: FlutterFlowTheme
                                                                      .of(context)
                                                                  .primaryBackground,
                                                              icon: Icon(
                                                                Icons
                                                                    .delete_outline_rounded,
                                                                color: Colors
                                                                    .black,
                                                                size: 24.0,
                                                              ),
                                                              onPressed:
                                                                  () async {
                                                                _model.removeFromImages(
                                                                    uploadedImagesItem);
                                                                safeSetState(
                                                                    () {});
                                                              },
                                                            ),
                                                          ),

                                                        ],
                                                      ),
                                                    );
                                                  }).divide(const SizedBox(
                                                      width: 5.0)),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          if (_model.file != null &&
                                              _model.file != '')
                                            Builder(
                                              builder: (context) {
                                                final fileUrl = _model.file!;
                                                final isPdf = fileUrl
                                                        .toLowerCase()
                                                        .endsWith('.pdf') ||
                                                    fileUrl
                                                        .toLowerCase()
                                                        .contains('.pdf');
                                                final uploadedFileName = _model
                                                    .uploadedLocalFile_uploadDataFile
                                                    .name;
                                                final fileName =
                                                    (uploadedFileName != null &&
                                                            uploadedFileName
                                                                .isNotEmpty)
                                                        ? uploadedFileName
                                                        : (fileUrl
                                                                .split('/')
                                                                .last
                                                                .split('?')
                                                                .first
                                                                .isNotEmpty
                                                            ? fileUrl
                                                                .split('/')
                                                                .last
                                                                .split('?')
                                                                .first
                                                            : 'file');

                                                if (isPdf) {
                                                  return SizedBox(
                                                    width: 160.0,
                                                    height: 120.0,
                                                    child: Stack(
                                                      alignment:
                                                          const AlignmentDirectional(
                                                              0.0, 0.0),
                                                      children: [
                                                        FlutterFlowPdfViewer(
                                                          networkPath: fileUrl,
                                                          height: 300.0,
                                                          horizontalScroll:
                                                              false,
                                                        ),
                                                        Align(
                                                          alignment:
                                                              const AlignmentDirectional(
                                                                  1.0, -0.95),
                                                          child:
                                                              FlutterFlowIconButton(
                                                            borderColor:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .error,
                                                            borderRadius: 20.0,
                                                            borderWidth: 2.0,
                                                            buttonSize: 40.0,
                                                            fillColor: FlutterFlowTheme
                                                                    .of(context)
                                                                .primaryBackground,
                                                            icon: Icon(
                                                              Icons
                                                                  .delete_outline_rounded,
                                                              color:
                                                                  Colors.black,
                                                              size: 24.0,
                                                            ),
                                                            onPressed:
                                                                () async {
                                                              safeSetState(() {
                                                                _model.isDataUploading_uploadDataFile =
                                                                    false;
                                                                _model.uploadedLocalFile_uploadDataFile =
                                                                    FFUploadedFile(
                                                                        bytes: Uint8List.fromList(
                                                                            []));
                                                                _model.uploadedFileUrl_uploadDataFile =
                                                                    '';
                                                                _model.file = '';
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                } else {
                                                  return Container(
                                                    width: 200.0,
                                                    padding:
                                                        EdgeInsets.all(12.0),
                                                    decoration: BoxDecoration(
                                                      color: FlutterFlowTheme
                                                              .of(context)
                                                          .secondaryBackground,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                      border: Border.all(
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .alternate,
                                                      ),
                                                    ),
                                                    child: Stack(
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .insert_drive_file_rounded,
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .primary,
                                                              size: 32.0,
                                                            ),
                                                            SizedBox(
                                                                width: 12.0),
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
                                                                    fileName,
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium,
                                                                    maxLines: 2,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),

                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        Align(
                                                          alignment:
                                                              AlignmentDirectional(
                                                                  1.0, -1.0),
                                                          child:
                                                              FlutterFlowIconButton(
                                                            borderColor:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .error,
                                                            borderRadius: 20.0,
                                                            borderWidth: 2.0,
                                                            buttonSize: 32.0,
                                                            fillColor: FlutterFlowTheme
                                                                    .of(context)
                                                                .primaryBackground,
                                                            icon: Icon(
                                                              Icons
                                                                  .delete_outline_rounded,
                                                              color:
                                                                  Colors.black,
                                                              size: 18.0,
                                                            ),
                                                            onPressed:
                                                                () async {
                                                              safeSetState(() {
                                                                _model.isDataUploading_uploadDataFile =
                                                                    false;
                                                                _model.uploadedLocalFile_uploadDataFile =
                                                                    FFUploadedFile(
                                                                        bytes: Uint8List.fromList(
                                                                            []));
                                                                _model.uploadedFileUrl_uploadDataFile =
                                                                    '';
                                                                _model.file = '';
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          if (_model.audiopath != null &&
                                              _model.audiopath != '')
                                            SizedBox(
                                              width: 300.0,
                                              height: 110.0,
                                              child: Stack(
                                                alignment:
                                                    const AlignmentDirectional(
                                                        0.0, 0.0),
                                                children: [
                                                  SizedBox(
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    child: custom_widgets
                                                        .LinkedUpPlayer(
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                      audioPath:
                                                          _model.audiopath!,
                                                      isLocal: true,
                                                    ),
                                                  ),
                                                  Align(
                                                    alignment:
                                                        const AlignmentDirectional(
                                                            -1.0, 1.0),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsetsDirectional
                                                              .fromSTEB(25.0,
                                                              0.0, 0.0, 5.0),
                                                      child:
                                                          FlutterFlowIconButton(
                                                        borderColor:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .error,
                                                        borderRadius: 20.0,
                                                        borderWidth: 2.0,
                                                        buttonSize: 30.0,
                                                        fillColor:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryBackground,
                                                        icon: Icon(
                                                          Icons
                                                              .delete_outline_rounded,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .error,
                                                          size: 14.0,
                                                        ),
                                                        onPressed: () async {
                                                          _model.audiopath =
                                                              null;
                                                          safeSetState(() {});
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (_model
                                                  .uploadedFileUrl_uploadDataCamera !=
                                              '')
                                            SizedBox(
                                              width: 140.0,
                                              height: 120.0,
                                              child: Stack(
                                                alignment:
                                                    const AlignmentDirectional(
                                                        0.0, 0.0),
                                                children: [
                                                  FlutterFlowMediaDisplay(
                                                      path: _model.image!,
                                                      imageBuilder: (path) =>
                                                          ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                8.0),
                                                        child: CachedNetworkImage(
                                                          fadeInDuration:
                                                              const Duration(
                                                                  milliseconds:
                                                                      500),
                                                          fadeOutDuration:
                                                              const Duration(
                                                                  milliseconds:
                                                                      500),
                                                          imageUrl: path,
                                                          width: 120.0,
                                                          height: 100.0,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                      videoPlayerBuilder: (path) =>
                                                          FlutterFlowVideoPlayer(
                                                        path: path,
                                                        width: 300.0,
                                                        autoPlay: false,
                                                        looping: true,
                                                        showControls: true,
                                                        allowFullScreen: true,
                                                        allowPlaybackSpeedMenu:
                                                          false,
                                                      ),
                                                    ),
                                                  Align(
                                                    alignment:
                                                        const AlignmentDirectional(
                                                            1.36, -0.95),
                                                    child:
                                                        FlutterFlowIconButton(
                                                      borderColor:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      borderRadius: 20.0,
                                                      borderWidth: 2.0,
                                                      buttonSize: 40.0,
                                                      fillColor:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryBackground,
                                                      icon: Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        color: Colors.black,
                                                        size: 24.0,
                                                      ),
                                                      onPressed: () async {
                                                        safeSetState(() {
                                                          _model.isDataUploading_uploadDataCamera =
                                                              false;
                                                          _model.uploadedLocalFile_uploadDataCamera =
                                                              FFUploadedFile(
                                                                  bytes: Uint8List
                                                                      .fromList(
                                                                          []));
                                                          _model.uploadedFileUrl_uploadDataCamera =
                                                              '';
                                                        });

                                                        _model.image = null;
                                                        safeSetState(() {});
                                                      },
                                                    ),
                                                  ),

                                                ],
                                              ),
                                            ),
                                        ]
                                            .divide(const SizedBox(width: 8.0))
                                            .addToStart(
                                                const SizedBox(width: 16.0))
                                            .addToEnd(
                                                const SizedBox(width: 16.0)),
                                      ),
                                    ),
                                  ),
                                  if (_model.selectedVideoFile != null)
                                    Padding(
                                      padding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                              16.0, 0.0, 0.0, 0.0),
                                      child: Container(
                                        width: 200.0,
                                        height: 150.0,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                        ),
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12.0),
                                              child: SizedBox(
                                                width: 200.0,
                                                height: 150.0,
                                                child: Container(
                                                  width: 200.0,
                                                  height: 150.0,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryBackground,
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons.videocam,
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primary,
                                                        size: 40,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'Video Selected',
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium,
                                                      ),
                                                      Text(
                                                        _model
                                                            .selectedVideoFile!
                                                            .storagePath
                                                            .split('/')
                                                            .last,
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodySmall,
                                                        textAlign:
                                                            TextAlign.center,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 8.0,
                                              right: 8.0,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.6),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20.0),
                                                ),
                                                child: IconButton(
                                                  icon: Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 20.0,
                                                  ),
                                                  onPressed: () {
                                                    _model.selectedVideoFile =
                                                        null;
                                                    safeSetState(() {});
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (_model.isSendingImage == true)
                                    Padding(
                                      padding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                              16.0, 0.0, 0.0, 0.0),
                                      child: Container(
                                        width: 120.0,
                                        height: 130.0,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(9.0),
                                          child: SizedBox(
                                            width: double.infinity,
                                            height: double.infinity,
                                            child: custom_widgets.FFlowSpinner(
                                              width: double.infinity,
                                              height: double.infinity,
                                              backgroundColor:
                                                  Colors.transparent,
                                              spinnerColor:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  // Group member mention overlay
                                  if (_model.showMentionOverlay && _model.filteredMembers.isNotEmpty)
                                    Container(
                                      constraints: BoxConstraints(
                                        maxHeight: 200.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context).secondaryBackground,
                                        borderRadius: BorderRadius.circular(8.0),
                                        border: Border.all(
                                          color: FlutterFlowTheme.of(context).alternate,
                                          width: 1.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0x1A000000),
                                            blurRadius: 8.0,
                                            offset: Offset(0, -2),
                                          ),
                                        ],
                                      ),
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        padding: EdgeInsets.zero,
                                        itemCount: _model.filteredMembers.length,
                                        itemBuilder: (context, index) {
                                          final member = _model.filteredMembers[index];
                                          return InkWell(
                                            onTap: () async {
                                              // Replace the @query with @username
                                              final currentText = _model.messageTextController?.text ?? '';
                                              final lastAtIndex = currentText.lastIndexOf('@');
                                              if (lastAtIndex != -1) {
                                                final beforeAt = currentText.substring(0, lastAtIndex);
                                                final mention = '@${member.displayName} ';
                                                _model.messageTextController?.text = beforeAt + mention;
                                                _model.messageTextController?.selection = TextSelection.fromPosition(
                                                  TextPosition(offset: (beforeAt + mention).length),
                                                );
                                              }
                                              
                                              // Hide overlay
                                              _model.showMentionOverlay = false;
                                              _model.filteredMembers = [];
                                              safeSetState(() {});
                                              
                                              // Refocus on text field
                                              _model.messageFocusNode?.requestFocus();
                                            },
                                            child: Container(
                                              padding: EdgeInsetsDirectional.fromSTEB(12.0, 8.0, 12.0, 8.0),
                                              decoration: BoxDecoration(
                                                color: FlutterFlowTheme.of(context).secondaryBackground,
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: FlutterFlowTheme.of(context).alternate,
                                                    width: 0.5,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  // Avatar
                                                  Container(
                                                    width: 32.0,
                                                    height: 32.0,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: FlutterFlowTheme.of(context).primary,
                                                        width: 1.0,
                                                      ),
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(16.0),
                                                      child: member.photoUrl.isNotEmpty
                                                          ? CachedNetworkImage(
                                                              imageUrl: member.photoUrl,
                                                              width: 32.0,
                                                              height: 32.0,
                                                              fit: BoxFit.cover,
                                                              placeholder: (context, url) => Container(
                                                                color: FlutterFlowTheme.of(context).alternate,
                                                                child: Icon(
                                                                  Icons.person,
                                                                  color: FlutterFlowTheme.of(context).secondaryText,
                                                                  size: 16.0,
                                                                ),
                                                              ),
                                                              errorWidget: (context, url, error) => Container(
                                                                color: FlutterFlowTheme.of(context).alternate,
                                                                child: Icon(
                                                                  Icons.person,
                                                                  color: FlutterFlowTheme.of(context).secondaryText,
                                                                  size: 16.0,
                                                                ),
                                                              ),
                                                            )
                                                          : Container(
                                                              color: FlutterFlowTheme.of(context).alternate,
                                                              child: Icon(
                                                                Icons.person,
                                                                color: FlutterFlowTheme.of(context).secondaryText,
                                                                size: 16.0,
                                                              ),
                                                            ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 12.0),
                                                  // Name and email
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          member.displayName,
                                                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                            font: GoogleFonts.inter(),
                                                            fontSize: 14.0,
                                                            fontWeight: FontWeight.w500,
                                                            letterSpacing: 0.0,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        if (member.email.isNotEmpty)
                                                          Text(
                                                            member.email,
                                                            style: FlutterFlowTheme.of(context).bodySmall.override(
                                                              font: GoogleFonts.inter(),
                                                              fontSize: 12.0,
                                                              color: FlutterFlowTheme.of(context).secondaryText,
                                                              letterSpacing: 0.0,
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
                                          );
                                        },
                                      ),
                                    ),
                                  // AI mention overlay (keep existing)
                                  if (_model.isMention == true)
                                    Padding(
                                      padding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                              16.0, 0.0, 16.0, 0.0),
                                      child: InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          safeSetState(() {
                                            _model.messageTextController?.text =
                                                '@linkai';
                                          });
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          height: 50.0,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                          ),
                                          child: Align(
                                            alignment:
                                                const AlignmentDirectional(
                                                    -1.0, 0.0),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsetsDirectional
                                                      .fromSTEB(
                                                      50.0, 0.0, 0.0, 0.0),
                                              child: Text(
                                                '@linkai',
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodyMedium
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      fontSize: 16.0,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ).animateOnActionTrigger(
                                          animationsMap[
                                              'containerOnActionTriggerAnimation1']!,
                                          hasBeenTriggered:
                                              hasContainerTriggered1),
                                    ),
                                  // Reply preview section
                                  if (_model.replyingToMessage != null)
                                    Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        border: Border.all(
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsetsDirectional
                                            .fromSTEB(12.0, 8.0, 12.0, 8.0),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 3.0,
                                              height: 40.0,
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  left: BorderSide(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primary,
                                                    width: 4.0,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Replying to ${_model.replyingToMessage!.senderName}',
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodySmall
                                                        .override(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primary,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 2.0),
                                                  Text(
                                                    _model.replyingToMessage!
                                                        .content,
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodySmall
                                                        .override(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                        ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.close,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                size: 20.0,
                                              ),
                                              onPressed: () {
                                                _model.replyingToMessage = null;
                                                safeSetState(() {});
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  // Edit preview section
                                  if (_model.editingMessage != null)
                                    Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        border: Border.all(
                                          color: FlutterFlowTheme.of(context)
                                              .warning,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsetsDirectional
                                            .fromSTEB(12.0, 8.0, 12.0, 8.0),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 3.0,
                                              height: 40.0,
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .warning,
                                                borderRadius:
                                                    BorderRadius.circular(2.0),
                                              ),
                                            ),
                                            const SizedBox(width: 8.0),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Editing message',
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodySmall
                                                        .override(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .warning,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 2.0),
                                                  Text(
                                                    _model.editingMessage!
                                                        .content,
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodySmall
                                                        .override(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                        ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.close,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                size: 20.0,
                                              ),
                                              onPressed: () {
                                                _cancelEdit();
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  Align(
                                    alignment:
                                        const AlignmentDirectional(0.0, 0.0),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxHeight: 150.0,
                                      ),
                                      decoration: const BoxDecoration(),
                                      child: Padding(
                                        padding: const EdgeInsetsDirectional
                                            .fromSTEB(16.0, 0.0, 16.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            FlutterFlowIconButton(
                                              borderRadius: 16.0,
                                              buttonSize: 38.0,
                                              icon: const Icon(
                                                Icons.add,
                                                color: Color(0xFF6B7280),
                                                size: 20.0,
                                              ),
                                              onPressed: () async {
                                                _model.select = true;
                                                safeSetState(() {});
                                              },
                                            ),
                                            Expanded(
                                              child: SizedBox(
                                                width: 200.0,
                                                child: TextFormField(
                                                  controller: _model
                                                      .messageTextController,
                                                  focusNode:
                                                      _model.messageFocusNode,
                                                  onChanged: (_) =>
                                                      EasyDebounce.debounce(
                                                    '_model.messageTextController',
                                                    const Duration(
                                                        milliseconds: 100),
                                                    () async {
                                                      // Check for AI mention
                                                      _model.isMention = functions
                                                          .checkmention(_model
                                                              .messageTextController
                                                              .text)!;
                                                      
                                                      // Check for group member mentions
                                                      final mentionQuery = functions.extractMentionQuery(
                                                        _model.messageTextController.text
                                                      );
                                                      
                                                      if (mentionQuery != null && widget.chatReference?.isGroup == true) {
                                                        // Show mention overlay for group members
                                                        _model.showMentionOverlay = true;
                                                        _model.mentionQuery = mentionQuery;
                                                        
                                                        // Fetch and filter group members
                                                        final memberRefs = widget.chatReference?.members ?? [];
                                                        final members = await Future.wait(
                                                          memberRefs.map((ref) => UsersRecord.getDocumentOnce(ref))
                                                        );
                                                        
                                                        // Filter members by query
                                                        _model.filteredMembers = members.where((member) {
                                                          final displayName = member.displayName.toLowerCase();
                                                          final email = member.email.toLowerCase();
                                                          final query = mentionQuery.toLowerCase();
                                                          return displayName.contains(query) || email.contains(query);
                                                        }).toList();
                                                      } else {
                                                        _model.showMentionOverlay = false;
                                                        _model.filteredMembers = [];
                                                      }
                                                      
                                                      safeSetState(() {});
                                                      
                                                      if (_model.isMention ==
                                                          true) {
                                                        if (animationsMap[
                                                                'containerOnActionTriggerAnimation1'] !=
                                                            null) {
                                                          safeSetState(() =>
                                                              hasContainerTriggered1 =
                                                                  true);
                                                          SchedulerBinding
                                                              .instance
                                                              .addPostFrameCallback((_) async =>
                                                                  await animationsMap[
                                                                          'containerOnActionTriggerAnimation1']!
                                                                      .controller
                                                                      .forward(
                                                                          from:
                                                                              0.0));
                                                        }
                                                      }
                                                    },
                                                  ),
                                                  onFieldSubmitted: (_) async {
                                                    safeSetState(() {
                                                      _model.messageTextController
                                                              ?.text =
                                                          '${_model.messageTextController.text}\\n';
                                                    });
                                                  },
                                                  autofocus: false,
                                                  obscureText: false,
                                                  decoration: InputDecoration(
                                                    isDense: false,
                                                    labelStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .labelMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelMedium
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelMedium
                                                                    .fontStyle,
                                                          ),
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                    hintText:
                                                        'Start typing here...',
                                                    hintStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .labelMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelMedium
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelMedium
                                                                    .fontStyle,
                                                          ),
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .accent2,
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12.0),
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .accent2,
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12.0),
                                                    ),
                                                    errorBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: Colors.black,
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12.0),
                                                    ),
                                                    focusedErrorBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: Colors.black,
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12.0),
                                                    ),
                                                    filled: true,
                                                    fillColor: FlutterFlowTheme
                                                            .of(context)
                                                        .secondaryBackground,
                                                  ),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                  maxLines: null,
                                                  cursorColor:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .primaryText,
                                                  validator: _model
                                                      .messageTextControllerValidator
                                                      .asValidator(context),
                                                ),
                                              ),
                                            ),
                                            Builder(
                                              builder: (context) {
                                                if (_model.isSending == false) {
                                                  return FlutterFlowIconButton(
                                                    borderRadius: 32.0,
                                                    buttonSize: 40.0,
                                                    fillColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .primary,
                                                    icon: Icon(
                                                      _model.editingMessage !=
                                                              null
                                                          ? Icons.save_rounded
                                                          : Icons.send_rounded,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .info,
                                                      size: 20.0,
                                                    ),
                                                    onPressed: ((_model
                                                                    .messageTextController
                                                                    .text ==
                                                                '') &&
                                                            (_model.audiopath ==
                                                                    null ||
                                                                _model.audiopath ==
                                                                    '') &&
                                                            (_model.image == null ||
                                                                _model.image ==
                                                                    '') &&
                                                            (_model.videoUrl ==
                                                                    null ||
                                                                _model.videoUrl ==
                                                                    '') &&
                                                            (_model.selectedVideoFile ==
                                                                null) &&
                                                            !(_model.images
                                                                .isNotEmpty) &&
                                                            !(_model.images
                                                                .isNotEmpty) &&
                                                            (_model.file ==
                                                                    null ||
                                                                _model.file ==
                                                                    ''))
                                                        ? null
                                                        : () async {
                                                            // Check if we're in edit mode
                                                            if (_model
                                                                    .editingMessage !=
                                                                null) {
                                                              await _updateMessage();
                                                              return;
                                                            }

                                                            final firestoreBatch =
                                                                FirebaseFirestore
                                                                    .instance
                                                                    .batch();
                                                            try {
                                                              _model.isSending =
                                                                  true;
                                                              safeSetState(
                                                                  () {});
                                                              if (!((_model
                                                                          .messageTextController
                                                                          .text ==
                                                                      '') &&
                                                                  (_model.image ==
                                                                          null ||
                                                                      _model.image ==
                                                                          '') &&
                                                                  (_model.audiopath ==
                                                                          null ||
                                                                      _model.audiopath ==
                                                                          '') &&
                                                                  (_model.videoUrl ==
                                                                          null ||
                                                                      _model.videoUrl ==
                                                                          '') &&
                                                                  (_model.selectedVideoFile ==
                                                                      null) &&
                                                                  (_model.file ==
                                                                          null ||
                                                                      _model.file ==
                                                                          '') &&
                                                                  !(_model
                                                                      .images
                                                                      .isNotEmpty))) {
                                                                _model.isValid =
                                                                    await actions
                                                                        .checkValidWords(
                                                                  _model
                                                                      .messageTextController
                                                                      .text,
                                                                );
                                                                if (_model
                                                                        .isValid ==
                                                                    true) {
                                                                  ScaffoldMessenger.of(
                                                                          context)
                                                                      .showSnackBar(
                                                                    SnackBar(
                                                                      content:
                                                                          Text(
                                                                        '⚠️ Message blocked due to inappropriate content.',
                                                                        style:
                                                                            TextStyle(
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                        ),
                                                                      ),
                                                                      duration: const Duration(
                                                                          milliseconds:
                                                                              4000),
                                                                      backgroundColor:
                                                                          FlutterFlowTheme.of(context)
                                                                              .secondary,
                                                                    ),
                                                                  );
                                                                } else {
                                                                  if (_model.audiopath !=
                                                                          null &&
                                                                      _model.audiopath !=
                                                                          '') {
                                                                    _model.netwoekURL =
                                                                        await actions
                                                                            .uploadAudioToStorage(
                                                                      _model
                                                                          .audiopath,
                                                                    );
                                                                    _model.audioMainUrl =
                                                                        _model
                                                                            .netwoekURL;
                                                                    safeSetState(
                                                                        () {});
                                                                  } else {
                                                                    if (functions.containsAIMention(_model
                                                                            .messageTextController
                                                                            .text) ==
                                                                        true) {
                                                                      unawaited(
                                                                        () async {
                                                                          await actions
                                                                              .callAIAgent(
                                                                            widget.chatReference!.reference.id,
                                                                            _model.messageTextController.text,
                                                                          );
                                                                        }(),
                                                                      );
                                                                    }
                                                                  }

                                                                  _model.addToUserSend(
                                                                      currentUserReference!);
                                                                  safeSetState(
                                                                      () {});

                                                                  firestoreBatch.update(
                                                                      widget
                                                                          .chatReference!
                                                                          .reference,
                                                                      {
                                                                        ...createChatsRecordData(
                                                                          lastMessage: widget.chatReference?.isGroup == true
                                                                              ? '$currentUserDisplayName: ${() {
                                                                                  if (_model.videoUrl != null && _model.videoUrl != '') {
                                                                                    return 'Sent Video';
                                                                                  } else if (_model.image != null && _model.image != '') {
                                                                                    return 'Sent Image';
                                                                                  } else if (_model.audiopath != null && _model.audiopath != '') {
                                                                                    return 'Sent Voice Message';
                                                                                  } else if (_model.file != null && _model.file != '') {
                                                                                    return 'Sent File';
                                                                                  } else {
                                                                                    return _model.messageTextController.text;
                                                                                  }
                                                                                }()}'
                                                                              : '$currentUserDisplayName: ${() {
                                                                                  if (_model.videoUrl != null && _model.videoUrl != '') {
                                                                                    return 'Sent Video';
                                                                                  } else if (_model.image != null && _model.image != '') {
                                                                                    return 'Sent Image';
                                                                                  } else if (_model.audiopath != null && _model.audiopath != '') {
                                                                                    return 'Sent Voice Message';
                                                                                  } else if (_model.file != null && _model.file != '') {
                                                                                    return 'Sent File';
                                                                                  } else {
                                                                                    return _model.messageTextController.text;
                                                                                  }
                                                                                }()}',
                                                                          lastMessageAt:
                                                                              getCurrentTimestamp,
                                                                          lastMessageSent:
                                                                              currentUserReference,
                                                                          lastMessageType:
                                                                              () {
                                                                            if (_model.videoUrl != null &&
                                                                                _model.videoUrl != '') {
                                                                              return MessageType.video;
                                                                            } else if (_model.image == null || _model.image == '') {
                                                                              return MessageType.text;
                                                                            } else {
                                                                              return MessageType.image;
                                                                            }
                                                                          }(),
                                                                        ),
                                                                        ...mapToFirestore(
                                                                          {
                                                                            'last_message_seen':
                                                                                _model.userSend,
                                                                          },
                                                                        ),
                                                                      });

                                                                  // Upload video if selected
                                                                  if (_model
                                                                          .selectedVideoFile !=
                                                                      null) {
                                                                    try {
                                                                      showUploadMessage(
                                                                        context,
                                                                        'Uploading video...',
                                                                        showLoading:
                                                                            true,
                                                                      );
                                                                      _model.videoUrl =
                                                                          await uploadData(
                                                                        _model
                                                                            .selectedVideoFile!
                                                                            .storagePath,
                                                                        _model
                                                                            .selectedVideoFile!
                                                                            .bytes,
                                                                      );
                                                                      ScaffoldMessenger.of(
                                                                              context)
                                                                          .hideCurrentSnackBar();

                                                                      // Update chat timestamp after video upload completes
                                                                      await widget
                                                                          .chatReference!
                                                                          .reference
                                                                          .update({
                                                                        'last_message_at':
                                                                            getCurrentTimestamp,
                                                                      });
                                                                    } catch (e) {
                                                                      ScaffoldMessenger.of(
                                                                              context)
                                                                          .hideCurrentSnackBar();
                                                                      ScaffoldMessenger.of(
                                                                              context)
                                                                          .showSnackBar(
                                                                        SnackBar(
                                                                          content:
                                                                              Text(
                                                                            'Failed to upload video: $e',
                                                                            style:
                                                                                TextStyle(
                                                                              color: FlutterFlowTheme.of(context).primaryText,
                                                                            ),
                                                                          ),
                                                                          duration:
                                                                              const Duration(milliseconds: 4000),
                                                                          backgroundColor:
                                                                              FlutterFlowTheme.of(context).secondary,
                                                                        ),
                                                                      );
                                                                      _model.isSending =
                                                                          false;
                                                                      safeSetState(
                                                                          () {});
                                                                      return;
                                                                    }
                                                                  }

                                                                  var messagesRecordReference =
                                                                      MessagesRecord.createDoc(widget
                                                                          .chatReference!
                                                                          .reference);
                                                                  firestoreBatch
                                                                      .set(
                                                                          messagesRecordReference,
                                                                          {
                                                                        ...createMessagesRecordData(
                                                                          senderRef:
                                                                              currentUserReference,
                                                                          content:
                                                                              () {
                                                                            // If sending a file without text, store the original file name in content
                                                                            if (_model.file != null &&
                                                                                _model.file != '' &&
                                                                                (_model.messageTextController?.text.isEmpty ?? true)) {
                                                                              final originalFileName = _model.uploadedLocalFile_uploadDataFile.name;
                                                                              return (originalFileName != null && originalFileName.isNotEmpty) ? originalFileName : (_model.messageTextController?.text ?? '');
                                                                            }
                                                                            return _model.messageTextController?.text ??
                                                                                '';
                                                                          }(),
                                                                          createdAt:
                                                                              getCurrentTimestamp,
                                                                          replyTo: _model
                                                                              .replyingToMessage
                                                                              ?.reference
                                                                              .id,
                                                                          replyToContent: _model
                                                                              .replyingToMessage
                                                                              ?.content,
                                                                          replyToSender: _model
                                                                              .replyingToMessage
                                                                              ?.senderName,
                                                                          messageType:
                                                                              () {
                                                                            if (_model.videoUrl != null &&
                                                                                _model.videoUrl != '') {
                                                                              return MessageType.video;
                                                                            } else if (_model.selectedVideoFile != null) {
                                                                              return MessageType.video;
                                                                            } else if (_model.image == null || _model.image == '') {
                                                                              return MessageType.text;
                                                                            } else if (_model.audiopath != null && _model.audiopath != '') {
                                                                              return MessageType.voice;
                                                                            } else {
                                                                              return MessageType.image;
                                                                            }
                                                                          }(),
                                                                          image: _model.image != null && _model.image != ''
                                                                              ? _model.image
                                                                              : null,
                                                                          audio:
                                                                              _model.audiopath,
                                                                          video: _model.videoUrl != null && _model.videoUrl != ''
                                                                              ? _model.videoUrl
                                                                              : null,
                                                                          attachmentUrl: _model.file != null && _model.file != ''
                                                                              ? _model.file
                                                                              : '',
                                                                          audioPath:
                                                                              _model.audioMainUrl,
                                                                          senderName:
                                                                              currentUserDisplayName,
                                                                          senderPhoto:
                                                                              currentUserPhoto,
                                                                        ),
                                                                        ...mapToFirestore(
                                                                          {
                                                                            'images': _model.images.isNotEmpty
                                                                                ? _model.images
                                                                                : functions.getEmptyListImagePath(),
                                                                          },
                                                                        ),
                                                                      });
                                                                  _model.newChat =
                                                                      MessagesRecord
                                                                          .getDocumentFromData({
                                                                    ...createMessagesRecordData(
                                                                      senderRef:
                                                                          currentUserReference,
                                                                      content:
                                                                          () {
                                                                        // If sending a file without text, store the original file name in content
                                                                        if (_model.file != null &&
                                                                            _model.file !=
                                                                                '' &&
                                                                            (_model.messageTextController?.text.isEmpty ??
                                                                                true)) {
                                                                          final originalFileName = _model
                                                                              .uploadedLocalFile_uploadDataFile
                                                                              .name;
                                                                          return (originalFileName != null && originalFileName.isNotEmpty)
                                                                              ? originalFileName
                                                                              : (_model.messageTextController?.text ?? '');
                                                                        }
                                                                        return _model.messageTextController?.text ??
                                                                            '';
                                                                      }(),
                                                                      createdAt:
                                                                          getCurrentTimestamp,
                                                                      replyTo: _model
                                                                          .replyingToMessage
                                                                          ?.reference
                                                                          .id,
                                                                      replyToContent: _model
                                                                          .replyingToMessage
                                                                          ?.content,
                                                                      replyToSender: _model
                                                                          .replyingToMessage
                                                                          ?.senderName,
                                                                      messageType:
                                                                          () {
                                                                        if (_model.image ==
                                                                                null ||
                                                                            _model.image ==
                                                                                '') {
                                                                          return MessageType
                                                                              .text;
                                                                        } else if (_model.audiopath !=
                                                                                null &&
                                                                            _model.audiopath !=
                                                                                '') {
                                                                          return MessageType
                                                                              .voice;
                                                                        } else {
                                                                          return MessageType
                                                                              .image;
                                                                        }
                                                                      }(),
                                                                      image: _model.image != null &&
                                                                              _model.image !=
                                                                                  ''
                                                                          ? _model
                                                                              .image
                                                                          : null,
                                                                      audio: _model
                                                                          .audiopath,
                                                                      attachmentUrl: _model.file != null &&
                                                                              _model.file !=
                                                                                  ''
                                                                          ? _model
                                                                              .file
                                                                          : '',
                                                                      audioPath:
                                                                          _model
                                                                              .audioMainUrl,
                                                                      senderName:
                                                                          currentUserDisplayName,
                                                                      senderPhoto:
                                                                          currentUserPhoto,
                                                                    ),
                                                                    ...mapToFirestore(
                                                                      {
                                                                        'images': _model.images.isNotEmpty
                                                                            ? _model.images
                                                                            : functions.getEmptyListImagePath(),
                                                                      },
                                                                    ),
                                                                  }, messagesRecordReference);
                                                                  triggerPushNotification(
                                                                    notificationTitle:
                                                                        'New Message',
                                                                    notificationText:
                                                                        '$currentUserDisplayName: ${_model.messageTextController?.text ?? 'sent a message'}',
                                                                    notificationImageUrl: _model.image !=
                                                                                null &&
                                                                            _model.image !=
                                                                                ''
                                                                        ? _model
                                                                            .image
                                                                        : '',
                                                                    notificationSound:
                                                                        'default',
                                                                    userRefs: widget
                                                                        .chatReference!
                                                                        .members
                                                                        .where((e) =>
                                                                            e !=
                                                                            currentUserReference)
                                                                        .toList(),
                                                                    initialPageName: (!kIsWeb &&
                                                                            Platform.isIOS)
                                                                        ? 'MobileChat'
                                                                        : 'ChatDetail',
                                                                    parameterData: {
                                                                      'chatDoc':
                                                                          widget
                                                                              .chatReference,
                                                                    },
                                                                  );
                                                                  safeSetState(
                                                                      () {
                                                                    _model
                                                                        .messageTextController
                                                                        ?.clear();
                                                                  });
                                                                  _model.audiopath =
                                                                      null;
                                                                  _model.select =
                                                                      false;
                                                                  _model.image =
                                                                      null;
                                                                  _model.file =
                                                                      null;
                                                                  _model.images =
                                                                      [];
                                                                  _model.videoUrl =
                                                                      null;
                                                                  _model.selectedVideoFile =
                                                                      null;
                                                                  _model.replyingToMessage =
                                                                      null;
                                                                  safeSetState(
                                                                      () {});
                                                                  safeSetState(
                                                                      () {
                                                                    _model.isDataUploading_uploadData =
                                                                        false;
                                                                    _model.uploadedLocalFiles_uploadData =
                                                                        [];
                                                                    _model.uploadedFileUrls_uploadData =
                                                                        [];
                                                                  });

                                                                  safeSetState(
                                                                      () {
                                                                    _model.isDataUploading_uploadDataCamera =
                                                                        false;
                                                                    _model.uploadedLocalFile_uploadDataCamera =
                                                                        FFUploadedFile(
                                                                            bytes:
                                                                                Uint8List.fromList([]));
                                                                    _model.uploadedFileUrl_uploadDataCamera =
                                                                        '';
                                                                  });

                                                                  safeSetState(
                                                                      () {
                                                                    _model.isDataUploading_uploadDataFile =
                                                                        false;
                                                                    _model.uploadedLocalFile_uploadDataFile =
                                                                        FFUploadedFile(
                                                                            bytes:
                                                                                Uint8List.fromList([]));
                                                                    _model.uploadedFileUrl_uploadDataFile =
                                                                        '';
                                                                  });
                                                                }
                                                              }
                                                              _model.isSending =
                                                                  false;
                                                              safeSetState(
                                                                  () {});
                                                            } finally {
                                                              await firestoreBatch
                                                                  .commit();
                                                            }

                                                            safeSetState(() {});
                                                          },
                                                  );
                                                } else {
                                                  return Container(
                                                    width: 40.0,
                                                    height: 40.0,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              5.0),
                                                      child: SizedBox(
                                                        width: double.infinity,
                                                        height: double.infinity,
                                                        child: custom_widgets
                                                            .FFlowSpinner(
                                                          width:
                                                              double.infinity,
                                                          height:
                                                              double.infinity,
                                                          backgroundColor:
                                                              Colors
                                                                  .transparent,
                                                          spinnerColor:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .secondaryBackground,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ].divide(const SizedBox(width: 12.0)),
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
                  ],
                ),
              ]
                  .divide(const SizedBox(height: 2.0))
                  .addToStart(const SizedBox(height: 8.0))
                  .addToEnd(const SizedBox(height: 8.0)),
            ),
            Align(
              alignment: const AlignmentDirectional(-0.8, 0.65),
              child: Container(
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Builder(
                  builder: (context) {
                    if (_model.audio == false) {
                      return Visibility(
                        visible: _model.select == true,
                        child: Container(
                          constraints: const BoxConstraints(
                            maxWidth: 150.0,
                          ),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 8.0,
                                color: Color(0x33000000),
                                offset: Offset(
                                  0.0,
                                  4.0,
                                ),
                                spreadRadius: 0.0,
                              )
                            ],
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                16.0, 16.0, 16.0, 16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select Media',
                                  textAlign: TextAlign.center,
                                  style: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .fontStyle,
                                      ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Temporarily commented out voice feature
                                    // InkWell(
                                    //   splashColor: Colors.transparent,
                                    //   focusColor: Colors.transparent,
                                    //   hoverColor: Colors.transparent,
                                    //   highlightColor: Colors.transparent,
                                    //   onTap: () async {
                                    //     _model.audio = true;
                                    //     safeSetState(() {});
                                    //   },
                                    //   child: Row(
                                    //     mainAxisSize: MainAxisSize.max,
                                    //     mainAxisAlignment:
                                    //         MainAxisAlignment.start,
                                    //     children: [
                                    //       Container(
                                    //         width: 30.0,
                                    //         decoration: BoxDecoration(),
                                    //         child: Align(
                                    //           alignment: AlignmentDirectional(
                                    //               -1.0, 0.0),
                                    //           child: Icon(
                                    //             Icons.mic_rounded,
                                    //             color:
                                    //                 FlutterFlowTheme.of(context)
                                    //                     .primary,
                                    //             size: 24.0,
                                    //           ),
                                    //         ),
                                    //       ),
                                    //       Container(
                                    //         width: 50.0,
                                    //         decoration: BoxDecoration(),
                                    //         child: Text(
                                    //           'Voice',
                                    //           style:
                                    //               FlutterFlowTheme.of(context)
                                    //                   .bodyMedium
                                    //                   .override(
                                    //                     font: GoogleFonts.inter(
                                    //                       fontWeight:
                                    //                           FlutterFlowTheme.of(
                                    //                                   context)
                                    //                               .bodyMedium
                                    //                               .fontWeight,
                                    //                       fontStyle:
                                    //                           FlutterFlowTheme.of(
                                    //                                   context)
                                    //                               .bodyMedium
                                    //                               .fontStyle,
                                    //                     ),
                                    //                     letterSpacing: 0.0,
                                    //                     fontWeight:
                                    //                         FlutterFlowTheme.of(
                                    //                                 context)
                                    //                             .bodyMedium
                                    //                             .fontWeight,
                                    //                     fontStyle:
                                    //                         FlutterFlowTheme.of(
                                    //                                 context)
                                    //                             .bodyMedium
                                    //                             .fontStyle,
                                    //                   ),
                                    //         ),
                                    //       ),
                                    //     ],
                                    //   ),
                                    // ),
                                    Container(
                                      width: double.infinity,
                                      height: 1.0,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                      ),
                                    ),
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        _model.isSendingImage = true;
                                        _model.select = false;
                                        safeSetState(() {});
                                        final selectedMedia = await selectMedia(
                                          mediaSource: MediaSource.photoGallery,
                                          multiImage: true,
                                        );
                                        if (selectedMedia != null &&
                                            selectedMedia.every((m) =>
                                                validateFileFormat(
                                                    m.storagePath, context))) {
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
                                          safeSetState(() => _model
                                                  .isDataUploading_uploadData =
                                              true);
                                          var selectedUploadedFiles =
                                              <FFUploadedFile>[];

                                          var downloadUrls = <String>[];
                                          try {
                                            selectedUploadedFiles =
                                                selectedMedia
                                                    .map((m) => FFUploadedFile(
                                                          name: m.storagePath
                                                              .split('/')
                                                              .last,
                                                          bytes: m.bytes,
                                                          height: m.dimensions
                                                              ?.height,
                                                          width: m.dimensions
                                                              ?.width,
                                                          blurHash: m.blurHash,
                                                        ))
                                                    .toList();

                                            downloadUrls = (await Future.wait(
                                              selectedMedia.map(
                                                (m) async => await uploadData(
                                                    m.storagePath, m.bytes),
                                              ),
                                            ))
                                                .where((u) => u != null)
                                                .map((u) => u!)
                                                .toList();
                                          } finally {
                                            _model.isDataUploading_uploadData =
                                                false;
                                          }
                                          if (selectedUploadedFiles.length ==
                                                  selectedMedia.length &&
                                              downloadUrls.length ==
                                                  selectedMedia.length) {
                                            safeSetState(() {
                                              _model.uploadedLocalFiles_uploadData =
                                                  selectedUploadedFiles;
                                              _model.uploadedFileUrls_uploadData =
                                                  downloadUrls;
                                            });
                                          } else {
                                            safeSetState(() {});
                                            return;
                                          }
                                        }

                                        if ((_model.uploadedFileUrls_uploadData
                                                .isNotEmpty) ==
                                            true) {
                                          _model.images = _model
                                              .uploadedFileUrls_uploadData
                                              .map((url) => url.toString())
                                              .toList();
                                          safeSetState(() {});
                                        }
                                        _model.isSendingImage = false;
                                        safeSetState(() {});
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 30.0,
                                            decoration: const BoxDecoration(),
                                            child: Align(
                                              alignment:
                                                  const AlignmentDirectional(
                                                      -1.0, 0.0),
                                              child: Icon(
                                                Icons.image_rounded,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primary,
                                                size: 24.0,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 50.0,
                                            decoration: const BoxDecoration(),
                                            child: Text(
                                              'Images',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: double.infinity,
                                      height: 1.0,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                      ),
                                    ),
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        _model.isSendingImage = true;
                                        _model.select = false;
                                        safeSetState(() {});
                                        final selectedMedia =
                                            await selectMediaWithSourceBottomSheet(
                                          context: context,
                                          allowPhoto: true,
                                          allowVideo: true,
                                        );
                                        if (selectedMedia != null &&
                                            selectedMedia.every((m) =>
                                                validateFileFormat(
                                                    m.storagePath, context))) {
                                          safeSetState(() => _model
                                                  .isDataUploading_uploadDataCamera =
                                              true);
                                          var selectedUploadedFiles =
                                              <FFUploadedFile>[];

                                          var downloadUrls = <String>[];
                                          try {
                                            selectedUploadedFiles =
                                                selectedMedia
                                                    .map((m) => FFUploadedFile(
                                                          name: m.storagePath
                                                              .split('/')
                                                              .last,
                                                          bytes: m.bytes,
                                                          height: m.dimensions
                                                              ?.height,
                                                          width: m.dimensions
                                                              ?.width,
                                                          blurHash: m.blurHash,
                                                        ))
                                                    .toList();

                                            downloadUrls = (await Future.wait(
                                              selectedMedia.map(
                                                (m) async => await uploadData(
                                                    m.storagePath, m.bytes),
                                              ),
                                            ))
                                                .where((u) => u != null)
                                                .map((u) => u!)
                                                .toList();
                                          } finally {
                                            _model.isDataUploading_uploadDataCamera =
                                                false;
                                          }
                                          if (selectedUploadedFiles.length ==
                                                  selectedMedia.length &&
                                              downloadUrls.length ==
                                                  selectedMedia.length) {
                                            safeSetState(() {
                                              _model.uploadedLocalFile_uploadDataCamera =
                                                  selectedUploadedFiles.first;
                                              _model.uploadedFileUrl_uploadDataCamera =
                                                  downloadUrls.first;
                                            });
                                          } else {
                                            safeSetState(() {});
                                            return;
                                          }
                                        }

                                        if (_model
                                                .uploadedFileUrl_uploadDataCamera !=
                                            '') {
                                          _model.image = _model
                                              .uploadedFileUrl_uploadDataCamera;
                                          safeSetState(() {});
                                        }
                                        _model.isSendingImage = false;
                                        safeSetState(() {});
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 30.0,
                                            decoration: const BoxDecoration(),
                                            child: Align(
                                              alignment:
                                                  const AlignmentDirectional(
                                                      -1.0, 0.0),
                                              child: Icon(
                                                Icons.camera_alt,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primary,
                                                size: 24.0,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 60.0,
                                            decoration: const BoxDecoration(),
                                            child: Text(
                                              'Camera',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: double.infinity,
                                      height: 1.0,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                      ),
                                    ),
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        _model.select = false;
                                        safeSetState(() {});
                                        
                                        // Get original filename from file picker
                                        final pickedFiles =
                                            await FilePicker.platform.pickFiles(
                                          type: FileType.any,
                                          withData: true,
                                          allowMultiple: false,
                                        );

                                        if (pickedFiles == null ||
                                            pickedFiles.files.isEmpty) {
                                          return;
                                        }

                                        final pickedFile =
                                            pickedFiles.files.first;
                                        if (pickedFile.bytes == null) {
                                          return;
                                        }

                                        final originalFileName =
                                            pickedFile.name;

                                        safeSetState(() => _model
                                                .isDataUploading_uploadDataFile =
                                            true);
                                        var selectedUploadedFiles =
                                            <FFUploadedFile>[];

                                        var downloadUrls = <String>[];
                                        try {
                                          // Generate storage path (similar to selectFiles)
                                          // Format: users/{uid}/uploads/{timestamp}.{ext}
                                          final currentUserUid =
                                              currentUserReference?.id ?? '';
                                          final pathPrefix =
                                              'users/$currentUserUid/uploads';
                                          final timestamp = DateTime.now()
                                              .microsecondsSinceEpoch;
                                          final ext = originalFileName
                                                  .contains('.')
                                              ? originalFileName.split('.').last
                                              : 'file';
                                          final storagePath =
                                              '$pathPrefix/$timestamp.$ext';

                                          // Use the original filename instead of storage path
                                          selectedUploadedFiles = [
                                            FFUploadedFile(
                                              name: originalFileName,
                                              bytes: pickedFile.bytes!,
                                            )
                                          ];

                                          downloadUrls = [
                                            (await uploadData(storagePath,
                                                    pickedFile.bytes!)) ??
                                                ''
                                          ].where((u) => u.isNotEmpty).toList();
                                        } finally {
                                          _model.isDataUploading_uploadDataFile =
                                              false;
                                        }
                                        if (selectedUploadedFiles.length == 1 &&
                                            downloadUrls.length == 1) {
                                          safeSetState(() {
                                            _model.uploadedLocalFile_uploadDataFile =
                                                selectedUploadedFiles.first;
                                            _model.uploadedFileUrl_uploadDataFile =
                                                downloadUrls.first;
                                          });
                                        } else {
                                          safeSetState(() {});
                                          return;
                                        }

                                        if (_model.uploadedFileUrl_uploadDataFile != '') {
                                          _model.file = _model
                                              .uploadedFileUrl_uploadDataFile;
                                          safeSetState(() {});
                                        }
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 30.0,
                                            decoration: const BoxDecoration(),
                                            child: Align(
                                              alignment:
                                                  const AlignmentDirectional(
                                                      -1.0, 0.0),
                                              child: Icon(
                                                Icons.attach_file_rounded,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primary,
                                                size: 24.0,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 50.0,
                                            decoration: const BoxDecoration(),
                                            child: Text(
                                              'File',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: double.infinity,
                                      height: 1.0,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                      ),
                                    ),
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        _model.isSendingImage = true;
                                        _model.select = false;
                                        safeSetState(() {});
                                        final selectedMedia =
                                            await selectMediaWithSourceBottomSheet(
                                          context: context,
                                          allowPhoto: false,
                                          allowVideo: true,
                                        );
                                        if (selectedMedia != null &&
                                            selectedMedia.every((m) =>
                                                validateFileFormat(
                                                    m.storagePath, context))) {
                                          // Store the selected video file locally for preview
                                          _model.selectedVideoFile =
                                              selectedMedia.first;
                                          safeSetState(() {});
                                        }
                                        _model.isSendingImage = false;
                                        safeSetState(() {});
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 30.0,
                                            decoration: const BoxDecoration(),
                                            child: Align(
                                              alignment:
                                                  const AlignmentDirectional(
                                                      -1.0, 0.0),
                                              child: Icon(
                                                Icons.videocam,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primary,
                                                size: 24.0,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 50.0,
                                            decoration: const BoxDecoration(),
                                            child: Text(
                                              'Video',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ].divide(const SizedBox(height: 8.0)),
                                ),
                              ].divide(const SizedBox(height: 12.0)),
                            ),
                          ),
                        ),
                      );
                    } else {
                      return Stack(
                        alignment: const AlignmentDirectional(1.0, -1.0),
                        children: [
                          Align(
                            alignment: const AlignmentDirectional(0.0, 0.0),
                            child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                              ),
                              alignment: const AlignmentDirectional(0.0, 0.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment:
                                          const AlignmentDirectional(0.0, 0.0),
                                      child: Container(
                                        decoration: const BoxDecoration(),
                                        child: InkWell(
                                          splashColor: Colors.transparent,
                                          focusColor: Colors.transparent,
                                          hoverColor: Colors.transparent,
                                          highlightColor: Colors.transparent,
                                          onTap: () async {
                                            if (_model.recording == false) {
                                              _model.recording = true;
                                              _model.text =
                                                  'Tap the mic to stop recording your voice.';
                                              safeSetState(() {});
                                              await requestPermission(
                                                  microphonePermission);
                                              if (await getPermissionStatus(
                                                  microphonePermission)) {
                                                await startAudioRecording(
                                                  context,
                                                  audioRecorder:
                                                      _model.audioRecorder ??=
                                                          AudioRecorder(),
                                                );
                                              }
                                              if (animationsMap[
                                                      'containerOnActionTriggerAnimation2'] !=
                                                  null) {
                                                safeSetState(() =>
                                                    hasContainerTriggered2 =
                                                        true);
                                                SchedulerBinding.instance
                                                    .addPostFrameCallback(
                                                        (_) async => animationsMap[
                                                                'containerOnActionTriggerAnimation2']!
                                                            .controller
                                                          ..reset()
                                                          ..repeat());
                                              }
                                            } else {
                                              _model.recording = false;
                                              safeSetState(() {});
                                              if (animationsMap[
                                                      'containerOnActionTriggerAnimation2'] !=
                                                  null) {
                                                animationsMap[
                                                        'containerOnActionTriggerAnimation2']!
                                                    .controller
                                                    .reset();
                                              }
                                              await stopAudioRecording(
                                                audioRecorder:
                                                    _model.audioRecorder,
                                                audioName: 'recordedFileBytes',
                                                onRecordingComplete:
                                                    (audioFilePath,
                                                        audioBytes) {
                                                  _model.stop = audioFilePath;
                                                  _model.recordedFileBytes =
                                                      audioBytes;
                                                },
                                              );

                                              _model.audiopath = functions
                                                  .converAudioPathToString(
                                                      _model.stop);
                                              _model.audio = false;
                                              _model.select = false;
                                              safeSetState(() {});
                                            }

                                            safeSetState(() {});
                                          },
                                          child: Container(
                                            width: 80.0,
                                            height: 80.0,
                                            decoration: BoxDecoration(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.mic,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                              size: 32.0,
                                            ),
                                          ),
                                        ).animateOnActionTrigger(
                                            animationsMap[
                                                'containerOnActionTriggerAnimation2']!,
                                            hasBeenTriggered:
                                                hasContainerTriggered2),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    valueOrDefault<String>(
                                      _model.text,
                                      'Tap the mic to record your voice.',
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_model.recording == false)
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  0.0, 9.0, 16.0, 0.0),
                              child: InkWell(
                                splashColor: Colors.transparent,
                                focusColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                onTap: () async {
                                  _model.audio = false;
                                  safeSetState(() {});
                                },
                                child: Icon(
                                  Icons.close_sharp,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  size: 24.0,
                                ),
                              ),
                            ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


}
