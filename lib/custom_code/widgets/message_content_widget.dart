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

  /// Parse content and extract mentions - highlight @mentions in BOLD BLUE
  /// WhatsApp-style: Only the @username portion is colored, not following text
  List<InlineSpan> _buildTextWithMentions() {
    final List<InlineSpan> spans = [];
    
    // Match patterns:
    // 1. @FirstName (capitalized) - e.g., @Mitansh
    // 2. @FirstName LastName (both capitalized) - e.g., @Mitansh Patel
    // 3. @linkai or @LinkAI (special AI assistant - case insensitive)
    // 4. @word (single lowercase word for usernames) - e.g., @mike
    final mentionRegex = RegExp(
      r'@(?:linkai|[A-Z][a-zA-Z]*(?:\s+[A-Z][a-zA-Z]*)?|[a-z]+)',
    );
    int lastMatchEnd = 0;

    // Base style for normal text - black
    const baseBlackStyle = TextStyle(
      fontSize: 17.0,
      fontFamily: 'SF Pro Text',
      color: Color(0xFF000000), // Black for regular text
      letterSpacing: -0.4,
      fontWeight: FontWeight.w400,
      height: 1.3,
    );

    // Style for @mentions - Bold Blue (iOS system blue)
    const mentionStyle = TextStyle(
      fontSize: 17.0,
      fontFamily: 'SF Pro Text',
      color: Color(0xFF007AFF), // iOS system blue
      letterSpacing: -0.4,
      fontWeight: FontWeight.w600, // Bold
      height: 1.3,
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

      // Add @mention - BOLD and BLUE
      spans.add(TextSpan(
        text: match.group(0), // Full match including @
        style: mentionStyle, // Bold blue style
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
      // Render message with styled @mentions (bold blue) and normal text (black)
      return SelectableText.rich(
        TextSpan(
          style: const TextStyle(
            color: Color(0xFF000000), // Default black
            fontSize: 17.0,
            fontFamily: 'SF Pro Text',
            fontWeight: FontWeight.w400,
            letterSpacing: -0.4,
            height: 1.3,
          ),
          children: _buildTextWithMentions(),
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
