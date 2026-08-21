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

/// Sends an email notification to the recipient of a connection request.
/// This is fire-and-forget: failures are logged but do not block the UI.
Future<bool> sendConnectionRequestEmail({
  required String recipientEmail,
  String? recipientName,
  String? senderName,
}) async {
  try {
    print('🔵 Sending connection request email to $recipientEmail...');

    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'sendConnectionRequestEmail',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 30),
      ),
    );

    final result = await callable.call({
      'recipientEmail': recipientEmail.trim(),
      'recipientName': recipientName?.trim(),
      'senderName': senderName?.trim(),
    });

    if (result.data != null && result.data['success'] == true) {
      print(
          '✅ Connection request email sent successfully. ID: ${result.data['id']}');
      return true;
    } else {
      print(
          '❌ Failed to send connection request email: ${result.data?['message'] ?? 'Unknown error'}');
      return false;
    }
  } catch (e) {
    print('❌ Error calling sendConnectionRequestEmail Cloud Function: $e');
    return false;
  }
}
