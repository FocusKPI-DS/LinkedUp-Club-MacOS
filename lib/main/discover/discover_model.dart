import '/auth/base_auth_user_provider.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/component/empty_schedule/empty_schedule_widget.dart';
import '/components/congratulatio_acc_creation_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/event/event_component/event_component_widget.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/permissions_util.dart';
import '/index.dart';
import 'discover_widget.dart' show DiscoverWidget;
import 'package:branchio_dynamic_linking_akp5u6/custom_code/actions/index.dart'
    as branchio_dynamic_linking_akp5u6_actions;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class DiscoverModel extends FlutterFlowModel<DiscoverWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - ensureFcmToken] action in Discover widget.
  bool? isSuccess;
  // Stores action output result for [Custom Action - checkEventInvite] action in Discover widget.
  DeeplinkInfoStruct? data;
  // State field(s) for TabBar widget.
  TabController? tabBarController;
  int get tabBarCurrentIndex =>
      tabBarController != null ? tabBarController!.index : 0;
  int get tabBarPreviousIndex =>
      tabBarController != null ? tabBarController!.previousIndex : 0;

  // Models for eventComponent dynamic component.
  late FlutterFlowDynamicModels<EventComponentModel> eventComponentModels2;
  // Stores action output result for [Action Block - checkBlock] action in Button widget.
  bool? blocked;

  @override
  void initState(BuildContext context) {
    eventComponentModels2 =
        FlutterFlowDynamicModels(() => EventComponentModel());
  }

  @override
  void dispose() {
    tabBarController?.dispose();
    eventComponentModels2.dispose();
  }
}
