import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'all_attendees_widget.dart' show AllAttendeesWidget;
import 'package:flutter/material.dart';

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
