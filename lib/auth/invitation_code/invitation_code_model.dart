import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'invitation_code_widget.dart' show InvitationCodeWidget;
import 'package:flutter/material.dart';

class InvitationCodeModel extends FlutterFlowModel<InvitationCodeWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for emailAddress widget.
  FocusNode? emailAddressFocusNode;
  TextEditingController? emailAddressTextController;
  String? Function(BuildContext, String?)? emailAddressTextControllerValidator;
  // Stores action output result for [Firestore Query - Query a collection] action in Button widget.
  UsersRecord? isValid;
  // Stores action output result for [Firestore Query - Query a collection] action in Button widget.
  List<InvitationCodeRecord>? code;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    emailAddressFocusNode?.dispose();
    emailAddressTextController?.dispose();
  }
}
