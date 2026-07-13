/// Example values for Windows Google Sign-In.
///
/// Option A — `google_desktop_oauth_config.dart`: set `_fileClientId` / `_fileClientSecret`
/// Option B — build with dart-define (do not commit secrets):
///   flutter build windows --dart-define=GOOGLE_DESKTOP_OAUTH_CLIENT_ID=... --dart-define=GOOGLE_DESKTOP_OAUTH_CLIENT_SECRET=...
///
/// Google Cloud Console → Credentials → OAuth client ID → **Web application**
/// Authorized redirect URI: `http://localhost:8000`
const String exampleGoogleDesktopOAuthClientId =
    'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';
const String exampleGoogleDesktopOAuthClientSecret = 'YOUR_CLIENT_SECRET';
