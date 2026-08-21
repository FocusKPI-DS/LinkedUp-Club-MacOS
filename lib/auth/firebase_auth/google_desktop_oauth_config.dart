/// Windows / Linux desktop Google OAuth (browser flow via [google_sign_in_all_platforms]).
///
/// Configure one of:
/// 1. Copy [env.json.example] to `env.json` (repo root, gitignored), then build with
///    `flutter build windows --dart-define-from-file=env.json`
/// 2. `--dart-define=GOOGLE_DESKTOP_OAUTH_CLIENT_ID=...` and `CLIENT_SECRET=...`
/// 3. Fill in [_fileClientId] / [_fileClientSecret] below (do not commit real secrets)
///
/// Google Cloud Console → OAuth client (Web application) → redirect URI:
/// `http://localhost:8000`
library;

/// Firebase project's **Web application** OAuth client (from Google Cloud Console).
/// Must match:
/// - `GOOGLE_DESKTOP_OAUTH_CLIENT_ID` in env.json
/// - Firebase Console → Authentication → Google → Web SDK configuration
///
/// Do NOT use the iOS/macOS client ID here.
const String kFirebaseProjectWebOAuthClientId =
    '548534727055-042f43gm4l2jhs3qf4t69m4g4g6mnjjc.apps.googleusercontent.com';

const int kGoogleDesktopOAuthRedirectPort = 8000;

/// Local dev fallback — leave empty in git; set locally or use dart-define.
const String _fileClientId = '';
const String _fileClientSecret = '';

String get kGoogleDesktopOAuthClientId {
  const fromEnv = String.fromEnvironment('GOOGLE_DESKTOP_OAUTH_CLIENT_ID');
  if (fromEnv.isNotEmpty) return fromEnv;
  return _fileClientId;
}

String get kGoogleDesktopOAuthClientSecret {
  const fromEnv = String.fromEnvironment('GOOGLE_DESKTOP_OAUTH_CLIENT_SECRET');
  if (fromEnv.isNotEmpty) return fromEnv;
  return _fileClientSecret;
}

bool get isGoogleDesktopOAuthConfigured =>
    kGoogleDesktopOAuthClientId.isNotEmpty &&
    kGoogleDesktopOAuthClientSecret.isNotEmpty;
