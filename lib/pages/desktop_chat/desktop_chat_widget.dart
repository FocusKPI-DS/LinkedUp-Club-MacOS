import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/chat/chat_component/chat_thread_component/chat_thread_component_widget.dart';
import '/pages/desktop_chat/desktop_chat_model.dart';
import '/pages/desktop_chat/chat_controller.dart';
import '/pages/chat/user_profile_detail/user_profile_detail_widget.dart';
import '/pages/chat/group_chat_detail/group_chat_detail_widget.dart';
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_storage/firebase_storage.dart';

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
      length: 2, // Reduced from 3 to 2 (removed Contact tab)
      initialIndex: 0,
    )..addListener(() {
        safeSetState(() {});
        chatController.updateSelectedTab(_model.tabController!.index);
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
                'LinkedUp Chat',
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
                SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    // Filter functionality
                  },
                  child: Icon(
                    Icons.filter_list,
                    color: Colors.white,
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
            Expanded(child: _buildTab('Direct Message', 0)),
            SizedBox(width: 8),
            Expanded(child: _buildTab('Groups', 1)),
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
            // If group creation is toggled, show group creation view
            if (_model.showGroupCreation) {
              return _buildGroupCreationView();
            }
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

  Widget _buildGroupCreationView() {
    return Column(
      children: [
        // Header for group creation
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
                Icons.group_add,
                color: Colors.white,
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Create New Group',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 14,
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
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
        // Group creation form
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group name input
                Text(
                  'Group Name',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF4B5563),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Color(0xFF6B7280),
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
                          EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
                    ),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                // Group image upload
                Text(
                  'Group Image (Optional)',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    // Image preview/placeholder
                    GestureDetector(
                      onTap: _model.isUploadingImage ? null : _pickGroupImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Color(0xFF4B5563),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Color(0xFF6B7280),
                            width: 1,
                          ),
                        ),
                        child: _model.isUploadingImage
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : _model.groupImageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: _model.groupImageUrl!,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 80,
                                        height: 80,
                                        color: Color(0xFF4B5563),
                                        child: Icon(
                                          Icons.image,
                                          color: Color(0xFF9CA3AF),
                                          size: 24,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        width: 80,
                                        height: 80,
                                        color: Color(0xFF4B5563),
                                        child: Icon(
                                          Icons.image,
                                          color: Color(0xFF9CA3AF),
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate,
                                        color: Color(0xFF9CA3AF),
                                        size: 24,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Add Image',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          color: Color(0xFF9CA3AF),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ),
                    SizedBox(width: 12),
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
                                  : Color(0xFF9CA3AF),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _model.isUploadingImage
                                    ? null
                                    : _pickGroupImage,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _model.isUploadingImage
                                        ? Color(0xFF6B7280)
                                        : Color(0xFF3B82F6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _model.groupImageUrl != null
                                        ? 'Change'
                                        : 'Select',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              if (_model.groupImageUrl != null) ...[
                                SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _model.groupImagePath = null;
                                      _model.groupImageUrl = null;
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFEF4444),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Remove',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
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
                SizedBox(height: 20),
                // Selected members count
                Text(
                  'Selected Members (${_model.selectedMembers.length})',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                // Workspace members list for selection
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Color(0xFF374151),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Color(0xFF4B5563),
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
                            color: Colors.white,
                          ),
                        );
                      }

                      final members = membersSnapshot.data!;
                      final searchQuery =
                          chatController.searchQuery.value.toLowerCase();

                      return ListView.builder(
                        padding: EdgeInsets.all(8),
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
                                  margin: EdgeInsets.only(bottom: 4),
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Color(0xFF3B82F6)
                                        : Color(0xFF4B5563),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSelected
                                          ? Color(0xFF3B82F6)
                                          : Color(0xFF6B7280),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Color(0xFF3B82F6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: CachedNetworkImage(
                                            imageUrl: user.photoUrl,
                                            width: 32,
                                            height: 32,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                color: Color(0xFF6B7280),
                                                size: 16,
                                              ),
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                color: Color(0xFF6B7280),
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user.displayName,
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              user.email,
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                color: Color(0xFF9CA3AF),
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 16,
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
                SizedBox(height: 20),
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
                          : Color(0xFF6B7280),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Create Group',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
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

        // Upload image to Firebase Storage
        await _uploadGroupImage(image.path);
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

  Future<void> _uploadGroupImage(String imagePath) async {
    try {
      final file = File(imagePath);
      final fileName =
          'group_images/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Check if user is authenticated
      if (currentUserReference == null) {
        throw Exception('User not authenticated');
      }

      // Upload to Firebase Storage
      final uploadTask = FirebaseStorage.instance.ref(fileName).putFile(file);
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
        child: _model.selectedChat != null
            ? Column(
                children: [
                  // Top panel with user info
                  _buildChatHeader(),
                  // Chat thread component
                  Expanded(
                    child: ChatThreadComponentWidget(
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
          if (userSnapshot.hasData && userSnapshot.data != null) {
            imageUrl = userSnapshot.data!.photoUrl;
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
          if (userSnapshot.hasData && userSnapshot.data != null) {
            final user = userSnapshot.data!;
            displayName =
                user.displayName.isNotEmpty ? user.displayName : 'Unknown User';
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
      context.pushNamed(
        GroupChatDetailWidget.routeName,
        queryParameters: {
          'chatDoc': serializeParam(chat, ParamType.Document),
        }.withoutNulls,
        extra: <String, dynamic>{'chatDoc': chat},
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening group chat details'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }
}

// Optimized chat list item widget to prevent flickering
class _ChatListItem extends StatefulWidget {
  final ChatsRecord chat;
  final bool isSelected;
  final VoidCallback onTap;
  final bool hasUnreadMessages;

  const _ChatListItem({
    Key? key,
    required this.chat,
    required this.isSelected,
    required this.onTap,
    required this.hasUnreadMessages,
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
                  _getChatDisplayName(widget.chat,
                      isSelected: widget.isSelected),
                  SizedBox(height: 2),
                  _getLastMessagePreview(widget.chat,
                      isSelected: widget.isSelected),
                ],
              ),
            ),
            // Timestamp and notification dot
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
                      color: Color(0xFFEF4444), // Red dot for unread messages
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
          if (userSnapshot.hasData && userSnapshot.data != null) {
            imageUrl = userSnapshot.data!.photoUrl;
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
          if (userSnapshot.hasData && userSnapshot.data != null) {
            final user = userSnapshot.data!;
            displayName =
                user.displayName.isNotEmpty ? user.displayName : 'Unknown User';

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
