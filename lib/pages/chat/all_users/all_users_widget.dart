import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/component/attendee_list/attendee_list_widget.dart';
import '/component/empty_friend_list/empty_friend_list_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:math';
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'all_users_model.dart';
export 'all_users_model.dart';

/// Pending Requests and Contacts List
class AllUsersWidget extends StatefulWidget {
  const AllUsersWidget({super.key});

  static String routeName = 'AllUsers';
  static String routePath = '/allUsers';

  @override
  State<AllUsersWidget> createState() => _AllUsersWidgetState();
}

class _AllUsersWidgetState extends State<AllUsersWidget>
    with TickerProviderStateMixin {
  late AllUsersModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final animationsMap = <String, AnimationInfo>{};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AllUsersModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.users = await queryUsersRecordOnce();
      _model.addToMember(currentUserReference!);
      safeSetState(() {});
      _model.usersDoc = _model.users!.toList().cast<UsersRecord>();
      safeSetState(() {});
    });

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

    animationsMap.addAll({
      'columnOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: const Offset(0.0, 30.0),
            end: const Offset(0.0, 0.0),
          ),
        ],
      ),
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFFF9FAFB),
        body: SafeArea(
          top: true,
          child: Align(
            alignment: const AlignmentDirectional(0.0, -1.0),
            child: Container(
              height: double.infinity,
              constraints: const BoxConstraints(
                maxWidth: 650.0,
                maxHeight: double.infinity,
              ),
              decoration: const BoxDecoration(),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 0.0, 0.0),
                      child: InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          context.safePop();
                        },
                        child: Icon(
                          Icons.chevron_left,
                          color: FlutterFlowTheme.of(context).primary,
                          size: 32.0,
                        ),
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: TextFormField(
                          controller: _model.textController,
                          focusNode: _model.textFieldFocusNode,
                          onChanged: (_) => EasyDebounce.debounce(
                            '_model.textController',
                            const Duration(milliseconds: 300),
                            () async {
                              _model.usersDoc = _model.users!
                                  .where((e) =>
                                      functions.textContaintext(e.displayName,
                                          _model.textController.text) ||
                                      functions.textContaintext(e.email,
                                          _model.textController.text) ||
                                      functions.textContaintext(
                                          e.bio, _model.textController.text))
                                  .toList()
                                  .cast<UsersRecord>();
                              safeSetState(() {});
                            },
                          ),
                          onFieldSubmitted: (_) async {
                            FFAppState().addToSearchUsersHistory(
                                _model.textController.text);
                            safeSetState(() {});
                          },
                          autofocus: false,
                          obscureText: false,
                          decoration: InputDecoration(
                            isDense: false,
                            hintText: 'Search',
                            hintStyle: FlutterFlowTheme.of(context)
                                .labelMedium
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontStyle,
                                  ),
                                  color: FlutterFlowTheme.of(context).accent2,
                                  fontSize: 16.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontStyle,
                                ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).accent2,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).accent2,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).error,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).error,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF3F4F6),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF9CA3AF),
                              size: 20.0,
                            ),
                          ),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                          cursorColor: FlutterFlowTheme.of(context).primaryText,
                          validator: _model.textControllerValidator
                              .asValidator(context),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (FFAppState().searchUsersHistory.isNotEmpty)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                16.0, 0.0, 0.0, 12.0),
                            child: Text(
                              'Search History',
                              style: FlutterFlowTheme.of(context)
                                  .labelMedium
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.normal,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontStyle,
                                    ),
                                    color: const Color(0xFF6B7280),
                                    fontSize: 12.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontStyle,
                                  ),
                            ),
                          ),
                        Builder(
                          builder: (context) {
                            final userNameHistory =
                                FFAppState().searchUsersHistory.toList();

                            return Column(
                              mainAxisSize: MainAxisSize.max,
                              children: List.generate(userNameHistory.length,
                                  (userNameHistoryIndex) {
                                final userNameHistoryItem =
                                    userNameHistory[userNameHistoryIndex];
                                return Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                      16.0, 0.0, 15.0, 0.0),
                                  child: InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      safeSetState(() {
                                        _model.textController?.text =
                                            userNameHistoryItem;
                                      });
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          userNameHistoryItem,
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                ),
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                        ),
                                        InkWell(
                                          splashColor: Colors.transparent,
                                          focusColor: Colors.transparent,
                                          hoverColor: Colors.transparent,
                                          highlightColor: Colors.transparent,
                                          onTap: () async {
                                            FFAppState()
                                                .removeFromSearchUsersHistory(
                                                    userNameHistoryItem);
                                            safeSetState(() {});
                                          },
                                          child: Icon(
                                            Icons.close,
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            size: 24.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).divide(const SizedBox(height: 5.0)),
                            );
                          },
                        ),
                      ],
                    ),
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF9FAFB),
                        ),
                        child: Builder(
                          builder: (context) {
                            final allUsersVar = _model.usersDoc.toList();
                            if (allUsersVar.isEmpty) {
                              return const EmptyFriendListWidget(
                                title: 'No Account Found',
                                description:
                                    'We couldn\'t find any accounts matching your search.',
                              );
                            }

                            return Column(
                              mainAxisSize: MainAxisSize.max,
                              children: List.generate(allUsersVar.length,
                                  (allUsersVarIndex) {
                                final allUsersVarItem =
                                    allUsersVar[allUsersVarIndex];
                                return Visibility(
                                  visible: allUsersVarItem.reference !=
                                      currentUserReference,
                                  child: AuthUserStreamWidget(
                                    builder: (context) => wrapWithModel(
                                      model: _model.attendeeListModels.getModel(
                                        allUsersVarItem.reference.id,
                                        allUsersVarIndex,
                                      ),
                                      updateCallback: () => safeSetState(() {}),
                                      child: AttendeeListWidget(
                                        key: Key(
                                          'Keys62_${allUsersVarItem.reference.id}',
                                        ),
                                        image: allUsersVarItem.photoUrl,
                                        name: allUsersVarItem.displayName,
                                        bio: allUsersVarItem.bio,
                                        isMutual: (currentUserDocument?.friends
                                                    .toList() ??
                                                [])
                                            .contains(
                                                allUsersVarItem.reference),
                                        isClick: (currentUserDocument
                                                    ?.sentRequests
                                                    .toList() ??
                                                [])
                                            .contains(
                                                allUsersVarItem.reference),
                                        user: allUsersVarItem,
                                        addFriend: () async {
                                          await currentUserReference!.update({
                                            ...mapToFirestore(
                                              {
                                                'sent_requests':
                                                    FieldValue.arrayUnion([
                                                  allUsersVarItem.reference
                                                ]),
                                              },
                                            ),
                                          });

                                          await allUsersVarItem.reference
                                              .update({
                                            ...mapToFirestore(
                                              {
                                                'friend_requests':
                                                    FieldValue.arrayUnion(
                                                        [currentUserReference]),
                                              },
                                            ),
                                          });
                                        },
                                        removeRequest: () async {
                                          await currentUserReference!.update({
                                            ...mapToFirestore(
                                              {
                                                'sent_requests':
                                                    FieldValue.arrayRemove([
                                                  allUsersVarItem.reference
                                                ]),
                                              },
                                            ),
                                          });

                                          await allUsersVarItem.reference
                                              .update({
                                            ...mapToFirestore(
                                              {
                                                'friend_requests':
                                                    FieldValue.arrayRemove(
                                                        [currentUserReference]),
                                              },
                                            ),
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              }).divide(
                                const SizedBox(height: 16.0),
                                filterFn: (allUsersVarIndex) {
                                  final allUsersVarItem =
                                      allUsersVar[allUsersVarIndex];
                                  return allUsersVarItem.reference !=
                                      currentUserReference;
                                },
                              ),
                            ).animateOnPageLoad(
                                animationsMap['columnOnPageLoadAnimation']!);
                          },
                        ),
                      ),
                    ),
                  ]
                      .divide(const SizedBox(height: 16.0))
                      .addToStart(const SizedBox(height: 16.0))
                      .addToEnd(const SizedBox(height: 24.0)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
