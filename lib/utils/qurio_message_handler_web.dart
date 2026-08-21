import 'dart:html' as html;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '/custom_code/services/web_notification_service_web.dart'
    deferred as notif_svc;
import '/custom_code/services/google_meet_creator.dart';

/// Web implementation: listens for postMessage events from the Qurio parent window.
///
/// Supported message types:
///   { "type": "QURIO_AUTH_TOKEN", "customToken": "..." }
///     → Signs in to Lona using signInWithCustomToken
///
///   { "type": "QURIO_SIGN_OUT" }
///     → Signs out the current Lona user
void startListening() {
  html.window.onMessage.listen((html.MessageEvent event) async {
    try {
      // Parse the incoming message
      final data = event.data;
      if (data == null) return;

      Map<String, dynamic> message;
      if (data is String) {
        message = json.decode(data) as Map<String, dynamic>;
      } else if (data is Map) {
        message = Map<String, dynamic>.from(data);
      } else {
        return; // Ignore non-map/non-string messages
      }

      final type = message['type'] as String?;
      if (type == null) return;

      switch (type) {
        case 'QURIO_AUTH_TOKEN':
          await _handleAuthToken(message, event);
          break;
        case 'QURIO_SIGN_OUT':
          await _handleSignOut(event);
          break;
        case 'QURIO_GOOGLE_TOKEN':
          _handleGoogleToken(message);
          break;
        default:
          print('[QurioMessageHandler] Unknown message type: $type');
      }
    } catch (e) {
      print('[QurioMessageHandler] ❌ Error processing message: $e');
      _postToParent({
        'type': 'LONA_AUTH_STATUS',
        'success': false,
        'error': e.toString(),
      });
    }
  });

  print('[QurioMessageHandler] ✅ Listening for postMessage from Qurio');

  // Notify Qurio that Lona is ready to receive messages
  _postToParent({'type': 'LONA_READY'});
}

/// Handle QURIO_AUTH_TOKEN: sign in with the provided Custom Token.
Future<void> _handleAuthToken(
  Map<String, dynamic> message,
  html.MessageEvent event,
) async {
  final customToken = message['customToken'] as String?;
  if (customToken == null || customToken.isEmpty) {
    print('[QurioMessageHandler] ❌ Missing customToken in QURIO_AUTH_TOKEN');
    _postToParent({
      'type': 'LONA_AUTH_STATUS',
      'success': false,
      'error': 'Missing custom token',
    });
    return;
  }

  print('[QurioMessageHandler] 🔐 Signing in with Custom Token...');

  try {
    final userCredential = await FirebaseAuth.instance.signInWithCustomToken(
      customToken,
    );
    final user = userCredential.user;

    print('[QurioMessageHandler] ✅ Signed in as: ${user?.email ?? user?.uid}');

    // Restart notification listener now that the user is authenticated.
    // Use deferred import to avoid circular dependency:
    //   qurio_embedded → qurio_message_handler_web → web_notification_service_web → qurio_embedded
    try {
      await notif_svc.loadLibrary();
      notif_svc.WebNotificationService.instance.restartNotificationListener();
      print('[QurioMessageHandler] 🔔 Notification listener restarted');
    } catch (e) {
      print(
        '[QurioMessageHandler] ⚠️ Failed to restart notification listener: $e',
      );
    }

    _postToParent({
      'type': 'LONA_AUTH_STATUS',
      'success': true,
      'uid': user?.uid,
      'email': user?.email,
    });
  } catch (e) {
    print('[QurioMessageHandler] ❌ signInWithCustomToken failed: $e');
    _postToParent({
      'type': 'LONA_AUTH_STATUS',
      'success': false,
      'error': e.toString(),
    });
  }
}

/// Handle QURIO_SIGN_OUT: sign out the current Lona user.
Future<void> _handleSignOut(html.MessageEvent event) async {
  try {
    await FirebaseAuth.instance.signOut();
    print('[QurioMessageHandler] ✅ Signed out');
    _postToParent({
      'type': 'LONA_AUTH_STATUS',
      'success': true,
      'signedOut': true,
    });
  } catch (e) {
    print('[QurioMessageHandler] ❌ Sign out failed: $e');
    _postToParent({
      'type': 'LONA_AUTH_STATUS',
      'success': false,
      'error': e.toString(),
    });
  }
}

/// Handle QURIO_GOOGLE_TOKEN: forward token to GoogleMeetCreator.
void _handleGoogleToken(Map<String, dynamic> message) {
  final token = message['token'] as String?;
  print('[QurioMessageHandler] 🔑 Got Google token: ${token != null ? 'yes' : 'null'}');
  GoogleMeetCreator.handleTokenResponse(token);
}

/// Send a message back to the Qurio parent window.
void _postToParent(Map<String, dynamic> message) {
  try {
    html.window.parent?.postMessage(json.encode(message), '*');
  } catch (e) {
    print('[QurioMessageHandler] ❌ Failed to postMessage to parent: $e');
  }
}
