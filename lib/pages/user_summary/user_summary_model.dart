import '/flutter_flow/flutter_flow_util.dart';
import 'user_summary_widget.dart' show UserSummaryWidget;
import 'package:flutter/material.dart';

class UserSummaryModel extends FlutterFlowModel<UserSummaryWidget> {
  ///  State fields for stateful widgets in this page.

  final unfocusNode = FocusNode();

  // Editing state
  bool _isEditing = false;
  bool get isEditing => _isEditing;
  set isEditing(bool value) => _isEditing = value;

  // Controllers for editing
  TextEditingController? displayNameController;
  TextEditingController? bioController;
  TextEditingController? locationController;
  TextEditingController? websiteController;
  TextEditingController? interestsController;

  @override
  void initState(BuildContext context) {
    displayNameController = TextEditingController();
    bioController = TextEditingController();
    locationController = TextEditingController();
    websiteController = TextEditingController();
    interestsController = TextEditingController();
  }

  @override
  void dispose() {
    unfocusNode.dispose();
    displayNameController?.dispose();
    bioController?.dispose();
    locationController?.dispose();
    websiteController?.dispose();
    interestsController?.dispose();
  }
}
