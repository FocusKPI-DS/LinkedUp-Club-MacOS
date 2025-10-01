import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'event_component_model.dart';
export 'event_component_model.dart';

class EventComponentWidget extends StatefulWidget {
  const EventComponentWidget({
    super.key,
    this.imageCover,
    this.category,
    this.nameEvent,
    required this.date,
    required this.time,
    this.location,
    this.action,
    required this.speakers,
    required this.participant,
    required this.eventRef,
    this.eventBriteId,
  });

  final String? imageCover;
  final String? category;
  final String? nameEvent;
  final String? date;
  final String? time;
  final String? location;
  final Future Function()? action;
  final List<SpeakerStruct>? speakers;
  final int? participant;
  final DocumentReference? eventRef;
  final String? eventBriteId;

  @override
  State<EventComponentWidget> createState() => _EventComponentWidgetState();
}

class _EventComponentWidgetState extends State<EventComponentWidget> {
  late EventComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EventComponentModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: InkWell(
        splashColor: Colors.transparent,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: () async {
          await widget.action?.call();
        },
        child: Container(
          width: 260.0,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            boxShadow: const [
              BoxShadow(
                blurRadius: 3.0,
                color: Color(0x33000000),
                offset: Offset(
                  0.0,
                  0.0,
                ),
              )
            ],
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: const AlignmentDirectional(1.0, -1.0),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: CachedNetworkImage(
                      fadeInDuration: const Duration(milliseconds: 300),
                      fadeOutDuration: const Duration(milliseconds: 300),
                      imageUrl: valueOrDefault<String>(
                        widget.imageCover,
                        'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fevent.jpg?alt=media&token=3e30709d-40ff-4e86-a702-5c9c2068fa8d',
                      ),
                      width: double.infinity,
                      height: 128.0,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(8.0, 8.0, 8.0, 0.0),
                    child: Container(
                      height: 30.0,
                      constraints: const BoxConstraints(
                        minWidth: 85.0,
                        maxWidth: 150.0,
                        maxHeight: 50.0,
                      ),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primary,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                8.0, 0.0, 8.0, 0.0),
                            child: Text(
                              widget.category!,
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .fontStyle,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(),
                    child: Align(
                      alignment: const AlignmentDirectional(-1.0, 0.0),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            10.0, 95.0, 0.0, 0.0),
                        child: FutureBuilder<EventsRecord>(
                          future:
                              EventsRecord.getDocumentOnce(widget.eventRef!),
                          builder: (context, snapshot) {
                            // Customize what your widget looks like when it's loading.
                            if (!snapshot.hasData) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                      0.0, 5.0, 210.0, 5.0),
                                  child: SizedBox(
                                    width: 20.0,
                                    height: 20.0,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            final rowEventsRecord = snapshot.data!;

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  children: [
                                    if (valueOrDefault<int>(
                                          widget.participant,
                                          42,
                                        ) >=
                                        1)
                                      Container(
                                        width: 26.0,
                                        height: 26.0,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                          ),
                                        ),
                                        alignment:
                                            const AlignmentDirectional(0.0, 0.0),
                                        child: FutureBuilder<UsersRecord>(
                                          future: UsersRecord.getDocumentOnce(
                                              rowEventsRecord
                                                  .participants.firstOrNull!),
                                          builder: (context, snapshot) {
                                            // Customize what your widget looks like when it's loading.
                                            if (!snapshot.hasData) {
                                              return Center(
                                                child: SizedBox(
                                                  width: 15.0,
                                                  height: 15.0,
                                                  child: SpinKitPulse(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primary,
                                                    size: 15.0,
                                                  ),
                                                ),
                                              );
                                            }

                                            final imageUsersRecord =
                                                snapshot.data!;

                                            return ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(24.0),
                                              child: CachedNetworkImage(
                                                fadeInDuration:
                                                    const Duration(milliseconds: 0),
                                                fadeOutDuration:
                                                    const Duration(milliseconds: 0),
                                                imageUrl:
                                                    valueOrDefault<String>(
                                                  imageUsersRecord.photoUrl,
                                                  'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                ),
                                                width: 30.0,
                                                height: 30.0,
                                                fit: BoxFit.cover,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    if (valueOrDefault<int>(
                                          widget.participant,
                                          42,
                                        ) >=
                                        2)
                                      Padding(
                                        padding: const EdgeInsetsDirectional.fromSTEB(
                                            20.0, 0.0, 0.0, 0.0),
                                        child: Container(
                                          width: 26.0,
                                          height: 26.0,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                            shape: BoxShape.circle,
                                          ),
                                          alignment:
                                              const AlignmentDirectional(0.0, 0.0),
                                          child: FutureBuilder<UsersRecord>(
                                            future: UsersRecord.getDocumentOnce(
                                                rowEventsRecord.participants
                                                    .elementAtOrNull(1)!),
                                            builder: (context, snapshot) {
                                              // Customize what your widget looks like when it's loading.
                                              if (!snapshot.hasData) {
                                                return Center(
                                                  child: SizedBox(
                                                    width: 15.0,
                                                    height: 15.0,
                                                    child: SpinKitPulse(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      size: 15.0,
                                                    ),
                                                  ),
                                                );
                                              }

                                              final imageUsersRecord =
                                                  snapshot.data!;

                                              return ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(24.0),
                                                child: CachedNetworkImage(
                                                  fadeInDuration:
                                                      const Duration(milliseconds: 0),
                                                  fadeOutDuration:
                                                      const Duration(milliseconds: 0),
                                                  imageUrl:
                                                      valueOrDefault<String>(
                                                    imageUsersRecord.photoUrl,
                                                    'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                  ),
                                                  width: 30.0,
                                                  height: 30.0,
                                                  fit: BoxFit.cover,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    if (valueOrDefault<int>(
                                          widget.participant,
                                          42,
                                        ) >=
                                        3)
                                      Padding(
                                        padding: const EdgeInsetsDirectional.fromSTEB(
                                            40.0, 0.0, 0.0, 0.0),
                                        child: Container(
                                          width: 26.0,
                                          height: 26.0,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                            shape: BoxShape.circle,
                                          ),
                                          alignment:
                                              const AlignmentDirectional(0.0, 0.0),
                                          child: FutureBuilder<UsersRecord>(
                                            future: UsersRecord.getDocumentOnce(
                                                rowEventsRecord.participants
                                                    .elementAtOrNull(2)!),
                                            builder: (context, snapshot) {
                                              // Customize what your widget looks like when it's loading.
                                              if (!snapshot.hasData) {
                                                return Center(
                                                  child: SizedBox(
                                                    width: 15.0,
                                                    height: 15.0,
                                                    child: SpinKitPulse(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      size: 15.0,
                                                    ),
                                                  ),
                                                );
                                              }

                                              final imageUsersRecord =
                                                  snapshot.data!;

                                              return ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(24.0),
                                                child: CachedNetworkImage(
                                                  fadeInDuration:
                                                      const Duration(milliseconds: 0),
                                                  fadeOutDuration:
                                                      const Duration(milliseconds: 0),
                                                  imageUrl:
                                                      valueOrDefault<String>(
                                                    imageUsersRecord.photoUrl,
                                                    'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                                  ),
                                                  width: 30.0,
                                                  height: 30.0,
                                                  fit: BoxFit.cover,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    if (valueOrDefault<int>(
                                          widget.participant,
                                          42,
                                        ) >
                                        3)
                                      Padding(
                                        padding: const EdgeInsetsDirectional.fromSTEB(
                                            60.0, 0.0, 0.0, 0.0),
                                        child: Container(
                                          width: 26.0,
                                          height: 26.0,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFE5E7EB),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Align(
                                            alignment:
                                                const AlignmentDirectional(0.0, 0.0),
                                            child: SizedBox(
                                              width: 16.0,
                                              height: 16.0,
                                              child: custom_widgets
                                                  .EventAttendeesCount(
                                                width: 16.0,
                                                height: 16.0,
                                                eventbriteEventId:
                                                    rowEventsRecord
                                                        .eventbriteId,
                                                showPendingLabel: false,
                                                textSize: 14.0,
                                                textColor: const Color(0xFF1F2937),
                                                eventRef:
                                                    rowEventsRecord.reference,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ].divide(const SizedBox(width: 4.0)),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (widget.eventBriteId != null &&
                      widget.eventBriteId != '')
                    Align(
                      alignment: const AlignmentDirectional(1.0, 1.0),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            0.0, 95.0, 10.0, 0.0),
                        child: Image.asset(
                          'assets/images/eventbrite-logo.png',
                          width: 25.0,
                          height: 25.0,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.nameEvent!,
                      style: FlutterFlowTheme.of(context).titleMedium.override(
                            font: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .fontStyle,
                            ),
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w500,
                            fontStyle: FlutterFlowTheme.of(context)
                                .titleMedium
                                .fontStyle,
                          ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Color(0xFF6B7280),
                          size: 16.0,
                        ),
                        RichText(
                          textScaler: MediaQuery.of(context).textScaler,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: widget.date!,
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
                                      color: const Color(0xFF6B7280),
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontStyle,
                                    ),
                              ),
                              const TextSpan(
                                text: '• ',
                                style: TextStyle(),
                              ),
                              TextSpan(
                                text: widget.time!,
                                style: const TextStyle(),
                              )
                            ],
                            style:
                                FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontStyle,
                                      ),
                                      color: const Color(0xFF6B7280),
                                      fontSize: 14.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontStyle,
                                    ),
                          ),
                        ),
                      ].divide(const SizedBox(width: 8.0)),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFF6B7280),
                          size: 16.0,
                        ),
                        Expanded(
                          child: Text(
                            widget.location!.maybeHandleOverflow(
                              maxChars: 30,
                              replacement: '…',
                            ),
                            style:
                                FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontStyle,
                                      ),
                                      color: const Color(0xFF6B7280),
                                      fontSize: 14.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontStyle,
                                    ),
                          ),
                        ),
                      ].divide(const SizedBox(width: 8.0)),
                    ),
                  ].divide(const SizedBox(height: 8.0)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
