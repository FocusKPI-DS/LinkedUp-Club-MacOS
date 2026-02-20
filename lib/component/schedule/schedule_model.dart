import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'schedule_widget.dart' show ScheduleWidget;
import 'package:flutter/material.dart';

class ScheduleModel extends FlutterFlowModel<ScheduleWidget> {
  ///  Local state fields for this component.

  List<SpeakerStruct> speakers = [];
  void addToSpeakers(SpeakerStruct item) => speakers.add(item);
  void removeFromSpeakers(SpeakerStruct item) => speakers.remove(item);
  void removeAtIndexFromSpeakers(int index) => speakers.removeAt(index);
  void insertAtIndexInSpeakers(int index, SpeakerStruct item) =>
      speakers.insert(index, item);
  void updateSpeakersAtIndex(int index, Function(SpeakerStruct) updateFn) =>
      speakers[index] = updateFn(speakers[index]);

  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Custom Action - seperateDate] action in Schedule widget.
  bool? date;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode1;
  TextEditingController? textController1;
  String? Function(BuildContext, String?)? textController1Validator;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode2;
  TextEditingController? textController2;
  String? Function(BuildContext, String?)? textController2Validator;
  // State field(s) for DropDown widget.
  String? dropDownValue;
  FormFieldController<String>? dropDownValueController;
  DateTime? datePicked1;
  DateTime? datePicked2;
  // State field(s) for PlacePicker widget.
  FFPlace placePickerValue = const FFPlace();

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode1?.dispose();
    textController1?.dispose();

    textFieldFocusNode2?.dispose();
    textController2?.dispose();
  }
}
