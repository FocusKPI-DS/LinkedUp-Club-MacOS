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
import 'package:branchio_dynamic_linking_akp5u6/custom_code/actions/index.dart'
    as branchio_dynamic_linking_akp5u6_actions;
import 'package:branchio_dynamic_linking_akp5u6/flutter_flow/custom_functions.dart'
    as branchio_dynamic_linking_akp5u6_functions;

Future<bool> syncEventbriteEvent(String eventbriteEventId) async {
  try {
    // Get the user's EventBrite access token
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserUid)
        .get();

    if (!userDoc.exists) {
      throw Exception('User document not found');
    }

    final userData = userDoc.data()!;
    final String? accessToken = userData['eventbrite_access_token'];

    if (accessToken == null) {
      throw Exception('EventBrite not connected');
    }

    // Fetch detailed event data from EventBrite
    final eventResponse = await http.get(
      Uri.parse('https://www.eventbriteapi.com/v3/events/$eventbriteEventId/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (eventResponse.statusCode != 200) {
      throw Exception(
          'Failed to fetch event details: ${eventResponse.statusCode}');
    }

    final eventData = json.decode(eventResponse.body);

    // Fetch venue data if available
    Map<String, dynamic>? venueData;
    if (eventData['venue_id'] != null) {
      final venueResponse = await http.get(
        Uri.parse(
            'https://www.eventbriteapi.com/v3/venues/${eventData['venue_id']}/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (venueResponse.statusCode == 200) {
        venueData = json.decode(venueResponse.body);
      }
    }

    // Prepare data for LinkedUp event
    final Map<String, dynamic> linkedUpEventData = {
      'title': eventData['name']['text'] ?? 'Untitled Event',
      'description': eventData['description']['text'] ?? '',
      'location': venueData != null
          ? venueData['name'] ?? 'Online Event'
          : 'Online Event',
      'latlng': venueData != null &&
              venueData['latitude'] != null &&
              venueData['longitude'] != null
          ? GeoPoint(
              double.parse(venueData['latitude'].toString()),
              double.parse(venueData['longitude'].toString()),
            )
          : null,
      'start_date': DateTime.parse(eventData['start']['utc']),
      'end_date': DateTime.parse(eventData['end']['utc']),
      'creator_id':
          FirebaseFirestore.instance.collection('users').doc(currentUserUid),
      'cover_image_url': eventData['logo']?['url'] ?? '',
      'is_private': false,
      'created_at': FieldValue.serverTimestamp(),
      'is_trending': false,
      'category': ['EventBrite Import'],
      'event_id': 'eventbrite_$eventbriteEventId',
      'price': eventData['is_free'] == true
          ? 0
          : (eventData['minimum_ticket_price']?['value'] ?? 0),
      'ticket_deadline': eventData['sales_end'] != null
          ? DateTime.parse(eventData['sales_end'])
          : DateTime.parse(eventData['start']['utc'])
              .subtract(const Duration(days: 1)),
      'ticket_amount': eventData['capacity'] ?? 0,
      'eventbrite_id': eventbriteEventId,
      'eventbrite_url': eventData['url'],
      'use_eventbrite_ticketing':
          true, // Default to using EventBrite for ticketing
    };

    // Check if event already exists
    final existingEventQuery = await FirebaseFirestore.instance
        .collection('events')
        .where('eventbrite_id', isEqualTo: eventbriteEventId)
        .limit(1)
        .get();

    DocumentReference eventRef;

    if (existingEventQuery.docs.isNotEmpty) {
      // Update existing event
      eventRef = existingEventQuery.docs.first.reference;
      await eventRef.update(linkedUpEventData);

      // Check if QR code exists, if not generate it
      final existingEvent = await eventRef.get();
      final existingData = existingEvent.data() as Map<String, dynamic>?;
      if (existingData?['qr_code_url'] == null) {
        await _generateAndUpdateQRCode(eventRef, eventData, currentUserUid);
      }
    } else {
      // Create new event
      eventRef = await FirebaseFirestore.instance
          .collection('events')
          .add(linkedUpEventData);

      // Update the event with its own reference
      await eventRef.update({
        'event_ref': eventRef,
        'event_id': eventRef.path, // Add event_id to match create_event flow
      });

      // Small delay to ensure document is fully created
      await Future.delayed(const Duration(milliseconds: 500));

      // Generate QR code for the event
      await _generateAndUpdateQRCode(eventRef, eventData, currentUserUid);

      // Create the main chat group for the event
      final chatGroupRef =
          await FirebaseFirestore.instance.collection('chats').add({
        'group_name': eventData['name']['text'] ?? 'Event Chat',
        'description': 'Main chat for ${eventData['name']['text']}',
        'is_public': true,
        'event_ref': eventRef,
        'admin_refs': [
          FirebaseFirestore.instance.collection('users').doc(currentUserUid)
        ],
        'created_at': FieldValue.serverTimestamp(),
        'members': [
          FirebaseFirestore.instance.collection('users').doc(currentUserUid)
        ],
        'last_message_time': FieldValue.serverTimestamp(),
        'recent_messages': [],
      });

      // Update event with main group reference
      await eventRef.update({
        'main_group': chatGroupRef,
        'chat_groups': [chatGroupRef],
      });
    }

    // Add current user as participant if not already
    await eventRef.update({
      'participants': FieldValue.arrayUnion(
          [FirebaseFirestore.instance.collection('users').doc(currentUserUid)]),
    });

    // Create participant record in subcollection (needed for QR code visibility)
    final currentUserRef =
        FirebaseFirestore.instance.collection('users').doc(currentUserUid);
    final participantQuery = await eventRef
        .collection('participant')
        .where('user_ref', isEqualTo: currentUserRef)
        .limit(1)
        .get();

    if (participantQuery.docs.isEmpty) {
      // Get current user data for participant record
      final currentUser = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid)
          .get();

      final userData = currentUser.data() ?? {};

      // Create participant record
      await eventRef.collection('participant').add({
        'user_id': currentUserUid,
        'user_ref': currentUserRef,
        'name': userData['display_name'] ?? '',
        'joined_at': FieldValue.serverTimestamp(),
        'status': 'joined',
        'image': userData['photo_url'] ?? '',
        'bio': userData['bio'] ?? '',
      });

      print(
          '[QR Generation] Created participant record for QR code visibility');
    }

    return true;
  } catch (e) {
    print('Error syncing EventBrite event: $e');
    return false;
  }
}

Future<void> _generateAndUpdateQRCode(
  DocumentReference eventRef,
  Map<String, dynamic> eventData,
  String currentUserUid,
) async {
  try {
    print(
        '[QR Generation] Starting QR code generation for event: ${eventRef.path}');

    // Get current user's invitation code
    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserUid)
        .get();

    final String userInvitationCode =
        currentUserDoc.data()?['invitation_code'] ?? '';

    print('[QR Generation] User invitation code: $userInvitationCode');

    // Generate dynamic link (matching the format from create_event_widget.dart)
    final qrCodeUrl =
        await branchio_dynamic_linking_akp5u6_actions.generateLink(
      'eventDetail_${eventRef.path}',
      'LinkedUp Event Invite',
      'Join me at this ${eventData['name']['text']} event!', // Note: no space after "this" to match original
      <String, String?>{
        'user_ref': currentUserUid,
        'event_id': eventRef.path,
      },
      branchio_dynamic_linking_akp5u6_functions.createLinkProperties(
        'in_app',
        'invite',
        'event_referral',
        'event_page',
        ['deeplink'],
        'deeplink',
        17000,
        <String, String?>{
          'eventId': eventRef.path,
          'inviteCode': userInvitationCode,
          'deeplink_path': 'eventDetail/${eventRef.id}',
          'invite_type': 'Event',
        },
      ),
    );

    print('[QR Generation] Generated QR code URL: $qrCodeUrl');

    // Update event with QR code URL using createEventsRecordData for consistency
    if (qrCodeUrl != null && qrCodeUrl.isNotEmpty) {
      await eventRef.update(createEventsRecordData(
        qrCodeUrl: qrCodeUrl,
      ));
      print('[QR Generation] Successfully updated event with QR code');
    } else {
      print('[QR Generation] QR code URL was null or empty');
    }
  } catch (e, stackTrace) {
    print('[QR Generation] Error generating QR code: $e');
    print('[QR Generation] Stack trace: $stackTrace');
    // Continue even if QR code generation fails
  }
}
