// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'dart:math' show min;
import '/flutter_flow/platform_utils/platform_util.dart';

Future<bool> ensureFcmToken(DocumentReference userRef) async {
  try {
    // Handle web platform (Chrome/Edge only)
    if (kIsWeb) {
      try {
        // Check if it's Chrome or Edge (Chromium-based browsers)
        final userAgent = getUserAgent();
        final isChrome =
            userAgent.contains('chrome') && !userAgent.contains('edge');
        final isEdge =
            userAgent.contains('edg'); // Edge user agent contains 'edg'

        if (!isChrome && !isEdge) {
          print('🔔 FCM web push only supported on Chrome/Edge browsers');
          return false;
        }

        print('🔔 Initializing FCM for web (Chrome/Edge)...');

        // VAPID key from Firebase Console
        const vapidKey =
            'BBQ41Zx5PrbQc0iFA-9X6l6440O9CKWk9ZI3CjU-IwPK6AUo7gqhGK8RF8g75N0vnRB_Wi-G_kX-MWHOsheMQtc';

        // Get Firebase Messaging instance
        final messaging = FirebaseMessaging.instance;

        // Request notification permission
        NotificationSettings settings = await messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: false,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        if (settings.authorizationStatus != AuthorizationStatus.authorized) {
          print(
              '❌ Notification permission not granted for web: ${settings.authorizationStatus}');
          return false;
        }

        print('✅ Notification permission granted for web');

        // Get FCM token with VAPID key for web
        String? token;
        try {
          token = await messaging.getToken(vapidKey: vapidKey);
        } catch (e) {
          print('❌ Error getting FCM token with VAPID key: $e');
          // Try without VAPID key as fallback
          try {
            token = await messaging.getToken();
          } catch (e2) {
            print('❌ Error getting FCM token: $e2');
          }
        }

        if (token == null || token.isEmpty) {
          print('❌ Failed to get FCM token on web');
          return false;
        }

        print('✅ FCM token obtained on web: ${token.substring(0, 10)}...');

        // Determine device type
        String deviceType = isChrome ? 'Chrome' : 'Edge';

        // Store token in Firestore (same logic as mobile platforms)
        final fcmTokensRef = userRef.collection('fcm_tokens');
        final existingTokenQuery = await fcmTokensRef
            .where('fcm_token', isEqualTo: token)
            .limit(1)
            .get();

        if (existingTokenQuery.docs.isEmpty) {
          final docRef = await fcmTokensRef.add({
            'fcm_token': token,
            'device_type': deviceType,
            'created_at': FieldValue.serverTimestamp(),
          });

          print('✅ FCM token added successfully for web!');
          print('   Token: ${token.substring(0, 10)}...');
          print('   Device: $deviceType');
          print('   Path: ${docRef.path}');
        } else {
          await existingTokenQuery.docs.first.reference.update({
            'fcm_token': token,
            'device_type': deviceType,
          });

          print('✅ FCM token updated successfully for web!');
        }

        // Listen for token refresh
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          try {
            print(
                '🔄 FCM Token refreshed on web! New: ${newToken.substring(0, 10)}...');

            final allTokensQuery = await fcmTokensRef.get();
            for (var doc in allTokensQuery.docs) {
              await doc.reference.delete();
            }

            await fcmTokensRef.add({
              'fcm_token': newToken,
              'device_type': deviceType,
              'created_at': FieldValue.serverTimestamp(),
            });

            print('✅ FCM token refresh completed for web!');
          } catch (e) {
            print('❌ Error during token refresh on web: $e');
          }
        });

        return true;
      } catch (e) {
        print('❌ Error setting up FCM on web: $e');
        return false;
      }
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
      print('❌ User declined notifications permission!');
      print('   Authorization status: ${settings.authorizationStatus}');
      return false;
    } else {
      print('✅ Notification permission granted!');
      print('   Authorization status: ${settings.authorizationStatus}');
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
        deviceType = 'iOS';
      } else if (Platform.isAndroid) {
        deviceType = 'Android';
      } else if (Platform.isMacOS) {
        deviceType = 'macOS';
      }
    }

    // Check if fcm_tokens subcollection exists and has this token
    final fcmTokensRef = userRef.collection('fcm_tokens');
    final existingTokenQuery =
        await fcmTokensRef.where('fcm_token', isEqualTo: token).limit(1).get();

    if (existingTokenQuery.docs.isEmpty) {
      // Token doesn't exist, add it
      final docRef = await fcmTokensRef.add({
        'fcm_token': token,
        'device_type': deviceType,
        'created_at': FieldValue.serverTimestamp(),
      });

      print('✅ FCM token added successfully!');
      print('   Token: ${token.substring(0, 10)}...');
      print('   Device: $deviceType');
      print('   Path: ${docRef.path}');
      print('   User: ${userRef.path}');
    } else {
      // Token exists, update it if needed
      await existingTokenQuery.docs.first.reference.update({
        'fcm_token': token,
        'device_type': deviceType,
      });

      print('✅ FCM token updated successfully!');
      print('   Token: ${token.substring(0, 10)}...');
      print('   Device: $deviceType');
      print('   Doc: ${existingTokenQuery.docs.first.reference.path}');
    }

    // Subscribe to News topic (mobile platforms only)
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await FirebaseMessaging.instance.subscribeToTopic('news');
        print('✅ Subscribed to topic: news');
      } else {
        print('ℹ️ Topic subscribe skipped on this platform');
      }
    } catch (e) {
      print('❌ Failed to subscribe to topic news: $e');
    }

    // Also listen for token refresh - FIXED VERSION
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        print(
            '🔄 FCM Token refreshed! Old: ${token.substring(0, 10)}... New: ${newToken.substring(0, 10)}...');

        // Remove ALL old tokens for this user (cleanup)
        final allTokensQuery = await fcmTokensRef.get();
        for (var doc in allTokensQuery.docs) {
          await doc.reference.delete();
        }

        // Add new token
        await fcmTokensRef.add({
          'fcm_token': newToken,
          'device_type': deviceType,
          'created_at': FieldValue.serverTimestamp(),
        });

        // Re-subscribe to topic after token refresh
        try {
          if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
            await FirebaseMessaging.instance.subscribeToTopic('news');
            print('✅ Re-subscribed to topic: news');
          }
        } catch (e) {
          print('❌ Failed to re-subscribe to topic news: $e');
        }

        print('✅ FCM token refresh completed! New token registered.');
      } catch (e) {
        print('❌ Error during token refresh: $e');
      }
    });

    return true;
  } catch (e) {
    print('Error ensuring FCM token: $e');
    return false;
  }
}
