import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/component/empty_schedule/empty_schedule_widget.dart';
import '/component/filter_search/filter_search_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/event/event_component/event_component_widget.dart';
import 'dart:math';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/permissions_util.dart';
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'search_model.dart';
export 'search_model.dart';

/// Event Discovery and Listings
class SearchWidget extends StatefulWidget {
  const SearchWidget({super.key});

  static String routeName = 'Search';
  static String routePath = '/search';

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget>
    with TickerProviderStateMixin {
  late SearchModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  LatLng? currentUserLocationValue;

  final animationsMap = <String, AnimationInfo>{};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SearchModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.loading = false;
      safeSetState(() {});
      _model.event = await queryEventsRecordOnce();
      _model.eventsResult = _model.event!.toList().cast<EventsRecord>();
      _model.loading = true;
      safeSetState(() {});
    });

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

    animationsMap.addAll({
      'textFieldOnPageLoadAnimation': AnimationInfo(
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
      'columnOnPageLoadAnimation': AnimationInfo(
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
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: FlutterFlowTheme.of(context).primary),
          automaticallyImplyLeading: true,
          actions: const [],
          centerTitle: true,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: Align(
            alignment: const AlignmentDirectional(0.0, -1.0),
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 650.0,
              ),
              decoration: const BoxDecoration(),
              child: Stack(
                children: [
                  Align(
                    alignment: const AlignmentDirectional(0.0, 0.0),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: const BoxDecoration(),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  16.0, 0.0, 16.0, 0.0),
                              child: SizedBox(
                                width: double.infinity,
                                child: TextFormField(
                                  controller: _model.textController,
                                  focusNode: _model.textFieldFocusNode,
                                  onChanged: (_) => EasyDebounce.debounce(
                                    '_model.textController',
                                    const Duration(milliseconds: 300),
                                    () async {
                                      _model.eventsResult = _model.event!
                                          .where((e) =>
                                              functions.textContaintext(e.title,
                                                  _model.textController.text) ||
                                              functions.textContaintext(
                                                  e.description,
                                                  _model.textController.text) ||
                                              functions.textContaintext(
                                                  e.category
                                                      .contains(_model
                                                          .textController.text)
                                                      .toString(),
                                                  _model.textController.text) ||
                                              e.category.contains(
                                                  _model.textController.text) ||
                                              functions.textContaintext(
                                                  e.startDate!.toString(),
                                                  _model.textController.text))
                                          .toList()
                                          .cast<EventsRecord>();
                                      safeSetState(() {});
                                    },
                                  ),
                                  onFieldSubmitted: (_) async {
                                    if (!(_model.textController.text == '')) {
                                      FFAppState().addToHistory(
                                          _model.textController.text);
                                      safeSetState(() {});
                                    }
                                  },
                                  autofocus: false,
                                  obscureText: false,
                                  decoration: InputDecoration(
                                    isDense: false,
                                    hintText:
                                        'Search events, groups or keywords',
                                    hintStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .accent2,
                                          fontSize: 16.0,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontStyle,
                                        ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context)
                                            .accent2,
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color:
                                            FlutterFlowTheme.of(context).error,
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color:
                                            FlutterFlowTheme.of(context).error,
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF3F4F6),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: Color(0xFFADAEBC),
                                      size: 20.0,
                                    ),
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
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
                                  cursorColor:
                                      FlutterFlowTheme.of(context).primaryText,
                                  validator: _model.textControllerValidator
                                      .asValidator(context),
                                ),
                              ).animateOnPageLoad(animationsMap[
                                  'textFieldOnPageLoadAnimation']!),
                            ),
                            if (FFAppState().history.isNotEmpty)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                            color: const Color(0xFF6B7280),
                                            fontSize: 12.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                  ),
                                  Builder(
                                    builder: (context) {
                                      final searchHistory =
                                          FFAppState().history.toList();

                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children:
                                            List.generate(searchHistory.length,
                                                (searchHistoryIndex) {
                                          final searchHistoryItem =
                                              searchHistory[searchHistoryIndex];
                                          return Padding(
                                            padding:
                                                const EdgeInsetsDirectional.fromSTEB(
                                                    16.0, 0.0, 16.0, 0.0),
                                            child: InkWell(
                                              splashColor: Colors.transparent,
                                              focusColor: Colors.transparent,
                                              hoverColor: Colors.transparent,
                                              highlightColor:
                                                  Colors.transparent,
                                              onTap: () async {
                                                safeSetState(() {
                                                  _model.textController?.text =
                                                      searchHistoryItem;
                                                });
                                              },
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    searchHistoryItem,
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                          fontSize: 16.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                  ),
                                                  InkWell(
                                                    splashColor:
                                                        Colors.transparent,
                                                    focusColor:
                                                        Colors.transparent,
                                                    hoverColor:
                                                        Colors.transparent,
                                                    highlightColor:
                                                        Colors.transparent,
                                                    onTap: () async {
                                                      FFAppState()
                                                          .removeFromHistory(
                                                              searchHistoryItem);
                                                      safeSetState(() {});
                                                    },
                                                    child: Icon(
                                                      Icons.close_rounded,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      size: 24.0,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).divide(const SizedBox(height: 5.0)),
                                      ).animateOnPageLoad(animationsMap[
                                          'columnOnPageLoadAnimation']!);
                                    },
                                  ),
                                ],
                              ),
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  16.0, 0.0, 16.0, 0.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  FFButtonWidget(
                                    onPressed: () async {
                                      currentUserLocationValue =
                                          await getCurrentUserLocation(
                                              defaultLocation:
                                                  const LatLng(0.0, 0.0));
                                      if (_model.isNear == false) {
                                        if (await getPermissionStatus(
                                            locationPermission)) {
                                          _model.eventsResult = _model.event!
                                              .where((e) =>
                                                  functions.locationNear(
                                                      e.latlng,
                                                      currentUserLocationValue)!)
                                              .toList()
                                              .cast<EventsRecord>();
                                          _model.isNear = true;
                                          safeSetState(() {});
                                        } else {
                                          await requestPermission(
                                              locationPermission);
                                        }
                                      } else {
                                        _model.eventsResult = _model.event!
                                            .toList()
                                            .cast<EventsRecord>();
                                        _model.isNear = false;
                                        safeSetState(() {});
                                      }
                                    },
                                    text: _model.isNear == true
                                        ? 'Near Me'
                                        : 'All Events',
                                    icon: const Icon(
                                      Icons.location_on,
                                      size: 12.0,
                                    ),
                                    options: FFButtonOptions(
                                      padding: const EdgeInsetsDirectional.fromSTEB(
                                          12.0, 8.0, 12.0, 8.0),
                                      iconPadding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                              0.0, 0.0, 0.0, 0.0),
                                      iconColor: FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                      color:
                                          FlutterFlowTheme.of(context).primary,
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
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w500,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontStyle,
                                          ),
                                      elevation: 0.0,
                                      borderSide: const BorderSide(
                                        color: Color(0x4C4B39EF),
                                        width: 0.5,
                                      ),
                                      borderRadius: BorderRadius.circular(14.0),
                                    ),
                                  ),
                                  FFButtonWidget(
                                    onPressed: () async {
                                      if (_model.isTodaySelected == false) {
                                        _model.eventsResult = _model.event!
                                            .where((e) => functions.todayEvent(
                                                e.startDate,
                                                getCurrentTimestamp))
                                            .toList()
                                            .cast<EventsRecord>();
                                        _model.isTodaySelected = true;
                                        safeSetState(() {});
                                      } else {
                                        _model.eventsResult = _model.event!
                                            .toList()
                                            .cast<EventsRecord>();
                                        _model.isTodaySelected = false;
                                        safeSetState(() {});
                                      }
                                    },
                                    text: 'Today',
                                    icon: const Icon(
                                      Icons.calendar_today,
                                      size: 12.0,
                                    ),
                                    options: FFButtonOptions(
                                      padding: const EdgeInsetsDirectional.fromSTEB(
                                          12.0, 8.0, 12.0, 8.0),
                                      iconPadding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                              0.0, 0.0, 0.0, 0.0),
                                      iconColor: _model.isTodaySelected == true
                                          ? FlutterFlowTheme.of(context)
                                              .secondaryBackground
                                          : const Color(0xFF374151),
                                      color: _model.isTodaySelected == true
                                          ? FlutterFlowTheme.of(context).primary
                                          : FlutterFlowTheme.of(context)
                                              .primaryBackground,
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
                                            color: _model.isTodaySelected ==
                                                    true
                                                ? FlutterFlowTheme.of(context)
                                                    .secondaryBackground
                                                : const Color(0xFF374151),
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w500,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontStyle,
                                          ),
                                      elevation: 0.0,
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context)
                                            .accent1,
                                      ),
                                      borderRadius: BorderRadius.circular(14.0),
                                    ),
                                  ),
                                  Builder(
                                    builder: (context) => FFButtonWidget(
                                      onPressed: () async {
                                        await showDialog(
                                          context: context,
                                          builder: (dialogContext) {
                                            return Dialog(
                                              elevation: 0,
                                              insetPadding: EdgeInsets.zero,
                                              backgroundColor:
                                                  Colors.transparent,
                                              alignment:
                                                  const AlignmentDirectional(0.0, 0.0)
                                                      .resolve(
                                                          Directionality.of(
                                                              context)),
                                              child: GestureDetector(
                                                onTap: () {
                                                  FocusScope.of(dialogContext)
                                                      .unfocus();
                                                  FocusManager
                                                      .instance.primaryFocus
                                                      ?.unfocus();
                                                },
                                                child: FilterSearchWidget(
                                                  action: (startTIme, category,
                                                      endTime, location) async {
                                                    _model.eventsResult = _model
                                                        .event!
                                                        .where((e) => functions
                                                            .shouldShowEventByDateRange(
                                                                e.startDate,
                                                                startTIme,
                                                                endTime,
                                                                e.category
                                                                    .toList(),
                                                                category,
                                                                location,
                                                                e.latlng)!)
                                                        .toList()
                                                        .sortedList(
                                                            keyOf: (e) => (endTime !=
                                                                        null) &&
                                                                    (startTIme ==
                                                                        null)
                                                                ? e.endDate!
                                                                : e.startDate!,
                                                            desc: true)
                                                        .toList()
                                                        .cast<EventsRecord>();
                                                    safeSetState(() {});
                                                    Navigator.pop(context);
                                                  },
                                                  reset: () async {
                                                    _model.eventsResult = _model
                                                        .event!
                                                        .toList()
                                                        .cast<EventsRecord>();
                                                    safeSetState(() {});
                                                    Navigator.pop(context);
                                                  },
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      text: 'Filter',
                                      icon: const Icon(
                                        Icons.filter_list,
                                        size: 12.0,
                                      ),
                                      options: FFButtonOptions(
                                        padding: const EdgeInsetsDirectional.fromSTEB(
                                            12.0, 8.0, 12.0, 8.0),
                                        iconPadding:
                                            const EdgeInsetsDirectional.fromSTEB(
                                                0.0, 0.0, 0.0, 0.0),
                                        iconColor: const Color(0xFF374151),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryBackground,
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
                                              color: const Color(0xFF374151),
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w500,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .fontStyle,
                                            ),
                                        elevation: 0.0,
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .accent2,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(14.0),
                                      ),
                                    ),
                                  ),
                                ].divide(const SizedBox(width: 12.0)),
                              ).animateOnPageLoad(
                                  animationsMap['rowOnPageLoadAnimation']!),
                            ),
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  16.0, 0.0, 16.0, 0.0),
                              child: Container(
                                width: double.infinity,
                                decoration: const BoxDecoration(),
                                child: Builder(
                                  builder: (context) {
                                    final events = _model.eventsResult.toList();
                                    if (events.isEmpty) {
                                      return SizedBox(
                                        width: double.infinity,
                                        height: 500.0,
                                        child: EmptyScheduleWidget(
                                          title: _model.isNear == true
                                              ? 'No nearby events'
                                              : 'No events',
                                          description: _model.isNear == true
                                              ? 'Sorry it seems like there is no event near you.'
                                              : 'Sorry it seems like there is no event available.',
                                          icon: const Icon(
                                            Icons.list,
                                          ),
                                        ),
                                      );
                                    }

                                    return Column(
                                      mainAxisSize: MainAxisSize.max,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: List.generate(events.length,
                                              (eventsIndex) {
                                        final eventsItem = events[eventsIndex];
                                        return EventComponentWidget(
                                          key: Key(
                                              'Keypdk_${eventsIndex}_of_${events.length}'),
                                          imageCover: valueOrDefault<String>(
                                            eventsItem.coverImageUrl,
                                            'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fevent.jpg?alt=media&token=3e30709d-40ff-4e86-a702-5c9c2068fa8d',
                                          ),
                                          category:
                                              eventsItem.category.firstOrNull,
                                          nameEvent: eventsItem.title,
                                          date: dateTimeFormat(
                                              "yMMMd", eventsItem.startDate!),
                                          time: dateTimeFormat(
                                              "jm", eventsItem.startDate!),
                                          location: eventsItem.location,
                                          participant:
                                              eventsItem.participants.length,
                                          speakers: eventsItem.speakers,
                                          eventRef: eventsItem.reference,
                                          eventBriteId: eventsItem.eventbriteId,
                                          action: () async {
                                            context.pushNamed(
                                              EventDetailWidget.routeName,
                                              pathParameters: {
                                                'eventId': serializeParam(
                                                  eventsItem.eventId,
                                                  ParamType.String,
                                                ),
                                              }.withoutNulls,
                                            );
                                          },
                                        );
                                      })
                                          .divide(const SizedBox(height: 16.0))
                                          .addToEnd(const SizedBox(height: 24.0)),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ].divide(const SizedBox(height: 24.0)),
                        ),
                      ),
                    ),
                  ),
                  if (_model.loading == false)
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: custom_widgets.FFlowSpinner(
                          width: double.infinity,
                          height: double.infinity,
                          spinnerColor: FlutterFlowTheme.of(context).primary,
                        ),
                      ),
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
