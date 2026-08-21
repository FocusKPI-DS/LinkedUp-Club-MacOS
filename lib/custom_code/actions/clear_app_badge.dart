// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!

import 'package:app_badge_plus/app_badge_plus.dart';

// Clear app badge (set to 0)
// Call this when user logs out or marks all notifications as read
Future<void> clearAppBadge() async {
  try {
    bool isSupported = await AppBadgePlus.isSupported();

    if (isSupported) {
      await AppBadgePlus.updateBadge(0);
      print('App badge cleared');
    }
  } catch (e) {
    print('Error clearing app badge: $e');
  }
}
