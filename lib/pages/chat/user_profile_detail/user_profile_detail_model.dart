import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'user_profile_detail_widget.dart' show UserProfileDetailWidget;
import 'package:flutter/material.dart';

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
