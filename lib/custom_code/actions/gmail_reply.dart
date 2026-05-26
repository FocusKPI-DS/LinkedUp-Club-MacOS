// Automatic FlutterFlow imports
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cloud_functions/cloud_functions.dart';

Future<bool> gmailReply({
  required String messageId,
  required String replyBody,
  bool isHtml = false,
}) async {
  try {
    print('🔵 Replying to Gmail email: $messageId');

    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'gmailReply',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 60),
      ),
    );

    final result = await callable.call({
      'messageId': messageId,
      'replyBody': replyBody,
      'isHtml': isHtml,
    });

    if (result.data != null && result.data['success'] == true) {
      print('✅ Gmail reply sent successfully');
      return true;
    } else {
      print('❌ Failed to send Gmail reply');
      return false;
    }
  } catch (e) {
    print('❌ Error sending Gmail reply: $e');
    return false;
  }
}
