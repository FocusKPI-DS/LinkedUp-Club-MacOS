import '/flutter_flow/flutter_flow_util.dart';
import 'profile_settings_widget.dart' show ProfileSettingsWidget;
import 'package:flutter/material.dart';

class ProfileSettingsModel extends FlutterFlowModel<ProfileSettingsWidget> {
  ///  State field(s) for this page.

  final unfocusNode = FocusNode();

  /// Selected setting in the sidebar
  String _selectedSetting = 'Personal Information';
  String get selectedSetting => _selectedSetting;
  set selectedSetting(String value) => _selectedSetting = value;

  /// Search functionality for workspace members
  TextEditingController? searchController;
  String _searchQuery = '';
  String get searchQuery => _searchQuery;
  set searchQuery(String value) => _searchQuery = value;

  /// Personal Information editing
  bool _isEditingProfile = false;
  bool get isEditingProfile => _isEditingProfile;
  set isEditingProfile(bool value) => _isEditingProfile = value;

  TextEditingController? displayNameController;
  TextEditingController? emailController;
  TextEditingController? locationController;

  /// Workspace creation
  bool _isCreatingWorkspace = false;
  bool get isCreatingWorkspace => _isCreatingWorkspace;
  set isCreatingWorkspace(bool value) => _isCreatingWorkspace = value;

  TextEditingController? workspaceNameController;
  TextEditingController? workspaceDescriptionController;

  /// Workspace deletion
  bool _isDeletingWorkspace = false;
  bool get isDeletingWorkspace => _isDeletingWorkspace;
  set isDeletingWorkspace(bool value) => _isDeletingWorkspace = value;

  TextEditingController? deleteConfirmationController;

  /// Workspace joining
  bool _isJoiningWorkspace = false;
  bool get isJoiningWorkspace => _isJoiningWorkspace;
  set isJoiningWorkspace(bool value) => _isJoiningWorkspace = value;

  TextEditingController? inviteCodeController;

  @override
  void initState(BuildContext context) {
    searchController = TextEditingController();
    displayNameController = TextEditingController();
    emailController = TextEditingController();
    locationController = TextEditingController();
    workspaceNameController = TextEditingController();
    workspaceDescriptionController = TextEditingController();
    deleteConfirmationController = TextEditingController();
    inviteCodeController = TextEditingController();
  }

  @override
  void dispose() {
    unfocusNode.dispose();
    searchController?.dispose();
    displayNameController?.dispose();
    emailController?.dispose();
    locationController?.dispose();
    workspaceNameController?.dispose();
    workspaceDescriptionController?.dispose();
    deleteConfirmationController?.dispose();
    inviteCodeController?.dispose();
  }
}
