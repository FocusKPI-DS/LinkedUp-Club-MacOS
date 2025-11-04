import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/chat/chat_component/chat_thread_component/chat_thread_component_widget.dart';
import '/pages/desktop_chat/desktop_chat_model.dart';
import '/pages/desktop_chat/chat_controller.dart';
import '/pages/chat/user_profile_detail/user_profile_detail_widget.dart';
import '/pages/chat/group_chat_detail/group_chat_detail_widget.dart';
import '/pages/chat/group_action_tasks/group_action_tasks_widget.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';

class DesktopChatWidget extends StatefulWidget {
  const DesktopChatWidget({Key? key}) : super(key: key);

  @override
  _DesktopChatWidgetState createState() => _DesktopChatWidgetState();
}

class _DesktopChatWidgetState extends State<DesktopChatWidget>
    with TickerProviderStateMixin {
  late DesktopChatModel _model;
  late ChatController chatController;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final animationsMap = <String, AnimationInfo>{};

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _model.dispose();
    Get.delete<ChatController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        color: Color(0xFF374151),
        border: Border(
          right: BorderSide(
            color: Color(0xFF4B5563),
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
        color: Color(0xFF374151),
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
                  color: Colors.white,
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
                GestureDetector(
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
                    Icons.add,
                    color: _model.showGroupCreation
                        ? Color(0xFF3B82F6)
                        : Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _model.showWorkspaceMembers =
                          !_model.showWorkspaceMembers;
                    });
                  },
                  child: Icon(
                    Icons.person,
                    color: _model.showWorkspaceMembers
                        ? Color(0xFF3B82F6)
                        : Colors.white,
                    size: 20,
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
          color: Color(0xFF4B5563),
          borderRadius: BorderRadius.circular(8),
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
              color: Colors.white,
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
                        color: Colors.white,
                        size: 18,
                      ),
                    )
                  : SizedBox.shrink();
            }),
          ),
          style: TextStyle(
            fontFamily: 'Inter',
            color: Colors.white,
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
        color: Color(0xFF374151),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(child: _buildTab('All', 0)),
            SizedBox(width: 8),
            Expanded(child: _buildTab('Direct Message', 1)),
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
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            color: isSelected ? Color(0xFF374151) : Colors.white,
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
                color: Colors.white,
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
            // If workspace members view is toggled, show workspace members
            if (_model.showWorkspaceMembers) {
              return _buildWorkspaceMembersList();
            }

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
                            _model.selectedChat = chat;
                          });
                          chatController.selectChat(chat);
                        },
                        hasUnreadMessages:
                            chatController.hasUnreadMessages(chat),
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
                      _model.selectedChat = chat;
                    });
                    chatController.selectChat(chat);
                  },
                  hasUnreadMessages: chatController.hasUnreadMessages(chat),
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

  Widget _buildWorkspaceMembersList() {
    return Column(
      children: [
        // Header for workspace members
        Container(
          width: double.infinity,
          padding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Color(0xFF4B5563),
            border: Border(
              bottom: BorderSide(
                color: Color(0xFF374151),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.group,
                color: Colors.white,
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Workspace Members',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_model.showWorkspaceMembers)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _model.showWorkspaceMembers = false;
                    });
                  },
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
        // Members list
        Expanded(
          child: StreamBuilder<List<WorkspaceMembersRecord>>(
            stream: queryWorkspaceMembersRecord(
              queryBuilder: (workspaceMembersRecord) =>
                  workspaceMembersRecord.where('workspace_ref',
                      isEqualTo: chatController.currentWorkspaceRef.value),
            ),
            builder: (context, membersSnapshot) {
              if (!membersSnapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                );
              }

              final members = membersSnapshot.data!;
              final searchQuery =
                  chatController.searchQuery.value.toLowerCase();

              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];

                  return StreamBuilder<UsersRecord>(
                    stream: UsersRecord.getDocument(member.userRef!),
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

                      // Check if search query matches
                      if (searchQuery.isNotEmpty) {
                        final displayName = user.displayName.toLowerCase();
                        final email = user.email.toLowerCase();
                        if (!displayName.contains(searchQuery) &&
                            !email.contains(searchQuery)) {
                          return SizedBox.shrink();
                        }
                      }

                      return InkWell(
                        onTap: () async {
                          await _startNewChatWithUser(user);
                        },
                        child: Container(
                          width: double.infinity,
                          padding:
                              EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              bottom: BorderSide(
                                color: Color(0xFF374151),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              // Avatar
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
                                    imageUrl: user.photoUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
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
                                    errorWidget: (context, url, error) =>
                                        Container(
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
                              SizedBox(width: 12),
                              // User Info
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            user.displayName,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getRoleColor(member.role),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            member.role.toUpperCase(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      user.email,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Tap to start a chat',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        color: Color(0xFF3B82F6),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Chat icon
                              Icon(
                                Icons.chat_bubble_outline,
                                color: Color(0xFF3B82F6),
                                size: 18,
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
      ],
    );
  }

  Widget _buildGroupCreationViewRight() {
    return Column(
      children: [
        // Header for group creation
        Container(
          width: double.infinity,
          padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: Color(0xFFF9FAFB),
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.group_add,
                color: Color(0xFF374151),
                size: 24,
              ),
              SizedBox(width: 12),
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
                    'Group Name',
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
                  // Selected members count
                  Text(
                    'Selected Members (${_model.selectedMembers.length})',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF374151),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  // Workspace members list for selection
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
                    child: StreamBuilder<List<WorkspaceMembersRecord>>(
                      stream: queryWorkspaceMembersRecord(
                        queryBuilder: (workspaceMembersRecord) =>
                            workspaceMembersRecord.where('workspace_ref',
                                isEqualTo:
                                    chatController.currentWorkspaceRef.value),
                      ),
                      builder: (context, membersSnapshot) {
                        if (!membersSnapshot.hasData) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF3B82F6),
                            ),
                          );
                        }

                        final members = membersSnapshot.data!;
                        final searchQuery =
                            chatController.searchQuery.value.toLowerCase();

                        return ListView.builder(
                          padding: EdgeInsets.all(12),
                          itemCount: members.length,
                          itemBuilder: (context, index) {
                            final member = members[index];

                            return StreamBuilder<UsersRecord>(
                              stream: UsersRecord.getDocument(member.userRef!),
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
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      user.displayName,
                                                      style: TextStyle(
                                                        fontFamily: 'Inter',
                                                        color:
                                                            Color(0xFF1F2937),
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  SizedBox(width: 6),
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: _getRoleColor(
                                                          member.role),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: Text(
                                                      member.role.toUpperCase(),
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                ],
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
                      onPressed: _model.groupName.isNotEmpty &&
                              _model.selectedMembers.isNotEmpty
                          ? () => _createGroup()
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _model.groupName.isNotEmpty &&
                                _model.selectedMembers.isNotEmpty
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

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Color(0xFFDC2626); // Red
      case 'moderator':
        return Color(0xFF059669); // Green
      case 'member':
        return Color(0xFF6B7280); // Gray
      default:
        return Color(0xFF6B7280); // Default gray
    }
  }

  Future<void> _startNewChatWithUser(UsersRecord user) async {
    try {
      // Check if a chat already exists between current user and this user IN THE CURRENT WORKSPACE
      final currentWorkspaceRef = chatController.currentWorkspaceRef.value;

      final existingChats = await queryChatsRecordOnce(
        queryBuilder: (chatsRecord) => chatsRecord
            .where('members', arrayContains: currentUserReference)
            .where('is_group', isEqualTo: false)
            .where('workspace_ref', isEqualTo: currentWorkspaceRef),
      );

      // Find if there's already a direct chat with this user in the current workspace
      ChatsRecord? existingChat;
      for (final chat in existingChats) {
        if (chat.members.contains(user.reference) &&
            chat.members.length == 2 &&
            !chat.isGroup &&
            chat.workspaceRef?.path == currentWorkspaceRef?.path) {
          existingChat = chat;
          break;
        }
      }

      if (existingChat != null) {
        // Chat already exists, select it
        setState(() {
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
            workspaceRef: chatController.currentWorkspaceRef.value,
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
      if (_model.groupName.isEmpty || _model.selectedMembers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Please enter a group name and select at least one member'),
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

      // Create the group chat
      final newChatRef = await ChatsRecord.collection.add({
        ...createChatsRecordData(
          title: _model.groupName,
          isGroup: true,
          createdAt: getCurrentTimestamp,
          lastMessageAt: getCurrentTimestamp,
          lastMessage: '',
          lastMessageSent: currentUserReference,
          workspaceRef: chatController.currentWorkspaceRef.value,
          chatImageUrl: _model.groupImageUrl ?? '',
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
        _model.selectedChat = newChat;
        _model.showGroupCreation = false;
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
          content: Text('Group "${_model.groupName}" created successfully!'),
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

  Widget _buildRightPanel() {
    return Expanded(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
        ),
        child: _model.showGroupCreation
            ? _buildGroupCreationViewRight()
            : _model.showGroupInfoPanel && _model.groupInfoChat != null
                ? Stack(
                    children: [
                      // Group info displayed inline (keeps vertical navbar)
                      Positioned.fill(
                        child: GroupChatDetailWidget(
                          chatDoc: _model.groupInfoChat,
                        ),
                      ),
                      // Overlay back button to return to chat view
                      // Positioned to avoid overlap with AppBar title
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _model.showGroupInfoPanel = false;
                                _model.groupInfoChat = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x1F000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.arrow_back,
                                  size: 20, color: Color(0xFF374151)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : _model.selectedChat != null
                    ? Column(
                        children: [
                          // Top panel with user info
                          _buildChatHeader(),
                          // Action Items Stats Section (only for group chats)
                          if (_model.selectedChat!.isGroup)
                            _buildActionItemsStats(_model.selectedChat!),
                          // Tasks panel or Chat thread component
                          Expanded(
                            child: _model.showTasksPanel &&
                                    _model.selectedChat!.isGroup
                                ? Stack(
                                    children: [
                                      // Tasks displayed inline (keeps vertical navbar)
                                      Positioned.fill(
                                        child: GroupActionTasksWidget(
                                          chatDoc: _model.selectedChat,
                                        ),
                                      ),
                                      // Overlay back button to return to chat view
                                      Positioned(
                                        top: 12,
                                        left: 12,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                _model.showTasksPanel = false;
                                              });
                                            },
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            child: Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Color(0x1F000000),
                                                    blurRadius: 6,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(Icons.arrow_back,
                                                  size: 20,
                                                  color: Color(0xFF374151)),
                                            ),
                                          ),
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
                      ),
      ),
    );
  }

  Widget _buildChatHeader() {
    final chat = _model.selectedChat!;

    return Container(
      width: double.infinity,
      padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Color(0xFFF9FAFB),
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

    // For direct chats, get the other user and navigate to their profile
    final otherUserRef = chat.members.firstWhere(
      (member) => member != currentUserReference,
      orElse: () => chat.members.first,
    );

    try {
      final user = await UsersRecord.getDocumentOnce(otherUserRef);
      if (context.mounted) {
        context.pushNamed(
          UserProfileDetailWidget.routeName,
          queryParameters: {
            'user': serializeParam(user, ParamType.Document),
          }.withoutNulls,
          extra: <String, dynamic>{'user': user},
        );
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
  final Function(ChatsRecord) onPin;
  final Function(ChatsRecord) onDelete;
  final Function(ChatsRecord) onMute;

  const _ChatListItem({
    Key? key,
    required this.chat,
    required this.isSelected,
    required this.onTap,
    required this.hasUnreadMessages,
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
          color: widget.isSelected ? Color(0xFFF3F4F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            bottom: BorderSide(
              color: Color(0xFF374151),
              width: 1,
            ),
          ),
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
                          color: widget.isSelected
                              ? Color(0xFF3B82F6)
                              : Color(0xFF9CA3AF),
                          size: 14,
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
            // Timestamp and notification dot
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Notification dot for unread messages
                    if (widget.hasUnreadMessages)
                      Container(
                        width: 8,
                        height: 8,
                        margin: EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color:
                              Color(0xFFEF4444), // Red dot for unread messages
                          shape: BoxShape.circle,
                        ),
                      ),
                    // Timestamp
                    Text(
                      widget.chat.lastMessageAt != null
                          ? timeago.format(widget.chat.lastMessageAt!)
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
          color: isSelected ? Color(0xFF111827) : Colors.white,
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
              color: isSelected ? Color(0xFF111827) : Colors.white,
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
