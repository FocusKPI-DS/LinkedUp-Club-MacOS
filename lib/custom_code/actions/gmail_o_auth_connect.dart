// Automatic FlutterFlow imports
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!

import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '/auth/firebase_auth/auth_util.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

// Helper functions declared before main function
Future<bool> _showInAppOAuthWebView({
  required BuildContext context,
  required String authUrl,
  required String sessionId,
  required HttpsCallable callable,
}) async {
  try {
    // Use SFSafariViewController on iOS (via inAppWebView mode) which Google accepts
    // This provides a secure, in-app browser experience
    final Uri authorizationUrl = Uri.parse(authUrl);

    if (await canLaunchUrl(authorizationUrl)) {
      print(
          '🔵 Launching OAuth URL in secure in-app browser (SFSafariViewController)...');

      // Use inAppWebView mode on iOS which uses SFSafariViewController
      // This is Google-compliant and provides in-app experience
      await launchUrl(
        authorizationUrl,
        mode: Platform.isIOS
            ? LaunchMode
                .inAppWebView // Uses SFSafariViewController - Google compliant
            : LaunchMode.externalApplication,
      );

      print('🔵 Started polling for OAuth completion...');

      // Poll for completion
      int attempts = 0;
      const maxAttempts = 120; // 10 minutes
      int pollInterval = 2;

      while (attempts < maxAttempts) {
        await Future.delayed(Duration(seconds: pollInterval));

        try {
          final checkResult = await callable.call({
            'userId': currentUserUid,
            'action': 'check',
            'sessionId': sessionId,
          });

          if (checkResult.data != null) {
            final completed = checkResult.data['completed'] == true;
            final success = checkResult.data['success'] == true;
            final error = checkResult.data['error'];

            if (completed) {
              if (success) {
                print('✅ Gmail OAuth completed successfully!');
                return true;
              } else {
                print('❌ Gmail OAuth failed: $error');
                return false;
              }
            }
          }

          if (attempts == 10) {
            pollInterval = 5;
          }
        } catch (e) {
          print('⚠️ Error checking OAuth status: $e');
        }

        attempts++;
      }

      print('❌ Gmail OAuth timed out');
      return false;
    } else {
      print('❌ Could not launch Gmail authorization URL');
      return false;
    }
  } catch (e) {
    print('❌ Error showing in-app OAuth: $e');
    // Fallback to external browser
    return await _fallbackToExternalBrowser(authUrl, sessionId, callable);
  }
}

Future<bool> _fallbackToExternalBrowser(
  String authUrl,
  String sessionId,
  HttpsCallable callable,
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

      // Poll for completion
      int attempts = 0;
      const maxAttempts = 120;
      int pollInterval = 2;

      while (attempts < maxAttempts) {
        await Future.delayed(Duration(seconds: pollInterval));

        try {
          final checkResult = await callable.call({
            'userId': currentUserUid,
            'action': 'check',
            'sessionId': sessionId,
          });

          if (checkResult.data != null) {
            final completed = checkResult.data['completed'] == true;
            final success = checkResult.data['success'] == true;
            final error = checkResult.data['error'];

            if (completed) {
              if (success) {
                print('✅ Gmail OAuth completed successfully!');
                return true;
              } else {
                print('❌ Gmail OAuth failed: $error');
                return false;
              }
            }
          }

          if (attempts == 10) {
            pollInterval = 5;
          }
        } catch (e) {
          print('⚠️ Error checking OAuth status: $e');
        }

        attempts++;
      }

      print('❌ Gmail OAuth timed out');
      return false;
    } else {
      print('❌ Could not launch Gmail authorization URL');
      return false;
    }
  } catch (e) {
    print('❌ Error in fallback browser: $e');
    return false;
  }
}

Future<bool> gmailOAuthConnect([BuildContext? context]) async {
  try {
    // CRITICAL: Ensure user is signed in before attempting Gmail OAuth
    // This prevents conflicts with Firebase Auth Google Sign-In
    if (currentUser == null) {
      print('❌ Cannot connect Gmail: User is not signed in');
      throw Exception('User must be signed in before connecting Gmail');
    }

    // Double-check that we have a valid user ID
    if (currentUserUid.isEmpty) {
      print('❌ Cannot connect Gmail: No user ID found');
      throw Exception('User must be authenticated before connecting Gmail');
    }

    print('🔵 Starting Gmail OAuth flow for user: $currentUserUid');

    // Call a Cloud Function to handle the OAuth flow
    // This is more secure and works better with mobile apps
    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'gmailOAuth',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 300),
      ),
    );

    print('🔵 Calling gmailOAuth with action: initiate');
    final result = await callable.call({
      'userId': currentUserUid,
      'action': 'initiate',
    });

    print('🔵 Got response: ${result.data}');

    if (result.data != null && result.data['authUrl'] != null) {
      final String authUrl = result.data['authUrl'];
      final String sessionId = result.data['sessionId'];

      print('🔵 Auth URL: $authUrl');
      print('🔵 Session ID: $sessionId');

      // Use in-app WebView if context is available, otherwise fallback to external browser
      if (context != null) {
        return await _showInAppOAuthWebView(
          context: context,
          authUrl: authUrl,
          sessionId: sessionId,
          callable: callable,
        );
      } else {
        // Fallback to external browser if no context
        return await _fallbackToExternalBrowser(
          authUrl,
          sessionId,
          callable,
        );
      }
    } else {
      print('❌ Failed to get authorization URL from Cloud Function');
      print('Response: ${result.data}');
      return false;
    }
  } catch (e, stackTrace) {
    print('❌ Error during Gmail OAuth: $e');
    print('Stack trace: $stackTrace');
    return false;
  }
}
