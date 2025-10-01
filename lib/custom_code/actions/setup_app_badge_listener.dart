// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!

import 'package:cloud_firestore/cloud_firestore.dart';
import '/auth/firebase_auth/auth_util.dart';
import 'package:app_badge_plus/app_badge_plus.dart';

// Listen to notification changes and update badge automatically
// Call this once after user logs in
Future<void> setupAppBadgeListener() async {
  if (currentUserReference == null) return;

  try {
    bool isSupported = await AppBadgePlus.isSupported();

    if (!isSupported) {
      print('App badges are not supported on this device');
      return;
    }

    // Listen to notification changes from ff_user_push_notifications
    // This collection is managed by FlutterFlow for push notifications
    final userPath = currentUserReference!.path;
    FirebaseFirestore.instance
        .collection('ff_user_push_notifications')
        .where('user_refs', arrayContains: userPath)
        .where('status', isEqualTo: 'succeeded')
        .snapshots()
        .listen((snapshot) async {
      int unreadCount = snapshot.docs.length;

      // Update the app badge with the count
      await AppBadgePlus.updateBadge(unreadCount);

      print('App badge updated to: $unreadCount');
    });

    print('App badge listener setup complete');
  } catch (e) {
    print('Error setting up app badge listener: $e');
  }
}
