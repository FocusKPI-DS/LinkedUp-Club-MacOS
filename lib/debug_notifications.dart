// Debug notifications file
// This file is used for debugging notification functionality

import 'package:flutter/material.dart';

class DebugNotifications {
  static void log(String message) {
    debugPrint('🔔 DEBUG NOTIFICATION: $message');
  }

  static void logError(String error) {
    debugPrint('❌ DEBUG NOTIFICATION ERROR: $error');
  }
}
