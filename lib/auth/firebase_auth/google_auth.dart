import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart'
    as gsiap;

import 'google_desktop_oauth_config.dart';

// Configure GoogleSignIn - for macOS, specifying both clientId and serverClientId helps with keychain issues
// This is the iOS client ID which works for macOS too
GoogleSignIn _getGoogleSignInInstance() {
  const String clientId =
      '548534727055-nudrbc4rnh96q9uumdkknfcq7hqp3fle.apps.googleusercontent.com';

  return GoogleSignIn(
    scopes: ['profile', 'email'],
    // clientId is needed for macOS keychain access and OAuth flow
    clientId: clientId,
    // serverClientId is needed to get idToken for Firebase Auth
    serverClientId: clientId,
  );
}

// Cache the instance, but allow recreation when needed
GoogleSignIn? _cachedGoogleSignIn;
GoogleSignIn get _googleSignIn {
  _cachedGoogleSignIn ??= _getGoogleSignInInstance();
  return _cachedGoogleSignIn!;
}

// Force recreation of GoogleSignIn instance (useful for keychain recovery)
void _resetGoogleSignInInstance() {
  _cachedGoogleSignIn = null;
}

gsiap.GoogleSignIn? _windowsGoogleSignIn;

gsiap.GoogleSignIn _getWindowsGoogleSignIn() {
  return _windowsGoogleSignIn ??= gsiap.GoogleSignIn(
    params: gsiap.GoogleSignInParams(
      clientId: kGoogleDesktopOAuthClientId,
      clientSecret: kGoogleDesktopOAuthClientSecret,
      redirectPort: kGoogleDesktopOAuthRedirectPort,
      scopes: const [
        'openid',
        'email',
        'profile',
        'https://www.googleapis.com/auth/userinfo.profile',
        'https://www.googleapis.com/auth/userinfo.email',
      ],
    ),
  );
}

/// Returns true when [idToken] JWT exp is in the past (or unparseable).
bool _isGoogleIdTokenExpired(String? idToken) {
  if (idToken == null || idToken.isEmpty) return true;
  try {
    final parts = idToken.split('.');
    if (parts.length < 2) return true;
    final payload = parts[1];
    final normalized = payload.padRight(
      payload.length + ((4 - payload.length % 4) % 4),
      '=',
    );
    final json =
        jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
    final exp = json['exp'];
    if (exp is! num) return true;
    final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    return DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 1)));
  } catch (_) {
    return true;
  }
}

Future<gsiap.GoogleSignInCredentials?> _windowsGoogleOAuthCredentials(
  gsiap.GoogleSignIn googleSignIn,
) async {
  // signIn() prefers cached SharedPreferences tokens. Expired id_tokens cause
  // Firebase invalid-credential even when access_token still works.
  final cached = await googleSignIn.signInOffline();
  if (cached != null &&
      cached.idToken != null &&
      cached.idToken!.isNotEmpty &&
      !_isGoogleIdTokenExpired(cached.idToken)) {
    debugPrint('Windows Google Sign-In: reusing cached id_token');
    return cached;
  }

  debugPrint('Windows Google Sign-In: opening browser for fresh OAuth');
  await googleSignIn.signOut();
  return googleSignIn.signInOnline();
}

Future<UserCredential?> _googleSignInWindows() async {
  if (!isGoogleDesktopOAuthConfigured) {
    throw StateError(
      'Windows Google Sign-In is not configured. Copy env.json.example to env.json, '
      'then run/build with: flutter run -d windows --dart-define-from-file=env.json',
    );
  }

  if (kGoogleDesktopOAuthClientId != kFirebaseProjectWebOAuthClientId) {
    debugPrint(
      '⚠️ GOOGLE_DESKTOP_OAUTH_CLIENT_ID in env.json does not match the Firebase '
      'web client ($kFirebaseProjectWebOAuthClientId). Sign-in may fail.',
    );
  }

  // Do NOT sign out Firebase before OAuth (macOS rule applies here too).
  final googleSignIn = _getWindowsGoogleSignIn();
  final creds = await _windowsGoogleOAuthCredentials(googleSignIn);
  if (creds == null) {
    return null;
  }

  if (creds.idToken == null || creds.idToken!.isEmpty) {
    throw StateError(
      'Google returned no id_token. Ensure env.json uses the Web OAuth client '
      'with redirect http://localhost:8000 and rebuild with '
      '--dart-define-from-file=env.json.',
    );
  }

  debugPrint(
    'Windows Google OAuth ok (id_token aud check next via Firebase)...',
  );

  final credential = GoogleAuthProvider.credential(
    accessToken: creds.accessToken,
    idToken: creds.idToken,
  );
  try {
    return await FirebaseAuth.instance.signInWithCredential(credential);
  } on FirebaseAuthException catch (e) {
    debugPrint('Firebase Google sign-in failed: ${e.code} ${e.message}');
    if (e.code == 'invalid-credential') {
      // Stale cache may have slipped through — force one online retry.
      debugPrint('Retrying Windows Google Sign-In with fresh browser OAuth...');
      await googleSignIn.signOut();
      final fresh = await googleSignIn.signInOnline();
      if (fresh?.idToken != null && fresh!.idToken!.isNotEmpty) {
        return FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(
            accessToken: fresh.accessToken,
            idToken: fresh.idToken,
          ),
        );
      }
    }
    rethrow;
  }
}

Future<UserCredential?> googleSignInFunc() async {
  if (kIsWeb) {
    // Once signed in, return the UserCredential
    return await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
  }

  // Windows: browser OAuth (google_sign_in has no Windows plugin).
  if (!kIsWeb && Platform.isWindows) {
    try {
      return await _googleSignInWindows();
    } catch (e) {
      print('Windows Google Sign-In error: $e');
      rethrow;
    }
  }

  // On macOS: avoid sign-out before sign-in and do not retry (was causing "retry 3 times then fail").
  if (!kIsWeb && Platform.isMacOS) {
    try {
      // Do NOT sign out before sign-in on macOS — it can clear state needed for
      // the OAuth callback and cause signIn() to fail after the user returns from the browser.
      // Single attempt only; no retries (retries were forcing the user through the flow 3 times).
      print('Attempting Google Sign-In on macOS...');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      print('macOS Google Sign-In error: $e');
      // If it's a keychain error, provide more helpful error message
      if (e.toString().contains('keychain') ||
          e.toString().contains('GIDSignIn') ||
          e.toString().contains('com.google.GIDSignIn')) {
        print('Keychain/GIDSignIn error detected. This may be due to:');
        print(
            '1. App not properly signed with development/provisioning profile');
        print('2. Keychain access groups not properly configured');
        print('3. First-time keychain access permissions');
        print(
            '4. Potential conflict with Gmail OAuth - try signing out and back in');
        print('5. Corrupted keychain state - try restarting the app');
        // Still rethrow so UI can handle it
      }
      rethrow;
    }
  }

  // iOS and Android: use native Google Sign-In
  try {
    // Always sign out first to clear cached account and show account picker
    // This ensures users can choose their account instead of auto-signing in
    try {
      await signOutWithGoogle();
    } catch (e) {
      // Ignore errors from sign out - it might fail if not signed in
      print('Sign out before sign-in (this is normal): $e');
    }

    // Always show account picker - don't use silent sign-in
    final auth = await (await _googleSignIn.signIn())?.authentication;
    if (auth == null) {
      return null; // User cancelled
    }
    final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken, accessToken: auth.accessToken);
    return await FirebaseAuth.instance.signInWithCredential(credential);
  } catch (e) {
    print('Google Sign-In error: $e');
    // Re-throw to let the UI handle the error
    rethrow;
  }
}

Future signOutWithGoogle() async {
  if (!kIsWeb && Platform.isWindows) {
    try {
      await _getWindowsGoogleSignIn().signOut();
    } catch (e) {
      print('Windows Google sign out error: $e');
    }
    return;
  }

  try {
    await _googleSignIn.signOut();
  } catch (e) {
    // If sign out fails, reset the instance anyway
    print('Sign out error (will reset instance): $e');
    _resetGoogleSignInInstance();
    rethrow;
  }
}
