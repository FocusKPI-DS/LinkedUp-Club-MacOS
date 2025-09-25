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
import '/auth/firebase_auth/auth_util.dart';
import 'package:app_badge_plus/app_badge_plus.dart';

// Update app badge with current unread notification count
// Call this when app resumes or when you need to refresh the badge
Future<void> updateAppBadge() async {
  try {
    // Check if badges are supported
    bool isSupported = await AppBadgePlus.isSupported();

    if (!isSupported) {
      print('App badges are not supported on this device');
      return;
    }

    if (currentUserReference == null) {
      // Clear badge if no user
      await AppBadgePlus.updateBadge(0);
      return;
    }

    // Count unread notifications from ff_user_push_notifications
    // This collection is managed by FlutterFlow for push notifications
    final userPath = currentUserReference!.path;
    final notificationSnapshot = await FirebaseFirestore.instance
        .collection('ff_user_push_notifications')
        .where('user_refs', arrayContains: userPath)
        .where('status', isEqualTo: 'succeeded')
        .get();

    int unreadCount = notificationSnapshot.docs.length;

    // Update the app badge
    await AppBadgePlus.updateBadge(unreadCount);

    print('App badge updated with count: $unreadCount');
  } catch (e) {
    print('Error updating app badge: $e');
  }
}
