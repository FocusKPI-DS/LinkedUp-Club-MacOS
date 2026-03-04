import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

Future<UserCredential?> googleSignInFunc() async {
  if (kIsWeb) {
    // Once signed in, return the UserCredential
    return await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
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
  try {
    await _googleSignIn.signOut();
  } catch (e) {
    // If sign out fails, reset the instance anyway
    print('Sign out error (will reset instance): $e');
    _resetGoogleSignInInstance();
    rethrow;
  }
}
