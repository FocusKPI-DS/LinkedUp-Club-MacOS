import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

/// Singleton manager that stores per-chat drafts in memory.
/// Drafts are QuillDelta JSON strings, keyed by chat ID.
class ChatDraftManager {
  ChatDraftManager._();
  static final ChatDraftManager instance = ChatDraftManager._();

  final Map<String, String> _drafts = {};

  /// Save the current editor content as a draft for the given chat.
  /// If the editor is empty, the draft is removed.
  void saveDraft(String chatId, QuillController controller) {
    final plainText = controller.document.toPlainText().trim();
    if (plainText.isEmpty) {
      _drafts.remove(chatId);
      return;
    }
    try {
      final deltaJson = jsonEncode(controller.document.toDelta().toJson());
      _drafts[chatId] = deltaJson;
    } catch (e) {
      // Silently fail - draft saving should never break the app
    }
  }

  /// Restore a saved draft into the QuillController.
  /// Returns true if a draft was restored, false otherwise.
  bool restoreDraft(String chatId, QuillController controller) {
    final deltaJson = _drafts[chatId];
    if (deltaJson == null) return false;

    try {
      final json = jsonDecode(deltaJson) as List;
      final delta = Delta.fromJson(json);
      controller.document = Document.fromDelta(delta);
      // Move cursor to end of content
      final length = controller.document.length;
      controller.moveCursorToPosition(length > 0 ? length - 1 : 0);
      return true;
    } catch (e) {
      // If restore fails, remove the corrupt draft
      _drafts.remove(chatId);
      return false;
    }
  }

  /// Clear the draft for a given chat (e.g. after sending a message).
  void clearDraft(String chatId) {
    _drafts.remove(chatId);
  }

  /// Check if a draft exists for a given chat.
  bool hasDraft(String chatId) {
    return _drafts.containsKey(chatId);
  }
}
