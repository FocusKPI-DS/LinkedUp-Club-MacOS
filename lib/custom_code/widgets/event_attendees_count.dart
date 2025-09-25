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

/// A widget that displays the combined attendee count from both LinkedUp
/// participants and EventBrite attendees.
///
/// This merges data from: - events/{eventId}.participants (LinkedUp users who
/// joined) - event_attendees collection (EventBrite ticket holders)
///
/// Parameters: - eventRef: Reference to the event document -
/// eventbriteEventId: The EventBrite event ID (if applicable) -
/// showPendingLabel: Whether to show "(X pending)" for non-LinkedUp users -
/// textSize: Font size for the count display (default: 14.0) - textColor:
/// Color for the count display (default: primaryText)
class EventAttendeesCount extends StatefulWidget {
  const EventAttendeesCount({
    super.key,
    this.width,
    this.height,
    required this.eventRef,
    this.eventbriteEventId,
    this.showPendingLabel = true,
    this.textSize = 14.0,
    this.textColor,
  });

  final double? width;
  final double? height;
  final DocumentReference eventRef;
  final String? eventbriteEventId;
  final bool showPendingLabel;
  final double textSize;
  final Color? textColor;

  @override
  State<EventAttendeesCount> createState() => _EventAttendeesCountState();
}

class _EventAttendeesCountState extends State<EventAttendeesCount> {
  int _linkedUpCount = 0;
  int _eventbriteCount = 0;
  int _pendingCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttendeeCounts();
  }

  Future<void> _loadAttendeeCounts() async {
    try {
      Set<String> uniqueEmails = {};

      // Get LinkedUp participants count from subcollection
      final participantsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventRef.id)
          .collection('participant')
          .get();

      // Count LinkedUp participants and collect emails
      _linkedUpCount = participantsSnapshot.docs.length;
      for (var doc in participantsSnapshot.docs) {
        final data = doc.data();
        final userRef = data['user_ref'] as DocumentReference?;
        if (userRef != null) {
          try {
            final userDoc = await userRef.get();
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              final email = userData['email'] as String?;
              if (email != null && email.isNotEmpty) {
                uniqueEmails.add(email.toLowerCase());
              }
            }
          } catch (e) {
            // Continue if user document not found
          }
        }
      }

      // Get EventBrite attendees count if applicable
      if (widget.eventbriteEventId != null &&
          widget.eventbriteEventId!.isNotEmpty) {
        final eventbriteQuery = await FirebaseFirestore.instance
            .collection('event_attendees')
            .where('event_id', isEqualTo: widget.eventbriteEventId)
            .get();

        // Count only EventBrite attendees not already in LinkedUp
        int eventbriteOnlyCount = 0;
        _pendingCount = 0;

        for (var doc in eventbriteQuery.docs) {
          final data = doc.data();
          final email = (data['email'] as String?)?.toLowerCase();
          final isPending = data['is_pending_verification'] == true;

          if (email != null && !uniqueEmails.contains(email)) {
            eventbriteOnlyCount++;
            if (isPending) {
              _pendingCount++;
            }
          }
        }

        _eventbriteCount = eventbriteOnlyCount;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading attendee counts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Text(
        '...',
        style: FlutterFlowTheme.of(context).bodyMedium.override(
              font: GoogleFonts.inter(),
              fontSize: widget.textSize,
              color:
                  widget.textColor ?? FlutterFlowTheme.of(context).primaryText,
              letterSpacing: 0.0,
            ),
      );
    }

    // Calculate total unique attendees
    // For EventBrite events, we combine both LinkedUp and EventBrite attendees
    // For non-EventBrite events, we just use LinkedUp count
    final totalCount = widget.eventbriteEventId != null
        ? _linkedUpCount +
            _eventbriteCount // Combine both counts for EventBrite events
        : _linkedUpCount; // Otherwise use LinkedUp count only

    String displayText = totalCount.toString();

    if (widget.showPendingLabel && _pendingCount > 0) {
      displayText += ' ($_pendingCount pending)';
    }

    return Container(
      width: widget.width,
      height: widget.height,
      child: StreamBuilder<QuerySnapshot>(
        // Listen to real-time updates from participant subcollection
        stream: FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventRef.id)
            .collection('participant')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            // Update count on changes
            final newLinkedUpCount = snapshot.data!.docs.length;

            if (newLinkedUpCount != _linkedUpCount) {
              _linkedUpCount = newLinkedUpCount;
              _loadAttendeeCounts(); // Reload to get updated counts
            }
          }

          return Text(
            displayText,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(),
                  fontSize: widget.textSize,
                  color: widget.textColor ??
                      FlutterFlowTheme.of(context).primaryText,
                  letterSpacing: 0.0,
                ),
          );
        },
      ),
    );
  }
}
