import '/auth/base_auth_user_provider.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/component/empty_schedule/empty_schedule_widget.dart';
import '/components/congratulatio_acc_creation_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/event/event_component/event_component_widget.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/permissions_util.dart';
import '/index.dart';
import 'package:branchio_dynamic_linking_akp5u6/custom_code/actions/index.dart'
    as branchio_dynamic_linking_akp5u6_actions;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'discover_model.dart';
export 'discover_model.dart';

/// Event Discovery and Listings
class DiscoverWidget extends StatefulWidget {
  const DiscoverWidget({
    super.key,
    bool? isDeeplink,
  }) : this.isDeeplink = isDeeplink ?? false;

  final bool isDeeplink;

  static String routeName = 'Discover';
  static String routePath = '/discover';

  @override
  State<DiscoverWidget> createState() => _DiscoverWidgetState();
}

class _DiscoverWidgetState extends State<DiscoverWidget>
    with TickerProviderStateMixin {
  late DiscoverModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final animationsMap = <String, AnimationInfo>{};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DiscoverModel());

    // On page load action.
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
      if (loggedIn) {
        unawaited(
          () async {
            _model.isSuccess = await actions.ensureFcmToken(
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
      if (widget!.isDeeplink == true) {
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
                child: CongratulatioAccCreationWidget(
                  action: () async {
                    Navigator.pop(context);
                  },
                ),
              ),
            );
          },
        );
      }
      await branchio_dynamic_linking_akp5u6_actions.handleBranchDeeplink(
        (linkData) async {
          _model.data = await actions.checkEventInvite(
            linkData,
          );
          FFAppState().DeeplinkInfo = _model.data!;
          FFAppState().update(() {});
          if (loggedIn) {
            context.goNamed(
              EventDetailWidget.routeName,
              pathParameters: {
                'eventId': serializeParam(
                  FFAppState().DeeplinkInfo.eventId,
                  ParamType.String,
                ),
              }.withoutNulls,
            );
          } else {
            context.pushNamed(
              InvitationCodeWidget.routeName,
              queryParameters: {
                'isDeeplink': serializeParam(
                  true,
                  ParamType.bool,
                ),
              }.withoutNulls,
            );
          }
        },
      );
      await action_blocks.homeCheck(context);
      if (!(await getPermissionStatus(locationPermission))) {
        await requestPermission(locationPermission);
      }
    });

    _model.tabBarController = TabController(
      vsync: this,
      length: 1, // Changed from 2 to 1 since we only have one tab now
      initialIndex: 0,
    )..addListener(() => safeSetState(() {}));

    animationsMap.addAll({
      'rowOnPageLoadAnimation': AnimationInfo(
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
      'tabBarOnPageLoadAnimation': AnimationInfo(
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
      'columnOnPageLoadAnimation1': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: Offset(0.0, 30.0),
            end: Offset(0.0, 0.0),
          ),
        ],
      ),
      'columnOnPageLoadAnimation2': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 50.0.ms,
            duration: 600.0.ms,
            begin: Offset(0.0, 50.0),
            end: Offset(0.0, 0.0),
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

    return Builder(
      builder: (context) => StreamBuilder<List<EventsRecord>>(
        stream: queryEventsRecord(),
        builder: (context, snapshot) {
          // Customize what your widget looks like when it's loading.
          if (!snapshot.hasData) {
            return Scaffold(
              backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
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
          List<EventsRecord> discoverEventsRecordList = snapshot.data!;

          return GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: PopScope(
              canPop: false,
              child: Scaffold(
                key: scaffoldKey,
                backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
                floatingActionButton: FloatingActionButton(
                  onPressed: () async {
                    context.pushNamed(QRScanPageWidget.routeName);
                  },
                  backgroundColor: FlutterFlowTheme.of(context).primary,
                  elevation: 8.0,
                  child: Icon(
                    Icons.qr_code_sharp,
                    color: FlutterFlowTheme.of(context).info,
                    size: 24.0,
                  ),
                ),
                body: Align(
                  alignment: AlignmentDirectional(0.0, 0.0),
                  child: Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 50.0, 0.0, 0.0),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: 650.0,
                      ),
                      decoration: BoxDecoration(),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              context.pushNamed(SearchWidget.routeName);
                            },
                            child: Container(
                              decoration: BoxDecoration(),
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    16.0, 0.0, 16.0, 0.0),
                                child: Container(
                                  width: 100.0,
                                  height: 50.0,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(
                                      color:
                                          FlutterFlowTheme.of(context).accent2,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        FaIcon(
                                          FontAwesomeIcons.search,
                                          color: FlutterFlowTheme.of(context)
                                              .accent2,
                                          size: 20.0,
                                        ),
                                        Text(
                                          'Search',
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w500,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .accent2,
                                                fontSize: 16.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w500,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                        ),
                                      ].divide(SizedBox(width: 12.0)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                16.0, 0.0, 16.0, 0.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                FFButtonWidget(
                                  onPressed: () async {
                                    context.pushNamed(SearchWidget.routeName);
                                  },
                                  text: 'All Event',
                                  options: FFButtonOptions(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        12.0, 8.0, 12.0, 8.0),
                                    iconPadding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 0.0),
                                    color: FlutterFlowTheme.of(context).primary,
                                    textStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.normal,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.normal,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontStyle,
                                        ),
                                    elevation: 0.0,
                                    borderRadius: BorderRadius.circular(14.0),
                                  ),
                                ),
                                FFButtonWidget(
                                  onPressed: () async {
                                    context.pushNamed(SearchWidget.routeName);
                                  },
                                  text: 'Today',
                                  icon: Icon(
                                    Icons.calendar_today,
                                    size: 12.0,
                                  ),
                                  options: FFButtonOptions(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        12.0, 8.0, 12.0, 8.0),
                                    iconPadding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 0.0),
                                    iconColor: Color(0xFF374151),
                                    color: Color(0xFFE5E7EB),
                                    textStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.w500,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontStyle,
                                          ),
                                          color: Color(0xFF374151),
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w500,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontStyle,
                                        ),
                                    elevation: 0.0,
                                    borderRadius: BorderRadius.circular(14.0),
                                  ),
                                ),
                                FFButtonWidget(
                                  onPressed: () async {
                                    if (_model.tabBarCurrentIndex == 1) {
                                      context.pushNamed(
                                          SearchChatWidget.routeName);
                                    } else {
                                      context.pushNamed(SearchWidget.routeName);
                                    }
                                  },
                                  text: 'Filter',
                                  icon: Icon(
                                    Icons.filter_list,
                                    size: 12.0,
                                  ),
                                  options: FFButtonOptions(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        12.0, 8.0, 12.0, 8.0),
                                    iconPadding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 0.0),
                                    iconColor: Color(0xFF374151),
                                    color: Color(0xFFE5E7EB),
                                    textStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.w500,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontStyle,
                                          ),
                                          color: Color(0xFF374151),
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w500,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontStyle,
                                        ),
                                    elevation: 0.0,
                                    borderRadius: BorderRadius.circular(14.0),
                                  ),
                                ),
                              ].divide(SizedBox(width: 12.0)),
                            ).animateOnPageLoad(
                                animationsMap['rowOnPageLoadAnimation']!),
                          ),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(),
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    20.0, 0.0, 20.0, 0.0),
                                child: Column(
                                  children: [
                                    Align(
                                      alignment: Alignment(0.0, 0),
                                      child: TabBar(
                                        labelColor:
                                            FlutterFlowTheme.of(context)
                                                .primary,
                                        unselectedLabelColor:
                                            FlutterFlowTheme.of(context)
                                                .secondaryText,
                                        labelStyle: FlutterFlowTheme.of(
                                                context)
                                            .titleMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.w500,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .titleMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w500,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleMedium
                                                      .fontStyle,
                                            ),
                                        unselectedLabelStyle:
                                            FlutterFlowTheme.of(context)
                                                .titleMedium
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w500,
                                                    fontStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .titleMedium
                                                        .fontStyle,
                                                  ),
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.w500,
                                                  fontStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .titleMedium
                                                      .fontStyle,
                                                ),
                                        indicatorColor:
                                            FlutterFlowTheme.of(context)
                                                .primary,
                                        tabs: [
                                          // Tab(
                                          //   text: 'Events',
                                          // ),
                                          Tab(
                                            text: 'Group Chats',
                                          ),
                                        ],
                                        controller: _model.tabBarController,
                                        onTap: (i) async {
                                          [() async {}, () async {}][i]();
                                        },
                                      ),
                                    ),
                                    Expanded(
                                      child: TabBarView(
                                        controller: _model.tabBarController,
                                        children: [
                                          // START OF COMMENTED OUT EVENTS CONTENT
                                          // SingleChildScrollView(
                                          //   child: Column(
                                          //     mainAxisSize: MainAxisSize.max,
                                          //     children: [
                                          //       Column(
                                          //         mainAxisSize:
                                          //             MainAxisSize.max,
                                          //         crossAxisAlignment:
                                          //             CrossAxisAlignment
                                          //                 .stretch,
                                          //         children: [
                                          //           Text(
                                          //             'Trending Events',
                                          //             style: FlutterFlowTheme
                                          //                     .of(context)
                                          //                 .titleLarge
                                          //                 .override(
                                          //                   font: GoogleFonts
                                          //                       .inter(
                                          //                     fontWeight:
                                          //                         FontWeight
                                          //                             .w600,
                                          //                     fontStyle:
                                          //                         FlutterFlowTheme.of(
                                          //                                 context)
                                          //                             .titleLarge
                                          //                             .fontStyle,
                                          //                   ),
                                          //                   fontSize: 18.0,
                                          //                   letterSpacing: 0.0,
                                          //                   fontWeight:
                                          //                       FontWeight.w600,
                                          //                   fontStyle:
                                          //                       FlutterFlowTheme.of(
                                          //                               context)
                                          //                           .titleLarge
                                          //                           .fontStyle,
                                          //                 ),
                                          //           ),
                                          //           Builder(
                                          //             builder: (context) {
                                          //               final trending =
                                          //                   discoverEventsRecordList
                                          //                       .where((e) =>
                                          //                           e.isTrending ==
                                          //                           true)
                                          //                       .toList();
                                          //               if (trending.isEmpty) {
                                          //                 return EmptyScheduleWidget(
                                          //                   title:
                                          //                       'No Trending Events',
                                          //                   description:
                                          //                       'Nothing’s trending just yet… maybe it’s waiting for you to spark it.',
                                          //                   icon: Icon(
                                          //                     Icons.star,
                                          //                     size: 48.0,
                                          //                   ),
                                          //                 );
                                          //               }

                                          //               return SingleChildScrollView(
                                          //                 scrollDirection:
                                          //                     Axis.horizontal,
                                          //                 child: Row(
                                          //                   mainAxisSize:
                                          //                       MainAxisSize
                                          //                           .max,
                                          //                   mainAxisAlignment:
                                          //                       MainAxisAlignment
                                          //                           .center,
                                          //                   children: List.generate(
                                          //                       trending.length,
                                          //                       (trendingIndex) {
                                          //                     final trendingItem =
                                          //                         trending[
                                          //                             trendingIndex];
                                          //                     return EventComponentWidget(
                                          //                       key: Key(
                                          //                           'Key2d4_${trendingIndex}_of_${trending.length}'),
                                          //                       imageCover:
                                          //                           valueOrDefault<
                                          //                               String>(
                                          //                         trendingItem
                                          //                             .coverImageUrl,
                                          //                         'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fevent.jpg?alt=media&token=3e30709d-40ff-4e86-a702-5c9c2068fa8d',
                                          //                       ),
                                          //                       category:
                                          //                           trendingItem
                                          //                               .category
                                          //                               .firstOrNull,
                                          //                       nameEvent:
                                          //                           trendingItem
                                          //                               .title,
                                          //                       date: dateTimeFormat(
                                          //                           "yMMMd",
                                          //                           trendingItem
                                          //                               .startDate!),
                                          //                       time: dateTimeFormat(
                                          //                           "jm",
                                          //                           trendingItem
                                          //                               .startDate!),
                                          //                       location:
                                          //                           trendingItem
                                          //                               .location,
                                          //                       participant:
                                          //                           trendingItem
                                          //                               .participants
                                          //                               .length,
                                          //                       speakers:
                                          //                           trendingItem
                                          //                               .speakers,
                                          //                       eventRef:
                                          //                           trendingItem
                                          //                               .reference,
                                          //                       eventBriteId:
                                          //                           trendingItem
                                          //                               .eventbriteId,
                                          //                       action:
                                          //                           () async {
                                          //                         context
                                          //                             .pushNamed(
                                          //                           EventDetailWidget
                                          //                               .routeName,
                                          //                           pathParameters:
                                          //                               {
                                          //                             'eventId':
                                          //                                 serializeParam(
                                          //                               trendingItem
                                          //                                   .eventId,
                                          //                               ParamType
                                          //                                   .String,
                                          //                             ),
                                          //                           }.withoutNulls,
                                          //                         );
                                          //                       },
                                          //                     );
                                          //                   }),
                                          //                 ),
                                          //               );
                                          //             },
                                          //           ),
                                          //         ].divide(
                                          //             SizedBox(height: 16.0)),
                                          //       ).animateOnPageLoad(animationsMap[
                                          //           'columnOnPageLoadAnimation1']!),
                                          //       Column(
                                          //         mainAxisSize:
                                          //             MainAxisSize.max,
                                          //         crossAxisAlignment:
                                          //             CrossAxisAlignment
                                          //                 .stretch,
                                          //         children: [
                                          //           Text(
                                          //             'Nearby Events',
                                          //             style: FlutterFlowTheme
                                          //                     .of(context)
                                          //                 .titleLarge
                                          //                 .override(
                                          //                   font: GoogleFonts
                                          //                       .inter(
                                          //                     fontWeight:
                                          //                         FontWeight
                                          //                             .w600,
                                          //                     fontStyle:
                                          //                         FlutterFlowTheme.of(
                                          //                                 context)
                                          //                             .titleLarge
                                          //                             .fontStyle,
                                          //                   ),
                                          //                   fontSize: 18.0,
                                          //                   letterSpacing: 0.0,
                                          //                   fontWeight:
                                          //                       FontWeight.w600,
                                          //                   fontStyle:
                                          //                       FlutterFlowTheme.of(
                                          //                               context)
                                          //                           .titleLarge
                                          //                           .fontStyle,
                                          //                 ),
                                          //           ),
                                          //           Builder(
                                          //             builder: (context) {
                                          //               final allEvents =
                                          //                   discoverEventsRecordList
                                          //                       .sortedList(
                                          //                           keyOf: (e) =>
                                          //                               e.startDate!,
                                          //                           desc: true)
                                          //                       .toList();
                                          //               if (allEvents.isEmpty) {
                                          //                 return EmptyScheduleWidget(
                                          //                   title:
                                          //                       'No Nearby Events',
                                          //                   description:
                                          //                       'Nothing in your area yet but, maybe it’s time to start one?',
                                          //                   icon: Icon(
                                          //                     Icons
                                          //                         .share_location,
                                          //                     size: 48.0,
                                          //                   ),
                                          //                 );
                                          //               }

                                          //               return Column(
                                          //                 mainAxisSize:
                                          //                     MainAxisSize.max,
                                          //                 crossAxisAlignment:
                                          //                     CrossAxisAlignment
                                          //                         .stretch,
                                          //                 children: List.generate(
                                          //                         allEvents
                                          //                             .length,
                                          //                         (allEventsIndex) {
                                          //                   final allEventsItem =
                                          //                       allEvents[
                                          //                           allEventsIndex];
                                          //                   return wrapWithModel(
                                          //                     model: _model
                                          //                         .eventComponentModels2
                                          //                         .getModel(
                                          //                           allEventsItem
                                          //                               .reference
                                          //                               .id,
                                          //                           allEventsIndex,
                                          //                         ),
                                          //                     updateCallback: () =>
                                          //                         safeSetState(
                                          //                             () {}),
                                          //                     child:
                                          //                         EventComponentWidget(
                                          //                       key: Key(
                                          //                         'Keysys_${allEventsItem.reference.id}',
                                          //                       ),
                                          //                       imageCover:
                                          //                           valueOrDefault<
                                          //                               String>(
                                          //                         allEventsItem
                                          //                             .coverImageUrl,
                                          //                         'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fevent.jpg?alt=media&token=3e30709d-40ff-4e86-a702-5c9c2068fa8d',
                                          //                       ),
                                          //                       category:
                                          //                           valueOrDefault<
                                          //                               String>(
                                          //                         allEventsItem
                                          //                             .category
                                          //                             .firstOrNull,
                                          //                         'Tech',
                                          //                       ),
                                          //                       nameEvent:
                                          //                           allEventsItem
                                          //                               .title,
                                          //                       date: dateTimeFormat(
                                          //                           "yMMMd",
                                          //                           allEventsItem
                                          //                               .startDate!),
                                          //                       time: dateTimeFormat(
                                          //                           "jm",
                                          //                           allEventsItem
                                          //                               .startDate!),
                                          //                       location:
                                          //                           allEventsItem
                                          //                               .location,
                                          //                       participant:
                                          //                           allEventsItem
                                          //                               .participants
                                          //                               .length,
                                          //                       speakers:
                                          //                           allEventsItem
                                          //                               .speakers,
                                          //                       eventRef:
                                          //                           allEventsItem
                                          //                               .reference,
                                          //                       eventBriteId:
                                          //                           allEventsItem
                                          //                               .eventbriteId,
                                          //                       action:
                                          //                           () async {
                                          //                         context
                                          //                             .pushNamed(
                                          //                           EventDetailWidget
                                          //                               .routeName,
                                          //                           pathParameters:
                                          //                               {
                                          //                             'eventId':
                                          //                                 serializeParam(
                                          //                               allEventsItem
                                          //                                   .eventId,
                                          //                               ParamType
                                          //                                   .String,
                                          //                             ),
                                          //                           }.withoutNulls,
                                          //                         );
                                          //                       },
                                          //                     ),
                                          //                   );
                                          //                 })
                                          //                     .divide(SizedBox(
                                          //                         height: 14.0))
                                          //                     .addToEnd(SizedBox(
                                          //                         height:
                                          //                             24.0)),
                                          //               );
                                          //             },
                                          //           ),
                                          //         ].divide(
                                          //             SizedBox(height: 16.0)),
                                          //       ).animateOnPageLoad(animationsMap[
                                          //           'columnOnPageLoadAnimation2']!),
                                          //     ]
                                          //         .divide(
                                          //             SizedBox(height: 24.0))
                                          //         .addToStart(
                                          //             SizedBox(height: 24.0))
                                          //         .addToEnd(
                                          //             SizedBox(height: 36.0)),
                                          //   ),
                                          // ),
                                          // END OF COMMENTED OUT EVENTS CONTENT
                                          SingleChildScrollView(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          5.0, 0.0, 5.0, 0.0),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Text(
                                                            'All Group Chats',
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .headlineSmall
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .headlineSmall
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
                                                                      .headlineSmall
                                                                      .fontStyle,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      StreamBuilder<
                                                          List<ChatsRecord>>(
                                                        stream:
                                                            queryChatsRecord(
                                                          queryBuilder:
                                                              (chatsRecord) =>
                                                                  chatsRecord
                                                                      .where(
                                                            'is_group',
                                                            isEqualTo: true,
                                                          ),
                                                        ),
                                                        builder: (context,
                                                            snapshot) {
                                                          // Customize what your widget looks like when it's loading.
                                                          if (!snapshot
                                                              .hasData) {
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
                                                          List<ChatsRecord>
                                                              wrapChatsRecordList =
                                                              snapshot.data!;

                                                          return Wrap(
                                                            spacing: 15.0,
                                                            runSpacing: 15.0,
                                                            alignment:
                                                                WrapAlignment
                                                                    .start,
                                                            crossAxisAlignment:
                                                                WrapCrossAlignment
                                                                    .start,
                                                            direction:
                                                                Axis.horizontal,
                                                            runAlignment:
                                                                WrapAlignment
                                                                    .start,
                                                            verticalDirection:
                                                                VerticalDirection
                                                                    .down,
                                                            clipBehavior:
                                                                Clip.none,
                                                            children: List.generate(
                                                                wrapChatsRecordList
                                                                    .length,
                                                                (wrapIndex) {
                                                              final wrapChatsRecord =
                                                                  wrapChatsRecordList[
                                                                      wrapIndex];
                                                              return Material(
                                                                color: Colors
                                                                    .transparent,
                                                                elevation: 1.0,
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                    8.0),
                                                                ),
                                                                child:
                                                                    Container(
                                                                  width: 160.0,
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryBackground,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                      8.0),
                                                                  ),
                                                                  child:
                                                                      Padding(
                                                                    padding:
                                                                        EdgeInsets.all(
                                                                            8.0),
                                                                    child:
                                                                        Column(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .max,
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children:
                                                                          [
                                                                        Container(
                                                                          width:
                                                                              double.infinity,
                                                                          height:
                                                                              96.0,
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            color:
                                                                                Color(0xFFE0E7FF),
                                                                            image:
                                                                                DecorationImage(
                                                                              fit: BoxFit.cover,
                                                                              image: CachedNetworkImageProvider(
                                                                                valueOrDefault<String>(
                                                                                  wrapChatsRecord.chatImageUrl,
                                                                                  'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            borderRadius:
                                                                                BorderRadius.circular(8.0),
                                                                          ),
                                                                          child:
                                                                              Stack(
                                                                            children: [
                                                                              Align(
                                                                                alignment: AlignmentDirectional(1.0, -1.0),
                                                                                child: Container(
                                                                                  width: 8.0,
                                                                                  height: 8.0,
                                                                                  decoration: BoxDecoration(
                                                                                    color: Color(0xFF10B981),
                                                                                    shape: BoxShape.circle,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          wrapChatsRecord
                                                                              .title
                                                                              .maybeHandleOverflow(
                                                                            maxChars:
                                                                                20,
                                                                            replacement:
                                                                                '…',
                                                                          ),
                                                                          maxLines:
                                                                              1,
                                                                          style: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .override(
                                                                                font: GoogleFonts.inter(
                                                                                  fontWeight: FontWeight.w500,
                                                                                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                ),
                                                                                color: Color(0xFF1F2937),
                                                                                fontSize: 14.0,
                                                                                letterSpacing: 0.0,
                                                                                fontWeight: FontWeight.w500,
                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                              ),
                                                                        ),
                                                                        Row(
                                                                          mainAxisSize:
                                                                              MainAxisSize.max,
                                                                          children:
                                                                              [
                                                                            Icon(
                                                                              Icons.people,
                                                                              color: Color(0xFF4B5563),
                                                                              size: 15.0,
                                                                            ),
                                                                            RichText(
                                                                              textScaler: MediaQuery.of(context).textScaler,
                                                                              text: TextSpan(
                                                                                children: [
                                                                                  TextSpan(
                                                                                    text: valueOrDefault<String>(
                                                                                      wrapChatsRecord.members.length.toString(),
                                                                                      '0',
                                                                                    ),
                                                                                    style: TextStyle(),
                                                                                  ),
                                                                                  TextSpan(
                                                                                    text: ' members',
                                                                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                          font: GoogleFonts.inter(
                                                                                            fontWeight: FontWeight.normal,
                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                          ),
                                                                                          color: Color(0xFF4B5563),
                                                                                          fontSize: 12.0,
                                                                                          letterSpacing: 0.0,
                                                                                          fontWeight: FontWeight.normal,
                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                        ),
                                                                                  )
                                                                                ],
                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                      font: GoogleFonts.inter(
                                                                                        fontWeight: FontWeight.normal,
                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                      ),
                                                                                      color: Color(0xFF4B5563),
                                                                                      fontSize: 12.0,
                                                                                      letterSpacing: 0.0,
                                                                                      fontWeight: FontWeight.normal,
                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                    ),
                                                                              ),
                                                                            ),
                                                                          ].divide(SizedBox(width: 4.0)),
                                                                        ),
                                                                        FFButtonWidget(
                                                                          onPressed:
                                                                              () async {
                                                                            _model.blocked =
                                                                                await action_blocks.checkBlock(
                                                                              context,
                                                                              userRef: currentUserReference,
                                                                              blockedUser: wrapChatsRecord.blockedUser,
                                                                            );
                                                                            if (_model.blocked ==
                                                                                true) {
                                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                                SnackBar(
                                                                                  content: Text(
                                                                                    'Sorry, you have been blocked from this Chatroom.',
                                                                                    style: TextStyle(
                                                                                      color: FlutterFlowTheme.of(context).primaryText,
                                                                                    ),
                                                                                  ),
                                                                                  duration: Duration(milliseconds: 4000),
                                                                                  backgroundColor: FlutterFlowTheme.of(context).secondary,
                                                                                ),
                                                                              );
                                                                            } else {
                                                                              if (wrapChatsRecord.members.contains(currentUserReference)) {
                                                                                context.pushNamed(
                                                                                  ChatDetailWidget.routeName,
                                                                                  queryParameters: {
                                                                                    'chatDoc': serializeParam(
                                                                                      wrapChatsRecord,
                                                                                      ParamType.Document,
                                                                                    ),
                                                                                  }.withoutNulls,
                                                                                  extra: <String, dynamic>{
                                                                                    'chatDoc': wrapChatsRecord,
                                                                                  },
                                                                                );
                                                                              } else {
                                                                                await wrapChatsRecord.reference.update({
                                                                                  ...mapToFirestore(
                                                                                    {
                                                                                      'members': FieldValue.arrayUnion([
                                                                                        currentUserReference
                                                                                      ]),
                                                                                    },
                                                                                  ),
                                                                                });

                                                                                context.pushNamed(
                                                                                  ChatDetailWidget.routeName,
                                                                                  queryParameters: {
                                                                                    'chatDoc': serializeParam(
                                                                                      wrapChatsRecord,
                                                                                      ParamType.Document,
                                                                                    ),
                                                                                  }.withoutNulls,
                                                                                  extra: <String, dynamic>{
                                                                                    'chatDoc': wrapChatsRecord,
                                                                                  },
                                                                                );
                                                                              }
                                                                            }

                                                                            safeSetState(() {});
                                                                          },
                                                                          text: wrapChatsRecord.members.contains(currentUserReference)
                                                                              ? 'Start a Chat'
                                                                              : 'Join',
                                                                          options:
                                                                              FFButtonOptions(
                                                                            width:
                                                                                double.infinity,
                                                                            height:
                                                                                28.0,
                                                                            padding: EdgeInsetsDirectional.fromSTEB(
                                                                                16.0,
                                                                                6.0,
                                                                                16.0,
                                                                                6.0),
                                                                            iconPadding: EdgeInsetsDirectional.fromSTEB(
                                                                                0.0,
                                                                                0.0,
                                                                                0.0,
                                                                                0.0),
                                                                            color:
                                                                                Color(0xFF4F46E5),
                                                                            textStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                  font: GoogleFonts.inter(
                                                                                    fontWeight: FontWeight.normal,
                                                                                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                  ),
                                                                                  color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                  fontSize: 12.0,
                                                                                  letterSpacing: 0.0,
                                                                                  fontWeight: FontWeight.normal,
                                                                                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                ),
                                                                            elevation:
                                                                                0.0,
                                                                            borderRadius:
                                                                                BorderRadius.circular(14.0),
                                                                          ),
                                                                        ),
                                                                      ].divide(SizedBox(
                                                                          height: 8.0)),
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            }),
                                                          );
                                                        },
                                                      ),
                                                    ].divide(
                                                        SizedBox(height: 16.0)),
                                                  ),
                                                ),
                                              ]
                                                  .divide(
                                                      SizedBox(height: 24.0))
                                                  .addToStart(
                                                      SizedBox(height: 24.0))
                                                  .addToEnd(
                                                      SizedBox(height: 24.0)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ).animateOnPageLoad(animationsMap[
                                    'tabBarOnPageLoadAnimation']!),
                              ),
                            ),
                          ),
                        ]
                            .divide(SizedBox(height: 24.0))
                            .addToStart(SizedBox(height: 16.0)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}