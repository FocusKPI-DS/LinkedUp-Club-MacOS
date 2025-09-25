import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/chat/chat_component/memo/memo_widget.dart';
import '/pages/event/gallary/gallary_widget.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'user_profile_detail_widget.dart' show UserProfileDetailWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class UserProfileDetailModel extends FlutterFlowModel<UserProfileDetailWidget> {
  ///  Local state fields for this page.

  String? memoText;

  bool friend = false;

  List<DocumentReference> members = [];
  void addToMembers(DocumentReference item) => members.add(item);
  void removeFromMembers(DocumentReference item) => members.remove(item);
  void removeAtIndexFromMembers(int index) => members.removeAt(index);
  void insertAtIndexInMembers(int index, DocumentReference item) =>
      members.insert(index, item);
  void updateMembersAtIndex(int index, Function(DocumentReference) updateFn) =>
      members[index] = updateFn(members[index]);

  String? image;

  bool? loading = false;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - handleDeletedContent] action in UserProfileDetail widget.
  bool? isExist;
  // Stores action output result for [Firestore Query - Query a collection] action in UserProfileDetail widget.
  UserMemoRecord? memo;
  // Stores action output result for [Custom Action - fetchSpecificChatDoc] action in Button widget.
  ChatsRecord? thisChatDoc;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  ChatsRecord? chat;
  // State field(s) for Switch widget.
  bool? switchValue;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
