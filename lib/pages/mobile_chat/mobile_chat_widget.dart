import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_expanded_image_view.dart';
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
import '/components/chat_filter_buttons.dart';
import '/custom_code/actions/index.dart' as actions;
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_debounce/easy_debounce.dart';
// import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart'; // Removed unused import
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

class MobileChatWidget extends StatefulWidget {
  const MobileChatWidget({
    super.key,
    this.onChatStateChanged,
    this.initialChat,
  });

  static String routeName = 'MobileChat';
  static String routePath = '/mobile-chat';

  final Function(bool isChatOpen)? onChatStateChanged;
  final ChatsRecord? initialChat;

  @override
  _MobileChatWidgetState createState() => _MobileChatWidgetState();
}

class _MobileChatWidgetState extends State<MobileChatWidget>
    with TickerProviderStateMixin {
  late MobileChatModel _model;
  late ChatController chatController;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final animationsMap = <String, AnimationInfo>{};
  double? _dragStartX;

  @override
  void initState() {
    super.initState();
    print('🚀 MobileChatWidget initState called');
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
    _model.dispose();
    // DON'T delete ChatController - keep it persistent across navigation
    // This preserves knownUnreadChats and locallySeenChats state
    // The controller will be cleaned up when app closes
    // Get.delete<ChatController>();
    super.dispose();
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
            child: Container(
              color: Colors.white, // Changed to white for consistent background
              child: RepaintBoundary(
                child: Column(
                  children: [
                    // Fixed header section with Chats title, action buttons, search bar, and filters
                    Container(
                      color: Colors
                          .white,
                      height: 180, // Changed to white for consistent background
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Chats heading in top left
                          Positioned(
                            top: 16,
                            left: 16,
                            child: Text(
                              'Chats',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.label,
                              ),
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
                      ), // Total height for header section
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
        chatReference: _model.selectedChat,
        onMessageLongPress: _showMessageMenu,
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
          chat: chat,
          onMessageLongPress: _showMessageMenu,
          shouldPopTwice:
              widget.initialChat != null, // Pop twice if opened from New Chat
          onPop: () {
            // Clear selected chat when route is popped so the same chat can be opened again
            if (mounted) {
              setState(() {
                _model.selectedChat = null;
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
        decoration: const BoxDecoration(
          color: Color(0xFFF2F2F7), // Match chat screen background exactly
        ),
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 44, // Native iOS toolbar height
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                // Floating back button on the left - iOS 26+ style with liquid glass effects
                AdaptiveFloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.white, // Pure white background
                      foregroundColor: const Color(0xFF007AFF), // System blue icon
                      onPressed: () {
                        print('🔙 MobileChatWidget Back button pressed');
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
                      child: const Icon(
                        CupertinoIcons.chevron_left,
                        size: 17,
                      ),
                    ),
                const SizedBox(width: 8),
                // Centered title in pill shape - native iOS 26 style
                Expanded(
                  child: Center(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          const SizedBox(width: 8),
                          // Group name or user name text
                          Flexible(
                            child: chat.isGroup
                                ? Text(
                                    _getChatDisplayName(chat),
                                    style: const TextStyle(
                                      fontFamily: 'System',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF000000), // Black
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : FutureBuilder<UsersRecord>(
                                    future: UsersRecord.getDocumentOnce(
                                      chat.members.firstWhere(
                                        (member) =>
                                            member != currentUserReference,
                                        orElse: () => chat.members.first,
                                      ),
                                    ),
                                    builder: (context, userSnapshot) {
                                      String displayName = 'Chat';
                                      if (userSnapshot.hasData &&
                                          userSnapshot.data != null) {
                                        final user = userSnapshot.data!;
                                        final otherUserRef =
                                            chat.members.firstWhere(
                                          (member) =>
                                              member != currentUserReference,
                                          orElse: () => chat.members.first,
                                        );
                                        // Check if this is Summer AI agent
                                        if (otherUserRef.path
                                            .contains('ai_agent_summerai')) {
                                          displayName = 'Summer';
                                        } else {
                                          displayName =
                                              user.displayName.isNotEmpty
                                                  ? user.displayName
                                                  : 'Unknown User';
                                        }
                                      }
                                      return Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontFamily: 'System',
                                          fontSize: 19,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF000000), // Black
                                        ),
                                        maxLines: 1,
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
                const SizedBox(width: 8),
                // Settings button on the right - iOS 26+ style with liquid glass effects
                AdaptiveFloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.white, // Pure white like back button
                      foregroundColor: const Color(0xFF007AFF), // System blue icon
                      onPressed: () {
                        print('⚙️ MobileChatWidget Settings button pressed');
                        _showChatOptions(chat);
                      },
                      child: const Icon(
                        CupertinoIcons.ellipsis,
                        size: 17,
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
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
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

  void _showMessageMenu(MessagesRecord message) {
    // Build popup menu items
    final menuItems = <AdaptivePopupMenuItem<String>>[
      AdaptivePopupMenuItem(
        label: 'Copy',
        icon:
            Platform.isIOS ? 'doc.on.doc' : Icons.copy_rounded,
        value: 'copy',
      ),
      AdaptivePopupMenuItem(
        label: 'React',
        icon: Platform.isIOS
            ? 'face.smiling'
            : Icons.emoji_emotions_rounded,
        value: 'react',
      ),
      AdaptivePopupMenuItem(
        label: 'Reply',
        icon: Platform.isIOS
            ? 'arrowshape.turn.up.left'
            : Icons.reply_rounded,
        value: 'reply',
      ),
    ];

    // Only show edit and unsend options for messages sent by current user
    if (message.senderRef == currentUserReference) {
      menuItems.addAll([
        AdaptivePopupMenuItem(
          label: 'Edit',
          icon: Platform.isIOS ? 'pencil' : Icons.edit_rounded,
          value: 'edit',
        ),
        AdaptivePopupMenuItem(
          label: 'Unsend',
          icon: Platform.isIOS
              ? 'arrow.uturn.backward'
              : Icons.undo_rounded,
          value: 'unsend',
        ),
      ]);
    }

    // Add Download option for messages with images
    if ((message.image.isNotEmpty) ||
        (message.images.isNotEmpty)) {
      menuItems.add(
        AdaptivePopupMenuItem(
          label: 'Download',
          icon: Platform.isIOS
              ? 'arrow.down.circle'
              : Icons.download_rounded,
          value: 'download',
        ),
      );
    }

    // Add Translate option for messages with text content
    if (message.content.isNotEmpty) {
      menuItems.add(
        AdaptivePopupMenuItem(
          label: 'Translate',
          icon: Platform.isIOS
              ? 'character.bubble'
              : Icons.translate_rounded,
          value: 'translate',
        ),
      );
    }

    // Add Pin/Unpin option
    final isPinned = message.isPinned;
    menuItems.add(
      AdaptivePopupMenuItem(
        label: isPinned ? 'Unpin' : 'Pin',
        icon: isPinned
            ? (Platform.isIOS ? 'pin.slash' : Icons.push_pin_outlined)
            : (Platform.isIOS ? 'pin' : Icons.push_pin_rounded),
        value: 'pin',
      ),
    );

    // Add Report option (destructive action)
    menuItems.add(
      AdaptivePopupMenuItem(
        label: 'Report',
        icon: Platform.isIOS
            ? 'exclamationmark.triangle'
            : Icons.report_gmailerrorred_rounded,
        value: 'report',
      ),
    );

    // Show floating popup menu at center of screen (iOS 26+ style)
    _showFloatingPopupMenu(
      context: context,
      items: menuItems,
      onSelected: (index, item) {
        switch (item.value) {
          case 'copy':
            _copyMessage(message);
            break;
          case 'react':
            _showEmojiMenu(message);
            break;
          case 'reply':
            _replyToMessage(message);
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
          case 'translate':
            ChatThreadComponentWidgetState.triggerTranslate(message);
            break;
          case 'pin':
            _togglePinMessage(message);
            break;
          case 'report':
            _reportMessage(message);
            break;
        }
      },
    );
  }

  void _showFloatingPopupMenu<T>({
    required BuildContext context,
    required List<AdaptivePopupMenuItem<T>> items,
    required Function(int index, AdaptivePopupMenuItem<T> item) onSelected,
  }) {
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    // Position at center of screen
    final screenSize = MediaQuery.of(context).size;
    final position = RelativeRect.fromSize(
      Rect.fromLTWH(
        screenSize.width / 2 - 150,
        screenSize.height / 2 - 100,
        300,
        200,
      ),
      overlay.size,
    );

    // Use showGeneralDialog for iOS 26+ glass effect, showMenu for older versions
    if (Platform.isIOS) {
      showGeneralDialog<T>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.3),
        barrierDismissible: true,
        barrierLabel: 'Dismiss menu',
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _IOS26PopupMenu<T>(
            position: position,
            items: items,
            onSelected: (index, item) {
              Navigator.of(context).pop();
              onSelected(index, item);
            },
          );
        },
      );
    } else {
      showMenu<T>(
        context: context,
        position: position,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.white,
        elevation: 8,
        items: items.map((item) {
          final isDestructive = item.value.toString().contains('report') ||
              item.value.toString().contains('unsend');
          final textColor =
              isDestructive ? const Color(0xFFFF3B30) : CupertinoColors.label;

          return PopupMenuItem<T>(
            value: item.value,
            child: Row(
              children: [
                Icon(
                  item.icon as IconData,
                  size: 20,
                  color: textColor,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 17,
                    color: textColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ).then((value) {
        if (value != null) {
          final index = items.indexWhere((item) => item.value == value);
          if (index != -1) {
            onSelected(index, items[index]);
          }
        }
      });
    }
  }

  Widget _buildIOS26ActionSheet(List<CupertinoActionSheetAction> actions) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              // Actions - extract and render properly
              ...actions.map((action) => _buildIOS26ActionButton(action)),
              const SizedBox(height: 8),
              // Cancel button
              _buildIOS26CancelButton(),
              const SizedBox(height: 20),
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
        const SizedBox(width: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: () => Navigator.pop(context),
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        child: const Text(
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

  void _handleMenuAction(MessagesRecord message, String action) {
    switch (action) {
      case 'copy':
        _copyMessage(message);
        break;
      case 'react':
        _showEmojiMenu(message);
        break;
      case 'reply':
        _replyToMessage(message);
        break;
      case 'edit':
        _editMessage(message);
        break;
      case 'unsend':
        _unsendMessage(message);
        break;
      case 'pin':
        _togglePinMessage(message);
        break;
      case 'translate':
        ChatThreadComponentWidgetState.triggerTranslate(message);
        break;
      case 'download':
        _downloadImage(message);
        break;
      case 'report':
        _reportMessage(message);
        break;
    }
  }

  Widget _buildAdaptiveMenuOption({
    required AdaptivePopupMenuItem<String> item,
    required VoidCallback onTap,
  }) {
    final isDestructive = item.value == 'report' || item.value == 'unsend';
    final textColor = isDestructive ? const Color(0xFFFF3B30) : const Color(0xFF1D1D1F);
    final iconColor = isDestructive ? const Color(0xFFFF3B30) : const Color(0xFF1D1D1F);

    // Get the appropriate icon
    Widget iconWidget;
    if (Platform.isIOS && item.icon is String) {
      // Use SF Symbol name - for now use CupertinoIcons as fallback
      // In a real implementation, you'd use a package that supports SF Symbols
      iconWidget = Icon(
        _getIconForSFSymbol(item.icon as String),
        color: iconColor,
        size: 24,
      );
    } else {
      iconWidget = Icon(
        item.icon as IconData,
        color: iconColor,
        size: 24,
      );
    }

    return ListTile(
      leading: iconWidget,
      title: Text(
        item.label,
        style: TextStyle(
          fontFamily: 'SF Pro Display',
          color: textColor,
          fontSize: 17,
          fontWeight: FontWeight.w400,
        ),
      ),
      onTap: onTap,
    );
  }

  IconData _getIconForSFSymbol(String sfSymbol) {
    // Map SF Symbols to CupertinoIcons
    final iconMap = {
      'doc.on.doc': CupertinoIcons.doc_on_doc,
      'face.smiling': CupertinoIcons.smiley,
      'arrowshape.turn.up.left': CupertinoIcons.arrow_turn_up_left,
      'pencil': CupertinoIcons.pencil,
      'arrow.uturn.backward': CupertinoIcons.arrow_counterclockwise,
      'exclamationmark.triangle': CupertinoIcons.exclamationmark_triangle,
      'arrow.down.circle': CupertinoIcons.arrow_down_circle,
      'pin': CupertinoIcons.pin,
      'pin.slash': CupertinoIcons.pin_slash,
      'character.bubble': Icons.translate_rounded,
    };
    return iconMap[sfSymbol] ?? CupertinoIcons.circle;
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
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
            backgroundColor: const Color(0xFFFF3B30),
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
              backgroundColor: const Color(0xFFFF3B30),
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
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    }
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
        color: iconColor ?? const Color(0xFF1D1D1F),
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'System',
          color: titleColor ?? const Color(0xFF1D1D1F),
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
      const SnackBar(
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
        const SnackBar(
          content: Text('Reaction added'),
          duration: Duration(milliseconds: 1000),
          backgroundColor: Color(0xFF34C759),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
          title: const Text(
            'Report Message',
            style: TextStyle(
              fontFamily: 'System',
              color: Color(0xFF1D1D1F),
              fontSize: 17,
              fontWeight: FontWeight.normal,
            ),
          ),
          content: const Text(
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
              child: const Text(
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
              child: const Text(
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
            duration: const Duration(milliseconds: 2000),
            backgroundColor: isPinned ? const Color(0xFF1D1D1F) : const Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating pin status: $e'),
            backgroundColor: const Color(0xFFFF3B30),
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
        decoration: const BoxDecoration(
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
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              // Reply preview
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
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
                      style: const TextStyle(
                        fontFamily: 'System',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.content,
                      style: const TextStyle(
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
              const SizedBox(height: 16),
              // Message input
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: replyController,
                  decoration: InputDecoration(
                    hintText: 'Type your reply...',
                    hintStyle: const TextStyle(
                      fontFamily: 'System',
                      color: Color(0xFF8E8E93),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF007AFF)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
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
              const SizedBox(height: 16),
              // Send button
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
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
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Send Reply',
                    style: TextStyle(
                      fontFamily: 'System',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
          const SnackBar(
            content: Text('Unable to send reply: chat not selected'),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
        return;
      }

      if (userRef == null) {
        print('❌ Error: currentUserReference is null');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
    }
  }

  Future<void> _editMessage(MessagesRecord message) async {
    // Check if the message was sent by the current user
    if (message.senderRef != currentUserReference) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
    final TextEditingController editController =
        TextEditingController(text: message.content);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
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
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              // Edit header
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: const Text(
                  'Edit Message',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Message input
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: editController,
                  decoration: InputDecoration(
                    hintText: 'Edit your message...',
                    hintStyle: const TextStyle(
                      fontFamily: 'System',
                      color: Color(0xFF8E8E93),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF007AFF)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 4,
                  minLines: 1,
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty) {
                      _updateMessage(message, text.trim());
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 16, right: 8),
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
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
                      margin: const EdgeInsets.only(left: 8, right: 16),
                      child: ElevatedButton(
                        onPressed: () {
                          if (editController.text.trim().isNotEmpty) {
                            _updateMessage(message, editController.text.trim());
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateMessage(MessagesRecord message, String newContent) async {
    try {
      // Update the message content
      await message.reference.update({
        'content': newContent,
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
        const SnackBar(
          content: Text('Message updated'),
          duration: Duration(milliseconds: 1000),
          backgroundColor: Color(0xFF34C759),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update message: $e'),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
    }
  }

  Future<void> _unsendMessage(MessagesRecord message) async {
    // Check if the message was sent by the current user
    if (message.senderRef != currentUserReference) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
        title: const Text(
          'Unsend Message',
          style: TextStyle(
            fontFamily: 'System',
            color: Color(0xFF1D1D1F),
            fontSize: 17,
            fontWeight: FontWeight.normal,
          ),
        ),
        content: const Text(
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
            child: const Text(
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
            child: const Text(
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
              style: const TextStyle(
                fontFamily: 'System',
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            duration: const Duration(milliseconds: 2000),
            backgroundColor: const Color(0xFFFF3B30),
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
                const Duration(milliseconds: 500),
                () => chatController.updateSearchQuery(value),
              );
            },
            placeholder: 'Search',
            placeholderStyle: const TextStyle(
              fontFamily: 'SF Pro Text',
              color: CupertinoColors.systemGrey,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            prefix: const Padding(
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
                      padding: const EdgeInsets.only(right: 12),
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
                                    CupertinoColors.systemGrey.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.clear_circled_solid,
                                color: CupertinoColors.systemGrey,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            }),
            style: const TextStyle(
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
  Widget _wrapWithGlassEffect(Widget child) {
    return LiquidStretch(
      stretch: 0.5,
      interactionScale: 1.05,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: 15, sigmaY: 15), // Increased blur for better glass effect
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(
                  0.85), // Slightly more transparent for glass effect
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.6), // Glassy white border
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withOpacity(0.05), // Subtle shadow for depth
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // + button - liquid glass background with system blue icon
        AdaptivePopupMenuButton.widget<String>(
          items: [
            AdaptivePopupMenuItem(
              label: 'New Chat',
              icon: Platform.isIOS
                  ? 'message'
                  : Icons.chat_bubble_outline,
              value: 'new_chat',
            ),
            AdaptivePopupMenuItem(
              label: 'New Group Chat',
              icon:
                  Platform.isIOS ? 'person.2' : Icons.group_add,
              value: 'new_group_chat',
            ),
          ],
          onSelected: (index, item) {
            if (item.value == 'new_chat') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MobileNewChatWidget(),
                ),
              );
            } else if (item.value == 'new_group_chat') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MobileNewGroupChatWidget(),
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
                child: const Icon(
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
        child: _buildChatListContentInner(),
      );
    });
  }

  Widget _buildChatListContentInner() {
    return Obx(() {
      switch (chatController.chatState.value) {
        case ChatState.loading:
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF007AFF),
            ),
          );

        case ChatState.error:
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFFF3B30),
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Error loading chats',
                  style: TextStyle(
                    fontFamily: 'System',
                    color: Color(0xFF1D1D1F),
                    fontSize: 17,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  chatController.errorMessage.value,
                  style: const TextStyle(
                    fontFamily: 'System',
                    color: Color(0xFF8E8E93),
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => chatController.refreshChats(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
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
            return const Center(
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
                      fontWeight: FontWeight.normal,
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

          // Show empty state message for new users when chat list is empty
          if (filteredChats.isEmpty &&
              chatController.searchQuery.value.isEmpty) {
            return Transform.translate(
              offset: const Offset(0, -40),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon with circular background
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.person_2_fill,
                          color: CupertinoColors.systemBlue,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Header title
                      const Text(
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
                      const SizedBox(height: 12),
                      // Subtitle message
                      const Text(
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

          return ListView.builder(
            key: ValueKey(
                'chat_list_items_${_model.tabController?.index ?? 0}_${filteredChats.length}_${chatController.searchQuery.value}'),
            padding: const EdgeInsets.only(top: 4, left: 0, right: 0, bottom: 100),
            itemCount: filteredChats.length,
            physics: const ClampingScrollPhysics(),
            primary: false,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                        return const SizedBox.shrink();
                      }
                    }

                    return Obx(() {
                      // Make hasUnreadMessages reactive by accessing observables
                      final _ = chatController.chats.length;
                      final __ = chatController.locallySeenChats.length;
                      final hasUnread = chatController.hasUnreadMessages(chat);
                      return _MobileChatListItem(
                        key: ValueKey('chat_item_${chat.reference.id}'),
                        chat: chat,
                        isSelected: isSelected,
                        onTap: () {
                          // Prevent multiple rapid taps
                          if (_model.selectedChat?.reference ==
                              chat.reference) {
                            return;
                          }
                          // Update controller
                          chatController.selectChat(chat);
                          // Push full-screen chat route (covers tab bar like WhatsApp)
                          _openChatFullScreen(chat);
                        },
                        hasUnreadMessages: hasUnread,
                      );
                    });
                  },
                );
              }

              return Obx(() {
                // Make hasUnreadMessages reactive by accessing observables
                final _ = chatController.chats.length;
                final __ = chatController.locallySeenChats.length;
                final hasUnread = chatController.hasUnreadMessages(chat);
                return _MobileChatListItem(
                  key: ValueKey('chat_item_${chat.reference.id}'),
                  chat: chat,
                  isSelected: isSelected,
                  onTap: () {
                    // Prevent multiple rapid taps
                    if (_model.selectedChat?.reference == chat.reference) {
                      return;
                    }
                    // Update controller
                    chatController.selectChat(chat);
                    // Push full-screen chat route (covers tab bar like WhatsApp)
                    _openChatFullScreen(chat);
                  },
                  hasUnreadMessages: hasUnread,
                );
              });
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

  Widget _buildGroupCreationView() {
    return Column(
      children: [
        // Header for group creation
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
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
              const Icon(
                CupertinoIcons.group_solid,
                color: CupertinoColors.systemBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
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
                child: const Icon(
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group name input
                const Text(
                  'Group Name (Optional)',
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    color: CupertinoColors.label,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.41,
                  ),
                ),
                const SizedBox(height: 8),
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
                    placeholderStyle: const TextStyle(
                      fontFamily: 'SF Pro Text',
                      color: CupertinoColors.systemGrey,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    style: const TextStyle(
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
                const SizedBox(height: 20),
                // Group image upload
                const Text(
                  'Group Image (Optional)',
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    color: CupertinoColors.label,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.41,
                  ),
                ),
                const SizedBox(height: 8),
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
                            ? const Center(
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
                                        child: const Icon(
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
                                        child: const Icon(
                                          CupertinoIcons.photo,
                                          color: CupertinoColors.systemGrey,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  )
                                : const Column(
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
                    const SizedBox(width: 12),
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
                          const SizedBox(height: 8),
                          CupertinoButton(
                            onPressed: _model.isUploadingImage
                                ? null
                                : _pickGroupImage,
                            color: _model.isUploadingImage
                                ? CupertinoColors.systemGrey
                                : CupertinoColors.systemBlue,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            borderRadius: BorderRadius.circular(8),
                            child: Text(
                              _model.groupImageUrl != null
                                  ? 'Change'
                                  : 'Select',
                              style: const TextStyle(
                                fontFamily: 'SF Pro Text',
                                color: CupertinoColors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.15,
                              ),
                            ), minimumSize: Size(0, 0),
                          ),
                          if (_model.groupImageUrl != null) ...[
                            const SizedBox(width: 8),
                            CupertinoButton(
                              onPressed: () {
                                setState(() {
                                  _model.groupImagePath = null;
                                  _model.groupImageUrl = null;
                                });
                              },
                              color: CupertinoColors.systemRed,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              borderRadius: BorderRadius.circular(8),
                              child: const Text(
                                'Remove',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Text',
                                  color: CupertinoColors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.15,
                                ),
                              ), minimumSize: Size(0, 0),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Selected members header with search
                Row(
                  children: [
                    Text(
                      'Selected Members (${_model.selectedMembers.length})',
                      style: const TextStyle(
                        fontFamily: 'SF Pro Text',
                        color: CupertinoColors.label,
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.41,
                      ),
                    ),
                    const Spacer(),
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
                        placeholderStyle: const TextStyle(
                          fontFamily: 'SF Pro Text',
                          color: CupertinoColors.systemGrey,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        prefix: const Padding(
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
                                child: const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Icon(
                                    CupertinoIcons.xmark_circle_fill,
                                    color: CupertinoColors.systemGrey,
                                    size: 16,
                                  ),
                                ),
                              )
                            : null,
                        style: const TextStyle(
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
                const SizedBox(height: 8),
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
                      ? const Center(
                          child: CupertinoActivityIndicator(
                            color: CupertinoColors.systemBlue,
                          ),
                        )
                      : StreamBuilder<UsersRecord>(
                          stream:
                              UsersRecord.getDocument(currentUserReference!),
                          builder: (context, currentUserSnapshot) {
                            if (!currentUserSnapshot.hasData) {
                              return const Center(
                                child: CupertinoActivityIndicator(
                                  color: CupertinoColors.systemBlue,
                                ),
                              );
                            }

                            final currentUser = currentUserSnapshot.data!;
                            final connections = currentUser.friends;

                            if (connections.isEmpty) {
                              return const Center(
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
                              padding: const EdgeInsets.all(8),
                              itemCount: connections.length,
                              itemBuilder: (context, index) {
                                final connectionRef = connections[index];

                                return StreamBuilder<UsersRecord>(
                                  stream:
                                      UsersRecord.getDocument(connectionRef),
                                  builder: (context, userSnapshot) {
                                    if (!userSnapshot.hasData) {
                                      return const SizedBox.shrink();
                                    }

                                    final user = userSnapshot.data!;
                                    final isCurrentUser =
                                        user.reference == currentUserReference;
                                    final isSelected = _model.selectedMembers
                                        .contains(user.reference);

                                    if (isCurrentUser) {
                                      return const SizedBox.shrink();
                                    }

                                    // Check if search query matches
                                    if (searchQuery.isNotEmpty) {
                                      final displayName =
                                          user.displayName.toLowerCase();
                                      final email = user.email.toLowerCase();
                                      if (!displayName.contains(searchQuery) &&
                                          !email.contains(searchQuery)) {
                                        return const SizedBox.shrink();
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
                                        margin: const EdgeInsets.only(bottom: 4),
                                        padding: const EdgeInsets.all(12),
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
                                                  decoration: const BoxDecoration(
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
                                                            const BoxDecoration(
                                                          color: CupertinoColors
                                                              .systemGrey5,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: const Icon(
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
                                                            const BoxDecoration(
                                                          color: CupertinoColors
                                                              .systemGrey5,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: const Icon(
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
                                            const SizedBox(width: 12),
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
                                                  const SizedBox(height: 2),
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
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: CupertinoColors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
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
                const SizedBox(height: 20),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    borderRadius: BorderRadius.circular(10),
                    child: const Text(
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
          backgroundColor: const Color(0xFFFF3B30),
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
        const SnackBar(
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
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
    }
  }

  Future<void> _createGroup() async {
    try {
      if (_model.selectedMembers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
          backgroundColor: const Color(0xFFFF3B30),
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
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
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
              const Icon(
                CupertinoIcons.chat_bubble,
                color: CupertinoColors.systemBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
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
                child: const Icon(
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
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
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
              placeholderStyle: const TextStyle(
                fontFamily: 'SF Pro Text',
                color: CupertinoColors.systemGrey,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefix: const Padding(
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
                      child: const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: CupertinoColors.systemGrey,
                          size: 16,
                        ),
                      ),
                    )
                  : null,
              style: const TextStyle(
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
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
                      const SizedBox(width: 8),
                      const Text(
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
                      ? const Center(
                          child: CupertinoActivityIndicator(
                            color: CupertinoColors.systemBlue,
                          ),
                        )
                      : StreamBuilder<UsersRecord>(
                          stream:
                              UsersRecord.getDocument(currentUserReference!),
                          builder: (context, currentUserSnapshot) {
                            if (!currentUserSnapshot.hasData) {
                              return const Center(
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
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.person_2,
                                        color: CupertinoColors.systemBlue,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No connections',
                                      style: TextStyle(
                                        fontFamily: 'SF Pro Text',
                                        color: CupertinoColors.label,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.41,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
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
                                      return const SizedBox.shrink();
                                    }

                                    final user = userSnapshot.data!;
                                    final isCurrentUser =
                                        user.reference == currentUserReference;

                                    if (isCurrentUser) {
                                      return const SizedBox.shrink();
                                    }

                                    // Filter by search query
                                    if (searchQuery.isNotEmpty) {
                                      final displayName =
                                          user.displayName.toLowerCase();
                                      final email = user.email.toLowerCase();
                                      if (!displayName.contains(searchQuery) &&
                                          !email.contains(searchQuery)) {
                                        return const SizedBox.shrink();
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
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
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
                                                  decoration: const BoxDecoration(
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
                                                            const BoxDecoration(
                                                          color: CupertinoColors
                                                              .systemGrey5,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: const Icon(
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
                                                            const BoxDecoration(
                                                          color: CupertinoColors
                                                              .systemGrey5,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: const Icon(
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
                                            const SizedBox(width: 12),
                                            // User info
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    user.displayName,
                                                    style: const TextStyle(
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
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    user.email,
                                                    style: const TextStyle(
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
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
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
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Widget _buildHeaderAvatar(ChatsRecord chat) {
    if (chat.isGroup) {
      return Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
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
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group,
                color: Color(0xFF8E8E93),
                size: 18,
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
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
            decoration: const BoxDecoration(
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF8E8E93),
                    size: 18,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
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
        decoration: const BoxDecoration(
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
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
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
                titleColor: const Color(0xFFFF3B30),
                iconColor: const Color(0xFFFF3B30),
                onTap: () {
                  Navigator.pop(context);
                  _blockUser(chat);
                },
              ),
            ],
            const SizedBox(height: 20),
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
        color: iconColor ?? const Color(0xFF1D1D1F),
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'System',
          color: titleColor ?? const Color(0xFF1D1D1F),
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
        const SnackBar(
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
        const SnackBar(
          content: Text('Error loading user profile'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
    }
  }

  void _blockUser(ChatsRecord chat) async {
    if (chat.isGroup) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
            title: const Text(
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
              style: const TextStyle(
                fontFamily: 'System',
                color: Color(0xFF8E8E93),
                fontSize: 15,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
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
                child: const Text(
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
          const SnackBar(
            content: Text('User has been blocked'),
            backgroundColor: Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error blocking user'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
    }
  }

  void _viewGroupChat(ChatsRecord chat) async {
    if (!chat.isGroup) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
        const SnackBar(
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
    super.key,
    required this.chat,
    required this.isSelected,
    required this.onTap,
    required this.hasUnreadMessages,
  });

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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
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
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            // Menu options
            _buildMenuOption(
              icon: chat.isPin ? Icons.push_pin : Icons.push_pin_outlined,
              title: chat.isPin ? 'Unpin Chat' : 'Pin Chat',
              onTap: () {
                Navigator.pop(context);
                _togglePinChat(chat);
              },
            ),
            _buildMenuOption(
              icon: Icons.delete_outline,
              title: 'Delete Chat',
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(chat);
              },
              textColor: Colors.red,
              iconColor: Colors.red,
            ),
            // Bottom spacing
            const SizedBox(height: 20),
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
    const defaultColor = Color(0xFF1D1D1F);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? defaultColor,
              size: 20,
            ),
            const SizedBox(width: 16),
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
      await chat.reference.update({
        'is_pin': !chat.isPin,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chat.isPin ? 'Chat unpinned' : 'Chat pinned'),
          backgroundColor: const Color(0xFF34C759),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating chat'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
    }
  }

  void _showDeleteConfirmation(ChatsRecord chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text(
            'Are you sure you want to delete this chat? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChat(chat);
            },
            child: const Text(
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
      await chat.reference.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat deleted'),
          backgroundColor: Color(0xFF34C759),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error deleting chat'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
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
                  const SizedBox(width: 12),
                  // Chat Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _getChatDisplayName(widget.chat),
                        const SizedBox(height: 4),
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
                          style: const TextStyle(
                            fontFamily: 'SF Pro Text',
                            color: Color(0xFF8E8E93),
                            fontSize: 13,
                          ),
                        ),
                        // Pin icon at bottom
                        if (widget.chat.isPin)
                          const Icon(
                            Icons.push_pin,
                            size: 12,
                            color: Color(0xFF8E8E93),
                          )
                        else
                          const SizedBox(height: 12), // Reserve space if no pin
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
                      decoration: const BoxDecoration(
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
        decoration: const BoxDecoration(
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
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group,
                color: Color(0xFF8E8E93),
                size: 24,
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
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
            decoration: const BoxDecoration(
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF8E8E93),
                    size: 24,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
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
        style: const TextStyle(
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

      return FutureBuilder<UsersRecord>(
        future: UsersRecord.getDocumentOnce(otherUserRef),
        builder: (context, userSnapshot) {
          String displayName = 'Direct Chat';
          if (userSnapshot.hasData && userSnapshot.data != null) {
            final user = userSnapshot.data!;
            // Check if this is Summer
            if (otherUserRef.path.contains('ai_agent_summerai')) {
              displayName = 'Summer';
            } else {
              displayName = user.displayName.isNotEmpty
                  ? user.displayName
                  : 'Unknown User';
            }
          }

          return Text(
            displayName,
            style: const TextStyle(
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
    if (chat.lastMessage.isEmpty) {
      // Special handling for service chats
      if (chat.isServiceChat == true) {
        return const Text(
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

      return const Text(
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
              chat.lastMessage,
              style: const TextStyle(
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
                  style: const TextStyle(
                    fontFamily: 'SF Pro Text',
                    color: Color(0xFF8E8E93),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: chat.lastMessage,
                  style: const TextStyle(
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
      chat.lastMessage,
      style: const TextStyle(
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
  final Function(MessagesRecord)? onMessageLongPress;
  final bool shouldPopTwice;
  final VoidCallback? onPop;

  const _FullScreenChatPage({
    super.key,
    required this.chat,
    this.onMessageLongPress,
    this.shouldPopTwice = false,
    this.onPop,
  });

  @override
  State<_FullScreenChatPage> createState() => _FullScreenChatPageState();
}

class _FullScreenChatPageState extends State<_FullScreenChatPage> {

  @override
  Widget build(BuildContext context) {
    // Ensure we have a valid context
    if (!mounted) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        bottom: false,
        child: Container(
          color: const Color(0xFFF2F2F7),
          child: ChatThreadComponentWidget(
            chatReference: widget.chat,
            onMessageLongPress: widget.onMessageLongPress,
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
          const Size.fromHeight(bubbleHeight + 50), // Account for the offset
      child: Stack(
        children: [
          // Spacer to push content down
          const SizedBox(height: bubbleHeight + 50),
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
                  const SizedBox(width: 8),
                  // Back button - using AdaptiveFloatingActionButton with liquid glass effects
                  AdaptiveFloatingActionButton(
                        onPressed: () {
                          print('🔙 FullScreenChat Back button clicked! shouldPopTwice: ${widget.shouldPopTwice}');
                          if (widget.shouldPopTwice) {
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
                        child: const Icon(
                          CupertinoIcons.chevron_left,
                          size: 22,
                        ),
                      ),
                  const SizedBox(width: 4),
                  // Centered title - tappable to view profile
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _navigateToProfile(chat),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Avatar
                              _buildAvatar(chat),
                              const SizedBox(width: 6),
                              // Name - show other user's name for DMs
                              Flexible(
                                child: chat.isGroup
                                    ? Text(
                                        chat.title.isNotEmpty
                                            ? chat.title
                                            : 'Group Chat',
                                        style: const TextStyle(
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
                                            style: const TextStyle(
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
                  const SizedBox(width: 4),
                  // More options button - iOS native adaptive popup menu
                  AdaptivePopupMenuButton.widget<String>(
                    items: chat.isGroup
                        ? [
                            // Group chat options
                            AdaptivePopupMenuItem(
                              label: 'Add Members',
                              icon: Platform.isIOS
                                  ? 'person.badge.plus'
                                  : Icons.person_add,
                              value: 'add_members',
                            ),
                            AdaptivePopupMenuItem(
                              label: 'Media',
                              icon: Platform.isIOS
                                  ? 'photo.on.rectangle'
                                  : Icons.photo_library,
                              value: 'media',
                            ),
                            AdaptivePopupMenuItem(
                              label: 'Tasks',
                              icon: Platform.isIOS
                                  ? 'checklist'
                                  : Icons.checklist,
                              value: 'tasks',
                            ),
                            AdaptivePopupMenuItem(
                              label: 'Group Info',
                              icon: Platform.isIOS
                                  ? 'info.circle'
                                  : Icons.info_outline,
                              value: 'group_info',
                            ),
                          ]
                        : [
                            // Direct message options
                            AdaptivePopupMenuItem(
                              label: 'View User Profile',
                              icon: Platform.isIOS
                                  ? 'person.circle'
                                  : Icons.person,
                              value: 'view_profile',
                            ),
                            AdaptivePopupMenuItem(
                              label: 'Block User',
                              icon: Platform.isIOS
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
                      }
                    },
                    child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.ellipsis,
                            size: 22,
                            color: CupertinoColors.systemBlue,
                          ),
                        ),
                  ),
                  const SizedBox(width: 8),
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
                color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                CupertinoIcons.person_2_fill,
                size: 14,
                color: Color(0xFF8E8E93),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
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
            color: const Color(0xFFE5E5EA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
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
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    CupertinoIcons.person_fill,
                    size: 14,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
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
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
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
      context.pushNamed(
        GroupChatDetailWidget.routeName,
        queryParameters: {
          'chatDoc': serializeParam(chat, ParamType.Document),
        }.withoutNulls,
        extra: <String, dynamic>{'chatDoc': chat},
      );
    } else {
      // For DMs, navigate to new user summary page instead of old profile page
      try {
        final user = await _getOtherUser(chat);
        if (context.mounted) {
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
          const SnackBar(
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
        const SnackBar(
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
            title: const Text(
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
              style: const TextStyle(
                fontFamily: 'System',
                color: Color(0xFF8E8E93),
                fontSize: 15,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
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
                child: const Text(
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
          const SnackBar(
            content: Text('User has been blocked'),
            backgroundColor: Color(0xFF34C759),
          ),
        );

        // Navigate back to chat list
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
    context.pushNamed(
      MobileGroupMediaWidget.routeName,
      queryParameters: {
        'chatDoc': serializeParam(chat, ParamType.Document),
      }.withoutNulls,
      extra: <String, dynamic>{'chatDoc': chat},
    );
  }

  void _navigateToTasks(ChatsRecord chat) {
    if (!chat.isGroup) return;
    context.pushNamed(
      MobileGroupTasksWidget.routeName,
      queryParameters: {
        'chatDoc': serializeParam(chat, ParamType.Document),
      }.withoutNulls,
      extra: <String, dynamic>{'chatDoc': chat},
    );
  }
}

// iOS 26+ floating popup menu with glass effect
class _IOS26PopupMenu<T> extends StatelessWidget {
  final RelativeRect position;
  final List<AdaptivePopupMenuItem<T>> items;
  final Function(int index, AdaptivePopupMenuItem<T> item) onSelected;

  const _IOS26PopupMenu({
    required this.position,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const menuWidth = 200.0;
    final menuHeight = items.length * 50.0 + 16.0; // 50 per item + padding

    // Calculate position (slightly above center, more natural for message menus)
    final left = screenSize.width / 2 - menuWidth / 2;
    final top = screenSize.height * 0.4 - menuHeight / 2;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dismissible background
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Floating menu
          Positioned(
            left: left,
            top: top,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: menuWidth,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isDestructive =
                        item.value.toString().contains('report') ||
                            item.value.toString().contains('unsend');
                    final textColor = isDestructive
                        ? const Color(0xFFFF3B30)
                        : CupertinoColors.label;
                    final isLast = index == items.length - 1;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          onSelected(index, item);
                        },
                        borderRadius: BorderRadius.vertical(
                          top: index == 0 ? const Radius.circular(16) : Radius.zero,
                          bottom: isLast ? const Radius.circular(16) : Radius.zero,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              // Icon
                              if (item.icon is String)
                                Icon(
                                  _getIconForSFSymbol(item.icon as String),
                                  size: 20,
                                  color: textColor,
                                )
                              else
                                Icon(
                                  item.icon as IconData,
                                  size: 20,
                                  color: textColor,
                                ),
                              const SizedBox(width: 12),
                              // Label
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Display',
                                    fontSize: 17,
                                    color: textColor,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
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

  IconData _getIconForSFSymbol(String symbol) {
    // Map SF Symbols to CupertinoIcons
    final iconMap = {
      'doc.on.doc': CupertinoIcons.doc_on_doc,
      'face.smiling': CupertinoIcons.smiley,
      'arrowshape.turn.up.left': CupertinoIcons.arrow_turn_up_left,
      'pencil': CupertinoIcons.pencil,
      'arrow.uturn.backward': CupertinoIcons.arrow_counterclockwise,
      'exclamationmark.triangle': CupertinoIcons.exclamationmark_triangle,
      'arrow.down.circle': CupertinoIcons.arrow_down_circle,
      'character.bubble': Icons.translate_rounded, // Use Material icon as fallback for translate
      'pin': CupertinoIcons.pin,
      'pin.slash': CupertinoIcons.pin_slash,
    };
    return iconMap[symbol] ?? CupertinoIcons.circle;
  }
}
