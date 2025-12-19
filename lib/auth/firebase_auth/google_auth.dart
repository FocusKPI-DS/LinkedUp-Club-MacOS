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

  // On macOS, Google Sign-In can have keychain issues
  if (!kIsWeb && Platform.isMacOS) {
    try {
      // Try silent sign-in first to avoid unnecessary sign-out
      // This prevents conflicts with Gmail OAuth
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signInSilently();
        if (googleUser != null) {
          // We have a cached user, try to use their credentials
          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication;

          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          // Try to sign in with existing credentials
          try {
            return await FirebaseAuth.instance.signInWithCredential(credential);
          } catch (e) {
            // If that fails, the credentials might be stale, continue with fresh sign-in
            print(
                'Sign-in with cached credentials failed, trying fresh sign-in: $e');
            await signOutWithGoogle().catchError((_) => null);
            googleUser = null; // Reset to force fresh sign-in
          }
        }
      } catch (e) {
        // Silent sign-in failed, this is normal if no cached user
        print('Silent sign-in failed (this is normal): $e');
        // Only sign out if there's an actual error, not just no cached user
        if (e.toString().contains('sign_in_required') == false &&
            e.toString().contains('SignInRequiredException') == false) {
          await signOutWithGoogle().catchError((_) => null);
        }
      }

      // If we don't have a user yet, attempt fresh Google Sign-In
      if (googleUser == null) {
        // For macOS, we need to ensure GIDSignIn is properly configured
        // The AppDelegate should have configured it, but we'll try anyway
        print('Attempting Google Sign-In on macOS...');

        // Clear any potentially corrupted state before attempting sign-in
        // This helps resolve conflicts with Gmail OAuth
        try {
          await signOutWithGoogle();
        } catch (e) {
          // Ignore errors from sign out - it might fail if not signed in
          print('Sign out before sign-in (this is normal): $e');
        }

        // Wait a brief moment to ensure keychain state is cleared
        await Future.delayed(const Duration(milliseconds: 200));

        // Try sign-in with retry logic for keychain errors
        int maxRetries = 2;
        int retryCount = 0;

        while (retryCount <= maxRetries && googleUser == null) {
          try {
            googleUser = await _googleSignIn.signIn();
            break; // Success, exit loop
          } catch (signInError) {
            // Check if it's a keychain/GIDSignIn error
            final isKeychainError =
                signInError.toString().contains('GIDSignIn') ||
                    signInError.toString().contains('com.google.GIDSignIn') ||
                    signInError.toString().contains('keychain');

            if (isKeychainError && retryCount < maxRetries) {
              retryCount++;
              print(
                  'GIDSignIn/keychain error detected (attempt $retryCount/$maxRetries), attempting recovery...');

              // Reset the instance and try again
              _resetGoogleSignInInstance();
              try {
                await signOutWithGoogle();
              } catch (_) {
                // Ignore sign out errors
              }

              // Wait longer between retries
              await Future.delayed(Duration(milliseconds: 500 * retryCount));
            } else {
              // Not a keychain error, or max retries reached
              if (isKeychainError) {
                print('Keychain error persists after $maxRetries retries');
                print('This may indicate:');
                print('1. App needs to be properly code-signed');
                print('2. Keychain access permissions need to be granted');
                print(
                    '3. Try restarting the app or signing out from System Preferences > Internet Accounts');
              }
              rethrow;
            }
          }
        }

        if (googleUser == null) {
          // User cancelled the sign-in
          return null;
        }
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
    // Try silent sign-in first to avoid unnecessary sign-out
    // This prevents conflicts with Gmail OAuth
    GoogleSignInAccount? googleUser;
    try {
      googleUser = await _googleSignIn.signInSilently();
      if (googleUser != null) {
        // We have a cached user, try to use their credentials
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Try to sign in with existing credentials
        try {
          return await FirebaseAuth.instance.signInWithCredential(credential);
        } catch (e) {
          // If that fails, the credentials might be stale, continue with fresh sign-in
          print(
              'Sign-in with cached credentials failed, trying fresh sign-in: $e');
          await signOutWithGoogle().catchError((_) => null);
          googleUser = null; // Reset to force fresh sign-in
        }
      }
    } catch (e) {
      // Silent sign-in failed, this is normal if no cached user
      print('Silent sign-in failed (this is normal): $e');
      // Only sign out if there's an actual error, not just no cached user
      if (e.toString().contains('sign_in_required') == false &&
          e.toString().contains('SignInRequiredException') == false) {
        await signOutWithGoogle().catchError((_) => null);
      }
    }

    // If we don't have a user yet, attempt fresh Google Sign-In
    if (googleUser == null) {
      await signOutWithGoogle().catchError((_) => null);
      final auth = await (await _googleSignIn.signIn())?.authentication;
      if (auth == null) {
        return null;
      }
      final credential = GoogleAuthProvider.credential(
          idToken: auth.idToken, accessToken: auth.accessToken);
      return await FirebaseAuth.instance.signInWithCredential(credential);
    }

    // Should not reach here, but just in case
    return null;
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
