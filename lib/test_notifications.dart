import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class TestNotificationsPage extends StatefulWidget {
  const TestNotificationsPage({super.key});

  @override
  _TestNotificationsPageState createState() => _TestNotificationsPageState();
}

class _TestNotificationsPageState extends State<TestNotificationsPage> {
  String? _fcmToken;
  String _status = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      // Request permission
      NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      setState(() {
        _status = 'Permission status: ${settings.authorizationStatus}';
      });

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // For macOS, wait for APNS token first
        if (Theme.of(context).platform == TargetPlatform.macOS) {
          setState(() {
            _status = 'Waiting for APNS token...';
          });

          // Wait a bit for APNS token to be available
          await Future.delayed(const Duration(seconds: 3));

          try {
            String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
            print('APNS Token: $apnsToken');
            setState(() {
              _status = 'APNS token received, getting FCM token...';
            });
          } catch (e) {
            setState(() {
              _status = 'APNS token error: $e';
            });
            return;
          }
        }

        // Get FCM token
        String? token = await FirebaseMessaging.instance.getToken();
        setState(() {
          _fcmToken = token;
          _status = 'Notifications enabled! Token received.';
        });

        print('FCM Token: $token');

        // Listen for foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print('Received foreground message: ${message.notification?.title}');
          setState(() {
            _status = 'Received: ${message.notification?.title ?? 'No title'}';
          });
        });

        // Listen for token refresh
        FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
          print('Token refreshed: $token');
          setState(() {
            _fcmToken = token;
          });
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      print('Error initializing notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Push Notifications'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_status),
            const SizedBox(height: 20),
            const Text(
              'FCM Token:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _fcmToken ?? 'No token yet',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Instructions:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Copy the FCM token above\n'
              '2. Go to Firebase Console > Cloud Messaging\n'
              '3. Click "Send your first message"\n'
              '4. Enter title and body\n'
              '5. Click "Send test message"\n'
              '6. Paste the token and send',
            ),
          ],
        ),
      ),
    );
  }
}
