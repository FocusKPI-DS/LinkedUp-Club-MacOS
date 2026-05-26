import '/flutter_flow/flutter_flow_util.dart';
import 'workspace_management_widget.dart' show WorkspaceManagementWidget;
import 'package:flutter/material.dart';

class WorkspaceManagementModel
    extends FlutterFlowModel<WorkspaceManagementWidget> {
  ///  State field(s) for this page.

  final unfocusNode = FocusNode();

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    unfocusNode.dispose();
  }
}
