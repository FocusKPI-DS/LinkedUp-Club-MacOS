import 'dart:async';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/chat/chat_component/chat_thread_component/chat_thread_component_model.dart';
import 'package:flutter/material.dart';

/// Sidebar display mode: flat chat list vs folder-grouped view.
enum SidebarMode { chat, folders }

/// Main content tabs shown in the group chat header.
enum GroupChatTab {
  messages,
  filesAndLinks,
  actionTasks,
  announcements,
  pinnedMessages,
}

/// Set to true to show the Folders sidebar toggle in the chat header.
const bool kShowFoldersSidebar = false;

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
  // People selected in the combined New Message view. One selection creates a
  // direct message; more than one creates a group chat.
  List<DocumentReference> newMessageSelectedMembers = [];
  bool isCreatingNewMessageChat = false;

  // Chat History panel
  bool showChatHistoryPanel = false;

  // Announcements panel
  bool showAnnouncementsPanel = false;

  // Meeting Transcripts popup (from header 3-dots menu)
  bool showMeetingTranscriptsPopup = false;
  ChatsRecord? meetingTranscriptsPopupChat;

  // Pinned Messages popup (from header 3-dots menu)
  bool showPinnedMessagesPopup = false;
  ChatsRecord? pinnedMessagesPopupChat;

  // Group Files popup (from header 3-dots menu)
  bool showGroupFilesPopup = false;
  ChatsRecord? groupFilesPopupChat;

  // Active tab in the group chat header (Messages, Files and Links, etc.)
  GroupChatTab groupChatTab = GroupChatTab.messages;

  // Sidebar resize/collapse state
  double sidebarWidth = 320.0; // Default width
  bool isSidebarCollapsed = false;
  static const double minSidebarWidth = 240.0;
  static const double maxSidebarWidth = 500.0;
  static const double collapsedSidebarWidth = 60.0;
  // Group member search
  TextEditingController? groupMemberSearchController;

  // Chat Folders
  bool showFolderView = false;
  // Smart folder collapse states
  bool isPinnedCollapsed = false;
  bool isDMCollapsed = false;
  bool isGroupCollapsed = false;
  bool isRecentCollapsed = false;
  bool isInactiveCollapsed = true;
  bool isUnfiledCollapsed = false;
  // Search states
  bool showQuickSearch = false; // dropdown overlay on left
  bool showFullSearch = false;  // full search page on right
  ChatsRecord? searchPreviewChat;   // chat to preview in bottom half
  String? searchPreviewMessageId;   // message to scroll to in preview
  List<ChatFoldersRecord> chatFolders = [];
  StreamSubscription? chatFoldersSubscription;

  // Sidebar mode: flat chat list vs folder view
  SidebarMode sidebarMode = SidebarMode.chat;

  // "Enable group folders" toggle above the All/Unread tabs.
  // When true, the sidebar shows the folder-grouped view.
  bool groupFoldersEnabled = false;

  @override
  void initState(BuildContext context) {
    searchFocusNode = FocusNode();
    searchTextController = TextEditingController();
    groupNameController = TextEditingController();
    newMessageSearchController = TextEditingController();

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

    groupMemberSearchController?.dispose();
    tabController?.dispose();
    chatThreadComponentModel.dispose();
    chatFoldersSubscription?.cancel();
  }
}
