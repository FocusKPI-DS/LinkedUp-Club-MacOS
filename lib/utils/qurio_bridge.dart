/// Utility functions for Lona to send messages to the Qurio parent window.
///
/// These are only functional on Web when embedded in Qurio's iframe.
/// On native platforms or when not embedded, all calls are no-ops.
///
/// Usage:
///   import '/utils/qurio_bridge.dart';
///
///   QurioBridge.sendNotification(title: 'New Message', body: 'You have a new chat message');
///   QurioBridge.sendAuthStatus(loggedIn: true);

import 'package:flutter/foundation.dart' show kIsWeb;
import 'qurio_embedded.dart';
import 'qurio_bridge_stub.dart'
    if (dart.library.html) 'qurio_bridge_web.dart'
    as bridge;

class QurioBridge {
  QurioBridge._();

  /// Send a notification to Qurio (displayed as OS notification).
  static void sendNotification({required String title, String? body}) {
    if (!kIsWeb || !QurioEmbedded.isEmbeddedInQurio) return;
    bridge.postToParent({
      'type': 'LONA_NOTIFICATION',
      'title': title,
      'body': body ?? '',
    });
  }

  /// Notify Qurio of Lona's current auth status.
  static void sendAuthStatus({
    required bool loggedIn,
    String? email,
    String? uid,
  }) {
    if (!kIsWeb || !QurioEmbedded.isEmbeddedInQurio) return;
    bridge.postToParent({
      'type': 'LONA_AUTH_STATUS',
      'success': loggedIn,
      'email': email,
      'uid': uid,
    });
  }

  /// Send a custom message to Qurio.
  static void sendMessage(Map<String, dynamic> message) {
    if (!kIsWeb || !QurioEmbedded.isEmbeddedInQurio) return;
    bridge.postToParent(message);
  }

  /// Ask Qurio to open a URL in the system browser.
  /// Returns true if the request was sent (embedded in Qurio), false otherwise.
  static bool openUrl(String url) {
    if (!kIsWeb || !QurioEmbedded.isEmbeddedInQurio) return false;
    bridge.postToParent({'type': 'LONA_OPEN_URL', 'url': url});
    return true;
  }
}
