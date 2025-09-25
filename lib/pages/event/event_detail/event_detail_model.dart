import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/push_notifications/push_notifications_util.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/schema/structs/index.dart';
import '/component/empty_schedule/empty_schedule_widget.dart';
import '/component/speaker_info/speaker_info_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/event/defult_chat_exist/defult_chat_exist_widget.dart';
import 'dart:math';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'event_detail_widget.dart' show EventDetailWidget;
import 'package:branchio_dynamic_linking_akp5u6/custom_code/actions/index.dart'
    as branchio_dynamic_linking_akp5u6_actions;
import 'package:branchio_dynamic_linking_akp5u6/flutter_flow/custom_functions.dart'
    as branchio_dynamic_linking_akp5u6_functions;
import 'package:aligned_dialog/aligned_dialog.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class EventDetailModel extends FlutterFlowModel<EventDetailWidget> {
  ///  Local state fields for this page.

  List<ScheduleStruct> schedule = [];
  void addToSchedule(ScheduleStruct item) => schedule.add(item);
  void removeFromSchedule(ScheduleStruct item) => schedule.remove(item);
  void removeAtIndexFromSchedule(int index) => schedule.removeAt(index);
  void insertAtIndexInSchedule(int index, ScheduleStruct item) =>
      schedule.insert(index, item);
  void updateScheduleAtIndex(int index, Function(ScheduleStruct) updateFn) =>
      schedule[index] = updateFn(schedule[index]);

  String? date;

  bool? joinSelected = false;

  bool? loading = false;

  EventsRecord? eventDoc;

  List<ParticipantRecord> participant = [];
  void addToParticipant(ParticipantRecord item) => participant.add(item);
  void removeFromParticipant(ParticipantRecord item) =>
      participant.remove(item);
  void removeAtIndexFromParticipant(int index) => participant.removeAt(index);
  void insertAtIndexInParticipant(int index, ParticipantRecord item) =>
      participant.insert(index, item);
  void updateParticipantAtIndex(
          int index, Function(ParticipantRecord) updateFn) =>
      participant[index] = updateFn(participant[index]);

  int? attendeesNum = 1;

  String? canonicalId;

  dynamic metaDataMap;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - handleDeletedContent] action in EventDetail widget.
  bool? isExist;
  // Stores action output result for [Firestore Query - Query a collection] action in EventDetail widget.
  EventsRecord? events;
  // Stores action output result for [Firestore Query - Query a collection] action in EventDetail widget.
  List<ParticipantRecord>? participants;
  // Stores action output result for [Firestore Query - Query a collection] action in EventDetail widget.
  ChatsRecord? chat;
  // Stores action output result for [Custom Action - generateLink] action in Icon widget.
  String? generate;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  ParticipantRecord? joined;
  // Stores action output result for [Action Block - checkBlock] action in Button widget.
  bool? blocked;
  // Stores action output result for [Firestore Query - Query a collection] action in EventTicketPurchaseButton widget.
  List<ParticipantRecord>? allParticipantsUpdated;
  // Stores action output result for [Backend Call - Read Document] action in EventTicketPurchaseButton widget.
  EventsRecord? updatedEvent;
  // State field(s) for TabBar widget.
  TabController? tabBarController;
  int get tabBarCurrentIndex =>
      tabBarController != null ? tabBarController!.index : 0;
  int get tabBarPreviousIndex =>
      tabBarController != null ? tabBarController!.previousIndex : 0;

  // Stores action output result for [Custom Action - downloadQRCode] action in Icon widget.
  bool? isSuccess;
  // Models for SpeakerInfo dynamic component.
  late FlutterFlowDynamicModels<SpeakerInfoModel> speakerInfoModels;

  @override
  void initState(BuildContext context) {
    speakerInfoModels = FlutterFlowDynamicModels(() => SpeakerInfoModel());
  }

  @override
  void dispose() {
    tabBarController?.dispose();
    speakerInfoModels.dispose();
  }
}
