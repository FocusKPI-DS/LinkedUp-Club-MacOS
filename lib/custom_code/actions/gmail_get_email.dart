// Automatic FlutterFlow imports
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cloud_functions/cloud_functions.dart';

Future<Map<String, dynamic>?> gmailGetEmail(String messageId) async {
  try {
    print('🔵 Fetching Gmail email: $messageId');

    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'gmailGetEmail',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 60),
      ),
    );

    final result = await callable.call({
      'messageId': messageId,
    });

    if (result.data != null) {
      final data = result.data as Map;
      if (data['success'] == true) {
        print('✅ Gmail email fetched successfully');
        return {
          'success': true,
          'email': data['email'],
        };
      } else {
        print('❌ Failed to fetch Gmail email');
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
    print('❌ Error fetching Gmail email: $e');
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}
