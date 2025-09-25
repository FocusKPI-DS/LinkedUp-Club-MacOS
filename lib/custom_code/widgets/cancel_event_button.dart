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
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:google_fonts/google_fonts.dart';

class CancelEventButton extends StatefulWidget {
  const CancelEventButton({
    Key? key,
    this.width,
    this.height,
    required this.event,
    this.onCancelled,
  }) : super(key: key);

  final double? width;
  final double? height;
  final EventsRecord event;
  final Future Function()? onCancelled;

  @override
  _CancelEventButtonState createState() => _CancelEventButtonState();
}

class _CancelEventButtonState extends State<CancelEventButton> {
  bool _isLoading = false;

  Future<void> _cancelEvent() async {
    // Show confirmation dialog
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Cancel Event',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
                  fontSize: 20.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
          ),
          content: Text(
            'Are you sure you want to cancel this event? This action cannot be undone.',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.normal,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.normal,
                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight: FontWeight.normal,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).secondaryText,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.normal,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
              ),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text(
                'Yes, Cancel Event',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).error,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get event reference
      DocumentReference eventRef = widget.event.reference;

      // Create batch for atomic operations
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // Delete the event
      batch.delete(eventRef);

      // Delete all participant subcollection documents
      QuerySnapshot participantsSnapshot =
          await eventRef.collection('participant').get();
      for (DocumentSnapshot doc in participantsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all event attendees records
      QuerySnapshot attendeesSnapshot = await FirebaseFirestore.instance
          .collection('eventAttendees')
          .where('event_ref', isEqualTo: eventRef)
          .get();
      for (DocumentSnapshot doc in attendeesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Update users to remove event from participants array
      if (widget.event.participants.isNotEmpty) {
        for (DocumentReference userRef in widget.event.participants) {
          batch.update(userRef, {
            'participants': FieldValue.arrayRemove([eventRef]),
          });
        }
      }

      // Delete associated chat groups if they exist
      if (widget.event.chatGroups.isNotEmpty) {
        for (DocumentReference chatRef in widget.event.chatGroups) {
          batch.delete(chatRef);
        }
      }

      // Send cancellation notification to all participants
      if (widget.event.participants.isNotEmpty) {
        Map<String, dynamic> notificationData = {
          'notification_title': 'Event Cancelled',
          'notification_text':
              'The event "${widget.event.title}" has been cancelled by the organizer.',
          'sender': currentUserReference?.path,
          'timestamp': FieldValue.serverTimestamp(),
          'user_refs': widget.event.participants
              .map((ref) => ref.path)
              .toList()
              .join(','),
        };

        DocumentReference notificationRef = FirebaseFirestore.instance
            .collection('ff_user_push_notifications')
            .doc();
        batch.set(notificationRef, notificationData);
      }

      // Commit all changes
      await batch.commit();

      // Call the onCancelled callback if provided
      if (widget.onCancelled != null) {
        await widget.onCancelled!();
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event cancelled successfully'),
          backgroundColor: FlutterFlowTheme.of(context).success,
        ),
      );
    } catch (error) {
      print('Error cancelling event: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling event. Please try again.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show button if current user is the event creator
    if (widget.event.creatorId != currentUserReference) {
      return SizedBox.shrink();
    }

    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 48.0,
      child: FFButtonWidget(
        onPressed: _isLoading ? null : _cancelEvent,
        text: _isLoading ? 'Cancelling...' : 'Cancel Event',
        options: FFButtonOptions(
          width: double.infinity,
          height: 48.0,
          padding: EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
          iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
          color: FlutterFlowTheme.of(context).error,
          textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                font: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                ),
                color: FlutterFlowTheme.of(context).secondaryBackground,
                fontSize: 16.0,
                letterSpacing: 0.0,
                fontWeight: FontWeight.w500,
                fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
              ),
          elevation: 0.0,
          borderSide: BorderSide(
            color: Colors.transparent,
            width: 0.0,
          ),
          borderRadius: BorderRadius.circular(8.0),
          disabledColor: FlutterFlowTheme.of(context).accent2,
        ),
      ),
    );
  }
}
