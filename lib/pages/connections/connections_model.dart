import '/flutter_flow/flutter_flow_util.dart';
import 'connections_widget.dart' show ConnectionsWidget;
import 'package:flutter/material.dart';

class ConnectionsModel extends FlutterFlowModel<ConnectionsWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for search widget.
  FocusNode? searchFocusNode;
  TextEditingController? searchTextController;
  String? Function(BuildContext, String?)? searchTextControllerValidator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    searchFocusNode?.dispose();
    searchTextController?.dispose();
  }
}