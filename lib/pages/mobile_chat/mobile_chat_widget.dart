import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/chat/chat_component/chat_thread_component/chat_thread_component_widget.dart';
import '/pages/mobile_chat/mobile_chat_model.dart';
import '/pages/desktop_chat/chat_controller.dart';
import '/pages/chat/user_profile_detail/user_profile_detail_widget.dart';
import '/pages/chat/group_chat_detail/group_chat_detail_widget.dart';
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_debounce/easy_debounce.dart';
// import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart'; // Removed unused import
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MobileChatWidget extends StatefulWidget {
  const MobileChatWidget({
    Key? key,
    this.onChatStateChanged,
  }) : super(key: key);

  static String routeName = 'MobileChat';
  static String routePath = '/mobile-chat';

  final Function(bool isChatOpen)? onChatStateChanged;

  @override
  _MobileChatWidgetState createState() => _MobileChatWidgetState();
}

class _MobileChatWidgetState extends State<MobileChatWidget>
    with TickerProviderStateMixin {
  late MobileChatModel _model;
  late ChatController chatController;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final animationsMap = <String, AnimationInfo>{};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MobileChatModel());
    chatController = Get.put(ChatController());

    // Initialize workspace for chat controller
    _initializeWorkspace();

    _model.tabController = TabController(
      vsync: this,
      length: 2, // Direct Message and Groups
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

  Future<void> _initializeWorkspace() async {
    try {
      if (currentUserReference != null) {
        final currentUserDoc =
            await UsersRecord.getDocumentOnce(currentUserReference!);
        final userWorkspaceRef = currentUserDoc.currentWorkspaceRef;
        chatController.updateCurrentWorkspace(userWorkspaceRef);
      }
    } catch (e) {
      print('Error initializing workspace: $e');
    }
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
      backgroundColor: Colors.white,
      body: RepaintBoundary(
        child:
            _model.selectedChat != null ? _buildChatView() : _buildChatList(),
      ),
    );
  }

  Widget _buildChatView() {
    return Column(
      children: [
        // iOS-style navigation bar
        _buildIOSNavigationBar(),
        // Chat thread component
        Expanded(
          child: ChatThreadComponentWidget(
            chatReference: _model.selectedChat,
            onMessageLongPress: _showMessageMenu,
          ),
        ),
      ],
    );
  }

  Widget _buildIOSNavigationBar() {
    final chat = _model.selectedChat!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 60,
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _model.selectedChat = null;
                  });
                  // Notify parent that chat is closed
                  widget.onChatStateChanged?.call(false);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios,
                    color: Color(0xFF007AFF), // iOS blue
                    size: 20,
                  ),
                ),
              ),
              SizedBox(width: 12),
              // Chat avatar
              _buildHeaderAvatar(chat),
              SizedBox(width: 12),
              // Chat info
              Expanded(
                child: _buildHeaderName(chat),
              ),
              // More options button
              GestureDetector(
                onTap: () => _showChatOptions(chat),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.more_vert,
                    color: Color(0xFF007AFF), // iOS blue
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return Column(
      children: [
        // iOS-style header
        _buildIOSHeader(),
        // Search bar (only when visible)
        if (_model.isSearchVisible) _buildSearchBar(),
        // Navigation tabs
        _buildNavigationTabs(),
        // Chat list
        Expanded(
          child: _buildChatListContent(),
        ),
      ],
    );
  }

  Widget _buildIOSHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 60,
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Workspace switcher (Slack-style)
              _buildWorkspaceSwitcher(),
              SizedBox(width: 12),
              // App title
              Expanded(
                child: Text(
                  'Messages',
                  style: TextStyle(
                    fontFamily: 'System',
                    color: Color(0xFF1D1D1F),
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _model.isSearchVisible = !_model.isSearchVisible;
                        if (_model.isSearchVisible) {
                          // Focus on search field when opened
                          Future.delayed(Duration(milliseconds: 100), () {
                            _model.searchFocusNode?.requestFocus();
                          });
                        } else {
                          // Clear search when closed
                          _model.searchTextController?.clear();
                          chatController.updateSearchQuery('');
                        }
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.search,
                        color: _model.isSearchVisible
                            ? Color(0xFF007AFF)
                            : Color(0xFF1D1D1F),
                        size: 20,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _model.showGroupCreation = !_model.showGroupCreation;
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
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.add,
                        color: _model.showGroupCreation
                            ? Color(0xFF007AFF)
                            : Color(0xFF1D1D1F),
                        size: 20,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _model.showWorkspaceMembers =
                            !_model.showWorkspaceMembers;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.person_add,
                        color: _model.showWorkspaceMembers
                            ? Color(0xFF007AFF)
                            : Color(0xFF1D1D1F),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceSwitcher() {
    if (currentUserReference == null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.business,
          color: Color(0xFF8E8E93),
          size: 20,
        ),
      );
    }

    return StreamBuilder<UsersRecord>(
      stream: UsersRecord.getDocument(currentUserReference!),
      builder: (context, snapshot) {
        if (!snapshot.hasData || currentUserReference == null) {
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.business,
              color: Color(0xFF8E8E93),
              size: 20,
            ),
          );
        }

        final currentUser = snapshot.data!;

        // Get all workspace memberships
        return StreamBuilder<List<WorkspaceMembersRecord>>(
          stream: queryWorkspaceMembersRecord(
            queryBuilder: (q) =>
                q.where('user_ref', isEqualTo: currentUserReference),
          ),
          builder: (context, membershipSnapshot) {
            if (!membershipSnapshot.hasData) {
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.business,
                  color: Color(0xFF8E8E93),
                  size: 20,
                ),
              );
            }

            final memberships = membershipSnapshot.data!;

            // If no workspace, show placeholder
            if (!currentUser.hasCurrentWorkspaceRef()) {
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.business,
                  color: Color(0xFF8E8E93),
                  size: 20,
                ),
              );
            }

            // Show current workspace with switcher
            final workspaceRef = currentUser.currentWorkspaceRef;
            if (workspaceRef == null) {
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.business,
                  color: Color(0xFF8E8E93),
                  size: 20,
                ),
              );
            }

            return FutureBuilder<WorkspacesRecord>(
              future: WorkspacesRecord.getDocumentOnce(workspaceRef),
              builder: (context, workspaceSnapshot) {
                final workspaceName = workspaceSnapshot.hasData
                    ? workspaceSnapshot.data?.name ?? 'Loading...'
                    : 'Loading...';

                // If only one workspace, just show it (Slack style)
                if (memberships.length <= 1) {
                  final workspace = workspaceSnapshot.data;
                  final hasLogo = workspace?.logoUrl.isNotEmpty ?? false;

                  return Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasLogo ? Colors.white : Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Color(0xFFE5E7EB),
                        width: 0.5,
                      ),
                    ),
                    child: hasLogo
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: workspace?.logoUrl ?? '',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF007AFF),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Text(
                                  workspaceName.isNotEmpty
                                      ? workspaceName[0].toUpperCase()
                                      : 'W',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              workspaceName.isNotEmpty
                                  ? workspaceName[0].toUpperCase()
                                  : 'W',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  );
                }

                // Multiple workspaces - show dropdown (Slack style)
                final workspace = workspaceSnapshot.data;
                final hasLogo = workspace?.logoUrl.isNotEmpty ?? false;

                return PopupMenuButton<DocumentReference>(
                  offset: Offset(0, 50),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasLogo ? Colors.white : Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Color(0xFFE5E7EB),
                        width: 0.5,
                      ),
                    ),
                    child: hasLogo
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: workspace?.logoUrl ?? '',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF007AFF),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Text(
                                  workspaceName.isNotEmpty
                                      ? workspaceName[0].toUpperCase()
                                      : 'W',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              workspaceName.isNotEmpty
                                  ? workspaceName[0].toUpperCase()
                                  : 'W',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ),
                  onSelected: (workspaceRef) async {
                    // Update user's current workspace
                    final userRef = currentUserReference;
                    if (userRef != null) {
                      await userRef.update({
                        'current_workspace_ref': workspaceRef,
                      });

                      // Update chat controller with new workspace
                      try {
                        chatController.updateCurrentWorkspace(workspaceRef);
                      } catch (e) {
                        // ChatController not found
                      }

                      // Show confirmation
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Workspace switched'),
                          duration: Duration(seconds: 2),
                          backgroundColor: Color(0xFF34C759),
                        ),
                      );

                      // Refresh the page
                      safeSetState(() {});
                    }
                  },
                  itemBuilder: (context) {
                    return memberships.map((membership) {
                      return PopupMenuItem<DocumentReference>(
                        value: membership.workspaceRef,
                        child: FutureBuilder<WorkspacesRecord>(
                          future: WorkspacesRecord.getDocumentOnce(
                            membership.workspaceRef ??
                                FirebaseFirestore.instance
                                    .collection('workspaces')
                                    .doc('placeholder'),
                          ),
                          builder: (context, ws) {
                            final name = ws.hasData
                                ? ws.data?.name ?? 'Loading...'
                                : 'Loading...';
                            final isSelected =
                                currentUser.currentWorkspaceRef?.id ==
                                    membership.workspaceRef?.id;

                            return Container(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF007AFF),
                                      size: 16,
                                    ),
                                  if (isSelected) SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    }).toList();
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _showMessageMenu(MessagesRecord message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 5,
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            // Message menu options
            _buildMessageMenuOption(
              icon: Icons.copy_rounded,
              title: 'Copy',
              onTap: () {
                Navigator.pop(context);
                _copyMessage(message);
              },
            ),
            _buildMessageMenuOption(
              icon: Icons.emoji_emotions_rounded,
              title: 'React',
              onTap: () {
                Navigator.pop(context);
                _showEmojiMenu(message);
              },
            ),
            _buildMessageMenuOption(
              icon: Icons.report_gmailerrorred_rounded,
              title: 'Report',
              titleColor: Color(0xFFFF3B30),
              iconColor: Color(0xFFFF3B30),
              onTap: () {
                Navigator.pop(context);
                _reportMessage(message);
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? Color(0xFF1D1D1F),
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'System',
          color: titleColor ?? Color(0xFF1D1D1F),
          fontSize: 17,
          fontWeight: FontWeight.w400,
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _copyMessage(MessagesRecord message) async {
    final text = message.content.trim();
    if (text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied to clipboard',
          style: TextStyle(
            fontFamily: 'System',
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        duration: Duration(milliseconds: 1600),
        backgroundColor: Color(0xFF1D1D1F),
      ),
    );
  }

  Future<void> _showEmojiMenu(MessagesRecord message) async {
    final emojis = <String>[
      '👍',
      '👏',
      '🙌',
      '✅',
      '💯',
      '🔥',
      '❤️',
      '🤔',
      '👀',
      '🎉',
    ];

    // Show emoji row above the message bubble
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          // Invisible overlay to close when tapped
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Emoji row positioned above the message
          Positioned(
            bottom: MediaQuery.of(context).size.height *
                0.3, // Adjust position as needed
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: emojis.map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _saveReaction(message, emoji);
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 2),
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          emoji,
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveReaction(MessagesRecord message, String emoji) async {
    try {
      final userId = currentUserUid;
      final msgRef = message.reference;
      if (userId.isEmpty) return;

      await msgRef.update({
        'reactions_by_user.$userId': FieldValue.arrayUnion([emoji])
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reaction added'),
          duration: Duration(milliseconds: 1000),
          backgroundColor: Color(0xFF34C759),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding reaction'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
    }
  }

  Future<void> _reportMessage(MessagesRecord message) async {
    // Show confirmation dialog
    final shouldReport = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'Report Message',
            style: TextStyle(
              fontFamily: 'System',
              color: Color(0xFF1D1D1F),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to report this message? This action cannot be undone.',
            style: TextStyle(
              fontFamily: 'System',
              color: Color(0xFF8E8E93),
              fontSize: 15,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'System',
                  color: Color(0xFF8E8E93),
                  fontSize: 17,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Report',
                style: TextStyle(
                  fontFamily: 'System',
                  color: Color(0xFFFF3B30),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldReport == true) {
      // Here you would implement the actual reporting logic
      // For now, just show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message reported'),
          backgroundColor: Color(0xFF34C759),
        ),
      );
    }
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Color(0xFFF2F2F7), // iOS search bar color
          borderRadius: BorderRadius.circular(10),
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
            hintText: 'Search',
            hintStyle: TextStyle(
              fontFamily: 'System',
              color: Color(0xFF8E8E93),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            prefixIcon: Icon(
              Icons.search,
              color: Color(0xFF8E8E93),
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
                        Icons.clear,
                        color: Color(0xFF8E8E93),
                        size: 18,
                      ),
                    )
                  : GestureDetector(
                      onTap: () {
                        setState(() {
                          _model.isSearchVisible = false;
                          _model.searchTextController?.clear();
                          chatController.updateSearchQuery('');
                        });
                      },
                      child: Icon(
                        Icons.close,
                        color: Color(0xFF8E8E93),
                        size: 18,
                      ),
                    );
            }),
          ),
          style: TextStyle(
            fontFamily: 'System',
            color: Color(0xFF1D1D1F),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationTabs() {
    return Container(
      height: 44,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildTab('Direct Message', 0)),
          SizedBox(width: 8),
          Expanded(child: _buildTab('Groups', 1)),
        ],
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
        height: 32,
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF007AFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'System',
              color: isSelected ? Colors.white : Color(0xFF8E8E93),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatListContent() {
    return Obx(() {
      switch (chatController.chatState.value) {
        case ChatState.loading:
          return Center(
            child: CircularProgressIndicator(
              color: Color(0xFF007AFF),
            ),
          );

        case ChatState.error:
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Color(0xFFFF3B30),
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'Error loading chats',
                  style: TextStyle(
                    fontFamily: 'System',
                    color: Color(0xFF1D1D1F),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  chatController.errorMessage.value,
                  style: TextStyle(
                    fontFamily: 'System',
                    color: Color(0xFF8E8E93),
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => chatController.refreshChats(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      fontFamily: 'System',
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                    color: Color(0xFF8E8E93),
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No search results',
                    style: TextStyle(
                      fontFamily: 'System',
                      color: Color(0xFF1D1D1F),
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Try a different search term',
                    style: TextStyle(
                      fontFamily: 'System',
                      color: Color(0xFF8E8E93),
                      fontSize: 15,
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
            itemCount: filteredChats.length,
            itemBuilder: (context, index) {
              final chat = filteredChats[index];
              final isSelected = chatController.selectedChat.value?.reference ==
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
                        return SizedBox.shrink();
                      }
                    }

                    return _MobileChatListItem(
                      key: ValueKey('chat_item_${chat.reference.id}'),
                      chat: chat,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _model.selectedChat = chat;
                        });
                        chatController.selectChat(chat);
                        // Notify parent that chat is opened
                        widget.onChatStateChanged?.call(true);
                      },
                      hasUnreadMessages: chatController.hasUnreadMessages(chat),
                    );
                  },
                );
              }

              return _MobileChatListItem(
                key: ValueKey('chat_item_${chat.reference.id}'),
                chat: chat,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _model.selectedChat = chat;
                  });
                  chatController.selectChat(chat);
                  // Notify parent that chat is opened
                  widget.onChatStateChanged?.call(true);
                },
                hasUnreadMessages: chatController.hasUnreadMessages(chat),
              );
            },
          );
      }
    });
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
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFFF2F2F7),
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFE5E7EB),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.group,
                color: Color(0xFF007AFF),
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Workspace Members',
                  style: TextStyle(
                    fontFamily: 'System',
                    color: Color(0xFF1D1D1F),
                    fontSize: 17,
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
                    color: Color(0xFF8E8E93),
                    size: 20,
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
                    color: Color(0xFF007AFF),
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
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              bottom: BorderSide(
                                color: Color(0xFFE5E7EB),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Color(0xFF007AFF),
                                  shape: BoxShape.circle,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(25),
                                  child: CachedNetworkImage(
                                    imageUrl: user.photoUrl,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 100,
                                    memCacheHeight: 100,
                                    maxWidthDiskCache: 100,
                                    maxHeightDiskCache: 100,
                                    filterQuality: FilterQuality.high,
                                    placeholder: (context, url) => Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: Color(0xFF8E8E93),
                                        size: 24,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: Color(0xFF8E8E93),
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              // User Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            user.displayName,
                                            style: TextStyle(
                                              fontFamily: 'System',
                                              color: Color(0xFF1D1D1F),
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getRoleColor(member.role),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            member.role.toUpperCase(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      user.email,
                                      style: TextStyle(
                                        fontFamily: 'System',
                                        color: Color(0xFF8E8E93),
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Tap to start a chat',
                                      style: TextStyle(
                                        fontFamily: 'System',
                                        color: Color(0xFF007AFF),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Chat icon
                              Icon(
                                Icons.chat_bubble_outline,
                                color: Color(0xFF007AFF),
                                size: 20,
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
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFFF2F2F7),
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFE5E7EB),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.group_add,
                color: Color(0xFF007AFF),
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Create New Group',
                  style: TextStyle(
                    fontFamily: 'System',
                    color: Color(0xFF1D1D1F),
                    fontSize: 17,
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
                  color: Color(0xFF8E8E93),
                  size: 20,
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
                    fontFamily: 'System',
                    color: Color(0xFF1D1D1F),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Color(0xFFE5E7EB),
                      width: 0.5,
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
                        fontFamily: 'System',
                        color: Color(0xFF8E8E93),
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    style: TextStyle(
                      fontFamily: 'System',
                      color: Color(0xFF1D1D1F),
                      fontSize: 16,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                // Group image upload
                Text(
                  'Group Image (Optional)',
                  style: TextStyle(
                    fontFamily: 'System',
                    color: Color(0xFF1D1D1F),
                    fontSize: 17,
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
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Color(0xFFE5E7EB),
                            width: 0.5,
                          ),
                        ),
                        child: _model.isUploadingImage
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF007AFF),
                                  strokeWidth: 2,
                                ),
                              )
                            : _model.groupImageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedNetworkImage(
                                      imageUrl: _model.groupImageUrl!,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 160,
                                      memCacheHeight: 160,
                                      maxWidthDiskCache: 160,
                                      maxHeightDiskCache: 160,
                                      filterQuality: FilterQuality.high,
                                      placeholder: (context, url) => Container(
                                        width: 80,
                                        height: 80,
                                        color: Color(0xFFF2F2F7),
                                        child: Icon(
                                          Icons.image,
                                          color: Color(0xFF8E8E93),
                                          size: 24,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        width: 80,
                                        height: 80,
                                        color: Color(0xFFF2F2F7),
                                        child: Icon(
                                          Icons.image,
                                          color: Color(0xFF8E8E93),
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
                                        color: Color(0xFF8E8E93),
                                        size: 24,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Add Image',
                                        style: TextStyle(
                                          fontFamily: 'System',
                                          color: Color(0xFF8E8E93),
                                          fontSize: 12,
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
                              fontFamily: 'System',
                              color: _model.groupImageUrl != null
                                  ? Color(0xFF34C759)
                                  : Color(0xFF8E8E93),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _model.isUploadingImage
                                    ? null
                                    : _pickGroupImage,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _model.isUploadingImage
                                        ? Color(0xFF8E8E93)
                                        : Color(0xFF007AFF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _model.groupImageUrl != null
                                        ? 'Change'
                                        : 'Select',
                                    style: TextStyle(
                                      fontFamily: 'System',
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
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
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFFF3B30),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Remove',
                                      style: TextStyle(
                                        fontFamily: 'System',
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
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
                    fontFamily: 'System',
                    color: Color(0xFF1D1D1F),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                // Workspace members list for selection
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Color(0xFFE5E7EB),
                      width: 0.5,
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
                            color: Color(0xFF007AFF),
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
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Color(0xFF007AFF)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? Color(0xFF007AFF)
                                          : Color(0xFFE5E7EB),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Color(0xFF007AFF),
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
                                            memCacheWidth: 80,
                                            memCacheHeight: 80,
                                            maxWidthDiskCache: 80,
                                            maxHeightDiskCache: 80,
                                            filterQuality: FilterQuality.high,
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
                                                color: Color(0xFF8E8E93),
                                                size: 18,
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
                                                color: Color(0xFF8E8E93),
                                                size: 18,
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
                                            Text(
                                              user.displayName,
                                              style: TextStyle(
                                                fontFamily: 'System',
                                                color: isSelected
                                                    ? Colors.white
                                                    : Color(0xFF1D1D1F),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              user.email,
                                              style: TextStyle(
                                                fontFamily: 'System',
                                                color: isSelected
                                                    ? Colors.white70
                                                    : Color(0xFF8E8E93),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 20,
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
                          ? Color(0xFF007AFF)
                          : Color(0xFF8E8E93),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Create Group',
                      style: TextStyle(
                        fontFamily: 'System',
                        color: Colors.white,
                        fontSize: 17,
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
        return Color(0xFFFF3B30); // Red
      case 'moderator':
        return Color(0xFF34C759); // Green
      case 'member':
        return Color(0xFF8E8E93); // Gray
      default:
        return Color(0xFF8E8E93); // Default gray
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
        // Notify parent that chat is opened
        widget.onChatStateChanged?.call(true);
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
        // Notify parent that chat is opened
        widget.onChatStateChanged?.call(true);
      }
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting chat: $e'),
          backgroundColor: Color(0xFFFF3B30),
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
          backgroundColor: Color(0xFFFF3B30),
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
          backgroundColor: Color(0xFF34C759),
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
          backgroundColor: Color(0xFFFF3B30),
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
            backgroundColor: Color(0xFFFF3B30),
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
      // Notify parent that chat is opened
      widget.onChatStateChanged?.call(true);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Group "${_model.groupName}" created successfully!'),
          backgroundColor: Color(0xFF34C759),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating group: $e'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
    }
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
                color: Color(0xFF8E8E93),
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
                color: Color(0xFF8E8E93),
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
              color: Color(0xFF007AFF),
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
                    color: Color(0xFF8E8E93),
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
                    color: Color(0xFF8E8E93),
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
          fontFamily: 'System',
          color: Color(0xFF1D1D1F),
          fontSize: 17,
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
              fontFamily: 'System',
              color: Color(0xFF1D1D1F),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      );
    }
  }

  void _showChatOptions(ChatsRecord chat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 5,
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            if (chat.isGroup) ...[
              _buildOptionTile(
                icon: Icons.group,
                title: 'View Group Chat',
                onTap: () {
                  Navigator.pop(context);
                  _viewGroupChat(chat);
                },
              ),
            ] else ...[
              _buildOptionTile(
                icon: Icons.person,
                title: 'View User Profile',
                onTap: () {
                  Navigator.pop(context);
                  _viewUserProfile(chat);
                },
              ),
              _buildOptionTile(
                icon: Icons.block,
                title: 'Block User',
                titleColor: Color(0xFFFF3B30),
                iconColor: Color(0xFFFF3B30),
                onTap: () {
                  Navigator.pop(context);
                  _blockUser(chat);
                },
              ),
            ],
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? Color(0xFF1D1D1F),
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'System',
          color: titleColor ?? Color(0xFF1D1D1F),
          fontSize: 17,
          fontWeight: FontWeight.w400,
        ),
      ),
      onTap: onTap,
    );
  }

  void _viewUserProfile(ChatsRecord chat) async {
    if (chat.isGroup) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Group chat - no user profile to view'),
          backgroundColor: Color(0xFF8E8E93),
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
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
    }
  }

  void _blockUser(ChatsRecord chat) async {
    if (chat.isGroup) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot block group chats'),
          backgroundColor: Color(0xFF8E8E93),
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
            backgroundColor: Colors.white,
            title: Text(
              'Block User',
              style: TextStyle(
                fontFamily: 'System',
                color: Color(0xFF1D1D1F),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              'Are you sure you want to block ${user.displayName}? You will no longer see their messages or be able to contact them.',
              style: TextStyle(
                fontFamily: 'System',
                color: Color(0xFF8E8E93),
                fontSize: 15,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'System',
                    color: Color(0xFF8E8E93),
                    fontSize: 17,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Block',
                  style: TextStyle(
                    fontFamily: 'System',
                    color: Color(0xFFFF3B30),
                    fontSize: 17,
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
            backgroundColor: Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error blocking user'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
    }
  }

  void _viewGroupChat(ChatsRecord chat) async {
    if (!chat.isGroup) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This is not a group chat'),
          backgroundColor: Color(0xFF8E8E93),
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
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
    }
  }
}

// iOS-optimized chat list item widget
class _MobileChatListItem extends StatefulWidget {
  final ChatsRecord chat;
  final bool isSelected;
  final VoidCallback onTap;
  final bool hasUnreadMessages;

  const _MobileChatListItem({
    Key? key,
    required this.chat,
    required this.isSelected,
    required this.onTap,
    required this.hasUnreadMessages,
  }) : super(key: key);

  @override
  _MobileChatListItemState createState() => _MobileChatListItemState();
}

class _MobileChatListItemState extends State<_MobileChatListItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return InkWell(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFE5E7EB),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            _buildChatAvatar(widget.chat),
            SizedBox(width: 12),
            // Chat Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _getChatDisplayName(widget.chat),
                  SizedBox(height: 4),
                  _getLastMessagePreview(widget.chat),
                ],
              ),
            ),
            // Timestamp and notification dot
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Timestamp
                Text(
                  widget.chat.lastMessageAt != null
                      ? timeago.format(widget.chat.lastMessageAt!)
                      : 'Unknown',
                  style: TextStyle(
                    fontFamily: 'System',
                    color: Color(0xFF8E8E93),
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 4),
                // Notification dot for unread messages
                if (widget.hasUnreadMessages)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Color(0xFF007AFF),
                      shape: BoxShape.circle,
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
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: CachedNetworkImage(
            imageUrl: chat.chatImageUrl,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            memCacheWidth: 100,
            memCacheHeight: 100,
            maxWidthDiskCache: 100,
            maxHeightDiskCache: 100,
            filterQuality: FilterQuality.high,
            placeholder: (context, url) => Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group,
                color: Color(0xFF8E8E93),
                size: 24,
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group,
                color: Color(0xFF8E8E93),
                size: 24,
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
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Color(0xFF007AFF),
              shape: BoxShape.circle,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                memCacheWidth: 100,
                memCacheHeight: 100,
                maxWidthDiskCache: 100,
                maxHeightDiskCache: 100,
                filterQuality: FilterQuality.high,
                placeholder: (context, url) => Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: Color(0xFF8E8E93),
                    size: 24,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: Color(0xFF8E8E93),
                    size: 24,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
  }

  Widget _getChatDisplayName(ChatsRecord chat) {
    if (chat.isGroup) {
      return Text(
        chat.title.isNotEmpty ? chat.title : 'Group Chat',
        style: TextStyle(
          fontFamily: 'System',
          color: Color(0xFF1D1D1F),
          fontSize: 17,
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
              fontFamily: 'System',
              color: Color(0xFF1D1D1F),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      );
    }
  }

  Widget _getLastMessagePreview(ChatsRecord chat) {
    if (chat.lastMessage.isEmpty) {
      return Text(
        'No messages',
        style: TextStyle(
          fontFamily: 'System',
          color: Color(0xFF8E8E93),
          fontSize: 15,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text(
      chat.lastMessage,
      style: TextStyle(
        fontFamily: 'System',
        color: Color(0xFF8E8E93),
        fontSize: 15,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
