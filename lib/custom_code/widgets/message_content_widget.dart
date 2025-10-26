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
      );
    }

    // Regular MarkdownBody for non-SummerAI messages
    return MarkdownBody(
      data: content,
      selectable:
          false, // Disabled to prevent interference with custom reaction/copy dropdown
      onTapLink: onTapLink,
      styleSheet: styleSheet,
    );
  }
}
