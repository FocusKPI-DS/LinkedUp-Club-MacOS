// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_expanded_image_view.dart';
import '/pages/feed/post_detail/post_detail_widget.dart';
import '/pages/chat/user_profile_detail/user_profile_detail_widget.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostItem extends StatefulWidget {
  const PostItem({
    super.key,
    required this.postRef,
    required this.width,
    required this.height,
    this.isPostDetail = false,
    this.actionEdit,
  });

  final DocumentReference postRef;
  final bool isPostDetail;
  final Future Function()? actionEdit;
  final double width;
  final double height;

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> with TickerProviderStateMixin {
  late AnimationController _likeAnimationController;
  late AnimationController _saveAnimationController;
  bool _isLikeAnimating = false;
  bool _isSaveAnimating = false;

  @override
  void initState() {
    super.initState();
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _saveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    _saveAnimationController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike(PostsRecord post, bool isLiked) async {
    if (!isLiked) {
      setState(() => _isLikeAnimating = true);
      _likeAnimationController.forward(from: 0.0).then((_) {
        _likeAnimationController.reverse().then((_) {
          if (mounted) setState(() => _isLikeAnimating = false);
        });
      });
    }

    if (isLiked) {
      await widget.postRef.update({
        'like_count': FieldValue.increment(-1),
        'liked_by': FieldValue.arrayRemove([currentUserReference]),
      });
    } else {
      await widget.postRef.update({
        'like_count': FieldValue.increment(1),
        'liked_by': FieldValue.arrayUnion([currentUserReference]),
      });
    }
  }

  Future<void> _toggleSave(PostsRecord post, bool isSaved) async {
    if (!isSaved) {
      setState(() => _isSaveAnimating = true);
      _saveAnimationController.forward(from: 0.0).then((_) {
        _saveAnimationController.reverse().then((_) {
          if (mounted) setState(() => _isSaveAnimating = false);
        });
      });
    }

    if (isSaved) {
      await widget.postRef.update({
        'saved_by': FieldValue.arrayRemove([currentUserReference]),
      });
    } else {
      await widget.postRef.update({
        'saved_by': FieldValue.arrayUnion([currentUserReference]),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PostsRecord>(
      stream: PostsRecord.getDocument(widget.postRef),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: FlutterFlowTheme.of(context).primary,
              ),
            ),
          );
        }

        final post = snapshot.data!;
        final isLiked = post.likedBy.contains(currentUserReference);
        final isSaved = post.savedBy.contains(currentUserReference);

        // Debug print to check data
        debugPrint('Post likes: ${post.likeCount}, isLiked: $isLiked');
        debugPrint('Post likedBy array: ${post.likedBy}');
        debugPrint('Current user ref: $currentUserReference');

        return Container(
          width: widget.width,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            boxShadow: [
              BoxShadow(
                blurRadius: 8.0,
                color: Color(0x1A000000),
                offset: Offset(0.0, 2.0),
              )
            ],
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info row
                InkWell(
                  onTap: () async {
                    final user =
                        await UsersRecord.getDocumentOnce(post.authorRef!);
                    if (context.mounted) {
                      context.pushNamed(
                        UserProfileDetailWidget.routeName,
                        queryParameters: {
                          'user': serializeParam(user, ParamType.Document),
                        }.withoutNulls,
                        extra: <String, dynamic>{'user': user},
                      );
                    }
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 40.0,
                        height: 40.0,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(shape: BoxShape.circle),
                        child: CachedNetworkImage(
                          fadeInDuration: Duration(milliseconds: 300),
                          fadeOutDuration: Duration(milliseconds: 300),
                          imageUrl: post.authorImage,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.authorName,
                              style: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    letterSpacing: 0.0,
                                  ),
                            ),
                            Text(
                              dateTimeFormat("relative", post.createdAt!),
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    font: GoogleFonts.inter(),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_horiz,
                          color: FlutterFlowTheme.of(context).secondaryText,
                          size: 20.0,
                        ),
                        onSelected: (String value) async {
                          if (value == 'report') {
                            // Show report dialog
                            final shouldReport = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text('Report Post'),
                                  content: Text('Are you sure you want to report this post for inappropriate content?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: Text(
                                        'Report',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                            
                            if (shouldReport == true) {
                              // Create report record
                              await ReportsRecord.collection.add({
                                ...createReportsRecordData(
                                  reportedBy: currentUserReference,
                                  reportedUser: post.authorRef,
                                  messageRef: post.reference, // Using messageRef for post reference
                                  reason: 'User reported this post as inappropriate',
                                  timestamp: getCurrentTimestamp,
                                ),
                              });
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Post has been reported')),
                              );
                            }
                          } else if (value == 'block') {
                            // Show block user dialog
                            final shouldBlock = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text('Block User'),
                                  content: Text('Are you sure you want to block ${post.authorName}? You will no longer see their posts or be able to contact them.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: Text(
                                        'Block',
                                        style: TextStyle(color: Colors.red),
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
                                  blockedUser: post.authorRef,
                                  createdAt: getCurrentTimestamp,
                                ),
                              });
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('User has been blocked')),
                              );
                            }
                          } else if (value == 'view_user') {
                            // Navigate to user profile
                            final user = await UsersRecord.getDocumentOnce(post.authorRef!);
                            if (context.mounted) {
                              context.pushNamed(
                                UserProfileDetailWidget.routeName,
                                queryParameters: {
                                  'user': serializeParam(user, ParamType.Document),
                                }.withoutNulls,
                                extra: <String, dynamic>{'user': user},
                              );
                            }
                          } else if (value == 'edit' && post.authorRef == currentUserReference) {
                            // Edit post (only for post author)
                            await widget.actionEdit?.call();
                          }
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          if (post.authorRef != currentUserReference) ...[
                            PopupMenuItem<String>(
                              value: 'view_user',
                              child: Row(
                                children: [
                                  Icon(Icons.person, size: 20),
                                  SizedBox(width: 8),
                                  Text('View User'),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'report',
                              child: Row(
                                children: [
                                  Icon(Icons.flag, color: Colors.orange, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Report',
                                    style: TextStyle(color: Colors.orange),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'block',
                              child: Row(
                                children: [
                                  Icon(Icons.block, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Block User',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Edit Post'),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.0),

                // Caption
                Text(
                  post.text
                      .maybeHandleOverflow(maxChars: 135, replacement: '…'),
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.inter(),
                        letterSpacing: 0.0,
                        lineHeight: 1.4,
                      ),
                ),
                SizedBox(height: 12.0),

                // Image
                InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.fade,
                        child: FlutterFlowExpandedImageView(
                          image: CachedNetworkImage(
                            fadeInDuration: Duration(milliseconds: 300),
                            fadeOutDuration: Duration(milliseconds: 300),
                            imageUrl: post.imageUrl,
                            fit: BoxFit.contain,
                          ),
                          allowRotation: false,
                          tag: post.imageUrl,
                          useHeroAnimation: true,
                        ),
                      ),
                    );
                  },
                  child: Hero(
                    tag: post.imageUrl,
                    transitionOnUserGestures: true,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: CachedNetworkImage(
                        fadeInDuration: Duration(milliseconds: 300),
                        fadeOutDuration: Duration(milliseconds: 300),
                        imageUrl: post.imageUrl,
                        width: double.infinity,
                        height: 300.0,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.0),

                // Actions row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Like button
                        Row(
                          children: [
                            AnimatedScale(
                              scale: _isLikeAnimating ? 1.2 : 1.0,
                              duration: Duration(milliseconds: 200),
                              child: FlutterFlowIconButton(
                                borderRadius: 16.0,
                                buttonSize: 40.0,
                                icon: Icon(
                                  isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isLiked
                                      ? FlutterFlowTheme.of(context).primary
                                      : FlutterFlowTheme.of(context)
                                          .secondaryText,
                                  size: 25.0,
                                ),
                                onPressed: () => _toggleLike(post, isLiked),
                              ),
                            ),
                            SizedBox(width: 4.0),
                            Text(
                              post.likeCount.toString(),
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    font: GoogleFonts.inter(),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ],
                        ),
                        SizedBox(width: 16.0),

                        // Comment button
                        Row(
                          children: [
                            FlutterFlowIconButton(
                              borderRadius: 16.0,
                              buttonSize: 40.0,
                              icon: Icon(
                                Icons.chat_bubble_outline,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                size: 25.0,
                              ),
                              onPressed: () async {
                                if (!widget.isPostDetail) {
                                  context.pushNamed(
                                    PostDetailWidget.routeName,
                                    queryParameters: {
                                      'postDoc': serializeParam(
                                          post, ParamType.Document),
                                    }.withoutNulls,
                                    extra: <String, dynamic>{'postDoc': post},
                                  );
                                }
                              },
                            ),
                            SizedBox(width: 4.0),
                            Text(
                              post.commentCount.toString(),
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    font: GoogleFonts.inter(),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Save button
                    AnimatedScale(
                      scale: _isSaveAnimating ? 1.2 : 1.0,
                      duration: Duration(milliseconds: 200),
                      child: FlutterFlowIconButton(
                        borderRadius: 16.0,
                        buttonSize: 40.0,
                        icon: Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border,
                          color: isSaved
                              ? FlutterFlowTheme.of(context).primary
                              : FlutterFlowTheme.of(context).secondaryText,
                          size: 25.0,
                        ),
                        onPressed: () => _toggleSave(post, isSaved),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
