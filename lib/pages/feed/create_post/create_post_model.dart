import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'create_post_widget.dart' show CreatePostWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CreatePostModel extends FlutterFlowModel<CreatePostWidget> {
  ///  Local state fields for this page.

  String? postType;

  String? image;

  String? caption;

  bool loading = false;

  bool selected = false;

  bool pageLoading = false;

  bool isPinned = false;

  ///  State fields for stateful widgets in this page.

  final formKey = GlobalKey<FormState>();
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;

  // Rich text formatting state
  List<TextSpan> textSpans = [];
  TextSelection? currentSelection;
  String plainText = '';

  // Current formatting state for new text
  bool isBold = false;
  bool isItalic = false;
  bool isUnderline = false;
  double fontSize = 16.0;
  Color textColor = const Color(0xFF000000);
  bool isDataUploading_uploadData6hi = false;
  FFUploadedFile uploadedLocalFile_uploadData6hi =
      FFUploadedFile(bytes: Uint8List.fromList([]));
  String uploadedFileUrl_uploadData6hi = '';

  bool isDataUploading_uploadData6hias = false;
  FFUploadedFile uploadedLocalFile_uploadData6hias =
      FFUploadedFile(bytes: Uint8List.fromList([]));
  String uploadedFileUrl_uploadData6hias = '';

  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  PostsRecord? done;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }

  // Helper method to create a TextSpan with current formatting
  TextSpan createFormattedSpan(String text) {
    return TextSpan(
      text: text,
      style: TextStyle(
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        fontSize: fontSize,
        color: textColor,
        decoration:
            isUnderline ? TextDecoration.underline : TextDecoration.none,
        fontFamily: GoogleFonts.inter().fontFamily,
      ),
    );
  }

  // Helper method to apply formatting to selected text
  void applyFormattingToSelection() {
    if (currentSelection == null || !currentSelection!.isValid) return;

    final selectedText = plainText.substring(
      currentSelection!.start,
      currentSelection!.end,
    );

    if (selectedText.isEmpty) return;

    // Create formatted span for selected text
    final formattedSpan = createFormattedSpan(selectedText);

    // Replace the selected text with formatted span
    final beforeText = plainText.substring(0, currentSelection!.start);
    final afterText = plainText.substring(currentSelection!.end);

    // Update text spans
    textSpans.clear();
    if (beforeText.isNotEmpty) {
      textSpans.add(TextSpan(text: beforeText));
    }
    textSpans.add(formattedSpan);
    if (afterText.isNotEmpty) {
      textSpans.add(TextSpan(text: afterText));
    }

    // Update plain text
    plainText = beforeText + selectedText + afterText;

    // Update the text controller to reflect changes
    textController?.text = plainText;
  }

  // Helper method to apply formatting to specific text range
  void applyFormattingToRange(int start, int end) {
    if (start < 0 || end > plainText.length || start >= end) return;

    final selectedText = plainText.substring(start, end);
    if (selectedText.isEmpty) return;

    // Create formatted span for selected text
    final formattedSpan = createFormattedSpan(selectedText);

    // Replace the selected text with formatted span
    final beforeText = plainText.substring(0, start);
    final afterText = plainText.substring(end);

    // Update text spans
    textSpans.clear();
    if (beforeText.isNotEmpty) {
      textSpans.add(TextSpan(text: beforeText));
    }
    textSpans.add(formattedSpan);
    if (afterText.isNotEmpty) {
      textSpans.add(TextSpan(text: afterText));
    }

    // Update plain text
    plainText = beforeText + selectedText + afterText;
  }

  // Helper method to get plain text from spans
  String getPlainTextFromSpans() {
    return textSpans.map((span) => span.text ?? '').join();
  }
}
