import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/component/empty_schedule/empty_schedule_widget.dart';
import '/components/delete_chat_group_widget.dart';
import '/flutter_flow/flutter_flow_expanded_image_view.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/chat/chat_component/add_user/add_user_widget.dart';
import '/pages/chat/chat_component/reminder_time/reminder_time_widget.dart';
import '/pages/event/event_component/event_component_widget.dart';
import '/pages/event/gallary/gallary_widget.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'group_chat_detail_widget.dart' show GroupChatDetailWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';

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
