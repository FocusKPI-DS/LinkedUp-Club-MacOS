// Automatic FlutterFlow imports
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cloud_functions/cloud_functions.dart';

Future<Map<String, dynamic>?> gmailRefreshCache({
  bool forceRefresh = false,
}) async {
  try {
    print('🔵 Refreshing Gmail cache...');

    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'gmailRefreshCache',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 60),
      ),
    );

    final result = await callable.call({
      'forceRefresh': forceRefresh,
    });

    if (result.data != null) {
      final data = result.data as Map;
      if (data['success'] == true) {
        // Check if refresh was skipped (cache is fresh)
        if (data['skipped'] == true) {
          print('✅ Gmail cache is fresh, no refresh needed');
          return {
            'success': true,
            'skipped': true,
            'message': data['message']?.toString() ?? 'Cache is fresh',
          };
        }

        print('✅ Gmail cache refreshed successfully');

        final emails = data['emails'];
        final newEmails = data['newEmails'];
        final updatedEmails = data['updatedEmails'];

        return {
          'success': true,
          'emails': emails,
          'newEmails': newEmails,
          'updatedEmails': updatedEmails,
          'message': data['message']?.toString(),
        };
      } else {
        print('❌ Failed to refresh Gmail cache');
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
    print('❌ Error refreshing Gmail cache: $e');
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}
