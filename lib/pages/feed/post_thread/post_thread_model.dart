import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'post_thread_widget.dart' show PostThreadWidget;
import 'package:flutter/material.dart';

class PostThreadModel extends FlutterFlowModel<PostThreadWidget> {
  ///  Local state fields for this component.

  bool islike = false;

  int? likeNum;

  int? cmmNum;

  bool isSaved = false;

  bool isLoaded = true;

  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Firestore Query - Query a collection] action in Row widget.
  UsersRecord? user;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
