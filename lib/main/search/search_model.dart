import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/component/empty_schedule/empty_schedule_widget.dart';
import '/component/filter_search/filter_search_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/event/event_component/event_component_widget.dart';
import 'dart:math';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/permissions_util.dart';
import '/index.dart';
import 'search_widget.dart' show SearchWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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
