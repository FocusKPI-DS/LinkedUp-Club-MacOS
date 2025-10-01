import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'all_attendees_model.dart';
export 'all_attendees_model.dart';

/// Chat Interface Overview
class AllAttendeesWidget extends StatefulWidget {
  const AllAttendeesWidget({
    super.key,
    required this.event,
  });

  final EventsRecord? event;

  static String routeName = 'AllAttendees';
  static String routePath = '/allAttendees';

  @override
  State<AllAttendeesWidget> createState() => _AllAttendeesWidgetState();
}

class _AllAttendeesWidgetState extends State<AllAttendeesWidget> {
  late AllAttendeesModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AllAttendeesModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.loading = true;
      safeSetState(() {});
      _model.participant = await queryParticipantRecordOnce(
        parent: widget.event?.reference,
      );
      _model.participants =
          _model.participant!.toList().cast<ParticipantRecord>();
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFFF9FAFB),
        body: SingleChildScrollView(
          primary: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Align(
                  alignment: const AlignmentDirectional(-1.0, 0.0),
                  child: Padding(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(16.0, 50.0, 0.0, 0.0),
                    child: FlutterFlowIconButton(
                      borderRadius: 8.0,
                      buttonSize: 40.0,
                      fillColor: Colors.transparent,
                      icon: Icon(
                        Icons.arrow_back,
                        color: FlutterFlowTheme.of(context).primaryText,
                        size: 24.0,
                      ),
                      onPressed: () async {
                        context.safePop();
                      },
                    ),
                  ),
                ),
              ),
              Align(
                alignment: const AlignmentDirectional(0.0, -1.0),
                child: Container(
                  width: double.infinity,
                  height: MediaQuery.sizeOf(context).height * 1.0,
                  constraints: const BoxConstraints(
                    maxWidth: 650.0,
                  ),
                  decoration: const BoxDecoration(),
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: custom_widgets.EnhancedAllAttendees(
                      width: double.infinity,
                      height: double.infinity,
                      eventbriteId: widget.event?.eventbriteId,
                      useEventbriteTicketing: false,
                      showEventbriteControls:
                          widget.event?.creatorId == currentUserReference,
                      event: widget.event!,
                      eventRef: widget.event!.reference,
                      onSyncAttendees: () async {
                        _model.isSuccess =
                            await actions.syncEventbriteAttendees(
                          widget.event!.eventbriteId,
                        );
                        if (_model.isSuccess == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Attendees synced successfully!',
                                style: GoogleFonts.inter(
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15.0,
                                ),
                              ),
                              duration: const Duration(milliseconds: 2000),
                              backgroundColor:
                                  FlutterFlowTheme.of(context).success,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Attendees synced failed',
                                style: GoogleFonts.inter(
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15.0,
                                ),
                              ),
                              duration: const Duration(milliseconds: 2000),
                              backgroundColor:
                                  FlutterFlowTheme.of(context).error,
                            ),
                          );
                        }

                        safeSetState(() {});
                      },
                      onUpdateTicketingMode: (useEventbrite) async {
                        _model.success = await actions.updateEventTicketingMode(
                          widget.event!.reference.id,
                          widget.event!.useEventbriteTicketing,
                        );
                        if (_model.success == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Ticketing mode synced successfully!',
                                style: GoogleFonts.inter(
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15.0,
                                ),
                              ),
                              duration: const Duration(milliseconds: 2000),
                              backgroundColor:
                                  FlutterFlowTheme.of(context).success,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Ticketing mode synced failed',
                                style: GoogleFonts.inter(
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15.0,
                                ),
                              ),
                              duration: const Duration(milliseconds: 2000),
                              backgroundColor:
                                  FlutterFlowTheme.of(context).error,
                            ),
                          );
                        }

                        safeSetState(() {});
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
