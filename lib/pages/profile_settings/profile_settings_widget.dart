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
import 'package:permission_handler/permission_handler.dart';

class ProfileSettingsWidget extends StatefulWidget {
  const ProfileSettingsWidget({super.key});

  @override
  _ProfileSettingsWidgetState createState() => _ProfileSettingsWidgetState();
}

class _ProfileSettingsWidgetState extends State<ProfileSettingsWidget> {
  late ProfileSettingsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Notification state
  bool _notificationsEnabled = false;
  bool _isLoadingNotificationStatus = true;
  SettingsTab? _lastSelectedTab;

  // Method channel for native notification permissions
  static const MethodChannel _notificationChannel =
      MethodChannel('com.lona.app/notifications');

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
    _loadNotificationStatus();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: const Color(0xFF0077B5),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const Icon(
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE3F2FD) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF0077B5) : const Color(0xFFE5E7EB),
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
                  color: isSelected ? const Color(0xFF0077B5) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0077B5) : const Color(0xFF999999),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
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
                        color: isSelected ? const Color(0xFF0077B5) : const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
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
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
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
            child: const Text('Close'),
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
        title: const Text('Customer Support'),
        content: const SingleChildScrollView(
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
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // Load notification status from system
  Future<void> _loadNotificationStatus() async {
    if (kIsWeb) {
      setState(() {
        _notificationsEnabled = false;
        _isLoadingNotificationStatus = false;
      });
      return;
    }

    if (!Platform.isMacOS) {
      setState(() {
        _isLoadingNotificationStatus = false;
      });
      return;
    }

    try {
      // Use method channel to get native permission status
      final bool? isAuthorized = await _notificationChannel
          .invokeMethod<bool>('getNotificationPermissionStatus');

      setState(() {
        _notificationsEnabled = isAuthorized ?? false;
        _isLoadingNotificationStatus = false;
      });
    } catch (e) {
      print('Error loading notification status: $e');
      // Fallback to Firebase Messaging if method channel fails
      try {
        final messaging = FirebaseMessaging.instance;
        final settings = await messaging.getNotificationSettings();
        final isAuthorized =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
                settings.authorizationStatus == AuthorizationStatus.provisional;
        setState(() {
          _notificationsEnabled = isAuthorized;
          _isLoadingNotificationStatus = false;
        });
      } catch (e2) {
        print('Error loading notification status (fallback): $e2');
        setState(() {
          _isLoadingNotificationStatus = false;
        });
      }
    }
  }

  // Handle notification toggle
  Future<void> _handleNotificationToggle(bool newValue) async {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    if (newValue) {
      // Turning ON - Directly request system notification permission via native method channel
      // This will show the native system dialog like WhatsApp/Slack
      try {
        // Use method channel to request native permission - this will show system dialog
        final bool? permissionGranted = await _notificationChannel
            .invokeMethod<bool>('requestNotificationPermission');

        // Update state based on actual permission result
        setState(() {
          _notificationsEnabled = permissionGranted ?? false;
        });

        // Update Firestore if user is logged in
        if (currentUserReference != null) {
          await currentUserReference!.update({
            'notifications_enabled': permissionGranted ?? false,
          });
        }

        // If permission was denied, open system settings
        if (!(permissionGranted ?? false) && mounted) {
          await openAppSettings();
        }
      } catch (e) {
        print('Error requesting notification permission: $e');
        setState(() {
          _notificationsEnabled = false;
        });
      }
    } else {
      // Turning OFF - Update state immediately
      setState(() {
        _notificationsEnabled = false;
      });

      // Update Firestore
      if (currentUserReference != null) {
        await currentUserReference!.update({
          'notifications_enabled': false,
        });
      }

      // Note: We can't actually disable system notifications programmatically
      // The user would need to do that in System Settings
      // But we can stop sending notifications by updating our preference
    }
  }

  Widget _buildSidebarItem({
    required SettingsTab tab,
    required String title,
    required IconData icon,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE3F2FD) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? const Color(0xFF0077B5) : const Color(0xFF666666),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? const Color(0xFF0077B5) : const Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
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
          const Padding(
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  tab: SettingsTab.helpFeedback,
                  title: 'Help & Feedback',
                  icon: CupertinoIcons.question_circle_fill,
                  isSelected: _model.selectedTab == SettingsTab.helpFeedback,
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 8),
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
            : const Center(
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
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
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
              const SizedBox(height: 24),
              // Suggestion box
              if (!kIsWeb && Platform.isMacOS)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFBBDEFB),
                      width: 1,
                    ),
                  ),
                  child: const Row(
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
              const SizedBox(height: 24),
              if (_isLoadingNotificationStatus)
                const Center(
                  child: CupertinoActivityIndicator(),
                )
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
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
                            const Text(
                              'Allow Notifications',
                              style: TextStyle(
                                fontFamily: 'SF Pro Display',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _notificationsEnabled
                                  ? 'Notifications enabled'
                                  : 'Notifications disabled',
                              style: const TextStyle(
                                fontFamily: 'SF Pro Display',
                                fontSize: 14,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ],
                        ),
                      ),
                      CupertinoSwitch(
                        value: _notificationsEnabled,
                        onChanged: _handleNotificationToggle,
                        activeTrackColor: const Color(0xFF0077B5),
                      ),
                    ],
                  ),
                ),
              if (!_isLoadingNotificationStatus && !kIsWeb && Platform.isMacOS)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _notificationsEnabled
                        ? 'You will receive notifications for new messages, connection requests, and other updates.'
                        : 'When enabled, you will receive a system notification permission request.',
                    style: const TextStyle(
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
        return Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
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
              const SizedBox(height: 24),
              // Keyboard Shortcuts Section
              const Text(
                'Keyboard Shortcuts',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Send Message Shortcut',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Choose how you want to send messages in chat',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
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
              const SizedBox(height: 16),
              // Info text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
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
              const SizedBox(height: 24),
              // Translation Language Section
              const Text(
                'Translation Language',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Target Language',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select the language you want messages to be translated into',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _translationLanguages.containsKey(FFAppState().translateLanguage) 
                              ? FFAppState().translateLanguage 
                              : 'system',
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF666666)),
                          items: _translationLanguages.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(
                                entry.value,
                                style: const TextStyle(
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
              const SizedBox(height: 16),
              // Auto Translate Toggle
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
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
                      activeTrackColor: const Color(0xFF0077B5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Account
              const Text(
                'Account',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  await showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) => Padding(
                      padding: MediaQuery.viewInsetsOf(context),
                      child: const DeleteAccountWidget(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.person_remove_outlined, size: 24, color: Color(0xFFDC2626)),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Account Deletion', style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                            SizedBox(height: 4),
                            Text('Permanently delete your account', style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 14, color: Color(0xFF666666))),
                          ],
                        ),
                      ),
                      Icon(CupertinoIcons.chevron_right, size: 20, color: Color(0xFF999999)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

      case SettingsTab.helpFeedback:
        return Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
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
              const SizedBox(height: 32),
              // Privacy Policy
              _buildHelpItem(
                icon: CupertinoIcons.lock_shield_fill,
                title: 'Privacy Policy',
                onTap: () => _showPrivacyPolicy(context),
              ),
              const SizedBox(height: 12),
              // Customer Support
              _buildHelpItem(
                icon: CupertinoIcons.chat_bubble_text_fill,
                title: 'Customer Support',
                onTap: () => _showCustomerSupport(context),
              ),
              const SizedBox(height: 32),
              // Security Message
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: const Row(
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
              const Icon(
                CupertinoIcons.arrow_right_square_fill,
                size: 64,
                color: Color(0xFFFF3B30),
              ),
              const SizedBox(height: 16),
              const Text(
                'Logout',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 200,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
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
                              backgroundColor: const Color(0xFFFF3B30),
                            ),
                          );
                        }
                      }
                    },
                    child: const Center(
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
            : CupertinoPageScaffold(
                navigationBar: const CupertinoNavigationBar(
                  middle: Text('Settings'),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
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
                              isSelected: _model.selectedTab ==
                                  SettingsTab.preferences,
                            ),
                            _buildSidebarItem(
                              tab: SettingsTab.helpFeedback,
                              title: 'Help & Feedback',
                              icon: CupertinoIcons.question_circle_fill,
                              isSelected: _model.selectedTab ==
                                  SettingsTab.helpFeedback,
                            ),
                            const SizedBox(height: 8),
                            const Divider(height: 1, color: Color(0xFFE5E7EB)),
                            const SizedBox(height: 8),
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
