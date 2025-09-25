import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_expanded_image_view.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:math';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:octo_image/octo_image.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'post_thread_model.dart';
export 'post_thread_model.dart';

class PostThreadWidget extends StatefulWidget {
  const PostThreadWidget({
    super.key,
    required this.image,
    required this.userImage,
    required this.caption,
    required this.createdTime,
    required this.likeCount,
    required this.commentCount,
    required this.name,
    required this.userRef,
    bool? isLike,
    bool? isSave,
    required this.postRef,
    required this.actionEdit,
    required this.likeAction,
    bool? isPostDetail,
  })  : this.isLike = isLike ?? false,
        this.isSave = isSave ?? false,
        this.isPostDetail = isPostDetail ?? false;

  final String? image;
  final String? userImage;
  final String? caption;
  final DateTime? createdTime;
  final int? likeCount;
  final int? commentCount;
  final String? name;
  final DocumentReference? userRef;
  final bool isLike;
  final bool isSave;
  final PostsRecord? postRef;
  final Future Function()? actionEdit;
  final Future Function(int currentLikeNo)? likeAction;
  final bool isPostDetail;

  @override
  State<PostThreadWidget> createState() => _PostThreadWidgetState();
}

class _PostThreadWidgetState extends State<PostThreadWidget>
    with TickerProviderStateMixin {
  late PostThreadModel _model;

  var hasIconButtonTriggered1 = false;
  var hasIconButtonTriggered2 = false;
  final animationsMap = <String, AnimationInfo>{};

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PostThreadModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.islike = widget!.isLike;
      _model.likeNum = widget!.likeCount;
      _model.cmmNum = widget!.commentCount;
      _model.isSaved = widget!.isSave;
      safeSetState(() {});
    });

    animationsMap.addAll({
      'iconOnActionTriggerAnimation': AnimationInfo(
        trigger: AnimationTrigger.onActionTrigger,
        applyInitialState: true,
        effectsBuilder: () => [
          VisibilityEffect(duration: 1.ms),
          ScaleEffect(
            curve: Curves.bounceOut,
            delay: 0.0.ms,
            duration: 400.0.ms,
            begin: Offset(0.0, 0.0),
            end: Offset(1.0, 1.0),
          ),
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 500.0.ms,
            begin: Offset(0.0, 5.0),
            end: Offset(0.0, 0.0),
          ),
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 600.0.ms,
            duration: 300.0.ms,
            begin: 1.0,
            end: 0.0,
          ),
        ],
      ),
      'iconButtonOnActionTriggerAnimation1': AnimationInfo(
        trigger: AnimationTrigger.onActionTrigger,
        applyInitialState: false,
        effectsBuilder: () => [
          ScaleEffect(
            curve: Curves.bounceOut,
            delay: 0.0.ms,
            duration: 400.0.ms,
            begin: Offset(0.0, 0.0),
            end: Offset(1.0, 1.0),
          ),
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 500.0.ms,
            begin: Offset(0.0, 5.0),
            end: Offset(0.0, 0.0),
          ),
        ],
      ),
      'iconButtonOnActionTriggerAnimation2': AnimationInfo(
        trigger: AnimationTrigger.onActionTrigger,
        applyInitialState: false,
        effectsBuilder: () => [
          ScaleEffect(
            curve: Curves.bounceOut,
            delay: 0.0.ms,
            duration: 400.0.ms,
            begin: Offset(0.0, 0.0),
            end: Offset(1.0, 1.0),
          ),
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 500.0.ms,
            begin: Offset(0.0, 5.0),
            end: Offset(0.0, 0.0),
          ),
        ],
      ),
    });
    setupAnimations(
      animationsMap.values.where((anim) =>
          anim.trigger == AnimationTrigger.onActionTrigger ||
          !anim.applyInitialState),
      this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        if (_model.isLoaded == true) {
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              boxShadow: [
                BoxShadow(
                  blurRadius: 8.0,
                  color: Color(0x1A000000),
                  offset: Offset(
                    0.0,
                    2.0,
                  ),
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
                  InkWell(
                    splashColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () async {
                      _model.user = await queryUsersRecordOnce(
                        queryBuilder: (usersRecord) => usersRecord.where(
                          'uid',
                          isEqualTo: widget!.userRef?.id,
                        ),
                        singleRecord: true,
                      ).then((s) => s.firstOrNull);

                      context.pushNamed(
                        UserProfileDetailWidget.routeName,
                        queryParameters: {
                          'user': serializeParam(
                            _model.user,
                            ParamType.Document,
                          ),
                        }.withoutNulls,
                        extra: <String, dynamic>{
                          'user': _model.user,
                        },
                      );

                      safeSetState(() {});
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                          width: 40.0,
                          height: 40.0,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: CachedNetworkImage(
                            fadeInDuration: Duration(milliseconds: 300),
                            fadeOutDuration: Duration(milliseconds: 300),
                            imageUrl: valueOrDefault<String>(
                              widget!.userImage,
                              'https://images.unsplash.com/photo-1720255487272-218f85016f23?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHJhbmRvbXx8fHx8fHx8fDE3NTI3NDMwNDZ8&ixlib=rb-4.1.0&q=80&w=1080',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                valueOrDefault<String>(
                                  widget!.name,
                                  'Sarah',
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                              ),
                              Text(
                                dateTimeFormat("relative", widget!.createdTime),
                                style: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontStyle,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (widget!.userRef == currentUserReference)
                          FlutterFlowIconButton(
                            borderRadius: 16.0,
                            buttonSize: 32.0,
                            icon: Icon(
                              Icons.more_horiz,
                              color: FlutterFlowTheme.of(context).secondaryText,
                              size: 20.0,
                            ),
                            onPressed: () async {
                              await widget.actionEdit?.call();
                            },
                          ),
                      ].divide(SizedBox(width: 12.0)),
                    ),
                  ),
                  Text(
                    valueOrDefault<String>(
                      widget!.caption,
                      'Just captured this amazing sunset from my balcony! The colors were absolutely breathtaking tonight. Nature never fails to amaze me ✨🌅',
                    ).maybeHandleOverflow(
                      maxChars: 135,
                      replacement: '…',
                    ),
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                          ),
                          letterSpacing: 0.0,
                          fontWeight: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                          lineHeight: 1.4,
                        ),
                  ),
                  InkWell(
                    splashColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onDoubleTap: () async {
                      if (_model.islike == false) {
                        _model.islike = true;
                        _model.likeNum = _model.likeNum! + 1;
                        safeSetState(() {});
                        await Future.wait([
                          Future(() async {
                            if (animationsMap['iconOnActionTriggerAnimation'] !=
                                null) {
                              await animationsMap[
                                      'iconOnActionTriggerAnimation']!
                                  .controller
                                  .forward(from: 0.0);
                            }
                          }),
                          Future(() async {
                            if (animationsMap[
                                    'iconButtonOnActionTriggerAnimation1'] !=
                                null) {
                              safeSetState(
                                  () => hasIconButtonTriggered1 = true);
                              SchedulerBinding.instance.addPostFrameCallback(
                                  (_) async => await animationsMap[
                                          'iconButtonOnActionTriggerAnimation1']!
                                      .controller
                                      .forward(from: 0.0));
                            }
                          }),
                        ]);

                        await widget!.postRef!.reference.update({
                          ...mapToFirestore(
                            {
                              'like_count': FieldValue.increment(1),
                              'liked_by':
                                  FieldValue.arrayUnion([currentUserReference]),
                            },
                          ),
                        });
                      } else {
                        await Future.wait([
                          Future(() async {
                            if (animationsMap['iconOnActionTriggerAnimation'] !=
                                null) {
                              await animationsMap[
                                      'iconOnActionTriggerAnimation']!
                                  .controller
                                  .forward(from: 0.0);
                            }
                          }),
                          Future(() async {
                            if (animationsMap[
                                    'iconButtonOnActionTriggerAnimation1'] !=
                                null) {
                              safeSetState(
                                  () => hasIconButtonTriggered1 = true);
                              SchedulerBinding.instance.addPostFrameCallback(
                                  (_) async => await animationsMap[
                                          'iconButtonOnActionTriggerAnimation1']!
                                      .controller
                                      .forward(from: 0.0));
                            }
                          }),
                        ]);
                      }
                    },
                    child: Stack(
                      alignment: AlignmentDirectional(0.0, 0.0),
                      children: [
                        InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              PageTransition(
                                type: PageTransitionType.fade,
                                child: FlutterFlowExpandedImageView(
                                  image: CachedNetworkImage(
                                    fadeInDuration: Duration(milliseconds: 300),
                                    fadeOutDuration:
                                        Duration(milliseconds: 300),
                                    imageUrl: valueOrDefault<String>(
                                      widget!.image,
                                      'https://images.unsplash.com/photo-1747128947265-7b22125aedd4?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHJhbmRvbXx8fHx8fHx8fDE3NTI3NDMwNDZ8&ixlib=rb-4.1.0&q=80&w=1080',
                                    ),
                                    fit: BoxFit.contain,
                                  ),
                                  allowRotation: false,
                                  tag: valueOrDefault<String>(
                                    widget!.image,
                                    'https://images.unsplash.com/photo-1747128947265-7b22125aedd4?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHJhbmRvbXx8fHx8fHx8fDE3NTI3NDMwNDZ8&ixlib=rb-4.1.0&q=80&w=1080',
                                  ),
                                  useHeroAnimation: true,
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: valueOrDefault<String>(
                              widget!.image,
                              'https://images.unsplash.com/photo-1747128947265-7b22125aedd4?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHJhbmRvbXx8fHx8fHx8fDE3NTI3NDMwNDZ8&ixlib=rb-4.1.0&q=80&w=1080',
                            ),
                            transitionOnUserGestures: true,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: CachedNetworkImage(
                                fadeInDuration: Duration(milliseconds: 300),
                                fadeOutDuration: Duration(milliseconds: 300),
                                imageUrl: valueOrDefault<String>(
                                  widget!.image,
                                  'https://images.unsplash.com/photo-1747128947265-7b22125aedd4?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHJhbmRvbXx8fHx8fHx8fDE3NTI3NDMwNDZ8&ixlib=rb-4.1.0&q=80&w=1080',
                                ),
                                width: double.infinity,
                                height: 300.0,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: Icon(
                            Icons.favorite_sharp,
                            color: FlutterFlowTheme.of(context).primary,
                            size: 70.0,
                          ).animateOnActionTrigger(
                            animationsMap['iconOnActionTriggerAnimation']!,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Stack(
                                children: [
                                  if (_model.islike == false)
                                    FlutterFlowIconButton(
                                      borderRadius: 16.0,
                                      buttonSize: 40.0,
                                      icon: Icon(
                                        Icons.favorite_border,
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        size: 25.0,
                                      ),
                                      onPressed: () async {
                                        _model.islike = true;
                                        _model.likeNum = _model.likeNum! + 1;
                                        _model.updatePage(() {});
                                        if (animationsMap[
                                                'iconButtonOnActionTriggerAnimation1'] !=
                                            null) {
                                          safeSetState(() =>
                                              hasIconButtonTriggered1 = true);
                                          SchedulerBinding.instance
                                              .addPostFrameCallback((_) async =>
                                                  await animationsMap[
                                                          'iconButtonOnActionTriggerAnimation1']!
                                                      .controller
                                                      .forward(from: 0.0));
                                        }

                                        await widget!.postRef!.reference
                                            .update({
                                          ...mapToFirestore(
                                            {
                                              'liked_by': FieldValue.arrayUnion(
                                                  [currentUserReference]),
                                              'like_count':
                                                  FieldValue.increment(1),
                                            },
                                          ),
                                        });
                                      },
                                    ),
                                  if (_model.islike == true)
                                    FlutterFlowIconButton(
                                      borderRadius: 16.0,
                                      buttonSize: 40.0,
                                      icon: Icon(
                                        Icons.favorite,
                                        color: FlutterFlowTheme.of(context)
                                            .primary,
                                        size: 25.0,
                                      ),
                                      onPressed: () async {
                                        _model.islike = false;
                                        _model.likeNum = _model.likeNum! + -1;
                                        safeSetState(() {});

                                        await widget!.postRef!.reference
                                            .update({
                                          ...mapToFirestore(
                                            {
                                              'like_count':
                                                  FieldValue.increment(-(1)),
                                              'liked_by':
                                                  FieldValue.arrayRemove(
                                                      [currentUserReference]),
                                            },
                                          ),
                                        });
                                      },
                                    ).animateOnActionTrigger(
                                        animationsMap[
                                            'iconButtonOnActionTriggerAnimation1']!,
                                        hasBeenTriggered:
                                            hasIconButtonTriggered1),
                                ],
                              ),
                              Text(
                                valueOrDefault<String>(
                                  _model.likeNum?.toString(),
                                  '0',
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontStyle,
                                    ),
                              ),
                            ].divide(SizedBox(width: 4.0)),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              FlutterFlowIconButton(
                                borderRadius: 16.0,
                                buttonSize: 40.0,
                                icon: Icon(
                                  Icons.chat_bubble_outline,
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                  size: 25.0,
                                ),
                                onPressed: () async {
                                  if (widget!.isPostDetail != true) {
                                    context.pushNamed(
                                      PostDetailWidget.routeName,
                                      queryParameters: {
                                        'postDoc': serializeParam(
                                          widget!.postRef,
                                          ParamType.Document,
                                        ),
                                      }.withoutNulls,
                                      extra: <String, dynamic>{
                                        'postDoc': widget!.postRef,
                                      },
                                    );
                                  }
                                },
                              ),
                              Text(
                                valueOrDefault<String>(
                                  widget!.commentCount?.toString(),
                                  '0',
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontStyle,
                                    ),
                              ),
                            ].divide(SizedBox(width: 4.0)),
                          ),
                        ].divide(SizedBox(width: 16.0)),
                      ),
                      Stack(
                        children: [
                          if (_model.isSaved == false)
                            FlutterFlowIconButton(
                              borderRadius: 16.0,
                              buttonSize: 40.0,
                              icon: Icon(
                                Icons.bookmark_border,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                size: 25.0,
                              ),
                              onPressed: () async {
                                _model.isSaved = true;
                                _model.updatePage(() {});
                                if (animationsMap[
                                        'iconButtonOnActionTriggerAnimation2'] !=
                                    null) {
                                  safeSetState(
                                      () => hasIconButtonTriggered2 = true);
                                  SchedulerBinding.instance.addPostFrameCallback(
                                      (_) async => await animationsMap[
                                              'iconButtonOnActionTriggerAnimation2']!
                                          .controller
                                          .forward(from: 0.0));
                                }

                                await widget!.postRef!.reference.update({
                                  ...mapToFirestore(
                                    {
                                      'saved_by': FieldValue.arrayUnion(
                                          [widget!.userRef]),
                                    },
                                  ),
                                });
                              },
                            ),
                          if (_model.isSaved == true)
                            FlutterFlowIconButton(
                              borderRadius: 16.0,
                              buttonSize: 40.0,
                              icon: Icon(
                                Icons.bookmark_rounded,
                                color: FlutterFlowTheme.of(context).primary,
                                size: 25.0,
                              ),
                              onPressed: () async {
                                _model.isSaved = false;
                                _model.updatePage(() {});

                                await widget!.postRef!.reference.update({
                                  ...mapToFirestore(
                                    {
                                      'saved_by': FieldValue.arrayRemove(
                                          [widget!.userRef]),
                                    },
                                  ),
                                });
                              },
                            ).animateOnActionTrigger(
                                animationsMap[
                                    'iconButtonOnActionTriggerAnimation2']!,
                                hasBeenTriggered: hasIconButtonTriggered2),
                        ],
                      ),
                    ],
                  ),
                ].divide(SizedBox(height: 12.0)),
              ),
            ),
          );
        } else {
          return Align(
            alignment: AlignmentDirectional(0.0, 0.0),
            child: Container(
              width: 100.0,
              height: 100.0,
              child: custom_widgets.FFlowSpinner(
                width: 100.0,
                height: 100.0,
                spinnerWidth: 50.0,
                spinnerHeight: 50.0,
                strokeWidth: 1.0,
                backgroundColor: Colors.transparent,
                spinnerColor: FlutterFlowTheme.of(context).primary,
              ),
            ),
          );
        }
      },
    );
  }
}
