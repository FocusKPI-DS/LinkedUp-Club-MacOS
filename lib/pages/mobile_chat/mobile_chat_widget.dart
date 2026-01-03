import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/chat/chat_component/chat_thread_component/chat_thread_component_widget.dart';
import '/pages/mobile_chat/mobile_chat_model.dart';
import '/pages/desktop_chat/chat_controller.dart';
import '/pages/chat/user_profile_detail/user_profile_detail_widget.dart';
import '/pages/chat/group_chat_detail/group_chat_detail_widget.dart';
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
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';

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
  late MobileChatModel _model;
  late ChatController chatController;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final animationsMap = <String, AnimationInfo>{};
  double? _dragStartX;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MobileChatModel());
    chatController = Get.put(ChatController());

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
            final success = await actions.ensureFcmToken(
              currentUserReference!,
            );
            if (success) {
              print('✅ FCM token ensured from MobileChat page');
            } else {
              print('⚠️ Failed to ensure FCM token from MobileChat page');
            }
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
    Get.delete<ChatController>();
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
      child: AdaptiveScaffold(
        appBar: null, // No app bar - using custom header instead
        body: SafeArea(
          bottom: false,
          child: Container(
            color: Color(0xFFF5F5F7),
            child: RepaintBoundary(
              child: Column(
                children: [
                  // Fixed header section with Chats title, action buttons, search bar, and filters
                  Container(
                    color: Color(0xFFF5F5F7),
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
    // Set the selected chat so reply/edit actions can access it
    _model.selectedChat = chat;

    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        fullscreenDialog: false,
        builder: (context) => _FullScreenChatPage(
          chat: chat,
          onMessageLongPress: _showMessageMenu,
        ),
      ),
    );
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
                // Floating back button on the left - iOS 26+ style
                AdaptiveFloatingActionButton(
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
                                        style: TextStyle(
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
                SizedBox(width: 8),
                // Settings button on the right - iOS 26+ style
                AdaptiveFloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white, // Pure white like back button
                  foregroundColor: Color(0xFF007AFF), // System blue icon
                  onPressed: () => _showChatOptions(chat),
                  child: Icon(
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

  void _showMessageMenu(MessagesRecord message) {
    // Build popup menu items
    final menuItems = <AdaptivePopupMenuItem<String>>[
      AdaptivePopupMenuItem(
        label: 'Copy',
        icon:
            PlatformInfo.isIOS26OrHigher() ? 'doc.on.doc' : Icons.copy_rounded,
        value: 'copy',
      ),
      AdaptivePopupMenuItem(
        label: 'React',
        icon: PlatformInfo.isIOS26OrHigher()
            ? 'face.smiling'
            : Icons.emoji_emotions_rounded,
        value: 'react',
      ),
      AdaptivePopupMenuItem(
        label: 'Reply',
        icon: PlatformInfo.isIOS26OrHigher()
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
          icon: PlatformInfo.isIOS26OrHigher() ? 'pencil' : Icons.edit_rounded,
          value: 'edit',
        ),
        AdaptivePopupMenuItem(
          label: 'Unsend',
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'arrow.uturn.backward'
              : Icons.undo_rounded,
          value: 'unsend',
        ),
      ]);
    }

    // Add Report option (destructive action)
    menuItems.add(
      AdaptivePopupMenuItem(
        label: 'Report',
        icon: PlatformInfo.isIOS26OrHigher()
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
    if (PlatformInfo.isIOS26OrHigher()) {
      showGeneralDialog<T>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.3),
        barrierDismissible: true,
        barrierLabel: 'Dismiss menu',
        transitionDuration: Duration(milliseconds: 200),
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
              isDestructive ? Color(0xFFFF3B30) : CupertinoColors.label;

          return PopupMenuItem<T>(
            value: item.value,
            child: Row(
              children: [
                Icon(
                  item.icon as IconData,
                  size: 20,
                  color: textColor,
                ),
                SizedBox(width: 12),
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
    final textColor = isDestructive ? Color(0xFFFF3B30) : Color(0xFF1D1D1F);
    final iconColor = isDestructive ? Color(0xFFFF3B30) : Color(0xFF1D1D1F);

    // Get the appropriate icon
    Widget iconWidget;
    if (PlatformInfo.isIOS26OrHigher() && item.icon is String) {
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
    // Map SF Symbol names to CupertinoIcons
    final iconMap = {
      'doc.on.doc': CupertinoIcons.doc_on_doc,
      'face.smiling': CupertinoIcons.smiley,
      'arrowshape.turn.up.left': CupertinoIcons.arrow_turn_up_left,
      'pencil': CupertinoIcons.pencil,
      'arrow.uturn.backward': CupertinoIcons.arrow_counterclockwise,
      'exclamationmark.triangle': CupertinoIcons.exclamationmark_triangle,
    };
    return iconMap[sfSymbol] ?? CupertinoIcons.circle;
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
                      message.content,
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
    final TextEditingController editController =
        TextEditingController(text: message.content);

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
                      _updateMessage(message, text.trim());
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
                            _updateMessage(message, editController.text.trim());
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

  Widget _buildHeaderActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AdaptiveFloatingActionButton(
          mini: true,
          backgroundColor: Colors.white, // Pure white like back button
          foregroundColor: Color(0xFF007AFF), // System blue icon
          onPressed: () {
            setState(() {
              _model.showNewChatScreen = !_model.showNewChatScreen;
              if (_model.showNewChatScreen) {
                _model.selectedChat = null;
                chatController.selectedChat.value = null;
                _model.newChatSearchController?.clear();
                _model.showGroupCreation = false;
                // Clear group creation state
                _model.groupName = '';
                _model.selectedMembers = [];
                _model.groupNameController?.clear();
                _model.groupMemberSearchController?.clear();
              }
            });
          },
          child: Icon(
            CupertinoIcons.add,
            size: 20,
          ),
        ),
        const SizedBox(width: 8.0),
        AdaptiveFloatingActionButton(
          mini: true,
          backgroundColor: Colors.white, // Pure white like back button
          foregroundColor: Color(0xFF007AFF), // System blue icon
          onPressed: () {
            setState(() {
              _model.showGroupCreation = !_model.showGroupCreation;
              if (_model.showGroupCreation) {
                _model.groupName = '';
                _model.selectedMembers = [];
                _model.groupNameController?.clear();
                _model.groupMemberSearchController?.clear();
                _model.groupImagePath = null;
                _model.groupImageUrl = null;
                _model.isUploadingImage = false;
                _model.showNewChatScreen = false;
                _model.newChatSearchController?.clear();
              }
            });
          },
          child: Icon(
            CupertinoIcons.person_2_fill,
            size: 20,
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
        child: _buildChatListContentInner(),
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

          return ListView.builder(
            key: ValueKey(
                'chat_list_items_${_model.tabController?.index ?? 0}_${filteredChats.length}_${chatController.searchQuery.value}'),
            padding: EdgeInsets.only(top: 4, left: 0, right: 0, bottom: 100),
            itemCount: filteredChats.length,
            physics: ClampingScrollPhysics(),
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
                        return SizedBox.shrink();
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
                          Row(
                            children: [
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

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Group "$groupName" created successfully!'),
          backgroundColor: Color(0xFF34C759),
        ),
      );

      // Open the new group chat in full-screen
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
          _model.showNewChatScreen = false;
        });
        chatController.selectChat(existingChat);
        // Open in full-screen
        _openChatFullScreen(existingChat);
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
          _model.showNewChatScreen = false;
        });
        chatController.selectChat(newChat);
        // Open in full-screen
        _openChatFullScreen(newChat);
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

  // Helper function to format timestamp
  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'Unknown';

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
      await chat.reference.update({
        'is_pin': !chat.isPin,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chat.isPin ? 'Chat unpinned' : 'Chat pinned'),
          backgroundColor: Color(0xFF34C759),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
      await chat.reference.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chat deleted'),
          backgroundColor: Color(0xFF34C759),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
                        if (widget.chat.isPin)
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
    if (chat.lastMessage.isEmpty) {
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

    return Text(
      chat.lastMessage,
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
  final Function(MessagesRecord)? onMessageLongPress;

  const _FullScreenChatPage({
    Key? key,
    required this.chat,
    this.onMessageLongPress,
  }) : super(key: key);

  @override
  State<_FullScreenChatPage> createState() => _FullScreenChatPageState();
}

class _FullScreenChatPageState extends State<_FullScreenChatPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: Color(0xFFF2F2F7),
      body: SafeArea(
        bottom: false,
        child: Container(
          color: Color(0xFFF2F2F7),
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
                  // Back button - using AdaptiveFloatingActionButton
                  AdaptiveFloatingActionButton(
                    onPressed: () {
                      print('🔙 Back button clicked!');
                      Navigator.of(context).pop();
                    },
                    mini: true,
                    backgroundColor: Colors.white,
                    foregroundColor: CupertinoColors.systemBlue,
                    child: Icon(
                      CupertinoIcons.chevron_left,
                      size: 22,
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
                  // More options button - using AdaptivePopupMenuButton
                  AdaptivePopupMenuButton.widget<String>(
                    items: chat.isGroup
                        ? [
                            // Group chat options
                            AdaptivePopupMenuItem(
                              label: 'View Group Chat',
                              icon: PlatformInfo.isIOS26OrHigher()
                                  ? 'person.2.circle'
                                  : Icons.group,
                              value: 'view_group',
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
                              label: 'Block User',
                              icon: PlatformInfo.isIOS26OrHigher()
                                  ? 'hand.raised.fill'
                                  : Icons.block,
                              value: 'block_user',
                            ),
                          ],
                    onSelected: (index, item) {
                      if (item.value == 'view_profile') {
                        _navigateToProfile(chat);
                      } else if (item.value == 'view_group') {
                        _navigateToProfile(chat);
                      } else if (item.value == 'block_user') {
                        _blockUserFromChat(chat);
                      }
                    },
                    child: AdaptiveFloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.white,
                      foregroundColor: CupertinoColors.systemBlue,
                      onPressed: () {
                        // Menu will open automatically
                      },
                      child: Icon(
                        CupertinoIcons.ellipsis,
                        size: 22,
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
      context.pushNamed(
        GroupChatDetailWidget.routeName,
        queryParameters: {
          'chatDoc': serializeParam(chat, ParamType.Document),
        }.withoutNulls,
        extra: <String, dynamic>{'chatDoc': chat},
      );
    } else {
      // For DMs, navigate to user profile
      try {
        final user = await _getOtherUser(chat);
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
    final menuWidth = 200.0;
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
                      offset: Offset(0, 8),
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
                        ? Color(0xFFFF3B30)
                        : CupertinoColors.label;
                    final isLast = index == items.length - 1;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          onSelected(index, item);
                        },
                        borderRadius: BorderRadius.vertical(
                          top: index == 0 ? Radius.circular(16) : Radius.zero,
                          bottom: isLast ? Radius.circular(16) : Radius.zero,
                        ),
                        child: Container(
                          padding: EdgeInsets.symmetric(
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
                              SizedBox(width: 12),
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
    };
    return iconMap[symbol] ?? CupertinoIcons.circle;
  }
}
