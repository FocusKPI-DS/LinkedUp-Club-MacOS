import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'search_chat_widget.dart' show SearchChatWidget;
import 'package:flutter/material.dart';

class SearchChatModel extends FlutterFlowModel<SearchChatWidget> {
  ///  Local state fields for this page.

  List<ChatsRecord> chatResult = [];
  void addToChatResult(ChatsRecord item) => chatResult.add(item);
  void removeFromChatResult(ChatsRecord item) => chatResult.remove(item);
  void removeAtIndexFromChatResult(int index) => chatResult.removeAt(index);
  void insertAtIndexInChatResult(int index, ChatsRecord item) =>
      chatResult.insert(index, item);
  void updateChatResultAtIndex(int index, Function(ChatsRecord) updateFn) =>
      chatResult[index] = updateFn(chatResult[index]);

  bool loading = false;

  bool isTodaySelected = false;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Firestore Query - Query a collection] action in SearchChat widget.
  List<ChatsRecord>? chat;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}
