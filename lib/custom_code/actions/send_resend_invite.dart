// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cloud_functions/cloud_functions.dart';

Future<bool> sendResendInvite({
  required String email,
  String? recipientName,
  String? senderName,
  required String referralLink,
  String? personalMessage,
}) async {
  try {
    print('🔵 Sending automated invite to $email via Resend...');

    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'sendInviteEmail',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 30),
      ),
    );

    final result = await callable.call({
      'email': email.trim(),
      'recipientName': recipientName?.trim(),
      'senderName': senderName?.trim(),
      'referralLink': referralLink.trim(),
      'personalMessage': personalMessage?.trim(),
    });

    if (result.data != null && result.data['success'] == true) {
      print('✅ Invite email sent successfully. ID: ${result.data['id']}');
      return true;
    } else {
      print('❌ Failed to send invite email: ${result.data?['message'] ?? 'Unknown error'}');
      return false;
    }
  } catch (e) {
    print('❌ Error calling sendInviteEmail Cloud Function: $e');
    return false;
  }
}
