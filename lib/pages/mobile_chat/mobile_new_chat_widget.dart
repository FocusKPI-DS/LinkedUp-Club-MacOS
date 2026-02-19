import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/mobile_chat/mobile_new_chat_model.dart';
import '/pages/mobile_chat/mobile_chat_widget.dart';
import '/utils/chat_helpers.dart';
import '/pages/desktop_chat/chat_controller.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
export 'mobile_new_chat_model.dart';

class MobileNewChatWidget extends StatefulWidget {
  const MobileNewChatWidget({Key? key}) : super(key: key);

  static String routeName = 'MobileNewChat';
  static String routePath = '/mobile-new-chat';

  @override
  _MobileNewChatWidgetState createState() => _MobileNewChatWidgetState();
}

class _MobileNewChatWidgetState extends State<MobileNewChatWidget> {
  late MobileNewChatModel _model;
  late ChatController chatController;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MobileNewChatModel());
    // Get existing controller or create a new one if it doesn't exist
    try {
      chatController = Get.find<ChatController>();
    } catch (e) {
      // If controller doesn't exist, create it
      chatController = Get.put(ChatController());
    }
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }


  Future<void> _startNewChatWithUser(UsersRecord user) async {
    try {
      final chatToOpen =
          await ChatHelpers.findOrCreateDirectChat(user.reference);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MobileChatWidget(
              initialChat: chatToOpen,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error starting chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting chat: $e'),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Custom header with iOS 26 native back button
            Container(
              height: 44,
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  // Floating back button - iOS 26+ style with liquid glass effects
                  LiquidStretch(
                    stretch: 0.5,
                    interactionScale: 1.05,
                    child: GlassGlow(
                      glowColor: Colors.white24,
                      glowRadius: 1.0,
                      child: AdaptiveFloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.white,
                        foregroundColor: Color(0xFF007AFF),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Icon(
                          CupertinoIcons.chevron_left,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Centered title
                  Expanded(
                    child: Center(
                      child: Text(
                        'New Chat',
                        style: TextStyle(
                          fontFamily: 'SF Pro Text',
                          color: CupertinoColors.label,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.41,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 40), // Balance the back button width
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
                              stream: UsersRecord.getDocument(currentUserReference!),
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

                                        return Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () async {
                                              print('Contact tapped: ${user.displayName}');
                                              await _startNewChatWithUser(user);
                                            },
                                            borderRadius: BorderRadius.circular(10),
                                            child: Container(
                                            margin: EdgeInsets.only(bottom: 8),
                                            padding: EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: CupertinoColors.systemBackground,
                                              borderRadius: BorderRadius.circular(10),
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
                                                        color: CupertinoColors.systemGrey5,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(24),
                                                        child: CachedNetworkImage(
                                                          imageUrl: user.photoUrl,
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
                                                              color: CupertinoColors.systemGrey5,
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: Icon(
                                                              CupertinoIcons.person_fill,
                                                              color: CupertinoColors.systemGrey,
                                                              size: 24,
                                                            ),
                                                          ),
                                                          errorWidget: (context, url, error) => Container(
                                                            width: 48,
                                                            height: 48,
                                                            decoration: BoxDecoration(
                                                              color: CupertinoColors.systemGrey5,
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: Icon(
                                                              CupertinoIcons.person_fill,
                                                              color: CupertinoColors.systemGrey,
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
                                                            color: CupertinoColors.systemGreen,
                                                            shape: BoxShape.circle,
                                                            border: Border.all(
                                                              color: CupertinoColors.systemBackground,
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
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        user.displayName,
                                                        style: TextStyle(
                                                          fontFamily: 'SF Pro Text',
                                                          color: CupertinoColors.label,
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w600,
                                                          letterSpacing: -0.24,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      SizedBox(height: 2),
                                                      Text(
                                                        user.email,
                                                        style: TextStyle(
                                                          fontFamily: 'SF Pro Text',
                                                          color: CupertinoColors.systemGrey,
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w400,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Start Chat button
                                                Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: CupertinoColors.systemBlue
                                                        .withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Icon(
                                                    CupertinoIcons.arrow_right,
                                                    color: CupertinoColors.systemBlue,
                                                    size: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
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
        ),
      ),
    );
  }
}

