import 'dart:html' as html;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/utils/qurio_embedded.dart';
import '/utils/qurio_bridge.dart';

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
  StreamSubscription<QuerySnapshot>? _notificationListenerEq;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (!kIsWeb) return;

    try {
      // When embedded in Qurio, notifications are routed through Qurio's Tauri API.
      // Skip browser Notification permission check (it's always blocked in iframes).
      if (QurioEmbedded.isEmbeddedInQurio) {
        print('🔔 [Qurio] Skipping browser notification permission (using Tauri)');
        _isSupported = true;
        _isInitialized = true;
        // Try to start listener now (may skip if not logged in yet)
        _startNotificationListener();
        // Also listen for auth state changes to restart when session is restored
        _listenForAuthChanges();
        return;
      }

      // Standalone web: use browser's Notification API
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
    bool forceShow = false, // Force show even when tab is hidden (for FCM)
  }) {
    if (!kIsWeb || !_isSupported || !_isInitialized) {
      print(
          '❌ Cannot show notification: kIsWeb=$kIsWeb, supported=$_isSupported, initialized=$_isInitialized');
      return;
    }

    try {
      // When embedded in Qurio, delegate to Qurio's Tauri notification system.
      // This ensures clicking the notification opens the Qurio window (not native Lona app).
      if (QurioEmbedded.isEmbeddedInQurio) {
        print('🔔 [Qurio] Delegating notification to Qurio: $title - $body');
        QurioBridge.sendNotification(title: title, body: body);
        _playNotificationSound();
        return;
      }

      // Standalone web: use browser's Notification API
      // Check permission again
      if (html.Notification.permission != 'granted') {
        print(
            '❌ Notification permission not granted: ${html.Notification.permission}');
        return;
      }

      // Only show if tab is visible (user is actively using the app)
      // Exception: forceShow=true for FCM notifications (they should show regardless)
      if (!forceShow && html.document.hidden == true) {
        print('📱 Tab is hidden, skipping notification');
        return;
      }

      print('🔔 Showing notification: $title - $body');

      // Create notification - Dart's Notification API supports title, body, and icon
      // These notifications will appear in macOS Notification Center automatically
      final notification = html.Notification(
        title,
        body: body,
        icon: '/app_launcher_icon.png', // Use your app logo
      );

      // Play notification sound manually
      _playNotificationSound();

      // Don't auto-close - let macOS handle it naturally (stays in Notification Center)
      // macOS will auto-dismiss it after user sees it or after system timeout
      // This allows it to appear in the Notification Center

      // Handle click - focus the tab and handle navigation
      notification.onClick.listen((_) {
        print('🔔 Notification clicked, focusing tab');
        // Focus the document element to bring tab to front
        html.document.documentElement?.focus();
        notification.close();
      });

      // Handle errors (using stream instead of setter)
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
      final audio = html.AudioElement();
      audio.volume = 0.8;

      // Use simple path from web/ directory (copied during build)
      audio.src = '/mac_os_glass.mp3';

      audio.play().catchError((e) {
        print('❌ Failed to play notification sound: $e');
      });

      print('🔊 Attempting to play macOS Glass notification sound');
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
    if (!kIsWeb || !html.Notification.supported) return 'unsupported';

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
    if (!kIsWeb) {
      print('⚠️ Cannot start notification listener: not on web');
      return;
    }
    if (currentUserReference == null) {
      print(
          '⚠️ Cannot start notification listener yet: currentUserReference is null (user not logged in)');
      return;
    }

    try {
      // Dispose existing listeners if any
      _notificationListener?.cancel();
      _notificationListenerEq?.cancel();

      print(
          '🔔 Starting web notification listener for user: ${currentUserReference?.path}');

      // Listener 1: when user_refs is an ARRAY of user paths
      _notificationListener = FirebaseFirestore.instance
          .collection('ff_user_push_notifications')
          .where('user_refs', arrayContains: currentUserReference?.path ?? '')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots()
          .listen((snapshot) {
        print(
            '🔔 [arrayContains] Received ${snapshot.docs.length} notifications');
        _handleNotificationSnapshot(snapshot);
      }, onError: (error) {
        print('❌ Web notification listener (arrayContains) error: $error');
      });

      // Listener 2: when user_refs is a STRING equal to the user path
      _notificationListenerEq = FirebaseFirestore.instance
          .collection('ff_user_push_notifications')
          .where('user_refs', isEqualTo: currentUserReference?.path ?? '')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots()
          .listen((snapshot) {
        print('🔔 [isEqualTo] Received ${snapshot.docs.length} notifications');
        _handleNotificationSnapshot(snapshot);
      }, onError: (error) {
        print('❌ Web notification listener (isEqualTo) error: $error');
      });

      print('✅ Web notification listeners started');
    } catch (e) {
      print('❌ Failed to start web notification listener: $e');
    }
  }

  /// Restart notification listener (call this after user logs in)
  void restartNotificationListener() {
    if (!kIsWeb || !_isInitialized) return;

    print('🔄 Restarting notification listener...');
    _processedNotifications.clear(); // Clear processed notifications
    _startNotificationListener();
  }

  /// Listen for Firebase auth state changes.
  /// When a persisted session is restored (e.g. after iframe reload),
  /// automatically start the Firestore notification listener.
  StreamSubscription? _authSubscription;
  void _listenForAuthChanges() {
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && _notificationListener == null) {
        print('🔔 [AuthChange] User signed in: ${user.email ?? user.uid}, starting notification listener');
        // Small delay to ensure currentUserReference is populated
        Future.delayed(const Duration(seconds: 1), () {
          _startNotificationListener();
        });
      }
    });
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
    _notificationListenerEq?.cancel();
    _notificationListenerEq = null;
  }
}
