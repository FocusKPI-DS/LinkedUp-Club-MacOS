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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:linkedup/auth/firebase_auth/auth_util.dart';
import 'package:linkedup/flutter_flow/flutter_flow_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class EventTicketPurchaseButton extends StatefulWidget {
  const EventTicketPurchaseButton({
    Key? key,
    this.width,
    this.height,
    required this.event,
    this.onSuccess,
    this.onError,
  }) : super(key: key);

  final double? width;
  final double? height;
  final EventsRecord event;
  final Future Function()? onSuccess;
  final Future Function(String errorText)? onError;

  @override
  _EventTicketPurchaseButtonState createState() =>
      _EventTicketPurchaseButtonState();
}

class _EventTicketPurchaseButtonState extends State<EventTicketPurchaseButton> {
  bool _isProcessing = false;
  bool _hasTicket = false;

  @override
  void initState() {
    super.initState();
    _checkIfUserHasTicket();
  }

  Future<void> _checkIfUserHasTicket() async {
    if (currentUserReference == null) return;

    // Check if user is already a participant
    if (widget.event.participants.contains(currentUserReference)) {
      setState(() {
        _hasTicket = true;
      });
      return;
    }

    // Also check payment history
    final paymentHistory = await FirebaseFirestore.instance
        .collection('payment_history')
        .where('user_ref', isEqualTo: currentUserReference)
        .where('event_ref', isEqualTo: widget.event.reference)
        .where('status', isEqualTo: 'completed')
        .limit(1)
        .get();

    if (paymentHistory.docs.isNotEmpty) {
      setState(() {
        _hasTicket = true;
      });
    }
  }

  Future<void> _handlePurchase() async {
    if (_isProcessing || _hasTicket) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Check if this is an Eventbrite event - redirect to Eventbrite if so
      if (widget.event.eventbriteId != null &&
          widget.event.eventbriteId!.isNotEmpty &&
          widget.event.useEventbriteTicketing == true) {
        // Redirect to Eventbrite for ticket purchase
        String eventbriteUrl =
            'https://www.eventbrite.com/e/${widget.event.eventbriteId}';
        if (await canLaunchUrl(Uri.parse(eventbriteUrl))) {
          await launchUrl(
            Uri.parse(eventbriteUrl),
            mode: LaunchMode.externalApplication,
          );
        }
        setState(() {
          _isProcessing = false;
        });
        if (widget.onError != null) {
          await widget
              .onError!('Redirecting to Eventbrite for ticket purchase');
        }
        return;
      }

      // Get event type - default to physical if not specified
      String eventType = widget.event.eventType;

      // Check if event is free
      final price = widget.event.price;

      // Check if tickets are still available
      if (widget.event.ticketAmount > 0) {
        final participantCount = widget.event.participants.length;
        if (participantCount >= widget.event.ticketAmount) {
          setState(() {
            _isProcessing = false;
          });
          if (widget.onError != null) {
            await widget.onError!('Sorry, this event is sold out');
          }
          return;
        }
      }

      // Check if ticket deadline has passed
      if (widget.event.ticketDeadline != null) {
        if (DateTime.now().isAfter(widget.event.ticketDeadline!)) {
          setState(() {
            _isProcessing = false;
          });
          if (widget.onError != null) {
            await widget.onError!('Ticket sales have ended for this event');
          }
          return;
        }
      }

      // Process the purchase
      final result = await purchaseEventTicket(
        widget.event.eventId.isNotEmpty
            ? widget.event.eventId
            : widget.event.reference.id,
        widget.event.title,
        price * 100, // Convert to cents
        widget.event.reference,
        eventType,
      );

      if (result.success) {
        // For Stripe payments, don't immediately mark as registered
        // since the user needs to complete the checkout
        if (eventType == 'physical' || eventType == 'hybrid') {
          // Stripe redirects to checkout, so we don't mark as registered yet
          // The webhook will handle the actual registration
          if (widget.onSuccess != null) {
            await widget.onSuccess!();
          }
        } else {
          // For free events and RevenueCat, mark as registered immediately
          setState(() {
            _hasTicket = true;
          });
          if (widget.onSuccess != null) {
            await widget.onSuccess!();
          }
        }
      } else {
        // Ensure we reset the ticket state on failure
        setState(() {
          _hasTicket = false;
        });
        if (widget.onError != null) {
          await widget.onError!(result.message);
        }
      }
    } catch (e) {
      if (widget.onError != null) {
        await widget.onError!('An error occurred: ${e.toString()}');
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  String _getButtonText() {
    if (_hasTicket) {
      return 'Already Registered';
    }

    if (_isProcessing) {
      return 'Processing...';
    }

    final price = widget.event.price;
    if (price == 0) {
      return 'Register for Free';
    }

    return 'Get Ticket - \$${price.toStringAsFixed(2)}';
  }

  Color _getButtonColor(BuildContext context) {
    if (_hasTicket) {
      return FlutterFlowTheme.of(context).success;
    }

    if (_isProcessing) {
      return FlutterFlowTheme.of(context).accent2;
    }

    return FlutterFlowTheme.of(context).primary;
  }

  @override
  Widget build(BuildContext context) {
    // Check if event has passed
    if (widget.event.endDate != null &&
        DateTime.now().isAfter(widget.event.endDate!)) {
      return Container(
        width: widget.width ?? double.infinity,
        height: widget.height ?? 48.0,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).accent2,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Center(
          child: Text(
            'Event has ended',
            style: FlutterFlowTheme.of(context).titleSmall.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                  ),
                  color: FlutterFlowTheme.of(context).secondaryText,
                  fontSize: 16.0,
                  letterSpacing: 0.0,
                ),
          ),
        ),
      );
    }

    // Check if tickets are sold out
    if (widget.event.ticketAmount > 0 &&
        widget.event.participants.length >= widget.event.ticketAmount) {
      return Container(
        width: widget.width ?? double.infinity,
        height: widget.height ?? 48.0,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).accent2,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Center(
          child: Text(
            'Sold Out',
            style: FlutterFlowTheme.of(context).titleSmall.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                  ),
                  color: FlutterFlowTheme.of(context).secondaryText,
                  fontSize: 16.0,
                  letterSpacing: 0.0,
                ),
          ),
        ),
      );
    }

    return FFButtonWidget(
      onPressed: (_hasTicket || _isProcessing) ? null : _handlePurchase,
      text: _getButtonText(),
      icon: _isProcessing
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  FlutterFlowTheme.of(context).info,
                ),
              ),
            )
          : (_hasTicket
              ? Icon(
                  Icons.check_circle,
                  size: 20.0,
                )
              : Icon(
                  Icons.confirmation_number,
                  size: 20.0,
                )),
      options: FFButtonOptions(
        width: widget.width ?? double.infinity,
        height: widget.height ?? 48.0,
        padding: EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
        iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 8.0, 0.0),
        color: _getButtonColor(context),
        textStyle: FlutterFlowTheme.of(context).titleSmall.override(
              font: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
              ),
              color: FlutterFlowTheme.of(context).info,
              fontSize: 16.0,
              letterSpacing: 0.0,
            ),
        elevation: 0.0,
        borderRadius: BorderRadius.circular(8.0),
        disabledColor: FlutterFlowTheme.of(context).accent2,
      ),
    );
  }
}
