import '/flutter_flow/flutter_flow_util.dart';
import 'create_workspace_widget.dart' show CreateWorkspaceWidget;
import 'package:flutter/material.dart';

class CreateWorkspaceModel extends FlutterFlowModel<CreateWorkspaceWidget> {
  ///  State fields for stateful widgets in this page.

  final unfocusNode = FocusNode();
  // State field(s) for workspaceName text field.
  FocusNode? workspaceNameFocusNode;
  TextEditingController? workspaceNameController;
  String? Function(BuildContext, String?)? workspaceNameControllerValidator;
  // State field(s) for description text field.
  FocusNode? descriptionFocusNode;
  TextEditingController? descriptionController;
  String? Function(BuildContext, String?)? descriptionControllerValidator;

  @override
  void initState(BuildContext context) {
    workspaceNameControllerValidator = _workspaceNameControllerValidator;
    descriptionControllerValidator = _descriptionControllerValidator;
  }

  @override
  void dispose() {
    unfocusNode.dispose();
    workspaceNameFocusNode?.dispose();
    workspaceNameController?.dispose();

    descriptionFocusNode?.dispose();
    descriptionController?.dispose();
  }

  /// Additional helper methods are added here.

  String? _workspaceNameControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Workspace name is required';
    }
    if (val.length < 3) {
      return 'Workspace name must be at least 3 characters';
    }
    return null;
  }

  String? _descriptionControllerValidator(BuildContext context, String? val) {
    // Description is optional, so no validation needed
    return null;
  }
}
