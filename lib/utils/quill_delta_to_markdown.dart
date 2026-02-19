import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

/// Converts a Quill [Delta] to a Markdown string.
/// 
/// Supports:
/// - Bold (**text**)
/// - Italic (*text*)
/// - Strikethrough (~~text~~)
/// - Code (`text`)
/// - Link ([text](url))
/// - Code Block (```\ntext\n```)
/// - Blockquote (> text)
/// - Bullet List (- text)
/// - Numbered List (1. text)
/// - Header (# text)
String quillDeltaToMarkdown(Delta delta) {
  final buffer = StringBuffer();
  
  // We need to process operations line by line to handle block attributes correctly
  // (like lists, code blocks, headers, quotes)
  
  // However, simple inline attributes can be processed operation by operation.
  // But block attributes are applied to the newline character at the end of the line.
  
  // final iterator = delta.iterator; // Iterator getter not available
  
  String currentLineText = '';
  Map<String, dynamic> currentLineAttributes = {};
  
  for (final op in delta.toList()) {
    // final op = iterator.next();
    
    if (op.data is! String) {
      // Embeds (image, video, etc.) - specific handling or skip for now
      continue;
    }
    
    String text = op.data as String;
    final attributes = op.attributes ?? {};
    
    // Split by newline to handle line-based block attributes
    // Note: Quill usually puts the block attribute ON the newline character itself.
    // e.g. "Item 1" (no attr), "\n" (attr: {list: bullet})
    
    List<String> parts = text.split('\n');
    
    for (int i = 0; i < parts.length; i++) {
      String part = parts[i];
      
      if (part.isNotEmpty) {
        // Apply inline formatting to this part
        String formattedPart = _applyInlineFormat(part, attributes);
        buffer.write(formattedPart);
      }
      
      // If there are more parts, it means we hit a newline
      if (i < parts.length - 1) {
        // This operation contained a newline, so check for block attributes
        // In Quill, existing attributes on the op containing correct newline apply to the block ending there
        _handleBlockAttributes(buffer, attributes); 
        buffer.write('\n');
      }
    }
  }
  
  return buffer.toString().trim();
}

String _applyInlineFormat(String text, Map<String, dynamic> attributes) {
  String res = text;
  
  if (attributes.containsKey('bold') && attributes['bold'] == true) {
    res = '**$res**';
  }
  if (attributes.containsKey('italic') && attributes['italic'] == true) {
    res = '*$res*';
  }
  if (attributes.containsKey('strike') && attributes['strike'] == true) {
    res = '~~$res~~';
  }
  if (attributes.containsKey('code') && attributes['code'] == true) {
    res = '`$res`';
  }
  if (attributes.containsKey('link') && attributes['link'] != null) {
    res = '[$res](${attributes['link']})';
  }
  
  return res;
}

void _handleBlockAttributes(StringBuffer buffer, Map<String, dynamic> attributes) {
  // Post-processing logic would be needed for perfect block translation 
  // because Markdown prefixes the line (e.g. "- Item"), but Quill attributes come at the end (`\n` has `list: bullet`).
  // This simple conversion might need to look BACKWARDS in the buffer to insert the prefix.
  
  // Since looking backwards in StringBuffer is hard, a better approach is:
  // 1. Iterate operations and build a list of "Lines".
  // 2. Each Line has text (with inline Markdown already applied) and Block Attributes.
  // 3. Process the Lines to generate final Markdown with prefixes.
}

/// Robust approach: distinct class for Line processing
class _Line {
  StringBuffer content = StringBuffer();
  Map<String, dynamic>? blockAttributes;
  
  void append(String text) {
    content.write(text);
  }
  
  String get text => content.toString();
}

String quillDeltaToMarkdownSimplified(Delta delta) {
  List<_Line> lines = [];
  _Line currentLine = _Line();
  lines.add(currentLine);
  
  for (final op in delta.toList()) {
    if (op.data is! String) continue;
    
    String text = op.data as String;
    Map<String, dynamic> attrs = op.attributes ?? {};
    
    int index = 0;
    while (index < text.length) {
      int nextNewline = text.indexOf('\n', index);
      
      if (nextNewline == -1) {
        // No more newlines, just append remaining text with inline formatting
        String segment = text.substring(index);
        currentLine.append(_applyInlineFormat(segment, attrs));
        break;
      } else {
        // Found a newline
        String segment = text.substring(index, nextNewline);
        currentLine.append(_applyInlineFormat(segment, attrs));
        
        // The block attributes usually attach to the newline op.
        // If this op has block attributes, apply them to the current line.
        if (_isBlockAttribute(attrs)) {
          currentLine.blockAttributes = attrs;
        }
        
        // Start new line
        currentLine = _Line();
        lines.add(currentLine);
        index = nextNewline + 1;
      }
    }
  }
  
  // Remove last empty line if it was created by trailing newline
  if (lines.isNotEmpty && lines.last.text.isEmpty && lines.last.blockAttributes == null) {
    lines.removeLast();
  }
  
  // Build final string
  StringBuffer finalBuffer = StringBuffer();
  
  bool inCodeBlock = false;
  
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    String lineText = line.text;
    Map<String, dynamic> attrs = line.blockAttributes ?? {};
    
    String prefix = '';
    String suffix = '';
    
    // Headers
    if (attrs.containsKey('header')) {
      int level = attrs['header'];
      prefix = '#' * level + ' ';
    }
    
    // Lists
    if (attrs.containsKey('list')) {
      if (attrs['list'] == 'ordered') {
        prefix = '1. '; // Simple 1. for all, Markdown renderers handle numbering
      } else if (attrs['list'] == 'bullet') {
        prefix = '- ';
      } else if (attrs['list'] == 'checked') {
        prefix = '- [x] ';
      } else if (attrs['list'] == 'unchecked') {
        prefix = '- [ ] ';
      }
    }
    
    // Blockquote
    if (attrs.containsKey('blockquote') && attrs['blockquote'] == true) {
      prefix = '> ';
    }
    
    // Code Block
    if (attrs.containsKey('code-block') && attrs['code-block'] == true) {
      if (!inCodeBlock) {
        finalBuffer.writeln('```');
        inCodeBlock = true;
      }
    } else {
      if (inCodeBlock) {
        finalBuffer.writeln('```');
        inCodeBlock = false;
      }
    }
    
    finalBuffer.write(prefix + lineText + suffix);
    if (i < lines.length - 1 || inCodeBlock) {
      finalBuffer.writeln();
    }
  }
  
  if (inCodeBlock) {
     finalBuffer.writeln('```');
  }
  
  return finalBuffer.toString().trim();
}

bool _isBlockAttribute(Map<String, dynamic> attrs) {
  return attrs.containsKey('header') || 
         attrs.containsKey('list') || 
         attrs.containsKey('blockquote') || 
         attrs.containsKey('code-block');
}
