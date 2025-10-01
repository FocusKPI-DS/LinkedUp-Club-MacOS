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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'dart:math' show min;

Future<bool> ensureFcmToken(DocumentReference userRef) async {
  try {
    // Skip FCM token generation on web platform for now
    if (kIsWeb) {
      print('FCM token generation skipped on web platform');
      return false;
    }

    // Get FCM token
    final messaging = FirebaseMessaging.instance;

    // Request permission first
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('User declined notifications permission');
      return false;
    }

    // For macOS and iOS, ensure APNS token is available before getting FCM token
    if (!kIsWeb && (Platform.isMacOS || Platform.isIOS)) {
      print(
          'Waiting for APNS token on ${Platform.isMacOS ? 'macOS' : 'iOS'}...');

      String? apnsToken;
      int maxRetries = 10;
      int retryCount = 0;

      while (apnsToken == null && retryCount < maxRetries) {
        try {
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken != null) {
            print(
                'APNS token received: ${apnsToken.substring(0, min(10, apnsToken.length))}...');
            break;
          }
        } catch (e) {
          print('Attempt ${retryCount + 1}: APNS token not yet available - $e');
        }

        // Exponential backoff: wait longer each time
        await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
        retryCount++;
      }

      if (apnsToken == null) {
        print('Failed to get APNS token after $maxRetries attempts');
        print('This might be due to:');
        print(
            '1. Another app version (e.g., TestFlight) is using the APNS token');
        print('2. APNS is not properly configured');
        print('3. The app is not properly signed');
        return false;
      }
    }

    // Get the token
    String? token = await messaging.getToken();

    if (token == null || token.isEmpty) {
      print('Failed to get FCM token');
      return false;
    }

    // Get device info
    String deviceType = 'unknown';
    if (!kIsWeb) {
      if (Platform.isIOS) {
        deviceType = 'ios';
      } else if (Platform.isAndroid) {
        deviceType = 'android';
      }
    }

    // Check if fcm_tokens subcollection exists and has this token
    final fcmTokensRef = userRef.collection('fcm_tokens');
    final existingTokenQuery =
        await fcmTokensRef.where('fcm_token', isEqualTo: token).limit(1).get();

    if (existingTokenQuery.docs.isEmpty) {
      // Token doesn't exist, add it
      await fcmTokensRef.add({
        'fcm_token': token,
        'device_type': deviceType,
        'created_at': FieldValue.serverTimestamp(),
      });

      print('FCM token added successfully: ${token.substring(0, 10)}...');
    } else {
      // Token exists, update it if needed
      await existingTokenQuery.docs.first.reference.update({
        'fcm_token': token,
        'device_type': deviceType,
      });

      print('FCM token updated successfully');
    }

    // Also listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      // Remove old token if it exists
      if (token != newToken) {
        final oldTokenQuery =
            await fcmTokensRef.where('fcm_token', isEqualTo: token).get();

        for (var doc in oldTokenQuery.docs) {
          await doc.reference.delete();
        }
      }

      // Add new token
      await fcmTokensRef.add({
        'fcm_token': newToken,
        'device_type': deviceType,
        'created_at': FieldValue.serverTimestamp(),
      });
    });

    return true;
  } catch (e) {
    print('Error ensuring FCM token: $e');
    return false;
  }
}
