import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'add_profile_widget.dart' show AddProfileWidget;
import 'package:flutter/material.dart';

class AddProfileModel extends FlutterFlowModel<AddProfileWidget> {
  ///  Local state fields for this component.

  String? image;

  bool toggle = false;

  List<UsersRecord> attendee = [];
  void addToAttendee(UsersRecord item) => attendee.add(item);
  void removeFromAttendee(UsersRecord item) => attendee.remove(item);
  void removeAtIndexFromAttendee(int index) => attendee.removeAt(index);
  void insertAtIndexInAttendee(int index, UsersRecord item) =>
      attendee.insert(index, item);
  void updateAttendeeAtIndex(int index, Function(UsersRecord) updateFn) =>
      attendee[index] = updateFn(attendee[index]);

  UsersRecord? user;

  bool isExisting = false;

  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Firestore Query - Query a collection] action in addProfile widget.
  List<UsersRecord>? friends;
  // State field(s) for Checkbox widget.
  bool? checkboxValue;
  bool isDataUploading_uploadDataTi8 = false;
  FFUploadedFile uploadedLocalFile_uploadDataTi8 =
      FFUploadedFile(bytes: Uint8List.fromList([]));
  String uploadedFileUrl_uploadDataTi8 = '';

  // State field(s) for yourName widget.
  FocusNode? yourNameFocusNode;
  TextEditingController? yourNameTextController;
  String? Function(BuildContext, String?)? yourNameTextControllerValidator;
  // State field(s) for Role widget.
  FocusNode? roleFocusNode;
  TextEditingController? roleTextController;
  String? Function(BuildContext, String?)? roleTextControllerValidator;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController3;
  String? Function(BuildContext, String?)? textController3Validator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    yourNameFocusNode?.dispose();
    yourNameTextController?.dispose();

    roleFocusNode?.dispose();
    roleTextController?.dispose();

    textFieldFocusNode?.dispose();
    textController3?.dispose();
  }
}
