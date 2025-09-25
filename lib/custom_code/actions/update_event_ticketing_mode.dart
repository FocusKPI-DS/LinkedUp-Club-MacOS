// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!

import '/auth/firebase_auth/auth_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<bool?> updateEventTicketingMode(
  String eventId,
  bool useEventbriteTicketing,
) async {
  try {
    // Update the event's ticketing mode
    await FirebaseFirestore.instance.collection('events').doc(eventId).update({
      'use_eventbrite_ticketing': useEventbriteTicketing,
      'ticketing_mode_updated': FieldValue.serverTimestamp(),
      'ticketing_mode_updated_by': currentUserUid,
    });

    // If switching to LinkedUp ticketing, we might need to
    // import existing attendees from EventBrite
    if (!useEventbriteTicketing) {
      // Mark that we need to sync attendees
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .update({
        'needs_attendee_sync': true,
      });
    }
  } catch (e) {
    print('Error updating event ticketing mode: $e');
    rethrow;
  }
}
