// Automatic FlutterFlow imports
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '/backend/cloud_functions/callable_functions.dart';

Future<Map<String, dynamic>?> calendarListEvents({
  String calendarId = 'primary',
  String? timeMin,
  String? timeMax,
  int maxResults = 50,
  String? pageToken,
  bool singleEvents = true,
  String orderBy = 'startTime',
}) async {
  try {
    print('🔵 Fetching calendar events...');
    if (FirebaseAuth.instance.currentUser == null) {
      return {
        'success': false,
        'error': 'Not signed in',
        'errorCode': 'unauthenticated',
      };
    }

    final resultData = await invokeCloudFunction(
      'calendarListEvents',
      data: {
        'calendarId': calendarId,
        if (timeMin != null) 'timeMin': timeMin,
        if (timeMax != null) 'timeMax': timeMax,
        'maxResults': maxResults,
        if (pageToken != null) 'pageToken': pageToken,
        'singleEvents': singleEvents,
        'orderBy': orderBy,
      },
      timeout: const Duration(seconds: 60),
    );

    if (resultData != null) {
      final data = Map<String, dynamic>.from(resultData as Map);
      if (data['success'] == true) {
        print('✅ Calendar events fetched successfully');

        final events = data['events'];
        final nextPageToken = data['nextPageToken'];

        return {
          'success': true,
          'events': events,
          'nextPageToken': nextPageToken,
        };
      } else {
        print('❌ Failed to fetch calendar events');
        return {
          'success': false,
          'error': data['error']?.toString() ?? 'Unknown error',
        };
      }
    } else {
      print('❌ No data received from Cloud Function');
      return {
        'success': false,
        'error': 'No data received',
      };
    }
  } on FirebaseFunctionsException catch (e) {
    print(
      '❌ Calendar Cloud Function error: code=${e.code} message=${e.message}',
    );
    return {
      'success': false,
      'error': e.message ?? e.code,
      'errorCode': e.code,
    };
  } catch (e) {
    print('❌ Error fetching calendar events: $e');
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}
