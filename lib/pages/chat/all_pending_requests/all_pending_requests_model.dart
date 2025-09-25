import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/component/empty_friend_list/empty_friend_list_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:math';
import 'dart:ui';
import 'all_pending_requests_widget.dart' show AllPendingRequestsWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AllPendingRequestsModel
    extends FlutterFlowModel<AllPendingRequestsWidget> {
  ///  Local state fields for this page.

  List<DocumentReference> member = [];
  void addToMember(DocumentReference item) => member.add(item);
  void removeFromMember(DocumentReference item) => member.remove(item);
  void removeAtIndexFromMember(int index) => member.removeAt(index);
  void insertAtIndexInMember(int index, DocumentReference item) =>
      member.insert(index, item);
  void updateMemberAtIndex(int index, Function(DocumentReference) updateFn) =>
      member[index] = updateFn(member[index]);

  List<UsersRecord> usersDoc = [];
  void addToUsersDoc(UsersRecord item) => usersDoc.add(item);
  void removeFromUsersDoc(UsersRecord item) => usersDoc.remove(item);
  void removeAtIndexFromUsersDoc(int index) => usersDoc.removeAt(index);
  void insertAtIndexInUsersDoc(int index, UsersRecord item) =>
      usersDoc.insert(index, item);
  void updateUsersDocAtIndex(int index, Function(UsersRecord) updateFn) =>
      usersDoc[index] = updateFn(usersDoc[index]);

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Firestore Query - Query a collection] action in AllPendingRequests widget.
  List<UsersRecord>? users;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
