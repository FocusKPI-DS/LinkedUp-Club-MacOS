import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Configure GoogleSignIn - for macOS, specifying serverClientId can help with keychain issues
// This is the iOS client ID which works for macOS too
final _googleSignIn = GoogleSignIn(
  scopes: ['profile', 'email'],
  // serverClientId is needed to get idToken for Firebase Auth
  // This should be the iOS client ID from GoogleService-Info.plist
  serverClientId:
      '548534727055-nudrbc4rnh96q9uumdkknfcq7hqp3fle.apps.googleusercontent.com',
);

Future<UserCredential?> googleSignInFunc() async {
  if (kIsWeb) {
    // Once signed in, return the UserCredential
    return await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
  }

  // On macOS, Google Sign-In can have keychain issues
  if (!kIsWeb && Platform.isMacOS) {
    try {
      // First, sign out to clear any cached credentials
      await signOutWithGoogle().catchError((_) => null);

      // Attempt Google Sign-In
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
          e.toString().contains('GIDSignIn')) {
        print('Keychain error detected. This may be due to:');
        print(
            '1. App not properly signed with development/provisioning profile');
        print('2. Keychain access groups not properly configured');
        print('3. First-time keychain access permissions');
        // Still rethrow so UI can handle it
      }
      rethrow;
    }
  }

  // iOS and Android: use native Google Sign-In
  try {
    await signOutWithGoogle().catchError((_) => null);
    final auth = await (await _googleSignIn.signIn())?.authentication;
    if (auth == null) {
      return null;
    }
    final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken, accessToken: auth.accessToken);
    return FirebaseAuth.instance.signInWithCredential(credential);
  } catch (e) {
    print('Google Sign-In error: $e');
    // Re-throw to let the UI handle the error
    rethrow;
  }
}

Future signOutWithGoogle() => _googleSignIn.signOut();
