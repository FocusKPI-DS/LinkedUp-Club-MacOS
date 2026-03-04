import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/push_notifications/push_notifications_util.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/schema/structs/index.dart';
import '/component/empty_schedule/empty_schedule_widget.dart';
import '/component/speaker_info/speaker_info_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/event/defult_chat_exist/defult_chat_exist_widget.dart';
import 'dart:math';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:branchio_dynamic_linking_akp5u6/custom_code/actions/index.dart'
    as branchio_dynamic_linking_akp5u6_actions;
import 'package:branchio_dynamic_linking_akp5u6/flutter_flow/custom_functions.dart'
    as branchio_dynamic_linking_akp5u6_functions;
import 'package:aligned_dialog/aligned_dialog.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'event_detail_model.dart';
export 'event_detail_model.dart';

/// Tech Summit 2025 Overview
class EventDetailWidget extends StatefulWidget {
  const EventDetailWidget({
    super.key,
    required this.eventId,
    this.payment,
    this.sessionId,
  });

  final String? eventId;
  final String? payment;
  final String? sessionId;

  static String routeName = 'EventDetail';
  static String routePath = '/eventDetail/:eventId';

  @override
  State<EventDetailWidget> createState() => _EventDetailWidgetState();
}

class _EventDetailWidgetState extends State<EventDetailWidget>
    with TickerProviderStateMixin {
  late EventDetailModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  var hasListViewTriggered = false;
  final animationsMap = <String, AnimationInfo>{};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EventDetailModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (widget.payment != null && widget.payment != '') {
        if (widget.payment == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payment successful! You have been registered for this event.',
                style: TextStyle(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  fontWeight: FontWeight.w500,
                ),
              ),
              duration: const Duration(milliseconds: 2000),
              backgroundColor: FlutterFlowTheme.of(context).success,
            ),
          );
        } else {
          if (widget.payment == 'cancelled') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Payment was cancelled. You can try again when ready.',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                duration: const Duration(milliseconds: 2000),
                backgroundColor: FlutterFlowTheme.of(context).error,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Unknown error. Please try again.',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                duration: const Duration(milliseconds: 2000),
                backgroundColor: FlutterFlowTheme.of(context).error,
              ),
            );
          }
        }
      }
      _model.isExist = await actions.handleDeletedContent(
        context,
        widget.eventId,
        'event',
      );
      if (_model.isExist != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Event not found.',
              style: GoogleFonts.inter(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                fontWeight: FontWeight.w500,
              ),
            ),
            duration: const Duration(milliseconds: 3000),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
        context.safePop();
        return;
      }
      _model.loading = false;
      safeSetState(() {});
      _model.events = await queryEventsRecordOnce(
        queryBuilder: (eventsRecord) => eventsRecord.where(
          'event_id',
          isEqualTo: widget.eventId,
        ),
        singleRecord: true,
      ).then((s) => s.firstOrNull);
      _model.attendeesNum = _model.events?.participants.length;
      _model.canonicalId =
          '${_model.events?.reference.id}/${currentUserReference?.path}/${valueOrDefault(currentUserDocument?.invitationCode, '')}';
      _model.eventDoc = _model.events;
      safeSetState(() {});
      _model.date = valueOrDefault<String>(
        functions.getDateFromEvent(_model.eventDoc),
        'N/A',
      );
      _model.schedule = functions
          .getScheduleFromEvent(_model.eventDoc)
          .toList()
          .cast<ScheduleStruct>();
      safeSetState(() {});
      await Future.wait([
        Future(() async {
          _model.participants = await queryParticipantRecordOnce(
            parent: _model.events?.reference,
          );
          _model.participant =
              _model.participants!.toList().cast<ParticipantRecord>();
          safeSetState(() {});
        }),
        Future(() async {
          _model.chat = await queryChatsRecordOnce(
            queryBuilder: (chatsRecord) => chatsRecord.where(
              'event_ref',
              isEqualTo: _model.events?.reference,
            ),
            singleRecord: true,
          ).then((s) => s.firstOrNull);
        }),
      ]);
      if (_model.participants!
          .where((e) => e.userRef == currentUserReference)
          .toList()
          .isNotEmpty) {
        _model.joinSelected = true;
        safeSetState(() {});
      }
      _model.loading = true;
      safeSetState(() {});
    });

    _model.tabBarController = TabController(
      vsync: this,
      length: 4,
      initialIndex: 0,
    )..addListener(() => safeSetState(() {}));

    animationsMap.addAll({
      'listViewOnActionTriggerAnimation': AnimationInfo(
        trigger: AnimationTrigger.onActionTrigger,
        applyInitialState: false,
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
      'containerOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: null,
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
    _model.dispose();

    super.dispose();
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
                  if (_model.loading == true)
                    Container(
                      width: MediaQuery.sizeOf(context).width * 1.0,
                      height: MediaQuery.sizeOf(context).height * 1.2,
                      decoration: const BoxDecoration(),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  16.0, 16.0, 16.0, 0.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        InkWell(
                                          splashColor: Colors.transparent,
                                          focusColor: Colors.transparent,
                                          hoverColor: Colors.transparent,
                                          highlightColor: Colors.transparent,
                                          onTap: () async {
                                            context.safePop();
                                          },
                                          child: Icon(
                                            Icons.arrow_back,
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            size: 28.0,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            valueOrDefault<String>(
                                              _model.eventDoc?.title,
                                              'N/A',
                                            ),
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
                                                  fontSize: 20.0,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.w500,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                ),
                                          ),
                                        ),
                                      ].divide(const SizedBox(width: 16.0)),
                                    ),
                                  ),
                                  Builder(
                                    builder: (context) => InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        _model.generate =
                                            await branchio_dynamic_linking_akp5u6_actions
                                                .generateLink(
                                          'eventDetail_${widget.eventId}',
                                          'LinkedUp Event Invite',
                                          'Join me at this${_model.eventDoc?.title}!',
                                          <String, String?>{
                                            'user_ref':
                                                currentUserReference?.id,
                                          },
                                          branchio_dynamic_linking_akp5u6_functions
                                              .createLinkProperties(
                                                  'in_app',
                                                  'invite',
                                                  'event_referral',
                                                  'event_page',
                                                  (["deeplink"]).toList(),
                                                  'deeplink',
                                                  17000, <String, String?>{
                                            'eventId':
                                                _model.eventDoc?.reference.id,
                                            'inviteCode': valueOrDefault(
                                                currentUserDocument
                                                    ?.invitationCode,
                                                ''),
                                            'deeplink_path':
                                                'eventDetail/${_model.eventDoc?.reference.id}',
                                            'invite_type': 'Event',
                                          }),
                                        );
                                        await Share.share(
                                          _model.generate!,
                                          sharePositionOrigin:
                                              getWidgetBoundingBox(context),
                                        );

                                        safeSetState(() {});
                                      },
                                      child: Icon(
                                        Icons.share,
                                        color: FlutterFlowTheme.of(context)
                                            .primary,
                                        size: 24.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                      16.0, 0.0, 16.0, 0.0),
                                  child: Container(
                                    width: double.infinity,
                                    height: 200.0,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          child: CachedNetworkImage(
                                            fadeInDuration:
                                                const Duration(milliseconds: 500),
                                            fadeOutDuration:
                                                const Duration(milliseconds: 500),
                                            imageUrl: valueOrDefault<String>(
                                              _model.eventDoc?.coverImageUrl,
                                              'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fevent.jpg?alt=media&token=3e30709d-40ff-4e86-a702-5c9c2068fa8d',
                                            ),
                                            width: double.infinity,
                                            height: double.infinity,
                                            fit: BoxFit.cover,
                                            errorWidget:
                                                (context, error, stackTrace) =>
                                                    Image.asset(
                                              'assets/images/error_image.png',
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        if (_model.eventDoc?.eventbriteId !=
                                                null &&
                                            _model.eventDoc?.eventbriteId != '')
                                          Align(
                                            alignment:
                                                const AlignmentDirectional(1.0, 1.0),
                                            child: Padding(
                                              padding: const EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      0.0, 0.0, 16.0, 16.0),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(0.0),
                                                child: Image.asset(
                                                  'assets/images/eventbrite-logo.png',
                                                  width: 50.0,
                                                  height: 50.0,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                      16.0, 0.0, 16.0, 0.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            valueOrDefault<String>(
                                              _model.eventDoc?.title,
                                              'N/A',
                                            ),
                                            style: FlutterFlowTheme.of(context)
                                                .headlineMedium
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w600,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .headlineMedium
                                                            .fontStyle,
                                                  ),
                                                  color: const Color(0xFF1F2937),
                                                  fontSize: 24.0,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.w600,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .headlineMedium
                                                          .fontStyle,
                                                ),
                                          ),
                                          Text(
                                            valueOrDefault<String>(
                                              dateTimeFormat("yMMMd",
                                                  _model.eventDoc?.startDate),
                                              'N/A',
                                            ),
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontStyle,
                                                  ),
                                                  color: const Color(0xFF4B5563),
                                                  fontSize: 16.0,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.normal,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                ),
                                          ),
                                        ].divide(const SizedBox(height: 8.0)),
                                      ),
                                      InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          await actions.linkGoogleMap(
                                            _model.eventDoc?.latlng,
                                          );
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.location_on,
                                              color: Color(0xFF4B5563),
                                              size: 16.0,
                                            ),
                                            Expanded(
                                              child: Text(
                                                valueOrDefault<String>(
                                                  _model.eventDoc?.location,
                                                  'N/A',
                                                ).maybeHandleOverflow(
                                                  maxChars: 50,
                                                ),
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodyMedium
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                      color: const Color(0xFF4B5563),
                                                      fontSize: 16.0,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                    ),
                                              ),
                                            ),
                                          ].divide(const SizedBox(width: 8.0)),
                                        ),
                                      ),
                                      InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          context.pushNamed(
                                            AllAttendeesWidget.routeName,
                                            queryParameters: {
                                              'event': serializeParam(
                                                _model.eventDoc,
                                                ParamType.Document,
                                              ),
                                            }.withoutNulls,
                                            extra: <String, dynamic>{
                                              'event': _model.eventDoc,
                                            },
                                          );
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            if ((_model
                                                    .participant.isNotEmpty) ==
                                                true)
                                              Builder(
                                                builder: (context) {
                                                  final paticipants = _model
                                                      .participant
                                                      .toList()
                                                      .take(5)
                                                      .toList();

                                                  return Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: List.generate(
                                                        paticipants.length,
                                                        (paticipantsIndex) {
                                                      final paticipantsItem =
                                                          paticipants[
                                                              paticipantsIndex];
                                                      return ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16.0),
                                                        child:
                                                            CachedNetworkImage(
                                                          fadeInDuration:
                                                              const Duration(
                                                                  milliseconds:
                                                                      300),
                                                          fadeOutDuration:
                                                              const Duration(
                                                                  milliseconds:
                                                                      300),
                                                          imageUrl:
                                                              valueOrDefault<
                                                                  String>(
                                                            paticipantsItem
                                                                .image,
                                                            'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                          ),
                                                          width: 32.0,
                                                          height: 32.0,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      );
                                                    }),
                                                  );
                                                },
                                              ),
                                            Row(
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                if ((_model.participant
                                                        .isNotEmpty) ==
                                                    false)
                                                  Text(
                                                    'Attendees: ',
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
                                                SizedBox(
                                                  width: 16.0,
                                                  height: 16.0,
                                                  child: custom_widgets
                                                      .EventAttendeesCount(
                                                    width: 16.0,
                                                    height: 16.0,
                                                    eventbriteEventId: _model
                                                        .eventDoc?.eventbriteId,
                                                    showPendingLabel: false,
                                                    textSize: 16.0,
                                                    textColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .primaryText,
                                                    eventRef: _model
                                                        .eventDoc!.reference,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ].divide(const SizedBox(width: 16.0)),
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          RichText(
                                            textScaler: MediaQuery.of(context)
                                                .textScaler,
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: 'Ticket Price: ',
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        fontSize: 14.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                ),
                                                TextSpan(
                                                  text: formatNumber(
                                                    _model.eventDoc!.price,
                                                    formatType:
                                                        FormatType.custom,
                                                    currency: '\$',
                                                    format: '0.00',
                                                    locale: 'en_US',
                                                  ),
                                                  style: TextStyle(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primary,
                                                  ),
                                                )
                                              ],
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        fontSize: 16.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                            ),
                                          ),
                                          RichText(
                                            textScaler: MediaQuery.of(context)
                                                .textScaler,
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: valueOrDefault<String>(
                                                    _model.events!
                                                                .ticketAmount >
                                                            0
                                                        ? valueOrDefault<
                                                            String>(
                                                            _model.events
                                                                ?.ticketAmount
                                                                .toString(),
                                                            '1',
                                                          )
                                                        : 'Unlimited',
                                                    '1',
                                                  ),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        fontSize: 14.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                ),
                                                TextSpan(
                                                  text: ' Tickets',
                                                  style: TextStyle(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primary,
                                                    fontSize: 14.0,
                                                  ),
                                                )
                                              ],
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        fontSize: 16.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Stack(
                                        children: [
                                          if (_model.eventDoc?.creatorId !=
                                              currentUserReference)
                                            Builder(
                                              builder: (context) {
                                                if (_model.joinSelected ==
                                                    false) {
                                                  return Builder(
                                                    builder: (context) =>
                                                        FFButtonWidget(
                                                      onPressed: () async {
                                                        var participantRecordReference =
                                                            ParticipantRecord
                                                                .createDoc(_model
                                                                    .eventDoc!
                                                                    .reference);
                                                        await participantRecordReference
                                                            .set(
                                                                createParticipantRecordData(
                                                          userId:
                                                              currentUserReference
                                                                  ?.id,
                                                          userRef:
                                                              currentUserReference,
                                                          name:
                                                              currentUserDisplayName,
                                                          joinedAt:
                                                              getCurrentTimestamp,
                                                          status:
                                                              ParticipantStatus
                                                                  .joined.name,
                                                          image:
                                                              currentUserPhoto,
                                                          bio: valueOrDefault(
                                                              currentUserDocument
                                                                  ?.bio,
                                                              ''),
                                                        ));
                                                        _model.joined = ParticipantRecord
                                                            .getDocumentFromData(
                                                                createParticipantRecordData(
                                                                  userId:
                                                                      currentUserReference
                                                                          ?.id,
                                                                  userRef:
                                                                      currentUserReference,
                                                                  name:
                                                                      currentUserDisplayName,
                                                                  joinedAt:
                                                                      getCurrentTimestamp,
                                                                  status:
                                                                      ParticipantStatus
                                                                          .joined
                                                                          .name,
                                                                  image:
                                                                      currentUserPhoto,
                                                                  bio: valueOrDefault(
                                                                      currentUserDocument
                                                                          ?.bio,
                                                                      ''),
                                                                ),
                                                                participantRecordReference);

                                                        await _model
                                                            .eventDoc!.reference
                                                            .update({
                                                          ...mapToFirestore(
                                                            {
                                                              'participants':
                                                                  FieldValue
                                                                      .arrayUnion([
                                                                currentUserReference
                                                              ]),
                                                            },
                                                          ),
                                                        });
                                                        if (_model.chat !=
                                                            null) {
                                                          _model.blocked =
                                                              await action_blocks
                                                                  .checkBlock(
                                                            context,
                                                            userRef:
                                                                currentUserReference,
                                                            blockedUser: _model
                                                                .chat
                                                                ?.blockedUser,
                                                          );
                                                          if (_model.blocked ==
                                                              true) {
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  'Unable to join event.',
                                                                  style:
                                                                      TextStyle(
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                  ),
                                                                ),
                                                                duration: const Duration(
                                                                    milliseconds:
                                                                        4000),
                                                                backgroundColor:
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondary,
                                                              ),
                                                            );
                                                          } else {
                                                            if (_model
                                                                .chat!.members
                                                                .contains(
                                                                    currentUserReference)) {
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    'You are already in the default Group Chat.',
                                                                    style:
                                                                        TextStyle(
                                                                      color: FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryText,
                                                                    ),
                                                                  ),
                                                                  duration: const Duration(
                                                                      milliseconds:
                                                                          4000),
                                                                  backgroundColor:
                                                                      FlutterFlowTheme.of(
                                                                              context)
                                                                          .secondary,
                                                                ),
                                                              );
                                                            } else {
                                                              await showAlignedDialog(
                                                                context:
                                                                    context,
                                                                isGlobal: false,
                                                                avoidOverflow:
                                                                    false,
                                                                targetAnchor:
                                                                    const AlignmentDirectional(
                                                                            0.0,
                                                                            0.0)
                                                                        .resolve(
                                                                            Directionality.of(context)),
                                                                followerAnchor:
                                                                    const AlignmentDirectional(
                                                                            0.0,
                                                                            0.0)
                                                                        .resolve(
                                                                            Directionality.of(context)),
                                                                builder:
                                                                    (dialogContext) {
                                                                  return Material(
                                                                    color: Colors
                                                                        .transparent,
                                                                    child:
                                                                        GestureDetector(
                                                                      onTap:
                                                                          () {
                                                                        FocusScope.of(dialogContext)
                                                                            .unfocus();
                                                                        FocusManager
                                                                            .instance
                                                                            .primaryFocus
                                                                            ?.unfocus();
                                                                      },
                                                                      child:
                                                                          DefultChatExistWidget(
                                                                        chatDoc:
                                                                            _model.chat!,
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                              );

                                                              await _model.chat!
                                                                  .reference
                                                                  .update({
                                                                ...mapToFirestore(
                                                                  {
                                                                    'members':
                                                                        FieldValue
                                                                            .arrayUnion([
                                                                      currentUserReference
                                                                    ]),
                                                                  },
                                                                ),
                                                              });
                                                            }
                                                          }

                                                          triggerPushNotification(
                                                            notificationTitle:
                                                                'Join Event',
                                                            notificationText:
                                                                '$currentUserDisplayName has join ${_model.eventDoc?.title} event.',
                                                            notificationSound:
                                                                'default',
                                                            userRefs: _model
                                                                .events!
                                                                .participants
                                                                .toList(),
                                                            initialPageName:
                                                                'EventDetail',
                                                            parameterData: {
                                                              'eventId': widget
                                                                  .eventId,
                                                            },
                                                          );
                                                        }
                                                        _model.joinSelected =
                                                            true;
                                                        _model.attendeesNum =
                                                            _model.attendeesNum! +
                                                                1;
                                                        safeSetState(() {});

                                                        safeSetState(() {});
                                                      },
                                                      text: 'Join',
                                                      options: FFButtonOptions(
                                                        width: double.infinity,
                                                        padding:
                                                            const EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    24.0,
                                                                    15.0,
                                                                    24.0,
                                                                    15.0),
                                                        iconPadding:
                                                            const EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    0.0,
                                                                    0.0,
                                                                    0.0),
                                                        color:
                                                            const Color(0xFF2563EB),
                                                        textStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleSmall
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .normal,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .titleSmall
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryBackground,
                                                                  fontSize:
                                                                      16.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleSmall
                                                                      .fontStyle,
                                                                ),
                                                        elevation: 0.0,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8.0),
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  return FFButtonWidget(
                                                    onPressed: () async {
                                                      if (_model.participants!
                                                          .where((e) =>
                                                              e.userRef ==
                                                              currentUserReference)
                                                          .toList()
                                                          .isNotEmpty) {
                                                        await _model
                                                            .participants!
                                                            .where((e) =>
                                                                e.userRef ==
                                                                currentUserReference)
                                                            .toList()
                                                            .firstOrNull!
                                                            .reference
                                                            .delete();

                                                        await _model
                                                            .eventDoc!.reference
                                                            .update({
                                                          ...mapToFirestore(
                                                            {
                                                              'participants':
                                                                  FieldValue
                                                                      .arrayRemove([
                                                                currentUserReference
                                                              ]),
                                                            },
                                                          ),
                                                        });
                                                      } else {
                                                        await _model
                                                            .joined!.reference
                                                            .delete();

                                                        await _model
                                                            .eventDoc!.reference
                                                            .update({
                                                          ...mapToFirestore(
                                                            {
                                                              'participants':
                                                                  FieldValue
                                                                      .arrayRemove([
                                                                currentUserReference
                                                              ]),
                                                            },
                                                          ),
                                                        });
                                                      }

                                                      _model.joinSelected =
                                                          false;
                                                      _model.attendeesNum =
                                                          _model.attendeesNum! +
                                                              -1;
                                                      safeSetState(() {});
                                                    },
                                                    text: 'Leave Event',
                                                    options: FFButtonOptions(
                                                      width: double.infinity,
                                                      padding:
                                                          const EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  24.0,
                                                                  15.0,
                                                                  24.0,
                                                                  15.0),
                                                      iconPadding:
                                                          const EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  0.0,
                                                                  0.0,
                                                                  0.0,
                                                                  0.0),
                                                      color: const Color(0xFFFA000F),
                                                      textStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .titleSmall
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleSmall
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryBackground,
                                                                fontSize: 16.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .normal,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontStyle,
                                                              ),
                                                      elevation: 0.0,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          if (_model.eventDoc?.creatorId ==
                                              currentUserReference)
                                            FFButtonWidget(
                                              onPressed: () async {
                                                context.goNamed(
                                                  CreateEventWidget.routeName,
                                                  queryParameters: {
                                                    'event': serializeParam(
                                                      _model.eventDoc,
                                                      ParamType.Document,
                                                    ),
                                                  }.withoutNulls,
                                                  extra: <String, dynamic>{
                                                    'event': _model.eventDoc,
                                                  },
                                                );
                                              },
                                              text: 'Edit Event',
                                              options: FFButtonOptions(
                                                width: double.infinity,
                                                padding: const EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        24.0, 15.0, 24.0, 15.0),
                                                iconPadding:
                                                    const EdgeInsetsDirectional
                                                        .fromSTEB(
                                                            0.0, 0.0, 0.0, 0.0),
                                                color: const Color(0xFF2563EB),
                                                textStyle: FlutterFlowTheme.of(
                                                        context)
                                                    .titleSmall
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleSmall
                                                                .fontStyle,
                                                      ),
                                                      color: FlutterFlowTheme
                                                              .of(context)
                                                          .secondaryBackground,
                                                      fontSize: 16.0,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .titleSmall
                                                              .fontStyle,
                                                    ),
                                                elevation: 0.0,
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                            ),
                                          if (_model.eventDoc?.creatorId !=
                                              currentUserReference)
                                            SizedBox(
                                              width: double.infinity,
                                              height: 50.0,
                                              child: custom_widgets
                                                  .EnhancedJoinButton(
                                                width: double.infinity,
                                                height: 50.0,
                                                eventDoc: _model.eventDoc!,
                                                onSuccess: () async {
                                                  _model.allParticipantsUpdated =
                                                      await queryParticipantRecordOnce(
                                                    parent: _model
                                                        .eventDoc?.reference,
                                                  );
                                                  _model.updatedEvent =
                                                      await EventsRecord
                                                          .getDocumentOnce(
                                                              _model.eventDoc!
                                                                  .reference);
                                                  _model.participant = _model
                                                      .allParticipantsUpdated!
                                                      .toList()
                                                      .cast<
                                                          ParticipantRecord>();
                                                  safeSetState(() {});
                                                  if ((_model.participant
                                                          .where((e) =>
                                                              e.userRef ==
                                                              currentUserReference)
                                                          .toList()
                                                          .isNotEmpty) ==
                                                      true) {
                                                    _model.joinSelected = true;
                                                    _model.attendeesNum = _model
                                                        .updatedEvent
                                                        ?.participants
                                                        .length;
                                                    safeSetState(() {});
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Successfully registered for ${_model.eventDoc?.title}',
                                                          style:
                                                              GoogleFonts.inter(
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .secondaryBackground,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                        duration: const Duration(
                                                            milliseconds: 3000),
                                                        backgroundColor:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .success,
                                                      ),
                                                    );
                                                    triggerPushNotification(
                                                      notificationTitle:
                                                          'New Attendee',
                                                      notificationText:
                                                          '$currentUserDisplayName has joined ${_model.updatedEvent?.title}',
                                                      notificationSound:
                                                          'default',
                                                      userRefs: _model
                                                          .updatedEvent!
                                                          .participants
                                                          .toList(),
                                                      initialPageName:
                                                          'EventDetail',
                                                      parameterData: {
                                                        'eventId':
                                                            widget.eventId,
                                                      },
                                                    );
                                                  }

                                                  safeSetState(() {});
                                                },
                                                onError: (errorText) async {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        errorText,
                                                        style:
                                                            GoogleFonts.inter(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      duration: const Duration(
                                                          milliseconds: 3000),
                                                      backgroundColor:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                        ],
                                      ),
                                    ].divide(const SizedBox(height: 16.0)),
                                  ),
                                ),
                              ]
                                  .divide(const SizedBox(height: 16.0))
                                  .addToStart(const SizedBox(height: 15.0))
                                  .addToEnd(const SizedBox(height: 25.0)),
                            ),
                            ClipRRect(
                              child: Container(
                                constraints: BoxConstraints(
                                  minHeight: 250.0,
                                  maxWidth:
                                      MediaQuery.sizeOf(context).width * 1.0,
                                  maxHeight: 600.0,
                                ),
                                decoration: const BoxDecoration(),
                                child: Column(
                                  children: [
                                    Align(
                                      alignment: const Alignment(0.0, 0),
                                      child: TabBar(
                                        labelColor: FlutterFlowTheme.of(context)
                                            .primary,
                                        unselectedLabelColor:
                                            FlutterFlowTheme.of(context)
                                                .secondaryText,
                                        labelStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.normal,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .titleMedium
                                                        .fontStyle,
                                              ),
                                              fontSize: 15.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.normal,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleMedium
                                                      .fontStyle,
                                            ),
                                        unselectedLabelStyle: FlutterFlowTheme
                                                .of(context)
                                            .titleMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.normal,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .titleMedium
                                                        .fontStyle,
                                              ),
                                              fontSize: 15.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.normal,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleMedium
                                                      .fontStyle,
                                            ),
                                        indicatorColor:
                                            FlutterFlowTheme.of(context)
                                                .primary,
                                        tabs: const [
                                          Tab(
                                            text: 'About',
                                          ),
                                          Tab(
                                            text: 'Schedule',
                                          ),
                                          Tab(
                                            text: 'Speakers',
                                          ),
                                          Tab(
                                            text: 'Chat',
                                          ),
                                        ],
                                        controller: _model.tabBarController,
                                        onTap: (i) async {
                                          [
                                            () async {},
                                            () async {},
                                            () async {},
                                            () async {}
                                          ][i]();
                                        },
                                      ),
                                    ),
                                    Expanded(
                                      child: TabBarView(
                                        controller: _model.tabBarController,
                                        children: [
                                          Padding(
                                            padding:
                                                const EdgeInsetsDirectional.fromSTEB(
                                                    16.0, 0.0, 16.0, 0.0),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'About Event',
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
                                                              color: const Color(
                                                                  0xFF1F2937),
                                                              fontSize: 18.0,
                                                              letterSpacing:
                                                                  0.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleMedium
                                                                      .fontStyle,
                                                            ),
                                                      ),
                                                      Text(
                                                        valueOrDefault<String>(
                                                          _model.eventDoc
                                                              ?.description,
                                                          'N/A',
                                                        ),
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .bodyMedium
                                                            .override(
                                                              font: GoogleFonts
                                                                  .inter(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .normal,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                              ),
                                                              color: const Color(
                                                                  0xFF4B5563),
                                                              fontSize: 16.0,
                                                              letterSpacing:
                                                                  0.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .normal,
                                                              fontStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                              lineHeight: 1.5,
                                                            ),
                                                      ),
                                                    ].divide(
                                                        const SizedBox(height: 12.0)),
                                                  ),
                                                  if (((_model.participant
                                                              .where((e) =>
                                                                  e.userRef ==
                                                                  currentUserReference)
                                                              .toList()
                                                              .isNotEmpty) ==
                                                          true) ||
                                                      ((_model.eventDoc
                                                                      ?.participants
                                                                      .where((e) =>
                                                                          e ==
                                                                          currentUserReference)
                                                                      .toList() !=
                                                                  null &&
                                                              (_model.eventDoc
                                                                      ?.participants
                                                                      .where((e) =>
                                                                          e ==
                                                                          currentUserReference)
                                                                      .toList())!
                                                                  .isNotEmpty) ==
                                                          true))
                                                    Padding(
                                                      padding:
                                                          const EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  0.0,
                                                                  35.0,
                                                                  0.0,
                                                                  0.0),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .max,
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              Text(
                                                                'QR Code',
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
                                                                      color: const Color(
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
                                                              Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .max,
                                                                children: [
                                                                  InkWell(
                                                                    splashColor:
                                                                        Colors
                                                                            .transparent,
                                                                    focusColor:
                                                                        Colors
                                                                            .transparent,
                                                                    hoverColor:
                                                                        Colors
                                                                            .transparent,
                                                                    highlightColor:
                                                                        Colors
                                                                            .transparent,
                                                                    onTap:
                                                                        () async {
                                                                      _model.isSuccess =
                                                                          await actions
                                                                              .downloadQRCode(
                                                                        _model
                                                                            .events!
                                                                            .qrCodeUrl,
                                                                        '${_model.eventDoc?.title}_QRCode_${_model.eventDoc?.category.firstOrNull}',
                                                                      );
                                                                      if (_model
                                                                              .isSuccess ==
                                                                          true) {
                                                                        ScaffoldMessenger.of(context)
                                                                            .showSnackBar(
                                                                          SnackBar(
                                                                            content:
                                                                                Text(
                                                                              'QR code downloaded successfully',
                                                                              style: GoogleFonts.inter(
                                                                                color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                fontWeight: FontWeight.w500,
                                                                                fontSize: 15.0,
                                                                              ),
                                                                            ),
                                                                            duration:
                                                                                const Duration(milliseconds: 2000),
                                                                            backgroundColor:
                                                                                FlutterFlowTheme.of(context).success,
                                                                          ),
                                                                        );
                                                                      }

                                                                      safeSetState(
                                                                          () {});
                                                                    },
                                                                    child: Icon(
                                                                      Icons
                                                                          .download,
                                                                      color: FlutterFlowTheme.of(
                                                                              context)
                                                                          .primary,
                                                                      size:
                                                                          24.0,
                                                                    ),
                                                                  ),
                                                                ].divide(const SizedBox(
                                                                    width:
                                                                        16.0)),
                                                              ),
                                                            ],
                                                          ),
                                                          Align(
                                                            alignment:
                                                                const AlignmentDirectional(
                                                                    0.0, 0.0),
                                                            child:
                                                                BarcodeWidget(
                                                              data: _model
                                                                  .events!
                                                                  .qrCodeUrl,
                                                              barcode: Barcode
                                                                  .qrCode(),
                                                              width: 200.0,
                                                              height: 200.0,
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .primary,
                                                              backgroundColor:
                                                                  Colors
                                                                      .transparent,
                                                              errorBuilder:
                                                                  (context,
                                                                          error) =>
                                                                      const SizedBox(
                                                                width: 200.0,
                                                                height: 200.0,
                                                              ),
                                                              drawText: false,
                                                            ),
                                                          ),
                                                        ].divide(const SizedBox(
                                                            height: 25.0)),
                                                      ),
                                                    ),
                                                ]
                                                    .divide(
                                                        const SizedBox(height: 5.0))
                                                    .addToStart(
                                                        const SizedBox(height: 16.0)),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                const EdgeInsetsDirectional.fromSTEB(
                                                    24.0, 15.0, 24.0, 0.0),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Builder(
                                                    builder: (context) {
                                                      final dateSchedule =
                                                          _model.eventDoc
                                                                  ?.dateSchedule
                                                                  .toList() ??
                                                              [];

                                                      return SingleChildScrollView(
                                                        scrollDirection:
                                                            Axis.horizontal,
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          children: List.generate(
                                                              dateSchedule
                                                                  .length,
                                                              (dateScheduleIndex) {
                                                            final dateScheduleItem =
                                                                dateSchedule[
                                                                    dateScheduleIndex];
                                                            return Align(
                                                              alignment:
                                                                  const AlignmentDirectional(
                                                                      1.0,
                                                                      -1.0),
                                                              child: InkWell(
                                                                splashColor: Colors
                                                                    .transparent,
                                                                focusColor: Colors
                                                                    .transparent,
                                                                hoverColor: Colors
                                                                    .transparent,
                                                                highlightColor:
                                                                    Colors
                                                                        .transparent,
                                                                onTap:
                                                                    () async {
                                                                  if (dateScheduleItem
                                                                          .date !=
                                                                      _model
                                                                          .date) {
                                                                    _model.schedule = dateScheduleItem
                                                                        .schedule
                                                                        .toList()
                                                                        .cast<
                                                                            ScheduleStruct>();
                                                                    _model.date =
                                                                        dateScheduleItem
                                                                            .date;
                                                                    safeSetState(
                                                                        () {});
                                                                    if (animationsMap[
                                                                            'listViewOnActionTriggerAnimation'] !=
                                                                        null) {
                                                                      safeSetState(() =>
                                                                          hasListViewTriggered =
                                                                              true);
                                                                      SchedulerBinding
                                                                          .instance
                                                                          .addPostFrameCallback((_) async => await animationsMap['listViewOnActionTriggerAnimation']!
                                                                              .controller
                                                                              .forward(from: 0.0));
                                                                    }
                                                                  }
                                                                },
                                                                child:
                                                                    Container(
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: dateScheduleItem.date ==
                                                                            _model
                                                                                .date
                                                                        ? FlutterFlowTheme.of(context)
                                                                            .primary
                                                                        : const Color(
                                                                            0x00000000),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            14.0),
                                                                    border:
                                                                        Border
                                                                            .all(
                                                                      color: FlutterFlowTheme.of(
                                                                              context)
                                                                          .accent2,
                                                                    ),
                                                                  ),
                                                                  child: Align(
                                                                    alignment:
                                                                        const AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                    child:
                                                                        Padding(
                                                                      padding: const EdgeInsetsDirectional.fromSTEB(
                                                                          16.0,
                                                                          8.0,
                                                                          16.0,
                                                                          8.0),
                                                                      child:
                                                                          Text(
                                                                        dateScheduleItem
                                                                            .date,
                                                                        style: FlutterFlowTheme.of(context)
                                                                            .bodySmall
                                                                            .override(
                                                                              font: GoogleFonts.inter(
                                                                                fontWeight: FontWeight.normal,
                                                                                fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                              ),
                                                                              color: dateScheduleItem.date == _model.date ? FlutterFlowTheme.of(context).secondaryBackground : FlutterFlowTheme.of(context).primaryText,
                                                                              fontSize: 14.0,
                                                                              letterSpacing: 0.0,
                                                                              fontWeight: FontWeight.normal,
                                                                              fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                            ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          }).divide(const SizedBox(
                                                              width: 16.0)),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  Divider(
                                                    height: 1.0,
                                                    thickness: 2.0,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .alternate,
                                                  ),
                                                  Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Sessions',
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleLarge
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .titleLarge
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  fontSize:
                                                                      15.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleLarge
                                                                      .fontStyle,
                                                                ),
                                                      ),
                                                      Container(
                                                        width: double.infinity,
                                                        constraints:
                                                            const BoxConstraints(
                                                          minHeight: 250.0,
                                                          maxHeight: 400.0,
                                                        ),
                                                        decoration:
                                                            const BoxDecoration(),
                                                        child: Builder(
                                                          builder: (context) {
                                                            final afternoonss =
                                                                _model.schedule
                                                                    .toList();
                                                            if (afternoonss
                                                                .isEmpty) {
                                                              return const EmptyScheduleWidget(
                                                                title:
                                                                    'No Schedule Exist',
                                                                description:
                                                                    'There is no schedule.',
                                                                icon: Icon(
                                                                  Icons
                                                                      .hourglass_empty_rounded,
                                                                  size: 32.0,
                                                                ),
                                                              );
                                                            }

                                                            return ListView
                                                                .builder(
                                                              padding:
                                                                  EdgeInsets
                                                                      .zero,
                                                              primary: false,
                                                              shrinkWrap: true,
                                                              scrollDirection:
                                                                  Axis.vertical,
                                                              itemCount:
                                                                  afternoonss
                                                                      .length,
                                                              itemBuilder: (context,
                                                                  afternoonssIndex) {
                                                                final afternoonssItem =
                                                                    afternoonss[
                                                                        afternoonssIndex];
                                                                return Padding(
                                                                  padding: const EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          5.0,
                                                                          10.0,
                                                                          5.0,
                                                                          10.0),
                                                                  child:
                                                                      Material(
                                                                    color: Colors
                                                                        .transparent,
                                                                    elevation:
                                                                        2.5,
                                                                    shape:
                                                                        RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              12.0),
                                                                    ),
                                                                    child:
                                                                        Container(
                                                                      width: double
                                                                          .infinity,
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .secondaryBackground,
                                                                        borderRadius:
                                                                            BorderRadius.circular(12.0),
                                                                      ),
                                                                      child:
                                                                          Padding(
                                                                        padding:
                                                                            const EdgeInsets.all(16.0),
                                                                        child:
                                                                            Row(
                                                                          mainAxisSize:
                                                                              MainAxisSize.max,
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.center,
                                                                          children:
                                                                              [
                                                                            Column(
                                                                              mainAxisSize: MainAxisSize.max,
                                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                                              children: [
                                                                                Align(
                                                                                  alignment: const AlignmentDirectional(0.0, 0.0),
                                                                                  child: Text(
                                                                                    dateTimeFormat("jm", afternoonssItem.startTime!),
                                                                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                          font: GoogleFonts.inter(
                                                                                            fontWeight: FontWeight.w500,
                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                          ),
                                                                                          color: const Color(0xFF2563EB),
                                                                                          fontSize: 16.0,
                                                                                          letterSpacing: 0.0,
                                                                                          fontWeight: FontWeight.w500,
                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                        ),
                                                                                  ),
                                                                                ),
                                                                                Align(
                                                                                  alignment: const AlignmentDirectional(0.0, 0.0),
                                                                                  child: Text(
                                                                                    valueOrDefault<String>(
                                                                                      functions.convertTRawTime(afternoonssItem.startTime, afternoonssItem.endTime),
                                                                                      '1h 30m',
                                                                                    ),
                                                                                    style: FlutterFlowTheme.of(context).titleMedium.override(
                                                                                          font: GoogleFonts.inter(
                                                                                            fontWeight: FontWeight.normal,
                                                                                            fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
                                                                                          ),
                                                                                          color: FlutterFlowTheme.of(context).secondaryText,
                                                                                          fontSize: 14.0,
                                                                                          letterSpacing: 0.0,
                                                                                          fontWeight: FontWeight.normal,
                                                                                          fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
                                                                                        ),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                            Expanded(
                                                                              child: Column(
                                                                                mainAxisSize: MainAxisSize.max,
                                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                                children: [
                                                                                  Text(
                                                                                    afternoonssItem.name,
                                                                                    style: FlutterFlowTheme.of(context).titleMedium.override(
                                                                                          font: GoogleFonts.inter(
                                                                                            fontWeight: FontWeight.w500,
                                                                                            fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
                                                                                          ),
                                                                                          fontSize: 16.0,
                                                                                          letterSpacing: 0.0,
                                                                                          fontWeight: FontWeight.w500,
                                                                                          fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
                                                                                        ),
                                                                                  ),
                                                                                  Row(
                                                                                    mainAxisSize: MainAxisSize.max,
                                                                                    children: [
                                                                                      Row(
                                                                                        mainAxisSize: MainAxisSize.max,
                                                                                        children: [
                                                                                          ClipRRect(
                                                                                            borderRadius: BorderRadius.circular(12.0),
                                                                                            child: CachedNetworkImage(
                                                                                              fadeInDuration: const Duration(milliseconds: 300),
                                                                                              fadeOutDuration: const Duration(milliseconds: 300),
                                                                                              imageUrl: valueOrDefault<String>(
                                                                                                afternoonssItem.speaker.firstOrNull?.image,
                                                                                                'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                                              ),
                                                                                              width: 24.0,
                                                                                              height: 24.0,
                                                                                              fit: BoxFit.cover,
                                                                                            ),
                                                                                          ),
                                                                                        ].divide(const SizedBox(width: 4.0)),
                                                                                      ),
                                                                                      Expanded(
                                                                                        child: AutoSizeText(
                                                                                          valueOrDefault<String>(
                                                                                            afternoonssItem.speaker.firstOrNull?.name,
                                                                                            'N/A',
                                                                                          ),
                                                                                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                                                                                font: GoogleFonts.inter(
                                                                                                  fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                                                                                                  fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                                ),
                                                                                                color: const Color(0xFF6B7280),
                                                                                                letterSpacing: 0.0,
                                                                                                fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                                                                                                fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                              ),
                                                                                        ),
                                                                                      ),
                                                                                    ].divide(const SizedBox(width: 8.0)),
                                                                                  ),
                                                                                  InkWell(
                                                                                    splashColor: Colors.transparent,
                                                                                    focusColor: Colors.transparent,
                                                                                    hoverColor: Colors.transparent,
                                                                                    highlightColor: Colors.transparent,
                                                                                    onTap: () async {
                                                                                      await actions.linkGoogleMap(
                                                                                        afternoonssItem.location,
                                                                                      );
                                                                                    },
                                                                                    child: Row(
                                                                                      mainAxisSize: MainAxisSize.max,
                                                                                      children: [
                                                                                        const Icon(
                                                                                          Icons.location_on,
                                                                                          color: Color(0xFF6B7280),
                                                                                          size: 16.0,
                                                                                        ),
                                                                                        Expanded(
                                                                                          child: Text(
                                                                                            afternoonssItem.locationName.maybeHandleOverflow(
                                                                                              maxChars: 20,
                                                                                              replacement: '…',
                                                                                            ),
                                                                                            style: FlutterFlowTheme.of(context).bodySmall.override(
                                                                                                  font: GoogleFonts.inter(
                                                                                                    fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                                                                                                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                                  ),
                                                                                                  color: const Color(0xFF6B7280),
                                                                                                  fontSize: 14.0,
                                                                                                  letterSpacing: 0.0,
                                                                                                  fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                                                                                                  fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                                ),
                                                                                          ),
                                                                                        ),
                                                                                      ].divide(const SizedBox(width: 8.0)),
                                                                                    ),
                                                                                  ),
                                                                                ].divide(const SizedBox(height: 8.0)),
                                                                              ),
                                                                            ),
                                                                            Icon(
                                                                              Icons.arrow_forward_ios,
                                                                              color: FlutterFlowTheme.of(context).secondaryText,
                                                                              size: 16.0,
                                                                            ),
                                                                          ].divide(const SizedBox(width: 16.0)),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            ).animateOnActionTrigger(
                                                                animationsMap[
                                                                    'listViewOnActionTriggerAnimation']!,
                                                                hasBeenTriggered:
                                                                    hasListViewTriggered);
                                                          },
                                                        ),
                                                      ),
                                                    ]
                                                        .divide(const SizedBox(
                                                            height: 16.0))
                                                        .addToEnd(const SizedBox(
                                                            height: 16.0)),
                                                  ),
                                                ].divide(
                                                    const SizedBox(height: 18.0)),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            height: 500.0,
                                            constraints: const BoxConstraints(
                                              maxHeight: 700.0,
                                            ),
                                            decoration: const BoxDecoration(),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Align(
                                                    alignment:
                                                        const AlignmentDirectional(
                                                            -1.0, 0.0),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  16.0,
                                                                  0.0,
                                                                  0.0,
                                                                  0.0),
                                                      child: Text(
                                                        'Feature Speaker',
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .bodyMedium
                                                            .override(
                                                              font: GoogleFonts
                                                                  .inter(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                              ),
                                                              fontSize: 18.0,
                                                              letterSpacing:
                                                                  0.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsetsDirectional
                                                            .fromSTEB(16.0, 0.0,
                                                                16.0, 0.0),
                                                    child: Builder(
                                                      builder: (context) {
                                                        final speakers = _model
                                                                .eventDoc
                                                                ?.speakers
                                                                .where((e) =>
                                                                    e.isFeature ==
                                                                    true)
                                                                .toList()
                                                                .toList() ??
                                                            [];
                                                        if (speakers.isEmpty) {
                                                          return SizedBox(
                                                            width:
                                                                double.infinity,
                                                            child:
                                                                const EmptyScheduleWidget(
                                                              title:
                                                                  'No Feature Speaker',
                                                              description:
                                                                  'We don\'t have any Feature in this event.',
                                                              icon: Icon(
                                                                Icons
                                                                    .person_off,
                                                                size: 32.0,
                                                              ),
                                                            ),
                                                          );
                                                        }

                                                        return SingleChildScrollView(
                                                          scrollDirection:
                                                              Axis.horizontal,
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .center,
                                                            children: List.generate(
                                                                speakers.length,
                                                                (speakersIndex) {
                                                              final speakersItem =
                                                                  speakers[
                                                                      speakersIndex];
                                                              return Container(
                                                                width: 175.0,
                                                                height: 200.0,
                                                                constraints:
                                                                    const BoxConstraints(
                                                                  maxWidth:
                                                                      180.0,
                                                                  maxHeight:
                                                                      200.0,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8.0),
                                                                ),
                                                                alignment:
                                                                    const AlignmentDirectional(
                                                                        0.0,
                                                                        0.0),
                                                                child: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .max,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Padding(
                                                                      padding: const EdgeInsetsDirectional.fromSTEB(
                                                                          0.0,
                                                                          0.0,
                                                                          0.0,
                                                                          8.0),
                                                                      child:
                                                                          Container(
                                                                        width: double
                                                                            .infinity,
                                                                        height:
                                                                            130.0,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          color:
                                                                              Colors.transparent,
                                                                          image:
                                                                              DecorationImage(
                                                                            fit:
                                                                                BoxFit.cover,
                                                                            alignment:
                                                                                const AlignmentDirectional(0.0, 0.0),
                                                                            image:
                                                                                CachedNetworkImageProvider(
                                                                              valueOrDefault<String>(
                                                                                speakersItem.image,
                                                                                'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          borderRadius:
                                                                              BorderRadius.circular(8.0),
                                                                        ),
                                                                        child:
                                                                            Align(
                                                                          alignment: const AlignmentDirectional(
                                                                              1.0,
                                                                              -1.0),
                                                                          child:
                                                                              Container(
                                                                            width:
                                                                                25.0,
                                                                            height:
                                                                                25.0,
                                                                            decoration:
                                                                                BoxDecoration(
                                                                              color: FlutterFlowTheme.of(context).primary,
                                                                              shape: BoxShape.circle,
                                                                            ),
                                                                            child:
                                                                                Align(
                                                                              alignment: const AlignmentDirectional(0.0, 0.0),
                                                                              child: FaIcon(
                                                                                FontAwesomeIcons.solidStar,
                                                                                color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                size: 14.0,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    Expanded(
                                                                      child:
                                                                          AutoSizeText(
                                                                        speakersItem
                                                                            .name,
                                                                        style: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .override(
                                                                              font: GoogleFonts.inter(
                                                                                fontWeight: FontWeight.w500,
                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                              ),
                                                                              color: const Color(0xFF1F2937),
                                                                              fontSize: 14.0,
                                                                              letterSpacing: 0.0,
                                                                              fontWeight: FontWeight.w500,
                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                            ),
                                                                      ),
                                                                    ),
                                                                    Expanded(
                                                                      child:
                                                                          AutoSizeText(
                                                                        speakersItem
                                                                            .role,
                                                                        style: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .override(
                                                                              font: GoogleFonts.inter(
                                                                                fontWeight: FontWeight.normal,
                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                              ),
                                                                              color: const Color(0xFF1F2937),
                                                                              fontSize: 12.0,
                                                                              letterSpacing: 0.0,
                                                                              fontWeight: FontWeight.normal,
                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                            ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ).animateOnPageLoad(
                                                                animationsMap[
                                                                    'containerOnPageLoadAnimation']!,
                                                                effects: [
                                                                  MoveEffect(
                                                                    curve: Curves
                                                                        .easeInOut,
                                                                    delay: valueOrDefault<
                                                                        double>(
                                                                      (speakersIndex *
                                                                              48)
                                                                          .toDouble(),
                                                                      48.0,
                                                                    ).ms,
                                                                    duration:
                                                                        600.0
                                                                            .ms,
                                                                    begin: const Offset(
                                                                        30.0,
                                                                        0.0),
                                                                    end: const Offset(
                                                                        0.0,
                                                                        0.0),
                                                                  ),
                                                                ],
                                                              );
                                                            }).divide(const SizedBox(
                                                                width: 8.0)),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  Align(
                                                    alignment:
                                                        const AlignmentDirectional(
                                                            -1.0, 0.0),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  16.0,
                                                                  0.0,
                                                                  0.0,
                                                                  0.0),
                                                      child: Text(
                                                        'All Speakers',
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .bodyMedium
                                                            .override(
                                                              font: GoogleFonts
                                                                  .inter(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                              ),
                                                              fontSize: 18.0,
                                                              letterSpacing:
                                                                  0.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    constraints: const BoxConstraints(
                                                      maxHeight: 450.0,
                                                    ),
                                                    decoration: const BoxDecoration(),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  16.0,
                                                                  0.0,
                                                                  16.0,
                                                                  0.0),
                                                      child: Builder(
                                                        builder: (context) {
                                                          final allSpeaker = _model
                                                                  .eventDoc
                                                                  ?.speakers
                                                                  .where((e) =>
                                                                      e.isFeature ==
                                                                      false)
                                                                  .toList()
                                                                  .toList() ??
                                                              [];
                                                          if (allSpeaker
                                                              .isEmpty) {
                                                            return const EmptyScheduleWidget(
                                                              title:
                                                                  'No Feature Speaker',
                                                              description:
                                                                  'We don\'t have any Feature in this event.',
                                                              icon: Icon(
                                                                Icons
                                                                    .person_off,
                                                                size: 32.0,
                                                              ),
                                                            );
                                                          }

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
                                                                allSpeaker
                                                                    .length,
                                                                (allSpeakerIndex) {
                                                              final allSpeakerItem =
                                                                  allSpeaker[
                                                                      allSpeakerIndex];
                                                              return wrapWithModel(
                                                                model: _model
                                                                    .speakerInfoModels
                                                                    .getModel(
                                                                  allSpeakerIndex
                                                                      .toString(),
                                                                  allSpeakerIndex,
                                                                ),
                                                                updateCallback: () =>
                                                                    safeSetState(
                                                                        () {}),
                                                                child:
                                                                    SpeakerInfoWidget(
                                                                  key: Key(
                                                                    'Keygud_${allSpeakerIndex.toString()}',
                                                                  ),
                                                                  image:
                                                                      valueOrDefault<
                                                                          String>(
                                                                    allSpeakerItem
                                                                        .image,
                                                                    'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                                  ),
                                                                  name:
                                                                      allSpeakerItem
                                                                          .name,
                                                                  role:
                                                                      allSpeakerItem
                                                                          .role,
                                                                ),
                                                              );
                                                            }),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ].divide(
                                                    const SizedBox(height: 20.0)),
                                              ),
                                            ),
                                          ),
                                          Align(
                                            alignment:
                                                const AlignmentDirectional(0.0, -1.0),
                                            child: Padding(
                                              padding: const EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      16.0, 15.0, 16.0, 0.0),
                                              child: StreamBuilder<
                                                  List<ChatsRecord>>(
                                                stream: queryChatsRecord(
                                                  queryBuilder: (chatsRecord) =>
                                                      chatsRecord
                                                          .where(
                                                            'is_group',
                                                            isEqualTo: true,
                                                          )
                                                          .where(
                                                            'event_ref',
                                                            isEqualTo: _model
                                                                .eventDoc
                                                                ?.reference,
                                                          ),
                                                ),
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
                                                  List<ChatsRecord>
                                                      columnChatsRecordList =
                                                      snapshot.data!;

                                                  return SingleChildScrollView(
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: List.generate(
                                                              columnChatsRecordList
                                                                  .length,
                                                              (columnIndex) {
                                                        final columnChatsRecord =
                                                            columnChatsRecordList[
                                                                columnIndex];
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      5.0,
                                                                      0.0,
                                                                      5.0,
                                                                      0.0),
                                                          child: InkWell(
                                                            splashColor: Colors
                                                                .transparent,
                                                            focusColor: Colors
                                                                .transparent,
                                                            hoverColor: Colors
                                                                .transparent,
                                                            highlightColor:
                                                                Colors
                                                                    .transparent,
                                                            onTap: () async {
                                                              if (columnChatsRecord
                                                                  .members
                                                                  .contains(
                                                                      currentUserReference)) {
                                                                context
                                                                    .pushNamed(
                                                                  ChatDetailWidget
                                                                      .routeName,
                                                                  queryParameters:
                                                                      {
                                                                    'chatDoc':
                                                                        serializeParam(
                                                                      columnChatsRecord,
                                                                      ParamType
                                                                          .Document,
                                                                    ),
                                                                  }.withoutNulls,
                                                                  extra: <String,
                                                                      dynamic>{
                                                                    'chatDoc':
                                                                        columnChatsRecord,
                                                                  },
                                                                );
                                                              }
                                                            },
                                                            child: Container(
                                                              width: double
                                                                  .infinity,
                                                              height: 110.0,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryBackground,
                                                                boxShadow: const [
                                                                  BoxShadow(
                                                                    blurRadius:
                                                                        6.0,
                                                                    color: Color(
                                                                        0x33000000),
                                                                    offset:
                                                                        Offset(
                                                                      0.0,
                                                                      1.0,
                                                                    ),
                                                                  )
                                                                ],
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12.0),
                                                              ),
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                            16.0),
                                                                child: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .max,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Expanded(
                                                                      child:
                                                                          Column(
                                                                        mainAxisSize:
                                                                            MainAxisSize.max,
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children:
                                                                            [
                                                                          Container(
                                                                            decoration:
                                                                                const BoxDecoration(),
                                                                            child:
                                                                                Text(
                                                                              columnChatsRecord.title.maybeHandleOverflow(
                                                                                maxChars: 20,
                                                                              ),
                                                                              style: FlutterFlowTheme.of(context).titleMedium.override(
                                                                                    font: GoogleFonts.inter(
                                                                                      fontWeight: FontWeight.w600,
                                                                                      fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
                                                                                    ),
                                                                                    fontSize: 16.0,
                                                                                    letterSpacing: 0.0,
                                                                                    fontWeight: FontWeight.w600,
                                                                                    fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
                                                                                  ),
                                                                            ),
                                                                          ),
                                                                          Text(
                                                                            columnChatsRecord.description.maybeHandleOverflow(
                                                                              maxChars: 30,
                                                                            ),
                                                                            style: FlutterFlowTheme.of(context).bodySmall.override(
                                                                                  font: GoogleFonts.inter(
                                                                                    fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                                                                                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                  ),
                                                                                  color: const Color(0xFF6B7280),
                                                                                  letterSpacing: 0.0,
                                                                                  fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                                                                                  fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                ),
                                                                          ),
                                                                          SingleChildScrollView(
                                                                            scrollDirection:
                                                                                Axis.horizontal,
                                                                            child:
                                                                                Row(
                                                                              mainAxisSize: MainAxisSize.max,
                                                                              children: [
                                                                                Row(
                                                                                  mainAxisSize: MainAxisSize.max,
                                                                                  children: [
                                                                                    Icon(
                                                                                      Icons.person_outline,
                                                                                      color: FlutterFlowTheme.of(context).secondaryText,
                                                                                      size: 18.0,
                                                                                    ),
                                                                                    RichText(
                                                                                      textScaler: MediaQuery.of(context).textScaler,
                                                                                      text: TextSpan(
                                                                                        children: [
                                                                                          TextSpan(
                                                                                            text: columnChatsRecord.members.length.toString(),
                                                                                            style: const TextStyle(),
                                                                                          ),
                                                                                          TextSpan(
                                                                                            text: ' members',
                                                                                            style: FlutterFlowTheme.of(context).bodySmall.override(
                                                                                                  font: GoogleFonts.inter(
                                                                                                    fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                                                                                                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                                  ),
                                                                                                  color: const Color(0xFF6B7280),
                                                                                                  letterSpacing: 0.0,
                                                                                                  fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                                                                                                  fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                                ),
                                                                                          )
                                                                                        ],
                                                                                        style: FlutterFlowTheme.of(context).bodySmall.override(
                                                                                              font: GoogleFonts.inter(
                                                                                                fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                                                                                                fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                              ),
                                                                                              color: const Color(0xFF6B7280),
                                                                                              letterSpacing: 0.0,
                                                                                              fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                                                                                              fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                            ),
                                                                                      ),
                                                                                    ),
                                                                                  ].divide(const SizedBox(width: 8.0)),
                                                                                ),
                                                                                Row(
                                                                                  mainAxisSize: MainAxisSize.max,
                                                                                  children: [
                                                                                    Icon(
                                                                                      Icons.chat_bubble_outline,
                                                                                      color: FlutterFlowTheme.of(context).secondaryText,
                                                                                      size: 18.0,
                                                                                    ),
                                                                                    Text(
                                                                                      'Active Chat',
                                                                                      style: FlutterFlowTheme.of(context).bodySmall.override(
                                                                                            font: GoogleFonts.inter(
                                                                                              fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                                                                                              fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                            ),
                                                                                            color: const Color(0xFF6B7280),
                                                                                            letterSpacing: 0.0,
                                                                                            fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                                                                                            fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                          ),
                                                                                    ),
                                                                                  ].divide(const SizedBox(width: 8.0)),
                                                                                ),
                                                                              ].divide(const SizedBox(width: 16.0)),
                                                                            ),
                                                                          ),
                                                                        ].divide(const SizedBox(height: 8.0)),
                                                                      ),
                                                                    ),
                                                                    if (!columnChatsRecord
                                                                        .members
                                                                        .contains(
                                                                            currentUserReference))
                                                                      FFButtonWidget(
                                                                        onPressed:
                                                                            () async {
                                                                          await columnChatsRecord
                                                                              .reference
                                                                              .update({
                                                                            ...mapToFirestore(
                                                                              {
                                                                                'members': FieldValue.arrayUnion([
                                                                                  currentUserReference
                                                                                ]),
                                                                              },
                                                                            ),
                                                                          });

                                                                          context
                                                                              .pushNamed(
                                                                            ChatDetailWidget.routeName,
                                                                            queryParameters:
                                                                                {
                                                                              'chatDoc': serializeParam(
                                                                                columnChatsRecord,
                                                                                ParamType.Document,
                                                                              ),
                                                                            }.withoutNulls,
                                                                            extra: <String,
                                                                                dynamic>{
                                                                              'chatDoc': columnChatsRecord,
                                                                            },
                                                                          );
                                                                        },
                                                                        text:
                                                                            'Join',
                                                                        options:
                                                                            FFButtonOptions(
                                                                          height:
                                                                              40.0,
                                                                          padding: const EdgeInsetsDirectional.fromSTEB(
                                                                              15.0,
                                                                              10.0,
                                                                              15.0,
                                                                              10.0),
                                                                          iconPadding: const EdgeInsetsDirectional.fromSTEB(
                                                                              0.0,
                                                                              0.0,
                                                                              0.0,
                                                                              0.0),
                                                                          color:
                                                                              const Color(0xFF2563EB),
                                                                          textStyle: FlutterFlowTheme.of(context)
                                                                              .titleSmall
                                                                              .override(
                                                                                font: GoogleFonts.inter(
                                                                                  fontWeight: FontWeight.normal,
                                                                                  fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                ),
                                                                                color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                fontSize: 16.0,
                                                                                letterSpacing: 0.0,
                                                                                fontWeight: FontWeight.normal,
                                                                                fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                              ),
                                                                          elevation:
                                                                              0.0,
                                                                          borderRadius:
                                                                              BorderRadius.circular(8.0),
                                                                        ),
                                                                      ),
                                                                  ].divide(const SizedBox(
                                                                      width:
                                                                          16.0)),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      })
                                                          .divide(const SizedBox(
                                                              height: 16.0))
                                                          .addToEnd(const SizedBox(
                                                              height: 24.0)),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_model.loading == false)
                    Container(
                      width: MediaQuery.sizeOf(context).width * 1.0,
                      height: MediaQuery.sizeOf(context).height * 1.0,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                      ),
                      child: SizedBox(
                        width: 300.0,
                        height: 300.0,
                        child: custom_widgets.FFlowSpinner(
                          width: 300.0,
                          height: 300.0,
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
