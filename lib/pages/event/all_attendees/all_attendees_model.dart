import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'all_attendees_widget.dart' show AllAttendeesWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AllAttendeesModel extends FlutterFlowModel<AllAttendeesWidget> {
  ///  Local state fields for this page.

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

  bool loading = false;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Firestore Query - Query a collection] action in AllAttendees widget.
  List<ParticipantRecord>? participant;
  // Stores action output result for [Custom Action - syncEventbriteAttendees] action in EnhancedAllAttendees widget.
  bool? isSuccess;
  // Stores action output result for [Custom Action - updateEventTicketingMode] action in EnhancedAllAttendees widget.
  bool? success;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
