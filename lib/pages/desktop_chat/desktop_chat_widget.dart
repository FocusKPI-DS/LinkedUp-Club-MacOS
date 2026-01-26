import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/invite_friends_button_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/chat/chat_component/chat_thread_component/chat_thread_component_widget.dart';
import '/pages/desktop_chat/desktop_chat_model.dart';
import '/pages/desktop_chat/chat_controller.dart';
import '/pages/chat/user_profile_detail/user_profile_detail_widget.dart';
import '/pages/chat/group_chat_detail/group_chat_detail_widget.dart';
import '/pages/chat/group_action_tasks/group_action_tasks_widget.dart';
import '/pages/chat/add_group_members/add_group_members_widget.dart';
import '/pages/chat/group_chat_detail/group_media_links_docs_widget.dart';
import '/pages/chat/all_pending_requests/all_pending_requests_widget.dart';
import '/pages/chat/calling_screen/calling_screen_widget.dart';
import '/pages/user_summary/user_summary_widget.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/scheduler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:branchio_dynamic_linking_akp5u6/custom_code/actions/index.dart'
    as branchio_dynamic_linking_akp5u6_actions;
import 'package:branchio_dynamic_linking_akp5u6/flutter_flow/custom_functions.dart'
    as branchio_dynamic_linking_akp5u6_functions;
import '/custom_code/actions/index.dart' as actions;

class DesktopChatWidget extends StatefulWidget {
  const DesktopChatWidget({Key? key}) : super(key: key);

  @override
  _DesktopChatWidgetState createState() => _DesktopChatWidgetState();
}

class _DesktopChatWidgetState extends State<DesktopChatWidget>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late DesktopChatModel _model;
  late ChatController chatController;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final animationsMap = <String, AnimationInfo>{};

  // Track previous friends count for notifications
  int _previousFriendsCount = 0;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  // Subscription to chatController.selectedChat for syncing with model
  StreamSubscription<ChatsRecord?>? _selectedChatSubscription;

  // Presence system for online status (like Slack)
  Timer? _inactivityTimer;
  static const Duration _inactivityThreshold = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _model = createModel(context, () => DesktopChatModel());
    // Use Get.put with permanent: true to keep controller persistent across navigation
    // This preserves knownUnreadChats and locallySeenChats state
    chatController = Get.put(ChatController(), permanent: true);

    _model.tabController = TabController(
      vsync: this,
      length: 3, // All, Direct Message, Groups
      initialIndex: 0,
    )..addListener(() {
        safeSetState(() {});
        chatController.updateSelectedTab(_model.tabController?.index ?? 0);
      });

    animationsMap.addAll({
      'containerOnPageLoadAnimation1': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
        ],
      ),
    });

    // Listen to chatController.selectedChat changes and sync with model
    // This allows external code to select chats by calling chatController.selectChat()
    _selectedChatSubscription =
        chatController.selectedChat.listen((selectedChat) {
      if (mounted) {
        setState(() {
          if (selectedChat != null) {
            // Clear all panels and views
            _clearAllViews();
            _model.showGroupInfoPanel = false;
            _model.groupInfoChat = null;
            _model.showUserProfilePanel = false;
            _model.userProfileUser = null;
            _model.showTasksPanel = false;
            // Set the selected chat
            _model.selectedChat = selectedChat;
            print(
                'DesktopChat: Synced selectedChat to model: ${selectedChat.reference.id}');
          } else {
            _model.selectedChat = null;
          }
        });
      }
    });

    // Initialize presence system after a delay to ensure user is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 500), () {
        _initializePresence();
      });
    });
  }

  // Initialize presence system (like Slack)
  // Initialize presence system (like Slack)
  void _initializePresence() {
    if (currentUserReference == null) {
      return;
    }
    _updateOnlineStatus(true);
    _resetInactivityTimer();

    // Track user activity
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackActivity();
    });
  }

  // Track user activity and reset inactivity timer
  void _trackActivity() {
    _resetInactivityTimer();
    // Update to online if currently away
    if (currentUserReference != null) {
      UsersRecord.getDocumentOnce(currentUserReference!).then((user) {
        if (!user.isOnline) {
          _updateOnlineStatus(true);
        }
      });
    }
  }

  // Reset inactivity timer (10 minutes like Slack)
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityThreshold, () {
      // User is inactive, set to away
      _updateOnlineStatus(false);
    });
  }

  // Update online status in Firestore
  Future<void> _updateOnlineStatus(bool isOnline) async {
    if (currentUserReference == null) {
      return;
    }

    try {
      await currentUserReference!.update({
        'is_online': isOnline,
      });
    } catch (e) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        // App is active, set user to online
        _trackActivity();
        _updateOnlineStatus(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App is in background, set user to away
        _updateOnlineStatus(false);
        _inactivityTimer?.cancel();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    _selectedChatSubscription?.cancel();
    // Set user to offline when disposing
    _updateOnlineStatus(false);
    _model.dispose();
    // DON'T delete ChatController - keep it persistent across navigation
    // This preserves knownUnreadChats and locallySeenChats state
    // The controller will be cleaned up when app closes
    // Get.delete<ChatController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Track activity when widget is built (user is interacting)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackActivity();
    });

    return GestureDetector(
      onTap: _trackActivity,
      onPanStart: (_) => _trackActivity(),
      child: Scaffold(
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Left Sidebar
            _buildLeftSidebar(),
            // Right Panel - Placeholder
            _buildRightPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftSidebar() {
    // Use collapsed width or stored width
    final currentWidth = _model.isSidebarCollapsed
        ? DesktopChatModel.collapsedSidebarWidth
        : _model.sidebarWidth;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: currentWidth,
      height: double.infinity,
      child: Stack(
        children: [
          // Main sidebar content
          if (!_model.isSidebarCollapsed)
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Color.fromRGBO(250, 252, 255, 1),
                border: Border(
                  right: BorderSide(
                    color: Color.fromRGBO(230, 235, 245, 1),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  _buildHeader(),
                  _buildNavigationTabs(),
                  _buildSearchBar(),
                  _buildChatList(),
                ],
              ),
            ),
          // Drag handle for resizing (positioned on right edge)
          if (!_model.isSidebarCollapsed)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _model.sidebarWidth =
                          (_model.sidebarWidth + details.delta.dx).clamp(
                              DesktopChatModel.minSidebarWidth,
                              DesktopChatModel.maxSidebarWidth);
                    });
                  },
                  child: Container(
                    width: 6,
                    color: Colors.transparent,
                    child: Center(
                      child: Container(
                        width: 3,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Collapse button (positioned at bottom right of sidebar)
          if (!_model.isSidebarCollapsed)
            Positioned(
              right: 12,
              bottom: 12,
              child: Tooltip(
                message: 'Collapse sidebar',
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _model.isSidebarCollapsed = true;
                    });
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Color(0xFFE5E7EB), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: Color(0xFF64748B),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          // Expand button (shown when collapsed)
          if (_model.isSidebarCollapsed)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 24,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(250, 252, 255, 1),
                  border: Border(
                    right: BorderSide(
                      color: Color.fromRGBO(230, 235, 245, 1),
                      width: 1,
                    ),
                  ),
                ),
                child: Center(
                  child: Tooltip(
                    message: 'Expand sidebar',
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _model.isSidebarCollapsed = false;
                        });
                      },
                      child: Container(
                        width: 20,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border:
                              Border.all(color: Color(0xFFE5E7EB), width: 1),
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF64748B),
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        color: Color.fromRGBO(
            250, 252, 255, 1), // Very light cyan tint, close to white
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16, 20, 16, 20),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            // App Name
            Expanded(
              child: Text(
                'Chat',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF111827), // Dark text for light background
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8),
            // Action Icons - directly on background, no containers
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<int>(
                  offset: const Offset(0, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                  color: Colors.white,
                  elevation: 8,
                  tooltip: 'New Chat',
                  onSelected: (value) {
                    setState(() {
                      _clearAllViews();
                      if (value == 1) {
                        _model.showNewMessageView = true;
                        _model.selectedChat = null;
                        chatController.selectedChat.value = null;
                        _model.newMessageSearchController?.clear();
                      } else if (value == 2) {
                        _model.showGroupCreation = true;
                        _model.selectedChat = null;
                        chatController.selectedChat.value = null;
                        _model.groupName = '';
                        _model.selectedMembers = [];
                        _model.groupNameController?.clear();
                        _model.groupImagePath = null;
                        _model.groupImageUrl = null;
                        _model.isUploadingImage = false;
                      }
                    });
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<int>(
                      value: 1,
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.person_fill,
                              color: Color(0xFF3B82F6), size: 18),
                          SizedBox(width: 12),
                          Text(
                            'Direct Message',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuDivider(height: 1),
                    PopupMenuItem<int>(
                      value: 2,
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.group_solid,
                              color: Color(0xFF3B82F6), size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Group Chat',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.add_rounded,
                      color: Color(0xFF374151),
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: double.infinity,
      padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white, // White search bar on light background
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Color.fromRGBO(230, 235, 245, 1), // Light border
            width: 1,
          ),
        ),
        child: TextFormField(
          controller: _model.searchTextController,
          focusNode: _model.searchFocusNode,
          onChanged: (value) {
            EasyDebounce.debounce(
              'searchTextController',
              Duration(milliseconds: 500),
              () => chatController.updateSearchQuery(value),
            );
          },
          decoration: InputDecoration(
            hintText: 'Search chats...',
            hintStyle: TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFF9CA3AF),
              fontSize: 14,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
            prefixIcon: Icon(
              Icons.search,
              color: Color(0xFF6B7280), // Dark icon for light background
              size: 18,
            ),
            suffixIcon: Obx(() {
              return chatController.searchQuery.value.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _model.searchTextController?.clear();
                        chatController.updateSearchQuery('');
                      },
                      child: Icon(
                        Icons.close,
                        color:
                            Color(0xFF6B7280), // Dark icon for light background
                        size: 18,
                      ),
                    )
                  : SizedBox.shrink();
            }),
          ),
          style: TextStyle(
            fontFamily: 'Inter',
            color: Color(0xFF111827), // Dark text for light background
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationTabs() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: Color.fromRGBO(
            250, 252, 255, 1), // Very light cyan tint, close to white
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(child: _buildTab('All', 0)),
            SizedBox(width: 8),
            Expanded(child: _buildTab('DM', 1)),
            SizedBox(width: 8),
            Expanded(child: _buildTab('Groups', 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String text, int index) {
    final isSelected = _model.tabController?.index == index;
    return GestureDetector(
      onTap: () {
        _model.tabController?.animateTo(index);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.transparent, // White background for selected
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(
                  color: Color.fromRGBO(
                      230, 235, 245, 1), // Light border for selected
                  width: 1,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.05), // Neutral gray shadow
                    blurRadius: 4,
                    offset: Offset(0, 1),
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            color: Color(0xFF374151), // Grey for both selected and unselected
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return Expanded(
      child: Obx(() {
        switch (chatController.chatState.value) {
          case ChatState.loading:
            return Center(
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 16, 184, 239), // Cyan color
              ),
            );

          case ChatState.error:
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Color(0xFFEF4444),
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Error loading chats',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF6B7280),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    chatController.errorMessage.value,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => chatController.refreshChats(),
                    child: Text('Retry'),
                  ),
                ],
              ),
            );

          case ChatState.success:
            final filteredChats = chatController.filteredChats;

            if (filteredChats.isEmpty &&
                chatController.searchQuery.value.isNotEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off,
                      color: Color(0xFF9CA3AF),
                      size: 48,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No search results',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF6B7280),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Try a different search term',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              key: ValueKey(
                  'chat_list_${filteredChats.length}_${chatController.searchQuery.value}'),
              padding: EdgeInsets.zero,
              scrollDirection: Axis.vertical,
              itemCount: filteredChats.length,
              itemBuilder: (context, index) {
                final chat = filteredChats[index];
                final isSelected =
                    chatController.selectedChat.value?.reference ==
                        chat.reference;

                return Obx(() {
                  // Make hasUnreadMessages reactive by accessing observables
                  // CRITICAL: Access selectedChat to ensure updates when chat is opened/closed
                  final _ = chatController.chats.length;
                  final __ = chatController.locallySeenChats.length;
                  final ___ = chatController.knownUnreadChats.length;
                  final ____ = chatController.selectedChat.value?.reference
                      .id; // Access selectedChat for reactivity
                  final hasUnread = chatController.hasUnreadMessages(chat);

                  return _ChatListItem(
                    key: ValueKey('chat_item_${chat.reference.id}'),
                    chat: chat,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        _clearAllViews();
                        _model.selectedChat = chat;
                      });
                      chatController.selectChat(chat);
                    },
                    hasUnreadMessages: hasUnread,
                    chatController: chatController,
                    onPin: _handlePinChat,
                    onDelete: _handleDeleteChat,
                    onMute: _handleMuteNotifications,
                  );
                });
              },
            );
        }
      }),
    );
  }

  Future<UsersRecord> _getOtherUser(ChatsRecord chat) async {
    final otherUserRef = chat.members.firstWhere(
      (member) => member != currentUserReference,
      orElse: () => chat.members.first,
    );
    return await UsersRecord.getDocumentOnce(otherUserRef);
  }

  Widget _buildGroupCreationViewRight() {
    return Column(
      children: [
        // Header for group creation
        Container(
          width: double.infinity,
          padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: Color.fromRGBO(250, 252, 255, 1), // Match left sidebar color
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Create New Group',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF1F2937),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _model.showGroupCreation = false;
                    _model.groupName = '';
                    _model.selectedMembers = [];
                    _model.groupNameController?.clear();
                    _model.groupImagePath = null;
                    _model.groupImageUrl = null;
                    _model.isUploadingImage = false;
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.close,
                    color: Color(0xFF6B7280),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Group creation form
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(32),
            child: Container(
              constraints: BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group name input
                  Text(
                    'Group Name (Optional)',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF374151),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Color(0xFFD1D5DB),
                        width: 1,
                      ),
                    ),
                    child: TextFormField(
                      controller: _model.groupNameController,
                      onChanged: (value) {
                        setState(() {
                          _model.groupName = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Enter group name',
                        hintStyle: TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
                      ),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF1F2937),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  // Group image upload
                  Text(
                    'Group Image (Optional)',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF374151),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      // Image preview/placeholder
                      GestureDetector(
                        onTap: _model.isUploadingImage ? null : _pickGroupImage,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Color(0xFFD1D5DB),
                              width: 2,
                            ),
                          ),
                          child: _model.isUploadingImage
                              ? Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF3B82F6),
                                    strokeWidth: 2,
                                  ),
                                )
                              : _model.groupImageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: _model.groupImageUrl!,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                          width: 100,
                                          height: 100,
                                          color: Color(0xFFF9FAFB),
                                          child: Icon(
                                            Icons.image,
                                            color: Color(0xFF9CA3AF),
                                            size: 32,
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                          width: 100,
                                          height: 100,
                                          color: Color(0xFFF9FAFB),
                                          child: Icon(
                                            Icons.image,
                                            color: Color(0xFF9CA3AF),
                                            size: 32,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate,
                                          color: Color(0xFF9CA3AF),
                                          size: 32,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Add Image',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            color: Color(0xFF6B7280),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                        ),
                      ),
                      SizedBox(width: 16),
                      // Image controls
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _model.groupImageUrl != null
                                  ? 'Image selected'
                                  : 'No image selected',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: _model.groupImageUrl != null
                                    ? Color(0xFF10B981)
                                    : Color(0xFF6B7280),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _model.isUploadingImage
                                      ? null
                                      : _pickGroupImage,
                                  icon: Icon(
                                    _model.groupImageUrl != null
                                        ? Icons.change_circle
                                        : Icons.upload,
                                    size: 16,
                                  ),
                                  label: Text(
                                    _model.groupImageUrl != null
                                        ? 'Change'
                                        : 'Select',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _model.isUploadingImage
                                        ? Color(0xFF9CA3AF)
                                        : Color(0xFF3B82F6),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                                if (_model.groupImageUrl != null) ...[
                                  SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _model.groupImagePath = null;
                                        _model.groupImageUrl = null;
                                      });
                                    },
                                    icon: Icon(Icons.delete, size: 16),
                                    label: Text(
                                      'Remove',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFFEF4444),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  // Selected members header with search
                  Row(
                    children: [
                      Text(
                        'Selected Members (${_model.selectedMembers.length})',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFF374151),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Spacer(),
                      Container(
                        width: 250,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Color(0xFFD9D9D9),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _model.groupMemberSearchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search by name or email...',
                            hintStyle: TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFF808080),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Color(0xFF4285F4),
                              size: 20,
                            ),
                            suffixIcon: _model.groupMemberSearchController?.text
                                        .isNotEmpty ==
                                    true
                                ? GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _model.groupMemberSearchController
                                            ?.clear();
                                      });
                                    },
                                    child: Icon(
                                      Icons.clear,
                                      color: Color(0xFF9CA3AF),
                                      size: 20,
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0xFF1F2937),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Connections list for selection
                  Container(
                    height: 350,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: StreamBuilder<UsersRecord>(
                      stream: UsersRecord.getDocument(currentUserReference!),
                      builder: (context, currentUserSnapshot) {
                        if (!currentUserSnapshot.hasData) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF3B82F6),
                            ),
                          );
                        }

                        final currentUser = currentUserSnapshot.data!;
                        final connections = currentUser.friends;

                        if (connections.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  color: Color(0xFF9CA3AF),
                                  size: 48,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No connections',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Color(0xFF6B7280),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Add connections to create a group',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final searchQuery = _model
                                .groupMemberSearchController?.text
                                .toLowerCase() ??
                            '';

                        return ListView.builder(
                          padding: EdgeInsets.all(12),
                          itemCount: connections.length,
                          itemBuilder: (context, index) {
                            final connectionRef = connections[index];

                            return StreamBuilder<UsersRecord>(
                              stream: UsersRecord.getDocument(connectionRef),
                              builder: (context, userSnapshot) {
                                if (!userSnapshot.hasData) {
                                  return SizedBox.shrink();
                                }

                                final user = userSnapshot.data!;
                                final isCurrentUser =
                                    user.reference == currentUserReference;
                                final isSelected = _model.selectedMembers
                                    .contains(user.reference);

                                if (isCurrentUser) {
                                  return SizedBox.shrink();
                                }

                                // Check if search query matches
                                if (searchQuery.isNotEmpty) {
                                  final displayName =
                                      user.displayName.toLowerCase();
                                  final email = user.email.toLowerCase();
                                  if (!displayName.contains(searchQuery) &&
                                      !email.contains(searchQuery)) {
                                    return SizedBox.shrink();
                                  }
                                }

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _model.selectedMembers
                                            .remove(user.reference);
                                      } else {
                                        _model.selectedMembers
                                            .add(user.reference);
                                      }
                                    });
                                  },
                                  child: Container(
                                    margin: EdgeInsets.only(bottom: 8),
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Color(0xFFEBF5FF)
                                          : Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? Color(0xFF3B82F6)
                                            : Color(0xFFE5E7EB),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Color(0xFF3B82F6),
                                                shape: BoxShape.circle,
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                child: CachedNetworkImage(
                                                  imageUrl: user.photoUrl,
                                                  width: 40,
                                                  height: 40,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.person,
                                                      color: Color(0xFF6B7280),
                                                      size: 20,
                                                    ),
                                                  ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.person,
                                                      color: Color(0xFF6B7280),
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Green dot indicator for online status
                                            if (user.isOnline)
                                              Positioned(
                                                right: 0,
                                                bottom: 0,
                                                child: Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: BoxDecoration(
                                                    color: Color(
                                                        0xFF10B981), // Green color
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.displayName,
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  color: Color(0xFF1F2937),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                user.email,
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  color: Color(0xFF6B7280),
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Container(
                                            padding: EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Color(0xFF3B82F6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 32),
                  // Create group button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _model.selectedMembers.isNotEmpty
                          ? () => _createGroup()
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _model.selectedMembers.isNotEmpty
                            ? Color(0xFF3B82F6)
                            : Color(0xFF9CA3AF),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Create Group',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _clearAllViews() {
    _model.showNewMessageView = false;
    _model.showGroupCreation = false;
  }

  Future<void> _startNewChatWithUser(UsersRecord user) async {
    try {
      // Check if a chat already exists between current user and this user
      final existingChats = await queryChatsRecordOnce(
        queryBuilder: (chatsRecord) => chatsRecord
            .where('members', arrayContains: currentUserReference)
            .where('is_group', isEqualTo: false),
      );

      // Find if there's already a direct chat with this user
      ChatsRecord? existingChat;
      for (final chat in existingChats) {
        if (chat.members.contains(user.reference) &&
            chat.members.length == 2 &&
            !chat.isGroup) {
          existingChat = chat;
          break;
        }
      }

      if (existingChat != null) {
        // Chat already exists, select it
        setState(() {
          _clearAllViews();
          _model.selectedChat = existingChat;
        });
        chatController.selectChat(existingChat);
      } else {
        // Create a new chat
        final newChatRef = await ChatsRecord.collection.add({
          ...createChatsRecordData(
            isGroup: false,
            title: '', // Empty for direct chats
            createdAt: getCurrentTimestamp,
            lastMessageAt: getCurrentTimestamp,
            lastMessage: '',
            lastMessageSent: currentUserReference,
          ),
          'members': [
            currentUserReference ??
                FirebaseFirestore.instance
                    .collection('users')
                    .doc('placeholder'),
            user.reference
          ],
          'last_message_seen': [
            currentUserReference ??
                FirebaseFirestore.instance
                    .collection('users')
                    .doc('placeholder')
          ],
        });

        // Get the created chat document
        final newChat = await ChatsRecord.getDocumentOnce(newChatRef);

        // Select the new chat
        setState(() {
          _clearAllViews();
          _model.selectedChat = newChat;
        });
        chatController.selectChat(newChat);
      }
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting chat: $e'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _pickGroupImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _model.groupImagePath = image.path;
          _model.isUploadingImage = true;
        });

        // Upload image to Firebase Storage (pass XFile for web compatibility)
        await _uploadGroupImage(image);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _uploadGroupImage(XFile imageFile) async {
    try {
      final fileName =
          'group_images/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Check if user is authenticated
      if (currentUserReference == null) {
        throw Exception('User not authenticated');
      }

      // Upload to Firebase Storage
      // Use bytes for web compatibility, File for native platforms
      final UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        uploadTask = FirebaseStorage.instance.ref(fileName).putData(bytes);
      } else {
        final file = File(imageFile.path);
        uploadTask = FirebaseStorage.instance.ref(fileName).putFile(file);
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _model.groupImageUrl = downloadUrl;
        _model.isUploadingImage = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image uploaded successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      setState(() {
        _model.isUploadingImage = false;
      });

      String errorMessage = 'Error uploading image: $e';
      if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please check your authentication.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _createGroup() async {
    try {
      if (_model.selectedMembers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select at least one member'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }

      // Add current user to members list
      final allMembers = [
        currentUserReference ??
            FirebaseFirestore.instance.collection('users').doc('placeholder'),
        ..._model.selectedMembers
      ];

      // Auto-generate group name from member names if not provided
      String groupName = _model.groupName.trim();
      if (groupName.isEmpty) {
        // Fetch all member names
        final List<String> memberNames = [];

        // Get current user name
        if (currentUserReference != null) {
          try {
            final currentUser =
                await UsersRecord.getDocumentOnce(currentUserReference!);
            memberNames.add(currentUser.displayName.isNotEmpty
                ? currentUser.displayName
                : currentUser.email.split('@')[0]);
          } catch (e) {
            memberNames.add('You');
          }
        }

        // Get selected member names
        for (final memberRef in _model.selectedMembers) {
          try {
            final user = await UsersRecord.getDocumentOnce(memberRef);
            memberNames.add(user.displayName.isNotEmpty
                ? user.displayName
                : user.email.split('@')[0]);
          } catch (e) {
            // Skip if we can't fetch the user
          }
        }

        // Join names with comma and space (like Slack)
        groupName = memberNames.join(', ');
      }

      // Create the group chat
      final newChatRef = await ChatsRecord.collection.add({
        ...createChatsRecordData(
          title: groupName,
          isGroup: true,
          createdAt: getCurrentTimestamp,
          createdBy: currentUserReference,
          lastMessageAt: getCurrentTimestamp,
          lastMessage: '',
          lastMessageSent: currentUserReference,
          chatImageUrl: _model.groupImageUrl ?? '',
          admin: currentUserReference,
        ),
        'members': allMembers,
        'last_message_seen': [
          currentUserReference ??
              FirebaseFirestore.instance.collection('users').doc('placeholder')
        ],
      });

      // Send greeting message so the chat appears in the list
      final greeting =
          '${currentUserDisplayName.isNotEmpty ? currentUserDisplayName : "You"} created the group';

      await newChatRef.collection('messages').add({
        'content': greeting,
        'created_at': getCurrentTimestamp,
        'sender_ref': currentUserReference,
        'is_system_message': true,
        'is_read_by': [currentUserReference],
      });

      // Update chat with last message
      await newChatRef.update({
        'last_message': greeting,
        'last_message_at': getCurrentTimestamp,
        'last_message_sent': currentUserReference,
      });

      // Get the created chat document
      final newChat = await ChatsRecord.getDocumentOnce(newChatRef);

      // Select the new group chat
      setState(() {
        _clearAllViews();
        _model.selectedChat = newChat;
        _model.groupName = '';
        _model.selectedMembers = [];
        _model.groupNameController?.clear();
        _model.groupImagePath = null;
        _model.groupImageUrl = null;
        _model.isUploadingImage = false;
      });
      chatController.selectChat(newChat);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Group "$groupName" created successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating group: $e'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  Widget _buildNewMessageView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Color(0xFFF0F4FF),
            Color(0xFFE8F0FE),
          ],
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsetsDirectional.fromSTEB(32, 32, 32, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.topRight,
                colors: [
                  Colors.white,
                  Color(0xFFF8FAFF),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _model.showNewMessageView = false;
                          _model.newMessageSearchController?.clear();
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.close,
                          color: Color(0xFF6B7280),
                          size: 20,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline,
                        color: Color(0xFF3B82F6),
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start a New Direct Message',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFF1A1F36),
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Search for a colleague to begin a private conversation',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Search bar
          Container(
            width: double.infinity,
            padding: EdgeInsetsDirectional.fromSTEB(32, 20, 32, 16),
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color(0xFFE2E8F0),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF3B82F6).withOpacity(0.08),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TextFormField(
                controller: _model.newMessageSearchController,
                onChanged: (value) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Search by name or email',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
                  prefixIcon: Padding(
                    padding: EdgeInsetsDirectional.only(start: 14, end: 10),
                    child: Icon(
                      Icons.search_rounded,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF1A1F36),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Invite friends buttons
          Container(
            width: double.infinity,
            padding: EdgeInsetsDirectional.fromSTEB(32, 12, 32, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InviteFriendsButtonWidget(),
                SizedBox(width: 16),
                _buildEmailInviteButton(),
              ],
            ),
          ),
          // Suggested connections list
          Expanded(
            child: Container(
              width: double.infinity,
              padding: EdgeInsetsDirectional.fromSTEB(32, 8, 32, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.only(start: 4, bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'SUGGESTED',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0xFF475569),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<UsersRecord>(
                      stream: UsersRecord.getDocument(currentUserReference!),
                      builder: (context, currentUserSnapshot) {
                        if (!currentUserSnapshot.hasData) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: Color.fromARGB(255, 16, 184, 239),
                            ),
                          );
                        }

                        final currentUser = currentUserSnapshot.data!;
                        final connections = currentUser.friends;

                        if (connections.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Color(0xFF3B82F6).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.people_outline_rounded,
                                    color: Color(0xFF3B82F6),
                                    size: 40,
                                  ),
                                ),
                                SizedBox(height: 24),
                                Text(
                                  'No connections',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Color(0xFF1A1F36),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Add connections to start chatting',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Color(0xFF64748B),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final searchQuery = _model
                                .newMessageSearchController?.text
                                .toLowerCase() ??
                            '';

                        return ListView.builder(
                          itemCount: connections.length,
                          itemBuilder: (context, index) {
                            final connectionRef = connections[index];

                            return StreamBuilder<UsersRecord>(
                              stream: UsersRecord.getDocument(connectionRef),
                              builder: (context, userSnapshot) {
                                if (!userSnapshot.hasData) {
                                  return SizedBox.shrink();
                                }

                                final user = userSnapshot.data!;
                                final isCurrentUser =
                                    user.reference == currentUserReference;

                                if (isCurrentUser) {
                                  return SizedBox.shrink();
                                }

                                // Filter by search query
                                if (searchQuery.isNotEmpty) {
                                  final displayName =
                                      user.displayName.toLowerCase();
                                  final email = user.email.toLowerCase();
                                  if (!displayName.contains(searchQuery) &&
                                      !email.contains(searchQuery)) {
                                    return SizedBox.shrink();
                                  }
                                }

                                return Container(
                                  margin: EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Color(0xFFE2E8F0),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x0A000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () async {
                                        await _startNewChatWithUser(user);
                                        setState(() {
                                          _model.showNewMessageView = false;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            16, 12, 16, 12),
                                        child: Row(
                                          children: [
                                            // Avatar with gradient border
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Color(0xFF3B82F6),
                                                    Color(0xFF60A5FA),
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Color(0xFF3B82F6)
                                                        .withOpacity(0.3),
                                                    blurRadius: 8,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              padding: EdgeInsets.all(2),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.white,
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(22),
                                                  child: CachedNetworkImage(
                                                    imageUrl: user.photoUrl,
                                                    width: 44,
                                                    height: 44,
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (context, url) =>
                                                            Container(
                                                      width: 44,
                                                      height: 44,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Color(0xFFF1F5F9),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.person_rounded,
                                                        color:
                                                            Color(0xFF64748B),
                                                        size: 20,
                                                      ),
                                                    ),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            Container(
                                                      width: 44,
                                                      height: 44,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Color(0xFFF1F5F9),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.person_rounded,
                                                        color:
                                                            Color(0xFF64748B),
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            // User info
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    user.displayName,
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      color: Color(0xFF111827),
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    user.email,
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      color: Color(0xFF6B7280),
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Start Chat button
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: Color(0xFF3B82F6)
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.arrow_forward_rounded,
                                                color: Color(0xFF3B82F6),
                                                size: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel() {
    // Determine if any right-side panel should be shown
    final showAnyPanel = _model.showGroupCreation ||
        _model.showNewMessageView ||
        (_model.showGroupInfoPanel && _model.groupInfoChat != null) ||
        (_model.showUserProfilePanel && _model.userProfileUser != null);

    return Expanded(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Color.fromRGBO(250, 252, 255, 1), // Match left sidebar color
        ),
        child: Stack(
          children: [
            // Always show default chat view at the bottom of the stack
            _buildDefaultChatView(),

            if (showAnyPanel) ...[
              // Semi-transparent overlay background
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _model.showGroupCreation = false;
                      _model.showNewMessageView = false;
                      _model.showGroupInfoPanel = false;
                      _model.groupInfoChat = null;
                      _model.showUserProfilePanel = false;
                      _model.userProfileUser = null;
                    });
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                  ),
                ),
              ),
              // Right-side panels
              if (_model.showGroupCreation)
                _buildRightSidePanel(_buildGroupCreationViewRight(), () {
                  setState(() {
                    _model.showGroupCreation = false;
                    _model.groupName = '';
                    _model.selectedMembers = [];
                    _model.groupNameController?.clear();
                    _model.groupImagePath = null;
                    _model.groupImageUrl = null;
                    _model.isUploadingImage = false;
                  });
                }),
              if (_model.showNewMessageView)
                _buildRightSidePanel(_buildNewMessageView(), () {
                  setState(() {
                    _model.showNewMessageView = false;
                    _model.newMessageSearchController?.clear();
                  });
                }),

              if (_model.showGroupInfoPanel && _model.groupInfoChat != null)
                _buildRightSidePanel(
                  GroupChatDetailWidget(
                    chatDoc: _model.groupInfoChat,
                    onClose: () {
                      setState(() {
                        _model.showGroupInfoPanel = false;
                        _model.groupInfoChat = null;
                      });
                    },
                  ),
                  () {
                    setState(() {
                      _model.showGroupInfoPanel = false;
                      _model.groupInfoChat = null;
                    });
                  },
                ),
              if (_model.showUserProfilePanel && _model.userProfileUser != null)
                _buildRightSidePanel(
                  UserProfileDetailWidget(
                    user: _model.userProfileUser,
                    onClose: () {
                      setState(() {
                        _model.showUserProfilePanel = false;
                        _model.userProfileUser = null;
                      });
                    },
                  ),
                  () {
                    setState(() {
                      _model.showUserProfilePanel = false;
                      _model.userProfileUser = null;
                    });
                  },
                  width: 0.3,
                  maxWidth: 400,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultChatView() {
    return _model.selectedChat != null
        ? Column(
            children: [
              // Top panel with user info
              _buildChatHeader(),
              // Action Items Stats Section (only for group chats)
              if (_model.selectedChat!.isGroup)
                _buildActionItemsStats(_model.selectedChat!),
              // Tasks panel or Chat thread component
              Expanded(
                child: _model.showTasksPanel && _model.selectedChat!.isGroup
                    ? Stack(
                        children: [
                          // Show chat thread behind
                          ChatThreadComponentWidget(
                            chatReference: _model.selectedChat,
                          ),
                          // Semi-transparent overlay background
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _model.showTasksPanel = false;
                                });
                              },
                              child: Container(
                                color: Colors.black.withOpacity(0.3),
                              ),
                            ),
                          ),
                          // Tasks panel on the right (30% width)
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.4,
                              constraints: BoxConstraints(
                                minWidth: 300,
                                maxWidth: 500,
                              ),
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: Offset(-2, 0),
                                  ),
                                ],
                              ),
                              child: GroupActionTasksWidget(
                                chatDoc: _model.selectedChat,
                                onClose: () {
                                  setState(() {
                                    _model.showTasksPanel = false;
                                  });
                                },
                              ),
                            ).animate().slideX(
                                  begin: 1.0,
                                  end: 0.0,
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                ),
                          ),
                        ],
                      )
                    : ChatThreadComponentWidget(
                        chatReference: _model.selectedChat,
                      ),
              ),
            ],
          )
        : Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: Color(0xFF9CA3AF),
                  size: 64,
                ),
                SizedBox(height: 16),
                Text(
                  'Select a chat to start messaging',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF6B7280),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildRightSidePanel(Widget content, VoidCallback onClose,
      {double width = 0.4, double maxWidth = 500}) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: Container(
        width: MediaQuery.of(context).size.width * width,
        constraints: BoxConstraints(
          minWidth: 300,
          maxWidth: maxWidth,
        ),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: Offset(-2, 0),
            ),
          ],
        ),
        child: content,
      ).animate().slideX(
            begin: 1.0,
            end: 0.0,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          ),
    );
  }

  Widget _buildChatHeader() {
    final chat = _model.selectedChat!;

    return Container(
      width: double.infinity,
      padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Color.fromRGBO(250, 252, 255, 1), // Match left sidebar color
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // User avatar
          _buildHeaderAvatar(chat),
          SizedBox(width: 12),
          // User info
          Expanded(
            child: _buildHeaderName(chat),
          ),
          // Google Meet icon
          Tooltip(
            message: 'Start a Google Meet',
            child: InkWell(
              onTap: () async {
                // Open Google Meet
                final meetUrl = 'https://meet.google.com/new';
                final uri = Uri.parse(meetUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0, 0, 12, 0),
                child: Image.asset(
                  'assets/images/gmeet.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // Audio/Video call icons removed for macOS (Zego not supported)
          // Call icons will show on iOS, Android, and Web builds
          // More options button - dropdown menu for group chats
          chat.isGroup
              ? PopupMenuButton<String>(
                  onSelected: (String value) {
                    if (value == 'add_members') {
                      _navigateToAddMembers(chat);
                    } else if (value == 'media') {
                      _navigateToMedia(chat);
                    } else if (value == 'tasks') {
                      _navigateToTasks(chat);
                    } else if (value == 'group_info') {
                      _viewGroupChat(chat);
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    // Group chat options
                    return <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'add_members',
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_add,
                              color: Color(0xFF374151),
                              size: 18,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Add Members',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFF111827),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'media',
                        child: Row(
                          children: [
                            Icon(
                              Icons.photo_library,
                              color: Color(0xFF374151),
                              size: 18,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Media',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFF111827),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'tasks',
                        child: Row(
                          children: [
                            Icon(
                              Icons.checklist,
                              color: Color(0xFF374151),
                              size: 18,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Tasks',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFF111827),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'group_info',
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF374151),
                              size: 18,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Group Info',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFF111827),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
                  icon: Icon(
                    Icons.more_vert,
                    color: Color(0xFF9CA3AF),
                    size: 20,
                  ),
                  tooltip: 'More options',
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  color: Colors.white,
                  elevation: 8,
                )
              : PopupMenuButton<String>(
                  onSelected: (String value) {
                    if (value == 'profile') {
                      _viewUserProfile(chat);
                    } else if (value == 'block') {
                      _blockUser(chat);
                    } else if (value == 'group') {
                      _viewGroupChat(chat);
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    // Direct chat options
                    return <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: Color(0xFF374151),
                              size: 18,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'View User Profile',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFF111827),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(
                              Icons.block,
                              color: Color(0xFFDC2626),
                              size: 18,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Block User',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFFDC2626),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
                  icon: Icon(
                    Icons.more_vert,
                    color: Color(0xFF9CA3AF),
                    size: 20,
                  ),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildActionItemsStats(ChatsRecord chat) {
    return StreamBuilder<List<ActionItemsRecord>>(
      stream: queryActionItemsRecord(
        queryBuilder: (actionItemsRecord) => actionItemsRecord.where(
          'chat_ref',
          isEqualTo: chat.reference,
        ),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox.shrink();
        }

        final allActionItems = snapshot.data ?? [];

        // Filter out completed tasks (same logic as GroupActionTasksWidget)
        // Deduplicate tasks by title - same logic as the Group Action Tasks page
        final Map<String, ActionItemsRecord> uniqueTodos = {};
        for (var todo in allActionItems) {
          // Exclude completed tasks - must match exactly like the GroupActionTasksWidget
          if (todo.status == 'completed') {
            continue;
          }
          // Deduplicate by title - show only one task per unique title
          if (!uniqueTodos.containsKey(todo.title)) {
            uniqueTodos[todo.title] = todo;
          }
        }
        final pendingItems = uniqueTodos.values.toList();

        final highPriority = pendingItems
            .where((item) => item.priority.toLowerCase() == 'high')
            .length;
        final moderatePriority = pendingItems
            .where((item) => item.priority.toLowerCase() == 'moderate')
            .length;
        final lowPriority = pendingItems
            .where((item) => item.priority.toLowerCase() == 'low')
            .length;

        if (pendingItems.isEmpty) {
          return SizedBox.shrink();
        }

        return Container(
          padding: EdgeInsetsDirectional.fromSTEB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Action Items',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFF111827),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _model.isActionItemsExpanded =
                                !_model.isActionItemsExpanded;
                          });
                        },
                        child: Icon(
                          _model.isActionItemsExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 20,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${pendingItems.length} pending',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (_model.isActionItemsExpanded) ...[
                SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (highPriority > 0)
                      Container(
                        padding: EdgeInsetsDirectional.fromSTEB(10, 6, 10, 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flag,
                              size: 13,
                              color: const Color(0xFFDC2626),
                            ),
                            SizedBox(width: 5),
                            Text(
                              '$highPriority High',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (moderatePriority > 0)
                      Container(
                        padding: EdgeInsetsDirectional.fromSTEB(10, 6, 10, 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flag,
                              size: 13,
                              color: const Color(0xFFD97706),
                            ),
                            SizedBox(width: 5),
                            Text(
                              '$moderatePriority Moderate',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (lowPriority > 0)
                      Container(
                        padding: EdgeInsetsDirectional.fromSTEB(10, 6, 10, 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flag,
                              size: 13,
                              color: const Color(0xFF4F46E5),
                            ),
                            SizedBox(width: 5),
                            Text(
                              '$lowPriority Low',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderAvatar(ChatsRecord chat) {
    if (chat.isGroup) {
      // For group chats, show the group logo
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: CachedNetworkImage(
            imageUrl: chat.chatImageUrl,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            memCacheWidth: 80,
            memCacheHeight: 80,
            maxWidthDiskCache: 80,
            maxHeightDiskCache: 80,
            filterQuality: FilterQuality.high,
            placeholder: (context, url) => Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group,
                color: Color(0xFF6B7280),
                size: 18,
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group,
                color: Color(0xFF6B7280),
                size: 18,
              ),
            ),
          ),
        ),
      );
    } else {
      // For direct chats, get the other user's profile picture
      final otherUserRef = chat.members.firstWhere(
        (member) => member != currentUserReference,
        orElse: () => chat.members.first,
      );

      return StreamBuilder<UsersRecord>(
        stream: UsersRecord.getDocument(otherUserRef),
        builder: (context, userSnapshot) {
          String imageUrl = '';
          bool isOnline = false;

          // Check if this is Summer first, regardless of userSnapshot
          if (otherUserRef.path.contains('ai_agent_summerai')) {
            imageUrl =
                'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120';
          } else if (userSnapshot.hasData && userSnapshot.data != null) {
            imageUrl = userSnapshot.data?.photoUrl ?? '';
            isOnline = userSnapshot.data?.isOnline ?? false;
          }

          return InkWell(
            onTap: () {
              if (!otherUserRef.path.contains('ai_agent_summerai')) {
                context.pushNamed(
                  'UserSummary',
                  queryParameters: {
                    'userRef': serializeParam(
                        otherUserRef, ParamType.DocumentReference),
                  }.withoutNulls,
                  extra: <String, dynamic>{
                    'userRef': otherUserRef,
                  },
                );
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(0xFF3B82F6),
                    shape: BoxShape.circle,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      memCacheWidth: 80,
                      memCacheHeight: 80,
                      maxWidthDiskCache: 80,
                      maxHeightDiskCache: 80,
                      filterQuality: FilterQuality.high,
                      placeholder: (context, url) => Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          color: Color(0xFF6B7280),
                          size: 18,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          color: Color(0xFF6B7280),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                // Green dot indicator for online status
                if (isOnline &&
                    !otherUserRef.path.contains('ai_agent_summerai'))
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Color(0xFF10B981), // Green color
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF10B981).withOpacity(0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }
  }

  Widget _buildHeaderName(ChatsRecord chat) {
    if (chat.isGroup) {
      return Text(
        chat.title.isNotEmpty ? chat.title : 'Group Chat',
        style: TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFF1F2937),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      // For direct chats, get the other user's name
      final otherUserRef = chat.members.firstWhere(
        (member) => member != currentUserReference,
        orElse: () => chat.members.first,
      );

      return FutureBuilder<UsersRecord>(
        future: UsersRecord.getDocumentOnce(otherUserRef),
        builder: (context, userSnapshot) {
          String displayName = 'Direct Chat';
          print('DEBUG: otherUserRef.path = ${otherUserRef.path}');

          // Check if this is Summer first, regardless of userSnapshot
          if (otherUserRef.path.contains('ai_agent_summerai')) {
            displayName = 'Summer';
            print('DEBUG: Found Summer user, setting displayName to Summer');
          } else if (userSnapshot.hasData && userSnapshot.data != null) {
            final user = userSnapshot.data!;
            displayName =
                user.displayName.isNotEmpty ? user.displayName : 'Unknown User';
            print('DEBUG: Regular user: ${user.displayName}');
          }

          return Text(
            displayName,
            style: TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFF1F2937),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      );
    }
  }

  // Generate daily summary using Summer
  Future<void> _generateDailySummary(ChatsRecord chat) async {
    if (!chat.isGroup) return;

    setState(() {
      _model.isGeneratingSummary = true;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('dailySummary');

      await callable.call({
        'chatId': chat.reference.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Summer has sent you a personal summary!',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error generating summary: $e');

      String errorMessage = 'Failed to generate summary. Please try again.';

      // Extract more specific error message if available
      if (e.toString().contains('No messages found')) {
        errorMessage = 'No messages found in the last 24 hours to summarize.';
      } else if (e.toString().contains('permission-denied')) {
        errorMessage =
            'You don\'t have permission to generate a summary for this chat.';
      } else if (e.toString().contains('unauthenticated')) {
        errorMessage = 'Please sign in to generate a summary.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _model.isGeneratingSummary = false;
        });
      }
    }
  }

  void _viewUserProfile(ChatsRecord chat) async {
    if (chat.isGroup) {
      // For group chats, show group info instead
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Group chat - no user profile to view'),
          backgroundColor: Color(0xFF6B7280),
        ),
      );
      return;
    }

    // For direct chats, get the other user and show profile inline
    final otherUserRef = chat.members.firstWhere(
      (member) => member != currentUserReference,
      orElse: () => chat.members.first,
    );

    try {
      final user = await UsersRecord.getDocumentOnce(otherUserRef);
      if (context.mounted) {
        // Show user profile inline in the right panel (macOS)
        setState(() {
          _model.userProfileUser = user;
          _model.showUserProfilePanel = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading user profile'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  void _blockUser(ChatsRecord chat) async {
    if (chat.isGroup) {
      // For group chats, show group info instead
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot block group chats'),
          backgroundColor: Color(0xFF6B7280),
        ),
      );
      return;
    }

    // For direct chats, get the other user and block them
    final otherUserRef = chat.members.firstWhere(
      (member) => member != currentUserReference,
      orElse: () => chat.members.first,
    );

    try {
      final user = await UsersRecord.getDocumentOnce(otherUserRef);

      // Show confirmation dialog
      final shouldBlock = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Color(0xFF2D3142),
            title: Text(
              'Block User',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              'Are you sure you want to block ${user.displayName}? You will no longer see their messages or be able to contact them.',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF9CA3AF),
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Block',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (shouldBlock == true) {
        // Create blocked user record
        await BlockedUsersRecord.collection.add({
          ...createBlockedUsersRecordData(
            blockerUser: currentUserReference,
            blockedUser: otherUserRef,
            createdAt: getCurrentTimestamp,
          ),
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User has been blocked'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error blocking user'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  void _showCallingScreen(ChatsRecord chat, {required bool isVideoCall}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: CallingScreenWidget(
          chat: chat,
          isVideoCall: isVideoCall,
          onEndCall: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _viewGroupChat(ChatsRecord chat) async {
    if (!chat.isGroup) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This is not a group chat'),
          backgroundColor: Color(0xFF6B7280),
        ),
      );
      return;
    }

    try {
      setState(() {
        _model.groupInfoChat = chat;
        _model.showGroupInfoPanel = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening group chat details'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  void _navigateToAddMembers(ChatsRecord chat) {
    if (!chat.isGroup) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddGroupMembersWidget(chatDoc: chat),
      ),
    );
  }

  void _navigateToMedia(ChatsRecord chat) {
    if (!chat.isGroup) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GroupMediaLinksDocsWidget(chatDoc: chat),
      ),
    );
  }

  void _navigateToTasks(ChatsRecord chat) {
    if (!chat.isGroup) return;
    setState(() {
      _model.showTasksPanel = true;
    });
  }

  void _handlePinChat(ChatsRecord chat) async {
    try {
      final newPinStatus = !chat.isPin;

      await chat.reference.update({
        'is_pin': newPinStatus,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error pinning chat: $e'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  void _handleDeleteChat(ChatsRecord chat) async {
    final chatName = chat.isGroup
        ? (chat.title.isNotEmpty ? chat.title : 'Group Chat')
        : 'this chat';

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF2D3142),
          title: Text(
            'Delete Chat',
            style: TextStyle(
              fontFamily: 'Inter',
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to delete $chatName? This action cannot be undone.',
            style: TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFF9CA3AF),
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      try {
        await chat.reference.delete();
        setState(() {
          _model.selectedChat = null;
        });
        chatController.selectedChat.value = null;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chat deleted successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting chat: $e'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _handleMuteNotifications(ChatsRecord chat) {
    // TODO: Implement mute notifications functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mute notifications feature coming soon!'),
        backgroundColor: Color(0xFF3B82F6),
      ),
    );
  }

  Widget _buildEmailInviteButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEmailInviteDialog(),
        borderRadius: BorderRadius.circular(20.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: CupertinoColors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: CupertinoColors.white.withOpacity(0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                CupertinoIcons.mail_solid,
                color: CupertinoColors.systemBlue,
                size: 20.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEmailInviteDialog() {
    final emailController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text('Invite via Email'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: CupertinoTextField(
            controller: emailController,
            placeholder: 'Recipient Email',
            keyboardType: TextInputType.emailAddress,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            child: Text('Send Invite'),
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                Navigator.pop(dialogContext);
                return;
              }
              Navigator.pop(dialogContext);

              try {
                final userUid = currentUserUid.isNotEmpty
                    ? currentUserUid
                    : (currentUserReference?.id ?? '');
                final referralLink = 'https://lona.club/invite/$userUid';

                await actions.sendResendInvite(
                  email: email,
                  senderName: currentUserDisplayName,
                  referralLink: referralLink,
                );

                // Show green tick overlay
                _showSuccessTick();
              } catch (e) {
                // Silently fail
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSuccessTick() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 0,
        right: 0,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 300),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: value,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    overlay.insert(entry);

    // Remove after 1.5 seconds
    Future.delayed(Duration(milliseconds: 1500), () {
      entry.remove();
    });
  }
}

// Optimized chat list item widget to prevent flickering
class _ChatListItem extends StatefulWidget {
  final ChatsRecord chat;
  final bool isSelected;
  final VoidCallback onTap;
  final bool hasUnreadMessages;
  final ChatController chatController;
  final Function(ChatsRecord) onPin;
  final Function(ChatsRecord) onDelete;
  final Function(ChatsRecord) onMute;

  const _ChatListItem({
    Key? key,
    required this.chat,
    required this.isSelected,
    required this.onTap,
    required this.hasUnreadMessages,
    required this.chatController,
    required this.onPin,
    required this.onDelete,
    required this.onMute,
  }) : super(key: key);

  @override
  _ChatListItemState createState() => _ChatListItemState();
}

class _ChatListItemState extends State<_ChatListItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return InkWell(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? Colors.white
              : Colors.transparent, // White for selected
          borderRadius: BorderRadius.circular(8),
          border: widget.isSelected
              ? Border.all(
                  color: Color.fromRGBO(
                      230, 235, 245, 1), // Light border for selected
                  width: 1,
                )
              : Border(
                  bottom: BorderSide(
                    color: Color.fromRGBO(230, 235, 245, 1), // Light border
                    width: 1,
                  ),
                ),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.05), // Neutral gray shadow
                    blurRadius: 8,
                    offset: Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Avatar
            _buildChatAvatar(widget.chat),
            SizedBox(width: 12),
            // Chat Info
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Pin icon if chat is pinned
                      if (widget.chat.isPin) ...[
                        Icon(
                          Icons.push_pin,
                          color: Color(0xFF000000), // Black
                          size: 16,
                        ),
                        SizedBox(width: 4),
                      ],
                      Expanded(
                        child: _getChatDisplayName(widget.chat,
                            isSelected: widget.isSelected),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  _getLastMessagePreview(widget.chat,
                      isSelected: widget.isSelected),
                ],
              ),
            ),
            // Timestamp and unread count badge
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Normal Badge (Blue dot)
                    if (widget.hasUnreadMessages)
                      Container(
                        width: 10,
                        height: 10,
                        margin: EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x4D3B82F6),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    // Timestamp
                    Text(
                      widget.chat.lastMessageAt != null
                          ? () {
                              final now = DateTime.now();
                              final messageTime = widget.chat.lastMessageAt!;
                              final difference = now.difference(messageTime);

                              // If within 24 hours, show time only
                              if (difference.inHours < 24) {
                                return DateFormat('h:mm a').format(messageTime);
                              } else {
                                // Otherwise show date in MM/DD/YYYY format
                                return DateFormat('MM/dd/yyyy')
                                    .format(messageTime);
                              }
                            }()
                          : 'Unknown',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: widget.isSelected
                            ? Color(0xFF6B7280)
                            : Color(0xFF9CA3AF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                // Settings button (3-dot menu)
                PopupMenuButton<String>(
                  onSelected: (String value) {
                    if (value == 'pin') {
                      widget.onPin(widget.chat);
                    } else if (value == 'delete') {
                      widget.onDelete(widget.chat);
                    } else if (value == 'mute') {
                      widget.onMute(widget.chat);
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'pin',
                        child: Row(
                          children: [
                            Icon(
                              widget.chat.isPin
                                  ? Icons.push_pin_outlined
                                  : Icons.push_pin,
                              color: Color(0xFF374151),
                              size: 18,
                            ),
                            SizedBox(width: 12),
                            Text(
                              widget.chat.isPin ? 'Unpin' : 'Pin',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFF111827),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete,
                              color: Color(0xFFDC2626),
                              size: 18,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Delete',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFFDC2626),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'mute',
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_off,
                              color: Color(0xFF374151),
                              size: 18,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Mute notifications',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFF111827),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
                  icon: Icon(
                    Icons.more_vert,
                    color: widget.isSelected
                        ? Color(0xFF6B7280)
                        : Color(0xFF9CA3AF),
                    size: 18,
                  ),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatAvatar(ChatsRecord chat) {
    if (chat.isGroup) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: CachedNetworkImage(
            imageUrl: chat.chatImageUrl,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            memCacheWidth: 96,
            memCacheHeight: 96,
            maxWidthDiskCache: 96,
            maxHeightDiskCache: 96,
            filterQuality: FilterQuality.high,
            placeholder: (context, url) => Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group,
                color: Color(0xFF6B7280),
                size: 20,
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group,
                color: Color(0xFF6B7280),
                size: 20,
              ),
            ),
          ),
        ),
      );
    } else {
      // For direct chats, get the other user's profile picture
      final otherUserRef = chat.members.firstWhere(
        (member) => member != currentUserReference,
        orElse: () => chat.members.first,
      );

      return StreamBuilder<UsersRecord>(
        stream: UsersRecord.getDocument(otherUserRef),
        builder: (context, userSnapshot) {
          String imageUrl = '';
          bool isOnline = false;

          // Check if this is Summer first, regardless of userSnapshot
          if (otherUserRef.path.contains('ai_agent_summerai')) {
            imageUrl =
                'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120';
          } else if (userSnapshot.hasData && userSnapshot.data != null) {
            imageUrl = userSnapshot.data?.photoUrl ?? '';
            isOnline = userSnapshot.data?.isOnline ?? false;
          } else if (userSnapshot.hasError) {
            // Error loading user
          } else {
            // Loading user data
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    memCacheWidth: 96,
                    memCacheHeight: 96,
                    maxWidthDiskCache: 96,
                    maxHeightDiskCache: 96,
                    filterQuality: FilterQuality.high,
                    placeholder: (context, url) => Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: Color(0xFF6B7280),
                        size: 20,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: Color(0xFF6B7280),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              // Green dot indicator for online status (like Slack)
              if (isOnline && !otherUserRef.path.contains('ai_agent_summerai'))
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Color(0xFF10B981), // Green color
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }
  }

  Widget _getChatDisplayName(ChatsRecord chat, {bool isSelected = false}) {
    if (chat.isGroup) {
      return Text(
        chat.title.isNotEmpty ? chat.title : 'Group Chat',
        style: TextStyle(
          fontFamily: 'Inter',
          color:
              Color(0xFF111827), // Dark text for both selected and unselected
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      // For direct chats, get the other user's name
      final otherUserRef = chat.members.firstWhere(
        (member) => member != currentUserReference,
        orElse: () => chat.members.first,
      );

      return FutureBuilder<UsersRecord>(
        future: UsersRecord.getDocumentOnce(otherUserRef),
        builder: (context, userSnapshot) {
          String displayName = 'Direct Chat';
          print('DEBUG: otherUserRef.path in chat list = ${otherUserRef.path}');

          // Check if this is Summer first, regardless of userSnapshot
          if (otherUserRef.path.contains('ai_agent_summerai')) {
            displayName = 'Summer';
            print(
                'DEBUG: Found Summer user in chat list, setting displayName to Summer');
          } else if (userSnapshot.hasData && userSnapshot.data != null) {
            final user = userSnapshot.data!;
            displayName =
                user.displayName.isNotEmpty ? user.displayName : 'Unknown User';
            print('DEBUG: Regular user in chat list: ${user.displayName}');

            // Note: Search filtering is handled at the ListView level
          }

          return Text(
            displayName,
            style: TextStyle(
              fontFamily: 'Inter',
              color: Color(
                  0xFF111827), // Dark text for both selected and unselected
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      );
    }
  }

  Widget _getLastMessagePreview(ChatsRecord chat, {bool isSelected = false}) {
    if (chat.lastMessage.isEmpty) {
      return Text(
        'No messages',
        style: TextStyle(
          fontFamily: 'Inter',
          color: isSelected ? Color(0xFF9CA3AF) : Color(0xFF6B7280),
          fontSize: 12,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // For group chats, show sender name
    if (chat.isGroup && chat.lastMessageSent != null) {
      return StreamBuilder<UsersRecord>(
        stream: UsersRecord.getDocument(chat.lastMessageSent!),
        builder: (context, snapshot) {
          String prefix = '';
          if (snapshot.hasData && snapshot.data != null) {
            final senderName = snapshot.data!.displayName;
            // Get first name only
            final firstName = senderName.split(' ').first;
            // Check if it's the current user
            if (chat.lastMessageSent == currentUserReference) {
              prefix = 'You: ';
            } else {
              prefix = '$firstName: ';
            }
          }
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: prefix,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: isSelected ? Color(0xFF6B7280) : Color(0xFF374151),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: chat.lastMessage,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: isSelected ? Color(0xFF9CA3AF) : Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      );
    }

    // For DMs, just show the message
    return Text(
      chat.lastMessage,
      style: TextStyle(
        fontFamily: 'Inter',
        color: isSelected ? Color(0xFF9CA3AF) : Color(0xFF6B7280),
        fontSize: 12,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
