import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'post_detail_widget.dart' show PostDetailWidget;
import 'package:flutter/material.dart';

class PostDetailModel extends FlutterFlowModel<PostDetailWidget> {
  ///  Local state fields for this page.

  String? content;

  int? numCmm;

  ///  State fields for stateful widgets in this page.

  // State field(s) for bigculom widget.
  ScrollController? bigculom;
  // State field(s) for ListView widget.
  ScrollController? listViewController;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;
  // Stores action output result for [Backend Call - Create Document] action in IconButton widget.
  CommentsRecord? done;

  @override
  void initState(BuildContext context) {
    bigculom = ScrollController();
    listViewController = ScrollController();
  }

  @override
  void dispose() {
    bigculom?.dispose();
    listViewController?.dispose();
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}
