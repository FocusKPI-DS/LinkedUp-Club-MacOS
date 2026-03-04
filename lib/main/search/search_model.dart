import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'search_widget.dart' show SearchWidget;
import 'package:flutter/material.dart';

class SearchModel extends FlutterFlowModel<SearchWidget> {
  ///  Local state fields for this page.

  List<EventsRecord> eventsResult = [];
  void addToEventsResult(EventsRecord item) => eventsResult.add(item);
  void removeFromEventsResult(EventsRecord item) => eventsResult.remove(item);
  void removeAtIndexFromEventsResult(int index) => eventsResult.removeAt(index);
  void insertAtIndexInEventsResult(int index, EventsRecord item) =>
      eventsResult.insert(index, item);
  void updateEventsResultAtIndex(int index, Function(EventsRecord) updateFn) =>
      eventsResult[index] = updateFn(eventsResult[index]);

  bool loading = false;

  bool isTodaySelected = false;

  bool isNear = false;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Firestore Query - Query a collection] action in Search widget.
  List<EventsRecord>? event;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}
