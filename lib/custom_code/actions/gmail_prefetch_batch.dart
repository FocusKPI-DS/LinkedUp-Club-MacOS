// Automatic FlutterFlow imports
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cloud_functions/cloud_functions.dart';

Future<Map<String, dynamic>?> gmailPrefetchBatch({
  required String pageToken,
  int maxResults = 20,
}) async {
  try {
    print('🔵 Prefetching Gmail email batch...');

    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'gmailPrefetchBatch',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 60),
      ),
    );

    final result = await callable.call({
      'pageToken': pageToken,
      'maxResults': maxResults,
    });

    if (result.data != null) {
      final data = result.data as Map;
      if (data['success'] == true) {
        print('✅ Gmail email batch prefetched successfully');

        final emails = data['emails'];
        final nextPageToken = data['nextPageToken'];
        final totalCached = data['totalCached'];

        return {
          'success': true,
          'emails': emails,
          'nextPageToken': nextPageToken,
          'totalCached': totalCached,
        };
      } else {
        print('❌ Failed to prefetch Gmail email batch');
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
    print('❌ Error prefetching Gmail email batch: $e');
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}
