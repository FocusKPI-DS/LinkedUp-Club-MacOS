// Automatic FlutterFlow imports
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cloud_functions/cloud_functions.dart';

Future<Map<String, dynamic>?> gmailPrefetchPriority() async {
  try {
    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'gmailPrefetchPriority',
      options: HttpsCallableOptions(
        timeout: const Duration(
            seconds: 30), // Fast fetch, should complete in 2-3 seconds
      ),
    );

    final result = await callable.call({});

    if (result.data != null) {
      final data = result.data as Map;
      if (data['success'] == true) {
        final emails = data['emails'];
        final nextPageToken = data['nextPageToken'];

        return {
          'success': true,
          'emails': emails,
          'nextPageToken': nextPageToken,
        };
      } else {
        return {
          'success': false,
          'error': data['error']?.toString() ?? 'Unknown error',
        };
      }
    } else {
      return {
        'success': false,
        'error': 'No data received',
      };
    }
  } catch (e) {
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}
