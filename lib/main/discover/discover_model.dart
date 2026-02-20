import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/event/event_component/event_component_widget.dart';
import 'discover_widget.dart' show DiscoverWidget;
import 'package:flutter/material.dart';

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
