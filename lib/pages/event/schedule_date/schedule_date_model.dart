import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'schedule_date_widget.dart' show ScheduleDateWidget;
import 'package:flutter/material.dart';

class ScheduleDateModel extends FlutterFlowModel<ScheduleDateWidget> {
  ///  Local state fields for this component.

  List<SpeakerStruct> speakers = [];
  void addToSpeakers(SpeakerStruct item) => speakers.add(item);
  void removeFromSpeakers(SpeakerStruct item) => speakers.remove(item);
  void removeAtIndexFromSpeakers(int index) => speakers.removeAt(index);
  void insertAtIndexInSpeakers(int index, SpeakerStruct item) =>
      speakers.insert(index, item);
  void updateSpeakersAtIndex(int index, Function(SpeakerStruct) updateFn) =>
      speakers[index] = updateFn(speakers[index]);

  List<ScheduleStruct> listSchedule = [];
  void addToListSchedule(ScheduleStruct item) => listSchedule.add(item);
  void removeFromListSchedule(ScheduleStruct item) => listSchedule.remove(item);
  void removeAtIndexFromListSchedule(int index) => listSchedule.removeAt(index);
  void insertAtIndexInListSchedule(int index, ScheduleStruct item) =>
      listSchedule.insert(index, item);
  void updateListScheduleAtIndex(
          int index, Function(ScheduleStruct) updateFn) =>
      listSchedule[index] = updateFn(listSchedule[index]);

  List<DateScheduleStruct> dateSchedule = [];
  void addToDateSchedule(DateScheduleStruct item) => dateSchedule.add(item);
  void removeFromDateSchedule(DateScheduleStruct item) =>
      dateSchedule.remove(item);
  void removeAtIndexFromDateSchedule(int index) => dateSchedule.removeAt(index);
  void insertAtIndexInDateSchedule(int index, DateScheduleStruct item) =>
      dateSchedule.insert(index, item);
  void updateDateScheduleAtIndex(
          int index, Function(DateScheduleStruct) updateFn) =>
      dateSchedule[index] = updateFn(dateSchedule[index]);

  DateTime? startTime;

  DateTime? endTime;

  String? location;

  LatLng? lagLng;

  bool loading = false;

  ///  State fields for stateful widgets in this component.

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode1;
  TextEditingController? textController1;
  String? Function(BuildContext, String?)? textController1Validator;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode2;
  TextEditingController? textController2;
  String? Function(BuildContext, String?)? textController2Validator;
  DateTime? datePicked1;
  DateTime? datePicked2;
  // State field(s) for PlacePicker widget.
  FFPlace placePickerValue = const FFPlace();
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode3;
  TextEditingController? textController3;
  String? Function(BuildContext, String?)? textController3Validator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode1?.dispose();
    textController1?.dispose();

    textFieldFocusNode2?.dispose();
    textController2?.dispose();

    textFieldFocusNode3?.dispose();
    textController3?.dispose();
  }
}
