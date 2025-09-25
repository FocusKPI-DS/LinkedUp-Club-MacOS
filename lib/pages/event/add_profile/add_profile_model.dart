import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_toggle_icon.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/upload_data.dart';
import 'dart:math';
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import 'add_profile_widget.dart' show AddProfileWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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
