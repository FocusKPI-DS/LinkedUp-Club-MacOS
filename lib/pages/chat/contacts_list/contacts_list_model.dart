import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/component/empty_friend_list/empty_friend_list_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:math';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'contacts_list_widget.dart' show ContactsListWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ContactsListModel extends FlutterFlowModel<ContactsListWidget> {
  ///  Local state fields for this page.

  List<DocumentReference> member = [];
  void addToMember(DocumentReference item) => member.add(item);
  void removeFromMember(DocumentReference item) => member.remove(item);
  void removeAtIndexFromMember(int index) => member.removeAt(index);
  void insertAtIndexInMember(int index, DocumentReference item) =>
      member.insert(index, item);
  void updateMemberAtIndex(int index, Function(DocumentReference) updateFn) =>
      member[index] = updateFn(member[index]);

  List<String> name = [];
  void addToName(String item) => name.add(item);
  void removeFromName(String item) => name.remove(item);
  void removeAtIndexFromName(int index) => name.removeAt(index);
  void insertAtIndexInName(int index, String item) => name.insert(index, item);
  void updateNameAtIndex(int index, Function(String) updateFn) =>
      name[index] = updateFn(name[index]);

  List<ChatsRecord> chat1 = [];
  void addToChat1(ChatsRecord item) => chat1.add(item);
  void removeFromChat1(ChatsRecord item) => chat1.remove(item);
  void removeAtIndexFromChat1(int index) => chat1.removeAt(index);
  void insertAtIndexInChat1(int index, ChatsRecord item) =>
      chat1.insert(index, item);
  void updateChat1AtIndex(int index, Function(ChatsRecord) updateFn) =>
      chat1[index] = updateFn(chat1[index]);

  /// Friends
  List<UsersRecord> friendList = [];
  void addToFriendList(UsersRecord item) => friendList.add(item);
  void removeFromFriendList(UsersRecord item) => friendList.remove(item);
  void removeAtIndexFromFriendList(int index) => friendList.removeAt(index);
  void insertAtIndexInFriendList(int index, UsersRecord item) =>
      friendList.insert(index, item);
  void updateFriendListAtIndex(int index, Function(UsersRecord) updateFn) =>
      friendList[index] = updateFn(friendList[index]);

  String? char;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Firestore Query - Query a collection] action in ContactsList widget.
  List<ChatsRecord>? myChat;
  // Stores action output result for [Custom Action - getFirstLetterName] action in Container widget.
  List<UsersRecord>? friendsList;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
