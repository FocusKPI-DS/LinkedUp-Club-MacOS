import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/backend/push_notifications/push_notifications_util.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_media_display.dart';
import '/flutter_flow/flutter_flow_pdf_viewer.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_video_player.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/upload_data.dart';
import '/pages/chat/chat_component/chat_thread/chat_thread_widget.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/permissions_util.dart';
import 'chat_thread_component_widget.dart' show ChatThreadComponentWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

class ChatThreadComponentModel
    extends FlutterFlowModel<ChatThreadComponentWidget> {
  ///  Local state fields for this component.

  String? image;

  String? file;

  bool select = false;

  bool audio = false;

  String? audiopath;

  bool recording = false;

  String? audioMainUrl;

  bool? isSending = false;

  bool? isSendingImage = false;

  bool isMention = false;

  List<DocumentReference> userSend = [];
  void addToUserSend(DocumentReference item) => userSend.add(item);
  void removeFromUserSend(DocumentReference item) => userSend.remove(item);
  void removeAtIndexFromUserSend(int index) => userSend.removeAt(index);
  void insertAtIndexInUserSend(int index, DocumentReference item) =>
      userSend.insert(index, item);
  void updateUserSendAtIndex(int index, Function(DocumentReference) updateFn) =>
      userSend[index] = updateFn(userSend[index]);

  String text = 'Tap the mic to record your voice.';

  List<String> images = [];
  void addToImages(String item) => images.add(item);
  void removeFromImages(String item) => images.remove(item);
  void removeAtIndexFromImages(int index) => images.removeAt(index);
  void insertAtIndexInImages(int index, String item) =>
      images.insert(index, item);
  void updateImagesAtIndex(int index, Function(String) updateFn) =>
      images[index] = updateFn(images[index]);

  ///  State fields for stateful widgets in this component.

  // Models for chatThread dynamic component.
  late FlutterFlowDynamicModels<ChatThreadModel> chatThreadModels;
  // State field(s) for message widget.
  FocusNode? messageFocusNode;
  TextEditingController? messageTextController;
  String? Function(BuildContext, String?)? messageTextControllerValidator;
  // Stores action output result for [Custom Action - checkValidWords] action in IconButton widget.
  bool? isValid;
  // Stores action output result for [Custom Action - uploadAudioToStorage] action in IconButton widget.
  String? netwoekURL;
  // Stores action output result for [Backend Call - Create Document] action in IconButton widget.
  MessagesRecord? newChat;
  bool isDataUploading_uploadData = false;
  List<FFUploadedFile> uploadedLocalFiles_uploadData = [];
  List<String> uploadedFileUrls_uploadData = [];

  bool isDataUploading_uploadDataCamera = false;
  FFUploadedFile uploadedLocalFile_uploadDataCamera =
      FFUploadedFile(bytes: Uint8List.fromList([]));
  String uploadedFileUrl_uploadDataCamera = '';

  bool isDataUploading_uploadDataFile = false;
  FFUploadedFile uploadedLocalFile_uploadDataFile =
      FFUploadedFile(bytes: Uint8List.fromList([]));
  String uploadedFileUrl_uploadDataFile = '';

  AudioRecorder? audioRecorder;
  String? stop;
  FFUploadedFile recordedFileBytes =
      FFUploadedFile(bytes: Uint8List.fromList([]));

  @override
  void initState(BuildContext context) {
    chatThreadModels = FlutterFlowDynamicModels(() => ChatThreadModel());
  }

  @override
  void dispose() {
    chatThreadModels.dispose();
    messageFocusNode?.dispose();
    messageTextController?.dispose();
  }
}
