// Stub implementation for non-web platforms
// This file provides empty implementations when dart:html is not available

/// Web notification service stub for non-web platforms
class WebNotificationService {
  static WebNotificationService? _instance;
  static WebNotificationService get instance =>
      _instance ??= WebNotificationService._();

  WebNotificationService._();

  bool _isSupported = false;
  bool _isInitialized = false;

  // Track processed notifications to prevent duplicates
  final Set<String> _processedNotifications = <String>{};

  /// Initialize the notification service (no-op for non-web)
  Future<void> initialize() async {
    print('🔔 Web notifications not available on this platform');
    _isInitialized = true;
  }

  /// Show a notification for a new message (no-op for non-web)
  void showMessageNotification({
    required String title,
    required String body,
    String? senderName,
    String? chatName,
    bool forceShow = false,
  }) {
    print('🔔 Web notifications not available on this platform');
  }

  /// Update tab title with unread count (no-op for non-web)
  void updateTabTitle(int unreadCount) {
    // No-op for non-web platforms
  }

  /// Check if notifications are available (always false for non-web)
  bool get isAvailable => false;

  /// Get current permission status (always 'unsupported' for non-web)
  String get permissionStatus => 'unsupported';

  /// Request permission manually (always returns 'unsupported' for non-web)
  Future<String> requestPermission() async {
    return 'unsupported';
  }

  /// Dispose resources (no-op for non-web)
  void dispose() {
    // No-op for non-web platforms
  }
}
