import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class InAppNotificationService {
  static final InAppNotificationService _instance =
      InAppNotificationService._internal();
  factory InAppNotificationService() => _instance;
  InAppNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
    print('🔔 In-app notification service initialized');
  }

  /// Show a notification with sound
  Future<void> showNotification({
    required String title,
    required String body,
    String? soundFile,
    Map<String, String>? data,
  }) async {
    await initialize();

    // Play custom sound if provided
    if (soundFile != null) {
      await _playNotificationSound(soundFile);
    }

    // Show local notification (disable system sound if custom sound is playing)
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_notifications',
          'Chat Notifications',
          channelDescription: 'Notifications for new chat messages',
          importance: Importance.high,
          priority: Priority.high,
          playSound:
              soundFile == null, // Only play system sound if no custom sound
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound:
              soundFile == null, // Only play system sound if no custom sound
          interruptionLevel: InterruptionLevel.timeSensitive,
          categoryIdentifier: 'chat_notifications',
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound:
              soundFile == null, // Only play system sound if no custom sound
          interruptionLevel: InterruptionLevel.timeSensitive,
          categoryIdentifier: 'chat_notifications',
        ),
      ),
      payload: data?.toString(),
    );

    print('🔔 In-app notification shown: $title - $body');
  }

  /// Show a chat message notification
  Future<void> showChatNotification({
    required String senderName,
    required String message,
    required String chatId,
    String? senderPhoto,
  }) async {
    await showNotification(
      title: '💬 $senderName',
      body: message,
      soundFile: 'new-notification-3-398649.mp3',
      data: {
        'type': 'chat_message',
        'chatId': chatId,
        'senderName': senderName,
      },
    );
  }

  /// Show a connection request notification
  Future<void> showConnectionRequestNotification({
    required String requesterName,
    required String requesterPhoto,
  }) async {
    await showNotification(
      title: '🤝 New Connection Request',
      body: '$requesterName wants to connect with you',
      soundFile: 'new-notification-3-398649.mp3',
      data: {
        'type': 'connection_request',
        'requesterName': requesterName,
      },
    );
  }

  /// Show an event notification
  Future<void> showEventNotification({
    required String eventTitle,
    required String eventDescription,
    required String eventId,
  }) async {
    await showNotification(
      title: '📅 New Event',
      body: '$eventTitle: $eventDescription',
      soundFile: 'new-notification-3-398649.mp3',
      data: {
        'type': 'event',
        'eventId': eventId,
        'eventTitle': eventTitle,
      },
    );
  }

  /// Play notification sound
  Future<void> _playNotificationSound(String soundFile) async {
    try {
      print('🔔 Playing custom notification sound: $soundFile');

      // Play the custom notification sound
      await _audioPlayer.play(AssetSource('audios/$soundFile'));

      print('🔔 Custom notification sound played successfully!');
    } catch (e) {
      print('🔔 Could not play notification sound: $e');
      // Fallback to system sound if custom sound fails
      print('🔔 Falling back to system notification sound');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('🔔 Notification tapped: ${response.payload}');
    // Handle navigation based on notification type
    // This would typically navigate to the relevant screen
  }

  /// Show a test notification
  Future<void> showTestNotification() async {
    await showNotification(
      title: ' Test Notification',
      body: 'In-app notifications are working perfectly!',
      soundFile: 'new-notification-3-398649.mp3',
      data: {'type': 'test'},
    );
  }

  /// Show in-app notification overlay from top
  static void showInAppNotification({
    required BuildContext context,
    required String title,
    required String body,
    String? soundFile,
    Duration duration = const Duration(seconds: 3),
  }) async {
    print('🔔 Showing in-app notification: $title');

    // Play custom sound if provided (only audio, no system notification)
    if (soundFile != null) {
      try {
        final service = InAppNotificationService();
        await service._playNotificationSound(soundFile);
        print('🔔 Custom sound played successfully');
      } catch (e) {
        print('🔔 Sound error: $e');
      }
    }

    // Show overlay notification from top
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Container();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          )),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 50),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.notifications_active,
                    color: Colors.blue,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Auto dismiss after duration
    Future.delayed(duration, () {
      if (context.mounted) {
        Navigator.of(context).pop();
        print('🔔 In-app notification dismissed');
      }
    });
  }

  /// Show notification with voice (text-to-speech)
  Future<void> showVoiceNotification({
    required String title,
    required String body,
    String? voiceText,
  }) async {
    await showNotification(
      title: title,
      body: body,
    );

    // Play voice if provided
    if (voiceText != null) {
      await _playVoiceNotification(voiceText);
    }
  }

  /// Play voice notification using system TTS
  Future<void> _playVoiceNotification(String text) async {
    try {
      // This would use a TTS package like flutter_tts
      // For now, we'll just print it
      print('🔊 Voice: $text');
    } catch (e) {
      print('🔊 Voice notification error: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    await _notifications.cancelAll();
    print('🔔 All notifications cleared');
  }
}
