import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/chat/chat_component/blocked/blocked_widget.dart';
import '/pages/chat/chat_component/chat_thread_component/chat_thread_component_widget.dart';
import 'dart:io';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'chat_detail_model.dart';
export 'chat_detail_model.dart';

/// Tech Conference 2025 Chat Overview
class ChatDetailWidget extends StatefulWidget {
  const ChatDetailWidget({
    super.key,
    required this.chatDoc,
  });

  final ChatsRecord? chatDoc;

  static String routeName = 'ChatDetail';
  static String routePath = '/chatDetail';

  @override
  State<ChatDetailWidget> createState() => _ChatDetailWidgetState();
}

class _ChatDetailWidgetState extends State<ChatDetailWidget> {
  late ChatDetailModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  double? _dragStartX;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChatDetailModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.isExist = await actions.handleDeletedContent(
        context,
        widget!.chatDoc?.reference.path,
        'chat',
      );
      if (_model.isExist != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Chat not found.',
              style: GoogleFonts.inter(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                fontWeight: FontWeight.w500,
              ),
            ),
            duration: Duration(milliseconds: 3000),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
        context.safePop();
        return;
      }
      _model.loading = true;
      safeSetState(() {});
      _model.blocked = await action_blocks.checkBlock(
        context,
        userRef: currentUserReference,
        blockedUser: widget!.chatDoc?.blockedUser,
      );
      if (_model.blocked == true) {
        await showDialog(
          context: context,
          builder: (dialogContext) {
            return Dialog(
              elevation: 0,
              insetPadding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              alignment: AlignmentDirectional(0.0, 0.0)
                  .resolve(Directionality.of(context)),
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(dialogContext).unfocus();
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                child: BlockedWidget(),
              ),
            );
          },
        );
      } else {
        if (!widget!.chatDoc!.lastMessageSeen.contains(currentUserReference)) {
          await widget!.chatDoc!.reference.update({
            ...mapToFirestore(
              {
                'last_message_seen':
                    FieldValue.arrayUnion([currentUserReference]),
              },
            ),
          });
        }
      }

      await Future.delayed(
        Duration(
          milliseconds: 500,
        ),
      );
      _model.loading = false;
      safeSetState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    // On page dispose action.
    () async {
      await actions.closekeyboard();
    }();

    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => StreamBuilder<ChatsRecord>(
        stream: ChatsRecord.getDocument(widget!.chatDoc!.reference),
        builder: (context, snapshot) {
          // Customize what your widget looks like when it's loading.
          if (!snapshot.hasData) {
            return Scaffold(
              backgroundColor: Color(0xFFF9FAFB),
              body: Center(
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
            );
          }

          final chatDetailChatsRecord = snapshot.data!;

          return GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: Scaffold(
              key: scaffoldKey,
              backgroundColor: Color(0xFFF9FAFB),
              body: GestureDetector(
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
                  if (Platform.isIOS &&
                      _dragStartX != null &&
                      _dragStartX! <= 20) {
                    // Check if swipe was from left to right (positive velocity)
                    if (details.primaryVelocity != null &&
                        details.primaryVelocity! > 200) {
                      // Navigate back
                      context.goNamed(
                        ChatWidget.routeName,
                        extra: <String, dynamic>{
                          kTransitionInfoKey: TransitionInfo(
                            hasTransition: true,
                            transitionType: PageTransitionType.fade,
                            duration: Duration(milliseconds: 0),
                          ),
                        },
                      );
                    }
                  }
                  _dragStartX = null;
                },
                child: Stack(
                  children: [
                    Align(
                      alignment: AlignmentDirectional(0.0, -1.0),
                      child: InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          await actions.closekeyboard();
                        },
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: 650.0,
                          ),
                          decoration: BoxDecoration(),
                          child: Stack(
                            children: [
                              // ═══════════════════════════════════════════════
                              // CHAT CONTENT - Full height, scrolls behind top bar
                              // ═══════════════════════════════════════════════
                              Positioned.fill(
                                child: Column(
                                  children: [
                                    // Top padding for floating header
                                    SizedBox(height: 100),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(),
                                        child: wrapWithModel(
                                          model:
                                              _model.chatThreadComponentModel,
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child: ChatThreadComponentWidget(
                                            chatReference:
                                                chatDetailChatsRecord,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // ═══════════════════════════════════════════════
                              // FLOATING TOP BAR - Glass effect, content scrolls behind
                              // ═══════════════════════════════════════════════
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: ClipRRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 30, sigmaY: 30),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        // 🔮 Ultra Glass effect (theme-aware)
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            (Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.black
                                                    : Colors.white)
                                                .withOpacity(0.85),
                                            (Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.black
                                                    : Colors.white)
                                                .withOpacity(0.75),
                                          ],
                                        ),
                                        border: Border(
                                          bottom: BorderSide(
                                            color:
                                                (Theme.of(context).brightness ==
                                                            Brightness.dark
                                                        ? Colors.white
                                                        : Colors.black)
                                                    .withOpacity(0.08),
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            16.0, 60.0, 16.0, 16.0),
                                        child: Container(
                                          decoration: BoxDecoration(),
                                          child: Builder(
                                            builder: (context) {
                                              if (widget!.chatDoc?.isGroup ==
                                                  false) {
                                                return StreamBuilder<
                                                    UsersRecord>(
                                                  stream: UsersRecord
                                                      .getDocument(widget!
                                                          .chatDoc!.members
                                                          .where((e) =>
                                                              e.id !=
                                                              currentUserReference
                                                                  ?.id)
                                                          .toList()
                                                          .firstOrNull!),
                                                  builder: (context, snapshot) {
                                                    // Customize what your widget looks like when it's loading.
                                                    if (!snapshot.hasData) {
                                                      return Center(
                                                        child: SizedBox(
                                                          width: 50.0,
                                                          height: 50.0,
                                                          child:
                                                              CircularProgressIndicator(
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                    Color>(
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .primary,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }

                                                    final bigUsersRecord =
                                                        snapshot.data!;

                                                    return Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          children: [
                                                            GestureDetector(
                                                              onTap: () {
                                                                context.goNamed(
                                                                  ChatWidget
                                                                      .routeName,
                                                                  extra: <String,
                                                                      dynamic>{
                                                                    kTransitionInfoKey:
                                                                        TransitionInfo(
                                                                      hasTransition:
                                                                          true,
                                                                      transitionType:
                                                                          PageTransitionType
                                                                              .fade,
                                                                      duration: Duration(
                                                                          milliseconds:
                                                                              0),
                                                                    ),
                                                                  },
                                                                );
                                                              },
                                                              child: Icon(
                                                                CupertinoIcons
                                                                    .chevron_left,
                                                                color: CupertinoColors
                                                                    .systemBlue,
                                                                size: 28.0,
                                                              ),
                                                            ),
                                                            Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  bigUsersRecord
                                                                      .displayName,
                                                                  style: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleMedium
                                                                      .override(
                                                                        font: GoogleFonts
                                                                            .inter(
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .titleMedium
                                                                              .fontStyle,
                                                                        ),
                                                                        color: Color(
                                                                            0xFF1F2937),
                                                                        fontSize:
                                                                            18.0,
                                                                        letterSpacing:
                                                                            0.0,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .titleMedium
                                                                            .fontStyle,
                                                                      ),
                                                                ),
                                                                Text(
                                                                  bigUsersRecord
                                                                      .email,
                                                                  style: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .override(
                                                                        font: GoogleFonts
                                                                            .inter(
                                                                          fontWeight: FlutterFlowTheme.of(context)
                                                                              .bodySmall
                                                                              .fontWeight,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodySmall
                                                                              .fontStyle,
                                                                        ),
                                                                        color: Color(
                                                                            0xFF6B7280),
                                                                        fontSize:
                                                                            12.0,
                                                                        letterSpacing:
                                                                            0.0,
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
                                                          ].divide(SizedBox(
                                                              width: 16.0)),
                                                        ),
                                                        InkWell(
                                                          splashColor: Colors
                                                              .transparent,
                                                          focusColor: Colors
                                                              .transparent,
                                                          hoverColor: Colors
                                                              .transparent,
                                                          highlightColor: Colors
                                                              .transparent,
                                                          onTap: () async {
                                                            context.pushNamed(
                                                              UserProfileDetailWidget
                                                                  .routeName,
                                                              queryParameters: {
                                                                'user':
                                                                    serializeParam(
                                                                  bigUsersRecord,
                                                                  ParamType
                                                                      .Document,
                                                                ),
                                                              }.withoutNulls,
                                                              extra: <String,
                                                                  dynamic>{
                                                                'user':
                                                                    bigUsersRecord,
                                                              },
                                                            );
                                                          },
                                                          child:
                                                              PopupMenuButton<
                                                                  String>(
                                                            icon: Icon(
                                                              Icons.more_vert,
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .primaryText,
                                                              size: 24.0,
                                                            ),
                                                            onSelected: (String
                                                                value) async {
                                                              if (value ==
                                                                  'block') {
                                                                // Show confirmation dialog
                                                                final shouldBlock =
                                                                    await showDialog<
                                                                        bool>(
                                                                  context:
                                                                      context,
                                                                  builder:
                                                                      (BuildContext
                                                                          context) {
                                                                    return AlertDialog(
                                                                      title: Text(
                                                                          'Block User'),
                                                                      content: Text(
                                                                          'Are you sure you want to block this user? You will no longer see their messages or be able to contact them.'),
                                                                      actions: [
                                                                        TextButton(
                                                                          onPressed: () =>
                                                                              Navigator.of(context).pop(false),
                                                                          child:
                                                                              Text('Cancel'),
                                                                        ),
                                                                        TextButton(
                                                                          onPressed: () =>
                                                                              Navigator.of(context).pop(true),
                                                                          child:
                                                                              Text(
                                                                            'Block',
                                                                            style:
                                                                                TextStyle(color: Colors.red),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    );
                                                                  },
                                                                );

                                                                if (shouldBlock ==
                                                                    true) {
                                                                  // Create blocked user record
                                                                  await BlockedUsersRecord
                                                                      .collection
                                                                      .add({
                                                                    ...createBlockedUsersRecordData(
                                                                      blockerUser:
                                                                          currentUserReference,
                                                                      blockedUser:
                                                                          bigUsersRecord
                                                                              .reference,
                                                                      createdAt:
                                                                          getCurrentTimestamp,
                                                                    ),
                                                                  });

                                                                  // Show success message and go back
                                                                  ScaffoldMessenger.of(
                                                                          context)
                                                                      .showSnackBar(
                                                                    SnackBar(
                                                                        content:
                                                                            Text('User has been blocked')),
                                                                  );
                                                                  context
                                                                      .safePop();
                                                                }
                                                              } else if (value ==
                                                                  'profile') {
                                                                context
                                                                    .pushNamed(
                                                                  'Profile',
                                                                  queryParameters:
                                                                      {
                                                                    'userRef':
                                                                        serializeParam(
                                                                      bigUsersRecord
                                                                          .reference,
                                                                      ParamType
                                                                          .DocumentReference,
                                                                    ),
                                                                  }.withoutNulls,
                                                                  extra: <String,
                                                                      dynamic>{
                                                                    'user':
                                                                        bigUsersRecord,
                                                                  },
                                                                );
                                                              }
                                                            },
                                                            itemBuilder: (BuildContext
                                                                    context) =>
                                                                <PopupMenuEntry<
                                                                    String>>[
                                                              PopupMenuItem<
                                                                  String>(
                                                                value:
                                                                    'profile',
                                                                child: Row(
                                                                  children: [
                                                                    Icon(
                                                                        Icons
                                                                            .person,
                                                                        size:
                                                                            20),
                                                                    SizedBox(
                                                                        width:
                                                                            8),
                                                                    Text(
                                                                        'View Profile'),
                                                                  ],
                                                                ),
                                                              ),
                                                              PopupMenuItem<
                                                                  String>(
                                                                value: 'block',
                                                                child: Row(
                                                                  children: [
                                                                    Icon(
                                                                        Icons
                                                                            .block,
                                                                        color: Colors
                                                                            .red,
                                                                        size:
                                                                            20),
                                                                    SizedBox(
                                                                        width:
                                                                            8),
                                                                    Text(
                                                                      'Block User',
                                                                      style: TextStyle(
                                                                          color:
                                                                              Colors.red),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                return Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        GestureDetector(
                                                          onTap: () {
                                                            context.goNamed(
                                                              ChatWidget
                                                                  .routeName,
                                                              extra: <String,
                                                                  dynamic>{
                                                                kTransitionInfoKey:
                                                                    TransitionInfo(
                                                                  hasTransition:
                                                                      true,
                                                                  transitionType:
                                                                      PageTransitionType
                                                                          .fade,
                                                                  duration: Duration(
                                                                      milliseconds:
                                                                          0),
                                                                ),
                                                              },
                                                            );
                                                          },
                                                          child: Icon(
                                                            CupertinoIcons
                                                                .chevron_left,
                                                            color:
                                                                CupertinoColors
                                                                    .systemBlue,
                                                            size: 28.0,
                                                          ),
                                                        ),
                                                        Column(
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              chatDetailChatsRecord
                                                                  .title,
                                                              style: FlutterFlowTheme
                                                                      .of(context)
                                                                  .titleMedium
                                                                  .override(
                                                                    font: GoogleFonts
                                                                        .inter(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .titleMedium
                                                                          .fontStyle,
                                                                    ),
                                                                    color: Color(
                                                                        0xFF1F2937),
                                                                    fontSize:
                                                                        18.0,
                                                                    letterSpacing:
                                                                        0.0,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .titleMedium
                                                                        .fontStyle,
                                                                  ),
                                                            ),
                                                            Text(
                                                              chatDetailChatsRecord
                                                                  .description
                                                                  .maybeHandleOverflow(
                                                                maxChars: 30,
                                                              ),
                                                              style: FlutterFlowTheme
                                                                      .of(context)
                                                                  .bodySmall
                                                                  .override(
                                                                    font: GoogleFonts
                                                                        .inter(
                                                                      fontWeight: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodySmall
                                                                          .fontWeight,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodySmall
                                                                          .fontStyle,
                                                                    ),
                                                                    color: Color(
                                                                        0xFF6B7280),
                                                                    fontSize:
                                                                        12.0,
                                                                    letterSpacing:
                                                                        0.0,
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodySmall
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodySmall
                                                                        .fontStyle,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ].divide(SizedBox(
                                                          width: 16.0)),
                                                    ),
                                                    PopupMenuButton<String>(
                                                      child: Container(
                                                        padding:
                                                            EdgeInsets.all(8.0),
                                                        child: Icon(
                                                          Platform.isIOS
                                                              ? CupertinoIcons
                                                                  .ellipsis
                                                              : Icons.more_vert,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          size: 24.0,
                                                        ),
                                                      ),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                Platform.isIOS
                                                                    ? 12.0
                                                                    : 10.0),
                                                      ),
                                                      color: Platform.isIOS
                                                          ? Colors.white
                                                          : FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryBackground,
                                                      elevation: Platform.isIOS
                                                          ? 8
                                                          : 6,
                                                      padding: EdgeInsets.zero,
                                                      offset: Offset(
                                                          0,
                                                          Platform.isIOS
                                                              ? 8
                                                              : 4),
                                                      onOpened: () {
                                                        print(
                                                            '🔵🔵🔵 3-dot menu button TAPPED - Menu opened!');
                                                        debugPrint(
                                                            '🔵🔵🔵 3-dot menu button TAPPED - Menu opened!');
                                                        if (Platform.isIOS) {
                                                          HapticFeedback
                                                              .mediumImpact();
                                                        }
                                                      },
                                                      onCanceled: () {
                                                        print(
                                                            '🔵 Menu canceled');
                                                      },
                                                      onSelected:
                                                          (String value) async {
                                                        print(
                                                            '🔵 Menu item selected: $value');
                                                        if (Platform.isIOS) {
                                                          HapticFeedback
                                                              .selectionClick();
                                                        }
                                                        if (value ==
                                                            'add_members') {
                                                          print(
                                                              '🔵 Navigating to add members');
                                                          // Navigate to group detail to add members
                                                          context.pushNamed(
                                                            GroupChatDetailWidget
                                                                .routeName,
                                                            queryParameters: {
                                                              'chatDoc':
                                                                  serializeParam(
                                                                chatDetailChatsRecord,
                                                                ParamType
                                                                    .Document,
                                                              ),
                                                            }.withoutNulls,
                                                            extra: <String,
                                                                dynamic>{
                                                              'chatDoc':
                                                                  chatDetailChatsRecord,
                                                            },
                                                          );
                                                        } else if (value ==
                                                            'media') {
                                                          // Navigate to group detail with media view
                                                          context.pushNamed(
                                                            GroupChatDetailWidget
                                                                .routeName,
                                                            queryParameters: {
                                                              'chatDoc':
                                                                  serializeParam(
                                                                chatDetailChatsRecord,
                                                                ParamType
                                                                    .Document,
                                                              ),
                                                            }.withoutNulls,
                                                            extra: <String,
                                                                dynamic>{
                                                              'chatDoc':
                                                                  chatDetailChatsRecord,
                                                            },
                                                          );
                                                        } else if (value ==
                                                            'group_info') {
                                                          // Navigate to group detail
                                                          context.pushNamed(
                                                            GroupChatDetailWidget
                                                                .routeName,
                                                            queryParameters: {
                                                              'chatDoc':
                                                                  serializeParam(
                                                                chatDetailChatsRecord,
                                                                ParamType
                                                                    .Document,
                                                              ),
                                                            }.withoutNulls,
                                                            extra: <String,
                                                                dynamic>{
                                                              'chatDoc':
                                                                  chatDetailChatsRecord,
                                                            },
                                                          );
                                                        } else if (value ==
                                                            'search') {
                                                          // Navigate to group detail for search
                                                          context.pushNamed(
                                                            GroupChatDetailWidget
                                                                .routeName,
                                                            queryParameters: {
                                                              'chatDoc':
                                                                  serializeParam(
                                                                chatDetailChatsRecord,
                                                                ParamType
                                                                    .Document,
                                                              ),
                                                            }.withoutNulls,
                                                            extra: <String,
                                                                dynamic>{
                                                              'chatDoc':
                                                                  chatDetailChatsRecord,
                                                            },
                                                          );
                                                        }
                                                      },
                                                      itemBuilder: (BuildContext
                                                              context) =>
                                                          [
                                                        PopupMenuItem<String>(
                                                          value: 'add_members',
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Platform.isIOS
                                                                    ? CupertinoIcons
                                                                        .person_add
                                                                    : Icons
                                                                        .person_add,
                                                                size: 20,
                                                                color: Platform
                                                                        .isIOS
                                                                    ? Colors
                                                                        .black87
                                                                    : FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                              ),
                                                              SizedBox(
                                                                  width: 12),
                                                              Text(
                                                                'Add Members',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize:
                                                                      Platform.isIOS
                                                                          ? 16
                                                                          : 14,
                                                                  color: Platform
                                                                          .isIOS
                                                                      ? Colors
                                                                          .black87
                                                                      : FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryText,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        PopupMenuItem<String>(
                                                          value: 'media',
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Platform.isIOS
                                                                    ? CupertinoIcons
                                                                        .photo_on_rectangle
                                                                    : Icons
                                                                        .photo_library,
                                                                size: 20,
                                                                color: Platform
                                                                        .isIOS
                                                                    ? Colors
                                                                        .black87
                                                                    : FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                              ),
                                                              SizedBox(
                                                                  width: 12),
                                                              Text(
                                                                'Media',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize:
                                                                      Platform.isIOS
                                                                          ? 16
                                                                          : 14,
                                                                  color: Platform
                                                                          .isIOS
                                                                      ? Colors
                                                                          .black87
                                                                      : FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryText,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        PopupMenuItem<String>(
                                                          value: 'search',
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Platform.isIOS
                                                                    ? CupertinoIcons
                                                                        .search
                                                                    : Icons
                                                                        .search,
                                                                size: 20,
                                                                color: Platform
                                                                        .isIOS
                                                                    ? Colors
                                                                        .black87
                                                                    : FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                              ),
                                                              SizedBox(
                                                                  width: 12),
                                                              Text(
                                                                'Search',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize:
                                                                      Platform.isIOS
                                                                          ? 16
                                                                          : 14,
                                                                  color: Platform
                                                                          .isIOS
                                                                      ? Colors
                                                                          .black87
                                                                      : FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryText,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        PopupMenuItem<String>(
                                                          value: 'group_info',
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Platform.isIOS
                                                                    ? CupertinoIcons
                                                                        .info_circle
                                                                    : Icons
                                                                        .info_outline,
                                                                size: 20,
                                                                color: Platform
                                                                        .isIOS
                                                                    ? Colors
                                                                        .black87
                                                                    : FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                              ),
                                                              SizedBox(
                                                                  width: 12),
                                                              Text(
                                                                'Group Info',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize:
                                                                      Platform.isIOS
                                                                          ? 16
                                                                          : 14,
                                                                  color: Platform
                                                                          .isIOS
                                                                      ? Colors
                                                                          .black87
                                                                      : FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryText,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_model.loading == true)
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: Color(0xFFF9FAFB),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(55.0),
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            child: custom_widgets.FFlowSpinner(
                              width: double.infinity,
                              height: double.infinity,
                              backgroundColor: Colors.transparent,
                              spinnerColor:
                                  FlutterFlowTheme.of(context).primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
