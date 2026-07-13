import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';

/// Lightweight message row for Windows desktop — avoids heavy [ChatThreadWidget]
/// (voice players, video init, auto-translate, reaction overlays).
class WindowsChatMessageTile extends StatelessWidget {
  const WindowsChatMessageTile({
    super.key,
    required this.message,
    required this.senderName,
    required this.senderPhoto,
    required this.isGroup,
    this.showTimestamp = true,
  });

  final MessagesRecord message;
  final String senderName;
  final String senderPhoto;
  final bool isGroup;
  final bool showTimestamp;

  bool get _isMe => message.senderRef == currentUserReference;

  String get _displayText {
    var text = message.content;
    if (text.isEmpty) return '';
    return text.replaceAllMapped(
      RegExp(r'<@([^|]+)\|([^>]+)>'),
      (m) => '@${m.group(2)}',
    );
  }

  String? get _imageUrl {
    if (message.image.isNotEmpty) return message.image;
    if (message.images.isNotEmpty) return message.images.first;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl;
    final hasVoice = message.audio.isNotEmpty || message.audioPath.isNotEmpty;
    final hasVideo = message.video.isNotEmpty;
    final hasFile = message.attachmentUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            _isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_isMe && isGroup) ...[
            _avatar(28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: _isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!_isMe && isGroup && senderName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(
                      senderName,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _isMe ? const Color(0xFF007AFF) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: _isMe
                        ? null
                        : Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_displayText.isNotEmpty)
                        Text(
                          _displayText,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: _isMe ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                      if (imageUrl != null) ...[
                        if (_displayText.isNotEmpty) const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 240,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const SizedBox(
                              width: 240,
                              height: 120,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                          ),
                        ),
                      ],
                      if (hasVoice)
                        _mediaChip(
                          Icons.mic,
                          'Voice message',
                          _isMe,
                        ),
                      if (hasVideo)
                        _mediaChip(
                          Icons.videocam,
                          'Video',
                          _isMe,
                        ),
                      if (hasFile && imageUrl == null && !hasVideo)
                        _mediaChip(
                          Icons.attach_file,
                          'Attachment',
                          _isMe,
                        ),
                      if (showTimestamp && message.createdAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _formatTime(message.createdAt!),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: _isMe
                                  ? Colors.white.withValues(alpha: 0.75)
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isMe && isGroup) ...[
            const SizedBox(width: 8),
            _avatar(28),
          ],
        ],
      ),
    );
  }

  Widget _avatar(double size) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFE5E7EB),
      backgroundImage:
          senderPhoto.isNotEmpty ? NetworkImage(senderPhoto) : null,
      child: senderPhoto.isEmpty
          ? Icon(Icons.person, size: size * 0.5, color: const Color(0xFF9CA3AF))
          : null,
    );
  }

  Widget _mediaChip(IconData icon, String label, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isMe ? Colors.white : const Color(0xFF6B7280),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: isMe ? Colors.white : const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}
