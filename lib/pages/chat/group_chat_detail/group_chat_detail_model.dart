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
  }

  @override
  void dispose() {
    eventComponentModel.dispose();
  }
}
