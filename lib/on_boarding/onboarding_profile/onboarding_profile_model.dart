import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'onboarding_profile_widget.dart' show OnboardingProfileWidget;
import 'package:flutter/material.dart';

class OnboardingProfileModel extends FlutterFlowModel<OnboardingProfileWidget> {
  ///  Local state fields for this page.

  String? userProfile;
  String? coverPhoto;

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
  
  bool isDataUploading_coverPhoto = false;
  FFUploadedFile uploadedLocalFile_coverPhoto =
      FFUploadedFile(bytes: Uint8List.fromList([]));
  String uploadedFileUrl_coverPhoto = '';
  
  bool isCoverPhotoLoading = false;

  // State field(s) for Bio widget.
  FocusNode? bioFocusNode;
  TextEditingController? bioTextController;
  String? Function(BuildContext, String?)? bioTextControllerValidator;
  // State field(s) for PlacePicker widget.
  FFPlace placePickerValue = const FFPlace();
  // State field(s) for eventUpdate widget.
  bool? eventUpdateValue;
  // State field(s) for newMessage widget.
  bool? newMessageValue;
  // State field(s) for ConnectionRequests widget.
  bool? connectionRequestsValue;
  // State field(s) for Search widget.
  FocusNode? searchFocusNode;
  TextEditingController? searchTextController;
  String? Function(BuildContext, String?)? searchTextControllerValidator;
  // Track loading states for connection requests
  Set<String> loadingConnectionOperations = <String>{};

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    bioFocusNode?.dispose();
    bioTextController?.dispose();
    searchFocusNode?.dispose();
    searchTextController?.dispose();
  }
}
