import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';

/// Web notification service implementation for web platform
class WebNotificationService {
  static WebNotificationService? _instance;
  static WebNotificationService get instance =>
      _instance ??= WebNotificationService._();

  WebNotificationService._();

  bool _isSupported = false;
  bool _isInitialized = false;

  // Track processed notifications to prevent duplicates
  final Set<String> _processedNotifications = <String>{};

  // Firestore listener for real notifications
  StreamSubscription<QuerySnapshot>? _notificationListener;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (!kIsWeb) return;

    try {
      // Check if notifications are supported
      _isSupported = html.Notification.supported;
      print('🔔 Web notifications supported: $_isSupported');

      if (_isSupported) {
        // Request permission (this is non-blocking and user-friendly)
        final permission = await html.Notification.requestPermission();
        print('🔔 Web notification permission: $permission');

        if (permission == 'granted') {
          print('✅ Web notifications enabled!');
        } else {
          print('❌ Web notifications blocked: $permission');
        }
      }

      _isInitialized = true;

      // Start listening for real notifications from cloud function
      _startNotificationListener();
    } catch (e) {
      print('❌ Web notification initialization failed: $e');
    }
  }

  /// Show a notification for a new message
  void showMessageNotification({
    required String title,
    required String body,
    String? senderName,
    String? chatName,
  }) {
    if (!kIsWeb || !_isSupported || !_isInitialized) {
      print(
          '❌ Cannot show notification: kIsWeb=$kIsWeb, supported=$_isSupported, initialized=$_isInitialized');
      return;
    }

    try {
      // Check permission again
      if (html.Notification.permission != 'granted') {
        print(
            '❌ Notification permission not granted: ${html.Notification.permission}');
        return;
      }

      // Only show if tab is visible (user is actively using the app)
      if (html.document.hidden == true) {
        print('📱 Tab is hidden, skipping notification');
        return;
      }

      print('🔔 Showing notification: $title - $body');

      final notification = html.Notification(
        title,
        body: body,
        icon: '/favicon.png', // Use your app icon
        tag: 'linkedup-message', // Prevent duplicate notifications
      );

      // Play notification sound manually
      _playNotificationSound();

      // Auto-close after 5 seconds
      Future.delayed(Duration(seconds: 5), () {
        notification.close();
      });

      // Handle click - focus the tab
      notification.onClick.listen((_) {
        print('🔔 Notification clicked, focusing tab');
        // Focus the window/tab
        html.document.documentElement?.focus();
        notification.close();
      });

      // Handle errors
      notification.onError.listen((error) {
        print('❌ Notification error: $error');
      });
    } catch (e) {
      print('❌ Failed to show web notification: $e');
    }
  }

  /// Play notification sound
  void _playNotificationSound() {
    try {
      // Play the macOS Glass notification sound
      html.AudioElement()
        ..src = '/assets/audios/mac_os_glass.mp3'
        ..volume = 0.8
        ..play();

      print('🔊 Playing macOS Glass notification sound');
    } catch (e) {
      print('❌ Failed to play macOS Glass notification sound: $e');
    }
  }

  /// Update tab title with unread count
  void updateTabTitle(int unreadCount) {
    if (!kIsWeb) return;

    try {
      if (unreadCount > 0) {
        html.document.title = '($unreadCount) Lona';
      } else {
        html.document.title = 'Lona';
      }
    } catch (e) {
      print('Failed to update tab title: $e');
    }
  }

  /// Check if notifications are available
  bool get isAvailable => kIsWeb && _isSupported && _isInitialized;

  /// Get current permission status
  String get permissionStatus => html.Notification.permission ?? 'unknown';

  /// Request permission manually (useful for testing)
  Future<String> requestPermission() async {
    if (!kIsWeb || !_isSupported) return 'unsupported';

    try {
      final permission = await html.Notification.requestPermission();
      print('🔔 Permission requested: $permission');
      return permission;
    } catch (e) {
      print('❌ Failed to request permission: $e');
      return 'denied';
    }
  }

  /// Start listening for real notifications from cloud function
  void _startNotificationListener() {
    if (!kIsWeb || currentUserReference == null) return;

    try {
      print(
          '🔔 Starting web notification listener for user: ${currentUserReference?.path}');

      _notificationListener = FirebaseFirestore.instance
          .collection('ff_user_push_notifications')
          .where('user_refs', arrayContains: currentUserReference?.path ?? '')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots()
          .listen((snapshot) {
        _handleNotificationSnapshot(snapshot);
      }, onError: (error) {
        print('❌ Web notification listener error: $error');
      });

      print('✅ Web notification listener started');
    } catch (e) {
      print('❌ Failed to start web notification listener: $e');
    }
  }

  /// Handle notification snapshot from Firestore
  void _handleNotificationSnapshot(QuerySnapshot snapshot) {
    if (!kIsWeb || currentUserReference == null) return;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final docId = doc.id;

      // Skip if already processed
      if (_processedNotifications.contains(docId)) continue;

      // Skip if this is an old notification (older than 5 minutes)
      final timestamp = data['timestamp'] as Timestamp?;
      if (timestamp != null) {
        final now = Timestamp.now();
        final diff = now.seconds - timestamp.seconds;
        if (diff > 300) {
          // 5 minutes
          continue;
        }
      }

      // Extract notification data
      final title = data['notification_title'] as String? ?? 'New Message';
      final body =
          data['notification_text'] as String? ?? 'You have a new message';

      // Show web notification
      showMessageNotification(
        title: title,
        body: body,
        senderName: 'Contact',
        chatName: 'Chat',
      );

      // Mark as processed
      _processedNotifications.add(docId);

      print('🔔 Web notification processed: $title - $body');
    }
  }

  /// Dispose resources
  void dispose() {
    _notificationListener?.cancel();
    _notificationListener = null;
  }
}
