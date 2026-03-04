import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';

class MobileNewChatModel extends FlutterFlowModel {
  ///  State fields for stateful widgets in this page.

  final unfocusNode = FocusNode();

  // New Chat search
  TextEditingController? newChatSearchController;

  @override
  void initState(BuildContext context) {
    newChatSearchController = TextEditingController();
  }

  @override
  void dispose() {
    unfocusNode.dispose();
    newChatSearchController?.dispose();
  }
}

