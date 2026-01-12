import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';

class MobileNewGroupChatModel extends FlutterFlowModel {
  ///  State fields for stateful widgets in this page.

  final unfocusNode = FocusNode();

  // Group creation
  String groupName = '';
  List<DocumentReference> selectedMembers = [];
  TextEditingController? groupNameController;

  // Group image upload
  String? groupImagePath;
  String? groupImageUrl;
  bool isUploadingImage = false;

  // Group member search
  TextEditingController? groupMemberSearchController;

  @override
  void initState(BuildContext context) {
    groupNameController = TextEditingController();
    groupMemberSearchController = TextEditingController();
  }

  @override
  void dispose() {
    unfocusNode.dispose();
    groupNameController?.dispose();
    groupMemberSearchController?.dispose();
  }
}







