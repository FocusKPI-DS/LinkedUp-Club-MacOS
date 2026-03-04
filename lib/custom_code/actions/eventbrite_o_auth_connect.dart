// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!

import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '/auth/firebase_auth/auth_util.dart';
import 'package:cloud_functions/cloud_functions.dart';

Future<bool> eventbriteOAuthConnect() async {
  try {
    // Call a Cloud Function to handle the OAuth flow
    // This is more secure and works better with mobile apps
    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'eventbriteOAuth',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 300),
      ),
    );

    final result = await callable.call({
      'userId': currentUserUid,
      'action': 'initiate',
    });

    if (result.data != null && result.data['authUrl'] != null) {
      final String authUrl = result.data['authUrl'];
      final String sessionId = result.data['sessionId'];

      // Launch the authorization URL
      final Uri authorizationUrl = Uri.parse(authUrl);
      if (await canLaunchUrl(authorizationUrl)) {
        await launchUrl(
          authorizationUrl,
          mode: LaunchMode.externalApplication,
        );

        // Poll for completion
        int attempts = 0;
        const maxAttempts = 60; // 5 minutes with 5-second intervals

        while (attempts < maxAttempts) {
          await Future.delayed(const Duration(seconds: 5));

          // Check if the OAuth flow is complete
          final checkResult = await callable.call({
            'userId': currentUserUid,
            'action': 'check',
            'sessionId': sessionId,
          });

          if (checkResult.data != null &&
              checkResult.data['completed'] == true) {
            if (checkResult.data['success'] == true) {
              // Update local state
              return true;
            } else {
              print('EventBrite OAuth failed: ${checkResult.data['error']}');
              return false;
            }
          }

          attempts++;
        }

        print('EventBrite OAuth timed out');
        return false;
      } else {
        print('Could not launch EventBrite authorization URL');
        return false;
      }
    } else {
      print('Failed to get authorization URL from Cloud Function');
      return false;
    }
  } catch (e) {
    print('Error during EventBrite OAuth: $e');
    return false;
  }
}
