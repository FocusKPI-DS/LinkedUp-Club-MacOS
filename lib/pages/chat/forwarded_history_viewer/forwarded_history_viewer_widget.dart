import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '/utils/chat_message_font.dart';

class ForwardedHistoryViewerWidget extends StatefulWidget {
  final String historyJson;
  
  const ForwardedHistoryViewerWidget({
    Key? key,
    required this.historyJson,
  }) : super(key: key);

  @override
  State<ForwardedHistoryViewerWidget> createState() => _ForwardedHistoryViewerWidgetState();
}

class _ForwardedHistoryViewerWidgetState extends State<ForwardedHistoryViewerWidget> {
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    try {
      final decoded = jsonDecode(widget.historyJson) as List<dynamic>;
      _messages = decoded.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error parsing forwarded history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // iOS group table background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back, color: Color(0xFF007AFF)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Chat History',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            fontFamily: chatMessageFontFamily,
          ),
        ),
        centerTitle: true,
      ),
      body: _messages.isEmpty
          ? const Center(child: Text('Empty history or failed to load'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final senderName = msg['sender_name'] ?? 'Unknown';
                final senderPhoto = msg['sender_photo']?.toString();
                final content = msg['content'] ?? '';
                final createdAtMs = msg['created_at'];
                final image = msg['image']?.toString();
                final imagesList = msg['images'] as List<dynamic>?;
                final video = msg['video']?.toString();
                final audio = msg['audio']?.toString() ?? msg['audio_path']?.toString();
                final attachment = msg['attachment_url']?.toString();

                final hasImage = image != null && image.isNotEmpty;
                final hasImagesList = imagesList != null && imagesList.isNotEmpty;
                final hasVideo = video != null && video.isNotEmpty;
                final hasAudio = audio != null && audio.isNotEmpty;
                final hasAttachment = attachment != null && attachment.isNotEmpty;

                DateTime? createdAt;
                if (createdAtMs != null) {
                  createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtMs as int);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0, left: 16.0, right: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar rendering
                      if (senderPhoto != null && senderPhoto.isNotEmpty)
                        ClipOval(
                          child: Image.network(
                            senderPhoto,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(senderName),
                          ),
                        )
                      else
                        _buildFallbackAvatar(senderName),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  senderName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Color(0xFF8E8E93),
                                  ),
                                ),
                                if (createdAt != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('MMM d, h:mm a').format(createdAt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFC7C7CC),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4.0),
                            // Render Content
                            if (content.isNotEmpty)
                              Text(
                                content,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black,
                                  height: 1.3,
                                ),
                              ),
                            if (hasImage)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: GestureDetector(
                                  onTap: () async {
                                    await showDialog(
                                      context: context,
                                      builder: (context) => Dialog(
                                        backgroundColor: Colors.transparent,
                                        insetPadding: EdgeInsets.zero,
                                        child: Stack(
                                          fit: StackFit.loose,
                                          alignment: Alignment.center,
                                          children: [
                                            InteractiveViewer(
                                              child: Image.network(image),
                                            ),
                                            Positioned(
                                              top: 40,
                                              right: 20,
                                              child: IconButton(
                                                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                                onPressed: () => Navigator.of(context).pop(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRuttaBox(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      image,
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            if (hasImagesList)
                              ...imagesList.map((imgUrlObj) {
                                final imgUrl = imgUrlObj.toString();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                                  child: GestureDetector(
                                    onTap: () async {
                                      await showDialog(
                                        context: context,
                                        builder: (context) => Dialog(
                                          backgroundColor: Colors.transparent,
                                          insetPadding: EdgeInsets.zero,
                                          child: Stack(
                                            fit: StackFit.loose,
                                            alignment: Alignment.center,
                                            children: [
                                              InteractiveViewer(
                                                child: Image.network(imgUrl),
                                              ),
                                              Positioned(
                                                top: 40,
                                                right: 20,
                                                child: IconButton(
                                                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                                  onPressed: () => Navigator.of(context).pop(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    child: ClipRuttaBox(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        imgUrl,
                                        width: 200,
                                        height: 200,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            if (hasVideo)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF007AFF).withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(CupertinoIcons.video_camera_solid, color: Color(0xFF007AFF)),
                                      SizedBox(width: 8),
                                      Text('Video Attachment', style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            if (hasAudio)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF34C759).withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF34C759).withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(CupertinoIcons.mic_solid, color: Color(0xFF34C759)),
                                      SizedBox(width: 8),
                                      Text('Voice Message', style: TextStyle(color: Color(0xFF34C759), fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            if (hasAttachment)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(CupertinoIcons.doc_fill, color: Colors.black54),
                                      SizedBox(width: 8),
                                      Text('File Attachment', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildFallbackAvatar(String senderName) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          senderName.isNotEmpty ? senderName.substring(0, 1).toUpperCase() : '?',
          style: const TextStyle(
            color: Color(0xFF007AFF),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

// Temporary fallback for ClipRRect to avoid compilation issues if undefined
class ClipRuttaBox extends StatelessWidget {
  final BorderRadius borderRadius;
  final Widget child;

  const ClipRuttaBox({Key? key, required this.borderRadius, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(borderRadius: borderRadius, child: child);
  }
}
