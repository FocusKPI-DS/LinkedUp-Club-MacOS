// Automatic FlutterFlow imports
import '/backend/backend.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
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
