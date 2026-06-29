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
        borderRadius: BorderRadius.circular(6),
        hoverColor: Color(0xFFF5F5F7),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF2F2F2), width: 0.5)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Color(0xFF007AFF)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
              ),
              Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
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
        borderRadius: BorderRadius.circular(6),
        hoverColor: Color(0xFFF5F5F7),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Color(0xFF007AFF).withOpacity(0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? Color(0xFF007AFF).withOpacity(0.3) : Color(0xFFE5E5E5),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Color(0xFF007AFF) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? Color(0xFF007AFF) : Color(0xFFC7C7CC),
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check, size: 10, color: Colors.white)
                    : null,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Color(0xFF007AFF) : Color(0xFF1D1D1F),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 11,
                        color: Color(0xFF8E8E93),
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
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 480,
            constraints: BoxConstraints(maxHeight: 520),
            decoration: BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title bar
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.lock_shield, size: 16, color: Color(0xFF007AFF)),
                      SizedBox(width: 8),
                      Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontFamily: 'SF Pro Text',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                      Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Color(0xFFE5E5E5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.close, size: 12, color: Color(0xFF8E8E93)),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last updated: January 2024',
                          style: TextStyle(fontFamily: 'SF Pro Text', fontSize: 11, color: Color(0xFF8E8E93)),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'At Lona Club, we are committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your personal information.',
                          style: TextStyle(fontFamily: 'SF Pro Text', fontSize: 12, color: Color(0xFF636366), height: 1.5),
                        ),
                        SizedBox(height: 16),
                        _buildPolicySection('Information We Collect', [
                          'Account information (name, email, phone number)',
                          'Messages and communications',
                          'Device information and usage data',
                        ]),
                        SizedBox(height: 12),
                        _buildPolicySection('How We Use Your Information', [
                          'To provide and improve our services',
                          'To communicate with you',
                          'To ensure security and prevent fraud',
                        ]),
                        SizedBox(height: 12),
                        _buildPolicySection('Data Security', [
                          'All your data is encrypted and stored securely',
                          'We use industry-standard security measures',
                        ]),
                        SizedBox(height: 12),
                        _buildPolicySection('Your Rights', [
                          'Access, update, or delete your personal information',
                          'Manage preferences through account settings',
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPolicySection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'SF Pro Text',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1D1D1F),
          ),
        ),
        SizedBox(height: 4),
        ...items.map((item) => Padding(
          padding: EdgeInsets.only(left: 8, top: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(fontFamily: 'SF Pro Text', fontSize: 12, color: Color(0xFF636366), height: 1.4),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  // Show Customer Support
  void _showCustomerSupport(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 480,
            constraints: BoxConstraints(maxHeight: 480),
            decoration: BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title bar
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.chat_bubble_text, size: 16, color: Color(0xFF007AFF)),
                      SizedBox(width: 8),
                      Text(
                        'Customer Support',
                        style: TextStyle(
                          fontFamily: 'SF Pro Text',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                      Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Color(0xFFE5E5E5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.close, size: 12, color: Color(0xFF8E8E93)),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Contact info card
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CONTACT',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Text',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF8E8E93),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 8),
                              _buildContactRow(CupertinoIcons.mail, 'support@lonaclub.com'),
                              SizedBox(height: 6),
                              _buildContactRow(CupertinoIcons.phone, '+1 (555) 123-4567'),
                              SizedBox(height: 6),
                              _buildContactRow(CupertinoIcons.clock, 'Mon – Fri, 9 AM – 6 PM EST'),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'For urgent issues, email us and we\'ll respond within 24 hours.',
                            style: TextStyle(fontFamily: 'SF Pro Text', fontSize: 11, color: Color(0xFF8E8E93)),
                          ),
                        ),
                        SizedBox(height: 20),
                        // FAQ
                        Text(
                          'FREQUENTLY ASKED QUESTIONS',
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF8E8E93),
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFaqItem('How do I reset my password?'),
                              SizedBox(height: 6),
                              _buildFaqItem('How do I delete my account?'),
                              SizedBox(height: 6),
                              _buildFaqItem('How do I report a problem?'),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Visit our help center for more answers.',
                            style: TextStyle(fontFamily: 'SF Pro Text', fontSize: 11, color: Color(0xFF8E8E93)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Color(0xFF636366)),
        SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(fontFamily: 'SF Pro Text', fontSize: 12, color: Color(0xFF1D1D1F)),
        ),
      ],
    );
  }

  Widget _buildFaqItem(String question) {
    return Row(
      children: [
        Icon(CupertinoIcons.question_circle, size: 13, color: Color(0xFF007AFF)),
        SizedBox(width: 8),
        Text(
          question,
          style: TextStyle(fontFamily: 'SF Pro Text', fontSize: 12, color: Color(0xFF1D1D1F)),
        ),
      ],
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
      margin: EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _model.selectedTab = tab;
            });
            if (tab == SettingsTab.notifications) {
              _loadNotificationStatus();
            }
          },
          borderRadius: BorderRadius.circular(5),
          hoverColor: Color(0xFFF5F5F7),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? Color(0xFF007AFF).withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? Color(0xFF007AFF) : Color(0xFF8E8E93),
                ),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Color(0xFF007AFF) : Color(0xFF1D1D1F),
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
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'API Keys',
            style: TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1D1F),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Manage API keys for AI integrations.',
            style: TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 12,
              color: Color(0xFF8E8E93),
            ),
          ),
          SizedBox(height: 24),

          // ── System Key Section ──
          Text(
            'SYSTEM KEY',
            style: TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8E8E93),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Messages sent via system key appear from "Qurio AI".',
            style: TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 12,
              color: Color(0xFF636366),
              height: 1.4,
            ),
          ),
          SizedBox(height: 12),

          // System key info card
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.person_crop_circle_badge_checkmark, size: 14, color: Color(0xFF8E8E93)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Qurio AI will appear as a separate bot account in chats, not as you.',
                    style: TextStyle(
                      fontFamily: 'SF Pro Text',
                      fontSize: 12,
                      color: Color(0xFF636366),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),

          // Generate System Key button
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: EdgeInsets.symmetric(vertical: 8),
              color: Color(0xFF007AFF),
              borderRadius: BorderRadius.circular(6),
              onPressed: _showGenerateSystemKeyDialog,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.plus, size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Generate System Key',
                    style: TextStyle(
                      fontFamily: 'SF Pro Text',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No system keys yet',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 12,
                        color: Color(0xFFAEAEB2),
                      ),
                    ),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Color(0xFFE5E5E5), width: 0.5),
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
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isActive ? Color(0xFF007AFF).withOpacity(0.1) : Color(0xFFF2F2F7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    CupertinoIcons.bolt,
                                    size: 14,
                                    color: isActive ? Color(0xFF007AFF) : Color(0xFFC7C7CC),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontFamily: 'SF Pro Text',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF1D1D1F),
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isActive ? Color(0xFF34C759).withOpacity(0.12) : Color(0xFFFF3B30).withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              isActive ? 'Active' : 'Revoked',
                                              style: TextStyle(
                                                fontFamily: 'SF Pro Text',
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: isActive ? Color(0xFF34C759) : Color(0xFFFF3B30),
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
                                          fontSize: 11,
                                          color: Color(0xFF8E8E93),
                                        ),
                                      ),
                                      Text(
                                        'Created ${createdAt != null ? DateFormat('MMM d, yyyy').format(createdAt.toDate()) : 'Unknown'}',
                                        style: TextStyle(
                                          fontFamily: 'SF Pro Text',
                                          fontSize: 11,
                                          color: Color(0xFFAEAEB2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isActive && keyHash != null)
                                  CupertinoButton(
                                    padding: EdgeInsets.all(6),
                                    minSize: 24,
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
                                    child: Icon(CupertinoIcons.xmark_circle, size: 16, color: Color(0xFFFF3B30)),
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

          SizedBox(height: 24),
          Divider(color: Color(0xFFE5E5E5), height: 1),
          SizedBox(height: 20),

          // ── Personal Key Section (existing) ──
          Text(
            'PERSONAL KEYS',
            style: TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8E8E93),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Messages appear from your account, tagged "via Qurio AI".',
            style: TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 12,
              color: Color(0xFF636366),
              height: 1.4,
            ),
          ),
          SizedBox(height: 12),

          // Info card
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.info_circle, size: 14, color: Color(0xFF8E8E93)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your API key allows AI to access only chats you are a member of.',
                    style: TextStyle(
                      fontFamily: 'SF Pro Text',
                      fontSize: 12,
                      color: Color(0xFF636366),
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
              padding: EdgeInsets.symmetric(vertical: 8),
              color: Color(0xFF007AFF),
              borderRadius: BorderRadius.circular(6),
              onPressed: _showGenerateKeyDialog,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.plus, size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Generate New API Key',
                    style: TextStyle(
                      fontFamily: 'SF Pro Text',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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
            'YOUR KEYS',
            style: TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8E8E93),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Manage your existing API keys',
            style: TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 12,
              color: Color(0xFF636366),
            ),
          ),
          SizedBox(height: 8),

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
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No API keys yet. Generate your first key above.',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 12,
                        color: Color(0xFFAEAEB2),
                      ),
                    ),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Color(0xFFE5E5E5), width: 0.5),
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
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: isActive ? Color(0xFF007AFF).withOpacity(0.1) : Color(0xFFF2F2F7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.lock,
                                      size: 14,
                                      color: isActive ? Color(0xFF007AFF) : Color(0xFFC7C7CC),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontFamily: 'SF Pro Text',
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF1D1D1F),
                                              ),
                                            ),
                                            SizedBox(width: 6),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: isActive ? Color(0xFF34C759).withOpacity(0.12) : Color(0xFFFF3B30).withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Text(
                                                isActive ? 'Active' : 'Revoked',
                                                style: TextStyle(
                                                  fontFamily: 'SF Pro Text',
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color: isActive ? Color(0xFF34C759) : Color(0xFFFF3B30),
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
                                            fontSize: 11,
                                            color: Color(0xFF8E8E93),
                                          ),
                                        ),
                                        Text(
                                          'Created ${createdAt != null ? DateFormat('MMM d, yyyy').format(createdAt.toDate()) : 'Unknown'}'
                                          '${lastUsed != null ? '  ·  Used ${DateFormat('MMM d').format(lastUsed.toDate())}' : ''}',
                                          style: TextStyle(
                                            fontFamily: 'SF Pro Text',
                                            fontSize: 11,
                                            color: Color(0xFFAEAEB2),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              if (isActive)
                                CupertinoButton(
                                  padding: EdgeInsets.all(6),
                                  minSize: 24,
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
                                    size: 14,
                                    color: Color(0xFFFF3B30),
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
      width: 200,
      decoration: BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border(
          right: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact header
          Container(
            height: 52,
            padding: EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
              ),
            ),
            child: Text(
              'Settings',
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D1D1F),
              ),
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                _buildSidebarItem(
                  tab: SettingsTab.yourProfile,
                  title: 'Profile',
                  icon: CupertinoIcons.person,
                  isSelected: _model.selectedTab == SettingsTab.yourProfile,
                ),
                _buildSidebarItem(
                  tab: SettingsTab.notifications,
                  title: 'Notifications',
                  icon: CupertinoIcons.bell,
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
                  icon: CupertinoIcons.lock,
                  isSelected: _model.selectedTab == SettingsTab.apiKeys,
                ),
                _buildSidebarItem(
                  tab: SettingsTab.helpFeedback,
                  title: 'Help',
                  icon: CupertinoIcons.question_circle,
                  isSelected: _model.selectedTab == SettingsTab.helpFeedback,
                ),
                SizedBox(height: 6),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 10),
                  child: Divider(height: 1, color: Color(0xFFE5E5E5)),
                ),
                SizedBox(height: 6),
                _buildSidebarItem(
                  tab: SettingsTab.logout,
                  title: 'Sign Out',
                  icon: CupertinoIcons.arrow_right_square,
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

        return Container(
          color: Color(0xFF1C1C1E),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage how you receive notifications.',
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontSize: 13,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                SizedBox(height: 24),
                if (!kIsWeb && Platform.isMacOS)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Color(0xFF3A3A3C), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.info_circle_fill, size: 16, color: Color(0xFF007AFF)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Enable in System Settings → Notifications → Lona Club',
                            style: TextStyle(
                              fontFamily: 'SF Pro Text',
                              fontSize: 12,
                              color: Color(0xFFAEAEB2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_isLoadingNotificationStatus)
                  Center(child: CupertinoActivityIndicator(color: Colors.white))
                else
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Color(0xFF3A3A3C), width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Allow Notifications',
                              style: TextStyle(
                                fontFamily: 'SF Pro Text',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              _notificationsEnabled ? 'Enabled' : 'Disabled',
                              style: TextStyle(
                                fontFamily: 'SF Pro Text',
                                fontSize: 12,
                                color: _notificationsEnabled ? Color(0xFF30D158) : Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                        CupertinoSwitch(
                          value: _notificationsEnabled,
                          activeTrackColor: Color(0xFF30D158),
                          onChanged: (val) => _handleNotificationToggle(val),
                        ),
                      ],
                    ),
                  ),
                if (!_isLoadingNotificationStatus)
                  Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      _notificationsEnabled
                          ? 'You will receive notifications for new messages, connection requests, and other updates.'
                          : 'Notifications are turned off.',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 12,
                        color: Color(0xFF636366),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );

      case SettingsTab.preferences:
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preferences',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D1D1F),
                ),
              ),
              SizedBox(height: 20),
              // Section header
              Text(
                'CHAT DISPLAY',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8E8E93),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Color(0xFFE5E5E5), width: 0.5),
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
                            fontFamily: 'SF Pro Text',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        Text(
                          '${FFAppState().chatFontSize.toInt()}pt',
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Adjust the size of text in your chat messages',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 11,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'A',
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        Expanded(
                          child: CupertinoSlider(
                            value: FFAppState().chatFontSize,
                            min: 12.0,
                            max: 24.0,
                            divisions: 12,
                            activeColor: Color(0xFF007AFF),
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
                            fontFamily: 'SF Pro Text',
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'This is how your messages will look.',
                        style: TextStyle(
                          fontFamily: 'SF Pro Text',
                          fontSize: FFAppState().chatFontSize,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              // UI Scale Section
              Text(
                'UI SCALE',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8E8E93),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Color(0xFFE5E5E5), width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Interface Scale',
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${(FFAppState().uiScale * 100).toInt()}%',
                              style: TextStyle(
                                fontFamily: 'SF Pro Text',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                            if (FFAppState().uiScale != 1.0) ...[
                              SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    FFAppState().uiScale = 1.0;
                                  });
                                },
                                child: Text(
                                  'Reset',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Text',
                                    fontSize: 11,
                                    color: Color(0xFF8E8E93),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Adjust the overall size of text and UI elements',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 11,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Aa',
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        Expanded(
                          child: CupertinoSlider(
                            value: FFAppState().uiScale,
                            min: 0.8,
                            max: 1.4,
                            divisions: 12,
                            activeColor: Color(0xFF007AFF),
                            onChanged: (value) {
                              setState(() {
                                FFAppState().uiScale = value;
                              });
                            },
                          ),
                        ),
                        Text(
                          'Aa',
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              // Keyboard Shortcuts Section
              Text(
                'KEYBOARD SHORTCUTS',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8E8E93),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Color(0xFFE5E5E5), width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send Message Shortcut',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Choose how you want to send messages in chat',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 11,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                    SizedBox(height: 12),
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
                    SizedBox(height: 6),
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
                    SizedBox(height: 6),
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
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.info_circle, size: 12, color: Color(0xFFAEAEB2)),
                    SizedBox(width: 6),
                    Text(
                      'This setting applies to all chat conversations',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 11,
                        color: Color(0xFFAEAEB2),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              // Translation Language Section
              Text(
                'TRANSLATION',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8E8E93),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Color(0xFFE5E5E5), width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target Language',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Select the language for message translation',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 11,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _translationLanguages
                                  .containsKey(FFAppState().translateLanguage)
                              ? FFAppState().translateLanguage
                              : 'system',
                          isExpanded: true,
                          icon: Icon(Icons.keyboard_arrow_down,
                              size: 16, color: Color(0xFF8E8E93)),
                          items: _translationLanguages.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  fontFamily: 'SF Pro Text',
                                  fontSize: 13,
                                  color: Color(0xFF1D1D1F),
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
              SizedBox(height: 8),
              // Auto Translate Toggle
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Color(0xFFE5E5E5), width: 0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto Translate',
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Translate all incoming messages automatically',
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            fontSize: 11,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                    CupertinoSwitch(
                      value: FFAppState().autoTranslate,
                      activeTrackColor: Color(0xFF007AFF),
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
                'OUTGOING TRANSLATION',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8E8E93),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Color(0xFFE5E5E5), width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                  fontFamily: 'SF Pro Text',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1D1D1F),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Auto-translate outgoing messages using free translation',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Text',
                                  fontSize: 11,
                                  color: Color(0xFF8E8E93),
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoSwitch(
                          value: FFAppState().aiTranslationEnabled,
                          activeTrackColor: Color(0xFF007AFF),
                          onChanged: (value) {
                            setState(() {
                              FFAppState().aiTranslationEnabled = value;
                            });
                          },
                        ),
                      ],
                    ),
                    if (FFAppState().aiTranslationEnabled) ...[
                      SizedBox(height: 8),
                      Padding(
                        padding: EdgeInsets.only(left: 2),
                        child: Text(
                          '⚠️ Results may not be accurate — use with caution.',
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            fontSize: 11,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                    Divider(height: 24, color: Color(0xFFE5E5E5)),
                    Text(
                      'Target Language',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Select the language for outgoing message translation',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 11,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _translationLanguages.containsKey(
                                  FFAppState().aiTranslationTargetLanguage)
                              ? FFAppState().aiTranslationTargetLanguage
                              : 'system',
                          isExpanded: true,
                          icon: Icon(Icons.keyboard_arrow_down,
                              size: 16, color: Color(0xFF8E8E93)),
                          items: _translationLanguages.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  fontFamily: 'SF Pro Text',
                                  fontSize: 13,
                                  color: Color(0xFF1D1D1F),
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
                'ACCOUNT',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8E8E93),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  hoverColor: Color(0xFFF5F5F7),
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
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Color(0xFFE5E5E5), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.person_badge_minus,
                            size: 16, color: Color(0xFFFF3B30)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Delete Account',
                                  style: TextStyle(
                                      fontFamily: 'SF Pro Text',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFFF3B30))),
                              SizedBox(height: 2),
                              Text('Permanently delete your account and data',
                                  style: TextStyle(
                                      fontFamily: 'SF Pro Text',
                                      fontSize: 11,
                                      color: Color(0xFF8E8E93))),
                            ],
                          ),
                        ),
                        Icon(CupertinoIcons.chevron_right,
                            size: 14, color: Color(0xFFC7C7CC)),
                      ],
                    ),
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
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Help',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D1D1F),
                ),
              ),
              SizedBox(height: 20),
              _buildHelpItem(
                icon: CupertinoIcons.lock_shield,
                title: 'Privacy Policy',
                onTap: () => _showPrivacyPolicy(context),
              ),
              _buildHelpItem(
                icon: CupertinoIcons.chat_bubble_text,
                title: 'Customer Support',
                onTap: () => _showCustomerSupport(context),
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.lock_shield, size: 14, color: Color(0xFF8E8E93)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your data is encrypted and protected with end-to-end encryption.',
                        style: TextStyle(
                          fontFamily: 'SF Pro Text',
                          fontSize: 12,
                          color: Color(0xFF636366),
                        ),
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
              Text(
                'Sign Out',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D1D1F),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'You will be signed out of your account.',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontSize: 13,
                  color: Color(0xFF8E8E93),
                ),
              ),
              SizedBox(height: 20),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
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
                            content: Text('Failed to sign out: $e'),
                            backgroundColor: Color(0xFFFF3B30),
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Sign Out',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
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
