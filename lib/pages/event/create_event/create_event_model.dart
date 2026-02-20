import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import '/index.dart';
import 'create_event_widget.dart' show CreateEventWidget;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CreateEventModel extends FlutterFlowModel<CreateEventWidget> {
  ///  Local state fields for this page.

  List<String> categorySelected = [];
  void addToCategorySelected(String item) => categorySelected.add(item);
  void removeFromCategorySelected(String item) => categorySelected.remove(item);
  void removeAtIndexFromCategorySelected(int index) =>
      categorySelected.removeAt(index);
  void insertAtIndexInCategorySelected(int index, String item) =>
      categorySelected.insert(index, item);
  void updateCategorySelectedAtIndex(int index, Function(String) updateFn) =>
      categorySelected[index] = updateFn(categorySelected[index]);

  String? image =
      'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fevent.jpg?alt=media&token=3e30709d-40ff-4e86-a702-5c9c2068fa8d';

  List<SpeakerStruct> speaker = [];
  void addToSpeaker(SpeakerStruct item) => speaker.add(item);
  void removeFromSpeaker(SpeakerStruct item) => speaker.remove(item);
  void removeAtIndexFromSpeaker(int index) => speaker.removeAt(index);
  void insertAtIndexInSpeaker(int index, SpeakerStruct item) =>
      speaker.insert(index, item);
  void updateSpeakerAtIndex(int index, Function(SpeakerStruct) updateFn) =>
      speaker[index] = updateFn(speaker[index]);

  bool isload = false;

  List<ScheduleStruct> schedule = [];
  void addToSchedule(ScheduleStruct item) => schedule.add(item);
  void removeFromSchedule(ScheduleStruct item) => schedule.remove(item);
  void removeAtIndexFromSchedule(int index) => schedule.removeAt(index);
  void insertAtIndexInSchedule(int index, ScheduleStruct item) =>
      schedule.insert(index, item);
  void updateScheduleAtIndex(int index, Function(ScheduleStruct) updateFn) =>
      schedule[index] = updateFn(schedule[index]);

  String? selectedDate;

  int? scheduleIndex;

  bool isDateSelected = false;

  DateTime? startDate;

  DateTime? endTime;

  String? location;

  LatLng? latlng;

  DateTime? deadlinePaying;

  String eventType = 'physical';

  String ticketingMethod = 'stripe';

  ///  State fields for stateful widgets in this page.

  final formKey = GlobalKey<FormState>();
  bool isDataUploading_uploadDataZ7t = false;
  FFUploadedFile uploadedLocalFile_uploadDataZ7t =
      FFUploadedFile(bytes: Uint8List.fromList([]));
  String uploadedFileUrl_uploadDataZ7t = '';

  // State field(s) for title widget.
  FocusNode? titleFocusNode;
  TextEditingController? titleTextController;
  String? Function(BuildContext, String?)? titleTextControllerValidator;
  String? _titleTextControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'title is required';
    }

    return null;
  }

  DateTime? datePicked1;
  DateTime? datePicked2;
  // Stores action output result for [Custom Action - seperateDate] action in Container widget.
  bool? seperate;
  // State field(s) for PlacePicker widget.
  FFPlace placePickerValue = const FFPlace();
  // State field(s) for eventLink widget.
  FocusNode? eventLinkFocusNode;
  TextEditingController? eventLinkTextController;
  String? Function(BuildContext, String?)? eventLinkTextControllerValidator;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController3;
  String? Function(BuildContext, String?)? textController3Validator;
  String? _textController3Validator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Description is required';
    }

    return null;
  }

  // State field(s) for Category widget.
  FormFieldController<List<String>>? categoryValueController;
  List<String>? get categoryValues => categoryValueController?.value;
  set categoryValues(List<String>? val) => categoryValueController?.value = val;
  // State field(s) for Price widget.
  FocusNode? priceFocusNode;
  TextEditingController? priceTextController;
  String? Function(BuildContext, String?)? priceTextControllerValidator;
  String? _priceTextControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Price is required';
    }

    return null;
  }

  // State field(s) for amount widget.
  FocusNode? amountFocusNode;
  TextEditingController? amountTextController;
  String? Function(BuildContext, String?)? amountTextControllerValidator;
  DateTime? datePicked3;
  // State field(s) for Group widget.
  bool? groupValue;
  // State field(s) for Switch widget.
  bool? switchValue1;
  // State field(s) for Switch widget.
  bool? switchValue2;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  EventsRecord? createdEventTop;
  // Stores action output result for [Custom Action - generateLink] action in Button widget.
  String? generate;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  ParticipantRecord? subParticipants;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  ChatsRecord? chat;

  @override
  void initState(BuildContext context) {
    titleTextControllerValidator = _titleTextControllerValidator;
    textController3Validator = _textController3Validator;
    priceTextControllerValidator = _priceTextControllerValidator;
  }

  @override
  void dispose() {
    titleFocusNode?.dispose();
    titleTextController?.dispose();

    eventLinkFocusNode?.dispose();
    eventLinkTextController?.dispose();

    textFieldFocusNode?.dispose();
    textController3?.dispose();

    priceFocusNode?.dispose();
    priceTextController?.dispose();

    amountFocusNode?.dispose();
    amountTextController?.dispose();
  }
}
