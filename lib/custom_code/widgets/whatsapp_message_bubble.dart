import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '/custom_code/widgets/message_content_widget.dart' as custom_widgets;

class WhatsAppMessageBubble extends StatelessWidget {
  final String? content;
  final String? image;
  final String? video;
  final List<String>? images;
  final String senderName;
  final bool isMe;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const WhatsAppMessageBubble({
    Key? key,
    this.content,
    this.image,
    this.video,
    this.images,
    required this.senderName,
    required this.isMe,
    this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFF3F4F6) : Colors.white,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image as main content (WhatsApp style)
            if (image != null && image != '')
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: 300.0,
                  minHeight: 200.0,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.0),
                    topRight: Radius.circular(16.0),
                    bottomLeft: Radius.circular(
                        content != null && content != '' ? 4.0 : 16.0),
                    bottomRight: Radius.circular(
                        content != null && content != '' ? 4.0 : 16.0),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.0),
                    topRight: Radius.circular(16.0),
                    bottomLeft: Radius.circular(
                        content != null && content != '' ? 4.0 : 16.0),
                    bottomRight: Radius.circular(
                        content != null && content != '' ? 4.0 : 16.0),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: image!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),

            // Video as main content
            if (video != null && video != '')
              Container(
                width: double.infinity,
                height: 200.0,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.0),
                    topRight: Radius.circular(16.0),
                    bottomLeft: Radius.circular(
                        content != null && content != '' ? 4.0 : 16.0),
                    bottomRight: Radius.circular(
                        content != null && content != '' ? 4.0 : 16.0),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.0),
                    topRight: Radius.circular(16.0),
                    bottomLeft: Radius.circular(
                        content != null && content != '' ? 4.0 : 16.0),
                    bottomRight: Radius.circular(
                        content != null && content != '' ? 4.0 : 16.0),
                  ),
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 50.0,
                      ),
                    ),
                  ),
                ),
              ),

            // Multiple images
            if (images != null && images!.isNotEmpty)
              Container(
                width: double.infinity,
                height: 200.0,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.0),
                    topRight: Radius.circular(16.0),
                    bottomLeft: Radius.circular(
                        content != null && content != '' ? 4.0 : 16.0),
                    bottomRight: Radius.circular(
                        content != null && content != '' ? 4.0 : 16.0),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.0),
                    topRight: Radius.circular(16.0),
                    bottomLeft: Radius.circular(
                        content != null && content != '' ? 4.0 : 16.0),
                    bottomRight: Radius.circular(
                        content != null && content != '' ? 4.0 : 16.0),
                  ),
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: images!.length,
                    itemBuilder: (context, index) {
                      return CachedNetworkImage(
                        imageUrl: images![index],
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
              ),

            // Text content below image (WhatsApp style)
            if (content != null && content != '')
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: custom_widgets.MessageContentWidget(
                  content: content!,
                  senderName: senderName,
                  onTapLink: (text, url, title) async {
                    if (url != null) {
                      await launchUrl(Uri.parse(url));
                    }
                  },
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      fontFamily: 'Inter',
                      color: const Color(0xFF1F2937),
                      fontSize: 14.0,
                      letterSpacing: 0.0,
                    ),
                    a: TextStyle(
                      fontFamily: 'Inter',
                      color: const Color(0xFF2563EB),
                      fontSize: 14.0,
                      letterSpacing: 0.0,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
