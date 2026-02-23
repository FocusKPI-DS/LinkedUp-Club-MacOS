import '/flutter_flow/flutter_flow_util.dart';
import 'memo_widget.dart' show MemoWidget;
import 'package:flutter/material.dart';

class MemoModel extends FlutterFlowModel<MemoWidget> {
  ///  Local state fields for this component.

  String? image;

  String? text;

  ///  State fields for stateful widgets in this component.

  bool isDataUploading_uploadDataBlw = false;
  FFUploadedFile uploadedLocalFile_uploadDataBlw =
      FFUploadedFile(bytes: Uint8List.fromList([]));
  String uploadedFileUrl_uploadDataBlw = '';

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}
