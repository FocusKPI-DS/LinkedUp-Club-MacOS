import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/component/empty_schedule/empty_schedule_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/event/event_component/event_component_widget.dart';
import 'dart:math';
import 'dart:ui';
import '/index.dart';
import 'event_widget.dart' show EventWidget;
import 'package:sticky_headers/sticky_headers.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class EventModel extends FlutterFlowModel<EventWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for TabBar widget.
  TabController? tabBarController;
  int get tabBarCurrentIndex =>
      tabBarController != null ? tabBarController!.index : 0;
  int get tabBarPreviousIndex =>
      tabBarController != null ? tabBarController!.previousIndex : 0;

  // Models for eventComponent dynamic component.
  late FlutterFlowDynamicModels<EventComponentModel> eventComponentModels1;
  // Models for eventComponent dynamic component.
  late FlutterFlowDynamicModels<EventComponentModel> eventComponentModels2;
  // Models for eventComponent dynamic component.
  late FlutterFlowDynamicModels<EventComponentModel> eventComponentModels3;
  // Models for eventComponent dynamic component.
  late FlutterFlowDynamicModels<EventComponentModel> eventComponentModels4;
  // Models for eventComponent dynamic component.
  late FlutterFlowDynamicModels<EventComponentModel> eventComponentModels5;
  // Models for eventComponent dynamic component.
  late FlutterFlowDynamicModels<EventComponentModel> eventComponentModels6;

  @override
  void initState(BuildContext context) {
    eventComponentModels1 =
        FlutterFlowDynamicModels(() => EventComponentModel());
    eventComponentModels2 =
        FlutterFlowDynamicModels(() => EventComponentModel());
    eventComponentModels3 =
        FlutterFlowDynamicModels(() => EventComponentModel());
    eventComponentModels4 =
        FlutterFlowDynamicModels(() => EventComponentModel());
    eventComponentModels5 =
        FlutterFlowDynamicModels(() => EventComponentModel());
    eventComponentModels6 =
        FlutterFlowDynamicModels(() => EventComponentModel());
  }

  @override
  void dispose() {
    tabBarController?.dispose();
    eventComponentModels1.dispose();
    eventComponentModels2.dispose();
    eventComponentModels3.dispose();
    eventComponentModels4.dispose();
    eventComponentModels5.dispose();
    eventComponentModels6.dispose();
  }
}
