import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import '/auth/firebase_auth/auth_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'feed_model.dart';
export 'feed_model.dart';

/// create me a feed page like have people to upload image and then have
/// share, like, comment and save
class FeedWidget extends StatefulWidget {
  const FeedWidget({super.key});

  static String routeName = 'Feed';
  static String routePath = '/feed';

  @override
  State<FeedWidget> createState() => _FeedWidgetState();
}

class _FeedWidgetState extends State<FeedWidget> {
  late FeedModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FeedModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.loading = true;
      safeSetState(() {});
      await Future.delayed(
        const Duration(
          milliseconds: 1000,
        ),
      );
      _model.loading = false;
      safeSetState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Future<List<PostsRecord>> _fetchAllPosts() async {
    try {
      final query = await PostsRecord.collection
          .orderBy('created_at', descending: true)
          .get();

      final List<PostsRecord> allPosts = [];
      for (final doc in query.docs) {
        allPosts.add(PostsRecord.fromSnapshot(doc));
      }

      // Sort posts: pinned first, then by creation date
      allPosts.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      return allPosts;
    } catch (e) {
      print('Error fetching posts: $e');
      return [];
    }
  }

  Future<bool> _isUserBlocked(DocumentReference? userRef) async {
    if (userRef == null || userRef == currentUserReference) {
      return false; // Don't block yourself
    }

    try {
      final blockedQuery = await BlockedUsersRecord.collection
          .where('blocker_user', isEqualTo: currentUserReference)
          .where('blocked_user', isEqualTo: userRef)
          .limit(1)
          .get();

      return blockedQuery.docs.isNotEmpty;
    } catch (e) {
      print('Error checking blocked user: $e');
      return false; // If error, don't block
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            context.pushNamed(
              CreatePostWidget.routeName,
              queryParameters: {
                'image': serializeParam(
                  '',
                  ParamType.String,
                ),
                'caption': serializeParam(
                  '',
                  ParamType.String,
                ),
                'feeling': serializeParam(
                  '',
                  ParamType.String,
                ),
                'isEdit': serializeParam(
                  false,
                  ParamType.bool,
                ),
              }.withoutNulls,
            );
          },
          backgroundColor: FlutterFlowTheme.of(context).primary,
          elevation: 8.0,
          child: FaIcon(
            FontAwesomeIcons.edit,
            color: FlutterFlowTheme.of(context).info,
            size: 20.0,
          ),
        ),
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
          automaticallyImplyLeading: false,
          title: Align(
            alignment: AlignmentDirectional(
                valueOrDefault<double>(
                  isiOS || isAndroid ? -1.0 : 0.0,
                  0.0,
                ),
                0.0),
            child: Text(
              'News',
              style: FlutterFlowTheme.of(context).headlineLarge.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).headlineLarge.fontStyle,
                    ),
                    fontSize: 20.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineLarge.fontStyle,
                  ),
            ),
          ),
          actions: const [],
          centerTitle: false,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: Align(
            alignment: const AlignmentDirectional(0.0, 0.0),
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 650.0,
              ),
              decoration: const BoxDecoration(),
              child: Stack(
                children: [
                  Builder(
                    builder: (context) {
                      if (_model.loading == false) {
                        return RefreshIndicator(
                          key: const Key('RefreshIndicator_wsurvo3x'),
                          onRefresh: () async {
                            setState(() {});
                          },
                          child: FutureBuilder<List<PostsRecord>>(
                            future: _fetchAllPosts(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (snapshot.hasError) {
                                return Center(
                                  child: Text('Error: ${snapshot.error}'),
                                );
                              }

                              final posts = snapshot.data ?? [];

                              return ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16.0,
                                  16.0,
                                  16.0,
                                  16.0,
                                ),
                                primary: false,
                                shrinkWrap: true,
                                itemCount:
                                    posts.length + 1, // +1 for AI summary
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 16.0),
                                itemBuilder: (context, index) {
                                  // Show AI summary as first item
                                  if (index == 0) {
                                    return custom_widgets
                                        .AIAnnouncementsSummary(
                                      width: double.infinity,
                                    );
                                  }

                                  // Show posts (adjust index by -1)
                                  final post = posts[index - 1];

                                  // Check if the post author is blocked
                                  return FutureBuilder<bool>(
                                    future: _isUserBlocked(post.authorRef),
                                    builder: (context, snapshot) {
                                      // If still loading, show the post (to avoid flickering)
                                      if (!snapshot.hasData) {
                                        return SizedBox(
                                          width: double.infinity,
                                          child: custom_widgets.PostItem(
                                            width: double.infinity,
                                            height: 0.0,
                                            isPostDetail: false,
                                            postRef: post.reference,
                                            actionEdit: () async {
                                              context.pushNamed(
                                                CreatePostWidget.routeName,
                                                queryParameters: {
                                                  'image': serializeParam(
                                                    post.imageUrl,
                                                    ParamType.String,
                                                  ),
                                                  'caption': serializeParam(
                                                    post.text,
                                                    ParamType.String,
                                                  ),
                                                  'feeling': serializeParam(
                                                    post.postType,
                                                    ParamType.String,
                                                  ),
                                                  'isEdit': serializeParam(
                                                    true,
                                                    ParamType.bool,
                                                  ),
                                                  'postDoc': serializeParam(
                                                    post.reference,
                                                    ParamType.DocumentReference,
                                                  ),
                                                }.withoutNulls,
                                              );
                                            },
                                          ),
                                        );
                                      }

                                      // If user is blocked, don't show the post
                                      if (snapshot.data == true) {
                                        return const SizedBox.shrink();
                                      }

                                      return SizedBox(
                                        width: double.infinity,
                                        child: custom_widgets.PostItem(
                                          width: double.infinity,
                                          height: 0.0,
                                          isPostDetail: false,
                                          postRef: post.reference,
                                          actionEdit: () async {
                                            context.pushNamed(
                                              CreatePostWidget.routeName,
                                              queryParameters: {
                                                'image': serializeParam(
                                                  post.imageUrl,
                                                  ParamType.String,
                                                ),
                                                'caption': serializeParam(
                                                  post.text,
                                                  ParamType.String,
                                                ),
                                                'feeling': serializeParam(
                                                  post.postType,
                                                  ParamType.String,
                                                ),
                                                'isEdit': serializeParam(
                                                  true,
                                                  ParamType.bool,
                                                ),
                                                'postDoc': serializeParam(
                                                  post.reference,
                                                  ParamType.DocumentReference,
                                                ),
                                              }.withoutNulls,
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        );
                      } else {
                        return SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: custom_widgets.FFlowSpinner(
                            width: double.infinity,
                            height: double.infinity,
                            backgroundColor: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            spinnerColor: FlutterFlowTheme.of(context).primary,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
