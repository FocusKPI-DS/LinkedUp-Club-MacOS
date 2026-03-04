import '/flutter_flow/flutter_flow_util.dart';
import '/pages/chat/chat_component/chat_thread_component/chat_thread_component_widget.dart';
import '/index.dart';
import 'chat_detail_widget.dart' show ChatDetailWidget;
import 'package:flutter/material.dart';

class ChatDetailModel extends FlutterFlowModel<ChatDetailWidget> {
  ///  Local state fields for this page.

  String? message;

  bool loading = false;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - handleDeletedContent] action in ChatDetail widget.
  bool? isExist;
  // Stores action output result for [Action Block - checkBlock] action in ChatDetail widget.
  bool? blocked;
  // Model for chatThreadComponent component.
  late ChatThreadComponentModel chatThreadComponentModel;

  @override
  void initState(BuildContext context) {
    chatThreadComponentModel =
        createModel(context, () => ChatThreadComponentModel());
  }

  @override
  void dispose() {
    chatThreadComponentModel.dispose();
  }
}
