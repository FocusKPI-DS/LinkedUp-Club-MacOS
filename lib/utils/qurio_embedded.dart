import 'package:flutter/foundation.dart' show kIsWeb;
import '/utils/debug_log.dart';
import 'qurio_message_handler_stub.dart'
    if (dart.library.html) 'qurio_message_handler_web.dart' as handler;
import 'qurio_embedded_check_stub.dart'
    if (dart.library.html) 'qurio_embedded_check_web.dart' as embedCheck;

/// Detects whether Lona is running inside the Qurio desktop app's iframe.
///
/// On web, checks for:
///   1. The `embedded=qurio` URL query parameter, OR
///   2. Whether `window.parent !== window` (running in any iframe)
///
/// On native platforms, this is always false.
///
/// Usage:
///   if (QurioEmbedded.isEmbeddedInQurio) { ... }
class QurioEmbedded {
  QurioEmbedded._();

  static bool _initialized = false;
  static bool _embedded = false;

  /// Whether Lona is currently running embedded inside Qurio's iframe.
  static bool get isEmbeddedInQurio {
    if (!_initialized) {
      _initialize();
    }
    return _embedded;
  }

  /// Call once at startup (optional — getter auto-initializes on first access).
  static void initialize() {
    if (!_initialized) {
      _initialize();
    }
  }

  static void _initialize() {
    _initialized = true;
    if (!kIsWeb) {
      _embedded = false;
      return;
    }
    try {
      // Method 1: Check URL parameter (primary, reliable on first load)
      final uri = Uri.base;
      final embeddedParam = uri.queryParameters['embedded'];
      final hasParam = embeddedParam == 'qurio';

      // Method 2: Check if running inside an iframe (works even after hot restart)
      final isInIframe = embedCheck.isRunningInIframe();

      _embedded = hasParam || isInIframe;

      if (_embedded) {
        debugLog('[QurioEmbedded] ✅ Running embedded inside Qurio'
            ' (param=$hasParam, iframe=$isInIframe)');
        // Start listening for postMessage from Qurio parent window
        handler.startListening();
      }
    } catch (e) {
      debugLog('[QurioEmbedded] ❌ Error checking embedded status: $e');
      _embedded = false;
    }
  }
}
