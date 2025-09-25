import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:math';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'search_chat_widget.dart' show SearchChatWidget;
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

class SearchChatModel extends FlutterFlowModel<SearchChatWidget> {
  ///  Local state fields for this page.

  List<ChatsRecord> chatResult = [];
  void addToChatResult(ChatsRecord item) => chatResult.add(item);
  void removeFromChatResult(ChatsRecord item) => chatResult.remove(item);
  void removeAtIndexFromChatResult(int index) => chatResult.removeAt(index);
  void insertAtIndexInChatResult(int index, ChatsRecord item) =>
      chatResult.insert(index, item);
  void updateChatResultAtIndex(int index, Function(ChatsRecord) updateFn) =>
      chatResult[index] = updateFn(chatResult[index]);

  bool loading = false;

  bool isTodaySelected = false;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Firestore Query - Query a collection] action in SearchChat widget.
  List<ChatsRecord>? chat;
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
