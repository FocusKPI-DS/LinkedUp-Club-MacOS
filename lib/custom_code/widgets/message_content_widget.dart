import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;

// Helper class to track match information
class _MatchInfo {
  final int start;
  final int end;
  final String text;
  final bool isMention;
  
  _MatchInfo({
    required this.start,
    required this.end,
    required this.text,
    required this.isMention,
  });
}

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

  /// Parse content and extract mentions AND hyperlinks
  /// Highlights @mentions in BOLD BLUE and hyperlinks in BLUE (clickable)
  /// WhatsApp-style: Only the @username portion is colored, not following text
  List<InlineSpan> _buildTextWithMentionsAndLinks() {
    final List<InlineSpan> spans = [];
    
    // Match patterns for mentions:
    // 1. @FirstName (capitalized) - e.g., @Mitansh
    // 2. @FirstName LastName (both capitalized) - e.g., @Mitansh Patel
    // 3. @linkai or @LinkAI (special AI assistant - case insensitive)
    // 4. @word (single lowercase word for usernames) - e.g., @mike
    final mentionRegex = RegExp(
      r'@(?:linkai|[A-Z][a-zA-Z]*(?:\s+[A-Z][a-zA-Z]*)?|[a-z]+)',
    );
    
    // Match patterns for hyperlinks (URLs)
    // Supports: http://, https://, www., and common TLDs
    final urlRegex = RegExp(
      r'(https?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9-]+\.[a-zA-Z]{2,}[^\s]*)',
      caseSensitive: false,
    );

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

    // Style for hyperlinks - Blue (not bold, but clickable)
    const linkStyle = TextStyle(
      fontSize: 17.0,
      fontFamily: 'SF Pro Text',
      color: const Color(0xFF007AFF), // iOS system blue
      letterSpacing: -0.4,
      fontWeight: FontWeight.w400, // Not bold
      height: 1.3,
      decoration: TextDecoration.underline,
    );

    // Find all mentions and links
    final mentionMatches = mentionRegex.allMatches(content).toList();
    final linkMatches = urlRegex.allMatches(content).toList();
    
    // Combine all matches and sort by position
    final allMatches = <_MatchInfo>[];
    for (final match in mentionMatches) {
      final group = match.group(0);
      if (group != null) {
        allMatches.add(_MatchInfo(
          start: match.start,
          end: match.end,
          text: group,
          isMention: true,
        ));
      }
    }
    for (final match in linkMatches) {
      final group = match.group(0);
      if (group != null) {
        allMatches.add(_MatchInfo(
          start: match.start,
          end: match.end,
          text: group,
          isMention: false,
        ));
      }
    }
    
    // Sort by start position
    allMatches.sort((a, b) => a.start.compareTo(b.start));
    
    // Remove overlapping matches (mentions take priority)
    final filteredMatches = <_MatchInfo>[];
    for (final match in allMatches) {
      bool overlaps = false;
      for (final existing in filteredMatches) {
        if (match.start < existing.end && match.end > existing.start) {
          overlaps = true;
          // If mention overlaps with link, keep mention
          if (match.isMention && !existing.isMention) {
            filteredMatches.remove(existing);
            filteredMatches.add(match);
          }
          break;
        }
      }
      if (!overlaps) {
        filteredMatches.add(match);
      }
    }
    
    // Re-sort after filtering
    filteredMatches.sort((a, b) => a.start.compareTo(b.start));
    
    // If no matches found, return full text in black
    if (filteredMatches.isEmpty) {
      return [
        TextSpan(
          text: content,
          style: baseBlackStyle,
        ),
      ];
    }

    int lastMatchEnd = 0;
    for (final match in filteredMatches) {
      // Add text BEFORE match in black
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: content.substring(lastMatchEnd, match.start),
          style: baseBlackStyle,
        ));
      }

      // Add mention or link with appropriate style
      if (match.isMention) {
        // Add @mention - BOLD and BLUE
        spans.add(TextSpan(
          text: match.text,
          style: mentionStyle,
        ));
      } else {
        // Add hyperlink - BLUE and clickable
        final url = match.text.startsWith('http') 
            ? match.text 
            : (match.text.startsWith('www.') 
                ? 'https://${match.text}' 
                : 'https://${match.text}');
        spans.add(TextSpan(
          text: match.text,
          style: linkStyle,
          recognizer: onTapLink != null
              ? (TapGestureRecognizer()
                ..onTap = () => onTapLink!(url, null, null))
              : null,
        ));
      }

      lastMatchEnd = match.end;
    }

    // Add remaining text AFTER last match in black
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
      // Render message with styled @mentions (bold blue), hyperlinks (blue), and normal text (black)
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
          children: _buildTextWithMentionsAndLinks(),
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
