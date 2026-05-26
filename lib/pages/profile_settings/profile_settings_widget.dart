import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/delete_account_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/user_summary/user_summary_widget.dart';
import '/app_state.dart';
import 'profile_settings_model.dart';
export 'profile_settings_model.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class ProfileSettingsWidget extends StatefulWidget {
  const ProfileSettingsWidget({Key? key, this.initialTab}) : super(key: key);

  final SettingsTab? initialTab;

  @override
  _ProfileSettingsWidgetState createState() => _ProfileSettingsWidgetState();
}

class _ProfileSettingsWidgetState extends State<ProfileSettingsWidget>
    with WidgetsBindingObserver {
  late ProfileSettingsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Notification state
  bool _notificationsEnabled = false;
  bool _isLoadingNotificationStatus = true;
  bool _waitingForSystemPermission = false;
  SettingsTab? _lastSelectedTab;

  final Map<String, String> _translationLanguages = {
    'system': 'System Language (Default)',
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'zh-cn': 'Chinese (Simplified)',
    'zh-tw': 'Chinese (Traditional)',
    'ja': 'Japanese',
    'ko': 'Korean',
    'hi': 'Hindi',
    'ar': 'Arabic',
  };

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileSettingsModel());
    _model.initState(context);
    if (widget.initialTab != null) {
      _model.selectedTab = widget.initialTab!;
    }
    WidgetsBinding.instance.addObserver(this);
    _loadNotificationStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _model.dispose();
    super.dispose();
  }

  // Re-check notification permission when returning from System Settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForSystemPermission) {
      _waitingForSystemPermission = false;
      _recheckSystemPermission();
    }
  }

  Future<void> _recheckSystemPermission() async {
    if (kIsWeb || !Platform.isMacOS) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      final isGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (isGranted) {
        // User granted permission in System Settings!
        setState(() {
          _notificationsEnabled = true;
        });
        final tokenDocRef = await _getCurrentDeviceTokenDoc();
        if (tokenDocRef != null) {
          await tokenDocRef.update({
            'notifications_enabled': true,
          });
          print('✅ Notification enabled for this device after System Settings grant');
        }
      } else {
        // User did NOT grant permission, keep toggle OFF
        setState(() {
          _notificationsEnabled = false;
        });
        print('⚠️ User returned from Settings without granting permission');
      }
    } catch (e) {
      print('Error rechecking notification permission: $e');
      setState(() {
        _notificationsEnabled = false;
      });
    }
  }

  // Override didUpdateWidget to reload notification status when tab changes
  @override
  void didUpdateWidget(ProfileSettingsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload notification status when switching to notifications tab
    if (_model.selectedTab == SettingsTab.notifications) {
      _loadNotificationStatus();
    }
  }

  bool get isDesktop => kIsWeb || (!kIsWeb && Platform.isMacOS);

  // Build help item widget
  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: Color(0xFF0077B5),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 20,
                color: Color(0xFF999999),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build keyboard shortcut option widget
  Widget _buildKeyboardShortcutOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Color(0xFFE3F2FD) : Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Color(0xFF0077B5) : Color(0xFFE5E7EB),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Color(0xFF0077B5) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? Color(0xFF0077B5) : Color(0xFF999999),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? Color(0xFF0077B5) : Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 13,
                        color: Color(0xFF666666),
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
  }

  // Show Privacy Policy
  void _showPrivacyPolicy(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Privacy Policy'),
        content: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Last updated: January 2024\n\n'
              'At Lona Club, we are committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your personal information.\n\n'
              'Information We Collect:\n'
              '• Account information (name, email, phone number)\n'
              '• Messages and communications\n'
              '• Device information and usage data\n\n'
              'How We Use Your Information:\n'
              '• To provide and improve our services\n'
              '• To communicate with you\n'
              '• To ensure security and prevent fraud\n\n'
              'Data Security:\n'
              'All your data is encrypted and stored securely. We use industry-standard security measures to protect your information.\n\n'
              'Your Rights:\n'
              'You have the right to access, update, or delete your personal information at any time through your account settings.',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 14,
                color: Color(0xFF1A1A1A),
                height: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // Show Customer Support
  void _showCustomerSupport(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Customer Support'),
        content: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'We\'re here to help!',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Contact Options:',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Email: support@lonaclub.com\n'
                  'Phone: +1 (555) 123-4567\n'
                  'Hours: Monday - Friday, 9 AM - 6 PM EST\n\n'
                  'For urgent issues, please email us and we\'ll respond within 24 hours.',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 14,
                    color: Color(0xFF666666),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Frequently Asked Questions:',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '• How do I reset my password?\n'
                  '• How do I delete my account?\n'
                  '• How do I report a problem?\n\n'
                  'Visit our help center for more answers.',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 14,
                    color: Color(0xFF666666),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // Helper: get current device's FCM token document reference
  Future<DocumentReference?> _getCurrentDeviceTokenDoc() async {
    if (currentUserReference == null) return null;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return null;

      final fcmTokensRef = currentUserReference!.collection('fcm_tokens');
      final query = await fcmTokensRef
          .where('fcm_token', isEqualTo: token)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.reference;
      }
    } catch (e) {
      print('Error finding device token doc: $e');
    }
    return null;
  }

  // Load notification status from current device's FCM token document
  Future<void> _loadNotificationStatus() async {
    try {
      final tokenDocRef = await _getCurrentDeviceTokenDoc();
      if (tokenDocRef != null) {
        final tokenDoc = await tokenDocRef.get();
        final data = tokenDoc.data() as Map<String, dynamic>?;
        setState(() {
          // Default to true if field doesn't exist (backward compatibility)
          _notificationsEnabled = data?['notifications_enabled'] ?? true;
          _isLoadingNotificationStatus = false;
        });
      } else {
        // No token doc found — likely no FCM token yet, default to enabled
        setState(() {
          _notificationsEnabled = true;
          _isLoadingNotificationStatus = false;
        });
      }
    } catch (e) {
      print('Error loading notification status: $e');
      setState(() {
        _isLoadingNotificationStatus = false;
      });
    }
  }

  // Handle notification toggle — update current device's FCM token doc
  Future<void> _handleNotificationToggle(bool newValue) async {
    if (!newValue) {
      // Turning OFF: update current device's token doc
      setState(() {
        _notificationsEnabled = false;
      });
      try {
        final tokenDocRef = await _getCurrentDeviceTokenDoc();
        if (tokenDocRef != null) {
          await tokenDocRef.update({
            'notifications_enabled': false,
          });
          print('✅ Notifications disabled for this device');
        }
      } catch (e) {
        print('Error disabling notifications: $e');
      }
      return;
    }

    // Turning ON: check macOS system permission first
    if (!kIsWeb && Platform.isMacOS) {
      bool systemPermissionGranted = false;
      try {
        final messaging = FirebaseMessaging.instance;
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        systemPermissionGranted =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      } catch (e) {
        print('⚠️ System notification permission not granted: $e');
        systemPermissionGranted = false;
      }

      if (!systemPermissionGranted) {
        // Permission denied — open System Settings, DON'T flip the toggle
        _waitingForSystemPermission = true;
        try {
          await Process.run('open', [
            'x-apple.systempreferences:com.apple.preference.notifications'
          ]);
        } catch (_) {
          try {
            await Process.run('open', [
              '/System/Library/PreferencePanes/Notifications.prefPane'
            ]);
          } catch (_) {
            await Process.run('open', ['-b', 'com.apple.systempreferences']);
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please enable notifications for Lona Club in System Settings',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Color(0xFF0077B5),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }

    // System permission granted — turn ON for this device
    setState(() {
      _notificationsEnabled = true;
    });
    try {
      final tokenDocRef = await _getCurrentDeviceTokenDoc();
      if (tokenDocRef != null) {
        await tokenDocRef.update({
          'notifications_enabled': true,
        });
        print('✅ Notifications enabled for this device');
      }
    } catch (e) {
      print('Error enabling notifications: $e');
      setState(() {
        _notificationsEnabled = false;
      });
    }
  }

  Widget _buildSidebarItem({
    required SettingsTab tab,
    required String title,
    required IconData icon,
    required bool isSelected,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _model.selectedTab = tab;
            });
            // Reload notification status when switching to notifications tab
            if (tab == SettingsTab.notifications) {
              _loadNotificationStatus();
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Color(0xFFE3F2FD) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Color(0xFF0077B5) : Color(0xFF666666),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Color(0xFF0077B5) : Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTabTitle(SettingsTab tab) {
    switch (tab) {
      case SettingsTab.yourProfile:
        return 'Your Profile';
      case SettingsTab.notifications:
        return 'Notifications';
      case SettingsTab.preferences:
        return 'Preferences';
      case SettingsTab.apiKeys:
        return 'API Keys';
      case SettingsTab.helpFeedback:
        return 'Help & Feedback';
      case SettingsTab.logout:
        return 'Logout';
    }
  }

  String _generateApiKey() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    final key = List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
    return 'sk_personal_$key';
  }

  String _generateSystemKey() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    final key = List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
    return 'sk_system_$key';
  }

  Future<void> _showGenerateKeyDialog() async {
    _model.apiKeyNameController?.clear();
    final name = await showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 400,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.lock_shield_fill, size: 22, color: Color(0xFF0077B5)),
                      SizedBox(width: 10),
                      Text(
                        'Generate New API Key',
                        style: TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Give your key a descriptive name so you can identify it later.',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 13,
                      color: Color(0xFF666666),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Key Name',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  SizedBox(height: 6),
                  CupertinoTextField(
                    controller: _model.apiKeyNameController,
                    placeholder: 'e.g. My Qurio Agent',
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Color(0xFFE5E7EB)),
                    ),
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          borderRadius: BorderRadius.circular(10),
                          color: Color(0xFFF0F0F0),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF333333),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          color: Color(0xFF0077B5),
                          borderRadius: BorderRadius.circular(10),
                          child: Text(
                            'Generate',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx, _model.apiKeyNameController?.text ?? 'Untitled'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (name == null || name.trim().isEmpty) {
      debugPrint('❌ API Key generation cancelled or empty name');
      return;
    }

    debugPrint('✅ Generating API key with name: ${name.trim()}');
    debugPrint('✅ currentUserUid: $currentUserUid');

    final rawKey = _generateApiKey();
    final keyHash = sha256.convert(utf8.encode(rawKey)).toString();

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid)
          .collection('api_keys')
          .add({
        'key_hash': keyHash,
        'key_value': rawKey,
        'key_preview': '${rawKey.substring(0, 16)}...${rawKey.substring(rawKey.length - 4)}',
        'name': name.trim(),
        'created_at': FieldValue.serverTimestamp(),
        'last_used_at': null,
        'permissions': ['read', 'write'],
        'is_active': true,
      });
      // Write to top-level index for O(1) lookup by Cloud Functions
      await FirebaseFirestore.instance
          .collection('api_key_hashes')
          .doc(keyHash)
          .set({
        'uid': currentUserUid,
        'key_doc_id': docRef.id,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ API key written to Firestore successfully');
    } catch (e) {
      debugPrint('❌ Firestore write error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save API key: $e')),
      );
      return;
    }

    if (!mounted) return;

    // Show the key one time only — styled dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 480,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.checkmark_seal_fill, size: 22, color: Color(0xFF2E7D32)),
                      SizedBox(width: 10),
                      Text(
                        'API Key Generated',
                        style: TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFFFFCC80)),
                    ),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 16, color: Color(0xFFF57C00)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Copy this key now. It will not be shown again.',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Color(0xFFE5E7EB)),
                    ),
                    child: SelectableText(
                      rawKey,
                      style: TextStyle(
                        fontFamily: 'SF Mono, Courier',
                        fontSize: 13,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      color: Color(0xFF0077B5),
                      borderRadius: BorderRadius.circular(10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.doc_on_clipboard, size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Copy & Close',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: rawKey));
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showGenerateSystemKeyDialog() async {
    _model.apiKeyNameController?.clear();
    final name = await showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 400,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.bolt_circle_fill, size: 22, color: Color(0xFF0077B5)),
                      SizedBox(width: 10),
                      Text(
                        'Generate System Key',
                        style: TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'System keys send messages as "Qurio AI" bot instead of your personal account.',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 13,
                      color: Color(0xFF666666),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Key Name',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  SizedBox(height: 6),
                  CupertinoTextField(
                    controller: _model.apiKeyNameController,
                    placeholder: 'e.g. Qurio Bot Key',
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Color(0xFFE5E7EB)),
                    ),
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          borderRadius: BorderRadius.circular(10),
                          color: Color(0xFFF0F0F0),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF333333),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          color: Color(0xFF0077B5),
                          borderRadius: BorderRadius.circular(10),
                          child: Text(
                            'Generate',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx, _model.apiKeyNameController?.text ?? 'Untitled'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (name == null || name.trim().isEmpty) return;

    final rawKey = _generateSystemKey();
    final keyHash = sha256.convert(utf8.encode(rawKey)).toString();

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid)
          .collection('api_keys')
          .add({
        'key_hash': keyHash,
        'key_value': rawKey,
        'key_preview': '${rawKey.substring(0, 14)}...${rawKey.substring(rawKey.length - 4)}',
        'name': name.trim(),
        'created_at': FieldValue.serverTimestamp(),
        'last_used_at': null,
        'permissions': ['read', 'write'],
        'is_active': true,
        'key_type': 'system',
      });
      await FirebaseFirestore.instance
          .collection('api_key_hashes')
          .doc(keyHash)
          .set({
        'uid': currentUserUid,
        'key_doc_id': docRef.id,
        'is_active': true,
        'key_type': 'system',
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save system key: $e')),
      );
      return;
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 480,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.checkmark_seal_fill, size: 22, color: Color(0xFF2E7D32)),
                      SizedBox(width: 10),
                      Text(
                        'System Key Generated',
                        style: TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFFFFCC80)),
                    ),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 16, color: Color(0xFFF57C00)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Copy this key now. Messages sent via this key will appear from "Qurio AI".',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Color(0xFFE5E7EB)),
                    ),
                    child: SelectableText(
                      rawKey,
                      style: TextStyle(
                        fontFamily: 'SF Mono, Courier',
                        fontSize: 13,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      color: Color(0xFF0077B5),
                      borderRadius: BorderRadius.circular(10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.doc_on_clipboard, size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Copy & Close',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: rawKey));
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildApiKeysContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.lock_shield_fill,
                size: 32,
                color: Color(0xFF0077B5),
              ),
              SizedBox(width: 12),
              Text(
                'API Keys',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Manage API keys for AI integrations. Personal keys send as you; System keys send as Qurio AI.',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 14,
              color: Color(0xFF666666),
              height: 1.4,
            ),
          ),
          SizedBox(height: 28),

          // ── System Key Section ──
          Row(
            children: [
              Icon(CupertinoIcons.bolt_circle_fill, size: 22, color: Color(0xFF0077B5)),
              SizedBox(width: 8),
              Text(
                'System Key',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'Messages sent via system key appear from "Qurio AI" instead of your personal account.',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 13,
              color: Color(0xFF666666),
              height: 1.4,
            ),
          ),
          SizedBox(height: 12),

          // System key info card
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFBBDEFB), width: 1),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.person_crop_circle_badge_checkmark, size: 18, color: Color(0xFF0077B5)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Qurio AI will appear as a separate bot account in chats, not as you.',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 13,
                      color: Color(0xFF1A1A1A),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14),

          // Generate System Key button
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: EdgeInsets.symmetric(vertical: 14),
              color: Color(0xFF0077B5),
              borderRadius: BorderRadius.circular(12),
              onPressed: _showGenerateSystemKeyDialog,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.plus_circle_fill, size: 20, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Generate System Key',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 14),

          // System keys list
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserUid)
                .collection('api_keys')
                .orderBy('created_at', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CupertinoActivityIndicator());
              }

              final docs = (snapshot.data?.docs ?? [])
                  .where((d) => (d.data() as Map<String, dynamic>)['key_type'] == 'system')
                  .toList();

              if (docs.isEmpty) {
                return Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFE5E7EB), width: 1),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(CupertinoIcons.bolt, size: 28, color: Color(0xFFCCCCCC)),
                        SizedBox(height: 8),
                        Text(
                          'No system keys yet',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFE5E7EB), width: 1),
                ),
                child: Column(
                  children: docs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final doc = entry.value;
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Untitled';
                    final preview = data['key_preview'] ?? '****';
                    final fullKey = data['key_value'] as String?;
                    final isActive = data['is_active'] ?? true;
                    final createdAt = data['created_at'] as Timestamp?;
                    final keyHash = data['key_hash'] as String?;

                    return Column(
                      children: [
                        if (index > 0)
                          Divider(height: 1, color: Color(0xFFE5E7EB)),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              barrierColor: Colors.black54,
                              builder: (ctx) => Center(
                                child: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    width: 400,
                                    padding: EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 24,
                                          offset: Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(CupertinoIcons.bolt_fill, size: 20, color: Color(0xFF0077B5)),
                                            SizedBox(width: 10),
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontFamily: 'SF Pro Display',
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1A1A1A),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isActive ? Color(0xFFE8F5E9) : Color(0xFFFFEBEE),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isActive ? 'Active' : 'Revoked',
                                                style: TextStyle(
                                                  fontFamily: 'SF Pro Display',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isActive ? Color(0xFF2E7D32) : Color(0xFFC62828),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 16),
                                        Text('System Key', style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
                                        SizedBox(height: 6),
                                        Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Color(0xFFF5F5F5),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Color(0xFFE5E7EB)),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: SelectableText(
                                                  fullKey ?? preview,
                                                  style: TextStyle(fontFamily: 'SF Mono, Courier', fontSize: 13, color: Color(0xFF1A1A1A)),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              CupertinoButton(
                                                padding: EdgeInsets.zero,
                                                minSize: 28,
                                                onPressed: () {
                                                  Clipboard.setData(ClipboardData(text: fullKey ?? preview));
                                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                                    SnackBar(
                                                      content: Text(fullKey != null ? 'System key copied!' : 'Key preview copied'),
                                                      duration: Duration(seconds: 2),
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
                                                  );
                                                },
                                                child: Icon(CupertinoIcons.doc_on_clipboard, size: 16, color: Color(0xFF0077B5)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 12),
                                        Text('Created', style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
                                        SizedBox(height: 4),
                                        Text(
                                          createdAt != null ? DateFormat('MMM d, yyyy \'at\' h:mm a').format(createdAt.toDate()) : 'Unknown',
                                          style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 13, color: Color(0xFF666666)),
                                        ),
                                        SizedBox(height: 20),
                                        Row(
                                          children: [
                                            if (isActive && keyHash != null)
                                              Expanded(
                                                child: CupertinoButton(
                                                  padding: EdgeInsets.symmetric(vertical: 12),
                                                  borderRadius: BorderRadius.circular(10),
                                                  color: Color(0xFFFFEBEE),
                                                  child: Text(
                                                    'Revoke Key',
                                                    style: TextStyle(
                                                      fontFamily: 'SF Pro Display',
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFFC62828),
                                                    ),
                                                  ),
                                                  onPressed: () async {
                                                    Navigator.pop(ctx);
                                                    final confirm = await showCupertinoDialog<bool>(
                                                      context: context,
                                                      builder: (ctx2) => CupertinoAlertDialog(
                                                        title: Text('Revoke "$name"?'),
                                                        content: Text('This system key will stop working immediately.'),
                                                        actions: [
                                                          CupertinoDialogAction(
                                                            child: Text('Cancel'),
                                                            onPressed: () => Navigator.pop(ctx2, false),
                                                          ),
                                                          CupertinoDialogAction(
                                                            isDestructiveAction: true,
                                                            child: Text('Revoke'),
                                                            onPressed: () => Navigator.pop(ctx2, true),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    if (confirm == true) {
                                                      await doc.reference.update({'is_active': false});
                                                      await FirebaseFirestore.instance.collection('api_key_hashes').doc(keyHash).update({'is_active': false});
                                                    }
                                                  },
                                                ),
                                              ),
                                            if (isActive && keyHash != null)
                                              SizedBox(width: 12),
                                            Expanded(
                                              child: CupertinoButton(
                                                padding: EdgeInsets.symmetric(vertical: 12),
                                                borderRadius: BorderRadius.circular(10),
                                                color: Color(0xFFF0F0F0),
                                                child: Text(
                                                  'Close',
                                                  style: TextStyle(
                                                    fontFamily: 'SF Pro Display',
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF333333),
                                                  ),
                                                ),
                                                onPressed: () => Navigator.pop(ctx),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isActive ? Color(0xFFE3F2FD) : Color(0xFFFBE9E7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    CupertinoIcons.bolt_fill,
                                    size: 16,
                                    color: isActive ? Color(0xFF0077B5) : Color(0xFFBF360C),
                                  ),
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontFamily: 'SF Pro Display',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1A1A1A),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isActive ? Color(0xFFE8F5E9) : Color(0xFFFFEBEE),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isActive ? 'Active' : 'Revoked',
                                              style: TextStyle(
                                                fontFamily: 'SF Pro Display',
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isActive ? Color(0xFF2E7D32) : Color(0xFFC62828),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        preview,
                                        style: TextStyle(
                                          fontFamily: 'SF Mono, Courier',
                                          fontSize: 12,
                                          color: Color(0xFF888888),
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Created ${createdAt != null ? DateFormat('MMM d, yyyy').format(createdAt.toDate()) : 'Unknown'}',
                                        style: TextStyle(
                                          fontFamily: 'SF Pro Display',
                                          fontSize: 12,
                                          color: Color(0xFFBBBBBB),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isActive && keyHash != null)
                                  CupertinoButton(
                                    padding: EdgeInsets.all(8),
                                    minSize: 32,
                                    onPressed: () async {
                                      final confirm = await showCupertinoDialog<bool>(
                                        context: context,
                                        builder: (ctx) => CupertinoAlertDialog(
                                          title: Text('Revoke "$name"?'),
                                          content: Text('This system key will stop working immediately.'),
                                          actions: [
                                            CupertinoDialogAction(
                                              child: Text('Cancel'),
                                              onPressed: () => Navigator.pop(ctx, false),
                                            ),
                                            CupertinoDialogAction(
                                              isDestructiveAction: true,
                                              child: Text('Revoke'),
                                              onPressed: () => Navigator.pop(ctx, true),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await doc.reference.update({'is_active': false});
                                        await FirebaseFirestore.instance.collection('api_key_hashes').doc(keyHash).update({'is_active': false});
                                      }
                                    },
                                    child: Icon(CupertinoIcons.xmark_circle, size: 20, color: Color(0xFFCC3333)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          ),

          SizedBox(height: 32),
          Divider(color: Color(0xFFE5E7EB)),
          SizedBox(height: 24),

          // ── Personal Key Section (existing) ──
          Row(
            children: [
              Icon(CupertinoIcons.person_crop_circle_fill, size: 22, color: Color(0xFF0077B5)),
              SizedBox(width: 8),
              Text(
                'Personal Keys',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'Messages sent via personal keys appear from your own account, tagged "via Qurio AI".',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 13,
              color: Color(0xFF666666),
              height: 1.4,
            ),
          ),
          SizedBox(height: 16),

          // Info card
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFBBDEFB), width: 1),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.info_circle_fill, size: 20, color: Color(0xFF0077B5)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your API key allows AI to access only chats you are a member of. Messages sent via API will be tagged "via Qurio AI".',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 13,
                      color: Color(0xFF1A1A1A),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),

          // Generate Key button
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: EdgeInsets.symmetric(vertical: 14),
              color: Color(0xFF0077B5),
              borderRadius: BorderRadius.circular(12),
              onPressed: _showGenerateKeyDialog,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.plus_circle_fill, size: 20, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Generate New API Key',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),

          // Existing keys list
          Text(
            'Your Keys',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Manage your existing API keys',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
          SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserUid)
                .collection('api_keys')
                .orderBy('created_at', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CupertinoActivityIndicator());
              }

              final docs = (snapshot.data?.docs ?? [])
                  .where((d) => (d.data() as Map<String, dynamic>)['key_type'] != 'system')
                  .toList();

              if (docs.isEmpty) {
                return Container(
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFE5E7EB), width: 1),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(CupertinoIcons.lock_open, size: 32, color: Color(0xFFCCCCCC)),
                        SizedBox(height: 12),
                        Text(
                          'No API keys yet',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF999999),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Generate your first key to get started with AI integrations.',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 13,
                            color: Color(0xFFBBBBBB),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFE5E7EB), width: 1),
                ),
                child: Column(
                  children: docs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final doc = entry.value;
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Untitled';
                    final preview = data['key_preview'] ?? '****';
                    final fullKey = data['key_value'] as String?;
                    final isActive = data['is_active'] ?? true;
                    final createdAt = data['created_at'] as Timestamp?;
                    final lastUsed = data['last_used_at'] as Timestamp?;

                    return Column(
                      children: [
                        if (index > 0)
                          Divider(height: 1, color: Color(0xFFE5E7EB)),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              barrierColor: Colors.black54,
                              builder: (ctx) => Center(
                                child: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    width: 400,
                                    padding: EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 24,
                                          offset: Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(CupertinoIcons.lock_fill, size: 20, color: Color(0xFF0077B5)),
                                            SizedBox(width: 10),
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontFamily: 'SF Pro Display',
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1A1A1A),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isActive ? Color(0xFFE8F5E9) : Color(0xFFFFEBEE),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isActive ? 'Active' : 'Revoked',
                                                style: TextStyle(
                                                  fontFamily: 'SF Pro Display',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isActive ? Color(0xFF2E7D32) : Color(0xFFC62828),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 16),
                                        Text('API Key', style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
                                        SizedBox(height: 6),
                                        Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Color(0xFFF5F5F5),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Color(0xFFE5E7EB)),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: SelectableText(
                                                  fullKey ?? preview,
                                                  style: TextStyle(fontFamily: 'SF Mono, Courier', fontSize: 13, color: Color(0xFF1A1A1A)),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              CupertinoButton(
                                                padding: EdgeInsets.zero,
                                                minSize: 28,
                                                onPressed: () {
                                                  Clipboard.setData(ClipboardData(text: fullKey ?? preview));
                                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                                    SnackBar(
                                                      content: Text(fullKey != null ? 'API key copied!' : 'Key preview copied'),
                                                      duration: Duration(seconds: 2),
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
                                                  );
                                                },
                                                child: Icon(CupertinoIcons.doc_on_clipboard, size: 16, color: Color(0xFF0077B5)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 12),
                                        Text('Created', style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
                                        SizedBox(height: 4),
                                        Text(
                                          createdAt != null ? DateFormat('MMM d, yyyy h:mm a').format(createdAt.toDate()) : 'Unknown',
                                          style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 14, color: Color(0xFF666666)),
                                        ),
                                        if (lastUsed != null) ...[
                                          SizedBox(height: 12),
                                          Text('Last Used', style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
                                          SizedBox(height: 4),
                                          Text(
                                            DateFormat('MMM d, yyyy h:mm a').format(lastUsed.toDate()),
                                            style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 14, color: Color(0xFF666666)),
                                          ),
                                        ],
                                        SizedBox(height: 12),
                                        Text('Permissions', style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
                                        SizedBox(height: 4),
                                        Text(
                                          (data['permissions'] as List<dynamic>?)?.join(', ') ?? 'read, write',
                                          style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 14, color: Color(0xFF666666)),
                                        ),
                                        SizedBox(height: 20),
                                        SizedBox(
                                          width: double.infinity,
                                          child: CupertinoButton(
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                            color: Color(0xFFF0F0F0),
                                            borderRadius: BorderRadius.circular(10),
                                            child: Text('Close', style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF333333))),
                                            onPressed: () => Navigator.pop(ctx),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isActive ? Color(0xFFE3F2FD) : Color(0xFFFBE9E7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.lock_fill,
                                      size: 16,
                                      color: isActive ? Color(0xFF0077B5) : Color(0xFFBF360C),
                                    ),
                                  ),
                                  SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontFamily: 'SF Pro Display',
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1A1A1A),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isActive ? Color(0xFFE8F5E9) : Color(0xFFFFEBEE),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isActive ? 'Active' : 'Revoked',
                                                style: TextStyle(
                                                  fontFamily: 'SF Pro Display',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isActive ? Color(0xFF2E7D32) : Color(0xFFC62828),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          preview,
                                          style: TextStyle(
                                            fontFamily: 'SF Mono, Courier',
                                            fontSize: 12,
                                            color: Color(0xFF888888),
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Created ${createdAt != null ? DateFormat('MMM d, yyyy').format(createdAt.toDate()) : 'Unknown'}'
                                          '${lastUsed != null ? '  ·  Used ${DateFormat('MMM d').format(lastUsed.toDate())}' : ''}',
                                          style: TextStyle(
                                            fontFamily: 'SF Pro Display',
                                            fontSize: 12,
                                            color: Color(0xFFBBBBBB),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              if (isActive)
                                CupertinoButton(
                                  padding: EdgeInsets.all(8),
                                  minSize: 32,
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      barrierColor: Colors.black54,
                                      builder: (ctx) => Center(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: Container(
                                            width: 360,
                                            padding: EdgeInsets.all(24),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.15),
                                                  blurRadius: 24,
                                                  offset: Offset(0, 8),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Revoke "$name"?',
                                                  style: TextStyle(
                                                    fontFamily: 'SF Pro Display',
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF1A1A1A),
                                                  ),
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'This key will stop working immediately. Any AI agent using this key will lose access.',
                                                  style: TextStyle(
                                                    fontFamily: 'SF Pro Display',
                                                    fontSize: 14,
                                                    color: Color(0xFF666666),
                                                    height: 1.4,
                                                  ),
                                                ),
                                                SizedBox(height: 20),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: CupertinoButton(
                                                        padding: EdgeInsets.symmetric(vertical: 12),
                                                        borderRadius: BorderRadius.circular(10),
                                                        color: Color(0xFFF0F0F0),
                                                        child: Text(
                                                          'Cancel',
                                                          style: TextStyle(
                                                            fontFamily: 'SF Pro Display',
                                                            fontSize: 15,
                                                            fontWeight: FontWeight.w500,
                                                            color: Color(0xFF333333),
                                                          ),
                                                        ),
                                                        onPressed: () => Navigator.pop(ctx, false),
                                                      ),
                                                    ),
                                                    SizedBox(width: 12),
                                                    Expanded(
                                                      child: CupertinoButton(
                                                        padding: EdgeInsets.symmetric(vertical: 12),
                                                        color: Color(0xFFCC0000),
                                                        borderRadius: BorderRadius.circular(10),
                                                        child: Text(
                                                          'Revoke Key',
                                                          style: TextStyle(
                                                            fontFamily: 'SF Pro Display',
                                                            fontSize: 15,
                                                            fontWeight: FontWeight.w600,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                        onPressed: () => Navigator.pop(ctx, true),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                    if (confirm == true) {
                                      await doc.reference.update({'is_active': false});
                                      // Also update top-level hash index
                                      final keyHash = (doc.data() as Map<String, dynamic>)['key_hash'];
                                      if (keyHash != null) {
                                        await FirebaseFirestore.instance.collection('api_key_hashes').doc(keyHash).update({'is_active': false});
                                      }
                                    }
                                  },
                                  child: Icon(
                                    CupertinoIcons.trash,
                                    size: 16,
                                    color: Color(0xFFCC0000),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Settings',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _buildSidebarItem(
                  tab: SettingsTab.yourProfile,
                  title: 'Your Profile',
                  icon: CupertinoIcons.person_fill,
                  isSelected: _model.selectedTab == SettingsTab.yourProfile,
                ),
                _buildSidebarItem(
                  tab: SettingsTab.notifications,
                  title: 'Notifications',
                  icon: CupertinoIcons.bell_fill,
                  isSelected: _model.selectedTab == SettingsTab.notifications,
                ),
                _buildSidebarItem(
                  tab: SettingsTab.preferences,
                  title: 'Preferences',
                  icon: CupertinoIcons.slider_horizontal_3,
                  isSelected: _model.selectedTab == SettingsTab.preferences,
                ),
                _buildSidebarItem(
                  tab: SettingsTab.apiKeys,
                  title: 'API Keys',
                  icon: CupertinoIcons.lock_shield_fill,
                  isSelected: _model.selectedTab == SettingsTab.apiKeys,
                ),
                _buildSidebarItem(
                  tab: SettingsTab.helpFeedback,
                  title: 'Help & Feedback',
                  icon: CupertinoIcons.question_circle_fill,
                  isSelected: _model.selectedTab == SettingsTab.helpFeedback,
                ),
                SizedBox(height: 8),
                Divider(height: 1, color: Color(0xFFE5E7EB)),
                SizedBox(height: 8),
                _buildSidebarItem(
                  tab: SettingsTab.logout,
                  title: 'Logout',
                  icon: CupertinoIcons.arrow_right_square_fill,
                  isSelected: _model.selectedTab == SettingsTab.logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_model.selectedTab) {
      case SettingsTab.yourProfile:
        return currentUserReference != null
            ? UserSummaryWidget(
                userRef: currentUserReference,
                isEditable: true,
              )
            : Center(
                child: Text('Please log in to view your profile'),
              );

      case SettingsTab.notifications:
        // Reload notification status when switching to this tab
        if (_lastSelectedTab != SettingsTab.notifications) {
          _lastSelectedTab = SettingsTab.notifications;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadNotificationStatus();
          });
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.bell_fill,
                    size: 32,
                    color: Color(0xFF0077B5),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Notifications',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              // Suggestion box
              if (!kIsWeb && Platform.isMacOS)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(0xFFBBDEFB),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.info_circle_fill,
                        size: 20,
                        color: Color(0xFF0077B5),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'To enable notifications go to Settings/Notifications/Lona Club and allow',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 14,
                            color: Color(0xFF1A1A1A),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 24),
              if (_isLoadingNotificationStatus)
                Center(
                  child: CupertinoActivityIndicator(),
                )
              else
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Allow Notifications',
                              style: TextStyle(
                                fontFamily: 'SF Pro Display',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _notificationsEnabled
                                  ? 'Notifications enabled'
                                  : 'Notifications disabled',
                              style: TextStyle(
                                fontFamily: 'SF Pro Display',
                                fontSize: 14,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _handleNotificationToggle(!_notificationsEnabled);
                        },
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          width: 51,
                          height: 31,
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: _notificationsEnabled
                                ? Color(0xFF0077B5)
                                : Color(0xFFE0E0E0),
                          ),
                          child: AnimatedAlign(
                            duration: Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            alignment: _notificationsEnabled
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              width: 27,
                              height: 27,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_isLoadingNotificationStatus)
                Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    _notificationsEnabled
                        ? 'You will receive notifications for new messages, connection requests, and other updates.'
                        : 'Notifications are turned off. You will not receive any push notifications.',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 13,
                      color: Color(0xFF999999),
                    ),
                  ),
                ),
            ],
          ),
        );

      case SettingsTab.preferences:
        return SingleChildScrollView(
          padding: EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.slider_horizontal_3,
                    size: 32,
                    color: Color(0xFF0077B5),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Preferences',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              // Chat Display Section
              Text(
                'Chat Display',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Message Font Size',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          '${FFAppState().chatFontSize.toInt()}pt',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0077B5),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Adjust the size of text in your chat messages',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'A',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF666666),
                          ),
                        ),
                        Expanded(
                          child: CupertinoSlider(
                            value: FFAppState().chatFontSize,
                            min: 12.0,
                            max: 24.0,
                            divisions: 12,
                            activeColor: Color(0xFF0077B5),
                            onChanged: (value) {
                              setState(() {
                                FFAppState().chatFontSize = value;
                              });
                            },
                          ),
                        ),
                        Text(
                          'A',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Text(
                        'This is how your messages will look.',
                        style: TextStyle(
                          fontFamily: 'SF Pro Text',
                          fontSize: FFAppState().chatFontSize,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              // Keyboard Shortcuts Section
              Text(
                'Keyboard Shortcuts',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send Message Shortcut',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Choose how you want to send messages in chat',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Option 1: Enter to send
                    _buildKeyboardShortcutOption(
                      title: 'Return (↵) to send',
                      subtitle: 'Shift + Return for new line',
                      isSelected: FFAppState().sendMessageShortcut == 0,
                      onTap: () {
                        setState(() {
                          FFAppState().sendMessageShortcut = 0;
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    // Option 2: Shift+Enter to send
                    _buildKeyboardShortcutOption(
                      title: 'Shift + Return to send',
                      subtitle: 'Return (↵) for new line',
                      isSelected: FFAppState().sendMessageShortcut == 1,
                      onTap: () {
                        setState(() {
                          FFAppState().sendMessageShortcut = 1;
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    // Option 3: Command+Enter to send
                    _buildKeyboardShortcutOption(
                      title: 'Command (⌘) + Return to send',
                      subtitle: 'Return (↵) for new line',
                      isSelected: FFAppState().sendMessageShortcut == 2,
                      onTap: () {
                        setState(() {
                          FFAppState().sendMessageShortcut = 2;
                        });
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Info text
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.info_circle_fill,
                      size: 18,
                      color: Color(0xFF666666),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This setting applies to all chat conversations',
                        style: TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 13,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              // Translation Language Section
              Text(
                'Translation Language',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target Language',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Select the language you want messages to be translated into',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Color(0xFFE5E7EB)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _translationLanguages
                                  .containsKey(FFAppState().translateLanguage)
                              ? FFAppState().translateLanguage
                              : 'system',
                          isExpanded: true,
                          icon: Icon(Icons.keyboard_arrow_down,
                              color: Color(0xFF666666)),
                          items: _translationLanguages.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  fontFamily: 'SF Pro Display',
                                  fontSize: 15,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                FFAppState().translateLanguage = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Auto Translate Toggle
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Auto Translate',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Automatically translate all messages to the selected language',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 14,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoSwitch(
                      value: FFAppState().autoTranslate,
                      onChanged: (value) {
                        setState(() {
                          FFAppState().autoTranslate = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              // Outgoing Translation Section
              Text(
                'Outgoing Translation',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enable AI Translation Switch
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enable Outgoing Translation',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Display',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Automatically translate outgoing messages using free translation',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Display',
                                  fontSize: 14,
                                  color: Color(0xFF666666),
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                '⚠️ Translation results may not be accurate — please use with caution.',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Display',
                                  fontSize: 13,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoSwitch(
                          value: FFAppState().aiTranslationEnabled,
                          onChanged: (value) {
                            setState(() {
                              FFAppState().aiTranslationEnabled = value;
                            });
                          },
                        ),
                      ],
                    ),
                    Divider(height: 32, color: Color(0xFFE5E7EB)),
                    // Target Language
                    Text(
                      'Target Language',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Select the language you want your messages to be translated into',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Color(0xFFE5E7EB)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _translationLanguages.containsKey(
                                  FFAppState().aiTranslationTargetLanguage)
                              ? FFAppState().aiTranslationTargetLanguage
                              : 'system',
                          isExpanded: true,
                          icon: Icon(Icons.keyboard_arrow_down,
                              color: Color(0xFF666666)),
                          items: _translationLanguages.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  fontFamily: 'SF Pro Display',
                                  fontSize: 15,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                FFAppState().aiTranslationTargetLanguage =
                                    value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              // Account
              Text(
                'Account',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  await showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) => Padding(
                      padding: MediaQuery.viewInsetsOf(context),
                      child: DeleteAccountWidget(),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFE5E7EB), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_remove_outlined,
                          size: 24, color: Color(0xFFDC2626)),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Account Deletion',
                                style: TextStyle(
                                    fontFamily: 'SF Pro Display',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A))),
                            SizedBox(height: 4),
                            Text('Permanently delete your account',
                                style: TextStyle(
                                    fontFamily: 'SF Pro Display',
                                    fontSize: 14,
                                    color: Color(0xFF666666))),
                          ],
                        ),
                      ),
                      Icon(CupertinoIcons.chevron_right,
                          size: 20, color: Color(0xFF999999)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

      case SettingsTab.apiKeys:
        return _buildApiKeysContent();

      case SettingsTab.helpFeedback:
        return SingleChildScrollView(
          padding: EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.question_circle_fill,
                    size: 32,
                    color: Color(0xFF0077B5),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Help & Feedback',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32),
              // Privacy Policy
              _buildHelpItem(
                icon: CupertinoIcons.lock_shield_fill,
                title: 'Privacy Policy',
                onTap: () => _showPrivacyPolicy(context),
              ),
              SizedBox(height: 12),
              // Customer Support
              _buildHelpItem(
                icon: CupertinoIcons.chat_bubble_text_fill,
                title: 'Customer Support',
                onTap: () => _showCustomerSupport(context),
              ),
              SizedBox(height: 32),
              // Security Message
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      CupertinoIcons.lock_shield_fill,
                      size: 24,
                      color: Color(0xFF0077B5),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your data is encrypted and secure',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'All your messages, calls, and shared content are protected with end-to-end encryption. Your privacy is our priority.',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 14,
                              color: Color(0xFF666666),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case SettingsTab.logout:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.arrow_right_square_fill,
                size: 64,
                color: Color(0xFFFF3B30),
              ),
              SizedBox(height: 16),
              Text(
                'Logout',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: 24),
              Container(
                width: 200,
                height: 44,
                decoration: BoxDecoration(
                  color: Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () async {
                      try {
                        await authManager.signOut();
                        if (context.mounted) {
                          context.goNamedAuth('Welcome', context.mounted);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to log out: $e'),
                              backgroundColor: Color(0xFFFF3B30),
                            ),
                          );
                        }
                      }
                    },
                    child: Center(
                      child: Text(
                        'Logout',
                        style: TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _model.unfocusNode.canRequestFocus
          ? FocusScope.of(context).requestFocus(_model.unfocusNode)
          : FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: isDesktop
            ? Row(
                children: [
                  _buildSidebar(),
                  Expanded(
                    child: _buildContent(),
                  ),
                ],
              )
            : widget.initialTab != null
                ? CupertinoPageScaffold(
                    navigationBar: CupertinoNavigationBar(
                      middle: Text(_getTabTitle(_model.selectedTab)),
                      leading: CupertinoNavigationBarBackButton(
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    child: SafeArea(
                      child: _buildContent(),
                    ),
                  )
                : CupertinoPageScaffold(
                    navigationBar: CupertinoNavigationBar(
                      middle: Text('Settings'),
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildSidebarItem(
                                  tab: SettingsTab.yourProfile,
                                  title: 'Your Profile',
                                  icon: CupertinoIcons.person_fill,
                                  isSelected:
                                      _model.selectedTab == SettingsTab.yourProfile,
                                ),
                                _buildSidebarItem(
                                  tab: SettingsTab.notifications,
                                  title: 'Notifications',
                                  icon: CupertinoIcons.bell_fill,
                                  isSelected: _model.selectedTab ==
                                      SettingsTab.notifications,
                                ),
                                _buildSidebarItem(
                                  tab: SettingsTab.preferences,
                                  title: 'Preferences',
                                  icon: CupertinoIcons.slider_horizontal_3,
                                  isSelected:
                                      _model.selectedTab == SettingsTab.preferences,
                                ),
                                _buildSidebarItem(
                                  tab: SettingsTab.apiKeys,
                                  title: 'API Keys',
                                  icon: CupertinoIcons.lock_shield_fill,
                                  isSelected:
                                      _model.selectedTab == SettingsTab.apiKeys,
                                ),
                                _buildSidebarItem(
                                  tab: SettingsTab.helpFeedback,
                                  title: 'Help & Feedback',
                                  icon: CupertinoIcons.question_circle_fill,
                                  isSelected: _model.selectedTab ==
                                      SettingsTab.helpFeedback,
                                ),
                                SizedBox(height: 8),
                                Divider(height: 1, color: Color(0xFFE5E7EB)),
                                SizedBox(height: 8),
                                _buildSidebarItem(
                                  tab: SettingsTab.logout,
                                  title: 'Logout',
                                  icon: CupertinoIcons.arrow_right_square_fill,
                                  isSelected:
                                      _model.selectedTab == SettingsTab.logout,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _buildContent(),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
