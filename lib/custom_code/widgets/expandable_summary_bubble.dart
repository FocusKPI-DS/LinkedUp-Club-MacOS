import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ExpandableSummaryBubble extends StatefulWidget {
  const ExpandableSummaryBubble({
    super.key,
    required this.content,
    this.maxPreviewLines = 3,
    this.expandText = 'Show more',
    this.collapseText = 'Show less',
    this.onTapLink,
  });

  final String content;
  final int maxPreviewLines;
  final String expandText;
  final String collapseText;
  final void Function(String, String?, String?)? onTapLink;

  @override
  State<ExpandableSummaryBubble> createState() =>
      _ExpandableSummaryBubbleState();
}

class _ExpandableSummaryBubbleState extends State<ExpandableSummaryBubble>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  String _getPreviewText(String content) {
    final lines = content.split('\n');
    if (lines.length <= widget.maxPreviewLines) {
      return content;
    }

    // Get the first few lines for preview
    final previewLines = lines.take(widget.maxPreviewLines).toList();
    return previewLines.join('\n');
  }

  bool _shouldShowExpandButton(String content) {
    final lines = content.split('\n');
    return lines.length > widget.maxPreviewLines;
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowButton = _shouldShowExpandButton(widget.content);
    final previewText = _getPreviewText(widget.content);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6), // Same background as other messages
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SummerAI header - subtle styling
            const Row(
              children: [
                Text(
                  'SummerAI',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 6.0),
                Icon(
                  Icons.auto_awesome,
                  size: 14.0,
                  color: Colors.black,
                ),
              ],
            ),
            const SizedBox(height: 8.0),

            // Content
            AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Always show preview or full content
                    MarkdownBody(
                      data: _isExpanded ? widget.content : previewText,
                      selectable: true,
                      onTapLink: widget.onTapLink,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.0,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                          color: Colors.black,
                        ),
                        h1: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        h2: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        h3: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        strong: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        em: const TextStyle(
                          fontFamily: 'Inter',
                          fontStyle: FontStyle.italic,
                          color: Colors.black,
                        ),
                        listBullet: const TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.black,
                        ),
                        blockquote: const TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.black,
                        ),
                        a: const TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFF2563EB),
                          fontSize: 14.0,
                          decoration: TextDecoration.underline,
                        ),
                        code: const TextStyle(
                          fontFamily: 'RobotoMono',
                          color: Colors.black,
                          fontSize: 13.0,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),

                    // Expand/Collapse button positioned at bottom right
                    if (shouldShowButton)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: GestureDetector(
                            onTap: _toggleExpanded,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 6.0,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _isExpanded
                                        ? widget.collapseText
                                        : widget.expandText,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4.0),
                                  AnimatedRotation(
                                    turns: _isExpanded ? 0.5 : 0.0,
                                    duration: const Duration(milliseconds: 300),
                                    child: const Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 16.0,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
