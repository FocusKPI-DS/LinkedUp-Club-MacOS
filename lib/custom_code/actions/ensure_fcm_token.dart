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
          return false;
        }

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
          return false;
        }

        // Get FCM token with VAPID key for web
        String? token;
        try {
          token = await messaging.getToken(vapidKey: vapidKey);
        } catch (e) {
          // Try without VAPID key as fallback
          try {
            token = await messaging.getToken();
          } catch (e2) {
            // Error getting FCM token
          }
        }

        if (token == null || token.isEmpty) {
          return false;
        }

        // Determine device type
        String deviceType = isChrome ? 'Chrome' : 'Edge';

        // Store token in Firestore (same logic as mobile platforms)
        final fcmTokensRef = userRef.collection('fcm_tokens');
        final existingTokenQuery = await fcmTokensRef
            .where('fcm_token', isEqualTo: token)
            .limit(1)
            .get();

        if (existingTokenQuery.docs.isEmpty) {
          await fcmTokensRef.add({
            'fcm_token': token,
            'device_type': deviceType,
            'created_at': FieldValue.serverTimestamp(),
          });
        } else {
          await existingTokenQuery.docs.first.reference.update({
            'fcm_token': token,
            'device_type': deviceType,
          });
        }

        // Listen for token refresh
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          try {
            final allTokensQuery = await fcmTokensRef.get();
            for (var doc in allTokensQuery.docs) {
              await doc.reference.delete();
            }

            await fcmTokensRef.add({
              'fcm_token': newToken,
              'device_type': deviceType,
              'created_at': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            // Error during token refresh
          }
        });

        return true;
      } catch (e) {
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
      return false;
    }

    // For macOS and iOS, ensure APNS token is available before getting FCM token
    if (!kIsWeb && (Platform.isMacOS || Platform.isIOS)) {
      String? apnsToken;
      int maxRetries = 10;
      int retryCount = 0;

      while (apnsToken == null && retryCount < maxRetries) {
        try {
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken != null) {
            break;
          }
        } catch (e) {
          // APNS token not yet available
        }

        // Exponential backoff: wait longer each time
        await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
        retryCount++;
      }

      if (apnsToken == null) {
        return false;
      }
    }

    // Get the token
    String? token = await messaging.getToken();

    if (token == null || token.isEmpty) {
      return false;
    }

    print('✅ Got FCM token: ${token.substring(0, min(10, token.length))}...');
    
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
    
    print('🔍 Checking Firestore for existing token ($deviceType)...');

    // Check if fcm_tokens subcollection exists and has this token
    final fcmTokensRef = userRef.collection('fcm_tokens');
    final existingTokenQuery =
        await fcmTokensRef.where('fcm_token', isEqualTo: token).limit(1).get();

    if (existingTokenQuery.docs.isEmpty) {
      // Token doesn't exist, add it
      print('📝 Token not found, adding new token to Firestore...');
      await fcmTokensRef.add({
        'fcm_token': token,
        'device_type': deviceType,
        'created_at': FieldValue.serverTimestamp(),
      });
      print('✅ New token saved successfully!');
    } else {
      // Token exists, update it if needed
      print('📝 Token found, updating existing record...');
      await existingTokenQuery.docs.first.reference.update({
        'fcm_token': token,
        'device_type': deviceType,
      });
      print('✅ Existing token updated successfully!');
    }

    // Subscribe to News topic (mobile platforms only)
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
        await FirebaseMessaging.instance.subscribeToTopic('news');
        print('✅ Subscribed to news topic');
      }
    } catch (e) {
      print('❌ Failed to subscribe to topic: $e');
    }

    // Also listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
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
          if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
            await FirebaseMessaging.instance.subscribeToTopic('news');
            print('✅ Subscribed to news topic (after refresh)');
          }
        } catch (e) {
          print('❌ Failed to re-subscribe: $e');
        }
      } catch (e) {
        print('❌ Error during token refresh: $e');
      }
    });

    return true;
  } catch (e) {
    print('❌ ensureFcmToken failed: $e');
    return false;
  }
}
