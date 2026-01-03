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
import '/pages/chat/all_pending_requests/all_pending_requests_widget.dart';
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

  // Presence system for online status (like Slack)
  Timer? _inactivityTimer;
  static const Duration _inactivityThreshold = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _model = createModel(context, () => DesktopChatModel());
    chatController = Get.put(ChatController());

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

    // Initialize presence system after a delay to ensure user is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 500), () {
        _initializePresence();
      });
    });
  }

  // Initialize presence system (like Slack)
  void _initializePresence() {
    print('🟢 DEBUG: Initializing presence system...');
    if (currentUserReference == null) {
      print(
          '❌ DEBUG: currentUserReference is null, cannot initialize presence');
      return;
    }
    print('✅ DEBUG: currentUserReference found: ${currentUserReference!.id}');
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
      print(
          '❌ DEBUG: Cannot update online status - currentUserReference is null');
      return;
    }

    try {
      print(
          '🔄 DEBUG: Updating online status to: $isOnline for user: ${currentUserReference!.id}');
      await currentUserReference!.update({
        'is_online': isOnline,
      });
      print('✅ DEBUG: Successfully updated online status to: $isOnline');
    } catch (e) {
      print('❌ ERROR: Failed to update online status: $e');
    }
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
    // Set user to offline when disposing
    _updateOnlineStatus(false);
    _model.dispose();
    Get.delete<ChatController>();
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
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth =
        (screenWidth * 0.3).clamp(200.0, 500.0); // Min 200px, Max 500px

    return Container(
      width: sidebarWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Color.fromRGBO(
            250, 252, 255, 1), // Very light cyan tint, close to white
        border: Border(
          right: BorderSide(
            color: Color.fromRGBO(230, 235, 245, 1), // Light border
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
                Tooltip(
                  message: 'DM',
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _model.showNewMessageView = !_model.showNewMessageView;
                        // Clear selected chat when opening new message view
                        if (_model.showNewMessageView) {
                          _model.selectedChat = null;
                          chatController.selectedChat.value = null;
                          _model.newMessageSearchController?.clear();
                        }
                      });
                    },
                    child: Icon(
                      Icons.add,
                      color: _model.showNewMessageView
                          ? Color(0xFF3B82F6)
                          : Color(0xFF374151), // Dark icon for light background
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Tooltip(
                  message: 'Group Chat',
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _model.showGroupCreation = !_model.showGroupCreation;
                        // Reset group creation state when opening
                        if (_model.showGroupCreation) {
                          // Clear selected chat to show group creation view
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
                    child: Icon(
                      Icons.people,
                      color: _model.showGroupCreation
                          ? Color(0xFF3B82F6)
                          : Color(0xFF374151), // Dark icon for light background
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Connection Requests Badge
                StreamBuilder<UsersRecord>(
                  stream: UsersRecord.getDocument(currentUserReference!),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return SizedBox.shrink();
                    }
                    final currentUser = snapshot.data!;
                    final pendingCount = currentUser.friendRequests.length;

                    return Tooltip(
                      message: pendingCount > 0
                          ? 'Connection Requests ($pendingCount)'
                          : 'Connection Requests',
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            // Open connections view
                            _model.showConnectionsView = true;
                            // Clear other views
                            _model.showNewMessageView = false;
                            _model.showGroupCreation = false;
                            _model.selectedChat = null;
                            chatController.selectedChat.value = null;
                            // Clear search state
                            _model.showConnectionsSearch = false;
                            _model.connectionsSearchController?.clear();
                          });
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              Icons.person_add_alt_1,
                              color: pendingCount > 0
                                  ? Color(0xFF3B82F6)
                                  : Color(0xFF374151),
                              size: 20,
                            ),
                            if (pendingCount > 0)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  padding: EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Color.fromRGBO(250, 252, 255, 1),
                                      width: 1.5,
                                    ),
                                  ),
                                  constraints: BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Center(
                                    child: Text(
                                      pendingCount > 99
                                          ? '99+'
                                          : '$pendingCount',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
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
            hintText: '',
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

                // For direct chats with search query, check if user name matches
                if (!chat.isGroup &&
                    chatController.searchQuery.value.isNotEmpty) {
                  return FutureBuilder<UsersRecord>(
                    future: _getOtherUser(chat),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.hasData && userSnapshot.data != null) {
                        final user = userSnapshot.data!;
                        final displayName = user.displayName.toLowerCase();
                        final query =
                            chatController.searchQuery.value.toLowerCase();

                        if (!displayName.contains(query)) {
                          return SizedBox
                              .shrink(); // Hide if name doesn't match
                        }
                      }

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
                        hasUnreadMessages:
                            chatController.hasUnreadMessages(chat),
                        chatController: chatController,
                        onPin: _handlePinChat,
                        onDelete: _handleDeleteChat,
                        onMute: _handleMuteNotifications,
                      );
                    },
                  );
                }

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
                  hasUnreadMessages: chatController.hasUnreadMessages(chat),
                  chatController: chatController,
                  onPin: _handlePinChat,
                  onDelete: _handleDeleteChat,
                  onMute: _handleMuteNotifications,
                );
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
    _model.showConnectionsView = false;
    _model.showGroupCreation = false;
    _model.showConnectionsSearch = false;
    _model.connectionsSearchController?.clear();
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
          // Invite friends button
          Container(
            width: double.infinity,
            padding: EdgeInsetsDirectional.fromSTEB(32, 12, 32, 12),
            child: Center(
              child: InviteFriendsButtonWidget(),
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

  Widget _buildConnectionsView() {
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
              children: [
                Row(
                  children: [
                    // X button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _model.showConnectionsView = false;
                          _model.showNewMessageView = false;
                          _model.showConnectionsSearch = false;
                          _model.connectionsSearchController?.clear();
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Connections',
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
                            'View and manage your network connections',
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
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _model.showConnectionsSearch =
                                !_model.showConnectionsSearch;
                            if (_model.showConnectionsSearch) {
                              _model.connectionsSearchController?.clear();
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        hoverColor: Color(0xFF3B82F6).withOpacity(0.05),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Color(0xFF3B82F6),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                color: Color(0xFF3B82F6),
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Add new',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Color(0xFF3B82F6),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Tab buttons - separate row
                SizedBox(height: 20),
                Row(
                  children: [
                    _buildTabButton(
                      'My Connections',
                      _model.connectionsTab == 'connections',
                      () {
                        setState(() {
                          _model.connectionsTab = 'connections';
                        });
                      },
                    ),
                    SizedBox(width: 8),
                    _buildTabButton(
                      'Requests',
                      _model.connectionsTab == 'requests',
                      () {
                        setState(() {
                          _model.connectionsTab = 'requests';
                        });
                      },
                    ),
                    SizedBox(width: 8),
                    _buildTabButton(
                      'Sent',
                      _model.connectionsTab == 'sent',
                      () {
                        setState(() {
                          _model.connectionsTab = 'sent';
                        });
                      },
                    ),
                  ],
                ),
                // Search box
                if (_model.showConnectionsSearch) ...[
                  SizedBox(height: 20),
                  Container(
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
                      controller: _model.connectionsSearchController,
                      autofocus: true,
                      onChanged: (value) {
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by name or email...',
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
                          padding:
                              EdgeInsetsDirectional.only(start: 14, end: 10),
                          child: Icon(
                            Icons.search_rounded,
                            color: Color(0xFF3B82F6),
                            size: 20,
                          ),
                        ),
                        suffixIcon: _model.connectionsSearchController?.text
                                    .isNotEmpty ==
                                true
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _model.connectionsSearchController?.clear();
                                  });
                                },
                              )
                            : null,
                      ),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF1A1F36),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Invite friends button
          Container(
            width: double.infinity,
            padding: EdgeInsetsDirectional.fromSTEB(32, 12, 32, 12),
            child: Center(
              child: InviteFriendsButtonWidget(),
            ),
          ),
          // Connections or Requests list
          Expanded(
            child: Container(
              width: double.infinity,
              padding: EdgeInsetsDirectional.fromSTEB(32, 24, 32, 32),
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

                  // Show requests tab
                  if (_model.connectionsTab == 'requests') {
                    final requests = currentUser.friendRequests;

                    if (requests.isEmpty) {
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
                                Icons.person_add_outlined,
                                color: Color(0xFF3B82F6),
                                size: 40,
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              'No pending requests',
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
                              'You have no pending connection requests',
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

                    return ListView.separated(
                      itemCount: requests.length,
                      separatorBuilder: (context, index) => SizedBox.shrink(),
                      itemBuilder: (context, index) {
                        final requestRef = requests[index];
                        return StreamBuilder<UsersRecord>(
                          stream: UsersRecord.getDocument(requestRef),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData) {
                              return SizedBox.shrink();
                            }
                            final user = userSnapshot.data!;
                            return _buildLinkedInStyleRequestCard(
                                user, currentUser);
                          },
                        );
                      },
                    );
                  }

                  // Show sent requests tab
                  if (_model.connectionsTab == 'sent') {
                    final sentRequests = currentUser.sentRequests
                        .where((ref) => !currentUser.friends.contains(ref))
                        .toList();

                    if (sentRequests.isEmpty) {
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
                                Icons.send_outlined,
                                color: Color(0xFF3B82F6),
                                size: 40,
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              'No sent requests',
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
                              'You have no pending sent connection requests',
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

                    return ListView.separated(
                      itemCount: sentRequests.length,
                      separatorBuilder: (context, index) => SizedBox.shrink(),
                      itemBuilder: (context, index) {
                        final requestRef = sentRequests[index];
                        return StreamBuilder<UsersRecord>(
                          stream: UsersRecord.getDocument(requestRef),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData) {
                              return SizedBox.shrink();
                            }
                            final user = userSnapshot.data!;
                            return _buildLinkedInStyleConnectionCardForSearch(
                                user, currentUser);
                          },
                        );
                      },
                    );
                  }

                  // Show connections tab
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
                            'Start connecting with people to build your network',
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

                  // Show search results if searching, otherwise show connections
                  if (_model.showConnectionsSearch &&
                      _model.connectionsSearchController?.text.isNotEmpty ==
                          true) {
                    final searchQuery = _model.connectionsSearchController?.text
                            .toLowerCase() ??
                        '';

                    return StreamBuilder<List<UsersRecord>>(
                      stream: queryUsersRecord(),
                      builder: (context, allUsersSnapshot) {
                        if (!allUsersSnapshot.hasData) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF3B82F6),
                            ),
                          );
                        }

                        final allUsers = allUsersSnapshot.data!;

                        // Filter users by search query and exclude current user
                        final filteredUsers = allUsers.where((user) {
                          if (user.reference == currentUserReference) {
                            return false;
                          }
                          final displayName = user.displayName.toLowerCase();
                          final email = user.email.toLowerCase();
                          return displayName.contains(searchQuery) ||
                              email.contains(searchQuery);
                        }).toList();

                        if (filteredUsers.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  color: Color(0xFF9CA3AF),
                                  size: 48,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No users found',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Color(0xFF6B7280),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: filteredUsers.length,
                          separatorBuilder: (context, index) =>
                              SizedBox.shrink(),
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final isConnected =
                                currentUser.friends.contains(user.reference);
                            if (isConnected) {
                              return _buildLinkedInStyleConnectionCard(
                                  user, currentUser);
                            } else {
                              return _buildLinkedInStyleConnectionCardForSearch(
                                  user, currentUser);
                            }
                          },
                        );
                      },
                    );
                  }

                  // Show connections list (LinkedIn style)
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
                            'Start connecting with people to build your network',
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

                  return ListView.separated(
                    itemCount: connections.length,
                    separatorBuilder: (context, index) => SizedBox.shrink(),
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

                          return _buildLinkedInStyleConnectionCard(
                              user, currentUser);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, bool isSelected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: Color(0xFFE2E8F0), width: 1)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: isSelected ? Color(0xFF1A1F36) : Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (isSelected) ...[
                SizedBox(height: 10),
                Container(
                  width: 120,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkedInStyleConnectionCard(
      UsersRecord user, UsersRecord currentUser) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: CachedNetworkImage(
                  imageUrl: user.photoUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: Color(0xFF64748B),
                      size: 28,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: Color(0xFF64748B),
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF000000),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  if (user.bio.isNotEmpty)
                    Text(
                      user.bio,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF666666),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      user.email,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF666666),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  SizedBox(height: 4),
                  Text(
                    'Connected',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            // Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Message button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await _startNewChatWithUser(user);
                      setState(() {
                        _model.showConnectionsView = false;
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Color(0xFF2563EB),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Message',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFF2563EB),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // More options dropdown
                PopupMenuButton<String>(
                  offset: Offset(0, 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  color: Colors.white,
                  elevation: 8,
                  shadowColor: Color(0x1A000000),
                  onSelected: (String value) async {
                    if (value == 'remove') {
                      try {
                        // Remove connection from both users
                        await currentUserReference!.update({
                          'friends': FieldValue.arrayRemove([user.reference]),
                        });
                        await user.reference.update({
                          'friends':
                              FieldValue.arrayRemove([currentUserReference]),
                        });
                        setState(() {});
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to remove connection'),
                            backgroundColor: Color(0xFFEF4444),
                          ),
                        );
                      }
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'remove',
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        'Remove connection',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFFDC2626),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      hoverColor: Color(0xFFF3F4F6),
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.more_horiz,
                          color: Color(0xFF6B7280),
                          size: 20,
                        ),
                      ),
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

  Widget _buildLinkedInStyleRequestCard(
      UsersRecord user, UsersRecord currentUser) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: CachedNetworkImage(
                  imageUrl: user.photoUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: Color(0xFF64748B),
                      size: 28,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: Color(0xFF64748B),
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF000000),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  if (user.bio.isNotEmpty)
                    Text(
                      user.bio,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF666666),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      user.email,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF666666),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
            // Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ignore button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      try {
                        // Remove from friend_requests
                        await currentUserReference!.update({
                          'friend_requests':
                              FieldValue.arrayRemove([user.reference]),
                        });
                        // Remove from their sent_requests
                        await user.reference.update({
                          'sent_requests':
                              FieldValue.arrayRemove([currentUserReference]),
                        });
                        setState(() {});
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to ignore request'),
                            backgroundColor: Color(0xFFEF4444),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Color(0xFFE5E7EB),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Ignore',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFF666666),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // Accept button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      try {
                        // Add to friends for both users
                        await currentUserReference!.update({
                          'friends': FieldValue.arrayUnion([user.reference]),
                          'friend_requests':
                              FieldValue.arrayRemove([user.reference]),
                        });
                        await user.reference.update({
                          'friends':
                              FieldValue.arrayUnion([currentUserReference]),
                          'sent_requests':
                              FieldValue.arrayRemove([currentUserReference]),
                        });
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Connection request accepted!'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to accept request'),
                            backgroundColor: Color(0xFFEF4444),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Accept',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _buildLinkedInStyleConnectionCardForSearch(
      UsersRecord user, UsersRecord currentUser) {
    final isConnected = currentUser.friends.contains(user.reference);
    final isPending = currentUser.sentRequests.contains(user.reference);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: CachedNetworkImage(
                  imageUrl: user.photoUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: Color(0xFF64748B),
                      size: 28,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: Color(0xFF64748B),
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF000000),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  if (user.bio.isNotEmpty)
                    Text(
                      user.bio,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF666666),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      user.email,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF666666),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  SizedBox(height: 4),
                  if (isConnected)
                    Text(
                      'Connected',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    )
                  else if (isPending)
                    Text(
                      'Pending',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFFF59E0B),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
            // Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isConnected)
                  // Message button for connected users
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        await _startNewChatWithUser(user);
                        setState(() {
                          _model.showConnectionsView = false;
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Color(0xFF2563EB),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Message',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0xFF2563EB),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (isPending)
                  // Pending button (disabled style)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Color(0xFFE5E7EB),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Pending',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  // Send Connection Request button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        try {
                          // Update current user's sent_requests
                          await currentUserReference!.update({
                            'sent_requests':
                                FieldValue.arrayUnion([user.reference]),
                          });

                          // Update target user's friend_requests
                          await user.reference.update({
                            'friend_requests':
                                FieldValue.arrayUnion([currentUserReference]),
                          });

                          // Refresh the UI
                          setState(() {});
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Failed to send connection request'),
                              backgroundColor: Color(0xFFEF4444),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Color(0xFF2563EB),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Send Connection Request',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0xFF2563EB),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

  Widget _buildConnectionCard(UsersRecord user, UsersRecord currentUser) {
    final isConnected = currentUser.friends.contains(user.reference);
    final isPending = currentUser.sentRequests.contains(user.reference);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar with gradient border
          Container(
            width: 64,
            height: 64,
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
                  color: Color(0xFF3B82F6).withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.all(2.5),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(29.5),
                child: CachedNetworkImage(
                  imageUrl: user.photoUrl,
                  width: 59,
                  height: 59,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 59,
                    height: 59,
                    decoration: BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: Color(0xFF64748B),
                      size: 26,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 59,
                    height: 59,
                    decoration: BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: Color(0xFF64748B),
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          // Name
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              user.displayName,
              style: TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF1A1F36),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: 8),
          // Connection status or button
          if (isConnected)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Connected',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else if (isPending)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 12,
                      color: Color(0xFFF59E0B),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Pending',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFFF59E0B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    try {
                      // Update current user's sent_requests
                      await currentUserReference!.update({
                        'sent_requests':
                            FieldValue.arrayUnion([user.reference]),
                      });

                      // Update target user's friend_requests
                      await user.reference.update({
                        'friend_requests':
                            FieldValue.arrayUnion([currentUserReference]),
                      });

                      // Refresh the UI
                      setState(() {});
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to send connection request'),
                          backgroundColor: Color(0xFFEF4444),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF2563EB).withOpacity(0.3),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Send Connection Request',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
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
        _model.showConnectionsView ||
        (_model.showGroupInfoPanel && _model.groupInfoChat != null) ||
        (_model.showUserProfilePanel && _model.userProfileUser != null);

    return Expanded(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Color.fromRGBO(250, 252, 255, 1), // Match left sidebar color
        ),
        child: showAnyPanel
            ? Stack(
                children: [
                  // Show default chat view behind the overlay
                  _buildDefaultChatView(),
                  // Semi-transparent overlay background
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _model.showGroupCreation = false;
                          _model.showNewMessageView = false;
                          _model.showConnectionsView = false;
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
                  if (_model.showConnectionsView)
                    _buildRightSidePanel(_buildConnectionsView(), () {
                      setState(() {
                        _model.showConnectionsView = false;
                        _model.showConnectionsSearch = false;
                        _model.connectionsSearchController?.clear();
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
                  if (_model.showUserProfilePanel &&
                      _model.userProfileUser != null)
                    _buildRightSidePanel(
                      UserProfileDetailWidget(
                        user: _model.userProfileUser,
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
              )
            : _buildDefaultChatView(),
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
          // AI Assistant icon (only for group chats)
          if (chat.isGroup) ...[
            Tooltip(
              message: 'Get Personal Daily Summary',
              child: InkWell(
                onTap: _model.isGeneratingSummary
                    ? null
                    : () async {
                        await _generateDailySummary(chat);
                      },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0, 0, 12, 0),
                  child: _model.isGeneratingSummary
                      ? SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF3B82F6),
                            ),
                          ),
                        )
                      : Image.asset(
                          'assets/images/software-agent.png',
                          width: 28,
                          height: 28,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
            ),
            // Tasks button next to SummerAI icon
            TextButton(
              onPressed: () {
                setState(() {
                  _model.showTasksPanel = !_model.showTasksPanel;
                });
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: Color(0xFF2563EB),
              ),
              child: Text(
                'Tasks',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          ],
          // More options button
          PopupMenuButton<String>(
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
              if (chat.isGroup) {
                // Group chat options
                return <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'group',
                    child: Row(
                      children: [
                        Icon(
                          Icons.group,
                          color: Color(0xFF374151),
                          size: 18,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'View Group Chat',
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
              } else {
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
              }
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

      return FutureBuilder<UsersRecord>(
        future: UsersRecord.getDocumentOnce(otherUserRef),
        builder: (context, userSnapshot) {
          String imageUrl = '';

          // Check if this is Summer first, regardless of userSnapshot
          if (otherUserRef.path.contains('ai_agent_summerai')) {
            imageUrl =
                'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120';
            print('DEBUG: Setting Summer photo');
          } else if (userSnapshot.hasData && userSnapshot.data != null) {
            imageUrl = userSnapshot.data?.photoUrl ?? '';
            print(
                'DEBUG: Setting regular user photo: ${userSnapshot.data?.photoUrl}');
          }

          return Container(
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
                    // Unread message count badge
                    if (widget.hasUnreadMessages)
                      StreamBuilder<int>(
                        stream: widget.chatController
                            .getUnreadMessageCount(widget.chat),
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.data ?? 0;
                          if (unreadCount == 0) {
                            return SizedBox.shrink();
                          }
                          return Container(
                            margin: EdgeInsets.only(right: 8),
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(0xFF3B82F6), // Blue background
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Center(
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
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
            print('🟡 DEBUG: Setting Summer photo');
          } else if (userSnapshot.hasData && userSnapshot.data != null) {
            imageUrl = userSnapshot.data?.photoUrl ?? '';
            isOnline = userSnapshot.data?.isOnline ?? false;
            print(
                '👤 DEBUG: User ${userSnapshot.data?.displayName} (${otherUserRef.id}) - isOnline: $isOnline');
            if (isOnline) {
              print('🟢 DEBUG: User is ONLINE - green dot should be visible!');
            }
          } else if (userSnapshot.hasError) {
            print('❌ DEBUG: Error loading user: ${userSnapshot.error}');
          } else {
            print('⏳ DEBUG: Loading user data...');
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
