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
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aligned_dialog/aligned_dialog.dart';
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
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
    final renderBox =
        _menuIconKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (renderBox == null || overlayBox == null) return;

    final topLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final bottomRight = renderBox.localToGlobal(
        renderBox.size.bottomRight(Offset.zero),
        ancestor: overlayBox);
    final position = RelativeRect.fromRect(
      Rect.fromPoints(topLeft.translate(0, -60), bottomRight.translate(0, -60)),
      Offset.zero & overlayBox.size,
    );

    final emojis = <String>[
      '👍',
      '👏',
      '🙌',
      '✅',
      '💯',
      '🔥',
      '❤️',
      '🤔',
      '👀',
    ];
    final selected = await showMenu<String>(
      context: context,
      position: position,
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 6.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < emojis.length; i++)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.of(context).pop(emojis[i]);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4.0, vertical: 4.0),
                      child: Text(
                        emojis[i],
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
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
  Widget _withMessageMenu({required Widget bubble}) {
    final reactionsBadge = _buildReactionsBadge();

    if (!kIsWeb && Platform.isIOS) {
      // iOS: Call parent callback for fixed top menu
      return GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          widget.onMessageLongPress?.call(widget.message!);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bubble,
            // Reactions badge positioned relative to bubble
            if (reactionsBadge != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
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
            bubble,
            if (_isHoveredForMenu || _isMenuOpen)
              Positioned(
                top: -4,
                right: -5,
                child: _messageMenuButton(),
              ),
            // Put badge last so it sits on top of all overlays for reliable taps
            if (reactionsBadge != null)
              Positioned(
                right: -6,
                bottom: -20,
                child: AbsorbPointer(
                  absorbing: false,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.transparent,
                    child: reactionsBadge,
                  ),
                ),
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

    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
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
              if (i != entries.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMe)
          Align(
            alignment: const AlignmentDirectional(-1.0, 0.0),
            child: Builder(
              builder: (context) => InkWell(
                splashColor: Colors.transparent,
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () async {
                  await actions.closekeyboard();
                  await widget.action?.call();
                },
                onLongPress: _openReportDialog,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.8,
                              minWidth: MediaQuery.of(context).size.width * 0.3,
                              minHeight: 60,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Align(
                                  alignment:
                                      const AlignmentDirectional(1.0, -1.0),
                                  child: Padding(
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 12.0, 0.0),
                                    child: InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onLongPress: _copyContentIfAny,
                                      child: _withMessageMenu(
                                        bubble: Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3F4F6),
                                            borderRadius:
                                                BorderRadius.circular(16.0),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Reply indicator
                                                if (widget.message?.replyTo !=
                                                        null &&
                                                    widget.message?.replyTo !=
                                                        '')
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _scrollToRepliedMessage(),
                                                    child: Container(
                                                      width: double.infinity,
                                                      margin:
                                                          const EdgeInsets.only(
                                                              bottom: 8.0),
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8.0),
                                                      decoration: BoxDecoration(
                                                        color: FlutterFlowTheme
                                                                .of(context)
                                                            .primaryBackground,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8.0),
                                                        border: Border(
                                                          left: BorderSide(
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .primary,
                                                            width: 4.0,
                                                          ),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          const SizedBox(
                                                              width: 8.0),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  'Replying to ${widget.message?.replyToSender ?? 'Unknown'}',
                                                                  style: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .override(
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .primary,
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
                                                                  style: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .override(
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .secondaryText,
                                                                      ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Icon(
                                                            Icons
                                                                .keyboard_arrow_up,
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .primary,
                                                            size: 16.0,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                if (widget.message?.content !=
                                                        null &&
                                                    widget.message?.content !=
                                                        '')
                                                  custom_widgets
                                                      .MessageContentWidget(
                                                    content:
                                                        valueOrDefault<String>(
                                                      widget.message?.content,
                                                      'I\'m at the venue now. Here\'s the map with the room highlighted:',
                                                    ),
                                                    senderName: widget.name,
                                                    onTapLink: (text, url,
                                                        title) async {
                                                      if (url != null) {
                                                        await _launchURL(url);
                                                      }
                                                    },
                                                    styleSheet:
                                                        MarkdownStyleSheet(
                                                      p: FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(
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
                                                            color: const Color(
                                                                0xFF1F2937),
                                                            fontSize: 14.0,
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
                                                      a: FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(),
                                                            color: const Color(
                                                                0xFF2563EB),
                                                            fontSize: 14.0,
                                                            letterSpacing: 0.0,
                                                            decoration:
                                                                TextDecoration
                                                                    .underline,
                                                          ),
                                                      code: FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .override(
                                                            font: GoogleFonts
                                                                .robotoMono(),
                                                            color: const Color(
                                                                0xFF1F2937),
                                                            fontSize: 13.0,
                                                          ),
                                                      codeblockDecoration:
                                                          BoxDecoration(
                                                        color: const Color(
                                                            0xFFE5E7EB),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                      ),
                                                      strong: FlutterFlowTheme
                                                              .of(context)
                                                          .bodyMedium
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                            color: const Color(
                                                                0xFF1F2937),
                                                            fontSize: 14.0,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                      em: FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic,
                                                            ),
                                                            color: const Color(
                                                                0xFF1F2937),
                                                            fontSize: 14.0,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                      tableBody:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .override(
                                                                font: GoogleFonts
                                                                    .inter(),
                                                                color: Colors
                                                                    .black,
                                                                fontSize: 14.0,
                                                              ),
                                                      tableHead:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                                color: Colors
                                                                    .black,
                                                                fontSize: 14.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                    ),
                                                  ),
                                                // Edited indicator
                                                if (widget.message?.isEdited ==
                                                    true)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsetsDirectional
                                                            .fromSTEB(
                                                            0.0, 4.0, 0.0, 0.0),
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
                                                            style: FlutterFlowTheme
                                                                    .of(context)
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
                                                                widget.message!
                                                                    .editedAt!),
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
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                if (widget.message?.image !=
                                                        null &&
                                                    widget.message?.image != '')
                                                  Container(
                                                    width: 265.0,
                                                    height: 207.2,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFE5E7EB),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                    ),
                                                    child: InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        await Navigator.push(
                                                          context,
                                                          PageTransition(
                                                            type:
                                                                PageTransitionType
                                                                    .fade,
                                                            child:
                                                                FlutterFlowExpandedImageView(
                                                              image:
                                                                  CachedNetworkImage(
                                                                fadeInDuration:
                                                                    const Duration(
                                                                        milliseconds:
                                                                            300),
                                                                fadeOutDuration:
                                                                    const Duration(
                                                                        milliseconds:
                                                                            300),
                                                                imageUrl:
                                                                    valueOrDefault<
                                                                        String>(
                                                                  widget.message
                                                                      ?.image,
                                                                  'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                ),
                                                                fit: BoxFit
                                                                    .contain,
                                                              ),
                                                              allowRotation:
                                                                  false,
                                                              tag:
                                                                  valueOrDefault<
                                                                      String>(
                                                                widget.message
                                                                    ?.image,
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
                                                          widget.message?.image,
                                                          'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                        ),
                                                        transitionOnUserGestures:
                                                            true,
                                                        child: ClipRRect(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                          child:
                                                              CachedNetworkImage(
                                                            fadeInDuration:
                                                                const Duration(
                                                                    milliseconds:
                                                                        300),
                                                            fadeOutDuration:
                                                                const Duration(
                                                                    milliseconds:
                                                                        300),
                                                            imageUrl:
                                                                valueOrDefault<
                                                                    String>(
                                                              widget.message
                                                                  ?.image,
                                                              'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                            ),
                                                            width: 222.23,
                                                            height: 144.0,
                                                            fit: BoxFit.cover,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                if (widget.message?.video !=
                                                        null &&
                                                    widget.message?.video != '')
                                                  Container(
                                                    width: 265.0,
                                                    height: 200.0,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFE5E7EB),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                    ),
                                                    child: VideoMessageWidget(
                                                      videoUrl: widget
                                                              .message?.video ??
                                                          '',
                                                      width: 265.0,
                                                      height: 200.0,
                                                      isOwnMessage: isMe,
                                                    ),
                                                  ),
                                                if ((widget.message?.images !=
                                                            null &&
                                                        (widget.message
                                                                ?.images)!
                                                            .isNotEmpty) ==
                                                    true)
                                                  Material(
                                                    color: Colors.transparent,
                                                    elevation: 0.0,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                    ),
                                                    child: Container(
                                                      width: 265.0,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.transparent,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8.0),
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
                                                                return InkWell(
                                                                  splashColor:
                                                                      Colors
                                                                          .transparent,
                                                                  focusColor: Colors
                                                                      .transparent,
                                                                  hoverColor: Colors
                                                                      .transparent,
                                                                  highlightColor:
                                                                      Colors
                                                                          .transparent,
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
                                                                              multipleImagesItem,
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
                                                                            multipleImagesItem,
                                                                            'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683$multipleImagesIndex',
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
                                                                      multipleImagesItem,
                                                                      'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683$multipleImagesIndex',
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
                                                                          multipleImagesItem,
                                                                          'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                        ),
                                                                        width: double
                                                                            .infinity,
                                                                        height:
                                                                            207.2,
                                                                        fit: BoxFit
                                                                            .cover,
                                                                        errorWidget: (context,
                                                                                error,
                                                                                stackTrace) =>
                                                                            Image.asset(
                                                                          'assets/images/error_image.png',
                                                                          width:
                                                                              double.infinity,
                                                                          height:
                                                                              207.2,
                                                                          fit: BoxFit
                                                                              .cover,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
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
                                                    widget.message?.audio != '')
                                                  Container(
                                                    width: double.infinity,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFE5E7EB),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                    ),
                                                    child:
                                                        FlutterFlowAudioPlayer(
                                                      audio: Audio.network(
                                                        widget
                                                            .message!.audioPath,
                                                        metas: Metas(
                                                          title: 'Voice',
                                                        ),
                                                      ),
                                                      titleTextStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .titleLarge
                                                              .override(
                                                                font:
                                                                    GoogleFonts
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
                                                                fontSize: 16.0,
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
                                                                font:
                                                                    GoogleFonts
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
                                                  Builder(
                                                    builder: (context) =>
                                                        InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        await showDialog(
                                                          context: context,
                                                          builder:
                                                              (dialogContext) {
                                                            return Dialog(
                                                              elevation: 0,
                                                              insetPadding:
                                                                  EdgeInsets
                                                                      .zero,
                                                              backgroundColor:
                                                                  Colors
                                                                      .transparent,
                                                              alignment: const AlignmentDirectional(
                                                                      0.0, 0.0)
                                                                  .resolve(
                                                                      Directionality.of(
                                                                          context)),
                                                              child:
                                                                  PDFViewWidget(
                                                                url: widget
                                                                    .message!
                                                                    .attachmentUrl,
                                                              ),
                                                            );
                                                          },
                                                        );
                                                      },
                                                      child: Container(
                                                        width: double.infinity,
                                                        height: 65.0,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      12.0),
                                                        ),
                                                        child: Align(
                                                          alignment:
                                                              const AlignmentDirectional(
                                                                  0.0, 0.0),
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(9.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Text(
                                                                  'View PDF File',
                                                                  style: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .override(
                                                                        font: GoogleFonts
                                                                            .inter(
                                                                          fontWeight: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontWeight,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                        letterSpacing:
                                                                            0.0,
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontStyle,
                                                                      ),
                                                                ),
                                                                Icon(
                                                                  Icons
                                                                      .cloud_download,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primary,
                                                                  size: 24.0,
                                                                ),
                                                              ].divide(
                                                                  const SizedBox(
                                                                      width:
                                                                          15.0)),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ].divide(
                                                  const SizedBox(height: 8.0)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                      12.0, 0.0, 12.0, 0.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        'You',
                                        style: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontStyle,
                                              ),
                                              color: const Color(0xFF6B7280),
                                              fontSize: 12.0,
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontStyle,
                                            ),
                                      ),
                                      Text(
                                        ' • ',
                                        style: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .override(
                                              font: GoogleFonts.inter(),
                                              color: const Color(0xFF6B7280),
                                              fontSize: 12.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                      Text(
                                        valueOrDefault<String>(
                                          dateTimeFormat("relative",
                                              widget.message?.createdAt),
                                          'N/A',
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontStyle,
                                              ),
                                              color: const Color(0xFF6B7280),
                                              fontSize: 12.0,
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontStyle,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ].divide(const SizedBox(height: 4.0)),
                            ),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16.0),
                          child: CachedNetworkImage(
                            fadeInDuration: const Duration(milliseconds: 300),
                            fadeOutDuration: const Duration(milliseconds: 300),
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
            alignment: const AlignmentDirectional(1.0, 0.0),
            child: Builder(
              builder: (context) => InkWell(
                splashColor: Colors.transparent,
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () async {
                  await actions.closekeyboard();
                  await widget.action?.call();
                },
                onLongPress: _openReportDialog,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16.0),
                          child: CachedNetworkImage(
                            fadeInDuration: const Duration(milliseconds: 300),
                            fadeOutDuration: const Duration(milliseconds: 300),
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
                              maxWidth: MediaQuery.of(context).size.width * 0.8,
                              minWidth: MediaQuery.of(context).size.width * 0.3,
                              minHeight: 60,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Align(
                                  alignment:
                                      const AlignmentDirectional(-1.0, -1.0),
                                  child: Padding(
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 12.0, 0.0),
                                    child: InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onLongPress: _copyContentIfAny,
                                      child: _withMessageMenu(
                                        bubble: Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3F4F6),
                                            borderRadius:
                                                BorderRadius.circular(16.0),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                // Reply indicator
                                                if (widget.message?.replyTo !=
                                                        null &&
                                                    widget.message?.replyTo !=
                                                        '')
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _scrollToRepliedMessage(),
                                                    child: Container(
                                                      width: double.infinity,
                                                      margin:
                                                          const EdgeInsets.only(
                                                              bottom: 8.0),
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8.0),
                                                      decoration: BoxDecoration(
                                                        color: FlutterFlowTheme
                                                                .of(context)
                                                            .primaryBackground,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8.0),
                                                        border: Border(
                                                          left: BorderSide(
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .primary,
                                                            width: 4.0,
                                                          ),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          const SizedBox(
                                                              width: 8.0),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  'Replying to ${widget.message?.replyToSender ?? 'Unknown'}',
                                                                  style: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .override(
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .primary,
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
                                                                  style: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .override(
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .secondaryText,
                                                                      ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Icon(
                                                            Icons
                                                                .keyboard_arrow_up,
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .primary,
                                                            size: 16.0,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                if (widget.message?.content !=
                                                        null &&
                                                    widget.message?.content !=
                                                        '')
                                                  custom_widgets
                                                      .MessageContentWidget(
                                                    content:
                                                        valueOrDefault<String>(
                                                      widget.message?.content,
                                                      'I\'m at the venue now. Here\'s the map with the room highlighted:',
                                                    ),
                                                    senderName: widget.name,
                                                    onTapLink: (text, url,
                                                        title) async {
                                                      if (url != null) {
                                                        await _launchURL(url);
                                                      }
                                                    },
                                                    styleSheet:
                                                        MarkdownStyleSheet(
                                                      p: FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(
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
                                                            color: const Color(
                                                                0xFF1F2937),
                                                            fontSize: 14.0,
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
                                                      a: FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(),
                                                            color: const Color(
                                                                0xFF2563EB),
                                                            fontSize: 14.0,
                                                            letterSpacing: 0.0,
                                                            decoration:
                                                                TextDecoration
                                                                    .underline,
                                                          ),
                                                      code: FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .override(
                                                            font: GoogleFonts
                                                                .robotoMono(),
                                                            color: const Color(
                                                                0xFF1F2937),
                                                            fontSize: 13.0,
                                                          ),
                                                      codeblockDecoration:
                                                          BoxDecoration(
                                                        color: const Color(
                                                            0xFFE5E7EB),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                      ),
                                                      strong: FlutterFlowTheme
                                                              .of(context)
                                                          .bodyMedium
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                            color: const Color(
                                                                0xFF1F2937),
                                                            fontSize: 14.0,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                      em: FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic,
                                                            ),
                                                            color: const Color(
                                                                0xFF1F2937),
                                                            fontSize: 14.0,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                      tableBody:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .override(
                                                                font: GoogleFonts
                                                                    .inter(),
                                                                color: Colors
                                                                    .black,
                                                                fontSize: 14.0,
                                                              ),
                                                      tableHead:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                                color: Colors
                                                                    .black,
                                                                fontSize: 14.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                    ),
                                                  ),
                                                // Edited indicator
                                                if (widget.message?.isEdited ==
                                                    true)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsetsDirectional
                                                            .fromSTEB(
                                                            0.0, 4.0, 0.0, 0.0),
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
                                                            style: FlutterFlowTheme
                                                                    .of(context)
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
                                                                widget.message!
                                                                    .editedAt!),
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
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                if (widget.message?.image !=
                                                        null &&
                                                    widget.message?.image != '')
                                                  Container(
                                                    width: 265.0,
                                                    height: 207.2,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFE5E7EB),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                    ),
                                                    child: InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        await Navigator.push(
                                                          context,
                                                          PageTransition(
                                                            type:
                                                                PageTransitionType
                                                                    .fade,
                                                            child:
                                                                FlutterFlowExpandedImageView(
                                                              image:
                                                                  CachedNetworkImage(
                                                                fadeInDuration:
                                                                    const Duration(
                                                                        milliseconds:
                                                                            300),
                                                                fadeOutDuration:
                                                                    const Duration(
                                                                        milliseconds:
                                                                            300),
                                                                imageUrl:
                                                                    valueOrDefault<
                                                                        String>(
                                                                  widget.message
                                                                      ?.image,
                                                                  'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                ),
                                                                fit: BoxFit
                                                                    .contain,
                                                                errorWidget: (context,
                                                                        error,
                                                                        stackTrace) =>
                                                                    Image.asset(
                                                                  'assets/images/error_image.png',
                                                                  fit: BoxFit
                                                                      .contain,
                                                                ),
                                                              ),
                                                              allowRotation:
                                                                  false,
                                                              tag:
                                                                  valueOrDefault<
                                                                      String>(
                                                                widget.message
                                                                    ?.image,
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
                                                          widget.message?.image,
                                                          'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                        ),
                                                        transitionOnUserGestures:
                                                            true,
                                                        child: ClipRRect(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                          child:
                                                              CachedNetworkImage(
                                                            fadeInDuration:
                                                                const Duration(
                                                                    milliseconds:
                                                                        300),
                                                            fadeOutDuration:
                                                                const Duration(
                                                                    milliseconds:
                                                                        300),
                                                            imageUrl:
                                                                valueOrDefault<
                                                                    String>(
                                                              widget.message
                                                                  ?.image,
                                                              'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                            ),
                                                            width: 222.2,
                                                            height: 144.0,
                                                            fit: BoxFit.cover,
                                                            errorWidget: (context,
                                                                    error,
                                                                    stackTrace) =>
                                                                Image.asset(
                                                              'assets/images/error_image.png',
                                                              width: 222.2,
                                                              height: 144.0,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                if (widget.message?.video !=
                                                        null &&
                                                    widget.message?.video != '')
                                                  Container(
                                                    width: 265.0,
                                                    height: 200.0,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFE5E7EB),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                    ),
                                                    child: VideoMessageWidget(
                                                      videoUrl: widget
                                                              .message?.video ??
                                                          '',
                                                      width: 265.0,
                                                      height: 200.0,
                                                      isOwnMessage: isMe,
                                                    ),
                                                  ),
                                                if ((widget.message?.images !=
                                                            null &&
                                                        (widget.message
                                                                ?.images)!
                                                            .isNotEmpty) ==
                                                    true)
                                                  Material(
                                                    color: Colors.transparent,
                                                    elevation: 0.0,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                    ),
                                                    child: Container(
                                                      width: 265.0,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.transparent,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8.0),
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
                                                                return InkWell(
                                                                  splashColor:
                                                                      Colors
                                                                          .transparent,
                                                                  focusColor: Colors
                                                                      .transparent,
                                                                  hoverColor: Colors
                                                                      .transparent,
                                                                  highlightColor:
                                                                      Colors
                                                                          .transparent,
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
                                                                              multipleImagesItem,
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
                                                                            multipleImagesItem,
                                                                            'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683$multipleImagesIndex',
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
                                                                      multipleImagesItem,
                                                                      'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683$multipleImagesIndex',
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
                                                                          multipleImagesItem,
                                                                          'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                        ),
                                                                        width: double
                                                                            .infinity,
                                                                        height:
                                                                            207.2,
                                                                        fit: BoxFit
                                                                            .cover,
                                                                        errorWidget: (context,
                                                                                error,
                                                                                stackTrace) =>
                                                                            Image.asset(
                                                                          'assets/images/error_image.png',
                                                                          width:
                                                                              double.infinity,
                                                                          height:
                                                                              207.2,
                                                                          fit: BoxFit
                                                                              .cover,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
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
                                                    widget.message?.audio != '')
                                                  Container(
                                                    width: double.infinity,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFE5E7EB),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                    ),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
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
                                                      ],
                                                    ),
                                                  ),
                                                if (widget.message
                                                            ?.attachmentUrl !=
                                                        null &&
                                                    widget.message
                                                            ?.attachmentUrl !=
                                                        '')
                                                  Builder(
                                                    builder: (context) =>
                                                        InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        await showDialog(
                                                          context: context,
                                                          builder:
                                                              (dialogContext) {
                                                            return Dialog(
                                                              elevation: 0,
                                                              insetPadding:
                                                                  EdgeInsets
                                                                      .zero,
                                                              backgroundColor:
                                                                  Colors
                                                                      .transparent,
                                                              alignment: const AlignmentDirectional(
                                                                      0.0, 0.0)
                                                                  .resolve(
                                                                      Directionality.of(
                                                                          context)),
                                                              child:
                                                                  PDFViewWidget(
                                                                url: widget
                                                                    .message!
                                                                    .attachmentUrl,
                                                              ),
                                                            );
                                                          },
                                                        );
                                                      },
                                                      child: Container(
                                                        width: double.infinity,
                                                        height: 65.0,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      12.0),
                                                        ),
                                                        child: Align(
                                                          alignment:
                                                              const AlignmentDirectional(
                                                                  0.0, 0.0),
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(9.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Text(
                                                                  'View PDF File',
                                                                  style: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .override(
                                                                        font: GoogleFonts
                                                                            .inter(
                                                                          fontWeight: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontWeight,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                        letterSpacing:
                                                                            0.0,
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontStyle,
                                                                      ),
                                                                ),
                                                                Icon(
                                                                  Icons
                                                                      .cloud_download,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primary,
                                                                  size: 24.0,
                                                                ),
                                                              ].divide(
                                                                  const SizedBox(
                                                                      width:
                                                                          15.0)),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ].divide(
                                                  const SizedBox(height: 8.0)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment:
                                      const AlignmentDirectional(-1.0, -1.0),
                                  child: Padding(
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 12.0, 0.0),
                                    child: RichText(
                                      textScaler:
                                          MediaQuery.of(context).textScaler,
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: valueOrDefault<String>(
                                              widget.name,
                                              'No One',
                                            ),
                                            style: FlutterFlowTheme.of(context)
                                                .bodySmall
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodySmall
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodySmall
                                                            .fontStyle,
                                                  ),
                                                  color:
                                                      const Color(0xFF6B7280),
                                                  fontSize: 12.0,
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodySmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodySmall
                                                          .fontStyle,
                                                ),
                                          ),
                                          const TextSpan(
                                            text: ' • ',
                                            style: TextStyle(),
                                          ),
                                          TextSpan(
                                            text: valueOrDefault<String>(
                                              dateTimeFormat("relative",
                                                  widget.message?.createdAt),
                                              'N/A',
                                            ),
                                            style: const TextStyle(),
                                          )
                                        ],
                                        style: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontStyle,
                                              ),
                                              color: const Color(0xFF6B7280),
                                              fontSize: 12.0,
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontStyle,
                                            ),
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
  }
}

enum _MsgAction { react, copy, report, unsend, reply, edit }

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
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          // ignore: avoid_print
          print('Reaction tapped: ' + emoji);
          onTap(emoji);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 18),
              ),
              if (count > 1)
                Padding(
                  padding: const EdgeInsets.only(left: 2.0),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
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
