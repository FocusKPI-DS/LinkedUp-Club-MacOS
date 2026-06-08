import 'package:flutter/foundation.dart';

/// Debug-only logging. Stripped in release builds (no console output).
void debugLog(Object? message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print(message);
  }
}
