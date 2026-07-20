import '/flutter_flow/flutter_flow_expanded_image_view.dart';
import '/utils/desktop_pointer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Photo stack inside the same white message bubble as a single photo.
///
/// Bubble chrome matches [ChatThreadWidget]: white fill, 18px radius, 1px border,
/// 400px media width, 14×10 padding, with a 300×300 image inside.
class PhotoStackBubble extends StatefulWidget {
  const PhotoStackBubble({
    super.key,
    required this.imageUrls,
    required this.isMine,
    this.messageId,
    this.senderName,
    this.isGroup = false,
    this.isConsecutive = false,
    this.isFollowedByConsecutive = false,
  });

  final List<String> imageUrls;
  final bool isMine;
  final String? messageId;
  final String? senderName;
  final bool isGroup;
  final bool isConsecutive;
  final bool isFollowedByConsecutive;

  @override
  State<PhotoStackBubble> createState() => _PhotoStackBubbleState();
}

class _PhotoStackBubbleState extends State<PhotoStackBubble> {
  // Match ChatThreadWidget media bubble + inner image sizes.
  static const double _bubbleWidth = 400;
  static const double _imageSize = 300;
  static const BorderRadius _imageRadius =
      BorderRadius.all(Radius.circular(8));

  late final PageController _pageController;
  int _index = 0;

  List<String> get _urls =>
      widget.imageUrls.where((u) => u.trim().isNotEmpty).toList();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openImage(
    String url, {
    required int index,
    String? heroTag,
  }) async {
    if (!mounted || url.isEmpty) return;
    final urls = _urls;
    await FlutterFlowExpandedImageView.show(
      context,
      image: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
      ),
      allowRotation: false,
      useHeroAnimation: heroTag != null,
      tag: heroTag,
      imageUrl: url,
      imageUrls: urls.length > 1 ? urls : null,
      initialIndex: index,
    );
  }

  void _showSeeAllGrid() {
    final urls = _urls;
    if (urls.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Photos (${urls.length})',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded,
                            color: Color(0xFF64748B)),
                      ).withClickCursor(),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: urls.length,
                    itemBuilder: (context, i) {
                      final url = urls[i];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          mouseCursor: SystemMouseCursors.click,
                          onTap: () async {
                            Navigator.of(dialogContext).pop();
                            await _openImage(
                              url,
                              index: i,
                              heroTag: 'stack_grid_${widget.messageId}_$i',
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              memCacheWidth: 360,
                              placeholder: (_, __) => Container(
                                color: const Color(0xFFE5E7EB),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: const Color(0xFFE5E7EB),
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        ),
                      ).withClickCursor();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageBubble(List<String> urls) {
    final count = urls.length;
    return Container(
      width: _imageSize,
      height: _imageSize,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: const BoxDecoration(
        color: Color(0xFFE5E7EB),
        borderRadius: _imageRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: count,
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            onPageChanged: (i) {
              setState(() => _index = i);
            },
            itemBuilder: (context, i) {
              final url = urls[i];
              final heroTag = 'stack_${widget.messageId ?? 'album'}_$i';
              return GestureDetector(
                onTap: () => _openImage(
                  url,
                  index: i,
                  heroTag: heroTag,
                ),
                child: Hero(
                  tag: heroTag,
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    width: _imageSize,
                    height: _imageSize,
                    memCacheWidth: 480,
                    fadeInDuration: const Duration(milliseconds: 300),
                    fadeOutDuration: const Duration(milliseconds: 300),
                    placeholder: (_, __) => Container(
                      color: const Color(0xFFE5E7EB),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFFE5E7EB),
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ).withClickCursor();
            },
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_index + 1}/$count',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(count, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 7 : 5,
                  height: active ? 7 : 5,
                  decoration: BoxDecoration(
                    color:
                        active ? Colors.white : Colors.white.withOpacity(0.45),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    if (urls.isEmpty) return const SizedBox.shrink();

    final topPad = widget.isConsecutive ? 2.0 : 8.0;
    final bottomPad = widget.isFollowedByConsecutive ? 2.0 : 8.0;

    // Outer row matches ChatThreadWidget (avatar gutter + 12px side padding).
    return Padding(
      padding: EdgeInsets.fromLTRB(8, topPad, 8, bottomPad),
      child: Row(
        mainAxisAlignment:
            widget.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isMine) const SizedBox(width: 36, height: 36),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
            child: Column(
              crossAxisAlignment: widget.isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isGroup &&
                    !widget.isMine &&
                    !widget.isConsecutive &&
                    (widget.senderName?.trim().isNotEmpty ?? false))
                  Padding(
                    // Align with bubble inner content (14px horizontal padding).
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                    child: Text(
                      widget.senderName!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                // Same white message bubble as single photo messages.
                Container(
                  width: _bubbleWidth,
                  constraints: const BoxConstraints(maxWidth: _bubbleWidth),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.black.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Incoming single photos use a 40px left inset.
                        if (!widget.isMine)
                          Padding(
                            padding: const EdgeInsets.only(left: 40),
                            child: _buildImageBubble(urls),
                          )
                        else
                          Align(
                            alignment: Alignment.centerRight,
                            child: _buildImageBubble(urls),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _showSeeAllGrid,
                  child: Text(
                    'See all',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.isMine
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF3B82F6),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ).withClickCursor(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
