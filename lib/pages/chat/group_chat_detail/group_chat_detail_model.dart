import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/event/event_component/event_component_widget.dart';
import '/index.dart';
import 'group_chat_detail_widget.dart' show GroupChatDetailWidget;
import 'package:flutter/material.dart';

class GroupChatDetailModel extends FlutterFlowModel<GroupChatDetailWidget> {
  ///  Local state fields for this page.

  EventsRecord? evnetsDoc;

  List<ParticipantRecord> participants = [];
  void addToParticipants(ParticipantRecord item) => participants.add(item);
  void removeFromParticipants(ParticipantRecord item) =>
      participants.remove(item);
  void removeAtIndexFromParticipants(int index) => participants.removeAt(index);
  void insertAtIndexInParticipants(int index, ParticipantRecord item) =>
      participants.insert(index, item);
  void updateParticipantsAtIndex(
          int index, Function(ParticipantRecord) updateFn) =>
      participants[index] = updateFn(participants[index]);

  List<MessagesRecord> message = [];
  void addToMessage(MessagesRecord item) => message.add(item);
  void removeFromMessage(MessagesRecord item) => message.remove(item);
  void removeAtIndexFromMessage(int index) => message.removeAt(index);
  void insertAtIndexInMessage(int index, MessagesRecord item) =>
      message.insert(index, item);
  void updateMessageAtIndex(int index, Function(MessagesRecord) updateFn) =>
      message[index] = updateFn(message[index]);

  bool laoding = false;

  bool showAddUserPanel = false;

  // Action tasks inline view - expanded/collapsed state
  bool showActionTasks = false;

  // Media/Links/Docs view state
  bool showMediaLinksDocs = false;

  // Inline editing state
  bool isEditingName = false;
  bool isEditingDescription = false;
  TextEditingController? groupNameController;
  TextEditingController? groupDescriptionController;

  // Group member search
  TextEditingController? groupMemberSearchController;
  List<DocumentReference> selectedMembersToAdd = [];
  void addToSelectedMembersToAdd(DocumentReference item) =>
      selectedMembersToAdd.add(item);
  void removeFromSelectedMembersToAdd(DocumentReference item) =>
      selectedMembersToAdd.remove(item);
  void removeAtIndexFromSelectedMembersToAdd(int index) =>
      selectedMembersToAdd.removeAt(index);
  void insertAtIndexInSelectedMembersToAdd(int index, DocumentReference item) =>
      selectedMembersToAdd.insert(index, item);
  void updateSelectedMembersToAddAtIndex(
          int index, Function(DocumentReference) updateFn) =>
      selectedMembersToAdd[index] = updateFn(selectedMembersToAdd[index]);
  void clearSelectedMembersToAdd() => selectedMembersToAdd.clear();

  // User references for add members dialog
  List<DocumentReference> userRef = [];
  void addToUserRef(DocumentReference item) => userRef.add(item);
  void removeFromUserRef(DocumentReference item) => userRef.remove(item);
  void removeAtIndexFromUserRef(int index) => userRef.removeAt(index);
  void insertAtIndexInUserRef(int index, DocumentReference item) =>
      userRef.insert(index, item);
  void updateUserRefAtIndex(int index, Function(DocumentReference) updateFn) =>
      userRef[index] = updateFn(userRef[index]);
  void clearUserRef() => userRef.clear();

  List<ReportsRecord> report = [];
  void addToReport(ReportsRecord item) => report.add(item);
  void removeFromReport(ReportsRecord item) => report.remove(item);
  void removeAtIndexFromReport(int index) => report.removeAt(index);
  void insertAtIndexInReport(int index, ReportsRecord item) =>
      report.insert(index, item);
  void updateReportAtIndex(int index, Function(ReportsRecord) updateFn) =>
      report[index] = updateFn(report[index]);

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Firestore Query - Query a collection] action in GroupChatDetail widget.
  List<ReportsRecord>? chat;
  // Stores action output result for [Firestore Query - Query a collection] action in GroupChatDetail widget.
  List<MessagesRecord>? messages;
  // Stores action output result for [Firestore Query - Query a collection] action in GroupChatDetail widget.
  List<ParticipantRecord>? participant;
  // Model for eventComponent component.
  late EventComponentModel eventComponentModel;

  @override
  void initState(BuildContext context) {
    eventComponentModel = createModel(context, () => EventComponentModel());
    groupMemberSearchController = TextEditingController();
    groupNameController = TextEditingController();
    groupDescriptionController = TextEditingController();
  }

  @override
  void dispose() {
    eventComponentModel.dispose();
    groupMemberSearchController?.dispose();
    groupNameController?.dispose();
    groupDescriptionController?.dispose();
  }
}
