import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/app_state.dart';

class _MatchInfo {
  final int start;
  final int end;
  final String text;
  final String? url; // For markdown links
  final bool isMention;
  final bool isMarkdownLink;

  _MatchInfo({
    required this.start,
    required this.end,
    required this.text,
    this.url,
    required this.isMention,
    this.isMarkdownLink = false,
  });
}

class MessageContentWidget extends StatelessWidget {
  const MessageContentWidget({
    super.key,
    required this.content,
    required this.senderName,
    this.onTapLink,
    this.styleSheet,
    this.mentionableUsers = const [],
    this.selectable = true,
    this.onSelectionMenuRequest,
    this.onToolbarShown,
    this.isOwnMessage = false,
  });

  final String content;
  final String? senderName;
  final void Function(String, String?, String?)? onTapLink;
  final MarkdownStyleSheet? styleSheet;
  final List<String> mentionableUsers;
  final bool selectable;
  final Function(String? action)? onSelectionMenuRequest;
  final VoidCallback? onToolbarShown;
  final bool isOwnMessage;

  /// Convert single newlines to Markdown hard breaks (two trailing spaces)
  /// while preserving code blocks (``` ... ```) as-is.
  static String _ensureHardLineBreaks(String text) {
    // Split by code fences to avoid modifying content inside code blocks
    final parts = text.split('```');
    for (int i = 0; i < parts.length; i++) {
      // Even indices are outside code blocks, odd indices are inside
      if (i.isEven) {
        // Replace single \n with two trailing spaces + \n (Markdown hard break)
        // but don't touch \n\n (paragraph breaks) — those already render correctly
        parts[i] = parts[i].replaceAllMapped(
          RegExp(r'(?<!\n)\n(?!\n)'),
          (m) => '  \n',
        );
      }
    }
    return parts.join('```');
  }

  List<InlineSpan> _buildTextWithMentionsAndLinks() {
    final List<InlineSpan> spans = [];

    // Slack-style mention markup: <@uid|DisplayName>
    final mentionRegex = RegExp(r'<@([^|]+)\|([^>]+)>');

    final urlRegex = RegExp(
      r'(https?://[^\s)\]{}<>"]+)',
      caseSensitive: false,
    );

    final markdownLinkRegex = RegExp(
      r'\[([^\]]+)\]\((https?://[^\s)\]{}<>"]+)\)',
      caseSensitive: false,
    );

    final fontSize = FFAppState().chatFontSize;

    final baseBlackStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: 'SF Pro Text',
      color: Color(0xFF000000),
      letterSpacing: -0.4,
      fontWeight: FontWeight.w400,
      height: 1.3,
    );

    final mentionStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: 'SF Pro Text',
      color: Color(0xFF007AFF),
      letterSpacing: -0.4,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );

    final linkStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: 'SF Pro Text',
      color: const Color(0xFF007AFF),
      letterSpacing: -0.4,
      fontWeight: FontWeight.w400,
      height: 1.3,
      decoration: TextDecoration.underline,
    );

    final mentionMatches = mentionRegex.allMatches(content).toList();
    final linkMatches = urlRegex.allMatches(content).toList();
    final mdLinkMatches = markdownLinkRegex.allMatches(content).toList();

    final allMatches = <_MatchInfo>[];

    for (final match in mentionMatches) {
      final displayName = match.group(2);
      if (displayName != null) {
        allMatches.add(_MatchInfo(
          start: match.start,
          end: match.end,
          text: '@$displayName',
          isMention: true,
        ));
      }
    }

    for (final match in mdLinkMatches) {
      final label = match.group(1);
      final url = match.group(2);
      if (label != null && url != null) {
        allMatches.add(_MatchInfo(
          start: match.start,
          end: match.end,
          text: label,
          url: url,
          isMention: false,
          isMarkdownLink: true,
        ));
      }
    }

    for (final match in linkMatches) {
      final group = match.group(0);
      if (group != null) {
        var cleanLink = group;
        var end = match.end;
        while (cleanLink.isNotEmpty && RegExp(r'[.,!?]$').hasMatch(cleanLink)) {
          cleanLink = cleanLink.substring(0, cleanLink.length - 1);
          end--;
        }

        allMatches.add(_MatchInfo(
          start: match.start,
          end: end,
          text: cleanLink,
          isMention: false,
        ));
      }
    }

    allMatches.sort((a, b) => a.start.compareTo(b.start));

    final filteredMatches = <_MatchInfo>[];
    for (final match in allMatches) {
      bool overlaps = false;
      for (int i = 0; i < filteredMatches.length; i++) {
        final existing = filteredMatches[i];
        if (match.start < existing.end && match.end > existing.start) {
          overlaps = true;
          bool shouldReplace = false;
          if (match.isMarkdownLink && !existing.isMarkdownLink) {
            shouldReplace = true;
          } else if (match.isMention &&
              !existing.isMention &&
              !existing.isMarkdownLink) {
            shouldReplace = true;
          }

          if (shouldReplace) {
            filteredMatches[i] = match;
          }
          break;
        }
      }
      if (!overlaps) {
        filteredMatches.add(match);
      }
    }

    filteredMatches.sort((a, b) => a.start.compareTo(b.start));

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
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: content.substring(lastMatchEnd, match.start),
          style: baseBlackStyle,
        ));
      }

      if (match.isMention) {
        String displayText = match.text;
        if (displayText.startsWith('@"')) {
          displayText = '@${displayText.substring(2, displayText.length - 1)}';
        }
        spans.add(TextSpan(
          text: displayText,
          style: mentionStyle,
        ));
      } else {
        final displayLabel = match.text;
        final actualUrl = match.url ??
            (displayLabel.startsWith('http')
                ? displayLabel
                : (displayLabel.startsWith('www.')
                    ? 'https://${displayLabel}'
                    : 'https://${displayLabel}'));

        // Use TapGestureRecognizer but do NOT let it win over SelectionArea.
        // The recognizer is attached only for single-tap; SelectionArea handles
        // long-press independently because Text.rich participates in selection.
        spans.add(TextSpan(
          text: displayLabel,
          style: linkStyle,
          recognizer: onTapLink != null
              ? (TapGestureRecognizer()
                ..onTap = () => onTapLink!(displayLabel, actualUrl, null))
              : null,
        ));
      }

      lastMatchEnd = match.end;
    }

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

    // Check for Slack-style mention markup: <@uid|name>
    final hasMentions = content.contains('<@') && !content.contains('```');

    // Check for URLs — route through Text.rich path so SelectionArea long-press
    // works properly (MarkdownBody's internal link GestureDetectors block it)
    final hasUrls = !content.contains('```') &&
        RegExp(r'https?://[^\s)\]{}<>"]+', caseSensitive: false).hasMatch(content);

    final useRichTextPath = hasMentions || hasUrls;

    Widget messageWidget;

    if (useRichTextPath) {
      final textSpan = TextSpan(
        style: TextStyle(
          color: Color(0xFF000000),
          fontSize: FFAppState().chatFontSize,
          fontFamily: 'SF Pro Text',
          fontWeight: FontWeight.w400,
          letterSpacing: -0.4,
          height: 1.3,
        ),
        children: _buildTextWithMentionsAndLinks(),
      );

      // Use Text.rich instead of RichText so it participates in SelectionArea
      // and allows long-press to trigger the selection toolbar on iOS.
      messageWidget = Text.rich(textSpan);
    } else {
      messageWidget = MarkdownBody(
        data: _ensureHardLineBreaks(content),
        selectable: false, // Must be false so parent SelectionArea handles it
        onTapLink: onTapLink,
        styleSheet: styleSheet,
        builders: {
          'code': CodeElementBuilder(context),
        },
      );
    }

    if (selectable) {
      return SelectionArea(
        onSelectionChanged: (content) {
          if (content == null) {
            onSelectionMenuRequest?.call(null);
          }
        },
        contextMenuBuilder: (context, selectableRegionState) {
          // Notify parent to dismiss any other toolbar (e.g. media overlay)
          onToolbarShown?.call();

          final endpoints = selectableRegionState.selectionEndpoints;
          if (endpoints.isEmpty) {
            return const SizedBox.shrink();
          }

          // Build full list of menu items corresponding to MobileChatWidget
          final allMenuItems = [
            {'label': 'Copy', 'icon': CupertinoIcons.doc_on_doc, 'value': 'copy'},
            {'label': 'Select', 'icon': CupertinoIcons.checkmark_circle, 'value': 'select'},
            {'label': 'React', 'icon': CupertinoIcons.smiley, 'value': 'react'},
            {'label': 'Reply', 'icon': CupertinoIcons.arrow_turn_up_left, 'value': 'reply'},
            {'label': 'Translate', 'icon': CupertinoIcons.book, 'value': 'translate'},
            {'label': 'Forward', 'icon': CupertinoIcons.arrow_turn_up_right, 'value': 'forward'},
            {'label': 'Delete', 'icon': CupertinoIcons.delete, 'value': 'delete'},
            if (isOwnMessage) {'label': 'Edit', 'icon': CupertinoIcons.pencil, 'value': 'edit'},
            if (isOwnMessage) {'label': 'Unsend', 'icon': CupertinoIcons.arrow_counterclockwise, 'value': 'unsend'},
            {'label': 'Download', 'icon': CupertinoIcons.arrow_down_circle, 'value': 'download'},
            {'label': 'Pin', 'icon': CupertinoIcons.pin, 'value': 'pin'},
            {'label': 'Report', 'icon': CupertinoIcons.exclamationmark_triangle, 'value': 'report'},
          ];
          final menuItems = allMenuItems;

          Widget buildGridItem(Map<String, dynamic> item) {
            final String value = item['value'] as String;
            final String label = item['label'] as String;
            final IconData icon = item['icon'] as IconData;
            
            final isDestructive = value == 'report' || value == 'unsend' || value == 'delete';

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (value == 'copy') {
                    selectableRegionState.copySelection(SelectionChangedCause.toolbar);
                  } else {
                    onSelectionMenuRequest?.call(value);
                  }
                  selectableRegionState.hideToolbar();
                },
                child: SizedBox(
                  width: 48, // slightly larger for touch target
                  height: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 16, // matching iOS size
                        color: isDestructive ? const Color(0xFFFF3B30) : const Color(0xFF1C1C1E),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 8.5, // slightly larger, readable
                        color: isDestructive
                            ? const Color(0xFFFF3B30)
                            : const Color(0xFF1C1C1E).withOpacity(0.8),
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.2,
                        decoration: TextDecoration.none, // Inherited from RichText fix
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

          final int itemsPerRow = 5; // wider menu for text selection
          final double itemSize = 48.0;
          final double horizontalPadding = 6.0;
          final double verticalPadding = 6.0;

          final int actualItemsInWidestRow = menuItems.length < itemsPerRow ? menuItems.length : itemsPerRow;
          final double menuWidth = (itemSize * actualItemsInWidestRow) + (horizontalPadding * 2) + 2.0;

          return CustomSingleChildLayout(
            delegate: TextSelectionToolbarLayoutDelegate(
              anchorAbove: selectableRegionState.contextMenuAnchors.primaryAnchor,
              anchorBelow: selectableRegionState.contextMenuAnchors.secondaryAnchor ??
                  selectableRegionState.contextMenuAnchors.primaryAnchor,
            ),
            child: Material(
              color: Colors.transparent, // Translucent for iOS effect
              elevation: 4,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: menuWidth,
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95), // Glass-like white
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.04),
                    width: 0.5,
                  ),
                ),
                child: Wrap(
                  spacing: 0,
                  runSpacing: 4,
                  alignment: WrapAlignment.start,
                  children: menuItems.map((item) => buildGridItem(item)).toList(),
                ),
              ),
            ),
          );
        },
        child: messageWidget,
      );
    }

    return messageWidget;
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  CodeElementBuilder(this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var language = '';

    if (element.attributes['class'] != null) {
      String lg = element.attributes['class'] as String;
      if (lg.startsWith('language-')) {
        language = lg.substring(9);
      }
    }

    final textContent = element.textContent;
    final isCodeBlock = textContent.contains('\n') || language.isNotEmpty;

    if (isCodeBlock) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: const Color(0xFF282C34),
          borderRadius: BorderRadius.circular(8.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              color: const Color(0xFF21252B),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    language.isEmpty ? 'code' : language,
                    style: const TextStyle(
                      color: Color(0xFFABB2BF),
                      fontSize: 12,
                      fontFamily: 'SF Pro Text',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: textContent));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Code copied to clipboard',
                            style: GoogleFonts.inter(
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          backgroundColor:
                              FlutterFlowTheme.of(context).secondaryText,
                          duration: const Duration(milliseconds: 1600),
                        ),
                      );
                    },
                    child: const Icon(Icons.copy,
                        size: 16, color: Color(0xFFABB2BF)),
                  )
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16.0),
              child: HighlightView(
                textContent,
                language: language.isEmpty ? 'dart' : language,
                theme: atomOneDarkTheme,
                padding: EdgeInsets.zero,
                textStyle: GoogleFonts.firaCode(
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1.0,
        ),
      ),
      child: Text(
        textContent,
        style: preferredStyle?.copyWith(
          fontFamily: GoogleFonts.firaCode().fontFamily,
          backgroundColor: Colors.transparent,
          color: FlutterFlowTheme.of(context).primaryText,
        ),
      ),
    );
  }
}
