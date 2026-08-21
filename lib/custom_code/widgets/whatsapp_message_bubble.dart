import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '/utils/qurio_url_launcher.dart';
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

  static const double _gap = 2.0;
  static const double _tileSize = 90.0; // Each tile is square

  /// Build a WeChat-style uniform grid (九宫格).
  /// 1 image: full width. 2: 2-col. 3-9: 3-col grid. >9: 3x3 grid + scroll strip.
  Widget _buildImageGrid(BuildContext context) {
    final imgs = images!;
    final count = imgs.length;
    final hasText = content != null && content != '';
    final outerRadius = BorderRadius.only(
      topLeft: const Radius.circular(16.0),
      topRight: const Radius.circular(16.0),
      bottomLeft: Radius.circular(hasText ? 4.0 : 16.0),
      bottomRight: Radius.circular(hasText ? 4.0 : 16.0),
    );

    Widget grid;

    if (count == 1) {
      // Single image — full width
      grid = SizedBox(
        height: 200,
        child: _buildImageTile(imgs[0]),
      );
    } else if (count <= 9) {
      // Uniform grid: 2 cols for 2 or 4 images, 3 cols otherwise
      final cols = (count == 2 || count == 4) ? 2 : 3;
      final rows = (count / cols).ceil();
      grid = _buildUniformGrid(imgs, cols, rows, count);
    } else {
      // >9 images: show 3x3 grid with "+N" overlay on 9th cell,
      // plus horizontal scroll strip below for all images
      grid = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUniformGrid(imgs.sublist(0, 9), 3, 3, count),
          const SizedBox(height: _gap),
          // Horizontal scroll strip for all images
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: count,
              separatorBuilder: (_, __) => const SizedBox(width: _gap),
              itemBuilder: (context, index) => SizedBox(
                width: 60,
                height: 60,
                child: _buildImageTile(imgs[index]),
              ),
            ),
          ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: outerRadius,
      child: Container(
        color: const Color(0xFFE5E7EB),
        child: grid,
      ),
    );
  }

  /// Build a uniform grid of [cols] x [rows] with equal-sized tiles.
  /// [totalCount] is the total images count (used for +N overlay).
  Widget _buildUniformGrid(List<String> imgs, int cols, int rows, int totalCount) {
    final displayCount = imgs.length;
    final showOverlay = totalCount > displayCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rows, (row) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (row > 0) const SizedBox(height: _gap),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(cols, (col) {
                final index = row * cols + col;
                if (index >= displayCount) {
                  // Empty cell — keep spacing uniform
                  return SizedBox(width: _tileSize, height: _tileSize);
                }

                final isLastCell = showOverlay && index == displayCount - 1;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (col > 0) const SizedBox(width: _gap),
                    SizedBox(
                      width: _tileSize,
                      height: _tileSize,
                      child: isLastCell
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildImageTile(imgs[index]),
                                Container(
                                  color: Colors.black.withOpacity(0.55),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '+${totalCount - displayCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'SF Pro Text',
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _buildImageTile(imgs[index]),
                    ),
                  ],
                );
              }),
            ),
          ],
        );
      }),
    );
  }

  /// Build a single image tile with cover fit and loading placeholder.
  Widget _buildImageTile(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4.0),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: const Color(0xFFE5E7EB),
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: const Color(0xFFE5E7EB),
          child: const Icon(Icons.broken_image, color: Colors.grey, size: 24),
        ),
      ),
    );
  }

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

            // Multiple images — Discord-style adaptive grid
            if (images != null && images!.isNotEmpty)
              _buildImageGrid(context),

            // Text content below image (WhatsApp style)
            if (content != null && content != '')
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: custom_widgets.MessageContentWidget(
                  content: content!,
                  senderName: senderName,
                  onTapLink: (text, url, title) async {
                    if (url != null) {
                      await qurioLaunchUrl(url);
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
