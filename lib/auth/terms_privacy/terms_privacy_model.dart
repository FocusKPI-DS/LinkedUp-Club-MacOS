import '/flutter_flow/flutter_flow_util.dart';
import 'terms_privacy_widget.dart' show TermsPrivacyWidget;
import 'package:flutter/material.dart';

class TermsPrivacyModel extends FlutterFlowModel<TermsPrivacyWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for Column widget.
  ScrollController? columnController;

  @override
  void initState(BuildContext context) {
    columnController = ScrollController();
  }

  @override
  void dispose() {
    columnController?.dispose();
  }
}
