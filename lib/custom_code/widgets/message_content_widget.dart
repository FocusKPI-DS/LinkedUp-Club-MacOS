import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;

class MessageContentWidget extends StatelessWidget {
  const MessageContentWidget({
    super.key,
    required this.content,
    required this.senderName,
    this.onTapLink,
    this.styleSheet,
  });

  final String content;
  final String? senderName;
  final void Function(String, String?, String?)? onTapLink;
  final MarkdownStyleSheet? styleSheet;

  /// Parse content and extract mentions - highlight ONLY @mentions
  List<InlineSpan> _buildTextWithMentions() {
    final List<InlineSpan> spans = [];
    // Match @ followed by word characters (including spaces in names like "@John Doe")
    final mentionRegex = RegExp(r'@(\w+(?:\s+\w+)*)');
    int lastMatchEnd = 0;

    // Base black style for normal text
    const baseBlackStyle = TextStyle(
      fontSize: 14.0,
      color: Color(0xFF1F2937), // Black
    );

    final matches = mentionRegex.allMatches(content).toList();
    
    // If no mentions found, return full text in black
    if (matches.isEmpty) {
      return [
        TextSpan(
          text: content,
          style: baseBlackStyle,
        ),
      ];
    }

    for (final match in matches) {
      // Add text BEFORE mention in black
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: content.substring(lastMatchEnd, match.start),
          style: baseBlackStyle,
        ));
      }

      // Add @mention - plain black, no special styling
      spans.add(TextSpan(
        text: match.group(0), // Full match including @
        style: baseBlackStyle, // Same as normal text - plain black
      ));

      lastMatchEnd = match.end;
    }

    // Add remaining text AFTER last mention in black
    if (lastMatchEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastMatchEnd),
        style: baseBlackStyle,
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    // Check if this is a SummerAI message
    final isSummerAI = senderName == 'SummerAI';

    if (isSummerAI) {
      return custom_widgets.ExpandableSummaryBubble(
        content: content,
        maxPreviewLines: 3,
        expandText: 'Show more',
        collapseText: 'Show less',
        onTapLink: onTapLink,
      );
    }

    // Check if content contains mentions
    final hasMentions = content.contains(RegExp(r'@\w+'));

    if (hasMentions) {
      // Completely isolate from ANY parent styles - use Container to break inheritance
      return Container(
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Color(0xFF1F2937), // FORCE black - overrides ANY parent
            fontSize: 14.0,
            fontWeight: FontWeight.normal,
            decoration: TextDecoration.none,
          ),
          child: Builder(
            builder: (context) {
              // Create completely isolated TextSpan tree
              return SelectableText.rich(
                TextSpan(
                  style: const TextStyle(
                    color: Color(0xFF1F2937), // Explicitly black - no inheritance
                    fontSize: 14.0,
                    fontWeight: FontWeight.normal,
                  ),
                  children: _buildTextWithMentions(),
                ),
              );
            },
          ),
        ),
      );
    }

    // Regular MarkdownBody for messages without mentions
    return MarkdownBody(
      data: content,
      selectable: true,
      onTapLink: onTapLink,
      styleSheet: styleSheet,
    );
  }
}
