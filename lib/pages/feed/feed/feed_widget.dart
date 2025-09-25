import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import '/auth/firebase_auth/auth_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';
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
        Duration(
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
              'Feed',
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
          actions: [],
          centerTitle: false,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: Align(
            alignment: AlignmentDirectional(0.0, 0.0),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 650.0,
              ),
              decoration: BoxDecoration(),
              child: Stack(
                children: [
                  Builder(
                    builder: (context) {
                      if (_model.loading == false) {
                        return RefreshIndicator(
                          key: Key('RefreshIndicator_wsurvo3x'),
                          onRefresh: () async {},
                          child: PagedListView<DocumentSnapshot<Object?>?,
                              PostsRecord>.separated(
                            pagingController: _model.setListViewController(
                              PostsRecord.collection
                                  .orderBy('created_at', descending: true),
                            ),
                            padding: EdgeInsets.fromLTRB(
                              0,
                              0,
                              0,
                              16.0,
                            ),
                            primary: false,
                            shrinkWrap: true,
                            reverse: false,
                            scrollDirection: Axis.vertical,
                            separatorBuilder: (_, __) => SizedBox(height: 16.0),
                            builderDelegate:
                                PagedChildBuilderDelegate<PostsRecord>(
                              // Customize what your widget looks like when it's loading the first page.
                              firstPageProgressIndicatorBuilder: (_) => Center(
                                child: SizedBox(
                                  width: 50.0,
                                  height: 50.0,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      FlutterFlowTheme.of(context).primary,
                                    ),
                                  ),
                                ),
                              ),
                              // Customize what your widget looks like when it's loading another page.
                              newPageProgressIndicatorBuilder: (_) => Center(
                                child: SizedBox(
                                  width: 50.0,
                                  height: 50.0,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      FlutterFlowTheme.of(context).primary,
                                    ),
                                  ),
                                ),
                              ),

                              itemBuilder: (context, _, listViewIndex) {
                                final listViewPostsRecord = _model
                                    .listViewPagingController!
                                    .itemList![listViewIndex];
                                
                                // Check if the post author is blocked
                                return FutureBuilder<bool>(
                                  future: _isUserBlocked(listViewPostsRecord.authorRef),
                                  builder: (context, snapshot) {
                                    // If still loading, show the post (to avoid flickering)
                                    if (!snapshot.hasData) {
                                      return Container(
                                        width: double.infinity,
                                        height: 475.0,
                                        child: custom_widgets.PostItem(
                                          width: double.infinity,
                                          height: 475.0,
                                          isPostDetail: false,
                                          postRef: listViewPostsRecord.reference,
                                          actionEdit: () async {
                                            context.pushNamed(
                                              CreatePostWidget.routeName,
                                              queryParameters: {
                                                'image': serializeParam(
                                                  listViewPostsRecord.imageUrl,
                                                  ParamType.String,
                                                ),
                                                'caption': serializeParam(
                                                  listViewPostsRecord.text,
                                                  ParamType.String,
                                                ),
                                                'feeling': serializeParam(
                                                  listViewPostsRecord.postType,
                                                  ParamType.String,
                                                ),
                                                'isEdit': serializeParam(
                                                  true,
                                                  ParamType.bool,
                                                ),
                                                'postDoc': serializeParam(
                                                  listViewPostsRecord.reference,
                                                  ParamType.DocumentReference,
                                                ),
                                              }.withoutNulls,
                                            );
                                          },
                                        ),
                                      );
                                    }
                                    
                                    // If user is blocked, return empty container
                                    if (snapshot.data == true) {
                                      return SizedBox.shrink();
                                    }
                                    
                                    // If user is not blocked, show the post
                                    return Container(
                                      width: double.infinity,
                                      height: 475.0,
                                      child: custom_widgets.PostItem(
                                        width: double.infinity,
                                        height: 475.0,
                                        isPostDetail: false,
                                        postRef: listViewPostsRecord.reference,
                                        actionEdit: () async {
                                          context.pushNamed(
                                            CreatePostWidget.routeName,
                                            queryParameters: {
                                              'image': serializeParam(
                                                listViewPostsRecord.imageUrl,
                                                ParamType.String,
                                              ),
                                              'caption': serializeParam(
                                                listViewPostsRecord.text,
                                                ParamType.String,
                                              ),
                                              'feeling': serializeParam(
                                                listViewPostsRecord.postType,
                                                ParamType.String,
                                              ),
                                              'isEdit': serializeParam(
                                                true,
                                                ParamType.bool,
                                              ),
                                              'postDoc': serializeParam(
                                                listViewPostsRecord.reference,
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
                            ),
                          ),
                        );
                      } else {
                        return Container(
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
