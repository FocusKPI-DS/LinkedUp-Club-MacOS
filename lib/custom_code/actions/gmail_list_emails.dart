// Automatic FlutterFlow imports
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cloud_functions/cloud_functions.dart';

Future<Map<String, dynamic>?> gmailListEmails({
  int maxResults = 50,
  String? pageToken,
}) async {
  try {
    print('🔵 Fetching Gmail emails...');

    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'gmailListEmails',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 60),
      ),
    );

    final result = await callable.call({
      'maxResults': maxResults,
      if (pageToken != null) 'pageToken': pageToken,
    });

    if (result.data != null) {
      final data = result.data as Map;
      if (data['success'] == true) {
        print('✅ Gmail emails fetched successfully');

        // Convert emails properly
        final emails = data['emails'];
        final nextPageToken = data['nextPageToken'];

        return {
          'success': true,
          'emails': emails,
          'nextPageToken': nextPageToken,
        };
      } else {
        print('❌ Failed to fetch Gmail emails');
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
    print('❌ Error fetching Gmail emails: $e');
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}
