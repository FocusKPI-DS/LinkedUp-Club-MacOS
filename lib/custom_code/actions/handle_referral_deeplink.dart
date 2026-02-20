// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

const String _referralUidKey = 'pending_referrer_uid';

/// Initialize deep link listener for referral links (lona://invite/{uid})
/// Returns a StreamSubscription that should be cancelled when done
StreamSubscription<Uri>? _referralLinkSubscription;

Future<void> initializeReferralDeepLink() async {
  try {
    final appLinks = AppLinks();

    // Handle initial link (if app was opened from a link)
    final initialUri = await appLinks.getInitialLink();
    if (initialUri != null) {
      _handleReferralLink(initialUri);
    }

    // Listen for incoming links while app is running
    _referralLinkSubscription = appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleReferralLink(uri);
      },
      onError: (error) {
        print('[Referral Deep Link] Error: $error');
      },
    );

    print('[Referral Deep Link] ✅ Listener initialized');
  } catch (e) {
    print('[Referral Deep Link] ❌ Failed to initialize: $e');
  }
}

/// Handle referral deep link (lona://invite/{uid} or https://lona.club/invite/{uid})
Future<void> _handleReferralLink(Uri uri) async {
  try {
    print('[Referral Deep Link] Received URI: $uri');

    String? uid;

    // Check if it's a custom URL scheme (lona://invite/{uid} or lona://invite/{uid})
    if (uri.scheme == 'lona') {
      // Handle lona://invite/{uid} format
      if (uri.host == 'invite' && uri.pathSegments.isNotEmpty) {
        uid = uri.pathSegments.first;
      }
      // Handle lona://invite/{uid} where host is empty and path is /invite/{uid}
      else if (uri.host.isEmpty) {
        final path = uri.path;
        final match = RegExp(r'/invite/([^/]+)').firstMatch(path);
        if (match != null) {
          uid = match.group(1);
        }
        // Also check if pathSegments contains 'invite'
        else if (uri.pathSegments.length >= 2 &&
            uri.pathSegments[0] == 'invite') {
          uid = uri.pathSegments[1];
        }
      }
    }
    // Check if it's a Universal Link (https://lona.club/invite/{uid})
    else if (uri.scheme == 'https' &&
        (uri.host == 'lona.club' || uri.host.contains('lona.club'))) {
      final path = uri.path;
      final match = RegExp(r'/invite/([^/]+)').firstMatch(path);
      if (match != null) {
        uid = match.group(1);
      }
    }

    if (uid != null && uid.isNotEmpty) {
      print('[Referral Deep Link] ✅ Extracted UID: $uid');
      await _storeReferralUid(uid);
    } else {
      print('[Referral Deep Link] ⚠️ No UID found in URI');
    }
  } catch (e) {
    print('[Referral Deep Link] ❌ Error handling link: $e');
  }
}

/// Store referral UID in SharedPreferences
Future<void> _storeReferralUid(String uid) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_referralUidKey, uid);
    print('[Referral Deep Link] ✅ Stored referral UID: $uid');
  } catch (e) {
    print('[Referral Deep Link] ❌ Failed to store UID: $e');
  }
}

/// Get stored referral UID (returns null if not found)
Future<String?> getStoredReferralUid() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_referralUidKey);
    return uid;
  } catch (e) {
    print('[Referral Deep Link] ❌ Failed to get stored UID: $e');
    return null;
  }
}

/// Clear stored referral UID (call after processing)
Future<void> clearStoredReferralUid() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_referralUidKey);
    print('[Referral Deep Link] ✅ Cleared stored referral UID');
  } catch (e) {
    print('[Referral Deep Link] ❌ Failed to clear UID: $e');
  }
}

/// Dispose the deep link listener
void disposeReferralDeepLink() {
  _referralLinkSubscription?.cancel();
  _referralLinkSubscription = null;
  print('[Referral Deep Link] ✅ Listener disposed');
}
