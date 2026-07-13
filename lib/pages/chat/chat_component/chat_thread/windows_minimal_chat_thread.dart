import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/firebase_storage/storage.dart';
import '/backend/firestore/windows_firestore_rest.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../chat_thread_component/desktop_clipboard_paste_helper.dart';

/// Bare-minimum chat thread for Windows/Linux desktop stability.
/// No Quill, no ScrollablePositionedList, no ChatThreadWidget, no live streams.
class WindowsMinimalChatThread extends StatefulWidget {
  const WindowsMinimalChatThread({
    super.key,
    required this.chat,
  });

  final ChatsRecord chat;

  static bool get isEnabled =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux);

  @override
  State<WindowsMinimalChatThread> createState() =>
      _WindowsMinimalChatThreadState();
}

class _WindowsMinimalChatThreadState extends State<WindowsMinimalChatThread> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<MessagesRecord> _messages = [];
  final List<_PendingPaste> _pending = [];

  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _loadMessages();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_loading && !_sending) _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await WindowsFirestoreRest.queryMessages(
        chatRef: widget.chat.reference,
        limit: 80,
      );
      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(list);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final items = await DesktopClipboardPasteHelper.readAll();
      if (items.isEmpty || !mounted) return;
      setState(() {
        for (final item in items) {
          _pending.add(_PendingPaste(item.bytes, item.fileName));
        }
      });
    } catch (e) {
      debugPrint('📋 [win-chat] paste failed: $e');
    }
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _pending.isEmpty) return;
    if (_sending) return;

    setState(() => _sending = true);
    final chatRef = widget.chat.reference;

    try {
      for (final att in List<_PendingPaste>.from(_pending)) {
        final ext = att.fileName.split('.').last.toLowerCase();
        final isImage = [
          'png',
          'jpg',
          'jpeg',
          'gif',
          'webp',
          'bmp',
        ].contains(ext);
        final path =
            'users/$currentUserUid/uploads/${DateTime.now().millisecondsSinceEpoch}_${att.fileName}';
        final url = await uploadData(path, att.bytes);
        if (url == null) continue;

        final attachmentData = createMessagesRecordData(
          senderRef: currentUserReference,
          content: '',
          createdAt: getCurrentTimestamp,
          messageType: isImage ? MessageType.image : MessageType.file,
          image: isImage ? url : null,
          attachmentUrl: isImage ? null : url,
          senderName: currentUserDisplayName,
          senderPhoto: currentUserPhoto,
        );
        await WindowsFirestoreRest.createMessage(
          chatRef: chatRef,
          data: attachmentData,
        );
      }
      _pending.clear();

      if (text.isNotEmpty) {
        await WindowsFirestoreRest.createMessage(
          chatRef: chatRef,
          data: createMessagesRecordData(
            senderRef: currentUserReference,
            content: text,
            createdAt: getCurrentTimestamp,
            messageType: MessageType.text,
            senderName: currentUserDisplayName,
            senderPhoto: currentUserPhoto,
          ),
        );
        await WindowsFirestoreRest.patchDocument(
          ref: chatRef,
          data: {
            'last_message':
                text.length > 100 ? text.substring(0, 100) : text,
            'last_message_at': getCurrentTimestamp,
            'last_message_sent': currentUserReference,
            'last_message_type': MessageType.text.serialize(),
            'last_message_seen': [currentUserReference],
          },
        );
      }

      _textController.clear();
      await _loadMessages(silent: true);
    } catch (e) {
      debugPrint('❌ [win-chat] send failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _plainContent(MessagesRecord m) {
    if (m.content.isEmpty) return '';
    return m.content.replaceAllMapped(
      RegExp(r'<@([^|]+)\|([^>]+)>'),
      (match) => '@${match.group(2)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_error != null)
          Material(
            color: const Color(0xFFFEE2E2),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Could not load messages. Pull to retry.',
                style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12),
              ),
            ),
          ),
        Expanded(
          child: _loading && _messages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(child: Text('No messages yet'))
                  : RefreshIndicator(
                      onRefresh: _loadMessages,
                      child: ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final m = _messages[index];
                          final isMe = m.senderRef == currentUserReference;
                          final plain = _plainContent(m);
                          final imageUrl = m.image.isNotEmpty
                              ? m.image
                              : (m.images.isNotEmpty ? m.images.first : null);

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              constraints: const BoxConstraints(maxWidth: 420),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFF007AFF)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: isMe
                                    ? null
                                    : Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe &&
                                      widget.chat.isGroup &&
                                      m.senderName.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        m.senderName,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  if (plain.isNotEmpty)
                                    Text(
                                      plain,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isMe
                                            ? Colors.white
                                            : const Color(0xFF111827),
                                      ),
                                    ),
                                  if (imageUrl != null) ...[
                                    if (plain.isNotEmpty)
                                      const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        width: 220,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ],
                                  if (m.audio.isNotEmpty || m.video.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        m.video.isNotEmpty
                                            ? '🎬 Video'
                                            : '🎤 Voice',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isMe
                                              ? Colors.white70
                                              : const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
        if (_pending.isNotEmpty)
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _pending.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final p = _pending[i];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        p.bytes,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 64,
                          height: 64,
                          color: const Color(0xFFE5E7EB),
                          child: const Icon(Icons.insert_drive_file),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _pending.removeAt(i)),
                        child: const CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        Material(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Paste image (Ctrl+V)',
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste),
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Message…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                _sending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        onPressed: _send,
                        icon: const Icon(Icons.send, color: Color(0xFF007AFF)),
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PendingPaste {
  _PendingPaste(this.bytes, this.fileName);
  final Uint8List bytes;
  final String fileName;
}
