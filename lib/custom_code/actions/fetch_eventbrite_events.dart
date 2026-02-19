// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!

import 'package:http/http.dart' as http;
import 'dart:convert';
import '/auth/firebase_auth/auth_util.dart';

Future<List<dynamic>> fetchEventbriteEvents() async {
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
    final String? eventbriteUserId = userData['eventbrite_user_id'];

    if (accessToken == null || eventbriteUserId == null) {
      throw Exception('EventBrite not connected');
    }

    // Fetch events from EventBrite API
    print('Attempting to fetch EventBrite events...');
    print('User ID: $eventbriteUserId');

    // First, let's verify we can access the user endpoint
    final userTest = await http.get(
      Uri.parse('https://www.eventbriteapi.com/v3/users/me/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );
    print('User endpoint test: ${userTest.statusCode}');
    if (userTest.statusCode == 200) {
      print('User data: ${userTest.body}');
    }

    // Try the organizer events endpoint
    var response = await http.get(
      Uri.parse(
          'https://www.eventbriteapi.com/v3/users/$eventbriteUserId/events/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );
    print('User events response: ${response.statusCode}');

    // If that doesn't work, try the organizer's events endpoint
    if (response.statusCode != 200) {
      response = await http.get(
        Uri.parse(
            'https://www.eventbriteapi.com/v3/users/$eventbriteUserId/organizers/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );
      print('Organizers response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final orgData = json.decode(response.body);
        final organizers = orgData['organizers'] ?? [];
        if (organizers.isNotEmpty) {
          final organizerId = organizers[0]['id'];
          response = await http.get(
            Uri.parse(
                'https://www.eventbriteapi.com/v3/organizers/$organizerId/events/'),
            headers: {
              'Authorization': 'Bearer $accessToken',
            },
          );
          print('Organizer events response: ${response.statusCode}');
        }
      }
    }

    // If that fails, try the events endpoint (includes both owned and attending)
    if (response.statusCode == 404) {
      print('Trying /users/me/events/ endpoint...');
      response = await http.get(
        Uri.parse('https://www.eventbriteapi.com/v3/users/me/events/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );
      print('Events response: ${response.statusCode}');
    }

    // If still failing, try the organizations endpoint
    if (response.statusCode == 404) {
      response = await http.get(
        Uri.parse('https://www.eventbriteapi.com/v3/users/me/organizations/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      // If we got organizations, try to get events from the first organization
      if (response.statusCode == 200) {
        final orgData = json.decode(response.body);
        final organizations = orgData['organizations'] ?? [];
        if (organizations.isNotEmpty) {
          final orgId = organizations[0]['id'];
          response = await http.get(
            Uri.parse(
                'https://www.eventbriteapi.com/v3/organizations/$orgId/events/'),
            headers: {
              'Authorization': 'Bearer $accessToken',
            },
          );
        }
      }
    }

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Response data keys: ${data.keys}');

      // EventBrite API might return events in different formats
      final events = data['events'] ?? data['data'] ?? [];

      // If events is not a list, try to extract it
      if (events is! List) {
        print('Events is not a list: ${events.runtimeType}');
        return [];
      }

      print('Found ${events.length} events');

      // Return all events for now (don't filter by date to see if we get any)
      return events;
    } else if (response.statusCode == 401) {
      // Token expired, try to refresh
      final refreshToken = userData['eventbrite_refresh_token'];
      if (refreshToken != null) {
        // Implement token refresh logic here
        throw Exception('EventBrite token expired. Please reconnect.');
      } else {
        throw Exception('EventBrite authentication failed');
      }
    } else {
      print('EventBrite API Error: ${response.statusCode}');
      print('Response body: ${response.body}');

      // Try to parse error message
      try {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error_description'] ??
            errorData['error'] ??
            'Unknown error';
        throw Exception('Failed to fetch events: $errorMessage');
      } catch (e) {
        throw Exception('Failed to fetch events: ${response.statusCode}');
      }
    }
  } catch (e) {
    print('Error fetching EventBrite events: $e');
    rethrow;
  }
}
