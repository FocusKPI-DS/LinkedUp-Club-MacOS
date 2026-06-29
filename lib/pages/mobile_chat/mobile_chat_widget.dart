import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import 'dart:convert';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/nav/nav.dart' as nav;
import '/pages/chat/chat_component/chat_thread_component/chat_thread_component_widget.dart';
import '/pages/mobile_chat/mobile_chat_model.dart';
import '/pages/mobile_chat/mobile_new_chat_widget.dart';
import '/pages/mobile_chat/mobile_new_group_chat_widget.dart';
import '/pages/desktop_chat/chat_controller.dart';
import '/utils/chat_helpers.dart';
import '/pages/user_summary/user_summary_widget.dart';
import '/pages/chat/group_chat_detail/group_chat_detail_widget.dart';
import '/pages/chat/group_chat_detail/mobile_group_media_widget.dart';
import '/pages/chat/group_chat_detail/mobile_group_tasks_widget.dart';
import '/pages/chat/add_group_members/add_group_members_widget.dart';
import '/pages/chat/chat_history/chat_history_widget.dart';
import '/pages/mobile_chat/mobile_pinned_messages_widget.dart';
import '/pages/mobile_chat/mobile_group_files_widget.dart';
import '/pages/chat/chat_component/group_announcements_widget.dart';
import '/component/meeting_banner/meeting_banner_widget.dart';
import '/components/chat_filter_buttons.dart';
import '/custom_code/actions/index.dart' as actions;
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_debounce/easy_debounce.dart';
import '/pages/chat/chat_component/forward_chat_picker_dialog.dart';
// import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart'; // Removed unused import
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '/utils/markdown_to_quill_delta.dart';

class MobileChatWidget extends StatefulWidget {
  const MobileChatWidget({
    Key? key,
    this.onChatStateChanged,
    this.initialChat,
  }) : super(key: key);

  static String routeName = 'MobileChat';
  static String routePath = '/mobile-chat';

  final Function(bool isChatOpen)? onChatStateChanged;
  final ChatsRecord? initialChat;

  @override
  _MobileChatWidgetState createState() => _MobileChatWidgetState();
}

class _MobileChatWidgetState extends State<MobileChatWidget>
    with TickerProviderStateMixin {
  OverlayEntry? _menuOverlayEntry;
  Offset? _lastMenuAnchor;
  RelativeRect? _currentMenuPosition;
  int _lastMenuUpdateTime = 0; // Throttle timestamp to reduce lag
  String?
      _highlightedMessageId; // Track highlighted message to prevent redundant rebuilds
  List<AdaptivePopupMenuItem<String>>? _currentMenuItems;
  Function(int index, AdaptivePopupMenuItem<String> item)? _currentOnSelected;
  ChatThreadComponentWidgetState? _activeChatThreadComponent;
  final ValueNotifier<String?> _activeSelectionId = ValueNotifier<String?>(null);

  // Multi-message selection state
  bool _isSelectionMode = false;
  final Set<MessagesRecord> _selectedMessages = {};

  // Chat folders state
  List<ChatFoldersRecord> _chatFolders = [];
  StreamSubscription? _chatFoldersSubscription;
  bool _isPinnedCollapsed = false;
  bool _isGroupsCollapsed = false;
  bool _isDMCollapsed = false;
  bool _isInactiveCollapsed = true; // Inactive chats hidden by default
  bool _isFolderMode = false; // Toggle between Chats (flat list) and Folders (grouped) mode
  final GlobalKey<_FullScreenChatPageState> _fullScreenChatPageKey = GlobalKey<_FullScreenChatPageState>();

  void _toggleMessageSelection(MessagesRecord message) {
    setState(() {
      if (_selectedMessages.map((m) => m.reference.id).contains(message.reference.id)) {
        _selectedMessages.removeWhere((m) => m.reference.id == message.reference.id);
        if (_selectedMessages.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessages.add(message);
      }
    });
  }

  void _hideMenuOverlay({bool clearSelection = true}) {
    if (_menuOverlayEntry == null) {
      if (clearSelection) {
        _activeSelectionId.value = null;
        if (_activeChatThreadComponent != null) {
          _activeChatThreadComponent!.safeSetState(() {
            _activeChatThreadComponent!.clearHighlight();
          });
          _activeChatThreadComponent = null;
        } else {
          final chatThreadComponent = _model.chatThreadComponentKey.currentState;
          if (chatThreadComponent != null) {
            chatThreadComponent.safeSetState(() {
              chatThreadComponent.clearHighlight();
            });
          }
        }
      }
      return; // Performance optimization: Don't trigger resets if no menu is active
    }
    _menuOverlayEntry?.remove();
    _menuOverlayEntry = null;
    _lastMenuAnchor = null;
    _currentMenuPosition = null;
    _currentMenuItems = null;
    _currentOnSelected = null;
    
    if (clearSelection) {
      _highlightedMessageId = null; // Reset highlight tracking
      _activeSelectionId.value = null; // Targeted reset for all messages

      // Clear highlight when menu is dismissed from the CORRECT component
      if (_activeChatThreadComponent != null) {
        _activeChatThreadComponent!.safeSetState(() {
          _activeChatThreadComponent!.clearHighlight();
        });
        _activeChatThreadComponent = null;
      } else {
        // Fallback for main view if no explicit active component tracked
        final chatThreadComponent = _model.chatThreadComponentKey.currentState;
        if (chatThreadComponent != null) {
          chatThreadComponent.safeSetState(() {
            chatThreadComponent.clearHighlight();
          });
        }
      }
    }
  }

  void _onMessageLongPress(
    MessagesRecord message,
    Offset? offset,
    ChatThreadComponentWidgetState? componentState, {
    bool clearSelection = true,
  }) {
    // If componentState is provided (from the component itself), use it.
    // Otherwise fallback to global key (for initial main view access)
    final activeComponent = componentState ?? _model.chatThreadComponentKey.currentState;

    if (activeComponent == null && offset != null) {
      // No component state available (e.g. in full-screen chat view with media long press)
      // Still show the menu — just skip highlight management
      if (_isSelectionMode) {
        _toggleMessageSelection(message);
        return;
      }
      _showMessageMenu(message, offset);
      return;
    }

    if (activeComponent == null) return;

    if (offset == null) {
      // Hide menu when selection is cleared or during temporary drag
      _hideMenuOverlay(clearSelection: clearSelection);

      if (clearSelection) {
        // Explicitly clear highlight from the active component if overlay hiding didn't catch it
        activeComponent.safeSetState(() {
          activeComponent.clearHighlight();
        });
      }
      return;
    }

    if (_isSelectionMode) {
      _toggleMessageSelection(message);
      return;
    }

    // Track which component is currently being interacted with for later cleanup
    _activeChatThreadComponent = activeComponent;

    // Performance fix: Only call setState if the highlighted message actually changes
    if (_highlightedMessageId != message.reference.id) {
      activeComponent.safeSetState(() {
        activeComponent.setHighlightedMessage(message.reference.id);
      });
      _highlightedMessageId = message.reference.id;
    }

    _showMessageMenu(message, offset);
  }

  late MobileChatModel _model;
  late ChatController chatController;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final animationsMap = <String, AnimationInfo>{};
  double? _dragStartX;

  final Map<String, Future<UsersRecord>> _userDocFutureCache = {};
  Future<UsersRecord> _getOrCreateUserFuture(DocumentReference ref) =>
      _userDocFutureCache.putIfAbsent(
          ref.id, () => UsersRecord.getDocumentOnce(ref));

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MobileChatModel());
    // Use Get.put with permanent: true to keep controller persistent across navigation
    // This preserves knownUnreadChats and locallySeenChats state
    chatController = Get.put(ChatController(), permanent: true);

    _model.tabController = TabController(
      vsync: this,
      length: 3, // All, Direct Message, and Groups
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

    // Subscribe to chat folders from Firestore
    _subscribeToChatFolders();

    // Handle initial chat if provided - open it in full-screen
    if (widget.initialChat != null) {
      // Use postFrameCallback to push the full-screen route after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.initialChat != null) {
          chatController.selectChat(widget.initialChat!);
          _openChatFullScreen(widget.initialChat!);
        }
      });
    }

    // On page load action - ensure FCM token is saved for push notifications
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      unawaited(
        () async {
          await actions.closekeyboard();
        }(),
      );
      unawaited(
        () async {
          await actions.dismissKeyboard(
            context,
          );
        }(),
      );
      if (loggedIn && currentUserReference != null) {
        unawaited(
          () async {
            await actions.ensureFcmToken(
              currentUserReference!,
            );
          }(),
        );
      }
      unawaited(
        () async {
          await actions.updateAppBadge();
        }(),
      );
    });
  }

  @override
  void dispose() {
    _hideMenuOverlay(); // Ensure menu is removed when page is closed
    _chatFoldersSubscription?.cancel();
    _model.dispose();
    super.dispose();
  }

  void _subscribeToChatFolders() {
    if (currentUserReference == null) return;
    _chatFoldersSubscription?.cancel();
    _chatFoldersSubscription = queryChatFoldersRecord(
      parent: currentUserReference,
      queryBuilder: (q) => q.orderBy('order'),
    ).listen((folders) {
      if (mounted) {
        setState(() => _chatFolders = folders);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Always show chat list - chat detail is shown in full-screen route
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        // Absorb all scroll notifications to prevent tab bar from minimizing/blurring
        return true;
      },
      child: Container(
        color: Colors
            .white, // White background for entire page including status bar area
        child: AdaptiveScaffold(
          appBar: null, // No app bar - using custom header instead
          body: SafeArea(
            bottom: false,
            child: Listener(
              onPointerDown: (event) {
                // If menu is open and touch is NOT on the menu itself, hide it.
                // We use Listener.onPointerDown because it's non-blocking (doesn't interfere with selection handles).
                if (_menuOverlayEntry != null && _currentMenuPosition != null) {
                  // Basic hit detection for the menu itself can be added here if needed,
                  // but usually just clicking anywhere else is desired.
                  _hideMenuOverlay();
                }
              },
              child: Container(
                color:
                    Colors.white, // Changed to white for consistent background
                child: RepaintBoundary(
                  child: Column(
                    children: [
                      // Fixed header section with Chats title, action buttons, search bar, and filters
                      Container(
                        color: Colors
                            .white, // Changed to white for consistent background
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Chats heading + mode toggle icons in top left
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Row(
                                children: [
                                  Text(
                                    'Chats',
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      color: CupertinoColors.label,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  // Chat mode toggle (bubble icon)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _isFolderMode = false);
                                    },
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: !_isFolderMode
                                            ? Color(0xFF3B82F6)
                                            : Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.chat_bubble_outline,
                                        size: 16,
                                        color: !_isFolderMode
                                            ? Colors.white
                                            : Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  // Folder mode toggle (folder icon)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _isFolderMode = true);
                                    },
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: _isFolderMode
                                            ? Color(0xFF3B82F6)
                                            : Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.folder_outlined,
                                        size: 16,
                                        color: _isFolderMode
                                            ? Colors.white
                                            : Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Header action buttons
                            Positioned(
                              top: 20,
                              right: 16,
                              child: _buildHeaderActionButtons(),
                            ),
                            // Always visible search bar
                            Positioned(
                              top: 70,
                              left: 0,
                              right: 0,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.0),
                                child: _buildAlwaysVisibleSearchBar(),
                              ),
                            ),
                            // Filter buttons below search bar
                            Positioned(
                              top: 118,
                              left: 0,
                              right: 0,
                              child: const ChatFilterButtons(),
                            ),
                          ],
                        ),
                        height: 180, // Total height for header section
                      ),
                      // Scrollable chat list
                      Expanded(
                        child: _buildChatList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatView() {
    return GestureDetector(
      onHorizontalDragStart: (details) {
        // Track drag start position for iOS swipe-to-go-back
        if (Platform.isIOS) {
          _dragStartX = details.globalPosition.dx;
        }
      },
      onHorizontalDragUpdate: (details) {
        // Only allow swipe if it started from the left edge (within 20px)
        if (Platform.isIOS && _dragStartX != null) {
          if (_dragStartX! > 20) {
            // Reset if drag didn't start from left edge
            _dragStartX = null;
          }
        }
      },
      onHorizontalDragEnd: (details) {
        // Enable swipe-to-go-back on iOS only
        if (Platform.isIOS && _dragStartX != null && _dragStartX! <= 20) {
          // Check if swipe was from left to right (positive velocity)
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 200) {
            // Navigate back
            setState(() {
              _model.selectedChat = null;
            });
            // Notify parent that chat is closed
            widget.onChatStateChanged?.call(false);
          }
        }
        _dragStartX = null;
      },
      child: ChatThreadComponentWidget(
        key: _model.chatThreadComponentKey,
        chatReference: _model.selectedChat,
        onMessageLongPress: (message, anchor, componentState,
            {bool clearSelection = true}) {
          if (clearSelection) {
            _activeSelectionId.value = message.reference.id;
          }
          _onMessageLongPress(message, anchor, componentState,
              clearSelection: clearSelection);
        },
        onMessageAction: handleMessageAction,
        activeSelectionId: _activeSelectionId,
        isSelectionMode: _isSelectionMode,
        selectedMessages: _selectedMessages,
        onMessageToggled: _toggleMessageSelection,
      ),
    );
  }

  /// Opens a chat in a full-screen modal route (like WhatsApp)
  /// This covers the tab bar completely without needing parent state changes
  void _openChatFullScreen(ChatsRecord chat) {
    // Defer state update to avoid blocking navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _model.selectedChat = chat;
        });
      }
    });

    // Push route immediately without waiting for state update
    Navigator.of(context, rootNavigator: true)
        .push(
      CupertinoPageRoute(
        fullscreenDialog: false,
        builder: (context) => _FullScreenChatPage(
          key: _fullScreenChatPageKey,
          chat: chat,
          onMessageLongPress: (message, anchor, componentState,
              {bool clearSelection = true}) {
            if (clearSelection) {
              _activeSelectionId.value = message.reference.id;
            }
            _onMessageLongPress(message, anchor, componentState,
                clearSelection: clearSelection);
          },
          onHideMenu: _hideMenuOverlay,
          activeSelectionId: _activeSelectionId,
          onMessageAction: handleMessageAction,
          isSelectionMode: _isSelectionMode,
          selectedMessages: _selectedMessages,
          onMessageToggled: _toggleMessageSelection,
          onExitSelectionMode: () {
            if (mounted) {
              setState(() {
                _isSelectionMode = false;
                _selectedMessages.clear();
              });
            }
          },
          shouldPopTwice:
              widget.initialChat != null, // Pop twice if opened from New Chat
          onPop: () {
            // Clear selected chat when route is popped so the same chat can be opened again
            if (mounted) {
              setState(() {
                _model.selectedChat = null;
                _isSelectionMode = false;
                _selectedMessages.clear();
              });
            }
          },
        ),
      ),
    )
        .then((_) {
      // Also clear when route completes (handles swipe back on iOS)
      if (mounted) {
        setState(() {
          _model.selectedChat = null;
          _isSelectionMode = false;
          _selectedMessages.clear();
        });
      }
    });
  }

  PreferredSizeWidget _buildChatAppBar() {
    final chat = _model.selectedChat!;

    return PreferredSize(
      preferredSize: Size.fromHeight(
          MediaQuery.of(context).padding.top + 10), // Increased header height
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFFF2F2F7), // Match chat screen background exactly
        ),
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 44, // Native iOS toolbar height
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                // Floating back button on the left - iOS 26+ style with liquid glass effects
                LiquidStretch(
                  stretch: 0.5,
                  interactionScale: 1.05,
                  child: GlassGlow(
                    glowColor: Colors.white24,
                    glowRadius: 1.0,
                    child: AdaptiveFloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.white, // Pure white background
                      foregroundColor: Color(0xFF007AFF), // System blue icon
                      onPressed: () {
                        // If we came from another page (like Connections), pop to go back
                        // Otherwise, just close the chat to show the chat list
                        if (widget.initialChat != null &&
                            Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          setState(() {
                            _model.selectedChat = null;
                          });
                          widget.onChatStateChanged?.call(false);
                        }
                      },
                      child: Icon(
                        CupertinoIcons.chevron_left,
                        size: 17,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // Centered title in pill shape - native iOS 26 style
                Expanded(
                  child: Center(
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white, // Pure white like back button
                        borderRadius: BorderRadius.circular(16), // Pill shape
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Avatar to the left of group name
                          SizedBox(
                            width: 34,
                            height: 34,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              clipBehavior: Clip.antiAlias,
                              child: _buildHeaderAvatar(chat),
                            ),
                          ),
                          SizedBox(width: 8),
                          // Group name or user name text
                          Flexible(
                            child: chat.isGroup
                                ? Text(
                                    _getChatDisplayName(chat),
                                    style: TextStyle(
                                      fontFamily: 'System',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF000000), // Black
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : _buildDirectChatHeaderName(chat),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // Settings button on the right - iOS 26+ style with liquid glass effects
                LiquidStretch(
                  stretch: 0.5,
                  interactionScale: 1.05,
                  child: GlassGlow(
                    glowColor: Colors.white24,
                    glowRadius: 1.0,
                    child: AdaptiveFloatingActionButton(
                      mini: true,
                      backgroundColor:
                          Colors.white, // Pure white like back button
                      foregroundColor: Color(0xFF007AFF), // System blue icon
                      onPressed: () => _showChatOptions(chat),
                      child: Icon(
                        CupertinoIcons.ellipsis,
                        size: 17,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getChatDisplayName(ChatsRecord chat) {
    if (chat.isGroup) {
      return chat.title.isNotEmpty ? chat.title : 'Group Chat';
    } else {
      // For direct chats, try to get name from searchNames if available
      // Otherwise return a placeholder that will be updated via FutureBuilder
      if (chat.searchNames.isNotEmpty) {
        // Find the name that's not the current user's name
        final currentUserName = currentUserDisplayName.toLowerCase();
        final otherName = chat.searchNames.firstWhere(
          (name) => name.toLowerCase() != currentUserName,
          orElse: () =>
              chat.searchNames.isNotEmpty ? chat.searchNames.first : '',
        );
        if (otherName.isNotEmpty) {
          return otherName;
        }
      }

      // Check if it's Summer AI agent
      final otherUserRef = chat.members.firstWhere(
        (member) => member != currentUserReference,
        orElse: () => chat.members.first,
      );
      if (otherUserRef.path.contains('ai_agent_summerai')) {
        return 'Summer';
      }

      // Fallback - will be updated when user data loads
      return 'Chat';
    }
  }

  /// Header title for open DM: uses cache + stable future so we don't show "Chat" / "Direct Chat" on rebuilds.
  Widget _buildDirectChatHeaderName(ChatsRecord chat) {
    final otherUserRef = chat.members.firstWhere(
      (member) => member != currentUserReference,
      orElse: () => chat.members.first,
    );
    final cachedName = chatController.getCachedDisplayName(otherUserRef.id);
    if (cachedName != null && cachedName.isNotEmpty) {
      return Text(
        cachedName,
        style: TextStyle(
          fontFamily: 'System',
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: Color(0xFF000000),
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
          displayName = userSnapshot.hasError ? 'Unknown User' : 'Direct Chat';
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
            fontFamily: 'System',
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: Color(0xFF000000),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  Widget _buildChatList() {
    return Column(
      children: [
        // Chat list with smooth transitions
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              // Prevent bottom navigation bar from hiding on scroll
              return false;
            },
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: _buildChatListContent(),
            ),
          ),
        ),
      ],
    );
  }


  void _showMessageMenu(MessagesRecord message, [Offset? offset]) {
    // Trigger highlight for this message
    final chatThreadComponent = _model.chatThreadComponentKey.currentState;
    if (chatThreadComponent != null) {
      chatThreadComponent.safeSetState(() {
        chatThreadComponent.setHighlightedMessage(message.reference.id);
      });
    }

    // Build menu items — matching contextMenuBuilder in MessageContentWidget
    final isOwnMessage = message.senderRef == currentUserReference;
    final menuItems = <Map<String, dynamic>>[
      {'label': 'Copy', 'icon': CupertinoIcons.doc_on_doc, 'value': 'copy'},
      {'label': 'Select', 'icon': CupertinoIcons.checkmark_circle, 'value': 'select'},
      {'label': 'React', 'icon': CupertinoIcons.smiley, 'value': 'react'},
      {'label': 'Reply', 'icon': CupertinoIcons.arrow_turn_up_left, 'value': 'reply'},
      {'label': 'Translate', 'icon': CupertinoIcons.book, 'value': 'translate'},
      {'label': 'Forward', 'icon': CupertinoIcons.arrow_turn_up_right, 'value': 'forward'},
      {'label': 'Delete', 'icon': CupertinoIcons.delete, 'value': 'delete'},
      if (isOwnMessage) {'label': 'Edit', 'icon': CupertinoIcons.pencil, 'value': 'edit'},
      if (isOwnMessage) {'label': 'Unsend', 'icon': CupertinoIcons.arrow_counterclockwise, 'value': 'unsend'},
      {'label': 'Download', 'icon': CupertinoIcons.arrow_down_circle, 'value': 'download'},
      {'label': 'Pin', 'icon': CupertinoIcons.pin, 'value': 'pin'},
      {'label': 'Report', 'icon': CupertinoIcons.exclamationmark_triangle, 'value': 'report'},
    ];

    // Dismiss any existing overlay AND any active text selection (prevents double-open)
    _hideMenuOverlay();
    // This clears any active text selection, which also dismisses the contextMenuBuilder toolbar
    primaryFocus?.unfocus();

    // Layout constants — identical to contextMenuBuilder in MessageContentWidget
    final int itemsPerRow = 5;
    final double itemSize = 48.0;
    final double horizontalPadding = 6.0;
    final double verticalPadding = 6.0;
    final int actualItemsInWidestRow = menuItems.length < itemsPerRow ? menuItems.length : itemsPerRow;
    final double menuWidth = (itemSize * actualItemsInWidestRow) + (horizontalPadding * 2) + 2.0;
    final int rowCount = (menuItems.length / itemsPerRow).ceil();
    final double menuHeight = (itemSize * rowCount) + (verticalPadding * 2) + (rowCount > 1 ? (rowCount - 1) * 4 : 0);

    // Calculate position near the long-press point
    final screenSize = MediaQuery.of(context).size;
    double left = (offset?.dx ?? screenSize.width / 2) - menuWidth / 2;
    double top = (offset?.dy ?? screenSize.height * 0.4) - menuHeight - 15;
    if (left < 10) left = 10;
    if (left + menuWidth > screenSize.width - 10) left = screenSize.width - menuWidth - 10;
    if (top < 60) top = (offset?.dy ?? screenSize.height * 0.4) + 30;
    if (top + menuHeight > screenSize.height - 60) top = screenSize.height - menuHeight - 60;

    _menuOverlayEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          // Full-screen transparent tap catcher — uses onTapDown via Listener
          // which does NOT create a TapGestureRecognizer (no gesture arena competition)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (_) {
                _hideMenuOverlay();
              },
            ),
          ),
          // The toolbar
          Positioned(
            left: left,
            top: top,
            child: Material(
              color: Colors.transparent,
              elevation: 4,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: menuWidth,
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.04),
                    width: 0.5,
                  ),
                ),
                child: Wrap(
                  spacing: 0,
                  runSpacing: 4,
                  alignment: WrapAlignment.start,
                  children: menuItems.map((item) {
                    final String value = item['value'] as String;
                    final String label = item['label'] as String;
                    final IconData icon = item['icon'] as IconData;
                    final isDestructive = value == 'report' || value == 'unsend' || value == 'delete';

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _hideMenuOverlay();
                        // Defer action to next frame so widget tree settles after overlay removal
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            handleMessageAction(value, message);
                          }
                        });
                      },
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: 16,
                              color: isDestructive ? const Color(0xFFFF3B30) : const Color(0xFF1C1C1E),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'SF Pro Text',
                                fontSize: 8.5,
                                color: isDestructive
                                    ? const Color(0xFFFF3B30)
                                    : const Color(0xFF1C1C1E).withOpacity(0.8),
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.2,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
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

    Overlay.of(context).insert(_menuOverlayEntry!);
  }

  void handleMessageAction(String action, MessagesRecord message) {
    print('✅ handleMessageAction triggered: $action for message ${message.reference.id}');
    switch (action) {
      case 'copy':
        // For text selection, 'copy' is handled natively by the SelectionArea.
        // We only call _copyMessage if we want to copy the whole bubble.
        _copyMessage(message);
        break;
      case 'react':
        _showEmojiMenu(message);
        break;
      case 'reply':
        _replyToMessage(message);
        break;
      case 'translate':
        _model.chatThreadComponentKey.currentState?.triggerTranslate(message);
        break;
      case 'select':
        setState(() {
          _isSelectionMode = true;
          _selectedMessages.add(message);
        });
        // Directly trigger selection on the _FullScreenChatPageState
        _fullScreenChatPageKey.currentState?.triggerSelect(message);
        break;
      case 'edit':
        _editMessage(message);
        break;
      case 'unsend':
        _unsendMessage(message);
        break;
      case 'download':
        _downloadImage(message);
        break;
      case 'report':
        _reportMessage(message);
        break;
      case 'forward':
        _forwardMessage(message);
        break;
      case 'pin':
        _togglePinMessage(message);
        break;
      case 'delete':
        // Local-only delete: hide message from current user's view only
        // Others can still see it in their chat
        _deleteMessageLocally(message);
        break;
    }
  }

  void _showFloatingPopupMenu({
    required BuildContext context,
    required List<AdaptivePopupMenuItem<String>> items,
    required Function(int index, AdaptivePopupMenuItem<String> item) onSelected,
    Offset? offset,
  }) {
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final screenSize = MediaQuery.of(context).size;

    // Accurate size calculations matching _IOS26PopupMenu
    final int itemsPerRow = 5;
    final double itemSize = 48.0;
    final double horizontalPadding = 8.0;
    final double verticalPadding = 10.0;

    final int actualItemsInWidestRow =
        items.length < itemsPerRow ? items.length : itemsPerRow;
    final double menuWidth =
        (itemSize * actualItemsInWidestRow) + (horizontalPadding * 2) + 2.0;
    final int rowCount = (items.length / itemsPerRow).ceil();
    final double menuHeight = (itemSize * rowCount) +
        (verticalPadding * 2) +
        (rowCount > 1 ? (rowCount - 1) * 4 : 0);

    RelativeRect position;
    if (offset != null) {
      // Position menu near the touch point
      double left = offset.dx - menuWidth / 2;
      double top =
          offset.dy - menuHeight - 15; // Appear slightly above the touch point

      // Boundary checks
      if (left < 10) left = 10;
      if (left + menuWidth > screenSize.width - 10) {
        left = screenSize.width - menuWidth - 10;
      }
      if (top < 60) {
        top = offset.dy + 30; // Appear below if not enough space above
      }
      if (top + menuHeight > screenSize.height - 60) {
        top = screenSize.height - menuHeight - 60;
      }

      position = RelativeRect.fromLTRB(
        left,
        top,
        screenSize.width - left - menuWidth,
        screenSize.height - top - menuHeight,
      );
    } else {
      // Fallback to center
      position = RelativeRect.fromLTRB(
        screenSize.width / 2 - menuWidth / 2,
        screenSize.height * 0.4 - menuHeight / 2,
        screenSize.width / 2 - menuWidth / 2,
        screenSize.height * 0.4 - menuHeight / 2,
      );
    }

    // Aggressive throttling to completely eliminate lag (卡卡的):
    // 1. Move distance check (minimum 10px instead of 5px for better stability)
    // 2. Time interval check (maximum 20 FPS update for the floating bar to save GPU)
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_menuOverlayEntry != null &&
        _lastMenuAnchor != null &&
        offset != null) {
      final distanceMoved = (offset - _lastMenuAnchor!).distance;
      final timeSinceUpdate = now - _lastMenuUpdateTime;

      // If we've already shown the menu recently and the user hasn't moved much, ignore.
      // This prevents the "vibrating" or "flickering" effect during slight finger tremor.
      if (distanceMoved < 10.0 && timeSinceUpdate < 50) {
        return;
      }
    }

    _lastMenuUpdateTime = now;
    _lastMenuAnchor = offset;
    _currentMenuPosition = position;
    // Cache items if they are effectively the same to prevent Wrap/Grid rebuilds
    _currentMenuItems = items;
    _currentOnSelected = onSelected;

    if (_menuOverlayEntry != null) {
      // Update existing overlay instead of removing/re-inserting to prevent flickering
      _menuOverlayEntry!.markNeedsBuild();
      return;
    }

    _menuOverlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Semi-transparent background to catch taps outside the menu
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideMenuOverlay,
              behavior: HitTestBehavior.translucent,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          _IOS26PopupMenu<String>(
            position: _currentMenuPosition!,
            items: _currentMenuItems!,
            onDismiss: _hideMenuOverlay,
            onSelected: (index, item) => _currentOnSelected?.call(index, item),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_menuOverlayEntry!);
  }

  Widget _buildIOS26ActionSheet(List<CupertinoActionSheetAction> actions) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
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
              // Actions - extract and render properly
              ...actions.map((action) => _buildIOS26ActionButton(action)),
              SizedBox(height: 8),
              // Cancel button
              _buildIOS26CancelButton(),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String label,
    required bool isDestructive,
  }) {
    final color =
        isDestructive ? CupertinoColors.destructiveRed : CupertinoColors.label;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 20,
          color: color,
        ),
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 17,
            color: color,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildIOS26ActionButton(CupertinoActionSheetAction action) {
    final isDestructive = action.isDestructiveAction;
    final textColor =
        isDestructive ? CupertinoColors.destructiveRed : CupertinoColors.label;

    return CupertinoButton(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: action.onPressed,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        child: DefaultTextStyle(
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 17,
            color: textColor,
            fontWeight: FontWeight.w400,
          ),
          child: action.child,
        ),
      ),
    );
  }

  Widget _buildIOS26CancelButton() {
    return CupertinoButton(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: () => Navigator.pop(context),
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        child: Text(
          'Cancel',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.activeBlue,
          ),
        ),
      ),
    );
  }

  String _getFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        String fileName = segments.last;
        // Remove Firebase storage tokens and parameters
        if (fileName.contains('?')) {
          fileName = fileName.split('?').first;
        }
        // Decode URL encoding
        fileName = Uri.decodeComponent(fileName);
        if (fileName.isNotEmpty) {
          return fileName;
        }
      }
    } catch (e) {
      // Fallback filename
    }
    // Generate filename based on timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'image_$timestamp.jpg';
  }

  void _showDownloadSuccessPopup() {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 80,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Downloaded',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Remove after 2 seconds
    Future.delayed(const Duration(milliseconds: 2000), () {
      overlayEntry.remove();
    });
  }

  Future<void> _downloadImage(MessagesRecord message) async {
    try {
      // Try single image first
      final imageUrl = message.image ?? '';
      final imageUrls = message.images ?? [];

      if (imageUrl.isNotEmpty) {
        await _downloadSingleImage(imageUrl);
      } else if (imageUrls.isNotEmpty) {
        // Download all images
        for (final imgUrl in imageUrls) {
          if (imgUrl.isNotEmpty) {
            await _downloadSingleImage(imgUrl);
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No images found in this message'),
              backgroundColor: Color(0xFFFF3B30),
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('Error downloading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading image: $e'),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  Future<void> _downloadSingleImage(String imageUrl) async {
    if (imageUrl.isEmpty) return;

    try {
      // Request permissions
      if (Platform.isAndroid) {
        final photosStatus = await Permission.photos.status;
        if (photosStatus.isDenied) {
          final permission = await Permission.photos.request();
          if (permission.isDenied || permission.isPermanentlyDenied) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Permission denied. Cannot download image.'),
                  backgroundColor: Color(0xFFFF3B30),
                ),
              );
            }
            return;
          }
        }
        // Also check storage permission for older Android versions
        final storageStatus = await Permission.storage.status;
        if (storageStatus.isDenied) {
          final permission = await Permission.storage.request();
          if (permission.isDenied || permission.isPermanentlyDenied) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Permission denied. Cannot download image.'),
                  backgroundColor: Color(0xFFFF3B30),
                ),
              );
            }
            return;
          }
        }
      } else if (Platform.isIOS) {
        final photosStatus = await Permission.photos.status;
        if (!photosStatus.isGranted && !photosStatus.isLimited) {
          final permission = await Permission.photos.request();
          if (permission.isDenied || permission.isPermanentlyDenied) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Permission denied. Cannot download image.'),
                  backgroundColor: Color(0xFFFF3B30),
                ),
              );
            }
            return;
          }
        }
      }

      // Download the image
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      // Get file name
      String safeFileName = _getFileNameFromUrl(imageUrl);
      safeFileName = safeFileName.replaceAll('/', '_').replaceAll('\\', '_');
      safeFileName = safeFileName.split('/').last.split('\\').last;

      // Remove extension if present, we'll let the saver handle it
      if (safeFileName.contains('.')) {
        safeFileName = safeFileName.split('.').first;
      }

      // If no filename, generate one
      if (safeFileName.isEmpty) {
        safeFileName = 'image_${DateTime.now().millisecondsSinceEpoch}';
      }

      // Save to gallery using image_gallery_saver_plus
      final result = await ImageGallerySaverPlus.saveImage(
        response.bodyBytes,
        quality: 100,
        name: safeFileName,
        isReturnImagePathOfIOS: false,
      );

      if (result['isSuccess'] == true) {
        if (mounted) {
          _showDownloadSuccessPopup();
        }
      } else {
        final errorMsg = result['errorMessage'] ?? result.toString();
        debugPrint('Save failed: $errorMsg');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save image: $errorMsg'),
              backgroundColor: Color(0xFFFF3B30),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error downloading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading image: $e'),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  Future<void> _copyMessage(MessagesRecord message) async {
    final rawText = message.content.trim();
    if (rawText.isEmpty) return;

    // Strip mention markup so clipboard gets @DisplayName, not raw <@uid|DisplayName>
    await Clipboard.setData(ClipboardData(text: stripMarkdownFormatting(rawText)));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.45,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Add Reaction',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: isDark ? Colors.white38 : Colors.black26,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            // Emoji Picker - Full featured
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                    bottom: 20.0,
                    left:
                        8.0), // Add bottom padding to move buttons up, left padding for search button
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    Navigator.pop(context, emoji.emoji);
                  },
                  config: Config(
                    height: MediaQuery.of(context).size.height * 0.35,
                    checkPlatformCompatibility: true,
                    emojiViewConfig: EmojiViewConfig(
                      emojiSizeMax: 28,
                      verticalSpacing: 0,
                      horizontalSpacing: 0,
                      gridPadding: EdgeInsets.zero,
                      recentsLimit: 28,
                      replaceEmojiOnLimitExceed: true,
                      noRecents: Text(
                        'No Recents',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      loadingIndicator: const Center(
                        child: CupertinoActivityIndicator(),
                      ),
                      buttonMode: ButtonMode.CUPERTINO,
                      backgroundColor:
                          isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    ),
                    skinToneConfig: const SkinToneConfig(
                      enabled: true,
                      dialogBackgroundColor: Colors.white,
                      indicatorColor: Colors.grey,
                    ),
                    categoryViewConfig: CategoryViewConfig(
                      initCategory: Category.RECENT,
                      backgroundColor:
                          isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      indicatorColor: CupertinoColors.activeBlue,
                      iconColor: isDark ? Colors.white54 : Colors.black45,
                      iconColorSelected: CupertinoColors.activeBlue,
                      categoryIcons: const CategoryIcons(
                        recentIcon: CupertinoIcons.clock,
                        smileyIcon: CupertinoIcons.smiley,
                        animalIcon: CupertinoIcons.tortoise,
                        foodIcon: CupertinoIcons.cart,
                        activityIcon: CupertinoIcons.sportscourt,
                        travelIcon: CupertinoIcons.car,
                        objectIcon: CupertinoIcons.lightbulb,
                        symbolIcon: CupertinoIcons.heart,
                        flagIcon: CupertinoIcons.flag,
                      ),
                    ),
                    bottomActionBarConfig: BottomActionBarConfig(
                      backgroundColor:
                          isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      buttonColor: isDark ? Colors.white54 : Colors.black45,
                      buttonIconColor: isDark ? Colors.white : Colors.black87,
                      showBackspaceButton: false,
                      showSearchViewButton: true,
                    ),
                    searchViewConfig: SearchViewConfig(
                      backgroundColor: isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFF2F2F7),
                      buttonIconColor: isDark ? Colors.white54 : Colors.black54,
                      hintText: 'Search emoji...',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null && selected.isNotEmpty) {
      await _saveReaction(message, selected);
    }
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
              fontWeight: FontWeight.normal,
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
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldReport == true) {
      // Here you would implement the actual reporting logic
      // Message reported - no snackbar needed
    }
  }

  Future<void> _togglePinMessage(MessagesRecord message) async {
    try {
      final isPinned = message.isPinned;
      await message.reference.update({
        'is_pinned': !isPinned,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPinned ? 'Message unpinned' : 'Message pinned'),
            duration: Duration(milliseconds: 2000),
            backgroundColor: isPinned ? Color(0xFF1D1D1F) : Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating pin status: $e'),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  Future<void> _replyToMessage(MessagesRecord message) async {
    // Show reply input area with the message being replied to
    _showReplyInput(message);
  }

  void _showReplyInput(MessagesRecord message) {
    final TextEditingController replyController = TextEditingController();

    // Create a reply input overlay
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
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
              // Reply preview
              Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(
                      color: Color(0xFF007AFF),
                      width: 4.0,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Replying to ${message.senderName}',
                      style: TextStyle(
                        fontFamily: 'System',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      stripMarkdownFormatting(message.content),
                      style: TextStyle(
                        fontFamily: 'System',
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Message input
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: replyController,
                  decoration: InputDecoration(
                    hintText: 'Type your reply...',
                    hintStyle: TextStyle(
                      fontFamily: 'System',
                      color: Color(0xFF8E8E93),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF007AFF)),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 4,
                  minLines: 1,
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty) {
                      _sendReplyMessage(message, text.trim());
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
              SizedBox(height: 16),
              // Send button
              Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton(
                  onPressed: () {
                    print('🔘 Send Reply button pressed');
                    print('📝 Reply text: "${replyController.text}"');
                    if (replyController.text.trim().isNotEmpty) {
                      print('✅ Sending reply...');
                      _sendReplyMessage(message, replyController.text.trim());
                      Navigator.pop(context);
                    } else {
                      print('❌ Reply text is empty');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Send Reply',
                    style: TextStyle(
                      fontFamily: 'System',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendReplyMessage(
      MessagesRecord originalMessage, String replyText) async {
    try {
      print(
          '🔄 Sending reply: "$replyText" to message: "${originalMessage.content}"');

      // Validate required values before proceeding
      final selectedChat = _model.selectedChat;
      final userRef = currentUserReference;

      if (selectedChat == null) {
        print('❌ Error: selectedChat is null');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to send reply: chat not selected'),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
        return;
      }

      if (userRef == null) {
        print('❌ Error: currentUserReference is null');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to send reply: user not logged in'),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
        return;
      }

      // Create the reply message
      final messageRef = MessagesRecord.createDoc(selectedChat.reference);
      await messageRef.set({
        'content': replyText,
        'sender_ref': userRef,
        'sender_name': currentUserDisplayName,
        'sender_photo': currentUserPhoto,
        'created_at': getCurrentTimestamp,
        'message_type': MessageType.text.serialize(),
        'reply_to': originalMessage.reference.id,
        'reply_to_content': originalMessage.content,
        'reply_to_sender': originalMessage.senderName,
        'is_read_by': [userRef], // Sender has read their own message
      });

      print('✅ Reply message created successfully');

      // Update chat's last message
      await selectedChat.reference.update({
        'last_message': replyText,
        'last_message_at': getCurrentTimestamp,
        'last_message_sent': userRef,
        'last_message_type': MessageType.text.serialize(),
      });
      print('✅ Chat metadata updated');
    } catch (e) {
      print('❌ Error sending reply: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send reply: $e'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
    }
  }

  Future<void> _editMessage(MessagesRecord message) async {
    // Check if the message was sent by the current user
    if (message.senderRef != currentUserReference) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You can only edit your own messages',
            style: TextStyle(
              fontFamily: 'System',
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          duration: Duration(milliseconds: 2000),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
      return;
    }

    // Show edit input area
    _showEditInput(message);
  }

  void _showEditInput(MessagesRecord message) {
    // Strip mention markup for display, but keep original content for re-injection
    final originalContent = message.content;
    final mentionPattern = RegExp(r'<@([^|]+)\|([^>]+)>');
    final displayContent = originalContent.replaceAllMapped(
      mentionPattern,
      (m) => '@${m.group(2)}',
    );
    // Parse existing mentions
    final existingMentions = <Map<String, String>>[];
    for (final match in mentionPattern.allMatches(originalContent)) {
      existingMentions.add({
        'uid': match.group(1)!,
        'displayName': match.group(2)!,
      });
    }
    final TextEditingController editController =
        TextEditingController(text: displayContent);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
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
              // Edit header
              Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Edit Message',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
              ),
              SizedBox(height: 16),
              // Message input
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: editController,
                  decoration: InputDecoration(
                    hintText: 'Edit your message...',
                    hintStyle: TextStyle(
                      fontFamily: 'System',
                      color: Color(0xFF8E8E93),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF007AFF)),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 4,
                  minLines: 1,
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty) {
                      _updateMessage(message, text.trim(), existingMentions);
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
              SizedBox(height: 16),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(left: 16, right: 8),
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Color(0xFFE5E7EB)),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'System',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(left: 8, right: 16),
                      child: ElevatedButton(
                        onPressed: () {
                          if (editController.text.trim().isNotEmpty) {
                            _updateMessage(message, editController.text.trim(), existingMentions);
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Save',
                          style: TextStyle(
                            fontFamily: 'System',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _forwardMessage(MessagesRecord message) async {
    final selectedChat = await showDialog<ChatsRecord>(
      context: context,
      builder: (context) => const ForwardChatPickerDialog(),
    );

    if (selectedChat != null && currentUserReference != null) {
      try {
        // Build forward data as a raw map to include all fields
        // (createMessagesRecordData doesn't support images list, file_name, etc.)
        final Map<String, dynamic> firestoreData = {
          'sender_ref': currentUserReference,
          'content': message.content,
          'created_at': getCurrentTimestamp,
          'message_type': message.messageType?.serialize(),
          'sender_name': currentUserDisplayName,
          'sender_photo': currentUserPhoto,
          'is_pinned': false,
          'is_system_message': false,
        };

        // Copy media fields if present
        if (message.image.isNotEmpty) {
          firestoreData['image'] = message.image;
        }
        if (message.images.isNotEmpty) {
          firestoreData['images'] = message.images;
        }
        if (message.video.isNotEmpty) {
          firestoreData['video'] = message.video;
        }
        if (message.audio.isNotEmpty) {
          firestoreData['audio'] = message.audio;
        }
        if (message.audioPath.isNotEmpty) {
          firestoreData['audio_path'] = message.audioPath;
        }
        if (message.attachmentUrl.isNotEmpty) {
          firestoreData['attachment_url'] = message.attachmentUrl;
        }
        // Copy file_name if present (used by file message rendering)
        final fileName = message.snapshotData['file_name'];
        if (fileName is String && fileName.isNotEmpty) {
          firestoreData['file_name'] = fileName;
        }
        // Copy message_format if present (e.g. 'markdown')
        final messageFormat = message.snapshotData['message_format'];
        if (messageFormat is String && messageFormat.isNotEmpty) {
          firestoreData['message_format'] = messageFormat;
        }

        await MessagesRecord.createDoc(selectedChat.reference).set(firestoreData);

        // Update chat's last_message fields for preview
        String previewText = message.content;
        if (previewText.isEmpty) {
          if (message.messageType == MessageType.image) previewText = '📷 Photo';
          else if (message.messageType == MessageType.video) previewText = '🎥 Video';
          else if (message.messageType == MessageType.file) previewText = '📎 File';
          else if (message.messageType == MessageType.voice) previewText = '🎵 Audio';
          else previewText = 'Message';
        }
        await selectedChat.reference.update({
          'last_message': previewText.length > 100 ? previewText.substring(0, 100) : previewText,
          'last_message_at': getCurrentTimestamp,
          'last_message_sent': currentUserReference,
          'last_message_type': message.messageType?.serialize() ?? MessageType.text.serialize(),
          'last_message_seen': [currentUserReference],
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Forwarded to ${selectedChat.title}'),
              backgroundColor: const Color(0xFF34C759),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error forwarding message: $e'),
              backgroundColor: const Color(0xFFFF3B30),
            ),
          );
        }
      }
    }
  }

  Future<void> _updateMessage(MessagesRecord message, String newContent, [List<Map<String, String>>? mentions]) async {
    try {
      // Re-inject mention markup if we have mentions
      var processedContent = newContent;
      if (mentions != null && mentions.isNotEmpty) {
        // Process longest names first to avoid partial matches
        final sorted = List<Map<String, String>>.from(mentions)
          ..sort((a, b) => b['displayName']!.length.compareTo(a['displayName']!.length));
        for (final m in sorted) {
          processedContent = processedContent.replaceFirst(
            '@${m['displayName']}',
            '<@${m['uid']}|${m['displayName']}>',
          );
        }
      }
      // Update the message content
      await message.reference.update({
        'content': processedContent,
        'edited_at': getCurrentTimestamp,
        'is_edited': true,
      });

      // Update chat's last message if this was the last message
      if (_model.selectedChat != null) {
        final chatDoc = await _model.selectedChat!.reference.get();
        if (chatDoc.exists) {
          final chatData = chatDoc.data() as Map<String, dynamic>;
          final lastMessageSent =
              chatData['last_message_sent'] as DocumentReference?;
          final chatLastMessage = chatData['last_message'] as String? ?? '';

          // If this was the last message, update chat metadata
          if (lastMessageSent == currentUserReference &&
              chatLastMessage == message.content) {
            await _model.selectedChat!.reference.update({
              'last_message': newContent,
              'last_message_at': getCurrentTimestamp,
            });
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message updated'),
          duration: Duration(milliseconds: 1000),
          backgroundColor: Color(0xFF34C759),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update message: $e'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
    }
  }

  Future<void> _deleteMessageLocally(MessagesRecord message) async {
    // Only show confirmation dialog the first time
    final prefs = FFAppState().prefs;
    final hasConfirmedBefore = prefs.getBool('local_delete_confirmed') ?? false;

    if (!hasConfirmedBefore) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'Delete Message',
            style: TextStyle(
              fontFamily: 'System',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          content: Text(
            'This message will be deleted for you only. Other participants can still see it.',
            style: TextStyle(
              fontFamily: 'System',
              fontSize: 13,
              color: Color(0xFF8E8E93),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'System',
                  color: Color(0xFF007AFF),
                  fontSize: 17,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete for Me',
                style: TextStyle(
                  fontFamily: 'System',
                  color: Color(0xFFFF3B30),
                  fontSize: 17,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      // Remember that user has confirmed
      await prefs.setBool('local_delete_confirmed', true);
    }

    try {
      // Add current user's UID to deleted_for array — message stays in DB but hidden for this user
      await message.reference.update({
        'deleted_for': FieldValue.arrayUnion([currentUserUid]),
      });
      print('✅ Message hidden locally for user $currentUserUid');
    } catch (e) {
      print('❌ Failed to delete message locally: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete message'),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  Future<void> _unsendMessage(MessagesRecord message) async {
    // Check if the message was sent by the current user
    if (message.senderRef != currentUserReference) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You can only unsend your own messages',
            style: TextStyle(
              fontFamily: 'System',
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          duration: Duration(milliseconds: 2000),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Unsend Message',
          style: TextStyle(
            fontFamily: 'System',
            color: Color(0xFF1D1D1F),
            fontSize: 17,
            fontWeight: FontWeight.normal,
          ),
        ),
        content: Text(
          'Are you sure you want to unsend this message? This action cannot be undone.',
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
              'Unsend',
              style: TextStyle(
                fontFamily: 'System',
                color: Color(0xFFFF3B30),
                fontSize: 17,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete the message from Firestore
        print(
            '🗑️ Deleting message: "${message.content}" from ${message.reference.path}');
        await message.reference.delete();
        print('✅ Message deleted successfully from Firebase');

        // Update chat's last message if this was the last message
        if (_model.selectedChat != null) {
          final chatDoc = await _model.selectedChat!.reference.get();
          if (chatDoc.exists) {
            final chatData = chatDoc.data() as Map<String, dynamic>;
            final lastMessageSent =
                chatData['last_message_sent'] as DocumentReference?;

            // Check if this was the last message by comparing the deleted message with chat's last message
            final chatLastMessage = chatData['last_message'] as String? ?? '';
            final deletedMessageContent = message.content;

            print('🔍 DEBUG: Chat last message: "$chatLastMessage"');
            print(
                '🔍 DEBUG: Deleted message content: "$deletedMessageContent"');
            print(
                '🔍 DEBUG: Last message sent by: ${chatData['last_message_sent']}');
            print('🔍 DEBUG: Current user: $currentUserReference');

            // If this was the last message, update chat
            if (lastMessageSent == currentUserReference &&
                chatLastMessage == deletedMessageContent) {
              print('🔄 Updating chat metadata - this was the last message');

              // Get the previous message
              final previousMessages = await _model.selectedChat!.reference
                  .collection('messages')
                  .orderBy('created_at', descending: true)
                  .limit(1)
                  .get();

              if (previousMessages.docs.isNotEmpty) {
                final previousMessage = previousMessages.docs.first;
                final previousData = previousMessage.data();

                print(
                    '🔄 Found previous message: "${previousData['content']}"');

                // Update chat with previous message info
                await _model.selectedChat!.reference.update({
                  'last_message': previousData['content'] ?? '',
                  'last_message_at': previousData['created_at'] ??
                      FieldValue.serverTimestamp(),
                  'last_message_sent': previousData['sender_ref'],
                  'last_message_type':
                      previousData['message_type'] ?? MessageType.text,
                });
              } else {
                print('🔄 No previous messages found, resetting chat');

                // No previous messages, reset chat
                await _model.selectedChat!.reference.update({
                  'last_message': '',
                  'last_message_at': FieldValue.serverTimestamp(),
                  'last_message_sent': currentUserReference,
                  'last_message_type': MessageType.text,
                });
              }
            } else {
              print(
                  'ℹ️ This was not the last message, no chat metadata update needed');
            }
          }
        }

        // Force immediate UI update by refreshing the specific chat
        print('🔄 Forcing immediate chat list update...');

        // Update the chat controller's local state immediately
        final chatIndex = chatController.chats.indexWhere(
          (chat) => chat.reference.id == _model.selectedChat?.reference.id,
        );

        if (chatIndex != -1) {
          // Get the updated chat document from Firebase
          final updatedChatDoc = await _model.selectedChat!.reference.get();
          if (updatedChatDoc.exists) {
            final updatedChat = ChatsRecord.fromSnapshot(updatedChatDoc);
            chatController.chats[chatIndex] = updatedChat;
            print('✅ Updated chat in controller: ${updatedChat.lastMessage}');
          }
        }

        // Force UI update to reflect changes immediately
        if (mounted) {
          safeSetState(() {});
        }

        // Also trigger a complete refresh as backup
        print('🔄 Triggering complete chat controller refresh...');
        await chatController.refreshChats();

        print('✅ Immediate chat list update completed');

        // Message unsent successfully - no snackbar needed
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to unsend message: $e',
              style: TextStyle(
                fontFamily: 'System',
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            duration: Duration(milliseconds: 2000),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  Widget _buildAlwaysVisibleSearchBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 44,
          width: double.infinity,
          decoration: BoxDecoration(
            // iOS 26 Liquid Glass effect
            color: CupertinoColors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: CupertinoColors.white.withOpacity(0.2),
              width: 0.5,
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
          child: CupertinoTextField(
            controller: _model.searchTextController,
            focusNode: _model.searchFocusNode,
            onChanged: (value) {
              EasyDebounce.debounce(
                'searchTextController',
                Duration(milliseconds: 500),
                () => chatController.updateSearchQuery(value),
              );
            },
            placeholder: 'Search',
            placeholderStyle: TextStyle(
              fontFamily: 'SF Pro Text',
              color: CupertinoColors.systemGrey,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            prefix: Padding(
              padding: EdgeInsets.only(left: 16, right: 12),
              child: Icon(
                CupertinoIcons.search,
                color: CupertinoColors.systemGrey,
                size: 20,
              ),
            ),
            suffix: Obx(() {
              return chatController.searchQuery.value.isNotEmpty
                  ? Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () {
                          _model.searchTextController?.clear();
                          chatController.updateSearchQuery('');
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color:
                                    CupertinoColors.systemGrey.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                CupertinoIcons.clear_circled_solid,
                                color: CupertinoColors.systemGrey,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : SizedBox.shrink();
            }),
            style: TextStyle(
              fontFamily: 'SF Pro Text',
              color: CupertinoColors.label,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(color: Colors.transparent),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to wrap buttons with glass effect
  // Native iOS glass effect with proper glassy border

  Widget _buildHeaderActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // + button - liquid glass background with system blue icon
        AdaptivePopupMenuButton.widget<String>(
          items: [
            AdaptivePopupMenuItem(
              label: 'New Chat',
              icon: PlatformInfo.isIOS26OrHigher()
                  ? 'message'
                  : Icons.chat_bubble_outline,
              value: 'new_chat',
            ),
            AdaptivePopupMenuItem(
              label: 'New Group Chat',
              icon:
                  PlatformInfo.isIOS26OrHigher() ? 'person.2' : Icons.group_add,
              value: 'new_group_chat',
            ),
          ],
          onSelected: (index, item) {
            if (item.value == 'new_chat') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MobileNewChatWidget(),
                ),
              );
            } else if (item.value == 'new_group_chat') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MobileNewGroupChatWidget(),
                ),
              );
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  // 🔮 Ultra Glass - very subtle
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black)
                          .withOpacity(0.05),
                      (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black)
                          .withOpacity(0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black)
                        .withOpacity(0.08),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  CupertinoIcons.plus,
                  size: 22,
                  color: CupertinoColors.systemBlue,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatListContent() {
    return Obx(() {
      final currentTabIndex = _model.tabController?.index ?? 0;
      return Container(
        key: ValueKey(
            'chat_list_${currentTabIndex}_${chatController.searchQuery.value}'),
        color: Colors.white, // Ensure consistent white background
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // Use ScrollStartNotification to detect the BEGINNING of a manual list drag.
            // This is efficient and avoids conflicts with auto-scroll during selection adjustment.
            if (notification is ScrollStartNotification &&
                notification.dragDetails != null) {
              _hideMenuOverlay();
            }
            return false;
          },
          child: _buildChatListContentInner(),
        ),
      );
    });
  }

  Widget _buildChatListContentInner() {
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
                    fontWeight: FontWeight.normal,
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
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );

        case ChatState.success:
          // If new chat screen is toggled, show new message view
          if (_model.showNewChatScreen) {
            return _buildNewMessageView();
          }
          // If group creation is toggled, show group creation view
          if (_model.showGroupCreation) {
            return _buildGroupCreationView();
          }

          final filteredChats = chatController.filteredChats;

          if (filteredChats.isEmpty &&
              chatController.searchQuery.value.isNotEmpty) {
            // No chats match by name — show message content results
            return _buildMessageSearchResults();
          }

          // Show empty state message for new users when chat list is empty
          if (filteredChats.isEmpty &&
              chatController.searchQuery.value.isEmpty) {
            return Transform.translate(
              offset: Offset(0, -40),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon with circular background
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.person_2_fill,
                          color: CupertinoColors.systemBlue,
                          size: 48,
                        ),
                      ),
                      SizedBox(height: 32),
                      // Header title
                      Text(
                        'Connect with Like-minded People!',
                        style: TextStyle(
                          fontFamily: '.SF Pro Display',
                          color: CupertinoColors.label,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),
                      // Subtitle message
                      Text(
                        'Start meaningful conversations by connecting with real users in your network',
                        style: TextStyle(
                          fontFamily: '.SF Pro Text',
                          color: CupertinoColors.secondaryLabel,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // When searching, show both chat matches AND message content matches
          if (chatController.searchQuery.value.isNotEmpty) {
            return CustomScrollView(
              key: ValueKey(
                  'search_results_${filteredChats.length}_${chatController.searchQuery.value}'),
              physics: ClampingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                // Chats section header (only if there are chat matches)
                if (filteredChats.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(left: 20, top: 8, bottom: 4),
                      child: Text(
                        'CHATS',
                        style: TextStyle(
                          fontFamily: 'SF Pro Text',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8E8E93),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                // Chat items
                if (filteredChats.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final chat = filteredChats[index];
                        final isSelected = chatController.selectedChat.value?.reference ==
                            chat.reference;
                        return _buildChatSearchItem(chat, isSelected);
                      },
                      childCount: filteredChats.length,
                    ),
                  ),
                // Messages section
                SliverToBoxAdapter(
                  child: _buildMessageSearchResults(),
                ),
                // Bottom padding
                SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          }

          // Show flat list or folder view based on mode toggle
          if (_isFolderMode) {
            // macOS-style folder view
            return _buildFolderListView(filteredChats);
          } else {
            // Flat chat list (no folder sections)
            return _buildFlatChatList(filteredChats);
          }
      }
    });
  }

  /// Build a single chat item for the search results sliver list.
  Widget _buildChatSearchItem(ChatsRecord chat, bool isSelected) {
    if (!chat.isGroup && chatController.searchQuery.value.isNotEmpty) {
      return FutureBuilder<UsersRecord>(
        future: _getOtherUser(chat),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasData && userSnapshot.data != null) {
            final user = userSnapshot.data!;
            final displayName = user.displayName.toLowerCase();
            final query = chatController.searchQuery.value.toLowerCase();
            if (!displayName.contains(query)) {
              return SizedBox.shrink();
            }
          }
          return _buildChatListItemObx(chat, isSelected);
        },
      );
    }
    return _buildChatListItemObx(chat, isSelected);
  }

  /// Shared Obx wrapper for a chat list item (used by both normal list and search).
  Widget _buildChatListItemObx(ChatsRecord chat, bool isSelected) {
    return Obx(() {
      final freshChat = chatController.chats.firstWhere(
        (c) => c.reference.id == chat.reference.id,
        orElse: () => chat,
      );
      final __ = chatController.locallySeenChats.length;
      final hasUnread = chatController.hasUnreadMessages(freshChat);
      return _MobileChatListItem(
        key: ValueKey('chat_item_${freshChat.reference.id}'),
        chat: freshChat,
        isSelected: isSelected,
        onTap: () {
          if (_model.selectedChat?.reference == freshChat.reference) return;
          chatController.selectChat(freshChat);
          _openChatFullScreen(freshChat);
        },
        hasUnreadMessages: hasUnread,
        chatController: chatController,
        getOrCreateUserFuture: _getOrCreateUserFuture,
      );
    });
  }

  /// Simple flat chat list with Pinned at top and Inactive at bottom (default view).
  Widget _buildFlatChatList(List<ChatsRecord> filteredChats) {
    final userRef = currentUserReference;
    final pinned = filteredChats.where((c) => c.isPinnedByUser(userRef)).toList();
    final unpinned = filteredChats.where((c) => !c.isPinnedByUser(userRef)).toList();

    // filteredChats already has active-only chats (controller excludes inactive on All tab),
    // so all unpinned chats here are active
    final active = unpinned;

    // Get inactive chats directly from the full unfiltered list
    final inactive = _getInactiveChats();

    return ListView(
      padding: EdgeInsets.only(bottom: 100),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        // Pinned section
        if (pinned.isNotEmpty) ...[
          _buildSmartSectionHeader(
            title: 'Pinned',
            icon: CupertinoIcons.pin_fill,
            count: pinned.length,
            isCollapsed: _isPinnedCollapsed,
            unreadCount: _countUnread(pinned),
            onToggle: () => setState(() => _isPinnedCollapsed = !_isPinnedCollapsed),
          ),
          if (!_isPinnedCollapsed)
            for (final chat in pinned)
              _buildChatListItemObx(chat, false),
        ],
        // "Recent" label divider (matches macOS)
        if (active.isNotEmpty && pinned.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
            child: Text(
              'Recent',
              style: TextStyle(
                fontFamily: '.SF Pro Text',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E8E93),
                letterSpacing: 0.2,
              ),
            ),
          ),

        // Active chats (recent)
        for (final chat in active)
          _buildChatListItemObx(chat, false),

        // Inactive section (30+ days)
        if (inactive.isNotEmpty) ...[
          _buildSmartSectionHeader(
            title: 'Inactive',
            icon: CupertinoIcons.archivebox,
            count: inactive.length,
            isCollapsed: _isInactiveCollapsed,
            unreadCount: _countUnread(inactive),
            onToggle: () => setState(() => _isInactiveCollapsed = !_isInactiveCollapsed),
          ),
          if (!_isInactiveCollapsed)
            for (final chat in inactive)
              _buildChatListItemObx(chat, false),
        ],
      ],
    );
  }

  /// Returns true if the chat has had no new messages in the last 30 days,
  /// OR if the current user has manually moved it to inactive.
  /// Mirrors ChatController._isInactive logic for parity with macOS.
  bool _isChatInactive(ChatsRecord chat) {
    // Check if manually moved to inactive by the current user
    final userRef = currentUserReference;
    if (userRef != null) {
      final manuallyInactiveBy = chat.snapshotData['manually_inactive_by'] as List<dynamic>?;
      if (manuallyInactiveBy != null && manuallyInactiveBy.contains(userRef)) {
        return true;
      }
    }
    final lastActivity = chat.lastMessageAt ?? chat.createdAt;
    if (lastActivity == null) return true;
    return DateTime.now().difference(lastActivity).inDays >= 30;
  }

  /// Get inactive chats from the FULL unfiltered list.
  /// chatController.filteredChats already excludes inactive chats on the All tab,
  /// so we must source them directly from chatController.chats.
  List<ChatsRecord> _getInactiveChats() {
    final userRef = currentUserReference;
    final blockedIds = chatController.blockedUserIds.value;
    return chatController.chats.where((chat) {
      // Must be inactive
      if (!_isChatInactive(chat)) return false;
      // Exclude pinned (pinned chats stay in the Pinned section)
      if (chat.isPinnedByUser(userRef)) return false;
      // Exclude blocked DMs
      if (!chat.isGroup && chat.members.any((m) =>
          m != userRef && blockedIds.contains(m.id))) return false;
      return true;
    }).toList();
  }


  /// macOS-style folder list view with smart sections.
  Widget _buildFolderListView(List<ChatsRecord> filteredChats) {
    // Smart folder classification (same as macOS)
    final userRef = currentUserReference;
    final pinned = filteredChats.where((c) => c.isPinnedByUser(userRef)).toList();
    // filteredChats already excludes inactive on All tab, no need for _isChatInactive check
    final groups = filteredChats.where((c) => !c.isPinnedByUser(userRef) && c.isGroup).toList();
    final dms = filteredChats.where((c) => !c.isPinnedByUser(userRef) && !c.isGroup).toList();
    // Get inactive chats from the full unfiltered list
    final inactive = _getInactiveChats();

    return ListView(
      padding: EdgeInsets.only(bottom: 100),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        // "New Folder" button at top (Slack-style compact link)
        _buildNewFolderLink(),

        // Pinned section (combined DM + Groups)
        if (pinned.isNotEmpty) ...[
          _buildSmartSectionHeader(
            title: 'Pinned',
            icon: CupertinoIcons.pin_fill,
            count: pinned.length,
            isCollapsed: _isPinnedCollapsed,
            unreadCount: _countUnread(pinned),
            onToggle: () => setState(() => _isPinnedCollapsed = !_isPinnedCollapsed),
          ),
          if (!_isPinnedCollapsed)
            for (final chat in pinned)
              _buildChatListItemObx(chat, false),
        ],

        // Groups section (active only)
        if (groups.isNotEmpty) ...[
          _buildSmartSectionHeader(
            title: 'Groups',
            icon: CupertinoIcons.person_2_fill,
            count: groups.length,
            isCollapsed: _isGroupsCollapsed,
            unreadCount: _countUnread(groups),
            onToggle: () => setState(() => _isGroupsCollapsed = !_isGroupsCollapsed),
          ),
          if (!_isGroupsCollapsed)
            for (final chat in groups)
              _buildChatListItemObx(chat, false),
        ],

        // DM section (active only)
        if (dms.isNotEmpty) ...[
          _buildSmartSectionHeader(
            title: 'DM',
            icon: CupertinoIcons.person_fill,
            count: dms.length,
            isCollapsed: _isDMCollapsed,
            unreadCount: _countUnread(dms),
            onToggle: () => setState(() => _isDMCollapsed = !_isDMCollapsed),
          ),
          if (!_isDMCollapsed)
            for (final chat in dms)
              _buildChatListItemObx(chat, false),
        ],

        // Custom user-created folders
        for (final folder in _chatFolders)
          _buildCustomFolderSection(folder, filteredChats),

        // Inactive section (30+ days no messages)
        if (inactive.isNotEmpty) ...[
          _buildSmartSectionHeader(
            title: 'Inactive',
            icon: CupertinoIcons.archivebox,
            count: inactive.length,
            isCollapsed: _isInactiveCollapsed,
            unreadCount: _countUnread(inactive),
            onToggle: () => setState(() => _isInactiveCollapsed = !_isInactiveCollapsed),
          ),
          if (!_isInactiveCollapsed)
            for (final chat in inactive)
              _buildChatListItemObx(chat, false),
        ],
      ],
    );
  }

  int _countUnread(List<ChatsRecord> chats) {
    int count = 0;
    for (final chat in chats) {
      if (chatController.hasUnreadMessages(chat)) count++;
    }
    return count;
  }

  /// Compact "New Folder" link at the top of the list.
  Widget _buildNewFolderLink() {
    return GestureDetector(
      onTap: () => _showCreateFolderDialog(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Icon(CupertinoIcons.add, size: 14, color: Color(0xFF8E8E93)),
            SizedBox(width: 6),
            Text(
              'New Folder',
              style: TextStyle(
                fontFamily: '.SF Pro Text',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Smart auto-category section header (Pinned, Groups, DM).
  Widget _buildSmartSectionHeader({
    required String title,
    required IconData icon,
    required int count,
    required bool isCollapsed,
    required int unreadCount,
    required VoidCallback onToggle,
  }) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Color(0xFFF2F2F7),
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCollapsed
                  ? CupertinoIcons.chevron_right
                  : CupertinoIcons.chevron_down,
              size: 13,
              color: Color(0xFF8E8E93),
            ),
            SizedBox(width: 6),
            Icon(icon, size: 15, color: Color(0xFF8E8E93)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: '.SF Pro Text',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unreadCount > 0) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 6),
            ],
            Text(
              '$count',
              style: TextStyle(
                fontFamily: '.SF Pro Text',
                fontSize: 12,
                color: Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a custom user-created folder section.
  Widget _buildCustomFolderSection(
      ChatFoldersRecord folder, List<ChatsRecord> allChats) {
    final folderChats = allChats
        .where((c) => folder.chatIds.contains(c.reference.id))
        .toList();
    final unreadCount = _countUnread(folderChats);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            folder.reference.update({'is_collapsed': !folder.isCollapsed});
          },
          onLongPress: () => _showFolderOptionsSheet(folder),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Color(0xFFF2F2F7),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  folder.isCollapsed
                      ? CupertinoIcons.chevron_right
                      : CupertinoIcons.chevron_down,
                  size: 13,
                  color: Color(0xFF8E8E93),
                ),
                SizedBox(width: 6),
                Icon(CupertinoIcons.folder_fill, size: 15, color: Color(0xFF007AFF)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    folder.name,
                    style: TextStyle(
                      fontFamily: '.SF Pro Text',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3C3C43),
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (unreadCount > 0) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: TextStyle(
                        fontFamily: '.SF Pro Text',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                ],
                Text(
                  '${folderChats.length}',
                  style: TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                SizedBox(width: 6),
                // Add chats button
                GestureDetector(
                  onTap: () => _showAddChatsToFolderSheet(folder),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(CupertinoIcons.add, size: 14, color: Color(0xFF8E8E93)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!folder.isCollapsed)
          for (final chat in folderChats)
            _buildChatListItemObx(chat, false),
      ],
    );
  }

  /// Create folder button (used from bottom sheet).
  Widget _buildCreateFolderButton() {
    return _buildNewFolderLink();
  }

  /// Show a Cupertino-style chat picker to add chats to a folder.
  void _showAddChatsToFolderSheet(ChatFoldersRecord folder) async {
    final allChats = chatController.chats;
    final existingIds = folder.chatIds.toSet();
    // Only show chats not already in this folder
    final availableChats = allChats
        .where((c) => !existingIds.contains(c.reference.id))
        .toList();
    final availableGroups = availableChats.where((c) => c.isGroup).toList();
    final availableDMs = availableChats.where((c) => !c.isGroup).toList();

    // Pre-resolve DM names
    final dmNameMap = <String, String>{};
    for (final dm in availableDMs) {
      if (dm.title.isNotEmpty) {
        dmNameMap[dm.reference.id] = dm.title;
      } else {
        try {
          final otherUserRef = dm.members.firstWhere(
            (m) => m != currentUserReference,
            orElse: () => dm.members.first,
          );
          final user = await _getOrCreateUserFuture(otherUserRef);
          dmNameMap[dm.reference.id] = user.displayName.isNotEmpty ? user.displayName : 'User';
        } catch (_) {
          dmNameMap[dm.reference.id] = 'Direct Message';
        }
      }
    }

    final selectedIds = <String>{};

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.7,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: EdgeInsets.only(top: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Color(0xFFD1D1D6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add to "${folder.name}"',
                              style: TextStyle(
                                fontFamily: '.SF Pro Text',
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1C1C1E),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Select chats to add',
                              style: TextStyle(
                                fontFamily: '.SF Pro Text',
                                fontSize: 13,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(20),
                        minSize: 0,
                        onPressed: selectedIds.isEmpty
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                await folder.reference.update({
                                  'chat_ids': FieldValue.arrayUnion(selectedIds.toList()),
                                  'updated_at': FieldValue.serverTimestamp(),
                                });
                              },
                        child: Text(
                          'Add (${selectedIds.length})',
                          style: TextStyle(
                            fontFamily: '.SF Pro Text',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Color(0xFFE5E5EA)),
                // Chat list
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(bottom: 20),
                    children: [
                      if (availableGroups.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(20, 12, 20, 6),
                          child: Text(
                            'GROUPS',
                            style: TextStyle(
                              fontFamily: '.SF Pro Text',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8E8E93),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        for (final chat in availableGroups)
                          _buildChatPickerTile(
                            name: chat.title.isNotEmpty ? chat.title : 'Group',
                            icon: CupertinoIcons.person_2_fill,
                            isSelected: selectedIds.contains(chat.reference.id),
                            onTap: () {
                              setSheetState(() {
                                if (selectedIds.contains(chat.reference.id)) {
                                  selectedIds.remove(chat.reference.id);
                                } else {
                                  selectedIds.add(chat.reference.id);
                                }
                              });
                            },
                          ),
                      ],
                      if (availableDMs.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(20, 12, 20, 6),
                          child: Text(
                            'DIRECT MESSAGES',
                            style: TextStyle(
                              fontFamily: '.SF Pro Text',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8E8E93),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        for (final chat in availableDMs)
                          _buildChatPickerTile(
                            name: dmNameMap[chat.reference.id] ?? chat.title,
                            icon: CupertinoIcons.person_fill,
                            isSelected: selectedIds.contains(chat.reference.id),
                            onTap: () {
                              setSheetState(() {
                                if (selectedIds.contains(chat.reference.id)) {
                                  selectedIds.remove(chat.reference.id);
                                } else {
                                  selectedIds.add(chat.reference.id);
                                }
                              });
                            },
                          ),
                      ],
                      if (availableGroups.isEmpty && availableDMs.isEmpty)
                        Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                              'All chats are already in this folder',
                              style: TextStyle(
                                fontFamily: '.SF Pro Text',
                                fontSize: 15,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatPickerTile({
    required String name,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: isSelected ? Color(0xFFE8F0FE) : Colors.transparent,
        child: Row(
          children: [
            Icon(icon, size: 18, color: Color(0xFF8E8E93)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontFamily: '.SF Pro Text',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF1C1C1E),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              Icon(CupertinoIcons.checkmark_circle_fill, size: 22, color: Color(0xFF007AFF)),
          ],
        ),
      ),
    );
  }

  void _showCreateFolderDialog() {
    final textController = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('New Folder'),
        content: Padding(
          padding: EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: textController,
            placeholder: 'Folder name',
            autofocus: true,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text('Create'),
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isEmpty || currentUserReference == null) return;
              Navigator.pop(ctx);
              final docRef =
                  ChatFoldersRecord.createDoc(currentUserReference!);
              await docRef.set({
                ...createChatFoldersRecordData(
                  name: name,
                  order: _chatFolders.length,
                  isCollapsed: false,
                  createdAt: getCurrentTimestamp,
                  updatedAt: getCurrentTimestamp,
                ),
                'chat_ids': [],
              });
            },
          ),
        ],
      ),
    );
  }

  void _showFolderOptionsSheet(ChatFoldersRecord folder) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(folder.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _showRenameFolderDialog(folder);
            },
            child: Text('Rename'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDeleteFolder(folder);
            },
            child: Text('Delete Folder'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel'),
        ),
      ),
    );
  }

  void _showRenameFolderDialog(ChatFoldersRecord folder) {
    final textController = TextEditingController(text: folder.name);
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Rename Folder'),
        content: Padding(
          padding: EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: textController,
            autofocus: true,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text('Save'),
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await folder.reference.update({
                'name': name,
                'updated_at': getCurrentTimestamp,
              });
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFolder(ChatFoldersRecord folder) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Delete "${folder.name}"?'),
        content: Text('Chats in this folder will not be deleted.'),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text('Delete'),
            onPressed: () async {
              Navigator.pop(ctx);
              await folder.reference.delete();
            },
          ),
        ],
      ),
    );
  }

  /// Build the "Messages" search results section.
  Widget _buildMessageSearchResults() {
    return Obx(() {
      final results = chatController.messageSearchResults;
      final isSearching = chatController.isSearchingMessages.value;
      final query = chatController.searchQuery.value;

      if (query.isEmpty) return SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: EdgeInsets.only(left: 20, top: 16, bottom: 8),
            child: Row(
              children: [
                Text(
                  'MESSAGES',
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8E8E93),
                    letterSpacing: 0.5,
                  ),
                ),
                if (isSearching) ...[
                  SizedBox(width: 8),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CupertinoActivityIndicator(radius: 6),
                  ),
                ],
              ],
            ),
          ),
          // Results or empty state
          if (!isSearching && results.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text(
                'No messages match "$query"',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontSize: 15,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ),
          // Message result cards
          ...results.map((result) => _buildMessageResultCard(result)),
        ],
      );
    });
  }

  /// Build a single message search result card.
  Widget _buildMessageResultCard(MessageSearchResult result) {
    final timeStr = result.createdAt != null
        ? _formatMessageTime(result.createdAt!)
        : '';

    // Highlight the matching text
    final query = chatController.searchQuery.value.toLowerCase();
    final content = result.content;

    return GestureDetector(
      onTap: () async {
        // Navigate to the chat and scroll to the message
        try {
          final chatDoc = await result.chatRef.get();
          if (chatDoc.exists && mounted) {
            final chat = ChatsRecord.fromSnapshot(chatDoc);
            chatController.selectChat(chat);

            // Clear search
            _model.searchTextController?.clear();
            chatController.updateSearchQuery('');

            // Open chat and scroll to message
            _openChatFullScreen(chat);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(Duration(milliseconds: 500), () {
                _model.chatThreadComponentKey.currentState
                    ?.scrollToMessage(result.messageRef.id);
              });
            });
          }
        } catch (e) {
          // Silently fail
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: sender info + chat name + time
            Row(
              children: [
                // Sender avatar
                if (result.senderPhoto.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      result.senderPhoto,
                      width: 24,
                      height: 24,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildDefaultAvatar(24),
                    ),
                  )
                else
                  _buildDefaultAvatar(24),
                SizedBox(width: 8),
                // Sender name
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: result.senderName.isNotEmpty
                              ? result.senderName
                              : 'Unknown',
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        TextSpan(
                          text: '  in ',
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            fontSize: 13,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        TextSpan(
                          text: result.chatName,
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            // Message content with highlighted query
            _buildHighlightedText(content, query),
          ],
        ),
      ),
    );
  }

  /// Build highlighted text with the search query emphasized.
  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'SF Pro Text',
          fontSize: 14,
          color: Color(0xFF3C3C43),
          height: 1.4,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);

    if (matchIndex == -1) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'SF Pro Text',
          fontSize: 14,
          color: Color(0xFF3C3C43),
          height: 1.4,
        ),
      );
    }

    // Show text around the match
    final start = (matchIndex - 30).clamp(0, text.length);
    final end = (matchIndex + query.length + 80).clamp(0, text.length);
    final visibleText = (start > 0 ? '...' : '') +
        text.substring(start, end) +
        (end < text.length ? '...' : '');
    final adjustedMatchIndex = matchIndex - start + (start > 0 ? 3 : 0);

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'SF Pro Text',
          fontSize: 14,
          color: Color(0xFF3C3C43),
          height: 1.4,
        ),
        children: [
          TextSpan(text: visibleText.substring(0, adjustedMatchIndex)),
          TextSpan(
            text: visibleText.substring(
                adjustedMatchIndex, adjustedMatchIndex + query.length),
            style: TextStyle(
              backgroundColor: Color(0xFFFFF3CD),
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1D1F),
            ),
          ),
          TextSpan(
              text: visibleText.substring(adjustedMatchIndex + query.length)),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Icon(
        CupertinoIcons.person_fill,
        size: size * 0.6,
        color: Color(0xFF8E8E93),
      ),
    );
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${timestamp.month}/${timestamp.day}';
  }

  Future<UsersRecord> _getOtherUser(ChatsRecord chat) async {
    final otherUserRef = chat.members.firstWhere(
      (member) => member != currentUserReference,
      orElse: () => chat.members.first,
    );
    return await UsersRecord.getDocumentOnce(otherUserRef);
  }

  Widget _buildGroupCreationView() {
    return Column(
      children: [
        // Header for group creation
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            border: Border(
              bottom: BorderSide(
                color: CupertinoColors.separator,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.group_solid,
                color: CupertinoColors.systemBlue,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Create New Group',
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    color: CupertinoColors.label,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.41,
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
                    _model.groupMemberSearchController?.clear();
                    _model.groupImagePath = null;
                    _model.groupImageUrl = null;
                    _model.isUploadingImage = false;
                  });
                },
                child: Icon(
                  CupertinoIcons.xmark,
                  color: CupertinoColors.systemGrey,
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
                  'Group Name (Optional)',
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    color: CupertinoColors.label,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.41,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: CupertinoColors.separator,
                      width: 0.5,
                    ),
                  ),
                  child: CupertinoTextField(
                    controller: _model.groupNameController,
                    onChanged: (value) {
                      setState(() {
                        _model.groupName = value;
                      });
                    },
                    placeholder: 'Enter group name',
                    placeholderStyle: TextStyle(
                      fontFamily: 'SF Pro Text',
                      color: CupertinoColors.systemGrey,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    style: TextStyle(
                      fontFamily: 'SF Pro Text',
                      color: CupertinoColors.label,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                // Group image upload
                Text(
                  'Group Image (Optional)',
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    color: CupertinoColors.label,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.41,
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
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: CupertinoColors.separator,
                            width: 0.5,
                          ),
                        ),
                        child: _model.isUploadingImage
                            ? Center(
                                child: CupertinoActivityIndicator(
                                  color: CupertinoColors.systemBlue,
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
                                        color: CupertinoColors.systemGrey6,
                                        child: Icon(
                                          CupertinoIcons.photo,
                                          color: CupertinoColors.systemGrey,
                                          size: 24,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        width: 80,
                                        height: 80,
                                        color: CupertinoColors.systemGrey6,
                                        child: Icon(
                                          CupertinoIcons.photo,
                                          color: CupertinoColors.systemGrey,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.photo_on_rectangle,
                                        color: CupertinoColors.systemGrey,
                                        size: 24,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Add Image',
                                        style: TextStyle(
                                          fontFamily: 'SF Pro Text',
                                          color: CupertinoColors.systemGrey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
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
                              fontFamily: 'SF Pro Text',
                              color: _model.groupImageUrl != null
                                  ? CupertinoColors.systemGreen
                                  : CupertinoColors.systemGrey,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.24,
                            ),
                          ),
                          SizedBox(height: 8),
                          CupertinoButton(
                            onPressed: _model.isUploadingImage
                                ? null
                                : _pickGroupImage,
                            color: _model.isUploadingImage
                                ? CupertinoColors.systemGrey
                                : CupertinoColors.systemBlue,
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            borderRadius: BorderRadius.circular(8),
                            minSize: 0,
                            child: Text(
                              _model.groupImageUrl != null
                                  ? 'Change'
                                  : 'Select',
                              style: TextStyle(
                                fontFamily: 'SF Pro Text',
                                color: CupertinoColors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.15,
                              ),
                            ),
                          ),
                          if (_model.groupImageUrl != null) ...[
                            SizedBox(width: 8),
                            CupertinoButton(
                              onPressed: () {
                                setState(() {
                                  _model.groupImagePath = null;
                                  _model.groupImageUrl = null;
                                });
                              },
                              color: CupertinoColors.systemRed,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              borderRadius: BorderRadius.circular(8),
                              minSize: 0,
                              child: Text(
                                'Remove',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Text',
                                  color: CupertinoColors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.15,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                // Selected members header with search
                Row(
                  children: [
                    Text(
                      'Selected Members (${_model.selectedMembers.length})',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        color: CupertinoColors.label,
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.41,
                      ),
                    ),
                    Spacer(),
                    Container(
                      width: 180,
                      height: 36,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: CupertinoColors.separator,
                          width: 0.5,
                        ),
                      ),
                      child: CupertinoTextField(
                        controller: _model.groupMemberSearchController,
                        onChanged: (_) => setState(() {}),
                        placeholder: 'Search...',
                        placeholderStyle: TextStyle(
                          fontFamily: 'SF Pro Text',
                          color: CupertinoColors.systemGrey,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        prefix: Padding(
                          padding: EdgeInsets.only(left: 8, right: 4),
                          child: Icon(
                            CupertinoIcons.search,
                            color: CupertinoColors.systemBlue,
                            size: 16,
                          ),
                        ),
                        suffix: _model.groupMemberSearchController?.text
                                    .isNotEmpty ==
                                true
                            ? GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _model.groupMemberSearchController?.clear();
                                  });
                                },
                                child: Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Icon(
                                    CupertinoIcons.xmark_circle_fill,
                                    color: CupertinoColors.systemGrey,
                                    size: 16,
                                  ),
                                ),
                              )
                            : null,
                        style: TextStyle(
                          fontFamily: 'SF Pro Text',
                          color: CupertinoColors.label,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                // Users list for selection (filtered by connections)
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: CupertinoColors.separator,
                      width: 0.5,
                    ),
                  ),
                  child: currentUserReference == null
                      ? Center(
                          child: CupertinoActivityIndicator(
                            color: CupertinoColors.systemBlue,
                          ),
                        )
                      : StreamBuilder<UsersRecord>(
                          stream:
                              UsersRecord.getDocument(currentUserReference!),
                          builder: (context, currentUserSnapshot) {
                            if (!currentUserSnapshot.hasData) {
                              return Center(
                                child: CupertinoActivityIndicator(
                                  color: CupertinoColors.systemBlue,
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
                                      CupertinoIcons.person_2,
                                      color: CupertinoColors.systemGrey,
                                      size: 48,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No connections yet',
                                      style: TextStyle(
                                        fontFamily: 'SF Pro Text',
                                        color: CupertinoColors.label,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: -0.41,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Add connections to create a group',
                                      style: TextStyle(
                                        fontFamily: 'SF Pro Text',
                                        color: CupertinoColors.systemGrey,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
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
                              padding: EdgeInsets.all(8),
                              itemCount: connections.length,
                              itemBuilder: (context, index) {
                                final connectionRef = connections[index];

                                return StreamBuilder<UsersRecord>(
                                  stream:
                                      UsersRecord.getDocument(connectionRef),
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

                                    return GestureDetector(
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
                                              ? CupertinoColors.systemBlue
                                              : CupertinoColors
                                                  .systemBackground,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSelected
                                                ? CupertinoColors.systemBlue
                                                : CupertinoColors.separator,
                                            width: isSelected ? 1.5 : 0.5,
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
                                                    color: CupertinoColors
                                                        .systemGrey5,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    child: CachedNetworkImage(
                                                      imageUrl: user.photoUrl,
                                                      width: 40,
                                                      height: 40,
                                                      fit: BoxFit.cover,
                                                      memCacheWidth: 80,
                                                      memCacheHeight: 80,
                                                      maxWidthDiskCache: 80,
                                                      maxHeightDiskCache: 80,
                                                      filterQuality:
                                                          FilterQuality.high,
                                                      placeholder:
                                                          (context, url) =>
                                                              Container(
                                                        width: 40,
                                                        height: 40,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: CupertinoColors
                                                              .systemGrey5,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: Icon(
                                                          CupertinoIcons
                                                              .person_fill,
                                                          color: CupertinoColors
                                                              .systemGrey,
                                                          size: 18,
                                                        ),
                                                      ),
                                                      errorWidget: (context,
                                                              url, error) =>
                                                          Container(
                                                        width: 40,
                                                        height: 40,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: CupertinoColors
                                                              .systemGrey5,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: Icon(
                                                          CupertinoIcons
                                                              .person_fill,
                                                          color: CupertinoColors
                                                              .systemGrey,
                                                          size: 18,
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
                                                        color: CupertinoColors
                                                            .systemGreen,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: CupertinoColors
                                                              .systemBackground,
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
                                                      fontFamily: 'SF Pro Text',
                                                      color: isSelected
                                                          ? CupertinoColors
                                                              .white
                                                          : CupertinoColors
                                                              .label,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      letterSpacing: -0.24,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    user.email,
                                                    style: TextStyle(
                                                      fontFamily: 'SF Pro Text',
                                                      color: isSelected
                                                          ? CupertinoColors
                                                              .white
                                                              .withOpacity(0.8)
                                                          : CupertinoColors
                                                              .systemGrey,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isSelected)
                                              Container(
                                                padding: EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: CupertinoColors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  CupertinoIcons.check_mark,
                                                  color: CupertinoColors
                                                      .systemBlue,
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
                          }),
                ),
                SizedBox(height: 20),
                // Create group button
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    onPressed: _model.selectedMembers.isNotEmpty
                        ? () => _createGroup()
                        : null,
                    color: _model.selectedMembers.isNotEmpty
                        ? CupertinoColors.systemBlue
                        : CupertinoColors.systemGrey,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    borderRadius: BorderRadius.circular(10),
                    child: Text(
                      'Create Group',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        color: CupertinoColors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.41,
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
      if (_model.selectedMembers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select at least one member'),
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
        _model.selectedChat = newChat;
        _model.showGroupCreation = false;
        _model.groupName = '';
        _model.selectedMembers = [];
        _model.groupNameController?.clear();
        _model.groupMemberSearchController?.clear();
        _model.groupImagePath = null;
        _model.groupImageUrl = null;
        _model.isUploadingImage = false;
      });
      chatController.selectChat(newChat);

      // Navigate to the new group chat immediately
      _openChatFullScreen(newChat);
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

  Widget _buildNewMessageView() {
    return Column(
      children: [
        // Header for new message
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            border: Border(
              bottom: BorderSide(
                color: CupertinoColors.separator,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.chat_bubble,
                color: CupertinoColors.systemBlue,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start a New Direct Message',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        color: CupertinoColors.label,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.41,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Search for a connection to begin a private conversation',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        color: CupertinoColors.systemGrey,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _model.showNewChatScreen = false;
                    _model.newChatSearchController?.clear();
                  });
                },
                child: Icon(
                  CupertinoIcons.xmark,
                  color: CupertinoColors.systemGrey,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        // Search bar
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
          ),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.separator,
                width: 0.5,
              ),
            ),
            child: CupertinoTextField(
              controller: _model.newChatSearchController,
              onChanged: (value) {
                setState(() {});
              },
              placeholder: 'Search by name or email',
              placeholderStyle: TextStyle(
                fontFamily: 'SF Pro Text',
                color: CupertinoColors.systemGrey,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefix: Padding(
                padding: EdgeInsets.only(left: 12, right: 8),
                child: Icon(
                  CupertinoIcons.search,
                  color: CupertinoColors.systemBlue,
                  size: 18,
                ),
              ),
              suffix: _model.newChatSearchController?.text.isNotEmpty == true
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          _model.newChatSearchController?.clear();
                        });
                      },
                      child: Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: CupertinoColors.systemGrey,
                          size: 16,
                        ),
                      ),
                    )
                  : null,
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                color: CupertinoColors.label,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        // Suggested connections list
        Expanded(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12, top: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 14,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBlue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'SUGGESTED',
                        style: TextStyle(
                          fontFamily: 'SF Pro Text',
                          color: CupertinoColors.systemGrey,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: currentUserReference == null
                      ? Center(
                          child: CupertinoActivityIndicator(
                            color: CupertinoColors.systemBlue,
                          ),
                        )
                      : StreamBuilder<UsersRecord>(
                          stream:
                              UsersRecord.getDocument(currentUserReference!),
                          builder: (context, currentUserSnapshot) {
                            if (!currentUserSnapshot.hasData) {
                              return Center(
                                child: CupertinoActivityIndicator(
                                  color: CupertinoColors.systemBlue,
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
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.systemBlue
                                            .withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.person_2,
                                        color: CupertinoColors.systemBlue,
                                        size: 32,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No connections',
                                      style: TextStyle(
                                        fontFamily: 'SF Pro Text',
                                        color: CupertinoColors.label,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.41,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Add connections to start chatting',
                                      style: TextStyle(
                                        fontFamily: 'SF Pro Text',
                                        color: CupertinoColors.systemGrey,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final searchQuery = _model
                                    .newChatSearchController?.text
                                    .toLowerCase() ??
                                '';

                            return ListView.builder(
                              itemCount: connections.length,
                              itemBuilder: (context, index) {
                                final connectionRef = connections[index];

                                return StreamBuilder<UsersRecord>(
                                  stream:
                                      UsersRecord.getDocument(connectionRef),
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

                                    return GestureDetector(
                                      onTap: () async {
                                        await _startNewChatWithUser(user);
                                        setState(() {
                                          _model.showNewChatScreen = false;
                                        });
                                      },
                                      child: Container(
                                        margin: EdgeInsets.only(bottom: 8),
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color:
                                              CupertinoColors.systemBackground,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: CupertinoColors.separator,
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            // Avatar
                                            Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    color: CupertinoColors
                                                        .systemGrey5,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            24),
                                                    child: CachedNetworkImage(
                                                      imageUrl: user.photoUrl,
                                                      width: 48,
                                                      height: 48,
                                                      fit: BoxFit.cover,
                                                      memCacheWidth: 96,
                                                      memCacheHeight: 96,
                                                      maxWidthDiskCache: 96,
                                                      maxHeightDiskCache: 96,
                                                      filterQuality:
                                                          FilterQuality.high,
                                                      placeholder:
                                                          (context, url) =>
                                                              Container(
                                                        width: 48,
                                                        height: 48,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: CupertinoColors
                                                              .systemGrey5,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: Icon(
                                                          CupertinoIcons
                                                              .person_fill,
                                                          color: CupertinoColors
                                                              .systemGrey,
                                                          size: 24,
                                                        ),
                                                      ),
                                                      errorWidget: (context,
                                                              url, error) =>
                                                          Container(
                                                        width: 48,
                                                        height: 48,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: CupertinoColors
                                                              .systemGrey5,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: Icon(
                                                          CupertinoIcons
                                                              .person_fill,
                                                          color: CupertinoColors
                                                              .systemGrey,
                                                          size: 24,
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
                                                        color: CupertinoColors
                                                            .systemGreen,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: CupertinoColors
                                                              .systemBackground,
                                                          width: 2,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
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
                                                      fontFamily: 'SF Pro Text',
                                                      color:
                                                          CupertinoColors.label,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      letterSpacing: -0.24,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    user.email,
                                                    style: TextStyle(
                                                      fontFamily: 'SF Pro Text',
                                                      color: CupertinoColors
                                                          .systemGrey,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Start Chat button
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: CupertinoColors
                                                    .systemBlue
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                CupertinoIcons.arrow_right,
                                                color:
                                                    CupertinoColors.systemBlue,
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
                          }),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _startNewChatWithUser(UsersRecord user) async {
    try {
      final chatToOpen =
          await ChatHelpers.findOrCreateDirectChat(user.reference);

      setState(() {
        _model.showNewChatScreen = false;
      });
      chatController.selectChat(chatToOpen);
      // Open in full-screen
      _openChatFullScreen(chatToOpen);
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

  Widget _buildHeaderAvatar(ChatsRecord chat) {
    if (chat.isGroup) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: CachedNetworkImage(
            imageUrl: chat.chatImageUrl,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            memCacheWidth: 80,
            memCacheHeight: 80,
            maxWidthDiskCache: 80,
            maxHeightDiskCache: 80,
            filterQuality: FilterQuality.high,
            placeholder: (context, url) => Container(
              width: 36,
              height: 36,
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
              width: 36,
              height: 36,
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
            // Check if this is Summer
            if (otherUserRef.path.contains('ai_agent_summerai')) {
              imageUrl =
                  'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120';
            } else {
              imageUrl = userSnapshot.data!.photoUrl;
            }
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
            _buildOptionTile(
              icon: Icons.push_pin_outlined,
              title: 'Pinned Messages',
              onTap: () {
                Navigator.pop(context);
                _navigateToPinnedMessages(chat);
              },
            ),
            if (chat.isGroup)
              _buildOptionTile(
                icon: Icons.folder_outlined,
                title: 'Group Files',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToGroupFiles(chat);
                },
              ),
            _buildOptionTile(
              icon: Icons.search_rounded,
              title: 'Search Chat History',
              onTap: () {
                Navigator.pop(context);
                _navigateToSearch(chat);
              },
            ),
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
        // Navigate to new user summary page instead of old profile page
        context.pushNamed(
          UserSummaryWidget.routeName,
          queryParameters: {
            'userRef':
                serializeParam(user.reference, ParamType.DocumentReference),
          }.withoutNulls,
          extra: <String, dynamic>{
            'userRef': user.reference,
          },
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
                fontWeight: FontWeight.normal,
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
                    fontWeight: FontWeight.normal,
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

  void _navigateToPinnedMessages(ChatsRecord chat) {
    _hideMenuOverlay();
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => MobilePinnedMessagesWidget(
          chatDoc: chat,
          onMessageTap: (messageId) {
            // After popping back, scroll to the pinned message
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _model.chatThreadComponentKey.currentState
                  ?.scrollToMessage(messageId);
            });
          },
        ),
      ),
    );
  }

  void _navigateToGroupFiles(ChatsRecord chat) {
    _hideMenuOverlay();
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => MobileGroupFilesWidget(chatDoc: chat),
      ),
    );
  }

  void _navigateToSearch(ChatsRecord chat) {
    _hideMenuOverlay();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatHistoryWidget(
          chatDoc: chat,
          showAppBar: true,
          onMessageSelected: (messageId) {
            Navigator.pop(context); // Close search screen
            // Use postFrameCallback to ensure chat thread is ready
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _model.chatThreadComponentKey.currentState
                  ?.scrollToMessage(messageId);
            });
          },
        ),
      ),
    );
  }
}

// iOS-optimized chat list item widget
class _MobileChatListItem extends StatefulWidget {
  final ChatsRecord chat;
  final bool isSelected;
  final VoidCallback onTap;
  final bool hasUnreadMessages;
  final ChatController chatController;
  final Future<UsersRecord> Function(DocumentReference) getOrCreateUserFuture;

  const _MobileChatListItem({
    Key? key,
    required this.chat,
    required this.isSelected,
    required this.onTap,
    required this.hasUnreadMessages,
    required this.chatController,
    required this.getOrCreateUserFuture,
  }) : super(key: key);

  @override
  _MobileChatListItemState createState() => _MobileChatListItemState();
}

class _MobileChatListItemState extends State<_MobileChatListItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Helper function to format timestamp
  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(timestamp);

    // If within 24 hours, show exact time
    if (difference.inHours < 24) {
      return DateFormat('h:mm a').format(timestamp);
    }
    // If more than 24 hours, show date
    else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  void _showChatMenu(ChatsRecord chat) {
    // Check if the current user has manually marked this chat as unread
    final currentUserRef = currentUserReference;
    final isManuallyUnread = currentUserRef != null && 
        (chat.snapshotData['marked_unread_by'] as List<dynamic>?)?.contains(currentUserRef) == true;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
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
            // Menu options
            _buildMenuOption(
              icon: chat.isPinnedByUser(currentUserReference) ? Icons.push_pin : Icons.push_pin_outlined,
              title: chat.isPinnedByUser(currentUserReference) ? 'Unpin Chat' : 'Pin Chat',
              onTap: () {
                Navigator.pop(sheetContext);
                _togglePinChat(chat);
              },
            ),
            _buildMenuOption(
              icon: isManuallyUnread ? Icons.mark_chat_read_outlined : Icons.mark_chat_unread_outlined,
              title: isManuallyUnread ? 'Mark as Read' : 'Mark as Unread',
              onTap: () {
                Navigator.pop(sheetContext);
                _toggleMarkAsUnread(chat, isManuallyUnread);
              },
            ),
            _buildMenuOption(
              icon: CupertinoIcons.folder,
              title: 'Move to Folder',
              onTap: () {
                Navigator.pop(sheetContext);
                _showMoveToFolderSheet(chat);
              },
            ),
            _buildMenuOption(
              icon: Icons.delete_outline,
              title: 'Delete Chat',
              onTap: () {
                Navigator.pop(sheetContext);
                _showDeleteConfirmation(chat);
              },
              textColor: Colors.red,
              iconColor: Colors.red,
            ),
            // Bottom spacing
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    final defaultColor = Color(0xFF1D1D1F);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? defaultColor,
              size: 20,
            ),
            SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                color: textColor ?? defaultColor,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _togglePinChat(ChatsRecord chat) async {
    try {
      final userRef = currentUserReference;
      if (userRef == null) return;
      final isPinned = chat.isPinnedByUser(userRef);
      print('📌 [_togglePinChat] Toggling pin for chat: ${chat.reference.path}, isPinnedByMe: $isPinned');
      if (isPinned) {
        await chat.reference.update({
          'pinned_by': FieldValue.arrayRemove([userRef]),
        });
      } else {
        await chat.reference.update({
          'pinned_by': FieldValue.arrayUnion([userRef]),
        });
      }
      print('📌 [_togglePinChat] Pin toggled successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPinned ? 'Chat unpinned' : 'Chat pinned'),
            backgroundColor: Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      print('❌ [_togglePinChat] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating chat: $e'),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  void _toggleMarkAsUnread(ChatsRecord chat, bool isCurrentlyUnread) async {
    try {
      final userRef = currentUserReference;
      if (userRef == null) return;

      if (isCurrentlyUnread) {
        // Remove from marked_unread_by
        await chat.reference.update({
          'marked_unread_by': FieldValue.arrayRemove([userRef]),
        });
        print('📖 [_toggleMarkAsUnread] Marked as read');
      } else {
        // Add to marked_unread_by and remove from last_message_seen
        await chat.reference.update({
          'marked_unread_by': FieldValue.arrayUnion([userRef]),
          'last_message_seen': FieldValue.arrayRemove([userRef]),
        });
        print('📩 [_toggleMarkAsUnread] Marked as unread');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isCurrentlyUnread ? 'Marked as read' : 'Marked as unread'),
            backgroundColor: Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      print('❌ [_toggleMarkAsUnread] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating chat'),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  void _showMoveToFolderSheet(ChatsRecord chat) async {
    if (currentUserReference == null) return;

    // Load current folders
    final folders = await queryChatFoldersRecordOnce(
      parent: currentUserReference,
      queryBuilder: (q) => q.orderBy('order'),
    );

    if (!mounted) return;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Move to Folder'),
        message: Text('Select a folder for this chat'),
        actions: [
          // Existing folders
          for (final folder in folders)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(context);
                final chatId = chat.reference.id;
                final isInFolder = folder.chatIds.contains(chatId);
                if (isInFolder) {
                  // Remove from folder
                  await folder.reference.update({
                    'chat_ids': FieldValue.arrayRemove([chatId]),
                    'updated_at': getCurrentTimestamp,
                  });
                } else {
                  // Add to folder
                  await folder.reference.update({
                    'chat_ids': FieldValue.arrayUnion([chatId]),
                    'updated_at': getCurrentTimestamp,
                  });
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (folder.chatIds.contains(chat.reference.id))
                    Icon(CupertinoIcons.check_mark, size: 18, color: CupertinoColors.systemBlue),
                  if (folder.chatIds.contains(chat.reference.id))
                    SizedBox(width: 8),
                  Text(
                    folder.name,
                    style: TextStyle(
                      color: folder.chatIds.contains(chat.reference.id)
                          ? CupertinoColors.systemBlue
                          : CupertinoColors.label,
                    ),
                  ),
                ],
              ),
            ),
          // Create new folder option
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showCreateFolderAndAdd(chat);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.folder_badge_plus, size: 18, color: CupertinoColors.systemBlue),
                SizedBox(width: 8),
                Text('New Folder', style: TextStyle(color: CupertinoColors.systemBlue)),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
      ),
    );
  }

  void _showCreateFolderAndAdd(ChatsRecord chat) {
    final textController = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('New Folder'),
        content: Padding(
          padding: EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: textController,
            placeholder: 'Folder name',
            autofocus: true,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text('Create'),
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isEmpty || currentUserReference == null) return;
              Navigator.pop(context);

              final docRef = ChatFoldersRecord.createDoc(currentUserReference!);
              await docRef.set({
                ...createChatFoldersRecordData(
                  name: name,
                  order: 0,
                  isCollapsed: false,
                  createdAt: getCurrentTimestamp,
                  updatedAt: getCurrentTimestamp,
                ),
                'chat_ids': [chat.reference.id],
              });
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(ChatsRecord chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Chat'),
        content: Text(
            'Are you sure you want to delete this chat? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChat(chat);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Color(0xFFFF3B30)),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteChat(ChatsRecord chat) async {
    try {
      print('🗑️ [_deleteChat] Deleting chat: ${chat.reference.path}');
      await chat.reference.delete();
      print('🗑️ [_deleteChat] Chat deleted successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chat deleted'),
            backgroundColor: Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      print('❌ [_deleteChat] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting chat: $e'),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Material(
      color: Colors
          .transparent, // Transparent Material to satisfy InkWell requirement
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: () => _showChatMenu(widget.chat),
        borderRadius: BorderRadius.circular(16),
        splashColor:
            Platform.isIOS ? Colors.transparent : null, // Disable ripple on iOS
        highlightColor: Platform.isIOS
            ? Colors.transparent
            : null, // Disable highlight on iOS
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  _buildChatAvatar(widget.chat),
                  SizedBox(width: 12),
                  // Chat Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _getChatDisplayName(widget.chat),
                        SizedBox(height: 4),
                        _getLastMessagePreview(widget.chat),
                      ],
                    ),
                  ),
                  // Timestamp and pin icon column
                  SizedBox(
                    height: 50, // Match avatar height
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Timestamp at top
                        Text(
                          _formatTimestamp(widget.chat.lastMessageAt),
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            color: Color(0xFF8E8E93),
                            fontSize: 13,
                          ),
                        ),
                        // Pin icon at bottom
                        if (widget.chat.isPinnedByUser(currentUserReference))
                          Icon(
                            Icons.push_pin,
                            size: 12,
                            color: Color(0xFF8E8E93),
                          )
                        else
                          SizedBox(height: 12), // Reserve space if no pin
                      ],
                    ),
                  ),
                ],
              ),
              // Notification dot centered vertically
              if (widget.hasUnreadMessages)
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Color(0xFF007AFF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
          fontFamily: 'SF Pro Text',
          color: Color(0xFF1D1D1F),
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
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
      if (cachedName != null && cachedName.isNotEmpty) {
        return Text(
          cachedName,
          style: TextStyle(
            fontFamily: 'SF Pro Text',
            color: Color(0xFF1D1D1F),
            fontSize: 17,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
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
              fontFamily: 'SF Pro Text',
              color: Color(0xFF1D1D1F),
              fontSize: 17,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      );
    }
  }

  Widget _getLastMessagePreview(ChatsRecord chat) {
    // DEBUG: Log what data the preview receives
    print('🔍 [Preview] chatId=${chat.reference.id} lastMessage="${chat.lastMessage}" lastMsgSent=${chat.lastMessageSent?.path} lastMsgType=${chat.lastMessageType} lastMsgAt=${chat.lastMessageAt}');
    
    if (chat.lastMessage.isEmpty) {
      // Special handling for service chats
      if (chat.isServiceChat == true) {
        return Text(
          'Service messages',
          style: TextStyle(
            fontFamily: 'SF Pro Text',
            color: Color(0xFF8E8E93),
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }

      // If there's a lastMessageAt timestamp, the chat has messages but
      // the last_message text field wasn't populated (e.g. image/file messages)
      if (chat.lastMessageAt != null) {
        // Try to show a descriptive preview based on message type
        final msgType = chat.lastMessageType;
        String preview = '';
        if (msgType == MessageType.image) {
          preview = '📷 Photo';
        } else if (msgType == MessageType.video) {
          preview = '🎥 Video';
        } else if (msgType == MessageType.file) {
          preview = '📎 File';
        } else if (msgType == MessageType.voice) {
          preview = '🎵 Audio';
        }

        // If we have a media preview, show it
        if (preview.isNotEmpty) {
          // Show sender name + type for group chats on iOS
          if (Platform.isIOS && chat.lastMessageSent != null) {
            return StreamBuilder<UsersRecord>(
              stream: UsersRecord.getDocument(chat.lastMessageSent!),
              builder: (context, snapshot) {
                String prefix = '';
                if (snapshot.hasData && snapshot.data != null) {
                  if (chat.lastMessageSent == currentUserReference) {
                    prefix = 'You: ';
                  } else {
                    final firstName = snapshot.data!.displayName.split(' ').first;
                    prefix = '$firstName: ';
                  }
                }
                return Text(
                  '$prefix$preview',
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    color: Color(0xFF8E8E93),
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            );
          }
          return Text(
            preview,
            style: TextStyle(
              fontFamily: 'SF Pro Text',
              color: Color(0xFF8E8E93),
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        // lastMessageAt exists but no specific media type — show generic "Message"
        // with sender prefix if available
        if (Platform.isIOS && chat.lastMessageSent != null) {
          return StreamBuilder<UsersRecord>(
            stream: UsersRecord.getDocument(chat.lastMessageSent!),
            builder: (context, snapshot) {
              String prefix = '';
              if (snapshot.hasData && snapshot.data != null) {
                if (chat.lastMessageSent == currentUserReference) {
                  prefix = 'You: ';
                } else {
                  final firstName = snapshot.data!.displayName.split(' ').first;
                  prefix = '$firstName: ';
                }
              }
              return Text(
                '${prefix}Message',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  color: Color(0xFF8E8E93),
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
          );
        }
        return Text(
          'Message',
          style: TextStyle(
            fontFamily: 'SF Pro Text',
            color: Color(0xFF8E8E93),
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }

      return Text(
        'No messages',
        style: TextStyle(
          fontFamily: 'SF Pro Text',
          color: Color(0xFF8E8E93),
          fontSize: 15,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Show sender name for group chats or when lastMessageSent is available
    // On iOS, show sender name for all chats
    if (Platform.isIOS && chat.lastMessageSent != null) {
      return StreamBuilder<UsersRecord>(
        stream: UsersRecord.getDocument(chat.lastMessageSent!),
        builder: (context, snapshot) {
          String prefix = '';
          if (snapshot.hasData && snapshot.data != null) {
            final senderName = snapshot.data!.displayName;
            // Get first name only for cleaner display
            final firstName = senderName.isNotEmpty
                ? senderName.split(' ').first
                : (snapshot.data!.email.split('@').first);
            // Check if it's the current user
            if (chat.lastMessageSent == currentUserReference) {
              prefix = 'You: ';
            } else {
              prefix = '$firstName: ';
            }
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            // Show message without prefix while loading
            return Text(
              stripMarkdownFormatting(chat.lastMessage),
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                color: Color(0xFF8E8E93),
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          }

          return Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: prefix,
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    color: Color(0xFF8E8E93),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: stripMarkdownFormatting(chat.lastMessage),
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    color: Color(0xFF8E8E93),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
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

    // For non-iOS or when lastMessageSent is not available, show message only
    return Text(
      stripMarkdownFormatting(chat.lastMessage),
      style: TextStyle(
        fontFamily: 'SF Pro Text',
        color: Color(0xFF8E8E93),
        fontSize: 15,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Full-screen chat page that covers the entire screen including tab bar
/// Used when opening a chat from the chat list (like WhatsApp behavior)
class _FullScreenChatPage extends StatefulWidget {
  final ChatsRecord chat;
  final Function(MessagesRecord, Offset?, ChatThreadComponentWidgetState?,
      {bool clearSelection})? onMessageLongPress;
  final VoidCallback? onHideMenu;
  final ValueNotifier<String?>? activeSelectionId;
  final bool shouldPopTwice;
  final VoidCallback? onPop;
  final Function(String, MessagesRecord)? onMessageAction;
  final bool isSelectionMode;
  final Set<MessagesRecord>? selectedMessages;
  final Function(MessagesRecord)? onMessageToggled;
  final VoidCallback? onExitSelectionMode;

  const _FullScreenChatPage({
    Key? key,
    required this.chat,
    this.onMessageLongPress,
    this.onHideMenu,
    this.activeSelectionId,
    this.shouldPopTwice = false,
    this.onPop,
    this.onMessageAction,
    this.isSelectionMode = false,
    this.selectedMessages,
    this.onMessageToggled,
    this.onExitSelectionMode,
  }) : super(key: key);

  @override
  State<_FullScreenChatPage> createState() => _FullScreenChatPageState();
}

class _FullScreenChatPageState extends State<_FullScreenChatPage> {
  final GlobalKey<ChatThreadComponentWidgetState> chatThreadComponentKey =
      GlobalKey<ChatThreadComponentWidgetState>();

  late bool _localIsSelectionMode;
  late Set<MessagesRecord> _localSelectedMessages;

  @override
  void initState() {
    super.initState();
    _localIsSelectionMode = widget.isSelectionMode;
    _localSelectedMessages = Set.from(widget.selectedMessages ?? {});
  }

  @override
  void didUpdateWidget(covariant _FullScreenChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync when parent exits selection mode
    if (!widget.isSelectionMode && _localIsSelectionMode) {
      _localIsSelectionMode = false;
      _localSelectedMessages.clear();
    }
  }

  /// Public method to enter selection mode from outside (e.g. media toolbar)
  void triggerSelect(MessagesRecord message) {
    setState(() {
      _localIsSelectionMode = true;
      _localSelectedMessages.add(message);
    });
  }

  void _handleLocalMessageAction(String action, MessagesRecord message) {
    if (action == 'select') {
      setState(() {
        _localIsSelectionMode = true;
        _localSelectedMessages.add(message);
      });
    }
    widget.onMessageAction?.call(action, message);
  }

  void _handleLocalMessageToggled(MessagesRecord message) {
    setState(() {
      if (_localSelectedMessages.contains(message)) {
        _localSelectedMessages.remove(message);
      } else {
        _localSelectedMessages.add(message);
      }
    });
    widget.onMessageToggled?.call(message);
  }

  @override
  Widget build(BuildContext context) {
    // Ensure we have a valid context
    if (!mounted) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: Color(0xFFF2F2F7),
      body: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // Dismiss menu only at the START of a manual drag gesture.
            // This prevents lag during the scroll and ensures handles can autoscroll without dismissal.
            if (notification is ScrollStartNotification &&
                notification.dragDetails != null) {
              widget.onHideMenu?.call();
            }
            return false;
          },
          child: Stack(
            children: [
              Container(
                child: Column(
                  children: [
                    // Live Meeting Banner (only for group chats)
                    if (widget.chat.isGroup)
                      MeetingBannerWidget(chat: widget.chat),
                    // Pinned Announcement Banner (only for group chats)
                    if (widget.chat.isGroup)
                      _buildAnnouncementBanner(widget.chat),
                    // Action Items Stats - disabled
                    // if (widget.chat.isGroup)
                    //   _buildMobileActionItemsStats(widget.chat),
                    Expanded(
                      child: ChatThreadComponentWidget(
                        key: chatThreadComponentKey,
                        chatReference: widget.chat,
                        onMessageLongPress: widget.onMessageLongPress,
                        onMessageAction: _handleLocalMessageAction,
                        activeSelectionId: widget.activeSelectionId,
                        isSelectionMode: _localIsSelectionMode,
                        selectedMessages: _localSelectedMessages,
                        onMessageToggled: _handleLocalMessageToggled,
                      ),
                    ),
                  ],
                ),
              ),
              if (_localIsSelectionMode)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: EdgeInsets.only(
                          top: 15,
                          bottom: MediaQuery.of(context).padding.bottom + 10,
                          left: 20,
                          right: 20,
                        ),
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1C1C1E).withOpacity(0.85)
                            : Colors.white.withOpacity(0.85),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _localIsSelectionMode = false;
                                  _localSelectedMessages.clear();
                                });
                                widget.onExitSelectionMode?.call();
                                if (widget.onHideMenu != null) {
                                  widget.onHideMenu!(/* clearSelection: true */);
                                }
                              },
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Text',
                                  fontSize: 17,
                                  color: Color(0xFF007AFF),
                                ),
                              ),
                            ),
                            Text(
                              '${_localSelectedMessages.length} Selected',
                              style: TextStyle(
                                fontFamily: 'SF Pro Text',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            TextButton(
                              onPressed: (_localSelectedMessages.isEmpty)
                                  ? null
                                  : () async {
                                      if (_localSelectedMessages.length == 1) {
                                        // Auto-proceed to forward one-by-one logic
                                        await _runForwardLogic(context, _localSelectedMessages.toList(), isCombined: false);
                                      } else {
                                        // Show action sheet
                                        final action = await showModalBottomSheet<String>(
                                          context: context,
                                          backgroundColor: Colors.transparent,
                                          builder: (BuildContext ctx) => Container(
                                            margin: const EdgeInsets.fromLTRB(10, 0, 10, 34),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Options card
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.95),
                                                    borderRadius: BorderRadius.circular(14),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      // Title
                                                      Padding(
                                                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                                                        child: Text(
                                                          'Forward ${_localSelectedMessages.length} Messages',
                                                          style: const TextStyle(
                                                            fontFamily: 'SF Pro Text',
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w500,
                                                            color: Color(0xFF8E8E93),
                                                            decoration: TextDecoration.none,
                                                          ),
                                                        ),
                                                      ),
                                                      const Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E5EA)),
                                                      // Combine option
                                                      Material(
                                                        color: Colors.transparent,
                                                        child: InkWell(
                                                          onTap: () => Navigator.pop(ctx, 'combine'),
                                                          child: Container(
                                                            width: double.infinity,
                                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                                            child: Column(
                                                              children: const [
                                                                Text(
                                                                  'Combine & Forward',
                                                                  style: TextStyle(
                                                                    fontFamily: 'SF Pro Text',
                                                                    fontSize: 17,
                                                                    fontWeight: FontWeight.w400,
                                                                    color: Color(0xFF007AFF),
                                                                    decoration: TextDecoration.none,
                                                                  ),
                                                                ),
                                                                SizedBox(height: 2),
                                                                Text(
                                                                  'Send as a single chat history',
                                                                  style: TextStyle(
                                                                    fontFamily: 'SF Pro Text',
                                                                    fontSize: 12,
                                                                    color: Color(0xFF8E8E93),
                                                                    decoration: TextDecoration.none,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E5EA)),
                                                      // Forward one-by-one option
                                                      Material(
                                                        color: Colors.transparent,
                                                        child: InkWell(
                                                          onTap: () => Navigator.pop(ctx, 'one_by_one'),
                                                          child: Container(
                                                            width: double.infinity,
                                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                                            child: Column(
                                                              children: const [
                                                                Text(
                                                                  'Forward Individually',
                                                                  style: TextStyle(
                                                                    fontFamily: 'SF Pro Text',
                                                                    fontSize: 17,
                                                                    fontWeight: FontWeight.w400,
                                                                    color: Color(0xFF007AFF),
                                                                    decoration: TextDecoration.none,
                                                                  ),
                                                                ),
                                                                SizedBox(height: 2),
                                                                Text(
                                                                  'Send each message separately',
                                                                  style: TextStyle(
                                                                    fontFamily: 'SF Pro Text',
                                                                    fontSize: 12,
                                                                    color: Color(0xFF8E8E93),
                                                                    decoration: TextDecoration.none,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                // Cancel button
                                                Container(
                                                  width: double.infinity,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.95),
                                                    borderRadius: BorderRadius.circular(14),
                                                  ),
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      borderRadius: BorderRadius.circular(14),
                                                      onTap: () => Navigator.pop(ctx, 'cancel'),
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                                        child: const Text(
                                                          'Cancel',
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(
                                                            fontFamily: 'SF Pro Text',
                                                            fontSize: 17,
                                                            fontWeight: FontWeight.w600,
                                                            color: Color(0xFF007AFF),
                                                            decoration: TextDecoration.none,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                        
                                        if (action == 'combine') {
                                          await _runForwardLogic(context, _localSelectedMessages.toList(), isCombined: true);
                                        } else if (action == 'one_by_one') {
                                          await _runForwardLogic(context, _localSelectedMessages.toList(), isCombined: false);
                                        } else {
                                          // Cancelled or barrier dismissed
                                          if (mounted) {
                                            setState(() {
                                              _localIsSelectionMode = false;
                                              _localSelectedMessages.clear();
                                            });
                                            widget.onExitSelectionMode?.call();
                                          }
                                        }
                                      }
                                    },
                              child: Text(
                                'Forward',
                                style: TextStyle(
                                    fontFamily: 'SF Pro Text',
                                  fontSize: 17,
                                  color: (_localSelectedMessages.isEmpty)
                                      ? Colors.grey
                                      : const Color(0xFF007AFF),
                                ),
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
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final chat = widget.chat;

    // Minimal header - just bubble height, shifted up
    const double bubbleHeight = 45;

    return PreferredSize(
      preferredSize:
          Size.fromHeight(bubbleHeight + 50), // Account for the offset
      child: Stack(
        children: [
          // Spacer to push content down
          SizedBox(height: bubbleHeight + 50),
          // Positioned header
          Positioned(
            top: 50, // Shift downward
            left: 0,
            right: 0,
            height: bubbleHeight,
            child: Container(
              height: bubbleHeight,
              color: Colors.transparent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 8),
                  // Back button - using AdaptiveFloatingActionButton with liquid glass effects
                  LiquidStretch(
                    stretch: 0.5,
                    interactionScale: 1.05,
                    child: GlassGlow(
                      glowColor: Colors.white24,
                      glowRadius: 1.0,
                      child: AdaptiveFloatingActionButton(
                        onPressed: () {
                          print(
                              '🔙 Back button clicked! shouldPopTwice: ${widget.shouldPopTwice}');
                          if (widget.shouldPopTwice) {
                            widget.onHideMenu
                                ?.call(); // Hide any active menu bar
                            // Pop the full-screen chat (pushed with rootNavigator: true)
                            if (Navigator.of(context, rootNavigator: true)
                                .canPop()) {
                              Navigator.of(context, rootNavigator: true).pop();
                              print('✅ Popped full-screen chat');
                            }
                            // Then pop MobileChatWidget and New Chat page using root context
                            // Use addPostFrameCallback to ensure the first pop completes
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              final rootContext =
                                  nav.appNavigatorKey.currentContext;
                              if (rootContext != null) {
                                final navigator = Navigator.of(rootContext);
                                // Pop MobileChatWidget (the one pushed from New Chat)
                                if (navigator.canPop()) {
                                  navigator.pop();
                                  print('✅ Popped MobileChatWidget');
                                }
                                // Pop New Chat page after a frame
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (navigator.canPop()) {
                                    navigator.pop();
                                    print('✅ Popped New Chat page');
                                  }
                                });
                              } else {
                                print('❌ Root context is null');
                              }
                            });
                          } else {
                            // Clear selected chat before popping
                            widget.onPop?.call();
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          }
                        },
                        mini: true,
                        backgroundColor: Colors.white,
                        foregroundColor: CupertinoColors.systemBlue,
                        child: Icon(
                          CupertinoIcons.chevron_left,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  // Centered title - tappable to view profile
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _navigateToProfile(chat),
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Avatar
                              _buildAvatar(chat),
                              SizedBox(width: 6),
                              // Name - show other user's name for DMs
                              Flexible(
                                child: chat.isGroup
                                    ? Text(
                                        chat.title.isNotEmpty
                                            ? chat.title
                                            : 'Group Chat',
                                        style: TextStyle(
                                          fontFamily: 'SF Pro Display',
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: CupertinoColors.label,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : FutureBuilder<UsersRecord>(
                                        future: _getOtherUser(chat),
                                        builder: (context, snapshot) {
                                          String displayName = 'Chat';
                                          if (snapshot.hasData) {
                                            final user = snapshot.data!;
                                            displayName =
                                                user.displayName.isNotEmpty
                                                    ? user.displayName
                                                    : 'Chat';
                                          }
                                          return Text(
                                            displayName,
                                            style: TextStyle(
                                              fontFamily: 'SF Pro Display',
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                              color: CupertinoColors.label,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  // More options button - iOS native adaptive popup menu
                  AdaptivePopupMenuButton.widget<String>(
                    items: chat.isGroup
                        ? [
                            // Group chat options
                            if (ChatHelpers.isGroupAdmin(chat, currentUserReference))
                              AdaptivePopupMenuItem(
                                label: 'Add Members',
                                icon: PlatformInfo.isIOS26OrHigher()
                                    ? 'person.badge.plus'
                                    : Icons.person_add,
                                value: 'add_members',
                              ),
                            AdaptivePopupMenuItem(
                              label: 'Media',
                              icon: PlatformInfo.isIOS26OrHigher()
                                  ? 'photo.on.rectangle'
                                  : Icons.photo_library,
                              value: 'media',
                            ),
                            AdaptivePopupMenuItem(
                              label: 'Tasks',
                              icon: PlatformInfo.isIOS26OrHigher()
                                  ? 'checklist'
                                  : Icons.checklist,
                              value: 'tasks',
                            ),
                            AdaptivePopupMenuItem(
                              label: 'Group Info',
                              icon: PlatformInfo.isIOS26OrHigher()
                                  ? 'info.circle'
                                  : Icons.info_outline,
                              value: 'group_info',
                            ),
                            AdaptivePopupMenuItem(
                              label: 'Search History',
                              icon: PlatformInfo.isIOS26OrHigher()
                                  ? 'magnifyingglass'
                                  : Icons.search,
                              value: 'search',
                            ),
                            AdaptivePopupMenuItem(
                              label: 'Announcements',
                              icon: PlatformInfo.isIOS26OrHigher()
                                  ? 'megaphone.fill'
                                  : Icons.campaign_rounded,
                              value: 'announcements',
                            ),
                            AdaptivePopupMenuItem(
                              label: 'Pinned Messages',
                              icon: PlatformInfo.isIOS26OrHigher()
                                  ? 'pin.fill'
                                  : Icons.push_pin_outlined,
                              value: 'pinned_messages',
                            ),
                            AdaptivePopupMenuItem(
                              label: 'Group Files',
                              icon: PlatformInfo.isIOS26OrHigher()
                                  ? 'folder.fill'
                                  : Icons.folder_outlined,
                              value: 'group_files',
                            ),
                            AdaptivePopupMenuItem(
                              label: 'Start Google Meet',
                              icon: PlatformInfo.isIOS26OrHigher()
                                  ? 'video.fill'
                                  : Icons.videocam_rounded,
                              value: 'google_meet',
                            ),
                          ]
                        : [
                            // Direct message options
                            AdaptivePopupMenuItem(
                              label: 'View User Profile',
                              icon: PlatformInfo.isIOS26OrHigher()
                                  ? 'person.circle'
                                  : Icons.person,
                              value: 'view_profile',
                            ),
                            AdaptivePopupMenuItem(
                              label: 'Search History',
                              icon: PlatformInfo.isIOS26OrHigher()
                                  ? 'magnifyingglass'
                                  : Icons.search,
                              value: 'search',
                            ),
                            AdaptivePopupMenuItem(
                              label: 'Block User',
                              icon: PlatformInfo.isIOS26OrHigher()
                                  ? 'hand.raised.fill'
                                  : Icons.block,
                              value: 'block_user',
                            ),
                          ],
                    onSelected: (index, item) {
                      print('🔵 Menu item selected: ${item.value}');
                      if (Platform.isIOS) {
                        HapticFeedback.selectionClick();
                      }
                      if (item.value == 'view_profile') {
                        _navigateToProfile(chat);
                      } else if (item.value == 'block_user') {
                        _blockUserFromChat(chat);
                      } else if (item.value == 'add_members') {
                        _navigateToAddMembers(chat);
                      } else if (item.value == 'media') {
                        _navigateToMedia(chat);
                      } else if (item.value == 'tasks') {
                        _navigateToTasks(chat);
                      } else if (item.value == 'group_info') {
                        _navigateToProfile(chat);
                      } else if (item.value == 'search') {
                        _navigateToSearch(chat);
                      } else if (item.value == 'announcements') {
                        _navigateToAnnouncements(chat);
                      } else if (item.value == 'pinned_messages') {
                        _navigateToPinnedMessages(chat);
                      } else if (item.value == 'group_files') {
                        _navigateToGroupFiles(chat);
                      } else if (item.value == 'google_meet') {
                        _showGoogleMeetDialog(chat);
                      }
                    },
                    child: LiquidStretch(
                      stretch: 0.5,
                      interactionScale: 1.05,
                      child: GlassGlow(
                        glowColor: Colors.white24,
                        glowRadius: 1.0,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.ellipsis,
                            size: 22,
                            color: CupertinoColors.systemBlue,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ChatsRecord chat) {
    if (chat.isGroup) {
      // Group avatar
      if (chat.chatImageUrl.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CachedNetworkImage(
            imageUrl: chat.chatImageUrl,
            width: 28,
            height: 28,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                CupertinoIcons.person_2_fill,
                size: 14,
                color: Color(0xFF8E8E93),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                CupertinoIcons.person_2_fill,
                size: 14,
                color: Color(0xFF8E8E93),
              ),
            ),
          ),
        );
      } else {
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Color(0xFFE5E5EA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            CupertinoIcons.person_2_fill,
            size: 14,
            color: Color(0xFF8E8E93),
          ),
        );
      }
    } else {
      // DM - show other user's avatar
      return FutureBuilder<UsersRecord>(
        future: _getOtherUser(chat),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.photoUrl.isNotEmpty) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: snapshot.data!.photoUrl,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    CupertinoIcons.person_fill,
                    size: 14,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    CupertinoIcons.person_fill,
                    size: 14,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ),
            );
          }
          return Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              CupertinoIcons.person_fill,
              size: 14,
              color: Color(0xFF8E8E93),
            ),
          );
        },
      );
    }
  }

  Future<UsersRecord> _getOtherUser(ChatsRecord chat) async {
    final otherUserRef = chat.members.firstWhere(
      (member) => member != currentUserReference,
      orElse: () => chat.members.first,
    );
    return await UsersRecord.getDocumentOnce(otherUserRef);
  }

  void _navigateToProfile(ChatsRecord chat) async {
    if (chat.isGroup) {
      // For group chats, navigate to group details
      // Use Navigator.push instead of GoRouter because _FullScreenChatPage
      // is pushed via rootNavigator and is outside GoRouter's route tree
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GroupChatDetailWidget(chatDoc: chat),
        ),
      );
    } else {
      // For DMs, navigate to new user summary page instead of old profile page
      try {
        final user = await _getOtherUser(chat);
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UserSummaryWidget(userRef: user.reference),
            ),
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
  }

  void _blockUserFromChat(ChatsRecord chat) async {
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
                fontWeight: FontWeight.normal,
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
                    fontWeight: FontWeight.normal,
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

        // Navigate back to chat list
        Navigator.of(context).pop();
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

  void _navigateToAddMembers(ChatsRecord chat) {
    if (!chat.isGroup) return;
    // Navigate to dedicated Add Members page
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddGroupMembersWidget(chatDoc: chat),
      ),
    );
  }

  void _navigateToMedia(ChatsRecord chat) {
    if (!chat.isGroup) return;
    widget.onHideMenu
        ?.call(); // Fix: Use callback to hide bar when navigating away
    // Use Navigator.push instead of GoRouter because _FullScreenChatPage
    // is pushed via rootNavigator and is outside GoRouter's route tree
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MobileGroupMediaWidget(chatDoc: chat),
      ),
    );
  }

  void _navigateToTasks(ChatsRecord chat) {
    if (!chat.isGroup) return;
    widget.onHideMenu
        ?.call(); // Fix: Use callback to hide bar when navigating away
    // Use Navigator.push instead of GoRouter because _FullScreenChatPage
    // is pushed via rootNavigator and is outside GoRouter's route tree
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MobileGroupTasksWidget(chatDoc: chat),
      ),
    );
  }

  void _navigateToAnnouncements(ChatsRecord chat) {
    if (!chat.isGroup) return;
    widget.onHideMenu?.call();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: GroupAnnouncementsWidget(
              chatDoc: chat,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }

  /// Action Items Stats bar for mobile — compact summary with overdue/pending counts.
  Widget _buildMobileActionItemsStats(ChatsRecord chat) {
    return StreamBuilder<List<ActionItemsRecord>>(
      stream: queryActionItemsRecord(
        queryBuilder: (actionItemsRecord) => actionItemsRecord.where(
          'chat_ref',
          isEqualTo: chat.reference,
        ),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();

        final allActionItems = snapshot.data ?? [];

        // Deduplicate and exclude completed
        final Map<String, ActionItemsRecord> uniqueTodos = {};
        for (var todo in allActionItems) {
          if (todo.status == 'completed') continue;
          if (!uniqueTodos.containsKey(todo.title)) {
            uniqueTodos[todo.title] = todo;
          }
        }
        final pendingItems = uniqueTodos.values.toList();
        if (pendingItems.isEmpty) return SizedBox.shrink();

        final now = DateTime.now();
        final overdueCount = pendingItems.where((item) {
          final due = item.dueDate;
          return due != null && due.isBefore(now);
        }).length;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => MobileGroupTasksWidget(chatDoc: chat),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.task_alt_rounded,
                  size: 18,
                  color: Color(0xFF3B82F6),
                ),
                SizedBox(width: 8),
                Text(
                  'Action Items',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                Spacer(),
                if (overdueCount > 0) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$overdueCount overdue',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                ],
                Text(
                  '${pendingItems.length} pending',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnnouncementBanner(ChatsRecord chat) {
    return StreamBuilder<List<AnnouncementsRecord>>(
      stream: queryAnnouncementsRecord(
        parent: chat.reference,
        queryBuilder: (q) => q
            .where('is_pinned', isEqualTo: true)
            .limit(1),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final ann = snapshot.data!.first;
        final isConfirmed = currentUserReference != null &&
            ann.confirmedBy.contains(currentUserReference);

        // Hide banner once the user has confirmed
        if (isConfirmed) return const SizedBox.shrink();

        final memberCount = chat.members.length;
        final confirmedCount = ann.confirmedBy.length;

        return GestureDetector(
          onTap: () => _navigateToAnnouncements(chat),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.06),
              border: const Border(
                bottom: BorderSide(
                  color: Color(0xFFD1D1D6),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(CupertinoIcons.speaker_2_fill,
                      color: Color(0xFF007AFF), size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ann.content.length > 60
                            ? '${ann.content.substring(0, 60)}...'
                            : ann.content,
                        style: const TextStyle(
                          fontFamily: 'SF Pro Display',
                          color: Color(0xFF1C1C1E),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$confirmedCount/$memberCount confirmed',
                        style: const TextStyle(
                          fontFamily: 'SF Pro Display',
                          color: Color(0xFF8E8E93),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    if (currentUserReference == null) return;
                    HapticFeedback.mediumImpact();
                    await ann.reference.update({
                      'confirmed_by':
                          FieldValue.arrayUnion([currentUserReference]),
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToSearch(ChatsRecord chat) {
    widget.onHideMenu?.call();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatHistoryWidget(
          chatDoc: chat,
          showAppBar: true,
          onMessageSelected: (messageId) {
            Navigator.pop(context); // Close search screen
            // Use postFrameCallback to ensure chat thread is ready
            WidgetsBinding.instance.addPostFrameCallback((_) {
              chatThreadComponentKey.currentState?.scrollToMessage(messageId);
            });
          },
        ),
      ),
    );
  }

  void _navigateToPinnedMessages(ChatsRecord chat) {
    widget.onHideMenu?.call();
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => MobilePinnedMessagesWidget(
          chatDoc: chat,
          onMessageTap: (messageId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              chatThreadComponentKey.currentState?.scrollToMessage(messageId);
            });
          },
        ),
      ),
    );
  }

  void _navigateToGroupFiles(ChatsRecord chat) {
    widget.onHideMenu?.call();
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => MobileGroupFilesWidget(chatDoc: chat),
      ),
    );
  }

  void _showGoogleMeetDialog(ChatsRecord chat) {
    widget.onHideMenu?.call();
    final controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_rounded, size: 22, color: Color(0xFF3B82F6)),
            SizedBox(width: 8),
            Text('Google Meet'),
          ],
        ),
        content: Column(
          children: [
            SizedBox(height: 12),
            Text(
              'Create a new meeting or paste an existing link to share with the group.',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 12),
            CupertinoButton(
              padding: EdgeInsets.symmetric(vertical: 8),
              onPressed: () async {
                final uri = Uri.parse('https://meet.google.com/new');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.arrow_up_right_square, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Open Google Meet',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            CupertinoTextField(
              controller: controller,
              placeholder: 'https://meet.google.com/...',
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: false,
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text('Share Link'),
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isNotEmpty && url.contains('meet.google.com')) {
                Navigator.pop(ctx);
                // Send meet link as a message
                final messageRef = chat.reference.collection('messages').doc();
                await messageRef.set({
                  'message': '📹 Google Meet: $url\n\nJoin the meeting: $url',
                  'sender_ref': currentUserReference,
                  'sender_name': currentUserDisplayName,
                  'sender_photo': currentUserPhoto,
                  'created_at': FieldValue.serverTimestamp(),
                  'is_system_message': false,
                });
                // Update chat's last message
                await chat.reference.update({
                  'last_message': '📹 Google Meet link shared',
                  'last_message_sent': currentUserReference,
                  'last_message_at': FieldValue.serverTimestamp(),
                  'last_message_seen': [currentUserReference],
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Meet link shared'),
                      backgroundColor: Color(0xFF34C759),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _runForwardLogic(BuildContext context, List<MessagesRecord> messagesToForward, {required bool isCombined}) async {
    final selectedChat = await showDialog<ChatsRecord>(
      context: context,
      builder: (context) => const ForwardChatPickerDialog(),
    );

    if (selectedChat == null) {
      if (mounted) {
        setState(() {
          _localIsSelectionMode = false;
          _localSelectedMessages.clear();
        });
        widget.onExitSelectionMode?.call();
      }
      return;
    }

    if (currentUserReference != null) {
      try {
        final sortedMessages = messagesToForward.toList()
          ..sort((a, b) {
            if (a.createdAt == null || b.createdAt == null) return 0;
            return a.createdAt!.compareTo(b.createdAt!);
          });

        if (isCombined) {
          // Pre-fetch missing user data for display names and photos
          final userCache = <DocumentReference, UsersRecord>{};
          for (final m in sortedMessages) {
             if (m.senderRef != null && !userCache.containsKey(m.senderRef)) {
                 try {
                   final doc = await UsersRecord.getDocumentOnce(m.senderRef!);
                   userCache[m.senderRef!] = doc;
                 } catch (e) {
                   print('Error fetching user for history payload: $e');
                 }
             }
          }

          // Serialize history
          final historyList = sortedMessages.map((m) {
                final user = m.senderRef != null ? userCache[m.senderRef!] : null;
                final senderName = (m.hasSenderName() && m.senderName.isNotEmpty) ? m.senderName : (user?.displayName ?? 'Unknown');
                final senderPhoto = (m.hasSenderPhoto() && m.senderPhoto.isNotEmpty) ? m.senderPhoto : (user?.photoUrl ?? '');

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

          // Build a single message
          final messageData = createMessagesRecordData(
            senderRef: currentUserReference,
            content: '[Chat History]',
            createdAt: getCurrentTimestamp,
            messageType: MessageType.text,
            isSystemMessage: false,
            isPinned: false,
            forwardedHistory: historyJson,
          );

          await MessagesRecord.createDoc(selectedChat.reference).set(messageData);

          // Update chat preview for combined forward
          await selectedChat.reference.update({
            'last_message': '[Chat History]',
            'last_message_at': getCurrentTimestamp,
            'last_message_sent': currentUserReference,
            'last_message_type': MessageType.text.serialize(),
            'last_message_seen': [currentUserReference],
          });
        } else {
          // Forward one by one
          String lastPreviewText = 'Message';
          for (final message in sortedMessages) {
            final messageData = createMessagesRecordData(
              senderRef: currentUserReference,
              content: message.content,
              createdAt: getCurrentTimestamp,
              messageType: message.messageType,
              image: message.image,
              video: message.video,
              audio: message.audio,
              isSystemMessage: false,
              isPinned: false,
            );

            final firestoreData = messageData;
            if (message.images.isNotEmpty) {
              firestoreData['images'] = message.images;
            }

            await MessagesRecord.createDoc(selectedChat.reference).set(firestoreData);

            // Track the last message's preview text
            lastPreviewText = message.content;
            if (lastPreviewText.isEmpty) {
              if (message.messageType == MessageType.image) lastPreviewText = '📷 Photo';
              else if (message.messageType == MessageType.video) lastPreviewText = '🎥 Video';
              else if (message.messageType == MessageType.file) lastPreviewText = '📎 File';
              else if (message.messageType == MessageType.voice) lastPreviewText = '🎵 Audio';
              else lastPreviewText = 'Message';
            }
          }

          // Update chat preview with the last forwarded message
          await selectedChat.reference.update({
            'last_message': lastPreviewText.length > 100 ? lastPreviewText.substring(0, 100) : lastPreviewText,
            'last_message_at': getCurrentTimestamp,
            'last_message_sent': currentUserReference,
            'last_message_type': sortedMessages.last.messageType?.serialize() ?? MessageType.text.serialize(),
            'last_message_seen': [currentUserReference],
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Forwarded to ${selectedChat.title}'),
              backgroundColor: const Color(0xFF34C759),
            ),
          );
        }
      } catch (e) {
        print('Error forwarding messages: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error forwarding messages: $e'),
              backgroundColor: const Color(0xFFFF3B30),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _localIsSelectionMode = false;
            _localSelectedMessages.clear();
          });
          widget.onExitSelectionMode?.call();
        }
        if (widget.onHideMenu != null) {
          widget.onHideMenu!();
        }
      }
    }
  }
}

// iOS 26+ floating popup menu with glass effect
class _IOS26PopupMenu<T> extends StatelessWidget {
  final RelativeRect position;
  final List<AdaptivePopupMenuItem<T>> items;
  final Function(int index, AdaptivePopupMenuItem<T> item) onSelected;
  final VoidCallback onDismiss;

  const _IOS26PopupMenu({
    required this.position,
    required this.items,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Hide the menu if the page is no longer the top-most route
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onDismiss());
      return const SizedBox.shrink();
    }

    // Exact size calculations to ensure alignment
    final int itemsPerRow = 5;
    final double itemSize = 48.0;
    final double horizontalPadding = 6.0;
    final double verticalPadding = 6.0;

    final int actualItemsInWidestRow =
        items.length < itemsPerRow ? items.length : itemsPerRow;
    final double menuWidth =
        (itemSize * actualItemsInWidestRow) + (horizontalPadding * 2) + 2.0;

    // Use the pre-calculated position from the caller
    final double left = position.left;
    final double top = position.top;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.white.withOpacity(0.95),
            elevation: 2,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: menuWidth,
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: verticalPadding),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.black.withOpacity(0.04),
                  width: 0.5,
                ),
              ),
              child: Wrap(
                spacing: 0,
                runSpacing: 4,
                alignment: WrapAlignment.start,
                children: items.asMap().entries.map((entry) {
                  return _MenuGridItem(
                    item: entry.value,
                    size: itemSize,
                    onTap: () {
                      onDismiss();
                      onSelected(entry.key, entry.value);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuGridItem<T> extends StatelessWidget {
  final AdaptivePopupMenuItem<T> item;
  final double size;
  final VoidCallback onTap;

  const _MenuGridItem({
    required this.item,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDestructive = item.value.toString().contains('report') ||
        item.value.toString().contains('unsend') ||
        item.value.toString().contains('delete');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          print('✅ _MenuGridItem tapped: ${item.value}');
          onTap();
        },
        child: Container(
          width: size,
          height: size,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            // Icon
            if (item.icon is String)
              Icon(
                _getIconForSFSymbol(item.icon as String),
                size: 16,
                color: isDestructive ? Color(0xFFFF3B30) : Color(0xFF1C1C1E),
              )
            else
              Icon(
                item.icon as IconData,
                size: 16,
                color: isDestructive ? Color(0xFFFF3B30) : Color(0xFF1C1C1E),
              ),
            SizedBox(height: 2),
            // Label
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                fontSize: 8.5,
                color: isDestructive
                    ? Color(0xFFFF3B30)
                    : Color(0xFF1C1C1E).withOpacity(0.8),
                fontWeight: FontWeight.w400,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

IconData _getIconForSFSymbol(String symbol) {
  // Map SF Symbols to CupertinoIcons
  final iconMap = {
    'doc.on.doc': CupertinoIcons.doc_on_doc,
    'checkmark.circle': CupertinoIcons.checkmark_circle,
    'face.smiling': CupertinoIcons.smiley,
    'arrowshape.turn.up.left': CupertinoIcons.arrow_turn_up_left,
    'arrowshape.turn.up.right': CupertinoIcons.arrow_turn_up_right,
    'quote.bubble': CupertinoIcons.quote_bubble,
    'star': CupertinoIcons.star,
    'bell': CupertinoIcons.bell,
    'magnifyingglass': CupertinoIcons.search,
    'headphones': CupertinoIcons.headphones,
    'pencil': CupertinoIcons.pencil,
    'arrow.uturn.backward': CupertinoIcons.arrow_counterclockwise,
    'exclamationmark.triangle': CupertinoIcons.exclamationmark_triangle,
    'arrow.down.circle': CupertinoIcons.arrow_down_circle,
    'pin': CupertinoIcons.pin,
    'pin.slash': CupertinoIcons.pin_slash,
    'character.book.closed': CupertinoIcons.book,
    'eye': CupertinoIcons.eye,
    'trash': CupertinoIcons.delete,
    'person.2': CupertinoIcons.group,
    'list.bullet.indent': CupertinoIcons.list_bullet,
  };
  return iconMap[symbol] ?? CupertinoIcons.circle;
}


