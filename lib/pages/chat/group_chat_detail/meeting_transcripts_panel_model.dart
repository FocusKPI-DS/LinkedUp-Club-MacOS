import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';

class MeetingTranscriptsPanelModel extends FlutterFlowModel {
  // Fireflies integration
  TextEditingController? firefliesApiKeyController;
  TextEditingController? firefliesSearchController;
  bool firefliesTranscriptsLoading = false;
  List<dynamic> firefliesTranscripts = [];
  String? firefliesError;
  bool firefliesInitialLoadDone = false;
  bool firefliesHasMore = true;
  static const int firefliesPageSize = 5;
  bool firefliesConnected = false;
  bool firefliesKeyLoadAttempted = false;
  Set<String> firefliesFetchingTranscriptIds = {};
  bool firefliesAutoLoadScheduled = false;

  TextEditingController? manualMeetingTranscriptionController;
  bool manualMeetingTranscriptionInitialized = false;
  bool firefliesShowManualInput = false;
  bool manualTranscriptSaving = false;

  @override
  void initState(BuildContext context) {
    firefliesApiKeyController = TextEditingController();
    firefliesSearchController = TextEditingController();
    manualMeetingTranscriptionController = TextEditingController();
  }

  @override
  void dispose() {
    firefliesApiKeyController?.dispose();
    firefliesSearchController?.dispose();
    manualMeetingTranscriptionController?.dispose();
  }
}
