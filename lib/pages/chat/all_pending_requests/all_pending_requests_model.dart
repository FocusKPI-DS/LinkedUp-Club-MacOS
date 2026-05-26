import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'all_pending_requests_widget.dart' show AllPendingRequestsWidget;
import 'package:flutter/material.dart';

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
