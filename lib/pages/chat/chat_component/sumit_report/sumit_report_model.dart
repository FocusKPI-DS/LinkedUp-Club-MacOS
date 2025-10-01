import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'sumit_report_widget.dart' show SumitReportWidget;
import 'package:flutter/material.dart';

class SumitReportModel extends FlutterFlowModel<SumitReportWidget> {
  ///  Local state fields for this component.

  String? issue;

  bool other = false;

  ///  State fields for stateful widgets in this component.

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  ReportsRecord? reported;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}
