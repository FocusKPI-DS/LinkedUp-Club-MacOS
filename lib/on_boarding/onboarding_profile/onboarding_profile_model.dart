import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/backend/schema/enums/enums.dart';
import '/components/congratulatio_acc_creation_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_place_picker.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/upload_data.dart';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'onboarding_profile_widget.dart' show OnboardingProfileWidget;
import 'package:smooth_page_indicator/smooth_page_indicator.dart'
    as smooth_page_indicator;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_commons/flutter_flow/place.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class OnboardingProfileModel extends FlutterFlowModel<OnboardingProfileWidget> {
  ///  Local state fields for this page.

  String? userProfile;

  List<String> iterested = [];
  void addToIterested(String item) => iterested.add(item);
  void removeFromIterested(String item) => iterested.remove(item);
  void removeAtIndexFromIterested(int index) => iterested.removeAt(index);
  void insertAtIndexInIterested(int index, String item) =>
      iterested.insert(index, item);
  void updateIterestedAtIndex(int index, Function(String) updateFn) =>
      iterested[index] = updateFn(iterested[index]);

  bool isload = false;

  bool location = false;

  ///  State fields for stateful widgets in this page.

  // State field(s) for PageView widget.
  PageController? pageViewController;

  int get pageViewCurrentIndex => pageViewController != null &&
          pageViewController!.hasClients &&
          pageViewController!.page != null
      ? pageViewController!.page!.round()
      : 0;
  bool isDataUploading_uploadDataMtl = false;
  FFUploadedFile uploadedLocalFile_uploadDataMtl =
      FFUploadedFile(bytes: Uint8List.fromList([]));
  String uploadedFileUrl_uploadDataMtl = '';

  // State field(s) for Bio widget.
  FocusNode? bioFocusNode;
  TextEditingController? bioTextController;
  String? Function(BuildContext, String?)? bioTextControllerValidator;
  // State field(s) for PlacePicker widget.
  FFPlace placePickerValue = FFPlace();
  // State field(s) for eventUpdate widget.
  bool? eventUpdateValue;
  // State field(s) for newMessage widget.
  bool? newMessageValue;
  // State field(s) for ConnectionRequests widget.
  bool? connectionRequestsValue;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    bioFocusNode?.dispose();
    bioTextController?.dispose();
  }
}
