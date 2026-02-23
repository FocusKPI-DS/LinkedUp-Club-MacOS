import 'package:flutter/foundation.dart' show kIsWeb;
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';

// Conditional import for web platform
import 'web_notification_service_stub.dart'
    if (dart.library.html) 'web_notification_service_web.dart';

// Re-export the WebNotificationService class
export 'web_notification_service_stub.dart'
    if (dart.library.html) 'web_notification_service_web.dart';

/// Web notification service for tab-only notifications
/// Only works when the browser tab is open - no background notifications
///
/// This is a platform-specific implementation that uses conditional imports
/// to provide web functionality on web platforms and stub implementations
/// on other platforms.
