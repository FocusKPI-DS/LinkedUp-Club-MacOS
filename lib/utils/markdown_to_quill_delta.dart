import 'package:flutter_quill/quill_delta.dart';

/// Converts a Markdown string back into a Quill [Delta].
///
/// This is the inverse of `quillDeltaToMarkdownSimplified`.
/// It supports the same subset of Markdown:
/// - **bold** / __bold__
/// - *italic* / _italic_
/// - ~~strikethrough~~
/// - `inline code`
/// - [text](url)  links
/// - Ordered / bullet / check lists
/// - > blockquote
/// - # headers
/// - ``` code blocks ```
Delta markdownToQuillDelta(String markdown) {
  final delta = Delta();
  final lines = markdown.split('\n');

  bool inCodeBlock = false;

  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];

    // --- Code block fence ---
    if (line.trimRight() == '```' ||
        line.trimRight().startsWith('```') && !inCodeBlock) {
      if (inCodeBlock) {
        // Closing fence — just emit newline with code-block attribute
        // (the previous lines already had code-block set)
        inCodeBlock = false;
        continue; // skip the closing ``` line itself
      } else {
        inCodeBlock = true;
        continue; // skip the opening ``` line itself
      }
    }

    if (inCodeBlock) {
      delta.insert(line);
      delta.insert('\n', {'code-block': true});
      continue;
    }

    // --- Block-level attributes ---
    Map<String, dynamic> blockAttrs = {};

    // Headers: # / ## / ###
    final headerMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
    if (headerMatch != null) {
      blockAttrs['header'] = headerMatch.group(1)!.length;
      line = headerMatch.group(2)!;
    }

    // Blockquote: > text
    if (line.startsWith('> ')) {
      blockAttrs['blockquote'] = true;
      line = line.substring(2);
    }

    // Ordered list: 1. text
    final orderedMatch = RegExp(r'^\d+\.\s+(.*)$').firstMatch(line);
    if (orderedMatch != null) {
      blockAttrs['list'] = 'ordered';
      line = orderedMatch.group(1)!;
    }

    // Bullet list: - text
    if (line.startsWith('- [x] ')) {
      blockAttrs['list'] = 'checked';
      line = line.substring(6);
    } else if (line.startsWith('- [ ] ')) {
      blockAttrs['list'] = 'unchecked';
      line = line.substring(6);
    } else if (line.startsWith('- ')) {
      blockAttrs['list'] = 'bullet';
      line = line.substring(2);
    }

    // --- Inline formatting ---
    _parseInlineMarkdown(delta, line);

    // Insert newline with block attributes
    if (blockAttrs.isNotEmpty) {
      delta.insert('\n', blockAttrs);
    } else {
      delta.insert('\n');
    }
  }

  return delta;
}

/// Parse inline markdown formatting and insert into delta.
/// Supports: ***bold+italic***, **bold**, *italic*, ~~strike~~, `code`, [text](url)
void _parseInlineMarkdown(Delta delta, String text) {
  if (text.isEmpty) return;

  // Combined regex for inline formatting — order matters
  final regex = RegExp(
    r'\*\*\*(.+?)\*\*\*'       // group 1: bold+italic
    r'|\*\*(.+?)\*\*'           // group 2: bold
    r'|\*(.+?)\*'               // group 3: italic
    r'|~~(.+?)~~'               // group 4: strikethrough
    r'|`([^`]+)`'               // group 5: inline code
    r'|\[([^\]]+)\]\(([^)]+)\)' // group 6+7: link [text](url)
  );

  int lastEnd = 0;

  for (final match in regex.allMatches(text)) {
    // Insert plain text before this match
    if (match.start > lastEnd) {
      delta.insert(text.substring(lastEnd, match.start));
    }

    if (match.group(1) != null) {
      // ***bold+italic***
      delta.insert(match.group(1)!, {'bold': true, 'italic': true});
    } else if (match.group(2) != null) {
      // **bold**
      delta.insert(match.group(2)!, {'bold': true});
    } else if (match.group(3) != null) {
      // *italic*
      delta.insert(match.group(3)!, {'italic': true});
    } else if (match.group(4) != null) {
      // ~~strikethrough~~
      delta.insert(match.group(4)!, {'strike': true});
    } else if (match.group(5) != null) {
      // `code`
      delta.insert(match.group(5)!, {'code': true});
    } else if (match.group(6) != null && match.group(7) != null) {
      // [text](url)
      delta.insert(match.group(6)!, {'link': match.group(7)!});
    }

    lastEnd = match.end;
  }

  // Insert remaining plain text after last match
  if (lastEnd < text.length) {
    delta.insert(text.substring(lastEnd));
  }
}

/// Strip markdown formatting from a string, returning plain text.
/// Useful for preview text (reply previews, notification previews, etc.)
String stripMarkdownFormatting(String text) {
  // Strip mention markup first: <@uid|Name> → @Name
  var result = text.replaceAllMapped(
    RegExp(r'<@[^|>]+\|([^>]+)>'),
    (m) => '@${m.group(1)}',
  );

  // Strip code blocks
  result = result.replaceAll(RegExp(r'```\n?'), '');

  // Strip inline formatting: ***bold italic*** → bold italic
  result = result.replaceAllMapped(
    RegExp(r'\*\*\*(.+?)\*\*\*'),
    (m) => m.group(1)!,
  );
  // **bold** → bold
  result = result.replaceAllMapped(
    RegExp(r'\*\*(.+?)\*\*'),
    (m) => m.group(1)!,
  );
  // *italic* → italic
  result = result.replaceAllMapped(
    RegExp(r'\*(.+?)\*'),
    (m) => m.group(1)!,
  );
  // ~~strike~~ → strike
  result = result.replaceAllMapped(
    RegExp(r'~~(.+?)~~'),
    (m) => m.group(1)!,
  );
  // `code` → code
  result = result.replaceAllMapped(
    RegExp(r'`([^`]+)`'),
    (m) => m.group(1)!,
  );
  // [text](url) → text
  result = result.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]+\)'),
    (m) => m.group(1)!,
  );
  // Strip block prefixes: > , - , 1. , # etc.
  result = result.replaceAllMapped(
    RegExp(r'^(#{1,6}\s+|>\s+|\d+\.\s+|- \[[ x]\] |- )', multiLine: true),
    (m) => '',
  );

  return result;
}
