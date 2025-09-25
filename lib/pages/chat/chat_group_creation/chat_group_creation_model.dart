import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/upload_data.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'chat_group_creation_widget.dart' show ChatGroupCreationWidget;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ChatGroupCreationModel extends FlutterFlowModel<ChatGroupCreationWidget> {
  ///  Local state fields for this page.

  bool isLoading = false;

  String? chatImage;

  DocumentReference? eventsRef;

  List<DocumentReference> members = [];
  void addToMembers(DocumentReference item) => members.add(item);
  void removeFromMembers(DocumentReference item) => members.remove(item);
  void removeAtIndexFromMembers(int index) => members.removeAt(index);
  void insertAtIndexInMembers(int index, DocumentReference item) =>
      members.insert(index, item);
  void updateMembersAtIndex(int index, Function(DocumentReference) updateFn) =>
      members[index] = updateFn(members[index]);

  List<UsersRecord> attendee = [];
  void addToAttendee(UsersRecord item) => attendee.add(item);
  void removeFromAttendee(UsersRecord item) => attendee.remove(item);
  void removeAtIndexFromAttendee(int index) => attendee.removeAt(index);
  void insertAtIndexInAttendee(int index, UsersRecord item) =>
      attendee.insert(index, item);
  void updateAttendeeAtIndex(int index, Function(UsersRecord) updateFn) =>
      attendee[index] = updateFn(attendee[index]);

  List<EventsRecord> event = [];
  void addToEvent(EventsRecord item) => event.add(item);
  void removeFromEvent(EventsRecord item) => event.remove(item);
  void removeAtIndexFromEvent(int index) => event.removeAt(index);
  void insertAtIndexInEvent(int index, EventsRecord item) =>
      event.insert(index, item);
  void updateEventAtIndex(int index, Function(EventsRecord) updateFn) =>
      event[index] = updateFn(event[index]);

  ///  State fields for stateful widgets in this page.

  final formKey = GlobalKey<FormState>();
  // Stores action output result for [Firestore Query - Query a collection] action in ChatGroupCreation widget.
  List<EventsRecord>? events;
  // Stores action output result for [Firestore Query - Query a collection] action in ChatGroupCreation widget.
  List<UsersRecord>? users;
  bool isDataUploading_uploadDataWml = false;
  FFUploadedFile uploadedLocalFile_uploadDataWml =
      FFUploadedFile(bytes: Uint8List.fromList([]));
  String uploadedFileUrl_uploadDataWml = '';

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode1;
  TextEditingController? textController1;
  String? Function(BuildContext, String?)? textController1Validator;
  String? _textController1Validator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'title is required';
    }

    return null;
  }

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode2;
  TextEditingController? textController2;
  String? Function(BuildContext, String?)? textController2Validator;
  String? _textController2Validator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'description is required';
    }

    return null;
  }

  // State field(s) for private widget.
  bool? privateValue;
  // State field(s) for group widget.
  bool? groupValue;
  // State field(s) for Switch widget.
  bool? switchValue;
  // State field(s) for TextFieldEvent widget.
  FocusNode? textFieldEventFocusNode;
  TextEditingController? textFieldEventTextController;
  String? Function(BuildContext, String?)?
      textFieldEventTextControllerValidator;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode3;
  TextEditingController? textController4;
  String? Function(BuildContext, String?)? textController4Validator;
  // State field(s) for Checkbox widget.
  Map<UsersRecord, bool> checkboxValueMap = {};
  List<UsersRecord> get checkboxCheckedItems =>
      checkboxValueMap.entries.where((e) => e.value).map((e) => e.key).toList();

  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  ChatsRecord? chat;

  @override
  void initState(BuildContext context) {
    textController1Validator = _textController1Validator;
    textController2Validator = _textController2Validator;
  }

  @override
  void dispose() {
    textFieldFocusNode1?.dispose();
    textController1?.dispose();

    textFieldFocusNode2?.dispose();
    textController2?.dispose();

    textFieldEventFocusNode?.dispose();
    textFieldEventTextController?.dispose();

    textFieldFocusNode3?.dispose();
    textController4?.dispose();
  }
}
