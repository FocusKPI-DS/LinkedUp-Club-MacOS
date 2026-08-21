// Automatic FlutterFlow imports
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!

import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '/auth/firebase_auth/auth_util.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

import '/backend/cloud_functions/callable_functions.dart';

Future<Map<String, dynamic>> _callGmailOAuth(Map<String, dynamic> data) async {
  final result = await invokeCloudFunction(
    'gmailOAuth',
    data: data,
    timeout: const Duration(seconds: 300),
  );
  if (result is Map) {
    return Map<String, dynamic>.from(result);
  }
  return {};
}

Future<bool> _pollGmailOAuthCompletion(String sessionId) async {
  int attempts = 0;
  const maxAttempts = 120;
  int pollInterval = 2;

  while (attempts < maxAttempts) {
    await Future.delayed(Duration(seconds: pollInterval));

    try {
      final checkResult = await _callGmailOAuth({
        'userId': currentUserUid,
        'action': 'check',
        'sessionId': sessionId,
      });

      final completed = checkResult['completed'] == true;
      if (completed) {
        final success = checkResult['success'] == true;
        final error = checkResult['error'];
        if (success) {
          print('✅ Gmail OAuth completed successfully!');
          return true;
        }
        print('❌ Gmail OAuth failed: $error');
        return false;
      }
    } catch (e) {
      print('⚠️ Error checking OAuth status: $e');
    }

    if (attempts == 10) {
      pollInterval = 5;
    }
    attempts++;
  }

  print('❌ Gmail OAuth timed out');
  return false;
}

Future<bool> _showInAppOAuthWebView({
  required BuildContext context,
  required String authUrl,
  required String sessionId,
}) async {
  try {
    final Uri authorizationUrl = Uri.parse(authUrl);

    if (await canLaunchUrl(authorizationUrl)) {
      print(
          '🔵 Launching OAuth URL in secure in-app browser (SFSafariViewController)...');

      await launchUrl(
        authorizationUrl,
        mode: Platform.isIOS
            ? LaunchMode.inAppWebView
            : LaunchMode.externalApplication,
      );

      print('🔵 Started polling for OAuth completion...');
      return _pollGmailOAuthCompletion(sessionId);
    }

    print('❌ Could not launch Gmail authorization URL');
    return false;
  } catch (e) {
    print('❌ Error showing in-app OAuth: $e');
    return _fallbackToExternalBrowser(authUrl, sessionId);
  }
}

Future<bool> _fallbackToExternalBrowser(
  String authUrl,
  String sessionId,
) async {
  try {
    final Uri authorizationUrl = Uri.parse(authUrl);
    if (await canLaunchUrl(authorizationUrl)) {
      print('🔵 Launching OAuth URL in external browser...');
      await launchUrl(
        authorizationUrl,
        mode: LaunchMode.externalApplication,
      );

      print('🔵 Started polling for OAuth completion...');
      return _pollGmailOAuthCompletion(sessionId);
    }

    print('❌ Could not launch Gmail authorization URL');
    return false;
  } catch (e) {
    print('❌ Error in fallback browser: $e');
    return false;
  }
}

Future<bool> gmailOAuthConnect([BuildContext? context]) async {
  try {
    if (currentUser == null) {
      print('❌ Cannot connect Gmail: User is not signed in');
      throw Exception('User must be signed in before connecting Gmail');
    }

    if (currentUserUid.isEmpty) {
      print('❌ Cannot connect Gmail: No user ID found');
      throw Exception('User must be authenticated before connecting Gmail');
    }

    print('🔵 Starting Gmail OAuth flow for user: ${currentUserUid}');

    print('🔵 Calling gmailOAuth with action: initiate');
    final result = await _callGmailOAuth({
      'userId': currentUserUid,
      'action': 'initiate',
    });

    print('🔵 Got response: $result');

    if (result['authUrl'] != null) {
      final String authUrl = result['authUrl'] as String;
      final String sessionId = result['sessionId'] as String;

      print('🔵 Auth URL: $authUrl');
      print('🔵 Session ID: $sessionId');

      if (context != null) {
        return _showInAppOAuthWebView(
          context: context,
          authUrl: authUrl,
          sessionId: sessionId,
        );
      }
      return _fallbackToExternalBrowser(authUrl, sessionId);
    }

    print('❌ Failed to get authorization URL from Cloud Function');
    print('Response: $result');
    return false;
  } catch (e, stackTrace) {
    print('❌ Error during Gmail OAuth: $e');
    print('Stack trace: $stackTrace');
    return false;
  }
}
