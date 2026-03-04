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
    // Note: user_refs is stored as a comma-separated string, not an array
    final userPath = currentUserReference!.path;
    final userId = currentUserReference!.id;
    
    /* 
    ❌ This listener is causing "Permission Denied" errors because we cannot query 'user_refs' (String) 
    server-side to match security rules. The current query fetches ALL 'succeeded' notifications 
    which strictly violates the privacy rules we just enforced.
    
    Until we can migrate 'user_refs' to an Array or add a 'receiver_uid' field, 
    we must disable this real-time listener to prevent log spam and crashes.
    
    FirebaseFirestore.instance
        .collection('ff_user_push_notifications')
        .where('status', isEqualTo: 'succeeded')
        .snapshots()
        .listen((snapshot) async {
      // Filter client-side to check if user_refs string contains the user path
      final filteredDocs = snapshot.docs.where((doc) {
        final userRefs = doc.data()['user_refs'] as String? ?? '';
        return userRefs.contains(userPath) || userRefs.contains(userId);
      }).toList();
      
      int unreadCount = filteredDocs.length;

      // Update the app badge with the count
      await AppBadgePlus.updateBadge(unreadCount);

      print('App badge updated to: $unreadCount');
    });
    */
    print('⚠️ App badge listener disabled to prevent Firestore permission errors');

    print('App badge listener setup complete');
  } catch (e) {
    print('Error setting up app badge listener: $e');
  }
}
