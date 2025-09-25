import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/component/empty_schedule/empty_schedule_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/event/event_component/event_component_widget.dart';
import 'dart:math';
import 'dart:ui';
import '/index.dart';
import 'package:sticky_headers/sticky_headers.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'event_model.dart';
export 'event_model.dart';

/// Event Discovery and Listings
class EventWidget extends StatefulWidget {
  const EventWidget({super.key});

  static String routeName = 'Event';
  static String routePath = '/event';

  @override
  State<EventWidget> createState() => _EventWidgetState();
}

class _EventWidgetState extends State<EventWidget>
    with TickerProviderStateMixin {
  late EventModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final animationsMap = <String, AnimationInfo>{};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EventModel());

    _model.tabBarController = TabController(
      vsync: this,
      length: 3,
      initialIndex: 0,
    )..addListener(() => safeSetState(() {}));

    animationsMap.addAll({
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
      'rowOnPageLoadAnimation1': AnimationInfo(
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
      'eventComponentOnPageLoadAnimation1': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: null,
      ),
      'eventComponentOnPageLoadAnimation2': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: null,
      ),
      'rowOnPageLoadAnimation2': AnimationInfo(
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
      'eventComponentOnPageLoadAnimation3': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: null,
      ),
      'eventComponentOnPageLoadAnimation4': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: null,
      ),
      'rowOnPageLoadAnimation3': AnimationInfo(
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
      'eventComponentOnPageLoadAnimation5': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: null,
      ),
      'eventComponentOnPageLoadAnimation6': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: null,
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
    return StreamBuilder<List<EventsRecord>>(
      stream: queryEventsRecord(),
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
        List<EventsRecord> eventEventsRecordList = snapshot.data!;

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: Color(0xFFF9FAFB),
            floatingActionButton: FloatingActionButton(
              onPressed: () async {
                context.pushNamed(CreateEventWidget.routeName);
              },
              backgroundColor: FlutterFlowTheme.of(context).primary,
              elevation: 8.0,
              child: Icon(
                Icons.add_rounded,
                color: FlutterFlowTheme.of(context).info,
                size: 24.0,
              ),
            ),
            body: SafeArea(
              top: true,
              child: Align(
                alignment: AlignmentDirectional(0.0, -1.0),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  constraints: BoxConstraints(
                    maxWidth: 650.0,
                  ),
                  decoration: BoxDecoration(),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment(0.0, 0),
                        child: TabBar(
                          labelColor: FlutterFlowTheme.of(context).primary,
                          unselectedLabelColor:
                              FlutterFlowTheme.of(context).secondaryText,
                          labelStyle:
                              FlutterFlowTheme.of(context).titleMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                          unselectedLabelStyle:
                              FlutterFlowTheme.of(context).titleMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                          indicatorColor: FlutterFlowTheme.of(context).primary,
                          tabs: [
                            Tab(
                              text: 'All Event',
                            ),
                            Tab(
                              text: 'Attending',
                            ),
                            Tab(
                              text: 'Hosting',
                            ),
                          ],
                          controller: _model.tabBarController,
                          onTap: (i) async {
                            [() async {}, () async {}, () async {}][i]();
                          },
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _model.tabBarController,
                          children: [
                            SingleChildScrollView(
                              primary: false,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StickyHeader(
                                    overlapHeaders: false,
                                    header: Container(
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                FFButtonWidget(
                                                  onPressed: () async {
                                                    context.pushNamed(
                                                        SearchWidget.routeName);
                                                  },
                                                  text: 'Date',
                                                  icon: Icon(
                                                    Icons.date_range_rounded,
                                                    size: 12.0,
                                                  ),
                                                  options: FFButtonOptions(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(12.0, 8.0,
                                                                12.0, 8.0),
                                                    iconPadding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 0.0,
                                                                0.0, 0.0),
                                                    iconColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .primaryText,
                                                    color: Color(0xFFF3F4F6),
                                                    textStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .titleSmall
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontStyle,
                                                        ),
                                                    elevation: 0.0,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            14.0),
                                                  ),
                                                ),
                                                FFButtonWidget(
                                                  onPressed: () async {
                                                    context.pushNamed(
                                                        SearchWidget.routeName);
                                                  },
                                                  text: 'Location',
                                                  icon: FaIcon(
                                                    FontAwesomeIcons
                                                        .mapMarkerAlt,
                                                    size: 12.0,
                                                  ),
                                                  options: FFButtonOptions(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(12.0, 8.0,
                                                                12.0, 8.0),
                                                    iconPadding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 0.0,
                                                                0.0, 0.0),
                                                    iconColor:
                                                        Color(0xFF374151),
                                                    color: Color(0xFFF3F4F6),
                                                    textStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .titleSmall
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontStyle,
                                                          ),
                                                          color:
                                                              Color(0xFF374151),
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontStyle,
                                                        ),
                                                    elevation: 0.0,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            14.0),
                                                  ),
                                                ),
                                              ].divide(SizedBox(width: 8.0)),
                                            ),
                                            FFButtonWidget(
                                              onPressed: () async {
                                                context.pushNamed(
                                                    SearchWidget.routeName);
                                              },
                                              text: 'Filter',
                                              icon: Icon(
                                                Icons.tune_rounded,
                                                size: 12.0,
                                              ),
                                              options: FFButtonOptions(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        12.0, 8.0, 12.0, 8.0),
                                                iconPadding:
                                                    EdgeInsetsDirectional
                                                        .fromSTEB(
                                                            0.0, 0.0, 0.0, 0.0),
                                                iconColor: Color(0xFF374151),
                                                color: Color(0xFFE5E7EB),
                                                textStyle: FlutterFlowTheme.of(
                                                        context)
                                                    .titleSmall
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleSmall
                                                                .fontStyle,
                                                      ),
                                                      color: Color(0xFF374151),
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .titleSmall
                                                              .fontStyle,
                                                    ),
                                                elevation: 0.0,
                                                borderRadius:
                                                    BorderRadius.circular(14.0),
                                              ),
                                            ),
                                          ].divide(SizedBox(width: 12.0)),
                                        ).animateOnPageLoad(animationsMap[
                                            'rowOnPageLoadAnimation1']!),
                                      ),
                                    ),
                                    content: Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          16.0, 0.0, 16.0, 0.0),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Upcoming Events',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .titleLarge
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleLarge
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleLarge
                                                                .fontStyle,
                                                      ),
                                            ),
                                            Align(
                                              alignment: AlignmentDirectional(
                                                  0.0, 0.0),
                                              child: Container(
                                                decoration: BoxDecoration(),
                                                child: Builder(
                                                  builder: (context) {
                                                    final upcomingEvents =
                                                        eventEventsRecordList
                                                            .where((e) =>
                                                                (e.startDate! >=
                                                                    getCurrentTimestamp) &&
                                                                e.participants
                                                                    .contains(
                                                                        currentUserReference))
                                                            .toList();
                                                    if (upcomingEvents
                                                        .isEmpty) {
                                                      return EmptyScheduleWidget(
                                                        title:
                                                            'No Event Upcoming',
                                                        description:
                                                            'You don\'t have any events yet. Take some time to relax or plan something new!',
                                                        icon: Icon(
                                                          Icons
                                                              .hourglass_empty_rounded,
                                                          size: 32.0,
                                                        ),
                                                      );
                                                    }

                                                    return Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .stretch,
                                                      children: List.generate(
                                                          upcomingEvents.length,
                                                          (upcomingEventsIndex) {
                                                        final upcomingEventsItem =
                                                            upcomingEvents[
                                                                upcomingEventsIndex];
                                                        return wrapWithModel(
                                                          model: _model
                                                              .eventComponentModels1
                                                              .getModel(
                                                            upcomingEventsItem
                                                                .reference.id,
                                                            upcomingEventsIndex,
                                                          ),
                                                          updateCallback: () =>
                                                              safeSetState(
                                                                  () {}),
                                                          child:
                                                              EventComponentWidget(
                                                            key: Key(
                                                              'Keyo9e_${upcomingEventsItem.reference.id}',
                                                            ),
                                                            imageCover:
                                                                valueOrDefault<
                                                                    String>(
                                                              upcomingEventsItem
                                                                  .coverImageUrl,
                                                              'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fevent.jpg?alt=media&token=3e30709d-40ff-4e86-a702-5c9c2068fa8d',
                                                            ),
                                                            category:
                                                                upcomingEventsItem
                                                                    .category
                                                                    .firstOrNull,
                                                            nameEvent:
                                                                upcomingEventsItem
                                                                    .title,
                                                            date: dateTimeFormat(
                                                                "yMMMd",
                                                                upcomingEventsItem
                                                                    .startDate!),
                                                            time: dateTimeFormat(
                                                                "jm",
                                                                upcomingEventsItem
                                                                    .startDate!),
                                                            location:
                                                                upcomingEventsItem
                                                                    .location,
                                                            speakers:
                                                                upcomingEventsItem
                                                                    .speakers,
                                                            participant:
                                                                upcomingEventsItem
                                                                    .participants
                                                                    .length,
                                                            eventRef:
                                                                upcomingEventsItem
                                                                    .reference,
                                                            eventBriteId:
                                                                upcomingEventsItem
                                                                    .eventbriteId,
                                                            action: () async {
                                                              context.pushNamed(
                                                                EventDetailWidget
                                                                    .routeName,
                                                                pathParameters:
                                                                    {
                                                                  'eventId':
                                                                      serializeParam(
                                                                    upcomingEventsItem
                                                                        .eventId,
                                                                    ParamType
                                                                        .String,
                                                                  ),
                                                                }.withoutNulls,
                                                              );
                                                            },
                                                          ),
                                                        ).animateOnPageLoad(
                                                          animationsMap[
                                                              'eventComponentOnPageLoadAnimation1']!,
                                                          effects: [
                                                            MoveEffect(
                                                              curve: Curves
                                                                  .easeInOut,
                                                              delay:
                                                                  (upcomingEventsIndex *
                                                                          48)
                                                                      .ms,
                                                              duration:
                                                                  600.0.ms,
                                                              begin: Offset(
                                                                  0.0, 30.0),
                                                              end: Offset(
                                                                  0.0, 0.0),
                                                            ),
                                                          ],
                                                        );
                                                      }).divide(SizedBox(
                                                          height: 12.0)),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Past Events',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .titleLarge
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleLarge
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleLarge
                                                                .fontStyle,
                                                      ),
                                            ),
                                            Align(
                                              alignment: AlignmentDirectional(
                                                  0.0, 0.0),
                                              child: Container(
                                                decoration: BoxDecoration(),
                                                child: Builder(
                                                  builder: (context) {
                                                    final pastEvent =
                                                        eventEventsRecordList
                                                            .where((e) =>
                                                                (e.startDate! <
                                                                    getCurrentTimestamp) &&
                                                                e.participants
                                                                    .contains(
                                                                        currentUserReference))
                                                            .toList();
                                                    if (pastEvent.isEmpty) {
                                                      return EmptyScheduleWidget(
                                                        title: 'No Event',
                                                        description:
                                                            'You don\'t have any events yet. Take some time to relax or plan something new!',
                                                        icon: Icon(
                                                          Icons
                                                              .hourglass_empty_rounded,
                                                          size: 32.0,
                                                        ),
                                                      );
                                                    }

                                                    return Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .stretch,
                                                      children: List.generate(
                                                          pastEvent.length,
                                                          (pastEventIndex) {
                                                        final pastEventItem =
                                                            pastEvent[
                                                                pastEventIndex];
                                                        return wrapWithModel(
                                                          model: _model
                                                              .eventComponentModels2
                                                              .getModel(
                                                            pastEventItem
                                                                .reference.id,
                                                            pastEventIndex,
                                                          ),
                                                          updateCallback: () =>
                                                              safeSetState(
                                                                  () {}),
                                                          child:
                                                              EventComponentWidget(
                                                            key: Key(
                                                              'Keyb6v_${pastEventItem.reference.id}',
                                                            ),
                                                            imageCover:
                                                                valueOrDefault<
                                                                    String>(
                                                              pastEventItem
                                                                  .coverImageUrl,
                                                              'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fevent.jpg?alt=media&token=3e30709d-40ff-4e86-a702-5c9c2068fa8d',
                                                            ),
                                                            category:
                                                                pastEventItem
                                                                    .category
                                                                    .firstOrNull,
                                                            nameEvent:
                                                                pastEventItem
                                                                    .title,
                                                            date: dateTimeFormat(
                                                                "yMMMd",
                                                                pastEventItem
                                                                    .startDate!),
                                                            time: dateTimeFormat(
                                                                "jm",
                                                                pastEventItem
                                                                    .startDate!),
                                                            location:
                                                                pastEventItem
                                                                    .location,
                                                            participant:
                                                                pastEventItem
                                                                    .participants
                                                                    .length,
                                                            speakers:
                                                                pastEventItem
                                                                    .speakers,
                                                            eventRef:
                                                                pastEventItem
                                                                    .reference,
                                                            eventBriteId:
                                                                pastEventItem
                                                                    .eventbriteId,
                                                            action: () async {
                                                              context.pushNamed(
                                                                EventDetailWidget
                                                                    .routeName,
                                                                pathParameters:
                                                                    {
                                                                  'eventId':
                                                                      serializeParam(
                                                                    pastEventItem
                                                                        .eventId,
                                                                    ParamType
                                                                        .String,
                                                                  ),
                                                                }.withoutNulls,
                                                              );
                                                            },
                                                          ),
                                                        ).animateOnPageLoad(
                                                          animationsMap[
                                                              'eventComponentOnPageLoadAnimation2']!,
                                                          effects: [
                                                            MoveEffect(
                                                              curve: Curves
                                                                  .easeInOut,
                                                              delay:
                                                                  valueOrDefault<
                                                                      double>(
                                                                (pastEventIndex *
                                                                        48)
                                                                    .toDouble(),
                                                                48.0,
                                                              ).ms,
                                                              duration:
                                                                  600.0.ms,
                                                              begin: Offset(
                                                                  0.0, 30.0),
                                                              end: Offset(
                                                                  0.0, 0.0),
                                                            ),
                                                          ],
                                                        );
                                                      }),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ]
                                              .divide(SizedBox(height: 24.0))
                                              .addToStart(
                                                  SizedBox(height: 24.0)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ]
                                    .divide(SizedBox(height: 24.0))
                                    .addToEnd(SizedBox(height: 24.0)),
                              ),
                            ),
                            SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  StickyHeader(
                                    overlapHeaders: false,
                                    header: Container(
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                FFButtonWidget(
                                                  onPressed: () async {
                                                    context.pushNamed(
                                                        SearchWidget.routeName);
                                                  },
                                                  text: 'Date',
                                                  icon: Icon(
                                                    Icons.date_range_rounded,
                                                    size: 12.0,
                                                  ),
                                                  options: FFButtonOptions(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(12.0, 8.0,
                                                                12.0, 8.0),
                                                    iconPadding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 0.0,
                                                                0.0, 0.0),
                                                    iconColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .primaryText,
                                                    color: Color(0xFFF3F4F6),
                                                    textStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .titleSmall
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontStyle,
                                                        ),
                                                    elevation: 0.0,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            14.0),
                                                  ),
                                                ),
                                                FFButtonWidget(
                                                  onPressed: () async {
                                                    context.pushNamed(
                                                        SearchWidget.routeName);
                                                  },
                                                  text: 'Location',
                                                  icon: FaIcon(
                                                    FontAwesomeIcons
                                                        .mapMarkerAlt,
                                                    size: 12.0,
                                                  ),
                                                  options: FFButtonOptions(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(12.0, 8.0,
                                                                12.0, 8.0),
                                                    iconPadding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 0.0,
                                                                0.0, 0.0),
                                                    iconColor:
                                                        Color(0xFF374151),
                                                    color: Color(0xFFF3F4F6),
                                                    textStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .titleSmall
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontStyle,
                                                          ),
                                                          color:
                                                              Color(0xFF374151),
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontStyle,
                                                        ),
                                                    elevation: 0.0,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            14.0),
                                                  ),
                                                ),
                                              ].divide(SizedBox(width: 8.0)),
                                            ),
                                            FFButtonWidget(
                                              onPressed: () async {
                                                context.pushNamed(
                                                    SearchWidget.routeName);
                                              },
                                              text: 'Filter',
                                              icon: Icon(
                                                Icons.tune_rounded,
                                                size: 12.0,
                                              ),
                                              options: FFButtonOptions(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        12.0, 8.0, 12.0, 8.0),
                                                iconPadding:
                                                    EdgeInsetsDirectional
                                                        .fromSTEB(
                                                            0.0, 0.0, 0.0, 0.0),
                                                iconColor: Color(0xFF374151),
                                                color: Color(0xFFE5E7EB),
                                                textStyle: FlutterFlowTheme.of(
                                                        context)
                                                    .titleSmall
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleSmall
                                                                .fontStyle,
                                                      ),
                                                      color: Color(0xFF374151),
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .titleSmall
                                                              .fontStyle,
                                                    ),
                                                elevation: 0.0,
                                                borderRadius:
                                                    BorderRadius.circular(14.0),
                                              ),
                                            ),
                                          ].divide(SizedBox(width: 12.0)),
                                        ).animateOnPageLoad(animationsMap[
                                            'rowOnPageLoadAnimation2']!),
                                      ),
                                    ),
                                    content: Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          16.0, 0.0, 16.0, 0.0),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Upcoming Events',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .titleLarge
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleLarge
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleLarge
                                                                .fontStyle,
                                                      ),
                                            ),
                                            Container(
                                              decoration: BoxDecoration(),
                                              child: Builder(
                                                builder: (context) {
                                                  final eventVar = eventEventsRecordList
                                                      .where((e) =>
                                                          (e.startDate! >=
                                                              getCurrentTimestamp) &&
                                                          (e.creatorId !=
                                                              currentUserReference) &&
                                                          e.participants.contains(
                                                              currentUserReference))
                                                      .toList();
                                                  if (eventVar.isEmpty) {
                                                    return EmptyScheduleWidget(
                                                      title:
                                                          'No Event Upcoming',
                                                      description:
                                                          'You don\'t have any events yet. Take some time to relax or plan something new!',
                                                      icon: Icon(
                                                        Icons
                                                            .hourglass_empty_rounded,
                                                        size: 32.0,
                                                      ),
                                                    );
                                                  }

                                                  return Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: List.generate(
                                                        eventVar.length,
                                                        (eventVarIndex) {
                                                      final eventVarItem =
                                                          eventVar[
                                                              eventVarIndex];
                                                      return wrapWithModel(
                                                        model: _model
                                                            .eventComponentModels3
                                                            .getModel(
                                                          eventVarItem
                                                              .reference.id,
                                                          eventVarIndex,
                                                        ),
                                                        updateCallback: () =>
                                                            safeSetState(() {}),
                                                        child:
                                                            EventComponentWidget(
                                                          key: Key(
                                                            'Keynpx_${eventVarItem.reference.id}',
                                                          ),
                                                          imageCover:
                                                              valueOrDefault<
                                                                  String>(
                                                            eventVarItem
                                                                .coverImageUrl,
                                                            'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fevent.jpg?alt=media&token=3e30709d-40ff-4e86-a702-5c9c2068fa8d',
                                                          ),
                                                          category: eventVarItem
                                                              .category
                                                              .firstOrNull,
                                                          nameEvent:
                                                              eventVarItem
                                                                  .title,
                                                          date: dateTimeFormat(
                                                              "yMMMd",
                                                              eventVarItem
                                                                  .startDate!),
                                                          time: dateTimeFormat(
                                                              "jm",
                                                              eventVarItem
                                                                  .startDate!),
                                                          location: eventVarItem
                                                              .location,
                                                          participant:
                                                              eventVarItem
                                                                  .participants
                                                                  .length,
                                                          speakers: eventVarItem
                                                              .speakers,
                                                          eventRef: eventVarItem
                                                              .reference,
                                                          eventBriteId:
                                                              eventVarItem
                                                                  .eventbriteId,
                                                          action: () async {
                                                            context.pushNamed(
                                                              EventDetailWidget
                                                                  .routeName,
                                                              pathParameters: {
                                                                'eventId':
                                                                    serializeParam(
                                                                  eventVarItem
                                                                      .eventId,
                                                                  ParamType
                                                                      .String,
                                                                ),
                                                              }.withoutNulls,
                                                            );
                                                          },
                                                        ),
                                                      ).animateOnPageLoad(
                                                        animationsMap[
                                                            'eventComponentOnPageLoadAnimation3']!,
                                                        effects: [
                                                          MoveEffect(
                                                            curve: Curves
                                                                .easeInOut,
                                                            delay:
                                                                (eventVarIndex *
                                                                        48)
                                                                    .ms,
                                                            duration: 600.0.ms,
                                                            begin: Offset(
                                                                0.0, 30.0),
                                                            end: Offset(
                                                                0.0, 0.0),
                                                          ),
                                                        ],
                                                      );
                                                    }).divide(
                                                        SizedBox(height: 12.0)),
                                                  );
                                                },
                                              ),
                                            ),
                                            Text(
                                              'Past Events',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .titleLarge
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleLarge
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleLarge
                                                                .fontStyle,
                                                      ),
                                            ),
                                            Container(
                                              decoration: BoxDecoration(),
                                              child: Builder(
                                                builder: (context) {
                                                  final pastEvent = eventEventsRecordList
                                                      .where((e) =>
                                                          (e.startDate! < getCurrentTimestamp) &&
                                                          (e.creatorId !=
                                                              currentUserReference) &&
                                                          e.participants.contains(
                                                              currentUserReference))
                                                      .toList();
                                                  if (pastEvent.isEmpty) {
                                                    return EmptyScheduleWidget(
                                                      title: 'No Event',
                                                      description:
                                                          'You don\'t have any events yet. Take some time to relax or plan something new!',
                                                      icon: Icon(
                                                        Icons
                                                            .hourglass_empty_rounded,
                                                      ),
                                                    );
                                                  }

                                                  return Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: List.generate(
                                                        pastEvent.length,
                                                        (pastEventIndex) {
                                                      final pastEventItem =
                                                          pastEvent[
                                                              pastEventIndex];
                                                      return wrapWithModel(
                                                        model: _model
                                                            .eventComponentModels4
                                                            .getModel(
                                                          pastEventItem
                                                              .reference.id,
                                                          pastEventIndex,
                                                        ),
                                                        updateCallback: () =>
                                                            safeSetState(() {}),
                                                        child:
                                                            EventComponentWidget(
                                                          key: Key(
                                                            'Key4x6_${pastEventItem.reference.id}',
                                                          ),
                                                          imageCover:
                                                              valueOrDefault<
                                                                  String>(
                                                            pastEventItem
                                                                .coverImageUrl,
                                                            'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fevent.jpg?alt=media&token=3e30709d-40ff-4e86-a702-5c9c2068fa8d',
                                                          ),
                                                          category:
                                                              pastEventItem
                                                                  .category
                                                                  .firstOrNull,
                                                          nameEvent:
                                                              pastEventItem
                                                                  .title,
                                                          date: dateTimeFormat(
                                                              "yMMMd",
                                                              pastEventItem
                                                                  .startDate!),
                                                          time: dateTimeFormat(
                                                              "jm",
                                                              pastEventItem
                                                                  .startDate!),
                                                          location:
                                                              pastEventItem
                                                                  .location,
                                                          participant:
                                                              pastEventItem
                                                                  .participants
                                                                  .length,
                                                          speakers:
                                                              pastEventItem
                                                                  .speakers,
                                                          eventRef:
                                                              pastEventItem
                                                                  .reference,
                                                          eventBriteId:
                                                              pastEventItem
                                                                  .eventbriteId,
                                                          action: () async {
                                                            context.pushNamed(
                                                              EventDetailWidget
                                                                  .routeName,
                                                              pathParameters: {
                                                                'eventId':
                                                                    serializeParam(
                                                                  pastEventItem
                                                                      .eventId,
                                                                  ParamType
                                                                      .String,
                                                                ),
                                                              }.withoutNulls,
                                                            );
                                                          },
                                                        ),
                                                      ).animateOnPageLoad(
                                                        animationsMap[
                                                            'eventComponentOnPageLoadAnimation4']!,
                                                        effects: [
                                                          MoveEffect(
                                                            curve: Curves
                                                                .easeInOut,
                                                            delay:
                                                                valueOrDefault<
                                                                    double>(
                                                              (pastEventIndex *
                                                                      48)
                                                                  .toDouble(),
                                                              48.0,
                                                            ).ms,
                                                            duration: 600.0.ms,
                                                            begin: Offset(
                                                                0.0, 30.0),
                                                            end: Offset(
                                                                0.0, 0.0),
                                                          ),
                                                        ],
                                                      );
                                                    }).divide(
                                                        SizedBox(height: 12.0)),
                                                  );
                                                },
                                              ),
                                            ),
                                          ]
                                              .divide(SizedBox(height: 24.0))
                                              .addToStart(
                                                  SizedBox(height: 24.0)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ]
                                    .divide(SizedBox(height: 24.0))
                                    .addToEnd(SizedBox(height: 24.0)),
                              ),
                            ),
                            SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  StickyHeader(
                                    overlapHeaders: false,
                                    header: Container(
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                FFButtonWidget(
                                                  onPressed: () async {
                                                    context.pushNamed(
                                                        SearchWidget.routeName);
                                                  },
                                                  text: 'Date',
                                                  icon: Icon(
                                                    Icons.date_range_rounded,
                                                    size: 12.0,
                                                  ),
                                                  options: FFButtonOptions(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(12.0, 8.0,
                                                                12.0, 8.0),
                                                    iconPadding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 0.0,
                                                                0.0, 0.0),
                                                    iconColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .primaryText,
                                                    color: Color(0xFFF3F4F6),
                                                    textStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .titleSmall
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontStyle,
                                                        ),
                                                    elevation: 0.0,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            14.0),
                                                  ),
                                                ),
                                                FFButtonWidget(
                                                  onPressed: () async {
                                                    context.pushNamed(
                                                        SearchWidget.routeName);
                                                  },
                                                  text: 'Location',
                                                  icon: FaIcon(
                                                    FontAwesomeIcons
                                                        .mapMarkerAlt,
                                                    size: 12.0,
                                                  ),
                                                  options: FFButtonOptions(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(12.0, 8.0,
                                                                12.0, 8.0),
                                                    iconPadding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 0.0,
                                                                0.0, 0.0),
                                                    iconColor:
                                                        Color(0xFF374151),
                                                    color: Color(0xFFF3F4F6),
                                                    textStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .titleSmall
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontStyle,
                                                          ),
                                                          color:
                                                              Color(0xFF374151),
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontStyle,
                                                        ),
                                                    elevation: 0.0,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            14.0),
                                                  ),
                                                ),
                                              ].divide(SizedBox(width: 8.0)),
                                            ),
                                            FFButtonWidget(
                                              onPressed: () async {
                                                context.pushNamed(
                                                    SearchWidget.routeName);
                                              },
                                              text: 'Filter',
                                              icon: Icon(
                                                Icons.tune_rounded,
                                                size: 12.0,
                                              ),
                                              options: FFButtonOptions(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        12.0, 8.0, 12.0, 8.0),
                                                iconPadding:
                                                    EdgeInsetsDirectional
                                                        .fromSTEB(
                                                            0.0, 0.0, 0.0, 0.0),
                                                iconColor: Color(0xFF374151),
                                                color: Color(0xFFE5E7EB),
                                                textStyle: FlutterFlowTheme.of(
                                                        context)
                                                    .titleSmall
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleSmall
                                                                .fontStyle,
                                                      ),
                                                      color: Color(0xFF374151),
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .titleSmall
                                                              .fontStyle,
                                                    ),
                                                elevation: 0.0,
                                                borderRadius:
                                                    BorderRadius.circular(14.0),
                                              ),
                                            ),
                                          ].divide(SizedBox(width: 12.0)),
                                        ).animateOnPageLoad(animationsMap[
                                            'rowOnPageLoadAnimation3']!),
                                      ),
                                    ),
                                    content: Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          16.0, 0.0, 16.0, 0.0),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Upcoming Events',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .titleLarge
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleLarge
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleLarge
                                                                .fontStyle,
                                                      ),
                                            ),
                                            Container(
                                              decoration: BoxDecoration(),
                                              child: Builder(
                                                builder: (context) {
                                                  final eventVar = eventEventsRecordList
                                                      .where((e) =>
                                                          (e.startDate! >=
                                                              getCurrentTimestamp) &&
                                                          (e.creatorId ==
                                                              currentUserReference))
                                                      .toList();
                                                  if (eventVar.isEmpty) {
                                                    return EmptyScheduleWidget(
                                                      title:
                                                          'No Event Upcoming',
                                                      description:
                                                          'You don\'t have any events yet. Take some time to relax or plan something new!',
                                                      icon: Icon(
                                                        Icons
                                                            .hourglass_empty_rounded,
                                                        size: 32.0,
                                                      ),
                                                    );
                                                  }

                                                  return Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: List.generate(
                                                        eventVar.length,
                                                        (eventVarIndex) {
                                                      final eventVarItem =
                                                          eventVar[
                                                              eventVarIndex];
                                                      return wrapWithModel(
                                                        model: _model
                                                            .eventComponentModels5
                                                            .getModel(
                                                          eventVarIndex
                                                              .toString(),
                                                          eventVarIndex,
                                                        ),
                                                        updateCallback: () =>
                                                            safeSetState(() {}),
                                                        child:
                                                            EventComponentWidget(
                                                          key: Key(
                                                            'Keyq2o_${eventVarIndex.toString()}',
                                                          ),
                                                          imageCover:
                                                              valueOrDefault<
                                                                  String>(
                                                            eventVarItem
                                                                .coverImageUrl,
                                                            'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fevent.jpg?alt=media&token=3e30709d-40ff-4e86-a702-5c9c2068fa8d',
                                                          ),
                                                          category: eventVarItem
                                                              .category
                                                              .firstOrNull,
                                                          nameEvent:
                                                              eventVarItem
                                                                  .title,
                                                          date: dateTimeFormat(
                                                              "yMMMd",
                                                              eventVarItem
                                                                  .startDate!),
                                                          time: dateTimeFormat(
                                                              "jm",
                                                              eventVarItem
                                                                  .startDate!),
                                                          location: eventVarItem
                                                              .location,
                                                          participant:
                                                              eventVarItem
                                                                  .participants
                                                                  .length,
                                                          speakers: eventVarItem
                                                              .speakers,
                                                          eventRef: eventVarItem
                                                              .reference,
                                                          eventBriteId:
                                                              eventVarItem
                                                                  .eventbriteId,
                                                          action: () async {
                                                            context.pushNamed(
                                                              EventDetailWidget
                                                                  .routeName,
                                                              pathParameters: {
                                                                'eventId':
                                                                    serializeParam(
                                                                  eventVarItem
                                                                      .eventId,
                                                                  ParamType
                                                                      .String,
                                                                ),
                                                              }.withoutNulls,
                                                            );
                                                          },
                                                        ),
                                                      ).animateOnPageLoad(
                                                        animationsMap[
                                                            'eventComponentOnPageLoadAnimation5']!,
                                                        effects: [
                                                          MoveEffect(
                                                            curve: Curves
                                                                .easeInOut,
                                                            delay:
                                                                (eventVarIndex *
                                                                        48)
                                                                    .ms,
                                                            duration: 600.0.ms,
                                                            begin: Offset(
                                                                0.0, 30.0),
                                                            end: Offset(
                                                                0.0, 0.0),
                                                          ),
                                                        ],
                                                      );
                                                    }).divide(
                                                        SizedBox(height: 12.0)),
                                                  );
                                                },
                                              ),
                                            ),
                                            Text(
                                              'Past Events',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .titleLarge
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleLarge
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleLarge
                                                                .fontStyle,
                                                      ),
                                            ),
                                            Container(
                                              decoration: BoxDecoration(),
                                              child: Builder(
                                                builder: (context) {
                                                  final pastEvent =
                                                      eventEventsRecordList
                                                          .where((e) =>
                                                              (e.startDate! <
                                                                  getCurrentTimestamp) &&
                                                              (e.creatorId ==
                                                                  currentUserReference))
                                                          .toList();
                                                  if (pastEvent.isEmpty) {
                                                    return EmptyScheduleWidget(
                                                      title: 'No Event',
                                                      description:
                                                          'You don\'t have any events yet. Take some time to relax or plan something new!',
                                                      icon: Icon(
                                                        Icons
                                                            .hourglass_empty_rounded,
                                                        size: 32.0,
                                                      ),
                                                    );
                                                  }

                                                  return Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: List.generate(
                                                        pastEvent.length,
                                                        (pastEventIndex) {
                                                      final pastEventItem =
                                                          pastEvent[
                                                              pastEventIndex];
                                                      return wrapWithModel(
                                                        model: _model
                                                            .eventComponentModels6
                                                            .getModel(
                                                          pastEventItem
                                                              .reference.id,
                                                          pastEventIndex,
                                                        ),
                                                        updateCallback: () =>
                                                            safeSetState(() {}),
                                                        child:
                                                            EventComponentWidget(
                                                          key: Key(
                                                            'Key95e_${pastEventItem.reference.id}',
                                                          ),
                                                          imageCover:
                                                              valueOrDefault<
                                                                  String>(
                                                            pastEventItem
                                                                .coverImageUrl,
                                                            'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fevent.jpg?alt=media&token=3e30709d-40ff-4e86-a702-5c9c2068fa8d',
                                                          ),
                                                          category:
                                                              pastEventItem
                                                                  .category
                                                                  .firstOrNull,
                                                          nameEvent:
                                                              pastEventItem
                                                                  .title,
                                                          date: dateTimeFormat(
                                                              "yMMMd",
                                                              pastEventItem
                                                                  .startDate!),
                                                          time: dateTimeFormat(
                                                              "jm",
                                                              pastEventItem
                                                                  .startDate!),
                                                          location:
                                                              pastEventItem
                                                                  .location,
                                                          participant:
                                                              pastEventItem
                                                                  .participants
                                                                  .length,
                                                          speakers:
                                                              pastEventItem
                                                                  .speakers,
                                                          eventRef:
                                                              pastEventItem
                                                                  .reference,
                                                          eventBriteId:
                                                              pastEventItem
                                                                  .eventbriteId,
                                                          action: () async {
                                                            context.pushNamed(
                                                              EventDetailWidget
                                                                  .routeName,
                                                              pathParameters: {
                                                                'eventId':
                                                                    serializeParam(
                                                                  pastEventItem
                                                                      .eventId,
                                                                  ParamType
                                                                      .String,
                                                                ),
                                                              }.withoutNulls,
                                                            );
                                                          },
                                                        ),
                                                      ).animateOnPageLoad(
                                                        animationsMap[
                                                            'eventComponentOnPageLoadAnimation6']!,
                                                        effects: [
                                                          MoveEffect(
                                                            curve: Curves
                                                                .easeInOut,
                                                            delay:
                                                                valueOrDefault<
                                                                    double>(
                                                              (pastEventIndex *
                                                                      48)
                                                                  .toDouble(),
                                                              48.0,
                                                            ).ms,
                                                            duration: 600.0.ms,
                                                            begin: Offset(
                                                                0.0, 30.0),
                                                            end: Offset(
                                                                0.0, 0.0),
                                                          ),
                                                        ],
                                                      );
                                                    }).divide(
                                                        SizedBox(height: 12.0)),
                                                  );
                                                },
                                              ),
                                            ),
                                          ]
                                              .divide(SizedBox(height: 24.0))
                                              .addToStart(
                                                  SizedBox(height: 24.0)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ]
                                    .divide(SizedBox(height: 24.0))
                                    .addToEnd(SizedBox(height: 24.0)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ).animateOnPageLoad(
                      animationsMap['tabBarOnPageLoadAnimation']!),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
