import 'dart:async';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/backend/backend.dart';
import 'chat_widget.dart' show ChatWidget;
import 'package:flutter/material.dart';

class ChatModel extends FlutterFlowModel<ChatWidget> {
  ///  Local state fields for this page.

  bool loading = false;

  /// Chat IDs that the user has manually marked as unread (WeChat-style).
  /// Local-only — cleared when user opens the chat.
  Set<String> manuallyUnreadIds = {};

  /// Folder mode toggle (false = flat chat list, true = grouped by folder)
  bool isFolderMode = false;

  /// Collapse state for smart folders
  bool isPinnedCollapsed = false;
  bool isGroupCollapsed = false;
  bool isDMCollapsed = false;

  /// User-created custom folders
  List<ChatFoldersRecord> chatFolders = [];
  StreamSubscription? chatFoldersSubscription;

  ///  State fields for stateful widgets in this page.

  // State field(s) for TabBar widget.
  TabController? tabBarController;
  int get tabBarCurrentIndex =>
      tabBarController != null ? tabBarController!.index : 0;
  int get tabBarPreviousIndex =>
      tabBarController != null ? tabBarController!.previousIndex : 0;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    tabBarController?.dispose();
    chatFoldersSubscription?.cancel();
  }
}
