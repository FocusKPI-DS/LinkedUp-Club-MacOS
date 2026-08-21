import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '/utils/qurio_embedded.dart';
import '/utils/qurio_bridge.dart';

/// Creates a Google Meet link using the Google Calendar API.
///
/// This is a standalone Lona capability. Token acquisition strategy:
///   1. Qurio-embedded: request token from Qurio (no popup needed)
///   2. Standalone Web: Firebase signInWithPopup with calendar scope
///   3. Native (iOS/macOS): google_sign_in package
class GoogleMeetCreator {
  GoogleMeetCreator._();

  static const _calendarScope =
      'https://www.googleapis.com/auth/calendar.events';

  /// Pending token completer — used for Qurio async round-trip.
  static Completer<String?>? _tokenCompleter;

  /// Called by the message handler when Qurio responds with a token.
  static void handleTokenResponse(String? token) {
    if (_tokenCompleter != null && !_tokenCompleter!.isCompleted) {
      _tokenCompleter!.complete(token);
    }
  }

  /// Create a new Google Meet and return the meeting URL.
  static Future<String?> createInstantMeeting({String? chatTitle}) async {
    try {
      print('[GoogleMeetCreator] 🚀 Creating instant meeting...');

      final accessToken = await _getCalendarAccessToken();
      if (accessToken == null) {
        print('[GoogleMeetCreator] ❌ Could not get calendar access token');
        return null;
      }
      print('[GoogleMeetCreator] ✅ Got access token');

      // Create a calendar event with Google Meet
      final now = DateTime.now().toUtc();
      final end = now.add(const Duration(hours: 1));

      final eventBody = {
        'summary': chatTitle ?? 'Quick Meeting',
        'start': {'dateTime': now.toIso8601String()},
        'end': {'dateTime': end.toIso8601String()},
        'conferenceData': {
          'createRequest': {
            'requestId':
                'lona-meet-${DateTime.now().millisecondsSinceEpoch}',
            'conferenceSolutionKey': {'type': 'hangoutsMeet'},
          },
        },
      };

      final response = await http.post(
        Uri.parse(
          'https://www.googleapis.com/calendar/v3/calendars/primary/events'
          '?conferenceDataVersion=1',
        ),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(eventBody),
      );

      print('[GoogleMeetCreator] Calendar API: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('[GoogleMeetCreator] ❌ Error: ${response.body}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final meetUrl =
          data['hangoutLink'] as String? ?? _extractMeetUrl(data);

      if (meetUrl != null) {
        print('[GoogleMeetCreator] ✅ Created Meet: $meetUrl');
      }
      return meetUrl;
    } catch (e) {
      print('[GoogleMeetCreator] ❌ Error: $e');
      return null;
    }
  }

  static Future<String?> _getCalendarAccessToken() async {
    if (!kIsWeb) return _getTokenNative();

    // Strategy 1: If inside Qurio, ask Qurio for its Google token (fast, no popup)
    if (QurioEmbedded.isEmbeddedInQurio) {
      print('[GoogleMeetCreator] 🔑 Requesting token from Qurio...');
      final token = await _getTokenFromQurio();
      if (token != null) return token;
      print('[GoogleMeetCreator] ⚠️ Qurio token failed, trying popup...');
    }

    // Strategy 2: Standalone Web — use Firebase popup
    return _getTokenWeb();
  }

  /// Request Google token from Qurio via postMessage.
  static Future<String?> _getTokenFromQurio() async {
    try {
      _tokenCompleter = Completer<String?>();

      // Ask Qurio for a Google access token
      QurioBridge.sendMessage({
        'type': 'LONA_REQUEST_GOOGLE_TOKEN',
      });

      // Wait up to 3 seconds for Qurio to respond
      final token = await _tokenCompleter!.future
          .timeout(const Duration(seconds: 3), onTimeout: () => null);

      _tokenCompleter = null;
      return token;
    } catch (e) {
      print('[GoogleMeetCreator] ❌ Qurio token error: $e');
      _tokenCompleter = null;
      return null;
    }
  }

  /// Web: Use Firebase Auth popup.
  static Future<String?> _getTokenWeb() async {
    try {
      print('[GoogleMeetCreator] 🌐 Using Firebase popup...');
      final provider = GoogleAuthProvider();
      provider.addScope(_calendarScope);
      provider.addScope('profile');
      provider.addScope('email');

      final result =
          await FirebaseAuth.instance.signInWithPopup(provider);
      final credential = result.credential;
      if (credential is OAuthCredential && credential.accessToken != null) {
        print('[GoogleMeetCreator] 🌐 ✅ Got token via popup');
        return credential.accessToken;
      }
      print('[GoogleMeetCreator] 🌐 ❌ No token in credential');
      return null;
    } catch (e) {
      print('[GoogleMeetCreator] 🌐 ❌ Popup error: $e');
      return null;
    }
  }

  /// Native: Use google_sign_in package.
  static Future<String?> _getTokenNative() async {
    try {
      print('[GoogleMeetCreator] 📱 Using GoogleSignIn...');
      final googleSignIn = GoogleSignIn(
        scopes: [_calendarScope, 'profile', 'email'],
      );

      GoogleSignInAccount? account = await googleSignIn.signInSilently();
      account ??= await googleSignIn.signIn();
      if (account == null) return null;

      final hasScope = await googleSignIn.requestScopes([_calendarScope]);
      if (!hasScope) return null;

      final auth = await account.authentication;
      return auth.accessToken;
    } catch (e) {
      print('[GoogleMeetCreator] 📱 ❌ Error: $e');
      return null;
    }
  }

  static String? _extractMeetUrl(Map<String, dynamic> eventData) {
    try {
      final confData =
          eventData['conferenceData'] as Map<String, dynamic>?;
      final entryPoints = confData?['entryPoints'] as List<dynamic>?;
      if (entryPoints == null) return null;
      for (final ep in entryPoints) {
        final epMap = ep as Map<String, dynamic>;
        if (epMap['entryPointType'] == 'video') {
          return epMap['uri'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }
}
