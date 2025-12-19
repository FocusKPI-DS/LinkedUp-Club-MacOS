// Automatic FlutterFlow imports
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cloud_functions/cloud_functions.dart';

Future<Map<String, dynamic>?> gmailPrefetchPriority() async {
  try {
    print('🔵 Prefetching priority Gmail emails (top 10)...');

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
        print('✅ Priority Gmail emails prefetched successfully');

        final emails = data['emails'];
        final nextPageToken = data['nextPageToken'];

        return {
          'success': true,
          'emails': emails,
          'nextPageToken': nextPageToken,
        };
      } else {
        print('❌ Failed to prefetch priority Gmail emails');
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
    print('❌ Error prefetching priority Gmail emails: $e');
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}
