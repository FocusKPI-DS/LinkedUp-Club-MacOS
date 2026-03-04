import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'reminder_time_widget.dart' show ReminderTimeWidget;
import 'package:flutter/material.dart';

class ReminderTimeModel extends FlutterFlowModel<ReminderTimeWidget> {
  ///  Local state fields for this component.

  int selectedFrequency = 1;

  ///  State fields for stateful widgets in this component.

  // State field(s) for ChoiceChips widget.
  FormFieldController<List<String>>? choiceChipsValueController;
  String? get choiceChipsValue =>
      choiceChipsValueController?.value?.firstOrNull;
  set choiceChipsValue(String? val) =>
      choiceChipsValueController?.value = val != null ? [val] : [];
  // Stores action output result for [Custom Action - updateGroupReminderFrequency] action in Button widget.
  bool? isSuccess;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
