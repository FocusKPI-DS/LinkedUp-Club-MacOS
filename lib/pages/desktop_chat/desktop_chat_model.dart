import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/chat/chat_component/chat_thread_component/chat_thread_component_model.dart';
import 'package:flutter/material.dart';

class DesktopChatModel extends FlutterFlowModel {
  ///  State fields for stateful widgets in this page.

  final unfocusNode = FocusNode();

  // Search functionality
  FocusNode? searchFocusNode;
  TextEditingController? searchTextController;
  String? Function(BuildContext, String?)? searchTextControllerValidator;
  String searchQuery = '';
  bool isSearchVisible = true;

  // Selected chat item
  String selectedChatItem = 'all_chat';

  // Selected chat for conversation
  ChatsRecord? selectedChat;

  // Loading states
  bool isLoading = false;
  bool isGeneratingSummary = false;

  // Tab controller for chat types
  TabController? tabController;

  // Chat thread component model
  late ChatThreadComponentModel chatThreadComponentModel;

  // Inline workspace members view
  bool showWorkspaceMembers = false;

  // Inline group creation view
  bool showGroupCreation = false;
  String groupName = '';
  List<DocumentReference> selectedMembers = [];
  TextEditingController? groupNameController;

  // Group image upload
  String? groupImagePath;
  String? groupImageUrl;
  bool isUploadingImage = false;

  // Inline group info panel
  bool showGroupInfoPanel = false;
  ChatsRecord? groupInfoChat;

  // Action items stats expansion state
  bool isActionItemsExpanded = false;

  // Inline tasks panel
  bool showTasksPanel = false;

  // Inline user profile panel
  bool showUserProfilePanel = false;
  UsersRecord? userProfileUser;

  // New message view in right panel
  bool showNewMessageView = false;
  TextEditingController? newMessageSearchController;

  // Connections view in right panel
  bool showConnectionsView = false;
  bool showConnectionsSearch = false;
  TextEditingController? connectionsSearchController;
  String connectionsTab = 'connections'; // 'connections', 'requests', or 'sent'
  UsersRecord? selectedConnectionProfile; // Selected user profile in connections view

  // Group member search
  TextEditingController? groupMemberSearchController;

  @override
  void initState(BuildContext context) {
    searchFocusNode = FocusNode();
    searchTextController = TextEditingController();
    groupNameController = TextEditingController();
    newMessageSearchController = TextEditingController();
    connectionsSearchController = TextEditingController();
    groupMemberSearchController = TextEditingController();
    chatThreadComponentModel =
        createModel(context, () => ChatThreadComponentModel());
  }

  @override
  void dispose() {
    unfocusNode.dispose();
    searchFocusNode?.dispose();
    searchTextController?.dispose();
    groupNameController?.dispose();
    newMessageSearchController?.dispose();
    connectionsSearchController?.dispose();
    groupMemberSearchController?.dispose();
    tabController?.dispose();
    chatThreadComponentModel.dispose();
  }
}
