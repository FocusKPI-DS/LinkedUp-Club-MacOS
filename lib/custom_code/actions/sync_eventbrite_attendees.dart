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

import 'package:http/http.dart' as http;
import 'dart:convert';
import '/auth/firebase_auth/auth_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<bool?> syncEventbriteAttendees(String eventId) async {
  try {
    // Get event data
    final eventDoc = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .get();

    if (!eventDoc.exists) {
      throw Exception('Event not found');
    }

    final eventData = eventDoc.data()!;
    final String? eventbriteId = eventData['eventbrite_id'];

    if (eventbriteId == null) {
      throw Exception('Not an EventBrite event');
    }

    // Get user's EventBrite access token
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserUid)
        .get();

    final userData = userDoc.data()!;
    final String? accessToken = userData['eventbrite_access_token'];

    if (accessToken == null) {
      throw Exception('EventBrite not connected');
    }

    // Fetch attendees from EventBrite
    final response = await http.get(
      Uri.parse(
          'https://www.eventbriteapi.com/v3/events/$eventbriteId/attendees/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch attendees: ${response.statusCode}');
    }

    final attendeesData = json.decode(response.body);
    final attendees = attendeesData['attendees'] ?? [];

    // Process each attendee
    for (var attendee in attendees) {
      final email = attendee['profile']['email'];
      final name = attendee['profile']['name'] ?? 'Unknown';
      final firstName = attendee['profile']['first_name'] ?? '';
      final lastName = attendee['profile']['last_name'] ?? '';
      final ticketClass = attendee['ticket_class_name'] ?? 'General';
      final status = attendee['status'] ?? 'unknown';
      final eventbriteAttendeeId = attendee['id'];

      // Check if attendee is already synced
      final existingAttendeeQuery = await FirebaseFirestore.instance
          .collection('event_attendees')
          .where('event_id', isEqualTo: eventId)
          .where('eventbrite_attendee_id', isEqualTo: eventbriteAttendeeId)
          .limit(1)
          .get();

      if (existingAttendeeQuery.docs.isEmpty) {
        // Check if user exists with this email
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        DocumentReference? userRef;
        bool isPendingVerification = false;

        if (userQuery.docs.isNotEmpty) {
          // User exists
          userRef = userQuery.docs.first.reference;
        } else {
          // Create pending user record
          isPendingVerification = true;
          // We'll store pending user info in the attendee record
        }

        // Create attendee record
        await FirebaseFirestore.instance.collection('event_attendees').add({
          'event_id': eventId,
          'event_ref': eventDoc.reference,
          'eventbrite_attendee_id': eventbriteAttendeeId,
          'email': email,
          'name': name,
          'first_name': firstName,
          'last_name': lastName,
          'ticket_class': ticketClass,
          'status': status,
          'user_ref': userRef,
          'is_pending_verification': isPendingVerification,
          'synced_at': FieldValue.serverTimestamp(),
          'checked_in': attendee['checked_in'] ?? false,
          'cancelled': attendee['cancelled'] ?? false,
        });

        // If user exists, add them to event participants
        if (userRef != null) {
          await eventDoc.reference.update({
            'participants': FieldValue.arrayUnion([userRef]),
          });
        }
      } else {
        // Update existing attendee record
        await existingAttendeeQuery.docs.first.reference.update({
          'status': status,
          'checked_in': attendee['checked_in'] ?? false,
          'cancelled': attendee['cancelled'] ?? false,
          'last_synced': FieldValue.serverTimestamp(),
        });
      }
    }

    // Update event with last sync time
    await eventDoc.reference.update({
      'last_attendee_sync': FieldValue.serverTimestamp(),
      'total_attendees': attendees.length,
    });
  } catch (e) {
    print('Error syncing EventBrite attendees: $e');
    rethrow;
  }
  return null;
}
