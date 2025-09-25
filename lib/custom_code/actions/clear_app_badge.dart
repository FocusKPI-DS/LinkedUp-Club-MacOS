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
