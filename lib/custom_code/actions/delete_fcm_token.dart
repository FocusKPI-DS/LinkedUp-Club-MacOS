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

/// Deletes all FCM tokens for the given user reference.
/// This should be called when a user logs out to prevent receiving
/// notifications for accounts they're no longer logged into.
Future<bool> deleteFcmToken(DocumentReference userRef) async {
  try {
    print('🗑️ Deleting FCM tokens for user: ${userRef.path}');
    
    // Get all FCM tokens for this user
    final fcmTokensRef = userRef.collection('fcm_tokens');
    final allTokensQuery = await fcmTokensRef.get();
    
    if (allTokensQuery.docs.isEmpty) {
      print('ℹ️ No FCM tokens found for user');
      return true;
    }
    
    // Delete all tokens
    int deletedCount = 0;
    for (var doc in allTokensQuery.docs) {
      try {
        await doc.reference.delete();
        deletedCount++;
      } catch (e) {
        print('⚠️ Error deleting token ${doc.id}: $e');
      }
    }
    
    print('✅ Deleted $deletedCount FCM token(s) for user');
    
    // Also unsubscribe from topics (mobile platforms only)
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
        await FirebaseMessaging.instance.unsubscribeFromTopic('news');
        print('✅ Unsubscribed from news topic');
      }
    } catch (e) {
      print('⚠️ Failed to unsubscribe from topic: $e');
    }
    
    // Delete the FCM token from Firebase Messaging instance
    try {
      await FirebaseMessaging.instance.deleteToken();
      print('✅ Deleted FCM token from Firebase Messaging instance');
    } catch (e) {
      print('⚠️ Failed to delete token from Firebase Messaging: $e');
      // This is not critical - the token will be invalidated when user logs out
    }
    
    return true;
  } catch (e) {
    print('❌ deleteFcmToken failed: $e');
    return false;
  }
}
