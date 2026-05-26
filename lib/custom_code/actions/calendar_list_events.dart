// Automatic FlutterFlow imports
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cloud_functions/cloud_functions.dart';

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

    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'calendarListEvents',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 60),
      ),
    );

    final result = await callable.call({
      'calendarId': calendarId,
      if (timeMin != null) 'timeMin': timeMin,
      if (timeMax != null) 'timeMax': timeMax,
      'maxResults': maxResults,
      if (pageToken != null) 'pageToken': pageToken,
      'singleEvents': singleEvents,
      'orderBy': orderBy,
    });

    if (result.data != null) {
      final data = result.data as Map;
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
  } catch (e) {
    print('❌ Error fetching calendar events: $e');
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}
