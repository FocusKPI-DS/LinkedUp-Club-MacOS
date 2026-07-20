import '/auth/firebase_auth/auth_util.dart';
import '/utils/debug_log.dart';
import '/utils/desktop_pointer.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/pages/desktop_chat/new_message_dialog.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/chat_helpers.dart';
import '/pages/desktop_chat/desktop_safe_user_builder.dart';
import '/pages/desktop_chat/windows_chat_list_labels.dart';
import '/pages/desktop_chat/windows_firestore_gate.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';
import '/pages/chat/chat_component/chat_thread_component/chat_thread_component_widget.dart';
import '/pages/chat/chat_component/task_reminder_digest_card.dart';
import '/pages/desktop_chat/desktop_chat_model.dart';
import '/pages/desktop_chat/chat_controller.dart';
import '/pages/chat/user_profile_detail/user_profile_detail_widget.dart';
import '/pages/chat/group_chat_detail/group_chat_detail_widget.dart';
import '/pages/chat/group_chat_detail/meeting_transcripts_panel_widget.dart';
import '/pages/chat/group_action_tasks/group_action_tasks_widget.dart';
import '/pages/chat/add_group_members/add_group_members_dialog.dart';
import '/pages/chat/group_chat_detail/group_media_links_docs_widget.dart';
import '/pages/chat/chat_history/chat_history_widget.dart';
import '/pages/chat/chat_component/group_announcements_widget.dart';
import '/pages/chat/all_pending_requests/all_pending_requests_widget.dart';
import '/pages/chat/user_profile_popup/user_profile_popup.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, listEquals;
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '/utils/qurio_url_launcher.dart';
import '/component/meeting_banner/meeting_banner_widget.dart';
import '/custom_code/services/meeting_service.dart';
import '/custom_code/services/google_meet_creator.dart';
import 'package:branchio_dynamic_linking_akp5u6/custom_code/actions/index.dart'
    as branchio_dynamic_linking_akp5u6_actions;
import 'package:branchio_dynamic_linking_akp5u6/flutter_flow/custom_functions.dart'
    as branchio_dynamic_linking_akp5u6_functions;
import '/custom_code/actions/index.dart' as actions;
import '/backend/cloud_functions/callable_functions.dart';

/// Lona Service logo — Storage `lona-logo.png` currently 404s; use the site logo.
const String _kLonaServiceLogoUrl = 'https://lona.club/logo.png';

bool _isBrokenLonaServiceLogoUrl(String url) {
  return url.contains('lona-logo.png');
}

String _lonaServiceAvatarUrl(ChatsRecord chat) {
  final stored = chat.chatImageUrl;
  if (stored.isNotEmpty && !_isBrokenLonaServiceLogoUrl(stored)) {
    return stored;
  }
  return _kLonaServiceLogoUrl;
}

Widget _buildLonaServiceAvatar({
  required double size,
  ChatsRecord? chat,
}) {
  final imageUrl =
      chat != null ? _lonaServiceAvatarUrl(chat) : _kLonaServiceLogoUrl;
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
    ),
    clipBehavior: Clip.antiAlias,
    child: CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: size,
      height: size,
      memCacheWidth: (size * 2).round(),
      memCacheHeight: (size * 2).round(),
      placeholder: (context, url) => Image.asset(
        'assets/images/Logo_2.png',
        fit: BoxFit.cover,
        width: size,
        height: size,
      ),
      errorWidget: (context, url, error) => Image.asset(
        'assets/images/Logo_2.png',
        fit: BoxFit.cover,
        width: size,
        height: size,
      ),
    ),
  );
}

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
  final _chatThreadKey = GlobalKey<ChatThreadComponentWidgetState>();

  // Sliding underline for group chat header tabs
  final GlobalKey _groupTabRowKey = GlobalKey();
  final List<GlobalKey> _groupTabKeys = List<GlobalKey>.generate(
    GroupChatTab.values.length,
    (_) => GlobalKey(),
  );
  double _groupTabIndicatorLeft = 0;
  double _groupTabIndicatorWidth = 0;
  bool _groupTabIndicatorReady = false;

  // Multi-message selection state
  bool _isSelectionMode = false;
  final Set<MessagesRecord> _selectedMessages = {};

  /// Defer group-only Firestore widgets on Windows until the thread is stable.
  bool _windowsGroupExtrasReady = false;
  Timer? _windowsGroupExtrasTimer;
  Timer? _chatFoldersPollTimer;

  bool get _showWindowsGroupExtras {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS) return true;
    if (Platform.isWindows || Platform.isLinux) return _windowsGroupExtrasReady;
    return true;
  }

  void _onWindowsThreadOpened() {
    if (kIsWeb || !(Platform.isWindows || Platform.isLinux)) return;
    _windowsGroupExtrasReady = false;
    _windowsGroupExtrasTimer?.cancel();
    _model.chatFoldersSubscription?.cancel();
    _model.chatFoldersSubscription = null;
    _chatFoldersPollTimer?.cancel();
    _chatFoldersPollTimer = null;
    _windowsGroupExtrasTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _windowsGroupExtrasReady = true);
    });
  }

  void _onWindowsThreadClosed() {
    if (kIsWeb || !(Platform.isWindows || Platform.isLinux)) return;
    _windowsGroupExtrasTimer?.cancel();
    if (mounted) setState(() => _windowsGroupExtrasReady = false);
    // Restart folder polling after leaving a thread. This runs on the REST
    // poll path (useOnceFetch), which is safe on Windows/Linux — the previous
    // guard made this a no-op and left folders stale after opening a chat.
    _subscribeToChatFolders();
  }

  Widget _buildPlatformChatThread({Key? key}) {
    final chat = _model.selectedChat;
    if (chat == null) {
      return const Center(child: Text('Select a conversation'));
    }
    return ChatThreadComponentWidget(
      key: key ?? _chatThreadKey,
      chatReference: chat,
      activeSelectionId: ValueNotifier(null),
      onMessageAction: _handleDesktopMessageAction,
      onSidebarPreviewUpdate: chatController.applyLocalChatLastMessageFromPatch,
      onMessagesMutated: () => chatController.refreshChats(force: true),
      isSelectionMode: _isSelectionMode,
      selectedMessages: _selectedMessages,
      onMessageToggled: _toggleMessageSelection,
    );
  }

  void _toggleMessageSelection(MessagesRecord message) {
    setState(() {
      if (_selectedMessages
          .map((m) => m.reference.id)
          .contains(message.reference.id)) {
        _selectedMessages
            .removeWhere((m) => m.reference.id == message.reference.id);
        if (_selectedMessages.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessages.add(message);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessages.clear();
    });
  }

  Future<UsersRecord> _getOrCreateUserFuture(DocumentReference ref) =>
      chatController.getOrCreateUserFuture(ref);

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
    // Reuse existing controller when switching back to Chat tab.
    try {
      chatController = Get.find<ChatController>();
    } catch (_) {
      chatController = Get.put(ChatController(), permanent: true);
    }

    _model.tabController = TabController(
      vsync: this,
      length: 2, // All, Unread
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
            _model.groupChatTab = GroupChatTab.messages;
            // Set the selected chat
            _model.selectedChat = selectedChat;
            debugLog(
                'DesktopChat: Synced selectedChat to model: ${selectedChat.reference.id}');
            _onWindowsThreadOpened();
          } else {
            _model.selectedChat = null;
            _onWindowsThreadClosed();
            chatController.resumeListListeners();
          }
        });
      }
    });

    // Initialize presence system after a delay to ensure user is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (DesktopSafeUserBuilder.useOnceFetch) {
        debugLog(
            '🪟 [DesktopChat] Windows chat tab opened (poll mode, no list streams)');
      }
      Future.delayed(Duration(milliseconds: 500), () {
        if (!DesktopSafeUserBuilder.useOnceFetch) {
          _initializePresence();
        }
        // Load chat folders on every platform. On Windows/Linux this uses the
        // REST poll path (no live streams), so it's safe under useOnceFetch.
        // Without this, previously created folders wouldn't appear until the
        // user created a new folder (which triggers a manual refresh).
        _subscribeToChatFolders();
      });
      // Clear dock badge when chat page is opened (macOS)
      if (!kIsWeb && Platform.isMacOS) {
        actions.clearAppBadge();
      }
    });
  }

  /// Fetches the latest folders from the backend and updates state right away.
  /// Used after creating a folder so it appears without waiting for the poll
  /// timer (Windows/Linux) or stream event. If the fetch returns nothing (or
  /// throws), [fallback] performs an optimistic local update.
  Future<void> _refreshChatFoldersNow({VoidCallback? fallback}) async {
    if (currentUserReference == null) return;
    try {
      final folders = await fsQueryChatFolders(currentUserReference!);
      if (!mounted) return;
      setState(() {
        if (folders.isNotEmpty) {
          _model.chatFolders = folders;
        } else {
          fallback?.call();
        }
      });
    } catch (e) {
      debugLog('Error refreshing chat folders after create: $e');
      if (mounted && fallback != null) {
        setState(fallback);
      }
    }
  }

  ChatFoldersRecord _folderWithCollapsed(
    ChatFoldersRecord folder,
    bool isCollapsed,
  ) {
    return ChatFoldersRecord.getDocumentFromData(
      {
        ...folder.snapshotData,
        'is_collapsed': isCollapsed,
      },
      folder.reference,
    );
  }

  ChatFoldersRecord _folderWithName(
    ChatFoldersRecord folder,
    String name,
  ) {
    return ChatFoldersRecord.getDocumentFromData(
      {
        ...folder.snapshotData,
        'name': name,
        'updated_at': getCurrentTimestamp,
      },
      folder.reference,
    );
  }

  ChatFoldersRecord _folderWithChatIds(
    ChatFoldersRecord folder,
    List<String> chatIds,
  ) {
    return ChatFoldersRecord.getDocumentFromData(
      {
        ...folder.snapshotData,
        'chat_ids': chatIds,
        'updated_at': getCurrentTimestamp,
      },
      folder.reference,
    );
  }

  /// Updates folder membership in local state so the sidebar moves chats
  /// immediately (Windows polls folders every 30s without this).
  void _applyLocalChatFolderMembership({
    required Iterable<String> chatIds,
    String? targetFolderId,
  }) {
    final ids = chatIds.toSet();
    setState(() {
      _model.chatFolders = _model.chatFolders.map((folder) {
        var next = folder.chatIds.where((id) => !ids.contains(id)).toList();
        if (targetFolderId != null && folder.reference.id == targetFolderId) {
          for (final id in ids) {
            if (!next.contains(id)) next.add(id);
          }
        }
        if (listEquals(next, folder.chatIds)) return folder;
        return _folderWithChatIds(folder, next);
      }).toList();
    });
  }

  void _applyLocalRemoveChatsFromOtherFolders(
    Iterable<String> chatIds, {
    required String exceptFolderId,
  }) {
    final ids = chatIds.toSet();
    setState(() {
      _model.chatFolders = _model.chatFolders.map((folder) {
        if (folder.reference.id == exceptFolderId) return folder;
        final next = folder.chatIds.where((id) => !ids.contains(id)).toList();
        if (listEquals(next, folder.chatIds)) return folder;
        return _folderWithChatIds(folder, next);
      }).toList();
    });
  }

  Future<void> _handleRenameFolder(
    ChatFoldersRecord folder,
    String newName,
  ) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == folder.name) return;

    final previousFolders = _model.chatFolders;
    setState(() {
      _model.chatFolders = _model.chatFolders.map((f) {
        if (f.reference.id != folder.reference.id) return f;
        return _folderWithName(f, trimmed);
      }).toList();
    });

    try {
      await fsPatchDocument(folder.reference, {
        'name': trimmed,
        'updated_at': getCurrentTimestamp,
      });
    } catch (e) {
      debugLog('❌ Error renaming folder: $e');
      if (mounted) {
        setState(() => _model.chatFolders = previousFolders);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error renaming folder: $e'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _toggleFolderCollapsed(ChatFoldersRecord folder) {
    final nextCollapsed = !folder.isCollapsed;
    setState(() {
      _model.chatFolders = _model.chatFolders.map((f) {
        if (f.reference.id != folder.reference.id) return f;
        return _folderWithCollapsed(f, nextCollapsed);
      }).toList();
    });
    fsPatchDocument(folder.reference, {'is_collapsed': nextCollapsed});
  }

  /// Deletes a folder and removes it from the sidebar immediately. On
  /// Windows/Linux the folder list only refreshes via a 30s poll, so without
  /// the optimistic removal the folder would linger until the next poll.
  Future<void> _deleteFolder(ChatFoldersRecord folder) async {
    final previousFolders = _model.chatFolders;
    setState(() {
      _model.chatFolders = _model.chatFolders
          .where((f) => f.reference.id != folder.reference.id)
          .toList();
    });
    try {
      await fsDeleteDocument(folder.reference);
    } catch (e) {
      debugLog('❌ Error deleting folder: $e');
      // Restore on failure so the UI reflects the real state.
      if (mounted) {
        setState(() => _model.chatFolders = previousFolders);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting folder: $e'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _subscribeToChatFolders() {
    if (currentUserReference == null) return;
    _model.chatFoldersSubscription?.cancel();
    _chatFoldersPollTimer?.cancel();

    if (useWindowsFirestoreRest) {
      Future<void> poll() async {
        try {
          final folders = await fsQueryChatFolders(currentUserReference!);
          if (mounted) {
            setState(() {
              _model.chatFolders = folders;
            });
          }
        } catch (e) {
          debugLog('Error polling chat folders: $e');
        }
      }

      poll();
      _chatFoldersPollTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => poll(),
      );
      return;
    }

    _model.chatFoldersSubscription = queryChatFoldersRecord(
      parent: currentUserReference,
      queryBuilder: (q) => q.orderBy('order'),
    ).listen((folders) {
      if (mounted) {
        setState(() {
          _model.chatFolders = folders;
        });
      }
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
      fsGetUserOnce(currentUserReference!).then((user) {
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
      await fsPatchDocument(currentUserReference!, {
        'is_online': isOnline,
      });
    } catch (e) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (DesktopSafeUserBuilder.useOnceFetch) return;
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
    _windowsGroupExtrasTimer?.cancel();
    _chatFoldersPollTimer?.cancel();
    _selectedChatSubscription?.cancel();
    if (!DesktopSafeUserBuilder.useOnceFetch) {
      _updateOnlineStatus(false);
    }
    _model.dispose();
    // DON'T delete ChatController - keep it persistent across navigation
    // This preserves knownUnreadChats and locallySeenChats state
    // The controller will be cleaned up when app closes
    // Get.delete<ChatController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Do NOT call _trackActivity() from build() - it runs on every rebuild and
    // causes high CPU and Idle Wake Ups. Activity is tracked on tap/pan and lifecycle.

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
                  _buildGroupFoldersToggle(),
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
                ).withClickCursor(),
              ),
            ),
          // Collapsed avatar list (shown when collapsed)
          if (_model.isSidebarCollapsed)
            Positioned.fill(
              child: Container(
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
                  children: [
                    // Expand button at top
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _model.isSidebarCollapsed = false;
                            });
                          },
                          child: Tooltip(
                            message: 'Expand sidebar',
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Color(0xFFE5E7EB), width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF64748B),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: Color.fromRGBO(230, 235, 245, 1)),
                    // Scrollable avatar list
                    Expanded(
                      child: Obx(() {
                        if (!_sidebarListReady) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: Color.fromARGB(255, 16, 184, 239),
                            ),
                          );
                        }

                        final filteredChats = chatController.filteredChats;
                        return ListView.builder(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          itemCount: filteredChats.length,
                          itemBuilder: (context, index) {
                            final chat = filteredChats[index];
                            final isSelected =
                                chatController.selectedChat.value?.reference ==
                                    chat.reference;
                            return Obx(() {
                              final _ = chatController.chats.length;
                              final __ = chatController.locallySeenChats.length;
                              final ___ =
                                  chatController.knownUnreadChats.length;
                              final hasUnread =
                                  chatController.hasUnreadMessages(chat);

                              // Get display name for tooltip
                              String displayName = '';
                              if (chat.isGroup) {
                                displayName = chat.title.isNotEmpty
                                    ? chat.title
                                    : 'Group Chat';
                              } else {
                                final otherRef = chat.members.firstWhere(
                                  (m) => m != currentUserReference,
                                  orElse: () => chat.members.first,
                                );
                                displayName = chatController
                                        .getCachedDisplayName(otherRef.id) ??
                                    'Chat';
                              }

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3),
                                child: Center(
                                  child: Tooltip(
                                    message: displayName,
                                    waitDuration: Duration(milliseconds: 300),
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _clearAllViews();
                                            _model.selectedChat = chat;
                                          });
                                          chatController.selectChat(chat);
                                        },
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            // Avatar with selection ring
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: isSelected
                                                    ? Border.all(
                                                        color:
                                                            Color(0xFF3B82F6),
                                                        width: 2)
                                                    : null,
                                              ),
                                              child: Padding(
                                                padding: EdgeInsets.all(
                                                    isSelected ? 2 : 0),
                                                child:
                                                    _buildCollapsedAvatar(chat),
                                              ),
                                            ),
                                            // Unread dot
                                            if (hasUnread)
                                              Positioned(
                                                right: -2,
                                                top: -2,
                                                child: Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: BoxDecoration(
                                                    color: Color(0xFF3B82F6),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                        color: Colors.white,
                                                        width: 2),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            });
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCollapsedAvatar(ChatsRecord chat) {
    const double size = 36;
    if (chat.isServiceChat) {
      return _buildLonaServiceAvatar(size: size, chat: chat);
    }
    if (chat.isGroup) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Color(0xFFE5E7EB), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: chat.chatImageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: chat.chatImageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                memCacheWidth: 72,
                memCacheHeight: 72,
                placeholder: (context, url) => Center(
                  child: Icon(Icons.group, color: Color(0xFF6B7280), size: 18),
                ),
                errorWidget: (context, url, error) => Center(
                  child: Icon(Icons.group, color: Color(0xFF6B7280), size: 18),
                ),
              )
            : Center(
                child: Icon(Icons.group, color: Color(0xFF6B7280), size: 18),
              ),
      );
    } else {
      final otherUserRef = chat.members.firstWhere(
        (member) => member != currentUserReference,
        orElse: () => chat.members.first,
      );

      return DesktopSafeUserBuilder(
        userRef: otherUserRef,
        fetchOnce: _getOrCreateUserFuture,
        builder: (context, userSnapshot) {
          String imageUrl = '';
          if (otherUserRef.path.contains('ai_agent_summerai')) {
            imageUrl =
                'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120';
          } else if (userSnapshot != null) {
            imageUrl = userSnapshot.photoUrl;
          }

          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Color(0xFF3B82F6),
              shape: BoxShape.circle,
              border: Border.all(color: Color(0xFFE5E7EB), width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size / 2),
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      memCacheWidth: 72,
                      memCacheHeight: 72,
                      placeholder: (context, url) => Container(
                        color: Color(0xFFE5E7EB),
                        child: Icon(Icons.person,
                            color: Color(0xFF9CA3AF), size: 18),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Color(0xFFE5E7EB),
                        child: Icon(Icons.person,
                            color: Color(0xFF9CA3AF), size: 18),
                      ),
                    )
                  : Container(
                      color: Color(0xFFE5E7EB),
                      child: Icon(Icons.person,
                          color: Color(0xFF9CA3AF), size: 18),
                    ),
            ),
          );
        },
      );
    }
  }

  Widget _buildHeader() {
    final isChatMode =
        !kShowFoldersSidebar || _model.sidebarMode == SidebarMode.chat;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color.fromRGBO(
            250, 252, 255, 1), // Very light cyan tint, close to white
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            // App Name — match Settings page header
            Expanded(
              child: Text(
                isChatMode ? 'Chat' : 'Folders',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  color: Color(0xFF1A1A1A),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8),
            // Mode switch icons (folders toggle hidden via kShowFoldersSidebar)
            if (kShowFoldersSidebar)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModeIcon(
                    icon: CupertinoIcons.chat_bubble_2_fill,
                    tooltip: 'Chat',
                    isActive: isChatMode,
                    onTap: () =>
                        setState(() => _model.sidebarMode = SidebarMode.chat),
                  ),
                  SizedBox(width: 4),
                  _buildModeIcon(
                    icon: CupertinoIcons.folder_fill,
                    tooltip: 'Folders',
                    isActive: !isChatMode,
                    onTap: () => setState(
                        () => _model.sidebarMode = SidebarMode.folders),
                  ),
                  SizedBox(width: 8),
                ],
              ),
            // New chat menu
            PopupMenuButton<int>(
              offset: const Offset(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
              color: Colors.white,
              elevation: 8,
              tooltip: 'Create new',
              onSelected: (value) {
                if (value == 1) {
                  _clearAllViews();
                  _model.selectedChat = null;
                  chatController.selectedChat.value = null;
                  _showNewMessageDialog();
                } else if (value == 2) {
                  _showCreateFolderDialog();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<int>(
                  value: 1,
                  mouseCursor: SystemMouseCursors.click,
                  child: desktopClickableMenuChild(
                    Row(
                      children: [
                        Icon(Icons.maps_ugc_rounded,
                            color: Color(0xFF3B82F6), size: 20),
                        SizedBox(width: 12),
                        Text(
                          'New Message',
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
                ),
                PopupMenuDivider(height: 1),
                PopupMenuItem<int>(
                  value: 2,
                  mouseCursor: SystemMouseCursors.click,
                  child: desktopClickableMenuChild(
                    Row(
                      children: [
                        Icon(Icons.create_new_folder_rounded,
                            color: Color(0xFF3B82F6), size: 20),
                        SizedBox(width: 12),
                        Text(
                          'New Folder',
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
                ),
              ],
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.add_rounded,
                    color: Color(0xFF374151),
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeIcon({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isActive
                  ? Color(0xFF3B82F6).withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isActive ? Color(0xFF3B82F6) : Color(0xFF9CA3AF),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: double.infinity,
      padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _model.searchFocusNode?.hasFocus == true
                ? Color(0xFF3B82F6)
                : Color.fromRGBO(230, 235, 245, 1),
            width: _model.searchFocusNode?.hasFocus == true ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(
                Icons.search,
                color: Color(0xFF9CA3AF),
                size: 16,
              ),
            ),
            Expanded(
              child: TextFormField(
                controller: _model.searchTextController,
                focusNode: _model.searchFocusNode,
                onChanged: (value) {
                  EasyDebounce.debounce(
                    'searchTextController',
                    Duration(milliseconds: 500),
                    () => chatController.updateSearchQuery(value),
                  );
                  setState(() {
                    _model.showQuickSearch = value.isNotEmpty;
                    _model.showFullSearch =
                        false; // Reset full search on new input
                  });
                },
                onFieldSubmitted: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _model.showQuickSearch = false;
                      _model.showFullSearch = true;
                    });
                    chatController.updateSearchQuery(value);
                  }
                },
                onTap: () {
                  setState(() {
                    if (chatController.searchQuery.value.isNotEmpty) {
                      _model.showQuickSearch = true;
                    }
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF111827),
                  fontSize: 13,
                ),
              ),
            ),
            Obx(() {
              if (chatController.searchQuery.value.isNotEmpty) {
                return GestureDetector(
                  onTap: () {
                    _model.searchTextController?.clear();
                    chatController.updateSearchQuery('');
                    _model.searchFocusNode?.unfocus();
                    setState(() {
                      _model.showQuickSearch = false;
                      _model.showFullSearch = false;
                    });
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.close_rounded,
                      color: Color(0xFF9CA3AF),
                      size: 16,
                    ),
                  ),
                ).withClickCursor();
              }
              // Show ⌘K shortcut hint when not searching
              return Padding(
                padding: EdgeInsets.only(right: 8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '⌘K',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// macOS-style toggle above the All/Unread tabs that switches the sidebar
  /// into the folder-grouped view when enabled.
  Widget _buildGroupFoldersToggle() {
    void toggle() {
      final value = !FFAppState().groupFoldersEnabled;
      setState(() {
        FFAppState().groupFoldersEnabled = value;
        _model.groupFoldersEnabled = value;
      });
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: toggle,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Color.fromRGBO(250, 252, 255, 1),
        ),
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enable group folders',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Group related chats under a shared topic',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            Transform.scale(
              scale: 0.7,
              alignment: Alignment.centerRight,
              child: CupertinoSwitch(
                value: FFAppState().groupFoldersEnabled,
                activeColor: Color(0xFF3B82F6),
                onChanged: (value) {
                  setState(() {
                    FFAppState().groupFoldersEnabled = value;
                    _model.groupFoldersEnabled = value;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    ).withClickCursor();
  }

  Widget _buildNavigationTabs() {
    // In folders mode, don't show tab bar
    if (kShowFoldersSidebar && _model.sidebarMode == SidebarMode.folders) {
      return SizedBox.shrink();
    }
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
            Expanded(child: _buildTab('Unread', 1)),
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
    ).withClickCursor();
  }

  bool get _sidebarListReady =>
      !DesktopSafeUserBuilder.useOnceFetch ||
      chatController.desktopSidebarReady.value;

  Widget _buildChatList() {
    return Expanded(
      child: Obx(() {
        if (!_sidebarListReady) {
          return Center(
            child: CircularProgressIndicator(
              color: Color.fromARGB(255, 16, 184, 239),
            ),
          );
        }

        switch (chatController.chatState.value) {
          case ChatState.loading:
            return Center(
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 16, 184, 239),
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

            final allChats = chatController.filteredChats;

            return Stack(
              children: [
                // Show folder-grouped view when "Enable group folders" is on,
                // otherwise the flat chat list.
                FFAppState().groupFoldersEnabled
                    ? _buildFolderListView(allChats)
                    : _buildFlatChatListView(allChats),
                // Quick search dropdown overlay
                if (_model.showQuickSearch &&
                    chatController.searchQuery.value.isNotEmpty)
                  _buildQuickSearchDropdown(allChats),
              ],
            );
        }
      }),
    );
  }

  Widget _buildQuickSearchDropdown(List<ChatsRecord> matchedChats) {
    final query = chatController.searchQuery.value;
    final quickChats = matchedChats.take(5).toList();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.12),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // "Search all messages" action
              GestureDetector(
                onTap: () {
                  setState(() {
                    _model.showQuickSearch = false;
                    _model.showFullSearch = true;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 15, color: Color(0xFF3B82F6)),
                      SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5,
                              color: Color(0xFF374151),
                            ),
                            children: [
                              TextSpan(text: 'Search messages for '),
                              TextSpan(
                                text: '"$query"',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Enter',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).withClickCursor(),
              // Divider
              if (quickChats.isNotEmpty)
                Divider(height: 1, color: Color(0xFFE5E7EB)),
              // Quick matching chats
              for (final chat in quickChats) _buildQuickSearchChatItem(chat),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSearchChatItem(ChatsRecord chat) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _model.showQuickSearch = false;
          _clearAllViews();
          _model.selectedChat = chat;
        });
        chatController.selectChat(chat);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              chat.isGroup ? Icons.groups_outlined : Icons.person_outline,
              size: 16,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                chat.title.isNotEmpty
                    ? chat.title
                    : (chatController.getCachedDisplayName(
                          chat.members
                              .firstWhere(
                                (m) => m != currentUserReference,
                                orElse: () => chat.members.first,
                              )
                              .id,
                        ) ??
                        'Chat'),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color(0xFF374151),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ).withClickCursor();
  }

  final GlobalKey<ChatThreadComponentWidgetState> _searchPreviewThreadKey =
      GlobalKey<ChatThreadComponentWidgetState>();

  Widget _buildFullSearchPage() {
    final query = chatController.searchQuery.value;
    final filteredChats = chatController.filteredChats;
    final hasPreview = _model.searchPreviewChat != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search page header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: Color(0xFF3B82F6)),
              SizedBox(width: 10),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: Color(0xFF111827),
                  ),
                  children: [
                    TextSpan(
                      text: 'Search: ',
                      style: TextStyle(fontWeight: FontWeight.w400),
                    ),
                    TextSpan(
                      text: query,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _model.showFullSearch = false;
                    _model.searchPreviewChat = null;
                    _model.searchPreviewMessageId = null;
                  });
                  _model.searchTextController?.clear();
                  chatController.updateSearchQuery('');
                },
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
                ),
              ).withClickCursor(),
            ],
          ),
        ),
        // Split view: search results + chat preview
        Expanded(
          child: hasPreview
              ? Column(
                  children: [
                    // Top half: search results
                    Expanded(
                      flex: 4,
                      child: _buildSearchResultsView(filteredChats),
                    ),
                    // Divider with chat name
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFFF0F4FF),
                        border: Border(
                          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                          bottom:
                              BorderSide(color: Color(0xFFE5E7EB), width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _model.searchPreviewChat!.isGroup
                                ? Icons.groups_outlined
                                : Icons.person_outline,
                            size: 14,
                            color: Color(0xFF3B82F6),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _model.searchPreviewChat!.title.isNotEmpty
                                  ? _model.searchPreviewChat!.title
                                  : (chatController.getCachedDisplayName(
                                        _model.searchPreviewChat!.members
                                            .firstWhere(
                                              (m) => m != currentUserReference,
                                              orElse: () => _model
                                                  .searchPreviewChat!
                                                  .members
                                                  .first,
                                            )
                                            .id,
                                      ) ??
                                      'Chat'),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3B82F6),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              // Open this chat fully
                              setState(() {
                                _model.showFullSearch = false;
                                _clearAllViews();
                                _model.selectedChat = _model.searchPreviewChat;
                              });
                              chatController
                                  .selectChat(_model.searchPreviewChat!);
                              _model.searchPreviewChat = null;
                              _model.searchPreviewMessageId = null;
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Color(0xFF3B82F6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Open Chat',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ).withClickCursor(),
                          SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _model.searchPreviewChat = null;
                                _model.searchPreviewMessageId = null;
                              });
                            },
                            child: Icon(Icons.close,
                                size: 16, color: Color(0xFF9CA3AF)),
                          ).withClickCursor(),
                        ],
                      ),
                    ),
                    // Bottom half: chat thread preview
                    Expanded(
                      flex: 6,
                      child: ChatThreadComponentWidget(
                        key: _searchPreviewThreadKey,
                        chatReference: _model.searchPreviewChat,
                        activeSelectionId: ValueNotifier(null),
                        onMessageAction: _handleDesktopMessageAction,
                        onSidebarPreviewUpdate:
                            chatController.applyLocalChatLastMessageFromPatch,
                        onMessagesMutated: () =>
                            chatController.refreshChats(force: true),
                        isSelectionMode: false,
                        selectedMessages: {},
                        onMessageToggled: (_) {},
                      ),
                    ),
                  ],
                )
              : _buildSearchResultsView(filteredChats),
        ),
      ],
    );
  }

  Widget _buildSearchResultsView(List<ChatsRecord> chatResults) {
    return Obx(() {
      final messageResults = chatController.messageSearchResults;
      final isSearching = chatController.isSearchingMessages.value;

      return ListView(
        padding: EdgeInsets.zero,
        children: [
          // Matching chats section
          if (chatResults.isNotEmpty) ...[
            _buildSearchSectionHeader(
              'Chats',
              chatResults.length,
              Icons.chat_bubble_outline,
            ),
            for (final chat in chatResults) _buildSearchChatItem(chat),
          ],

          // Message results section
          if (isSearching)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Searching messages...',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (!isSearching && messageResults.isNotEmpty) ...[
            _buildSearchSectionHeader(
              'Messages',
              messageResults.length,
              Icons.message_outlined,
            ),
            for (final result in messageResults)
              _buildMessageResultCard(result),
          ],

          // No results at all
          if (!isSearching && chatResults.isEmpty && messageResults.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 36, color: Color(0xFFD1D5DB)),
                    SizedBox(height: 8),
                    Text(
                      'No results found',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildSearchSectionHeader(String title, int count, IconData icon) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Color(0xFF6B7280)),
          SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchChatItem(ChatsRecord chat) {
    return Obx(() {
      final _ = chatController.chats.length;
      final __ = chatController.locallySeenChats.length;
      final ___ = chatController.knownUnreadChats.length;
      final ____ = chatController.selectedChat.value?.reference.id;
      final hasUnread = chatController.hasUnreadMessages(chat);
      final isSelected =
          chatController.selectedChat.value?.reference == chat.reference;

      return _ChatListItem(
        key: ValueKey('search_result_${chat.reference.id}'),
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
        onMarkUnread: (chat) => chatController.markChatAsUnread(chat),
        onMoveToFolder: _showMoveToFolderMenu,
        onRename: _showRenameGroupChatDialog,
        getOrCreateUserFuture: _getOrCreateUserFuture,
      );
    });
  }

  Widget _buildMessageResultCard(MessageSearchResult result) {
    final query = chatController.searchQuery.value.toLowerCase();
    final timeStr = result.createdAt != null
        ? _formatSearchResultTime(result.createdAt!)
        : '';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final chat = chatController.chats.firstWhereOrNull(
            (c) => c.reference.id == result.chatId,
          );
          if (chat != null) {
            final messageId = result.messageRef.id;
            if (_model.showFullSearch) {
              // Split view: show chat preview in bottom half
              setState(() {
                _model.searchPreviewChat = chat;
                _model.searchPreviewMessageId = messageId;
              });
              // Scroll to message after preview builds
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Future.delayed(Duration(milliseconds: 600), () {
                  _searchPreviewThreadKey.currentState
                      ?.scrollToMessage(messageId);
                });
              });
            } else {
              // Normal mode: open chat directly
              setState(() {
                _clearAllViews();
                _model.selectedChat = chat;
              });
              chatController.selectChat(chat);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Future.delayed(Duration(milliseconds: 500), () {
                  _chatThreadKey.currentState?.scrollToMessage(messageId);
                });
              });
            }
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: sender name + chat name + time
              Row(
                children: [
                  // Sender avatar
                  if (result.senderPhoto.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        result.senderPhoto,
                        width: 20,
                        height: 20,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Color(0xFFDFE3E8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(Icons.person,
                              size: 12, color: Color(0xFF9CA3AF)),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Color(0xFFDFE3E8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.person,
                          size: 12, color: Color(0xFF9CA3AF)),
                    ),
                  SizedBox(width: 6),
                  // Sender name
                  Text(
                    result.senderName.isNotEmpty
                        ? result.senderName
                        : 'Unknown',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(width: 6),
                  // Chat name badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Color(0xFFEBF5FF),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          result.isGroup
                              ? Icons.groups_outlined
                              : Icons.person_outline,
                          size: 10,
                          color: Color(0xFF3B82F6),
                        ),
                        SizedBox(width: 3),
                        Text(
                          result.chatName,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF3B82F6),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Spacer(),
                  // Timestamp
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              // Message content with highlighted query
              _buildHighlightedText(
                  _cleanMessageContent(result.content), query),
            ],
          ),
        ),
      ),
    );
  }

  /// Clean raw message content for display in search results
  String _cleanMessageContent(String content) {
    // Strip mention markup: <@userId|displayName> → @displayName
    content = content.replaceAllMapped(
      RegExp(r'<@[^|>]+\|([^>]+)>'),
      (match) => '@${match.group(1)}',
    );
    // Strip mention markup without display name: <@userId> → @user
    content = content.replaceAllMapped(
      RegExp(r'<@([^>]+)>'),
      (match) => '@user',
    );
    // Shorten long URLs: keep domain + truncate
    content = content.replaceAllMapped(
      RegExp(r'https?://([^/\s]{1,40})[^\s]{40,}'),
      (match) => 'https://${match.group(1)}/...',
    );
    return content;
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        style: TextStyle(
            fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF374151)),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(
          backgroundColor: Color(0xFFFEF3C7),
          fontWeight: FontWeight.w600,
          color: Color(0xFF92400E),
        ),
      ));
      start = index + query.length;
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12.5,
          color: Color(0xFF374151),
        ),
        children: spans,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatSearchResultTime(DateTime time) {
    final local = time.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inDays == 0) {
      return DateFormat('h:mm a').format(local);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[local.weekday - 1];
    } else {
      return '${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}/${local.year}';
    }
  }

  /// Flat chat list (Chat mode): Pinned at top, then all chats by time.
  bool _shouldShowInactiveSection() {
    final tabIndex = _model.tabController?.index ?? 0;
    return tabIndex == 0 &&
        chatController.chatFilter.value == 'All' &&
        chatController.searchQuery.value.isEmpty;
  }

  List<ChatsRecord> _getInactiveChats() {
    if (!_shouldShowInactiveSection()) return const [];
    return chatController.getInactiveChatsForSidebar();
  }

  List<Widget> _buildInactiveSection() {
    // Always show the Inactive header on the All tab, even when there are no
    // inactive chats (parity with how the Pinned section is presented).
    if (!_shouldShowInactiveSection()) return const [];
    final inactive = chatController.getInactiveChatsForSidebar();

    return [
      _buildSmartFolderHeader(
        'Inactive',
        inactive.length,
        Icons.archive_outlined,
        _model.isInactiveCollapsed,
        () => setState(
            () => _model.isInactiveCollapsed = !_model.isInactiveCollapsed),
      ),
      if (!_model.isInactiveCollapsed)
        for (final chat in inactive) _buildFolderChatItem(chat),
    ];
  }

  Widget _buildFlatChatListView(List<ChatsRecord> filteredChats) {
    final userRef = currentUserReference;
    final pinned =
        filteredChats.where((c) => c.isPinnedByUser(userRef)).toList();
    final rest =
        filteredChats.where((c) => !c.isPinnedByUser(userRef)).toList();
    final inactive = _getInactiveChats();

    if (filteredChats.isEmpty && inactive.isEmpty) {
      final tabIndex = _model.tabController?.index ?? 0;
      final emptyMessage = tabIndex == 1 ? 'No unread chats' : 'No chats yet';
      final emptyIcon = tabIndex == 1
          ? Icons.mark_email_read_outlined
          : CupertinoIcons.chat_bubble_2;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 48, color: Color(0xFFD1D5DB)),
            SizedBox(height: 12),
            Text(
              emptyMessage,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Pinned section (collapsible)
        if (pinned.isNotEmpty) ...[
          _buildSmartFolderHeader(
            'Pinned',
            pinned.length,
            Icons.push_pin_rounded,
            _model.isPinnedCollapsed,
            () => setState(
                () => _model.isPinnedCollapsed = !_model.isPinnedCollapsed),
          ),
          if (!_model.isPinnedCollapsed)
            for (final chat in pinned)
              _buildFolderChatItem(chat, showPinIcon: false),
        ],

        // All other chats — flat, sorted by time (already sorted by controller)
        if (rest.isNotEmpty) ...[
          _buildSmartFolderHeader(
            'Recent',
            rest.length,
            Icons.history_rounded,
            _model.isRecentCollapsed,
            () => setState(
                () => _model.isRecentCollapsed = !_model.isRecentCollapsed),
          ),
          if (!_model.isRecentCollapsed)
            for (final chat in rest) _buildFolderChatItem(chat),
        ],

        ..._buildInactiveSection(),
      ],
    );
  }

  /// Chat IDs that belong to a custom folder. Such chats live exclusively
  /// under their folder and are hidden from the Pinned/Group/DM sections so
  /// each chat only ever appears in one place.
  Set<String> _folderedChatIds() {
    final ids = <String>{};
    for (final folder in _model.chatFolders) {
      ids.addAll(folder.chatIds);
    }
    return ids;
  }

  Widget _buildFolderListView(List<ChatsRecord> filteredChats) {
    // Smart folder classification
    // Combine pinned DMs and Groups into a single "Pinned" section
    final userRef = currentUserReference;
    final folderedIds = _folderedChatIds();
    // Pinned takes precedence over folders: a pinned chat always shows in the
    // Pinned section (and is excluded from its folder below).
    final pinned =
        filteredChats.where((c) => c.isPinnedByUser(userRef)).toList();
    final groups = filteredChats
        .where((c) =>
            !c.isPinnedByUser(userRef) &&
            c.isGroup &&
            !folderedIds.contains(c.reference.id))
        .toList();
    final dms = filteredChats
        .where((c) =>
            !c.isPinnedByUser(userRef) &&
            !c.isGroup &&
            !folderedIds.contains(c.reference.id))
        .toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Pinned (combined DM and Groups)
        if (pinned.isNotEmpty) ...[
          _buildSmartFolderHeader(
            'Pinned',
            pinned.length,
            Icons.push_pin_rounded,
            _model.isPinnedCollapsed,
            () => setState(
                () => _model.isPinnedCollapsed = !_model.isPinnedCollapsed),
          ),
          if (!_model.isPinnedCollapsed)
            for (final chat in pinned)
              _buildFolderChatItem(chat, showPinIcon: false),
        ],

        // Custom folders (user-created)
        for (final folder in _model.chatFolders)
          _buildFolderSection(folder, filteredChats),

        // Group
        if (groups.isNotEmpty) ...[
          _buildSmartFolderHeader(
            'Group',
            groups.length,
            Icons.group_outlined,
            _model.isGroupCollapsed,
            () => setState(
                () => _model.isGroupCollapsed = !_model.isGroupCollapsed),
          ),
          if (!_model.isGroupCollapsed)
            for (final chat in groups) _buildFolderChatItem(chat),
        ],

        // DM
        if (dms.isNotEmpty) ...[
          _buildSmartFolderHeader(
            'DM',
            dms.length,
            Icons.person_outline_rounded,
            _model.isDMCollapsed,
            () => setState(() => _model.isDMCollapsed = !_model.isDMCollapsed),
          ),
          if (!_model.isDMCollapsed)
            for (final chat in dms) _buildFolderChatItem(chat),
        ],

        ..._buildInactiveSection(),
      ],
    );
  }

  Widget _buildSmartFolderHeader(
    String title,
    int count,
    IconData icon,
    bool isCollapsed,
    VoidCallback onToggle,
  ) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Color(0xFFF3F4F6),
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCollapsed
                  ? Icons.chevron_right_rounded
                  : Icons.expand_more_rounded,
              size: 18,
              color: Color(0xFF6B7280),
            ),
            SizedBox(width: 4),
            Icon(icon, size: 15, color: Color(0xFF9CA3AF)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    ).withClickCursor();
  }

  Widget _buildFolderSection(
      ChatFoldersRecord folder, List<ChatsRecord> filteredChats) {
    // Only show chats in this folder that match the current tab filter.
    // Pinned chats take precedence and live in the Pinned section instead.
    final folderChats = filteredChats
        .where((c) =>
            folder.chatIds.contains(c.reference.id) &&
            !c.isPinnedByUser(currentUserReference))
        .toList();

    // Count unread in this folder
    int unreadCount = 0;
    for (final chat in folderChats) {
      if (chatController.hasUnreadMessages(chat)) {
        unreadCount++;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSectionHeader(
          folder.name,
          folderChats.length,
          folder,
          unreadCount: unreadCount,
        ),
        if (!folder.isCollapsed)
          for (final chat in folderChats) _buildFolderChatItem(chat),
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count,
    ChatFoldersRecord? folder, {
    int unreadCount = 0,
  }) {
    final isCollapsed = folder?.isCollapsed ?? false;

    return GestureDetector(
      onTap: () {
        if (folder != null) {
          _toggleFolderCollapsed(folder);
        }
      },
      onSecondaryTapUp: folder != null
          ? (details) {
              _showFolderContextMenu(
                details.globalPosition,
                folder,
              );
            }
          : null,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Color(0xFFF3F4F6),
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCollapsed
                  ? Icons.chevron_right_rounded
                  : Icons.expand_more_rounded,
              size: 18,
              color: Color(0xFF6B7280),
            ),
            SizedBox(width: 4),
            Icon(
              folder != null ? Icons.folder_rounded : Icons.inbox_rounded,
              size: 15,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unreadCount > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            // Add button for custom folders
            if (folder != null) ...[
              SizedBox(width: 4),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _showAddChatsToExistingFolderDialog(folder),
                  child: Tooltip(
                    message: 'Add chats to folder',
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.add_rounded,
                          size: 14, color: Color(0xFF6B7280)),
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    ).withClickCursor();
  }

  Widget _buildUnfiledHeader(int count) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _model.isUnfiledCollapsed = !_model.isUnfiledCollapsed;
        });
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Color(0xFFF3F4F6),
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _model.isUnfiledCollapsed
                  ? Icons.chevron_right_rounded
                  : Icons.expand_more_rounded,
              size: 18,
              color: Color(0xFF6B7280),
            ),
            SizedBox(width: 4),
            Icon(Icons.inbox_rounded, size: 15, color: Color(0xFF9CA3AF)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Unfiled',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    ).withClickCursor();
  }

  Widget _buildFolderChatItem(ChatsRecord chat, {bool showPinIcon = true}) {
    return Obx(() {
      final _ = chatController.chats.length;
      final __ = chatController.locallySeenChats.length;
      final ___ = chatController.knownUnreadChats.length;
      final ____ = chatController.selectedChat.value?.reference.id;
      final hasUnread = chatController.hasUnreadMessages(chat);
      final isSelected =
          chatController.selectedChat.value?.reference == chat.reference;

      return _ChatListItem(
        key: ValueKey('folder_chat_${chat.reference.id}'),
        chat: chat,
        isSelected: isSelected,
        showPinIcon: showPinIcon,
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
        onMarkUnread: (chat) => chatController.markChatAsUnread(chat),
        onMoveToFolder: _showMoveToFolderMenu,
        onRename: _showRenameGroupChatDialog,
        getOrCreateUserFuture: _getOrCreateUserFuture,
      );
    });
  }

  // ─── Folder Management Dialogs ───

  /// Single-popup create-folder flow:
  ///   Step 1 — Enter a name for your folder
  ///   Step 2 — Add Chats (Groups | Direct Messages side by side)
  void _showCreateFolderDialog() async {
    final nameController = TextEditingController();
    final selectedIds = <String>{};
    final groupsScrollController = ScrollController();
    final dmsScrollController = ScrollController();

    final allChats = chatController.chats;
    final allGroups = allChats.where((c) => c.isGroup).toList();
    final allDMs = allChats.where((c) => !c.isGroup).toList();

    // Pre-resolve DM display names from the other participant.
    final dmNameMap = <String, String>{};
    for (final dm in allDMs) {
      if (dm.title.isNotEmpty) {
        dmNameMap[dm.reference.id] = dm.title;
      } else {
        try {
          final otherUserRef = dm.members.firstWhere(
            (m) => m != currentUserReference,
            orElse: () => dm.members.first,
          );
          final user = await _getOrCreateUserFuture(otherUserRef);
          dmNameMap[dm.reference.id] =
              user.displayName.isNotEmpty ? user.displayName : 'User';
        } catch (_) {
          dmNameMap[dm.reference.id] = 'Direct Message';
        }
      }
    }

    // Chats already filed in another folder are locked out (one folder each).
    final chatFolderMap = <String, List<String>>{};
    final lockedChatIds = <String>{};
    for (final folder in _model.chatFolders) {
      for (final chatId in folder.chatIds) {
        chatFolderMap.putIfAbsent(chatId, () => []).add(folder.name);
        lockedChatIds.add(chatId);
      }
    }

    bool isSelectable(ChatsRecord c) =>
        !lockedChatIds.contains(c.reference.id) &&
        !c.isPinnedByUser(currentUserReference);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Widget buildColumn(
            String label,
            IconData icon,
            List<ChatsRecord> chats,
            ScrollController scrollController, {
            bool isDm = false,
          }) {
            return Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPickerSectionLabel(label, icon, chats.length),
                  SizedBox(height: 4),
                  Expanded(
                    child: chats.isEmpty
                        ? Center(
                            child: Text(
                              'None',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          )
                        : Scrollbar(
                            controller: scrollController,
                            thumbVisibility: true,
                            child: ListView(
                              controller: scrollController,
                              padding: EdgeInsets.only(right: 8),
                              children: [
                                for (final chat in chats)
                                  _buildPickerChatRow(
                                    chat: chat,
                                    resolvedName: isDm
                                        ? dmNameMap[chat.reference.id]
                                        : null,
                                    isChecked:
                                        selectedIds.contains(chat.reference.id),
                                    isAlreadyInFolder: false,
                                    isLockedInOtherFolder: lockedChatIds
                                        .contains(chat.reference.id),
                                    isPinned: chat
                                        .isPinnedByUser(currentUserReference),
                                    folderNames:
                                        chatFolderMap[chat.reference.id],
                                    onTap: () {
                                      if (!isSelectable(chat)) return;
                                      setDialogState(() {
                                        if (selectedIds
                                            .contains(chat.reference.id)) {
                                          selectedIds.remove(chat.reference.id);
                                        } else {
                                          selectedIds.add(chat.reference.id);
                                        }
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(
              'New Folder',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            content: SizedBox(
              width: 560,
              height: MediaQuery.of(ctx).size.height / 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Step 1: Name ──
                  Text(
                    'Step 1: Enter a name for your folder',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Folder name',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF9CA3AF),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Color(0xFF3B82F6)),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 16),
                  // ── Step 2: Add Chats ──
                  Row(
                    children: [
                      Text(
                        'Step 2: Add Chats',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      Spacer(),
                      Text(
                        '${selectedIds.length} selected',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Divider(height: 1, color: Color(0xFFE5E7EB)),
                  SizedBox(height: 8),
                  // Groups | Direct Messages side by side
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildColumn(
                          'Groups',
                          Icons.group_outlined,
                          allGroups,
                          groupsScrollController,
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: VerticalDivider(
                            width: 1,
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        buildColumn(
                          'Direct Messages',
                          Icons.person_outline_rounded,
                          allDMs,
                          dmsScrollController,
                          isDm: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: desktopClickableButtonStyle(null),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  Navigator.of(ctx).pop();
                  _createFolder(name, selectedChatIds: selectedIds.toList());
                },
                style: desktopClickableButtonStyle(null),
                child: Text(
                  'Create Folder',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Dialog to add chats to an existing folder (from the + button)
  /// Removes the given chat IDs from every folder except [exceptFolderId], so a
  /// chat can only ever belong to a single folder.
  Future<void> _removeChatsFromOtherFolders(
    Iterable<String> chatIds, {
    required String exceptFolderId,
  }) async {
    final ids = chatIds.toList();
    final previousFolders = _model.chatFolders;
    _applyLocalRemoveChatsFromOtherFolders(ids, exceptFolderId: exceptFolderId);
    for (final folder in previousFolders) {
      if (folder.reference.id == exceptFolderId) continue;
      final toRemove = ids.where((id) => folder.chatIds.contains(id)).toList();
      if (toRemove.isEmpty) continue;
      try {
        await fsArrayRemove(folder.reference, 'chat_ids', toRemove);
        await fsPatchDocument(folder.reference, {
          'updated_at': getCurrentTimestamp,
        });
      } catch (e) {
        debugLog('❌ Error removing chats from folder ${folder.name}: $e');
      }
    }
  }

  void _showAddChatsToExistingFolderDialog(ChatFoldersRecord folder) {
    _showChatPickerDialog(
      title: 'Add Chats to "${folder.name}"',
      subtitle: 'Select chats to add',
      actionLabel: 'Add to Folder',
      existingChatIds: folder.chatIds.toSet(),
      currentFolderId: folder.reference.id,
      onConfirm: (selectedIds) async {
        if (selectedIds.isEmpty) return;
        final previousFolders = _model.chatFolders;
        _applyLocalChatFolderMembership(
          chatIds: selectedIds,
          targetFolderId: folder.reference.id,
        );
        try {
          await fsArrayUnion(
            folder.reference,
            'chat_ids',
            selectedIds.toList(),
          );
          await fsPatchDocument(folder.reference, {
            'updated_at': getCurrentTimestamp,
          });
          // A chat belongs to only one folder — drop it from any others.
          await _removeChatsFromOtherFolders(
            selectedIds,
            exceptFolderId: folder.reference.id,
          );
        } catch (e) {
          debugLog('❌ Error adding chats to folder: $e');
          if (mounted) {
            setState(() => _model.chatFolders = previousFolders);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error adding chats to folder: $e'),
                backgroundColor: Color(0xFFEF4444),
              ),
            );
          }
        }
      },
    );
  }

  /// Shared chat picker dialog showing Groups, DMs, and existing folder reference
  ///
  /// [currentFolderId] is the folder being edited (null when creating a new one).
  /// A chat may only ever live in a single folder, so any chat already filed in
  /// a *different* folder is locked: it renders grayed out and cannot be picked.
  void _showChatPickerDialog({
    required String title,
    required String subtitle,
    required String actionLabel,
    required Set<String> existingChatIds,
    required Function(Set<String>) onConfirm,
    String? currentFolderId,
  }) async {
    final allChats = chatController.chats;
    final allGroups = allChats.where((c) => c.isGroup).toList();
    final allDMs = allChats.where((c) => !c.isGroup).toList();
    final selectedIds = <String>{};
    final searchQuery = ValueNotifier<String>('');
    final groupsScrollController = ScrollController();
    final dmsScrollController = ScrollController();

    // Pre-resolve DM display names from other user
    final dmNameMap = <String, String>{};
    for (final dm in allDMs) {
      if (dm.title.isNotEmpty) {
        dmNameMap[dm.reference.id] = dm.title;
      } else {
        try {
          final otherUserRef = dm.members.firstWhere(
            (m) => m != currentUserReference,
            orElse: () => dm.members.first,
          );
          final user = await _getOrCreateUserFuture(otherUserRef);
          dmNameMap[dm.reference.id] =
              user.displayName.isNotEmpty ? user.displayName : 'User';
        } catch (_) {
          dmNameMap[dm.reference.id] = 'Direct Message';
        }
      }
    }

    // Build folder lookup for chats already filed in a *different* folder.
    // These are locked out of the picker so a chat can only belong to one folder.
    final chatFolderMap = <String, List<String>>{};
    final lockedChatIds = <String>{};
    for (final folder in _model.chatFolders) {
      if (folder.reference.id == currentFolderId) continue;
      for (final chatId in folder.chatIds) {
        chatFolderMap.putIfAbsent(chatId, () => []).add(folder.name);
        lockedChatIds.add(chatId);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final query = searchQuery.value.toLowerCase();
          final filteredGroups = query.isEmpty
              ? allGroups
              : allGroups
                  .where((g) => g.title.toLowerCase().contains(query))
                  .toList();
          final filteredDMs = query.isEmpty
              ? allDMs
              : allDMs.where((d) {
                  final resolvedName = dmNameMap[d.reference.id] ?? d.title;
                  return resolvedName.toLowerCase().contains(query);
                }).toList();
          final allFiltered = [...filteredGroups, ...filteredDMs];

          return AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827))),
                SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280))),
              ],
            ),
            content: SizedBox(
              width: 560,
              height: MediaQuery.of(ctx).size.height / 2,
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    onChanged: (value) {
                      searchQuery.value = value;
                      setDialogState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'Search chats...',
                      hintStyle: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Color(0xFF9CA3AF)),
                      prefixIcon: Icon(Icons.search,
                          size: 18, color: Color(0xFF9CA3AF)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Color(0xFFE5E7EB))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Color(0xFF3B82F6))),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Color(0xFF111827)),
                  ),
                  SizedBox(height: 8),
                  // Select all / count
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            final allSelectableIds = allFiltered
                                .where((c) =>
                                    !existingChatIds.contains(c.reference.id) &&
                                    !lockedChatIds.contains(c.reference.id) &&
                                    !c.isPinnedByUser(currentUserReference))
                                .map((c) => c.reference.id)
                                .toSet();
                            if (selectedIds.containsAll(allSelectableIds)) {
                              selectedIds.removeAll(allSelectableIds);
                            } else {
                              selectedIds.addAll(allSelectableIds);
                            }
                          });
                        },
                        child: Text(
                          'Select All',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF3B82F6)),
                        ),
                      ).withClickCursor(),
                      Spacer(),
                      Text(
                        '${selectedIds.length} selected',
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Divider(height: 1, color: Color(0xFFE5E7EB)),
                  SizedBox(height: 8),
                  // Groups | Direct Messages side by side
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPickerSectionLabel('Groups',
                                  Icons.group_outlined, filteredGroups.length),
                              SizedBox(height: 4),
                              Expanded(
                                child: filteredGroups.isEmpty
                                    ? Center(
                                        child: Text(
                                          query.isEmpty
                                              ? 'None'
                                              : 'No chats found',
                                          style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              color: Color(0xFF9CA3AF)),
                                        ),
                                      )
                                    : Scrollbar(
                                        controller: groupsScrollController,
                                        thumbVisibility: true,
                                        child: ListView(
                                          controller: groupsScrollController,
                                          padding: EdgeInsets.only(right: 8),
                                          children: [
                                            for (final chat in filteredGroups)
                                              _buildPickerChatRow(
                                                chat: chat,
                                                isChecked: selectedIds.contains(
                                                    chat.reference.id),
                                                isAlreadyInFolder:
                                                    existingChatIds.contains(
                                                        chat.reference.id),
                                                isLockedInOtherFolder:
                                                    lockedChatIds.contains(
                                                        chat.reference.id),
                                                isPinned: chat.isPinnedByUser(
                                                    currentUserReference),
                                                folderNames: chatFolderMap[
                                                    chat.reference.id],
                                                onTap: () {
                                                  if (existingChatIds.contains(
                                                      chat.reference.id))
                                                    return;
                                                  if (lockedChatIds.contains(
                                                      chat.reference.id))
                                                    return;
                                                  if (chat.isPinnedByUser(
                                                      currentUserReference))
                                                    return;
                                                  setDialogState(() {
                                                    if (selectedIds.contains(
                                                        chat.reference.id)) {
                                                      selectedIds.remove(
                                                          chat.reference.id);
                                                    } else {
                                                      selectedIds.add(
                                                          chat.reference.id);
                                                    }
                                                  });
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: VerticalDivider(
                            width: 1,
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPickerSectionLabel(
                                  'Direct Messages',
                                  Icons.person_outline_rounded,
                                  filteredDMs.length),
                              SizedBox(height: 4),
                              Expanded(
                                child: filteredDMs.isEmpty
                                    ? Center(
                                        child: Text(
                                          query.isEmpty
                                              ? 'None'
                                              : 'No chats found',
                                          style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              color: Color(0xFF9CA3AF)),
                                        ),
                                      )
                                    : Scrollbar(
                                        controller: dmsScrollController,
                                        thumbVisibility: true,
                                        child: ListView(
                                          controller: dmsScrollController,
                                          padding: EdgeInsets.only(right: 8),
                                          children: [
                                            for (final chat in filteredDMs)
                                              _buildPickerChatRow(
                                                chat: chat,
                                                resolvedName: dmNameMap[
                                                    chat.reference.id],
                                                isChecked: selectedIds.contains(
                                                    chat.reference.id),
                                                isAlreadyInFolder:
                                                    existingChatIds.contains(
                                                        chat.reference.id),
                                                isLockedInOtherFolder:
                                                    lockedChatIds.contains(
                                                        chat.reference.id),
                                                isPinned: chat.isPinnedByUser(
                                                    currentUserReference),
                                                folderNames: chatFolderMap[
                                                    chat.reference.id],
                                                onTap: () {
                                                  if (existingChatIds.contains(
                                                      chat.reference.id))
                                                    return;
                                                  if (lockedChatIds.contains(
                                                      chat.reference.id))
                                                    return;
                                                  if (chat.isPinnedByUser(
                                                      currentUserReference))
                                                    return;
                                                  setDialogState(() {
                                                    if (selectedIds.contains(
                                                        chat.reference.id)) {
                                                      selectedIds.remove(
                                                          chat.reference.id);
                                                    } else {
                                                      selectedIds.add(
                                                          chat.reference.id);
                                                    }
                                                  });
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancel',
                    style: TextStyle(
                        fontFamily: 'Inter', color: Color(0xFF6B7280))),
              ),
              TextButton(
                onPressed: () {
                  onConfirm(selectedIds);
                  Navigator.of(ctx).pop();
                },
                child: Text(actionLabel,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Section label in the chat picker dialog
  Widget _buildPickerSectionLabel(String label, IconData icon, int count) {
    return Padding(
      padding: EdgeInsets.only(top: 8, bottom: 4, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Color(0xFF6B7280)),
          SizedBox(width: 6),
          Text(
            '$label ($count)',
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
                letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }

  /// Single chat row in the picker dialog
  Widget _buildPickerChatRow({
    required ChatsRecord chat,
    String? resolvedName,
    required bool isChecked,
    required bool isAlreadyInFolder,
    bool isLockedInOtherFolder = false,
    bool isPinned = false,
    List<String>? folderNames,
    required VoidCallback onTap,
  }) {
    final displayName = resolvedName ??
        (chat.title.isNotEmpty
            ? chat.title
            : (chat.isGroup ? 'Group Chat' : 'Direct Message'));
    final isGroup = chat.isGroup;
    // Disabled when already in this folder, filed in another folder, or pinned.
    // Pinned chats take precedence and live in the Pinned section only.
    final isDisabled = isAlreadyInFolder || isLockedInOtherFolder || isPinned;
    final opacity = isDisabled ? 0.5 : 1.0;

    return Opacity(
      opacity: opacity,
      child: InkWell(
        mouseCursor: isDisabled
            ? SystemMouseCursors.forbidden
            : MaterialStateMouseCursor.clickable,
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: Row(
            children: [
              // Checkbox
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: (isChecked || isAlreadyInFolder)
                      ? Color(0xFF3B82F6)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (isChecked || isAlreadyInFolder)
                        ? Color(0xFF3B82F6)
                        : Color(0xFFD1D5DB),
                    width: 1.5,
                  ),
                ),
                child: (isChecked || isAlreadyInFolder)
                    ? Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              SizedBox(width: 10),
              // Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: chat.chatImageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: chat.chatImageUrl,
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                        memCacheWidth: 60,
                        memCacheHeight: 60,
                        placeholder: (context, url) => Container(
                          width: 30,
                          height: 30,
                          color: Color(0xFFE5E7EB),
                          child: Icon(isGroup ? Icons.group : Icons.person,
                              size: 14, color: Color(0xFF6B7280)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 30,
                          height: 30,
                          color: Color(0xFFE5E7EB),
                          child: Icon(isGroup ? Icons.group : Icons.person,
                              size: 14, color: Color(0xFF6B7280)),
                        ),
                      )
                    : Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                            color: Color(0xFFE5E7EB), shape: BoxShape.circle),
                        child: Icon(isGroup ? Icons.group : Icons.person,
                            size: 14, color: Color(0xFF6B7280)),
                      ),
              ),
              SizedBox(width: 10),
              // Name + folder tags
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: (isChecked || isAlreadyInFolder)
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: Color(0xFF111827),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (folderNames != null && folderNames.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.folder_outlined,
                                size: 10, color: Color(0xFF9CA3AF)),
                            SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                folderNames.join(', '),
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    color: Color(0xFF9CA3AF)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isAlreadyInFolder)
                      Text(
                        'Already in this folder',
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: Color(0xFF9CA3AF),
                            fontStyle: FontStyle.italic),
                      ),
                    if (isPinned && !isAlreadyInFolder)
                      Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.push_pin_rounded,
                                size: 10, color: Color(0xFF9CA3AF)),
                            SizedBox(width: 3),
                            Text(
                              "Pinned — can't be added to folders",
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  color: Color(0xFF9CA3AF),
                                  fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createFolder(String name,
      {List<String>? selectedChatIds}) async {
    if (currentUserReference == null) {
      debugLog('❌ _createFolder: currentUserReference is null');
      return;
    }
    try {
      final nextOrder = _model.chatFolders.length;
      debugLog('📁 Creating folder "$name"');
      final docRef = await fsCreateChatFolderDocument(
        userRef: currentUserReference!,
        data: {
          'name': name,
          'order': nextOrder,
          'is_collapsed': false,
          'chat_ids': selectedChatIds ?? <String>[],
          'created_at': getCurrentTimestamp,
          'updated_at': getCurrentTimestamp,
        },
      );
      debugLog(
          '✅ Folder "$name" created successfully with ${selectedChatIds?.length ?? 0} groups');

      // Make the folder visible immediately. On Windows/Linux the folder list
      // is refreshed via a 30s poll (no live stream), so without this the new
      // folder wouldn't appear until the next poll. We refresh from the backend
      // and fall back to an optimistic local insert if the fetch is empty/slow.
      await _refreshChatFoldersNow(
        fallback: () {
          if (_model.chatFolders.any((f) => f.reference.id == docRef.id)) {
            return;
          }
          _model.chatFolders = [
            ..._model.chatFolders,
            ChatFoldersRecord.getDocumentFromData(
              {
                'name': name,
                'order': nextOrder,
                'is_collapsed': false,
                'chat_ids': selectedChatIds ?? <String>[],
                'created_at': getCurrentTimestamp,
                'updated_at': getCurrentTimestamp,
              },
              docRef,
            ),
          ];
        },
      );

      // A chat belongs to only one folder — drop the newly added chats from
      // any other folders they may have been in.
      if (selectedChatIds != null && selectedChatIds.isNotEmpty) {
        await _removeChatsFromOtherFolders(
          selectedChatIds,
          exceptFolderId: docRef.id,
        );
      }
    } catch (e, stack) {
      debugLog('❌ Error creating folder: $e');
      debugLog(stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating folder: $e'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showRenameGroupChatDialog(ChatsRecord chat) {
    if (!chat.isGroup ||
        !ChatHelpers.isGroupOwner(chat, currentUserReference)) {
      return;
    }

    final controller = TextEditingController(text: chat.title);
    XFile? pickedImage;
    Uint8List? previewBytes;
    var isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final existingImageUrl = chat.chatImageUrl;
          Future<void> pickImage() async {
            try {
              final picker = ImagePicker();
              final image = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 512,
                maxHeight: 512,
                imageQuality: 85,
              );
              if (image == null) return;
              final bytes = await image.readAsBytes();
              setDialogState(() {
                pickedImage = image;
                previewBytes = bytes;
              });
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error picking image: $e'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
            }
          }

          Future<void> save() async {
            final name = controller.text.trim();
            if (name.isEmpty || isSaving) return;
            final nameChanged = name != chat.title;
            final imageChanged = pickedImage != null;
            if (!nameChanged && !imageChanged) {
              Navigator.of(ctx).pop();
              return;
            }

            setDialogState(() => isSaving = true);
            try {
              await _handleEditGroupChat(
                chat,
                newName: nameChanged ? name : null,
                imageFile: pickedImage,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            } catch (_) {
              setDialogState(() => isSaving = false);
            }
          }

          Widget avatarChild;
          if (previewBytes != null) {
            avatarChild = Image.memory(
              previewBytes!,
              fit: BoxFit.cover,
              width: 72,
              height: 72,
            );
          } else if (existingImageUrl.isNotEmpty) {
            avatarChild = CachedNetworkImage(
              imageUrl: existingImageUrl,
              fit: BoxFit.cover,
              width: 72,
              height: 72,
              errorWidget: (_, __, ___) => Icon(
                Icons.group_rounded,
                size: 32,
                color: Color(0xFF9CA3AF),
              ),
            );
          } else {
            avatarChild = Icon(
              Icons.group_rounded,
              size: 32,
              color: Color(0xFF9CA3AF),
            );
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              'Edit Group',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: isSaving ? null : pickImage,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: avatarChild,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).withClickCursor(),
                SizedBox(height: 8),
                Text(
                  'Tap to change photo',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    hintText: 'Group name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFF3B82F6)),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                  onSubmitted: (_) => save(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              TextButton(
                onPressed: isSaving ? null : save,
                child: isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF3B82F6),
                        ),
                      )
                    : Text(
                        'Save',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String> _uploadExistingGroupImage(
    ChatsRecord chat,
    XFile imageFile,
  ) async {
    final fileName =
        'group_images/${chat.reference.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref(fileName);
    final UploadTask uploadTask;
    if (kIsWeb) {
      final bytes = await imageFile.readAsBytes();
      uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } else {
      uploadTask = ref.putFile(
        File(imageFile.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
    }
    final snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }

  Future<void> _handleEditGroupChat(
    ChatsRecord chat, {
    String? newName,
    XFile? imageFile,
  }) async {
    if (!chat.isGroup ||
        !ChatHelpers.isGroupOwner(chat, currentUserReference)) {
      return;
    }

    final oldName = chat.title;
    final nameChanged = newName != null && newName.isNotEmpty && newName != oldName;
    final imageChanged = imageFile != null;
    if (!nameChanged && !imageChanged) return;

    try {
      final userName = currentUserDisplayName.isNotEmpty
          ? currentUserDisplayName
          : (currentUserDocument?.displayName ?? 'Someone');
      final patch = <String, dynamic>{};
      String? systemMessage;
      String? newImageUrl;

      if (imageChanged) {
        newImageUrl = await _uploadExistingGroupImage(chat, imageFile);
        patch['chat_image_url'] = newImageUrl;
      }
      if (nameChanged) {
        patch['title'] = newName;
      }

      if (nameChanged && imageChanged) {
        systemMessage =
            '$userName updated the group name from "$oldName" to "$newName" and changed the group photo';
      } else if (nameChanged) {
        systemMessage =
            '$userName updated the group name from "$oldName" to "$newName"';
      } else {
        systemMessage = '$userName changed the group photo';
      }

      patch['last_message'] = systemMessage;
      patch['last_message_at'] = getCurrentTimestamp;
      patch['last_message_sent'] = currentUserReference;

      await fsPatchDocument(chat.reference, patch);

      await fsCreateMessage(chat.reference, {
        'content': systemMessage,
        'created_at': getCurrentTimestamp,
        'sender_ref': currentUserReference,
        'sender_name': userName,
        'sender_photo': currentUserPhoto.isNotEmpty
            ? currentUserPhoto
            : (currentUserDocument?.photoUrl ?? ''),
        'is_system_message': true,
        'is_read_by': [currentUserReference],
      });

      chatController.applyLocalChatLastMessageFromPatch(chat.reference, patch);

      if (_model.selectedChat?.reference.id == chat.reference.id) {
        final data = Map<String, dynamic>.from(chat.snapshotData);
        if (nameChanged) data['title'] = newName;
        if (newImageUrl != null) data['chat_image_url'] = newImageUrl;
        data['last_message'] = systemMessage;
        data['last_message_at'] = getCurrentTimestamp;
        data['last_message_sent'] = currentUserReference;
        setState(() {
          _model.selectedChat =
              ChatsRecord.getDocumentFromData(data, chat.reference);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nameChanged && imageChanged
                  ? 'Group updated successfully'
                  : nameChanged
                      ? 'Group renamed successfully'
                      : 'Group photo updated successfully',
            ),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugLog('❌ Error editing group chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating group: $e'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      rethrow;
    }
  }

  void _showRenameFolderDialog(ChatFoldersRecord folder) {
    final controller = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Rename Folder',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Folder name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFF3B82F6)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xFF111827),
          ),
          onSubmitted: (value) {
            final name = value.trim();
            if (name.isNotEmpty) {
              Navigator.of(ctx).pop();
              _handleRenameFolder(folder, name);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style:
                    TextStyle(fontFamily: 'Inter', color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();
              _handleRenameFolder(folder, name);
            },
            child: Text('Rename',
                style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderDialog(ChatFoldersRecord folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Delete Folder',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        content: Text(
          'Delete the folder "${folder.name}"? Chats will not be deleted.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style:
                    TextStyle(fontFamily: 'Inter', color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteFolder(folder);
            },
            child: Text('Delete',
                style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showFolderContextMenu(Offset position, ChatFoldersRecord folder) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
      items: [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16, color: Color(0xFF374151)),
              SizedBox(width: 8),
              Text('Rename',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF111827))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text('Delete',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFFEF4444))),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'rename') {
        _showRenameFolderDialog(folder);
      } else if (value == 'delete') {
        _showDeleteFolderDialog(folder);
      }
    });
  }

  void _showMoveToFolderMenu(Offset position, ChatsRecord chat) {
    // A chat can only live in one folder. If it's already filed, every other
    // folder is disabled — the user must "Move to Unfiled" first to relocate it.
    // Pinned chats take precedence and can't be added to any folder.
    final isFiledElsewhere =
        _model.chatFolders.any((f) => f.chatIds.contains(chat.reference.id));
    final isPinned = chat.isPinnedByUser(currentUserReference);
    final items = <PopupMenuEntry<String>>[
      // Existing folders
      for (final folder in _model.chatFolders)
        () {
          final containsChat = folder.chatIds.contains(chat.reference.id);
          final isLocked = isPinned || (isFiledElsewhere && !containsChat);
          return PopupMenuItem<String>(
            value: folder.reference.id,
            enabled: !isLocked,
            child: Opacity(
              opacity: isLocked ? 0.4 : 1.0,
              child: Row(
                children: [
                  Icon(
                    containsChat ? Icons.folder_rounded : Icons.folder_outlined,
                    size: 16,
                    color: containsChat ? Color(0xFF3B82F6) : Color(0xFF374151),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      folder.name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Color(0xFF111827),
                        fontWeight:
                            containsChat ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (containsChat)
                    Icon(Icons.check, size: 14, color: Color(0xFF3B82F6)),
                ],
              ),
            ),
          );
        }(),
      if (_model.chatFolders.isNotEmpty) PopupMenuDivider(),
      // Remove from folder
      PopupMenuItem<String>(
        value: '_remove',
        child: Row(
          children: [
            Icon(Icons.inbox_outlined, size: 16, color: Color(0xFF6B7280)),
            SizedBox(width: 8),
            Text('Move to Unfiled',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF6B7280))),
          ],
        ),
      ),
      PopupMenuDivider(),
      // Create new folder
      PopupMenuItem<String>(
        value: '_new',
        child: Row(
          children: [
            Icon(Icons.create_new_folder_outlined,
                size: 16, color: Color(0xFF3B82F6)),
            SizedBox(width: 8),
            Text('New Folder',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    ];

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
      items: items,
    ).then((value) async {
      if (value == null) return;
      if (value == '_new') {
        _showCreateFolderDialog();
        return;
      }

      final chatId = chat.reference.id;
      final previousFolders = _model.chatFolders;

      if (value == '_remove') {
        _applyLocalChatFolderMembership(chatIds: [chatId]);
        try {
          for (final folder in previousFolders) {
            if (folder.chatIds.contains(chatId)) {
              await fsArrayRemove(
                folder.reference,
                'chat_ids',
                [chatId],
              );
              await fsPatchDocument(folder.reference, {
                'updated_at': getCurrentTimestamp,
              });
            }
          }
        } catch (e) {
          debugLog('❌ Error moving chat to unfiled: $e');
          if (mounted) {
            setState(() => _model.chatFolders = previousFolders);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error moving chat: $e'),
                backgroundColor: Color(0xFFEF4444),
              ),
            );
          }
        }
        return;
      }

      _applyLocalChatFolderMembership(
        chatIds: [chatId],
        targetFolderId: value,
      );
      try {
        for (final folder in previousFolders) {
          if (folder.reference.id != value && folder.chatIds.contains(chatId)) {
            await fsArrayRemove(
              folder.reference,
              'chat_ids',
              [chatId],
            );
            await fsPatchDocument(folder.reference, {
              'updated_at': getCurrentTimestamp,
            });
          }
        }
        final targetRef =
            currentUserReference!.collection('chat_folders').doc(value);
        await fsArrayUnion(targetRef, 'chat_ids', [chatId]);
        await fsPatchDocument(targetRef, {
          'updated_at': getCurrentTimestamp,
        });
      } catch (e) {
        debugLog('❌ Error moving chat to folder: $e');
        if (mounted) {
          setState(() => _model.chatFolders = previousFolders);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error moving chat to folder: $e'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      }
    });
  }

  Future<UsersRecord> _getOtherUser(ChatsRecord chat) async {
    final otherUserRef = chat.members.firstWhere(
      (member) => member != currentUserReference,
      orElse: () => chat.members.first,
    );
    return await fsGetUserOnce(otherUserRef);
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
              ).withClickCursor(),
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
                      ).withClickCursor(),
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
                    child: DesktopSafeUserBuilder(
                      userRef: currentUserReference!,
                      fetchOnce: _getOrCreateUserFuture,
                      builder: (context, currentUser) {
                        if (currentUser == null) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF3B82F6),
                            ),
                          );
                        }

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

                            return DesktopSafeUserBuilder(
                              userRef: connectionRef,
                              fetchOnce: _getOrCreateUserFuture,
                              builder: (context, user) {
                                if (user == null) {
                                  return SizedBox.shrink();
                                }

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
                                  mouseCursor:
                                      MaterialStateMouseCursor.clickable,
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
    _model.showGroupCreation = false;
    _model.newMessageSelectedMembers = [];
    _model.isCreatingNewMessageChat = false;
    _model.groupChatTab = GroupChatTab.messages;
  }

  List<(String, GroupChatTab, IconData)> _chatHeaderTabConfigs(
      ChatsRecord chat) {
    const dmTabs = <(String, GroupChatTab, IconData)>[
      ('Messages', GroupChatTab.messages, Icons.chat_bubble_outline_rounded),
      ('Files and Links', GroupChatTab.filesAndLinks, Icons.folder_outlined),
      ('Action Tasks', GroupChatTab.actionTasks, Icons.checklist_rounded),
      ('Pinned Messages', GroupChatTab.pinnedMessages, Icons.push_pin_outlined),
    ];
    if (!chat.isGroup) return dmTabs;

    return [
      ...dmTabs.sublist(0, 3),
      ('Announcements', GroupChatTab.announcements, Icons.campaign_outlined),
      dmTabs[3],
    ];
  }

  void _selectGroupChatTab(GroupChatTab tab) {
    final chat = _model.selectedChat;
    if (chat != null && !chat.isGroup && tab == GroupChatTab.announcements) {
      tab = GroupChatTab.messages;
    }
    setState(() {
      _model.groupChatTab = tab;
      _model.showTasksPanel = false;
      _model.showAnnouncementsPanel = false;
      _model.showPinnedMessagesPopup = false;
      _model.pinnedMessagesPopupChat = null;
      _model.showGroupFilesPopup = false;
      _model.groupFilesPopupChat = null;
    });
    _scheduleGroupTabIndicatorUpdate();
  }

  void _scheduleGroupTabIndicatorUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final chat = _model.selectedChat;
      if (chat == null) return;

      final tabConfigs = _chatHeaderTabConfigs(chat);
      final tabIndex =
          tabConfigs.indexWhere((config) => config.$2 == _model.groupChatTab);
      if (tabIndex < 0 || tabIndex >= _groupTabKeys.length) return;

      final tabContext = _groupTabKeys[tabIndex].currentContext;
      final rowContext = _groupTabRowKey.currentContext;
      if (tabContext == null || rowContext == null) return;

      final tabBox = tabContext.findRenderObject() as RenderBox?;
      final rowBox = rowContext.findRenderObject() as RenderBox?;
      if (tabBox == null || !tabBox.hasSize || rowBox == null) return;

      final tabOffset = tabBox.localToGlobal(Offset.zero, ancestor: rowBox);
      final nextLeft = tabOffset.dx;
      final nextWidth = tabBox.size.width;

      if (_groupTabIndicatorLeft == nextLeft &&
          _groupTabIndicatorWidth == nextWidth &&
          _groupTabIndicatorReady) {
        return;
      }

      setState(() {
        _groupTabIndicatorLeft = nextLeft;
        _groupTabIndicatorWidth = nextWidth;
        _groupTabIndicatorReady = true;
      });
    });
  }

  Widget _buildChatTabBody(ChatsRecord chat) {
    switch (_model.groupChatTab) {
      case GroupChatTab.messages:
        return Column(
          children: [
            if (chat.isGroup) _buildAnnouncementBanner(chat),
            Expanded(
              child: _buildPlatformChatThread(key: _chatThreadKey),
            ),
            if (_isSelectionMode) _buildSelectionBar(),
          ],
        );
      case GroupChatTab.filesAndLinks:
        return GroupMediaLinksDocsWidget(
          key: ValueKey('chat-media-${chat.reference.path}'),
          chatDoc: chat,
          embedded: true,
        );
      case GroupChatTab.actionTasks:
        return GroupActionTasksWidget(chatDoc: chat, embedded: true);
      case GroupChatTab.announcements:
        return GroupAnnouncementsWidget(chatDoc: chat, embedded: true);
      case GroupChatTab.pinnedMessages:
        return ColoredBox(
          color: Colors.white,
          child: _buildPinnedMessagesPopupContent(chat, inTabView: true),
        );
    }
  }

  Widget _buildChatHeaderTabs(ChatsRecord chat) {
    _scheduleGroupTabIndicatorUpdate();

    final tabConfigs = _chatHeaderTabConfigs(chat);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Stack(
            key: _groupTabRowKey,
            clipBehavior: Clip.none,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < tabConfigs.length; i++) ...[
                    if (i > 0) const SizedBox(width: 20),
                    _buildGroupChatHeaderTabItem(
                      tabConfigs[i].$1,
                      tabConfigs[i].$2,
                      tabConfigs[i].$3,
                      key: _groupTabKeys[i],
                    ),
                  ],
                ],
              ),
              if (_groupTabIndicatorReady)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  left: _groupTabIndicatorLeft,
                  bottom: 0,
                  width: _groupTabIndicatorWidth,
                  height: 2,
                  child: const ColoredBox(color: Color(0xFF3B82F6)),
                ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
      ],
    );
  }

  Widget _buildGroupChatHeaderTabItem(
    String label,
    GroupChatTab tab,
    IconData icon, {
    Key? key,
  }) {
    final isSelected = _model.groupChatTab == tab;
    const activeBlue = Color(0xFF3B82F6);
    const inactiveColor = Color(0xFF6B7280);

    return InkWell(
      key: key,
      mouseCursor: MaterialStateMouseCursor.clickable,
      onTap: () => _selectGroupChatTab(tab),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeBlue : inactiveColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? activeBlue : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startNewChatWithUser(UsersRecord user) async {
    try {
      final chatToOpen =
          await ChatHelpers.findOrCreateDirectChat(user.reference);

      setState(() {
        _clearAllViews();
        _model.selectedChat = chatToOpen;
      });
      chatController.selectChat(chatToOpen);
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
            final currentUser = await fsGetUserOnce(currentUserReference!);
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
            final user = await fsGetUserOnce(memberRef);
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
      final newChatRef = await fsCreateChat({
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
        'admin_users': [currentUserReference],
        'last_message_seen': [
          currentUserReference ??
              FirebaseFirestore.instance.collection('users').doc('placeholder')
        ],
      });

      // Send greeting message so the chat appears in the list
      final greeting =
          '${currentUserDisplayName.isNotEmpty ? currentUserDisplayName : "You"} created the group';

      await fsCreateMessage(newChatRef, {
        'content': greeting,
        'created_at': getCurrentTimestamp,
        'sender_ref': currentUserReference,
        'is_system_message': true,
        'is_read_by': [currentUserReference],
      });

      // Update chat with last message
      await fsPatchDocument(newChatRef, {
        'last_message': greeting,
        'last_message_at': getCurrentTimestamp,
        'last_message_sent': currentUserReference,
      });

      // Get the created chat document
      final newChat = await fsGetChatOnce(newChatRef);

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

  Future<void> _showNewMessageDialog() async {
    await showNewMessageDialog(
      context: context,
      searchController: _model.newMessageSearchController!,
      initialSelectedMembers: _model.newMessageSelectedMembers,
      fetchUser: _getOrCreateUserFuture,
      onSubmit: _createChatFromNewMessageSelection,
    );

    if (mounted) {
      setState(() {
        _model.newMessageSelectedMembers = [];
        _model.newMessageSearchController?.clear();
        _model.isCreatingNewMessageChat = false;
      });
    }
  }

  /// Creates a direct message when a single person is selected, or a group
  /// chat when multiple people are selected, from the New Message dialog.
  Future<void> _createChatFromNewMessageSelection(
    List<DocumentReference> selected,
  ) async {
    if (selected.isEmpty) return;

    _model.newMessageSelectedMembers = List.from(selected);
    setState(() => _model.isCreatingNewMessageChat = true);
    try {
      if (selected.length == 1) {
        final user = await _getOrCreateUserFuture(selected.first);
        await _startNewChatWithUser(user);
      } else {
        _model.selectedMembers = List.from(selected);
        _model.groupName = '';
        _model.groupNameController?.clear();
        _model.groupImagePath = null;
        _model.groupImageUrl = null;
        _model.isUploadingImage = false;
        await _createGroup();
      }
    } finally {
      if (mounted) {
        setState(() {
          _model.isCreatingNewMessageChat = false;
          _model.newMessageSelectedMembers = [];
          _model.newMessageSearchController?.clear();
        });
      }
    }
  }

  Widget _buildRightPanel() {
    // Determine if any right-side panel should be shown
    final showAnyPanel = _model.showGroupCreation ||
        (_model.showGroupInfoPanel && _model.groupInfoChat != null) ||
        (_model.showUserProfilePanel && _model.userProfileUser != null) ||
        _model.showChatHistoryPanel ||
        _model.showAnnouncementsPanel;

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
                      _model.newMessageSelectedMembers = [];
                      _model.showGroupInfoPanel = false;
                      _model.groupInfoChat = null;
                      _model.showUserProfilePanel = false;
                      _model.userProfileUser = null;
                      _model.showChatHistoryPanel = false;
                      _model.showAnnouncementsPanel = false;
                    });
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                  ),
                ).withClickCursor(),
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

              if (_model.showChatHistoryPanel)
                _buildRightSidePanel(
                  ChatHistoryWidget(
                    chatDoc: _model.selectedChat!,
                    showAppBar: false,
                    onMessageSelected: (messageId) {
                      setState(() {
                        _model.showChatHistoryPanel = false;
                      });
                      _chatThreadKey.currentState?.scrollToMessage(messageId);
                    },
                  ),
                  () {
                    setState(() {
                      _model.showChatHistoryPanel = false;
                    });
                  },
                ),

              if (_model.showAnnouncementsPanel && _model.selectedChat != null)
                _buildRightSidePanel(
                  GroupAnnouncementsWidget(
                    chatDoc: _model.selectedChat,
                    onClose: () {
                      setState(() {
                        _model.showAnnouncementsPanel = false;
                      });
                    },
                  ),
                  () {
                    setState(() {
                      _model.showAnnouncementsPanel = false;
                    });
                  },
                ),
            ],

            // Meeting Transcripts popup overlay (positioned slightly up)
            if (_model.showMeetingTranscriptsPopup &&
                _model.meetingTranscriptsPopupChat != null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _model.showMeetingTranscriptsPopup = false;
                      _model.meetingTranscriptsPopupChat = null;
                    });
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.35),
                    child: Align(
                      alignment: const Alignment(0.0, -0.25),
                      child: GestureDetector(
                        onTap: () {},
                        behavior: HitTestBehavior.opaque,
                        child: _buildMeetingTranscriptsPopupCard(),
                      ).withClickCursor(),
                    ),
                  ),
                ).withClickCursor(),
              ),

            // Pinned Messages popup overlay
            if (_model.showPinnedMessagesPopup &&
                _model.pinnedMessagesPopupChat != null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _model.showPinnedMessagesPopup = false;
                      _model.pinnedMessagesPopupChat = null;
                    });
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.35),
                    child: Align(
                      alignment: const Alignment(0.0, -0.15),
                      child: GestureDetector(
                        onTap: () {},
                        behavior: HitTestBehavior.opaque,
                        child: _buildPinnedMessagesPopupCard(),
                      ).withClickCursor(),
                    ),
                  ),
                ).withClickCursor(),
              ),
            // Group Files popup overlay
            if (_model.showGroupFilesPopup &&
                _model.groupFilesPopupChat != null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _model.showGroupFilesPopup = false;
                      _model.groupFilesPopupChat = null;
                    });
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.35),
                    child: Align(
                      alignment: const Alignment(0.0, -0.15),
                      child: GestureDetector(
                        onTap: () {},
                        behavior: HitTestBehavior.opaque,
                        child: _buildGroupFilesPopupCard(),
                      ).withClickCursor(),
                    ),
                  ),
                ).withClickCursor(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingTranscriptsPopupCard() {
    final chat = _model.meetingTranscriptsPopupChat!;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 420,
        constraints: BoxConstraints(maxWidth: 420, maxHeight: 520),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: SingleChildScrollView(
              child: MeetingTranscriptsPanelWidget(
                chatDoc: chat,
                showCloseButton: true,
                onClose: () {
                  setState(() {
                    _model.showMeetingTranscriptsPopup = false;
                    _model.meetingTranscriptsPopupChat = null;
                  });
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedMessagesPopupCard() {
    final chat = _model.pinnedMessagesPopupChat!;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 32,
              offset: Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: Color(0xFFFAFBFC),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(Icons.push_pin,
                          size: 20, color: Color(0xFF3B82F6)),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Pinned Messages',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Spacer(),
                  InkWell(
                    mouseCursor: MaterialStateMouseCursor.clickable,
                    onTap: () {
                      setState(() {
                        _model.showPinnedMessagesPopup = false;
                        _model.pinnedMessagesPopupChat = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Color(0xFFE5E7EB)),
                      ),
                      child:
                          Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
            ),
            // Content — pinned messages
            Flexible(
              child: _buildPinnedMessagesPopupContent(chat),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedMessagesPopupContent(
    ChatsRecord chat, {
    bool inTabView = false,
  }) {
    Widget buildBody(AsyncSnapshot<List<MessagesRecord>> snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting &&
          !snapshot.hasData) {
        return Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
            ),
          ),
        );
      }

      final pinnedMessages = (snapshot.data ?? [])
        ..sort((a, b) {
          final aTime = a.createdAt;
          final bTime = b.createdAt;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

      if (pinnedMessages.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.push_pin_outlined,
                size: 48,
                color: Color(0xFFD1D5DB),
              ),
              SizedBox(height: 12),
              Text(
                'No pinned messages',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Long-press a message and select "Pin" to pin it here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        shrinkWrap: !inTabView,
        padding: EdgeInsets.symmetric(
          vertical: 8,
          horizontal: inTabView ? 4 : 0,
        ),
        itemCount: pinnedMessages.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: Color(0xFFF3F4F6),
          indent: 16,
          endIndent: 16,
        ),
        itemBuilder: (context, index) {
          final msg = pinnedMessages[index];
          final senderName =
              msg.senderName.isNotEmpty ? msg.senderName : 'Unknown';
          final content = msg.content.isNotEmpty
              ? msg.content
              : (msg.attachmentUrl.isNotEmpty
                  ? '📎 Attachment'
                  : (msg.image.isNotEmpty ? '🖼️ Image' : '💬 Message'));
          final timestamp = msg.createdAt?.toLocal();
          final timeStr = timestamp != null
              ? DateFormat('M/d/yyyy h:mm a').format(timestamp)
              : '';

          return InkWell(
            mouseCursor: MaterialStateMouseCursor.clickable,
            onTap: () {
              final messageId = msg.reference.id;
              if (inTabView) {
                _selectGroupChatTab(GroupChatTab.messages);
              } else {
                setState(() {
                  _model.showPinnedMessagesPopup = false;
                  _model.pinnedMessagesPopupChat = null;
                });
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _chatThreadKey.currentState?.scrollToMessage(messageId);
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.push_pin,
                        size: 14,
                        color: Color(0xFF3B82F6),
                      ),
                      SizedBox(width: 6),
                      Text(
                        senderName,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Spacer(),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    content.length > 200
                        ? '${content.substring(0, 200)}...'
                        : content,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      color: Color(0xFF374151),
                      height: 1.4,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (msg.image.isNotEmpty || msg.images.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(Icons.image, size: 14, color: Color(0xFF9CA3AF)),
                          SizedBox(width: 4),
                          Text(
                            '${1 + msg.images.length} image(s)',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (useWindowsFirestoreRest) {
      return _RestPollBuilder<List<MessagesRecord>>(
        interval: const Duration(seconds: 10),
        fetch: () => fsQueryPinnedMessages(chat.reference),
        builder: (context, snapshot) => buildBody(snapshot),
      );
    }

    return StreamBuilder<List<MessagesRecord>>(
      stream: queryMessagesRecord(
        parent: chat.reference,
        queryBuilder: (q) => q.where('is_pinned', isEqualTo: true),
      ),
      builder: (context, snapshot) => buildBody(snapshot),
    );
  }

  Widget _buildGroupFilesPopupCard() {
    final chat = _model.groupFilesPopupChat!;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 32,
              offset: Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: Color(0xFFFAFBFC),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(Icons.folder_rounded,
                          size: 20, color: Color(0xFF3B82F6)),
                    ),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Group Files',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Files expire after 30 days',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  Spacer(),
                  InkWell(
                    mouseCursor: MaterialStateMouseCursor.clickable,
                    onTap: () {
                      setState(() {
                        _model.showGroupFilesPopup = false;
                        _model.groupFilesPopupChat = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Color(0xFFE5E7EB)),
                      ),
                      child:
                          Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: _buildGroupFilesPopupContent(chat),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupFilesPopupContent(ChatsRecord chat) {
    Widget buildBody(AsyncSnapshot<List<MessagesRecord>> snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting &&
          !snapshot.hasData) {
        return Padding(
          padding: const EdgeInsets.all(60),
          child: Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
            ),
          ),
        );
      }

      final fileMessages = (snapshot.data ?? []).where((msg) {
        if (msg.attachmentUrl.isEmpty) return false;
        if (msg.messageType == MessageType.image ||
            msg.messageType == MessageType.voice ||
            msg.messageType == MessageType.video) {
          return false;
        }
        if (msg.image.isNotEmpty || msg.images.isNotEmpty) return false;
        if (msg.audio.isNotEmpty || msg.video.isNotEmpty) return false;
        return true;
      }).toList();

      if (fileMessages.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_rounded,
                  size: 56, color: Color(0xFFD1D5DB)),
              SizedBox(height: 16),
              Text('No files shared yet',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280))),
              SizedBox(height: 6),
              Text('Files shared in this group will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF9CA3AF))),
            ],
          ),
        );
      }

      return Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1))),
            child: Row(
              children: [
                Text(
                    '${fileMessages.length} file${fileMessages.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280))),
                Spacer(),
                Text('Sorted by newest',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: fileMessages.length,
              itemBuilder: (context, index) {
                final msg = fileMessages[index];
                final senderName =
                    msg.senderName.isNotEmpty ? msg.senderName : 'Unknown';
                final timestamp = msg.createdAt;
                final daysAgo = timestamp != null
                    ? DateTime.now().difference(timestamp).inDays
                    : 0;
                final daysAgoStr = daysAgo == 0
                    ? 'Today'
                    : (daysAgo == 1 ? 'Yesterday' : '$daysAgo days ago');
                final isExpired = daysAgo > 30;

                final fileUrl = msg.attachmentUrl;
                String fileName;
                final storedFileName = msg.snapshotData['file_name'];
                if (storedFileName is String &&
                    storedFileName.trim().isNotEmpty) {
                  fileName = storedFileName.trim();
                } else if (msg.content.isNotEmpty &&
                    msg.content.contains('.') &&
                    msg.content.length < 150 &&
                    !msg.content.contains('/') &&
                    msg.content.split(' ').length < 8) {
                  fileName = msg.content;
                } else {
                  try {
                    final decodedPath = Uri.decodeComponent(fileUrl);
                    final match =
                        RegExp(r'\/([^\/\?]+)\?').firstMatch(decodedPath);
                    String raw = '';
                    if (match != null) {
                      raw = match.group(1)!;
                    } else {
                      final uri = Uri.parse(fileUrl);
                      raw = uri.pathSegments.isNotEmpty
                          ? uri.pathSegments.last
                          : 'file';
                      if (raw.contains('/')) raw = raw.split('/').last;
                      if (raw.contains('?')) raw = raw.split('?').first;
                    }
                    raw = Uri.decodeComponent(raw);
                    final stripped = raw.replaceFirst(RegExp(r'^\d{10,}_'), '');
                    fileName = (stripped.isNotEmpty && stripped.contains('.'))
                        ? stripped
                        : (raw.isNotEmpty ? raw : 'File');
                  } catch (_) {
                    fileName = 'File';
                  }
                }

                final ext = fileName.split('.').last.toLowerCase();
                IconData fileIcon;
                Color fileIconColor;
                if (['pdf'].contains(ext)) {
                  fileIcon = Icons.picture_as_pdf_rounded;
                  fileIconColor = Color(0xFFDC2626);
                } else if (['doc', 'docx'].contains(ext)) {
                  fileIcon = Icons.description_rounded;
                  fileIconColor = Color(0xFF2563EB);
                } else if (['xls', 'xlsx', 'csv'].contains(ext)) {
                  fileIcon = Icons.table_chart_rounded;
                  fileIconColor = Color(0xFF059669);
                } else if (['ppt', 'pptx'].contains(ext)) {
                  fileIcon = Icons.slideshow_rounded;
                  fileIconColor = Color(0xFFEA580C);
                } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
                  fileIcon = Icons.folder_zip_rounded;
                  fileIconColor = Color(0xFF7C3AED);
                } else if ([
                  'env',
                  'txt',
                  'json',
                  'yml',
                  'yaml',
                  'md',
                  'js',
                  'dart',
                  'py'
                ].contains(ext)) {
                  fileIcon = Icons.code_rounded;
                  fileIconColor = Color(0xFF475569);
                } else {
                  fileIcon = Icons.insert_drive_file_rounded;
                  fileIconColor = Color(0xFF6B7280);
                }

                return InkWell(
                  mouseCursor: MaterialStateMouseCursor.clickable,
                  onTap: isExpired
                      ? null
                      : () async {
                          if (fileUrl.isNotEmpty) {
                            await qurioLaunchUrl(fileUrl);
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: Color(0xFFF3F4F6), width: 1))),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: isExpired
                                  ? Color(0xFFF3F4F6)
                                  : fileIconColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: Center(
                              child: Icon(fileIcon,
                                  size: 22,
                                  color: isExpired
                                      ? Color(0xFFD1D5DB)
                                      : fileIconColor)),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fileName,
                                  style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isExpired
                                          ? Color(0xFF9CA3AF)
                                          : Color(0xFF111827),
                                      decoration: isExpired
                                          ? TextDecoration.lineThrough
                                          : null),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              SizedBox(height: 4),
                              Row(children: [
                                Icon(Icons.person_outline,
                                    size: 12, color: Color(0xFFBBBFCA)),
                                SizedBox(width: 4),
                                Text(senderName,
                                    style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: Color(0xFF9CA3AF))),
                                SizedBox(width: 12),
                                Icon(Icons.access_time,
                                    size: 12, color: Color(0xFFBBBFCA)),
                                SizedBox(width: 4),
                                Text(daysAgoStr,
                                    style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: Color(0xFF9CA3AF))),
                              ]),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        if (isExpired)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Color(0xFFFECACA))),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.timer_off_rounded,
                                  size: 12, color: Color(0xFFEF4444)),
                              SizedBox(width: 4),
                              Text('Expired',
                                  style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFEF4444))),
                            ]),
                          )
                        else
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Color(0xFFBFDBFE))),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.download_rounded,
                                  size: 14, color: Color(0xFF3B82F6)),
                              SizedBox(width: 4),
                              Text('Download',
                                  style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF3B82F6))),
                            ]),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    if (useWindowsFirestoreRest) {
      return _RestPollBuilder<List<MessagesRecord>>(
        interval: const Duration(seconds: 15),
        fetch: () => fsQueryChatMessages(chat.reference, limit: 200),
        builder: (context, snapshot) => buildBody(snapshot),
      );
    }

    return StreamBuilder<List<MessagesRecord>>(
      stream: queryMessagesRecord(
        parent: chat.reference,
        queryBuilder: (q) => q.orderBy('created_at', descending: true),
      ),
      builder: (context, snapshot) => buildBody(snapshot),
    );
  }

  Widget _buildDefaultChatView() {
    // Full search page takes priority
    if (_model.showFullSearch) {
      return _buildFullSearchPage();
    }

    return _model.selectedChat != null
        ? Column(
            children: [
              _buildChatHeader(),
              Expanded(
                child: _buildChatTabBody(_model.selectedChat!),
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
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: Color.fromRGBO(250, 252, 255, 1), // Match left sidebar color
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChatHeaderMainRow(chat),
          _buildChatHeaderTabs(chat),
        ],
      ),
    );
  }

  Widget _buildChatHeaderMainRow(ChatsRecord chat) {
    return Row(
      children: [
        // User avatar
        _buildHeaderAvatar(chat),
        SizedBox(width: 12),
        // User info
        Expanded(
          child: _buildHeaderName(chat),
        ),
        if (chat.isGroup) _buildGroupMembersHeaderButton(chat),
        _buildChatSearchHeaderButton(),
        // Google Meet icon
        if (chat.isGroup)
          Tooltip(
            message: chat.hasActiveMeeting
                ? 'Join active meeting'
                : 'Start a Google Meet',
            child: InkWell(
              mouseCursor: MaterialStateMouseCursor.clickable,
              onTap: () async {
                if (chat.hasActiveMeeting) {
                  // Join existing meeting
                  await MeetingService.joinMeeting(chatRef: chat.reference);
                  await qurioLaunchUrl(chat.activeMeetingUrl);
                } else {
                  // Try one-click first (uses Qurio token or Firebase popup)
                  final meetUrl = await GoogleMeetCreator.createInstantMeeting(
                    chatTitle:
                        chat.title.isNotEmpty ? chat.title : 'Quick Meeting',
                  );
                  if (meetUrl != null) {
                    await MeetingService.startMeeting(
                      chatRef: chat.reference,
                      meetUrl: meetUrl,
                      starterName: currentUserDocument?.displayName,
                    );
                    await qurioLaunchUrl(meetUrl);
                  } else {
                    // Fallback: dialog for manual link
                    final manualUrl = await _showStartMeetingDialog();
                    if (manualUrl != null && manualUrl.isNotEmpty) {
                      await MeetingService.startMeeting(
                        chatRef: chat.reference,
                        meetUrl: manualUrl,
                        starterName: currentUserDocument?.displayName,
                      );
                      await qurioLaunchUrl(manualUrl);
                    }
                  }
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
                  if (value == 'search') {
                    _openChatSearchPanel();
                  } else if (value == 'add_members') {
                    _navigateToAddMembers(chat);
                  } else if (value == 'group_info') {
                    _viewGroupChat(chat);
                  }
                },
                itemBuilder: (BuildContext context) {
                  // Group chat options
                  return <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'search',
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: Color(0xFF374151),
                            size: 18,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Search in chat',
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
                    if (ChatHelpers.isGroupAdmin(chat, currentUserReference))
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
                    PopupMenuDivider(),
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
                  if (value == 'search') {
                    _openChatSearchPanel();
                  } else if (value == 'profile') {
                    _viewUserProfile(chat);
                  } else if (value == 'block_toggle') {
                    _toggleBlockUser(chat);
                  } else if (value == 'group') {
                    _viewGroupChat(chat);
                  }
                },
                itemBuilder: (BuildContext context) {
                  // Direct chat options
                  final otherUserRef = chat.members.firstWhere(
                    (member) => member != currentUserReference,
                    orElse: () => chat.members.first,
                  );

                  return <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'search',
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: Color(0xFF374151),
                            size: 18,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Search in chat',
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
                      value: 'block_toggle',
                      child: Obx(() {
                        final isBlockedNow = chatController.blockedUserIds.value
                            .contains(otherUserRef.id);
                        return Row(
                          children: [
                            Icon(
                              isBlockedNow ? Icons.check_circle : Icons.block,
                              color: isBlockedNow
                                  ? Color(0xFF10B981)
                                  : Color(0xFFDC2626),
                              size: 18,
                            ),
                            SizedBox(width: 12),
                            Text(
                              isBlockedNow ? 'Unblock User' : 'Block User',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: isBlockedNow
                                    ? Color(0xFF10B981)
                                    : Color(0xFFDC2626),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      }),
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
    );
  }

  static String _normalizeActionItemPath(String path) {
    if (path.isEmpty) return path;
    if (path.contains('/')) return path;
    return 'action_items/$path';
  }

  Future<void> _markActionItemDone(String actionItemRefPath) async {
    final path = _normalizeActionItemPath(actionItemRefPath);
    try {
      final ref = FirebaseFirestore.instance.doc(path);
      if (!await fsDocumentExists(ref)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Task already completed or removed',
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'Inter',
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            backgroundColor: FlutterFlowTheme.of(context).secondaryText,
          ),
        );
        return;
      }
      await fsMarkActionItemDone(ref);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'not-found'
                ? 'Task already completed or removed'
                : 'Failed to update: ${e.message}',
          ),
          backgroundColor: e.code == 'not-found'
              ? FlutterFlowTheme.of(context).secondaryText
              : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to update: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _remindAgain(String actionItemRefPath) async {
    final path = _normalizeActionItemPath(actionItemRefPath);
    try {
      final ref = FirebaseFirestore.instance.doc(path);
      if (!await fsDocumentExists(ref)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task no longer found'),
            backgroundColor: FlutterFlowTheme.of(context).secondaryText,
          ),
        );
        return;
      }
      await fsDeleteDocumentField(ref, 'last_reminder_at');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reminder will be sent again on the next run',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'Inter',
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  fontWeight: FontWeight.w500,
                ),
          ),
          backgroundColor: FlutterFlowTheme.of(context).primary,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to update: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildActionItemsStats(ChatsRecord chat) {
    if (useWindowsFirestoreRest) {
      return _RestPollBuilder<List<ActionItemsRecord>>(
        interval: const Duration(seconds: 20),
        fetch: () => fsQueryActionItemsByChat(chat.reference),
        builder: (context, snapshot) =>
            _buildActionItemsStatsBody(context, chat, snapshot),
      );
    }

    final stream = queryActionItemsRecord(
      queryBuilder: (actionItemsRecord) => actionItemsRecord.where(
        'chat_ref',
        isEqualTo: chat.reference,
      ),
    );

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      return _DeferredFirestoreStream<List<ActionItemsRecord>>(
        delay: const Duration(milliseconds: 1200),
        stream: stream,
        placeholder: const SizedBox.shrink(),
        builder: (context, snapshot) =>
            _buildActionItemsStatsBody(context, chat, snapshot),
      );
    }

    return StreamBuilder<List<ActionItemsRecord>>(
      stream: stream,
      builder: (context, snapshot) =>
          _buildActionItemsStatsBody(context, chat, snapshot),
    );
  }

  Widget _buildActionItemsStatsBody(
    BuildContext context,
    ChatsRecord chat,
    AsyncSnapshot<List<ActionItemsRecord>> snapshot,
  ) {
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

    final now = DateTime.now();
    final overdueCount = pendingItems.where((item) {
      final due = item.dueDate;
      return due != null && due.isBefore(now);
    }).length;

    final overdueItems = pendingItems.where((item) {
      final due = item.dueDate;
      return due != null && due.isBefore(now);
    }).toList();

    final overdueTasksForCard = overdueItems.map((item) {
      return <String, dynamic>{
        'title': item.title,
        'priority': item.priority,
        'description': item.description,
        'involved_people': item.involvedPeople,
        'due_date': item.dueDate,
        'created_time': item.createdTime,
        'action_item_ref': item.reference.path,
      };
    }).toList();

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

    final isMacOSOrWeb =
        kIsWeb || defaultTargetPlatform == TargetPlatform.macOS;

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
                    mouseCursor: MaterialStateMouseCursor.clickable,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isMacOSOrWeb && overdueCount > 0) ...[
                    Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: Color(0xFFDC2626),
                          )
                              .animate(
                                onPlay: (c) => c.repeat(reverse: true),
                              )
                              .scale(
                                begin: Offset(0.95, 0.95),
                                end: Offset(1.2, 1.2),
                                duration: 600.ms,
                                curve: Curves.easeInOut,
                              ),
                          SizedBox(width: 4),
                          Text(
                            '$overdueCount overdue',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFFDC2626),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
            if (isMacOSOrWeb &&
                overdueCount > 0 &&
                overdueTasksForCard.isNotEmpty) ...[
              SizedBox(height: 16),
              TaskReminderDigestCard(
                overdueCount: overdueCount,
                introText: 'Your attention is needed on a few tasks below.',
                tasks: overdueTasksForCard,
                onMarkDone: _markActionItemDone,
                onRemindAgain: _remindAgain,
                initialExpanded: false,
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Show a dialog to start a new meeting.
  /// Returns the Meet URL, or null if cancelled.
  Future<String?> _showStartMeetingDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Image.asset('assets/images/gmeet.png', width: 24, height: 24),
            const SizedBox(width: 10),
            const Text(
              'Start Google Meet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a new meeting or paste an existing link:',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            // Quick create button
            InkWell(
              mouseCursor: MaterialStateMouseCursor.clickable,
              onTap: () async {
                // Open meet.google.com/new in browser, user copies the link
                await qurioLaunchUrl('https://meet.google.com/new');
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.open_in_new_rounded,
                        size: 18, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Open Google Meet to create a link',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                          Text(
                            'Copy the meeting link and paste below',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Paste link field
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'https://meet.google.com/abc-defg-hij',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Color(0xFF3B82F6)),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                prefixIcon: Icon(Icons.link_rounded,
                    size: 20, color: Color(0xFF9CA3AF)),
              ),
              style: TextStyle(fontFamily: 'Inter', fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(ctx, url);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_rounded, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Start Meeting',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Announcement banner — shows the latest pinned announcement below the chat header.
  Widget _buildAnnouncementBanner(ChatsRecord chat) {
    Widget buildBanner(List<AnnouncementsRecord> items, {Object? error}) {
      if (error != null) {
        debugLog('❌ [AnnouncementBanner] Stream error: $error');
        return const SizedBox.shrink();
      }
      if (items.isEmpty) {
        return const SizedBox.shrink();
      }

      final ann = items.first;
      final isConfirmed = currentUserReference != null &&
          ann.confirmedBy.contains(currentUserReference);

      // Hide banner once the user has confirmed
      if (isConfirmed) return const SizedBox.shrink();

      final memberCount = chat.members.length;
      final confirmedCount = ann.confirmedBy.length;

      return GestureDetector(
        onTap: () => _selectGroupChatTab(GroupChatTab.announcements),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF3B82F6).withOpacity(0.08),
                const Color(0xFF3B82F6).withOpacity(0.04),
              ],
            ),
            border: const Border(
              bottom: BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.campaign_rounded,
                    color: Color(0xFF3B82F6), size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ann.content.length > 80
                          ? '${ann.content.substring(0, 80)}...'
                          : ann.content,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF1E40AF),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$confirmedCount/$memberCount confirmed',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: const Color(0xFF6B7280),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isConfirmed)
                InkWell(
                  mouseCursor: MaterialStateMouseCursor.clickable,
                  onTap: () async {
                    if (currentUserReference == null) return;
                    await fsArrayUnion(
                      ann.reference,
                      'confirmed_by',
                      [currentUserReference],
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          color: Color(0xFF10B981), size: 13),
                      SizedBox(width: 3),
                      Text(
                        'Confirmed',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right,
                  color: Color(0xFF9CA3AF), size: 18),
            ],
          ),
        ),
      ).withClickCursor().withClickCursor();
    }

    if (useWindowsFirestoreRest) {
      return _RestPollBuilder<List<AnnouncementsRecord>>(
        interval: const Duration(seconds: 15),
        fetch: () => fsQueryPinnedAnnouncements(chat.reference),
        builder: (context, snapshot) =>
            buildBanner(snapshot.data ?? [], error: snapshot.error),
      );
    }

    return StreamBuilder<List<AnnouncementsRecord>>(
      stream: queryAnnouncementsRecord(
        parent: chat.reference,
        queryBuilder: (q) => q.where('is_pinned', isEqualTo: true).limit(1),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return buildBanner([], error: snapshot.error);
        }
        return buildBanner(snapshot.data ?? []);
      },
    );
  }

  Widget _buildHeaderAvatar(ChatsRecord chat) {
    if (chat.isServiceChat) {
      return _buildLonaServiceAvatar(size: 40, chat: chat);
    }
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

      return DesktopSafeUserBuilder(
        userRef: otherUserRef,
        fetchOnce: _getOrCreateUserFuture,
        builder: (context, user) {
          String imageUrl = '';
          bool isOnline = false;

          // Check if this is Summer first, regardless of userSnapshot
          if (otherUserRef.path.contains('ai_agent_summerai')) {
            imageUrl =
                'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120';
          } else if (user != null) {
            imageUrl = user.photoUrl;
            isOnline = user.isOnline;
          }

          return InkWell(
            mouseCursor: MaterialStateMouseCursor.clickable,
            onTap: () {
              if (!otherUserRef.path.contains('ai_agent_summerai')) {
                showUserProfilePopup(
                  context,
                  user: user,
                  userRef: otherUserRef,
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
      final title = chat.title.isNotEmpty ? chat.title : 'Group Chat';
      final canRename = ChatHelpers.isGroupOwner(chat, currentUserReference);

      return Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF1F2937),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (canRename) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Edit group',
              child: InkWell(
                mouseCursor: MaterialStateMouseCursor.clickable,
                onTap: () => _showRenameGroupChatDialog(chat),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    } else {
      // For direct chats, get the other user's name
      final otherUserRef = chat.members.firstWhere(
        (member) => member != currentUserReference,
        orElse: () => chat.members.first,
      );

      // Use cached name when available
      final cachedName = chatController.getCachedDisplayName(otherUserRef.id);
      if (windowsChatListSkipUserFetch) {
        return Text(
          windowsChatDmListLabel(
            otherUserRef: otherUserRef,
            cachedName: cachedName,
          ),
          style: TextStyle(
            fontFamily: 'Inter',
            color: Color(0xFF1F2937),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }

      if (cachedName != null && cachedName.isNotEmpty) {
        return Text(
          cachedName,
          style: TextStyle(
            fontFamily: 'Inter',
            color: Color(0xFF1F2937),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }

      return FutureBuilder<UsersRecord>(
        future: _getOrCreateUserFuture(otherUserRef),
        builder: (context, userSnapshot) {
          String displayName;
          if (otherUserRef.path.contains('ai_agent_summerai')) {
            displayName = 'Summer';
          } else if (userSnapshot.hasError ||
              userSnapshot.connectionState == ConnectionState.waiting) {
            displayName =
                userSnapshot.hasError ? 'Unknown User' : 'Direct Chat';
          } else if (userSnapshot.hasData && userSnapshot.data != null) {
            final user = userSnapshot.data!;
            displayName =
                user.displayName.isNotEmpty ? user.displayName : 'Unknown User';
          } else {
            displayName = 'Unknown User';
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

  void _openChatSearchPanel() {
    setState(() {
      _model.showChatHistoryPanel = true;
      _model.showGroupCreation = false;
      _model.showGroupInfoPanel = false;
      _model.groupInfoChat = null;
      _model.showUserProfilePanel = false;
      _model.userProfileUser = null;
    });
  }

  Widget _buildChatSearchHeaderButton() {
    return Tooltip(
      message: 'Search in chat',
      child: InkWell(
        mouseCursor: MaterialStateMouseCursor.clickable,
        onTap: _openChatSearchPanel,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(0, 0, 12, 0),
          child: Icon(
            Icons.search_rounded,
            color: Color(0xFF6B7280),
            size: 22,
          ),
        ),
      ),
    );
  }

  List<DocumentReference> _sortGroupMembers(ChatsRecord chat) {
    final sortedMembers = List<DocumentReference>.from(chat.members);
    sortedMembers.sort((a, b) {
      if (a == chat.admin) return -1;
      if (b == chat.admin) return 1;
      if (a == chat.createdBy) return -1;
      if (b == chat.createdBy) return 1;
      return 0;
    });
    return sortedMembers;
  }

  Widget _buildGroupMembersHeaderButton(ChatsRecord chat) {
    final members = chat.members;
    final displayCount = members.length > 3 ? 3 : members.length;
    const double avatarSize = 24.0;
    const double spacing = 14.0;
    final double stackWidth =
        displayCount > 0 ? avatarSize + (displayCount - 1) * spacing : 0;
    final remaining = members.length - displayCount;

    return Tooltip(
      message: '${members.length} members',
      child: InkWell(
        mouseCursor: MaterialStateMouseCursor.clickable,
        onTap: () => _showGroupMembersDialog(chat),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(0, 0, 12, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (members.isEmpty)
                Icon(
                  Icons.people_outline_rounded,
                  size: 22,
                  color: Color(0xFF6B7280),
                )
              else ...[
                SizedBox(
                  width: stackWidth + (remaining > 0 ? 18 : 0),
                  height: avatarSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (int i = 0; i < displayCount; i++)
                        Positioned(
                          left: i * spacing,
                          child: _buildMemberAvatarChip(
                            members[i],
                            avatarSize,
                          ),
                        ),
                      if (remaining > 0)
                        Positioned(
                          left: displayCount * spacing,
                          child: Container(
                            width: avatarSize,
                            height: avatarSize,
                            decoration: BoxDecoration(
                              color: Color(0xFFE5E7EB),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '+$remaining',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberAvatarChip(
    DocumentReference userRef,
    double size,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: ClipOval(
        child: DesktopSafeUserBuilder(
          userRef: userRef,
          fetchOnce: _getOrCreateUserFuture,
          builder: (context, user) {
            final imageUrl = userRef.path.contains('ai_agent_summerai')
                ? 'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120'
                : (user?.photoUrl ?? '');

            return CachedNetworkImage(
              imageUrl: imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              memCacheWidth: (size * 2).round(),
              memCacheHeight: (size * 2).round(),
              placeholder: (context, url) => Container(
                color: Color(0xFFF3F4F6),
                child: Icon(
                  Icons.person,
                  color: Color(0xFF9CA3AF),
                  size: size * 0.55,
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Color(0xFFF3F4F6),
                child: Icon(
                  Icons.person,
                  color: Color(0xFF9CA3AF),
                  size: size * 0.55,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showGroupMembersDialog(ChatsRecord chat) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        var members = _sortGroupMembers(chat);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                width: 360,
                constraints:
                    const BoxConstraints(maxWidth: 360, maxHeight: 520),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Color(0xFFFAFBFC),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        border: Border(
                          bottom:
                              BorderSide(color: Color(0xFFE5E7EB), width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.people_rounded,
                              color: Color(0xFF3B82F6),
                              size: 18,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Group Members',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Color(0xFF111827),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${members.length} members',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Color(0xFF6B7280),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(Icons.close_rounded,
                                color: Color(0xFF9CA3AF), size: 20),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: members.length +
                            (ChatHelpers.isGroupAdmin(
                                    chat, currentUserReference)
                                ? 1
                                : 0),
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 68,
                          color: Color(0xFFF3F4F6),
                        ),
                        itemBuilder: (context, index) {
                          final canManageMembers = ChatHelpers.isGroupAdmin(
                              chat, currentUserReference);
                          if (canManageMembers && index == 0) {
                            return _buildAddMemberListRow(
                              onTap: () {
                                Navigator.pop(dialogContext);
                                _showAddMembersDialog(chat);
                              },
                            );
                          }
                          final memberIndex =
                              canManageMembers ? index - 1 : index;
                          final memberRef = members[memberIndex];
                          return _buildGroupMemberRow(
                            chat,
                            memberRef,
                            dialogContext,
                            onMemberRemoved: () {
                              setDialogState(() {
                                members = List<DocumentReference>.from(members)
                                  ..removeWhere(
                                      (ref) => ref.id == memberRef.id);
                              });
                            },
                          );
                        },
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
  }

  Future<void> _confirmAndRemoveGroupMember({
    required ChatsRecord chat,
    required UsersRecord user,
    required BuildContext dialogContext,
    required VoidCallback onMemberRemoved,
  }) async {
    final confirmed = await showDialog<bool>(
      context: dialogContext,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Remove member',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1F36),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Are you sure you want to remove ${user.displayName} from the group?',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: Text(
                      'Remove',
                      style: TextStyle(fontFamily: 'Inter'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final updatedMembers = List<DocumentReference>.from(chat.members)
        ..remove(user.reference);

      await fsPatchDocument(chat.reference, {
        'members': updatedMembers,
      });

      final actorName = currentUserDisplayName.isNotEmpty
          ? currentUserDisplayName
          : (currentUserDocument?.displayName ?? 'Someone');
      final systemMessage =
          '$actorName removed ${user.displayName} from the group';

      await fsCreateMessage(chat.reference, {
        'content': systemMessage,
        'created_at': getCurrentTimestamp,
        'sender_ref': currentUserReference,
        'sender_name': actorName,
        'sender_photo': currentUserPhoto.isNotEmpty
            ? currentUserPhoto
            : (currentUserDocument?.photoUrl ?? ''),
        'is_system_message': true,
        'is_read_by': [currentUserReference],
      });

      await fsPatchDocument(chat.reference, {
        'last_message': systemMessage,
        'last_message_at': getCurrentTimestamp,
        'last_message_sent': currentUserReference,
      });

      await chatController.refreshChats(force: true);
      onMemberRemoved();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.displayName} removed from group'),
            backgroundColor: Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove member'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Widget _buildGroupMemberRow(
    ChatsRecord chat,
    DocumentReference memberRef,
    BuildContext dialogContext, {
    VoidCallback? onMemberRemoved,
  }) {
    return DesktopSafeUserBuilder(
      userRef: memberRef,
      fetchOnce: _getOrCreateUserFuture,
      builder: (context, user) {
        if (user == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final isOwner = ChatHelpers.isGroupOwner(chat, memberRef);
        final isAdmin = ChatHelpers.isGroupAdmin(chat, memberRef);
        final isCurrentUser = memberRef == currentUserReference;
        final canRemove = ChatHelpers.canRemoveGroupMember(
          chat,
          currentUserReference,
          memberRef,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  mouseCursor: MaterialStateMouseCursor.clickable,
                  onTap: () {
                    Navigator.pop(dialogContext);
                    showUserProfilePopup(
                      context,
                      userRef: memberRef,
                      groupChat: chat,
                    );
                  },
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: CachedNetworkImage(
                          imageUrl: memberRef.path.contains('ai_agent_summerai')
                              ? 'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120'
                              : user.photoUrl,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 36,
                            height: 36,
                            color: Color(0xFFF3F4F6),
                            child: Icon(Icons.person,
                                color: Color(0xFF9CA3AF), size: 18),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 36,
                            height: 36,
                            color: Color(0xFFF3F4F6),
                            child: Icon(Icons.person,
                                color: Color(0xFF9CA3AF), size: 18),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.displayName.isNotEmpty
                                        ? user.displayName
                                        : 'Unknown User',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Color(0xFF111827),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isCurrentUser) ...[
                                  SizedBox(width: 6),
                                  Text(
                                    '(You)',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (isOwner || isAdmin)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  isOwner ? 'Owner' : 'Admin',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: isOwner
                                        ? Color(0xFFF59E0B)
                                        : Color(0xFF3B82F6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (canRemove)
                TextButton(
                  onPressed: () => _confirmAndRemoveGroupMember(
                    chat: chat,
                    user: user,
                    dialogContext: dialogContext,
                    onMemberRemoved: onMemberRemoved ?? () {},
                  ),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Remove',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFFEF4444),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Generate daily summary using Summer
  Future<void> _generateDailySummary(ChatsRecord chat) async {
    if (!chat.isGroup) return;

    setState(() {
      _model.isGeneratingSummary = true;
    });

    try {
      await invokeCloudFunction(
        'dailySummary',
        data: {'chatId': chat.reference.id},
        timeout: const Duration(seconds: 120),
      );

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
      debugLog('Error generating summary: $e');

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
      final user = await fsGetUserOnce(otherUserRef);
      if (context.mounted) {
        await showUserProfilePopup(context, user: user);
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

  void _toggleBlockUser(ChatsRecord chat) async {
    if (chat.isGroup) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot block group chats'),
          backgroundColor: Color(0xFF6B7280),
        ),
      );
      return;
    }

    final otherUserRef = chat.members.firstWhere(
      (member) => member != currentUserReference,
      orElse: () => chat.members.first,
    );

    final isBlocked =
        chatController.blockedUserIds.value.contains(otherUserRef.id);

    try {
      final user = await fsGetUserOnce(otherUserRef);

      if (isBlocked) {
        // Unblock Logic
        final shouldUnblock = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Color(0xFF2D3142),
              title: Text(
                'Unblock User',
                style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
              content: Text(
                'Are you sure you want to unblock ${user.displayName}? You will be able to see their messages again.',
                style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF9CA3AF),
                    fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel',
                      style: TextStyle(
                          fontFamily: 'Inter', color: Color(0xFF9CA3AF))),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Unblock',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );

        if (shouldUnblock == true) {
          await fsUnblockUser(
            blockerUser: currentUserReference!,
            blockedUser: otherUserRef,
          );
          final unblockedIds =
              Set<String>.from(chatController.blockedUserIds.value)
                ..remove(otherUserRef.id);
          chatController.blockedUserIds.value = unblockedIds;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('User has been unblocked'),
                backgroundColor: Color(0xFF10B981)),
          );
        }
      } else {
        // Block Logic
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
                    fontWeight: FontWeight.w600),
              ),
              content: Text(
                'Are you sure you want to block ${user.displayName}? You will no longer see their messages.',
                style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF9CA3AF),
                    fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel',
                      style: TextStyle(
                          fontFamily: 'Inter', color: Color(0xFF9CA3AF))),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Block',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );

        if (shouldBlock == true) {
          await fsBlockUser(
            blockerUser: currentUserReference!,
            blockedUser: otherUserRef,
          );
          chatController.blockedUserIds.value = {
            ...chatController.blockedUserIds.value,
            otherUserRef.id,
          };

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('User has been blocked'),
                backgroundColor: Color(0xFF10B981)),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error updating block status: $e'),
            backgroundColor: Color(0xFFEF4444)),
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

  void _showAddMembersDialog(ChatsRecord chat) {
    if (!chat.isGroup) return;
    if (!ChatHelpers.isGroupAdmin(chat, currentUserReference)) return;

    showAddGroupMembersDialog(
      context: context,
      chat: chat,
      onMembersAdded: () async {
        await chatController.refreshChats(force: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Members added successfully'),
              backgroundColor: Color(0xFF34C759),
            ),
          );
        }
      },
    );
  }

  void _navigateToAddMembers(ChatsRecord chat) {
    _showAddMembersDialog(chat);
  }

  Widget _buildAddMemberListRow({required VoidCallback onTap}) {
    return InkWell(
      mouseCursor: MaterialStateMouseCursor.clickable,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF9CA3AF),
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Add member',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF3B82F6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToMedia(ChatsRecord chat) {
    _selectGroupChatTab(GroupChatTab.filesAndLinks);
  }

  void _navigateToTasks(ChatsRecord chat) {
    _selectGroupChatTab(GroupChatTab.actionTasks);
  }

  void _handlePinChat(ChatsRecord chat) async {
    try {
      final userRef = currentUserReference;
      if (userRef == null) return;
      final isPinned = chat.isPinnedByUser(userRef);

      if (isPinned) {
        await fsArrayRemove(chat.reference, 'pinned_by', [userRef]);
      } else {
        await fsArrayUnion(chat.reference, 'pinned_by', [userRef]);
      }

      chatController.applyLocalChatPinState(
        chatRef: chat.reference,
        userRef: userRef,
        pinned: !isPinned,
      );
      await chatController.refreshChats(force: true);
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
        await fsDeleteDocument(chat.reference);
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

  Widget _buildSelectionBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Selected count
          Text(
            '${_selectedMessages.length} selected',
            style: TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1C1C1E),
            ),
          ),
          Spacer(),
          // Forward button
          TextButton.icon(
            onPressed: _selectedMessages.isEmpty
                ? null
                : () {
                    // Forward all selected messages to a chat
                    _forwardSelectedMessages();
                  },
            icon: Icon(CupertinoIcons.arrow_turn_up_right, size: 16),
            label: Text('Forward'),
            style: TextButton.styleFrom(
              foregroundColor: Color(0xFF007AFF),
              textStyle: TextStyle(
                fontFamily: 'SF Pro Text',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: 8),
          // Delete button
          TextButton.icon(
            onPressed: _selectedMessages.isEmpty
                ? null
                : () {
                    _deleteSelectedMessages();
                  },
            icon: Icon(CupertinoIcons.delete, size: 16),
            label: Text('Delete'),
            style: TextButton.styleFrom(
              foregroundColor: Color(0xFFFF3B30),
              textStyle: TextStyle(
                fontFamily: 'SF Pro Text',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: 8),
          // Cancel button
          TextButton(
            onPressed: _exitSelectionMode,
            child: Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Color(0xFF8E8E93),
              textStyle: TextStyle(
                fontFamily: 'SF Pro Text',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _forwardSelectedMessages() async {
    if (_selectedMessages.isEmpty) return;
    final messages = _selectedMessages.toList()
      ..sort((a, b) => (a.createdAt ?? DateTime.now())
          .compareTo(b.createdAt ?? DateTime.now()));

    // Step 1: Ask forward mode
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Forward ${messages.length} message${messages.length > 1 ? 's' : ''}',
          style: TextStyle(
            fontFamily: 'SF Pro Text',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Combined option
            _ForwardModeOption(
              icon: CupertinoIcons.archivebox,
              title: 'Forward as Combined',
              subtitle: 'Package all messages into one',
              onTap: () => Navigator.pop(ctx, 'combined'),
            ),
            SizedBox(height: 8),
            // Individual option
            _ForwardModeOption(
              icon: CupertinoIcons.list_bullet,
              title: 'Forward Individually',
              subtitle: 'Send each message separately',
              onTap: () => Navigator.pop(ctx, 'individual'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    fontFamily: 'SF Pro Text', color: Color(0xFF007AFF))),
          ),
        ],
      ),
    );

    if (mode == null) return;
    final isCombined = mode == 'combined';

    // Step 2: Show chat picker
    final chats = chatController.chats;
    final searchQuery = ValueNotifier<String>('');

    final selectedChat = await showDialog<ChatsRecord>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Select chat',
            style: TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          content: SizedBox(
            width: 360,
            height: 400,
            child: Column(
              children: [
                CupertinoTextField(
                  placeholder: 'Search chats...',
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onChanged: (value) => searchQuery.value = value,
                ),
                SizedBox(height: 12),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: searchQuery,
                    builder: (context, query, _) {
                      final filtered = chats.where((chat) {
                        if (query.isEmpty) return true;
                        return chat.title
                            .toLowerCase()
                            .contains(query.toLowerCase());
                      }).toList();

                      return ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final chat = filtered[index];
                          final displayName = chat.isGroup
                              ? (chat.title.isNotEmpty
                                  ? chat.title
                                  : 'Group Chat')
                              : (chatController.getCachedDisplayName(
                                    chat.members
                                        .firstWhere(
                                          (m) => m != currentUserReference,
                                          orElse: () => chat.members.first,
                                        )
                                        .id,
                                  ) ??
                                  'Chat');

                          return ListTile(
                            dense: true,
                            leading: Icon(
                              chat.isGroup ? Icons.group : Icons.person,
                              color: Color(0xFF007AFF),
                              size: 20,
                            ),
                            title: Text(
                              displayName,
                              style: TextStyle(
                                fontFamily: 'SF Pro Text',
                                fontSize: 15,
                                color: Color(0xFF1C1C1E),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            hoverColor: Color(0xFFF2F2F7),
                            onTap: () => Navigator.pop(dialogContext, chat),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  color: Color(0xFF007AFF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (selectedChat == null) return;

    // Step 3: Execute forward
    try {
      if (isCombined) {
        await _executeCombinedForward(selectedChat, messages);
      } else {
        for (final msg in messages) {
          await _executeForward(selectedChat, msg);
        }
      }
      _exitSelectionMode();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Forwarded ${messages.length} message${messages.length > 1 ? 's' : ''}'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to forward: $e'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _executeCombinedForward(
      ChatsRecord targetChat, List<MessagesRecord> messages) async {
    // Pre-fetch missing user data for display names
    final userCache = <DocumentReference, UsersRecord>{};
    for (final m in messages) {
      if (m.senderRef != null && !userCache.containsKey(m.senderRef)) {
        try {
          final doc = await fsGetUserOnce(m.senderRef!);
          userCache[m.senderRef!] = doc;
        } catch (_) {}
      }
    }

    // Serialize history
    final historyList = messages.map((m) {
      final user = m.senderRef != null ? userCache[m.senderRef!] : null;
      final senderName = (m.hasSenderName() && m.senderName.isNotEmpty)
          ? m.senderName
          : (user?.displayName ?? 'Unknown');
      final senderPhoto = (m.hasSenderPhoto() && m.senderPhoto.isNotEmpty)
          ? m.senderPhoto
          : (user?.photoUrl ?? '');

      return {
        'sender_name': senderName,
        'sender_photo': senderPhoto,
        'content': m.content,
        'message_type': m.messageType?.name ?? 'text',
        'image': m.image,
        'images': m.images,
        'video': m.video,
        'audio': m.audio,
        'audio_path': m.audioPath,
        'attachment_url': m.attachmentUrl,
        'created_at': m.createdAt?.millisecondsSinceEpoch,
      };
    }).toList();
    final historyJson = jsonEncode(historyList);

    final messageData = createMessagesRecordData(
      senderRef: currentUserReference,
      content: '[Chat History]',
      createdAt: getCurrentTimestamp,
      messageType: MessageType.text,
      isSystemMessage: false,
      isPinned: false,
      forwardedHistory: historyJson,
    );

    await fsCreateMessageAndUpdateChat(
      chatRef: targetChat.reference,
      messageData: messageData,
      chatUpdateData: {
        'last_message': '[Chat History]',
        'last_message_at': getCurrentTimestamp,
        'last_message_sent': currentUserReference,
        'last_message_type': MessageType.text.serialize(),
        'last_message_seen': [currentUserReference],
      },
    );
  }

  void _deleteSelectedMessages() async {
    if (_selectedMessages.isEmpty) return;
    final count = _selectedMessages.length;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete $count message${count > 1 ? 's' : ''}?',
            style: TextStyle(
                fontFamily: 'SF Pro Text',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E))),
        content: Text('This action cannot be undone.',
            style: TextStyle(
                fontFamily: 'SF Pro Text',
                fontSize: 14,
                color: Color(0xFF8E8E93))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(
                    fontFamily: 'SF Pro Text', color: Color(0xFF007AFF))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    color: Color(0xFFFF3B30),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      for (final msg in _selectedMessages) {
        try {
          await fsDeleteDocument(msg.reference);
        } catch (_) {}
      }
      _exitSelectionMode();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$count message${count > 1 ? 's' : ''} deleted'),
              backgroundColor: Color(0xFF10B981)),
        );
      }
    }
  }

  void _handleDesktopMessageAction(String action, MessagesRecord message) {
    switch (action) {
      case 'forward':
        _forwardMessageDesktop(message);
        break;
      case 'translate':
        _chatThreadKey.currentState?.triggerTranslate(message);
        break;
      case 'select':
        setState(() {
          _isSelectionMode = true;
          _selectedMessages.add(message);
        });
        break;
      case 'delete':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message hidden from your view'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  void _forwardMessageDesktop(MessagesRecord message) {
    final chats = chatController.chats;
    final searchQuery = ValueNotifier<String>('');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Forward To',
            style: TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          content: SizedBox(
            width: 360,
            height: 400,
            child: Column(
              children: [
                // Search box
                CupertinoTextField(
                  placeholder: 'Search chats...',
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onChanged: (value) => searchQuery.value = value,
                ),
                SizedBox(height: 12),
                // Chat list
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: searchQuery,
                    builder: (context, query, _) {
                      final filtered = chats.where((chat) {
                        if (query.isEmpty) return true;
                        final title = chat.title.toLowerCase();
                        return title.contains(query.toLowerCase());
                      }).toList();

                      return ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final chat = filtered[index];
                          final displayName = chat.isGroup
                              ? (chat.title.isNotEmpty
                                  ? chat.title
                                  : 'Group Chat')
                              : (chatController.getCachedDisplayName(
                                    chat.members
                                        .firstWhere(
                                          (m) => m != currentUserReference,
                                          orElse: () => chat.members.first,
                                        )
                                        .id,
                                  ) ??
                                  'Chat');

                          return ListTile(
                            dense: true,
                            leading: Icon(
                              chat.isGroup ? Icons.group : Icons.person,
                              color: Color(0xFF007AFF),
                              size: 20,
                            ),
                            title: Text(
                              displayName,
                              style: TextStyle(
                                fontFamily: 'SF Pro Text',
                                fontSize: 15,
                                color: Color(0xFF1C1C1E),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            hoverColor: Color(0xFFF2F2F7),
                            onTap: () async {
                              Navigator.pop(dialogContext);
                              await _executeForward(chat, message);
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  color: Color(0xFF007AFF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeForward(
      ChatsRecord targetChat, MessagesRecord message) async {
    try {
      final forwardData = createMessagesRecordData(
        senderRef: currentUserReference,
        content: message.content,
        createdAt: getCurrentTimestamp,
        messageType: message.messageType,
        image: message.image,
        video: message.video,
        audio: message.audio,
        attachmentUrl: message.attachmentUrl,
        senderName: currentUserDisplayName,
        senderPhoto: currentUserPhoto,
      );

      final previewText = message.content.length > 100
          ? message.content.substring(0, 100)
          : message.content;

      await fsCreateMessageAndUpdateChat(
        chatRef: targetChat.reference,
        messageData: forwardData,
        chatUpdateData: {
          'last_message': previewText,
          'last_message_at': getCurrentTimestamp,
          'last_message_sent': currentUserReference,
          'last_message_type': message.messageType?.serialize() ?? 'M',
          'last_message_seen': [currentUserReference],
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message forwarded'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to forward: $e'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
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
  final Function(ChatsRecord) onMarkUnread;
  final Function(Offset, ChatsRecord)? onMoveToFolder;
  final Function(ChatsRecord)? onRename;
  final Future<UsersRecord> Function(DocumentReference) getOrCreateUserFuture;
  final bool showPinIcon;

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
    required this.onMarkUnread,
    this.onMoveToFolder,
    this.onRename,
    required this.getOrCreateUserFuture,
    this.showPinIcon = true,
  }) : super(key: key);

  @override
  _ChatListItemState createState() => _ChatListItemState();
}

class _ChatListItemState extends State<_ChatListItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<int>? _unreadCountFuture;

  @override
  void initState() {
    super.initState();
    _ensureUnreadCountFuture();
  }

  @override
  void didUpdateWidget(covariant _ChatListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final chatChanged = oldWidget.chat.reference.id != widget.chat.reference.id;
    final becameUnread =
        !oldWidget.hasUnreadMessages && widget.hasUnreadMessages;
    if (chatChanged || becameUnread) {
      _unreadCountFuture = null;
      _ensureUnreadCountFuture();
    }
  }

  void _ensureUnreadCountFuture() {
    if (!useWindowsFirestoreRest) return;
    _unreadCountFuture ??= _fetchUnreadCount(widget.chat).then((count) {
      widget.chatController.cacheUnreadCount(widget.chat.reference.id, count);
      return count;
    });
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'pin',
          child: Row(
            children: [
              Icon(
                widget.chat.isPinnedByUser(currentUserReference)
                    ? Icons.push_pin_outlined
                    : Icons.push_pin,
                color: Color(0xFF374151),
                size: 18,
              ),
              SizedBox(width: 12),
              Text(
                widget.chat.isPinnedByUser(currentUserReference)
                    ? 'Unpin'
                    : 'Pin',
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
          value: 'mark_unread',
          child: Row(
            children: [
              Icon(
                widget.hasUnreadMessages
                    ? Icons.mark_chat_read_outlined
                    : Icons.mark_chat_unread_outlined,
                color: Color(0xFF3B82F6),
                size: 18,
              ),
              SizedBox(width: 12),
              Text(
                widget.hasUnreadMessages ? 'Mark as Read' : 'Mark as Unread',
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
        if (widget.onMoveToFolder != null)
          PopupMenuItem<String>(
            value: 'move_to_folder',
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  color: Color(0xFF374151),
                  size: 18,
                ),
                SizedBox(width: 12),
                Text(
                  'Move to Folder',
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
        if (widget.chat.isGroup &&
            widget.onRename != null &&
            ChatHelpers.isGroupOwner(widget.chat, currentUserReference))
          PopupMenuItem<String>(
            value: 'rename',
            child: Row(
              children: [
                Icon(
                  Icons.edit_outlined,
                  color: Color(0xFF374151),
                  size: 18,
                ),
                SizedBox(width: 12),
                Text(
                  'Edit Group',
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
      ],
    ).then((value) {
      if (value == 'pin') {
        widget.onPin(widget.chat);
      } else if (value == 'delete') {
        widget.onDelete(widget.chat);
      } else if (value == 'mute') {
        widget.onMute(widget.chat);
      } else if (value == 'mark_unread') {
        if (widget.hasUnreadMessages) {
          widget.chatController.markMessagesAsSeen(widget.chat);
        } else {
          widget.onMarkUnread(widget.chat);
        }
      } else if (value == 'move_to_folder') {
        widget.onMoveToFolder?.call(position, widget.chat);
      } else if (value == 'rename') {
        widget.onRename?.call(widget.chat);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return GestureDetector(
      onSecondaryTapDown: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      child: InkWell(
        mouseCursor: MaterialStateMouseCursor.clickable,
        onTap: widget.onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isSelected)
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                    decoration: BoxDecoration(
                      color:
                          widget.isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: widget.isSelected
                          ? Border.all(
                              color: Color.fromRGBO(230, 235, 245, 1),
                              width: 1,
                            )
                          : Border(
                              bottom: BorderSide(
                                color: Color.fromRGBO(230, 235, 245, 1),
                                width: 1,
                              ),
                            ),
                      boxShadow: widget.isSelected
                          ? [
                              BoxShadow(
                                color: Color.fromRGBO(0, 0, 0, 0.05),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                                spreadRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildChatAvatar(widget.chat),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (widget.showPinIcon &&
                                        widget.chat.isPinnedByUser(
                                            currentUserReference)) ...[
                                      const Icon(
                                        Icons.push_pin,
                                        color: Color(0xFF000000),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Expanded(
                                      child: _getChatDisplayName(widget.chat,
                                          isSelected: widget.isSelected),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                _getLastMessagePreview(widget.chat,
                                    isSelected: widget.isSelected),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 70,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildMessageTimestamp(),
                                if (widget.hasUnreadMessages) ...[
                                  const SizedBox(height: 6),
                                  _buildUnreadCountBadge(),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).withClickCursor().withClickCursor();
  }

  Widget _buildChatAvatar(ChatsRecord chat) {
    if (chat.isServiceChat) {
      return _buildLonaServiceAvatar(size: 30, chat: chat);
    }
    if (chat.isGroup) {
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Color(0xFFE5E7EB), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: chat.chatImageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: chat.chatImageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                memCacheWidth: 72,
                memCacheHeight: 72,
                maxWidthDiskCache: 72,
                maxHeightDiskCache: 72,
                filterQuality: FilterQuality.high,
                placeholder: (context, url) => Center(
                  child: Icon(
                    Icons.group,
                    color: Color(0xFF6B7280),
                    size: 18,
                  ),
                ),
                errorWidget: (context, url, error) => Center(
                  child: Icon(
                    Icons.group,
                    color: Color(0xFF6B7280),
                    size: 18,
                  ),
                ),
              )
            : Center(
                child: Icon(
                  Icons.group,
                  color: Color(0xFF6B7280),
                  size: 18,
                ),
              ),
      );
    } else {
      // For direct chats, get the other user's profile picture
      final otherUserRef = chat.members.firstWhere(
        (member) => member != currentUserReference,
        orElse: () => chat.members.first,
      );

      return DesktopSafeUserBuilder(
        userRef: otherUserRef,
        fetchOnce: widget.getOrCreateUserFuture,
        builder: (context, user) {
          String imageUrl = '';
          bool isOnline = false;

          // Check if this is Summer first, regardless of userSnapshot
          if (otherUserRef.path.contains('ai_agent_summerai')) {
            imageUrl =
                'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120';
          } else if (user != null) {
            imageUrl = user.photoUrl;
            isOnline = user.isOnline;
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Color(0xFFE5E7EB), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 30,
                    height: 30,
                    fit: BoxFit.cover,
                    memCacheWidth: 72,
                    memCacheHeight: 72,
                    maxWidthDiskCache: 72,
                    maxHeightDiskCache: 72,
                    filterQuality: FilterQuality.high,
                    placeholder: (context, url) => Container(
                      width: 30,
                      height: 30,
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
                    errorWidget: (context, url, error) => Container(
                      width: 30,
                      height: 30,
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
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(0xFF10B981), // Green color
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
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
          color: Color(0xFF111827),
          fontSize: 13,
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

      // Use cached name when available to avoid "Direct Chat" flash on rebuilds
      final cachedName =
          widget.chatController.getCachedDisplayName(otherUserRef.id);

      if (windowsChatListSkipUserFetch) {
        return Text(
          windowsChatDmListLabel(
            otherUserRef: otherUserRef,
            cachedName: cachedName,
          ),
          style: TextStyle(
            fontFamily: 'Inter',
            color: Color(0xFF111827),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }

      if (cachedName != null && cachedName.isNotEmpty) {
        return Text(
          cachedName,
          style: TextStyle(
            fontFamily: 'Inter',
            color: Color(0xFF111827),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }

      // Stable future so FutureBuilder doesn't reset on every parent rebuild
      return FutureBuilder<UsersRecord>(
        future: widget.getOrCreateUserFuture(otherUserRef),
        builder: (context, userSnapshot) {
          String displayName;
          if (otherUserRef.path.contains('ai_agent_summerai')) {
            displayName = 'Summer';
          } else if (userSnapshot.hasError ||
              userSnapshot.connectionState == ConnectionState.waiting) {
            displayName =
                userSnapshot.hasError ? 'Unknown User' : 'Direct Chat';
          } else if (userSnapshot.hasData && userSnapshot.data != null) {
            final user = userSnapshot.data!;
            displayName =
                user.displayName.isNotEmpty ? user.displayName : 'Unknown User';
          } else {
            displayName = 'Unknown User';
          }

          return Text(
            displayName,
            style: TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFF111827),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      );
    }
  }

  Widget _buildMessageTimestamp() {
    final timestampText = widget.chat.lastMessageAt != null
        ? () {
            final now = DateTime.now();
            final messageTime = widget.chat.lastMessageAt!.toLocal();
            final difference = now.difference(messageTime);

            if (difference.inHours < 24) {
              return DateFormat('h:mm a').format(messageTime);
            }
            // Omit year when the message is from the current year.
            if (messageTime.year == now.year) {
              return DateFormat('MM/dd').format(messageTime);
            }
            return DateFormat('MM/dd/yyyy').format(messageTime);
          }()
        : 'Unknown';

    return Text(
      timestampText,
      style: TextStyle(
        fontFamily: 'Inter',
        color: widget.isSelected ? Color(0xFF6B7280) : Color(0xFF9CA3AF),
        fontSize: 11,
      ),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
    );
  }

  Widget _buildUnreadCountBadge() {
    Widget badge(int count) {
      const badgeHeight = 16.0;
      final display = count > 99 ? '99+' : '$count';
      final badgeWidth =
          display.length > 2 ? 26.0 : (display.length > 1 ? 20.0 : badgeHeight);

      return Container(
        width: badgeWidth,
        height: badgeHeight,
        decoration: BoxDecoration(
          color: Color(0xFF3B82F6),
          borderRadius: BorderRadius.circular(badgeHeight / 2),
          boxShadow: [
            BoxShadow(
              color: Color(0x4D3B82F6),
              blurRadius: 3,
              spreadRadius: 0.5,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          display,
          style: TextStyle(
            fontFamily: 'Inter',
            color: Colors.white,
            fontSize: display.length > 2 ? 7 : 9,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
          textAlign: TextAlign.center,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
        ),
      );
    }

    if (useWindowsFirestoreRest) {
      return FutureBuilder<int>(
        future: _unreadCountFuture,
        initialData: widget.chatController
            .getCachedUnreadCount(widget.chat.reference.id),
        builder: (context, snapshot) {
          final count = snapshot.data;
          if (count == null || count <= 0) {
            return const SizedBox.shrink();
          }
          return badge(count);
        },
      );
    }

    return StreamBuilder<int>(
      stream: widget.chatController.getUnreadMessageCount(widget.chat),
      initialData:
          widget.chatController.getCachedUnreadCount(widget.chat.reference.id),
      builder: (context, snapshot) {
        final count = snapshot.data;
        if (count == null || count <= 0) {
          return const SizedBox.shrink();
        }
        return badge(count);
      },
    );
  }

  Future<int> _fetchUnreadCount(ChatsRecord chat) async {
    if (currentUserReference == null) return 0;

    try {
      final messages = await fsQueryChatMessages(chat.reference, limit: 500);
      int count = 0;

      for (final message in messages) {
        final isUnread = message.senderRef != currentUserReference &&
            !message.isSystemMessage &&
            !message.isReadBy.contains(currentUserReference);

        if (isUnread) {
          count++;
        } else if (message.senderRef == currentUserReference ||
            message.isReadBy.contains(currentUserReference)) {
          break;
        }
      }

      return count;
    } catch (_) {
      return widget.chatController.getCachedUnreadCount(chat.reference.id) ?? 0;
    }
  }

  Widget _getLastMessagePreview(ChatsRecord chat, {bool isSelected = false}) {
    String _groupSenderPrefix() {
      if (chat.lastMessageSent == null) return '';
      if (chat.lastMessageSent == currentUserReference) return 'You: ';
      if (DesktopSafeUserBuilder.useOnceFetch) {
        final cached = widget.chatController
            .getCachedDisplayName(chat.lastMessageSent!.id);
        if (cached != null && cached.isNotEmpty) {
          return '${cached.split(' ').first}: ';
        }
        return '';
      }
      return '';
    }

    Widget _richPreview(String prefix, String text) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: prefix,
              style: TextStyle(
                fontFamily: 'Inter',
                color: isSelected ? Color(0xFF6B7280) : Color(0xFF374151),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: text,
              style: TextStyle(
                fontFamily: 'Inter',
                color: isSelected ? Color(0xFF9CA3AF) : Color(0xFF6B7280),
                fontSize: 11,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // If lastMessage is empty, check lastMessageType to show appropriate preview
    if (chat.lastMessage.isEmpty) {
      // Check if there's a message type (video, image, etc.)
      if (chat.lastMessageType != null) {
        String previewText = 'No messages';
        switch (chat.lastMessageType) {
          case MessageType.video:
            previewText = '🎬 Video';
            break;
          case MessageType.image:
            previewText = '📷 Photo';
            break;
          case MessageType.voice:
            previewText = '🎤 Voice message';
            break;
          case MessageType.file:
            previewText = '📎 File';
            break;
          case MessageType.text:
          default:
            previewText = 'No messages';
            break;
        }

        // For group chats, we might want to show sender name too
        if (chat.isGroup && chat.lastMessageSent != null) {
          if (DesktopSafeUserBuilder.useOnceFetch) {
            return _richPreview(_groupSenderPrefix(), previewText);
          }
          return DesktopSafeUserBuilder(
            userRef: chat.lastMessageSent!,
            fetchOnce: widget.getOrCreateUserFuture,
            builder: (context, sender) {
              String prefix = '';
              if (sender != null) {
                final senderName = sender.displayName;
                final firstName = senderName.split(' ').first;
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
                        color:
                            isSelected ? Color(0xFF6B7280) : Color(0xFF374151),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: previewText,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color:
                            isSelected ? Color(0xFF9CA3AF) : Color(0xFF6B7280),
                        fontSize: 11,
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

        return Text(
          previewText,
          style: TextStyle(
            fontFamily: 'Inter',
            color: isSelected ? Color(0xFF9CA3AF) : Color(0xFF6B7280),
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }

      // No message type, show default
      return Text(
        'No messages',
        style: TextStyle(
          fontFamily: 'Inter',
          color: isSelected ? Color(0xFF9CA3AF) : Color(0xFF6B7280),
          fontSize: 11,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // For group chats, show sender name
    if (chat.isGroup && chat.lastMessageSent != null) {
      final body = chat.lastMessage.replaceAllMapped(
        RegExp(r'<@[^|]+\|([^>]+)>'),
        (m) => '@${m.group(1)}',
      );
      if (DesktopSafeUserBuilder.useOnceFetch) {
        return _richPreview(_groupSenderPrefix(), body);
      }
      return DesktopSafeUserBuilder(
        userRef: chat.lastMessageSent!,
        fetchOnce: widget.getOrCreateUserFuture,
        builder: (context, sender) {
          String prefix = '';
          if (sender != null) {
            final senderName = sender.displayName;
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
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: chat.lastMessage.replaceAllMapped(
                    RegExp(r'<@[^|]+\|([^>]+)>'),
                    (m) => '@${m.group(1)}',
                  ),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: isSelected ? Color(0xFF9CA3AF) : Color(0xFF6B7280),
                    fontSize: 11,
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
      chat.lastMessage.replaceAllMapped(
        RegExp(r'<@[^|]+\|([^>]+)>'),
        (m) => '@${m.group(1)}',
      ),
      style: TextStyle(
        fontFamily: 'Inter',
        color: isSelected ? Color(0xFF9CA3AF) : Color(0xFF6B7280),
        fontSize: 11,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ForwardModeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ForwardModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: MaterialStateMouseCursor.clickable,
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: Color(0xFF007AFF)),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 12,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Color(0xFFC7C7CC), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Delays subscribing to a Firestore stream on Windows/Linux to reduce
/// concurrent native channel traffic when opening a chat thread.
class _DeferredFirestoreStream<T> extends StatefulWidget {
  const _DeferredFirestoreStream({
    required this.delay,
    required this.stream,
    required this.builder,
    this.placeholder = const SizedBox.shrink(),
  });

  final Duration delay;
  final Stream<T> stream;
  final Widget placeholder;
  final Widget Function(BuildContext context, AsyncSnapshot<T> snapshot)
      builder;

  @override
  State<_DeferredFirestoreStream<T>> createState() =>
      _DeferredFirestoreStreamState<T>();
}

class _DeferredFirestoreStreamState<T>
    extends State<_DeferredFirestoreStream<T>> {
  Stream<T>? _activeStream;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _activeStream = widget.stream);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_activeStream == null) return widget.placeholder;
    return StreamBuilder<T>(
      stream: _activeStream,
      builder: widget.builder,
    );
  }
}

/// Periodic REST fetch for Windows/Linux — same UI as StreamBuilder, no native plugin.
class _RestPollBuilder<T> extends StatefulWidget {
  const _RestPollBuilder({
    required this.interval,
    required this.fetch,
    required this.builder,
  });

  final Duration interval;
  final Future<T> Function() fetch;
  final Widget Function(BuildContext context, AsyncSnapshot<T> snapshot)
      builder;

  @override
  State<_RestPollBuilder<T>> createState() => _RestPollBuilderState<T>();
}

class _RestPollBuilderState<T> extends State<_RestPollBuilder<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(widget.interval, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await widget.fetch();
      if (mounted) {
        setState(() {
          _data = result;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _loading && _data == null
          ? AsyncSnapshot<T>.waiting()
          : _error != null
              ? AsyncSnapshot<T>.withError(
                  ConnectionState.done, _error!, StackTrace.current)
              : AsyncSnapshot<T>.withData(ConnectionState.done, _data as T),
    );
  }
}
