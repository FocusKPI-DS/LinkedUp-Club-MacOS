// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your widget name, define your parameter, and then add the
// boilerplate code using the green button on the right!

import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PaymentSuccessCustomWidget extends StatefulWidget {
  const PaymentSuccessCustomWidget({
    super.key,
    this.width,
    this.height,
    required this.eventId,
    this.payment,
    this.sessionId,
  });

  final double? width;
  final double? height;
  final String eventId;
  final String? payment;
  final String? sessionId;

  @override
  State<PaymentSuccessCustomWidget> createState() =>
      _PaymentSuccessCustomWidgetState();
}

class _PaymentSuccessCustomWidgetState extends State<PaymentSuccessCustomWidget>
    with TickerProviderStateMixin {
  EventsRecord? eventDetails;
  final animationsMap = <String, AnimationInfo>{};

  @override
  void initState() {
    super.initState();

    // Fetch event details on page load
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await _fetchEventDetails();
    });

    animationsMap.addAll({
      'containerOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          VisibilityEffect(duration: 1.ms),
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: const Offset(0.0, 100.0),
            end: const Offset(0.0, 0.0),
          ),
        ],
      ),
      'iconOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          ScaleEffect(
            curve: Curves.elasticOut,
            delay: 300.0.ms,
            duration: 900.0.ms,
            begin: const Offset(0.0, 0.0),
            end: const Offset(1.0, 1.0),
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

    WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
  }

  Future<void> _fetchEventDetails() async {
    if (widget.eventId.isNotEmpty) {
      try {
        final eventQuery = await FirebaseFirestore.instance
            .collection('events')
            .where('event_id', isEqualTo: widget.eventId)
            .limit(1)
            .get();

        if (eventQuery.docs.isNotEmpty) {
          setState(() {
            eventDetails = EventsRecord.fromSnapshot(eventQuery.docs.first);
          });
        }
      } catch (e) {
        print('Error fetching event details: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.payment == 'success';
    final isCancelled = widget.payment == 'cancelled';
    final isLoggedIn = currentUser?.loggedIn ?? false;

    return Container(
      width: widget.width ?? MediaQuery.sizeOf(context).width,
      height: widget.height ?? MediaQuery.sizeOf(context).height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FlutterFlowTheme.of(context).primaryBackground,
            isSuccess
                ? const Color(0xFFE8F5E9)
                : isCancelled
                    ? const Color(0xFFFFF3E0)
                    : const Color(0xFFFFEBEE),
          ],
          stops: const [0.0, 1.0],
          begin: const AlignmentDirectional(0.0, -1.0),
          end: const AlignmentDirectional(0.0, 1.0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(24.0, 24.0, 24.0, 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Status Icon
            Container(
              width: 120.0,
              height: 120.0,
              decoration: BoxDecoration(
                color: isSuccess
                    ? const Color(0xFF4CAF50)
                    : isCancelled
                        ? const Color(0xFFFFA726)
                        : const Color(0xFFEF5350),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 20.0,
                    color: (isSuccess
                            ? const Color(0xFF4CAF50)
                            : isCancelled
                                ? const Color(0xFFFFA726)
                                : const Color(0xFFEF5350))
                        .withOpacity(0.3),
                    offset: const Offset(0.0, 10.0),
                  )
                ],
              ),
              child: Center(
                child: Icon(
                  isSuccess
                      ? Icons.check_rounded
                      : isCancelled
                          ? Icons.close_rounded
                          : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 60.0,
                ),
              ),
            ).animateOnPageLoad(animationsMap['iconOnPageLoadAnimation']!),

            // Status Title
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(0.0, 32.0, 0.0, 0.0),
              child: Text(
                isSuccess
                    ? 'Payment Successful!'
                    : isCancelled
                        ? 'Payment Cancelled'
                        : 'Payment Failed',
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).headlineLarge.override(
                      font: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                      ),
                      color: FlutterFlowTheme.of(context).primaryText,
                      fontSize: 32.0,
                      letterSpacing: 0.0,
                    ),
              ),
            ),

            // Status Message
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
              child: Text(
                isSuccess
                    ? 'Your ticket has been successfully purchased${eventDetails != null ? ' for ${eventDetails!.title}' : ''}!'
                    : isCancelled
                        ? 'Your payment was cancelled. You can try again when you\'re ready.'
                        : 'There was an issue processing your payment. Please try again.',
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).bodyLarge.override(
                      font: GoogleFonts.inter(),
                      color: FlutterFlowTheme.of(context).secondaryText,
                      fontSize: 16.0,
                      letterSpacing: 0.0,
                      lineHeight: 1.5,
                    ),
              ),
            ),

            // Event Details Card (if available)
            if (eventDetails != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0.0, 32.0, 0.0, 0.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 10.0,
                        color: Color(0x1A000000),
                        offset: Offset(0.0, 2.0),
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Event Details',
                          style:
                              FlutterFlowTheme.of(context).titleMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    letterSpacing: 0.0,
                                  ),
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              0.0, 12.0, 0.0, 0.0),
                          child: Text(
                            eventDetails!.title,
                            style:
                                FlutterFlowTheme.of(context).bodyLarge.override(
                                      font: GoogleFonts.inter(),
                                      letterSpacing: 0.0,
                                    ),
                          ),
                        ),
                        if (eventDetails!.startDate != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                0.0, 8.0, 0.0, 0.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                  size: 16.0,
                                ),
                                Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                      8.0, 0.0, 0.0, 0.0),
                                  child: Text(
                                    dateTimeFormat(
                                        'yMMMd', eventDetails!.startDate!),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.inter(),
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (eventDetails!.location.isNotEmpty)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                0.0, 8.0, 0.0, 0.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                  size: 16.0,
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsetsDirectional.fromSTEB(
                                        8.0, 0.0, 0.0, 0.0),
                                    child: Text(
                                      eventDetails!.location
                                          .maybeHandleOverflow(
                                        maxChars: 50,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.inter(),
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            letterSpacing: 0.0,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ).animateOnPageLoad(
                    animationsMap['containerOnPageLoadAnimation']!),
              ),

            // Action Buttons
            Expanded(
              child: Align(
                alignment: const AlignmentDirectional(0.0, 1.0),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(0.0, 32.0, 0.0, 0.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Primary Button
                      FFButtonWidget(
                        onPressed: () async {
                          if (isLoggedIn) {
                            // Check if we're on web and should try to open mobile app
                            if (kIsWeb) {
                              // Try to open the mobile app using deeplink
                              final deeplinkUrl =
                                  'linkedupclub://linkedupclub.app.link/eventDetail/${widget.eventId}?payment=${widget.payment ?? ''}&sessionId=${widget.sessionId ?? ''}';

                              try {
                                final Uri deeplink = Uri.parse(deeplinkUrl);
                                if (await canLaunchUrl(deeplink)) {
                                  await launchUrl(
                                    deeplink,
                                    mode: LaunchMode.externalApplication,
                                  );
                                  return; // Exit after launching deeplink
                                }
                              } catch (e) {
                                print('Could not launch deeplink: $e');
                              }

                              // If deeplink fails, fall back to web navigation
                              context.pushNamed(
                                'EventDetail',
                                pathParameters: {
                                  'eventId': widget.eventId,
                                }.withoutNulls,
                                queryParameters: {
                                  'payment': widget.payment,
                                  'sessionId': widget.sessionId,
                                }.withoutNulls,
                              );
                            } else {
                              // In mobile app - use normal navigation
                              context.pushNamed(
                                'EventDetail',
                                pathParameters: {
                                  'eventId': widget.eventId,
                                }.withoutNulls,
                                queryParameters: {
                                  'payment': widget.payment,
                                  'sessionId': widget.sessionId,
                                }.withoutNulls,
                              );
                            }
                          } else {
                            // User is not logged in - navigate to login
                            // Store the event ID in app state for redirect after login
                            FFAppState().update(() {
                              FFAppState().eventId = widget.eventId;
                              // Store payment status in linkUrl temporarily
                              FFAppState().linkUrl =
                                  'payment:${widget.payment}:${widget.sessionId}';
                            });

                            context.goNamed('Login');
                          }
                        },
                        text: isLoggedIn
                            ? (isSuccess ? 'View Your Ticket' : 'Back to Event')
                            : 'Login to View Ticket',
                        icon: Icon(
                          isLoggedIn
                              ? Icons.confirmation_number_outlined
                              : Icons.login,
                          size: 20.0,
                        ),
                        options: FFButtonOptions(
                          width: double.infinity,
                          height: 56.0,
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              24.0, 0.0, 24.0, 0.0),
                          iconPadding: const EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 8.0, 0.0),
                          color: FlutterFlowTheme.of(context).primary,
                          textStyle:
                              FlutterFlowTheme.of(context).titleMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    color: Colors.white,
                                    letterSpacing: 0.0,
                                  ),
                          elevation: 3.0,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),

                      // Secondary Button (if cancelled or failed)
                      if (!isSuccess)
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              0.0, 16.0, 0.0, 0.0),
                          child: FFButtonWidget(
                            onPressed: () async {
                              // Try again - go back to event detail
                              if (isLoggedIn) {
                                if (kIsWeb) {
                                  // Try to open the mobile app using deeplink
                                  final deeplinkUrl =
                                      'linkedupclub://linkedupclub.app.link/eventDetail/${widget.eventId}';

                                  try {
                                    final Uri deeplink = Uri.parse(deeplinkUrl);
                                    if (await canLaunchUrl(deeplink)) {
                                      await launchUrl(
                                        deeplink,
                                        mode: LaunchMode.externalApplication,
                                      );
                                      return;
                                    }
                                  } catch (e) {
                                    print('Could not launch deeplink: $e');
                                  }

                                  // Fallback to web navigation
                                  context.pushNamed(
                                    'EventDetail',
                                    pathParameters: {
                                      'eventId': widget.eventId,
                                    }.withoutNulls,
                                  );
                                } else {
                                  // In mobile app - use normal navigation
                                  context.pushNamed(
                                    'EventDetail',
                                    pathParameters: {
                                      'eventId': widget.eventId,
                                    }.withoutNulls,
                                  );
                                }
                              } else {
                                // Go to home/discover page
                                context.goNamed('Welcome');
                              }
                            },
                            text: isLoggedIn ? 'Try Again' : 'Go to Home',
                            icon: Icon(
                              isLoggedIn ? Icons.refresh : Icons.home,
                              size: 20.0,
                            ),
                            options: FFButtonOptions(
                              width: double.infinity,
                              height: 56.0,
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  24.0, 0.0, 24.0, 0.0),
                              iconPadding: const EdgeInsetsDirectional.fromSTEB(
                                  0.0, 0.0, 8.0, 0.0),
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                              textStyle: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    letterSpacing: 0.0,
                                  ),
                              elevation: 0.0,
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).alternate,
                                width: 2.0,
                              ),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        ),

                      // Help Text
                      if (!isLoggedIn && isSuccess)
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              0.0, 24.0, 0.0, 0.0),
                          child: Text(
                            'Don\'t worry! Your ticket is saved. Log in to access it anytime.',
                            textAlign: TextAlign.center,
                            style:
                                FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.inter(),
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      fontSize: 14.0,
                                      letterSpacing: 0.0,
                                    ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
