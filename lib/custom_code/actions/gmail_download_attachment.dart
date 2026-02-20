// Automatic FlutterFlow imports
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cloud_functions/cloud_functions.dart';

Future<Map<String, dynamic>?> gmailDownloadAttachment(
  String messageId,
  String attachmentId,
) async {
  try {
    print('🔵 Downloading Gmail attachment: $attachmentId');

    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'gmailDownloadAttachment',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 60),
      ),
    );

    final result = await callable.call({
      'messageId': messageId,
      'attachmentId': attachmentId,
    });

    if (result.data != null) {
      final data = result.data as Map;
      if (data['success'] == true) {
        print('✅ Gmail attachment downloaded successfully');
        return {
          'success': true,
          'data': data['data'],
          'size': data['size'],
        };
      } else {
        print('❌ Failed to download Gmail attachment');
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
    print('❌ Error downloading Gmail attachment: $e');
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}
