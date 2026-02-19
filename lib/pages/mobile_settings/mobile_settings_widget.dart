import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/user_summary/user_summary_widget.dart';
import '/components/delete_account_widget.dart';
import '/auth/terms_privacy/terms_privacy_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart'
    show
        AdaptiveAlertDialog,
        AlertAction,
        AlertActionStyle,
        PlatformInfo,
        AdaptiveSwitch;
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '/app_state.dart';
import '/custom_code/actions/index.dart' as actions;

class MobileSettingsWidget extends StatefulWidget {
  const MobileSettingsWidget({
    super.key,
    this.initialSection,
  });

  final String? initialSection;

  static String routeName = 'MobileSettings';
  static String routePath = '/mobileSettings';

  @override
  State<MobileSettingsWidget> createState() => _MobileSettingsWidgetState();
}

class _MobileSettingsWidgetState extends State<MobileSettingsWidget>
  with WidgetsBindingObserver {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  // State variables
  String _selectedSetting = '';
  String _searchQuery = '';
  bool _openInEditMode = false;

  // Notification settings state - synced with system
  bool _pushNotificationsEnabled = false;
  bool _isLoadingNotificationStatus = false;
  bool _hasLoadedNotificationStatus = false;

  // Controllers
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load notification settings once on init (deferred to avoid blocking)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotificationSettings();
    });

    // Set initial section if provided
    if (widget.initialSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedSetting = widget.initialSection!;
        });
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh notification status when app comes back to foreground
    // (e.g., when user returns from system settings)
    if (state == AppLifecycleState.resumed &&
        _selectedSetting == 'Notifications') {
      _loadNotificationSettings();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotificationSettings() async {
    // Prevent multiple simultaneous loads
    if (_isLoadingNotificationStatus) return;

    setState(() {
      _isLoadingNotificationStatus = true;
    });

    // Check actual system notification permission status directly
    bool systemNotificationEnabled = false;

    if (kIsWeb) {
      // For web, check browser notification permission
      systemNotificationEnabled = false; // Web notifications handled separately
    } else if (Platform.isMacOS || Platform.isIOS) {
      // Use permission_handler to check actual system notification permission
      try {
        final status = await Permission.notification.status;
        systemNotificationEnabled = status.isGranted;

        // Also check Firebase Messaging settings as secondary check
        try {
          final messaging = FirebaseMessaging.instance;
          final settings = await messaging.getNotificationSettings();
          // If permission_handler says granted, trust it (like WhatsApp)
          // Firebase might not be fully synced yet
          if (status.isGranted) {
            systemNotificationEnabled = true;
          } else {
            // If not granted, check Firebase status
            systemNotificationEnabled = settings.authorizationStatus ==
                    AuthorizationStatus.authorized ||
                settings.authorizationStatus == AuthorizationStatus.provisional;
          }
        } catch (e) {
          print('Error checking Firebase notification settings: $e');
          // Fall back to permission_handler result
        }
      } catch (e) {
        print('Error checking notification permission: $e');
        // Fallback to Firebase Messaging check
        try {
          final messaging = FirebaseMessaging.instance;
          final settings = await messaging.getNotificationSettings();
          systemNotificationEnabled = settings.authorizationStatus ==
                  AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
        } catch (e2) {
          print('Error in Firebase fallback: $e2');
        }
      }
    }

    // Update state based on system permission (like WhatsApp - system permission is source of truth)
    if (mounted) {
      setState(() {
        _pushNotificationsEnabled = systemNotificationEnabled;
        _isLoadingNotificationStatus = false;
        _hasLoadedNotificationStatus = true;
      });
    }
  }



  String _getInviteMessage() {
    // Get current user's UID for personalized referral link
    final userUid = currentUserUid.isNotEmpty
        ? currentUserUid
        : (currentUserReference?.id ?? '');

    // Create personalized referral link
    final referralLink = 'https://lona.club/invite/$userUid';

    return 'Hey! I\'ve been using this app named Lona for communication, and it\'s amazing! It really boosts productivity and makes team collaboration so much easier. You should check it out!\n\nJoin me on Lona: $referralLink';
  }

  Future<void> _shareInviteMessage() async {
    // Open native iOS share sheet
    final size = MediaQuery.of(context).size;
    final sharePositionOrigin = Rect.fromLTWH(
      size.width / 2 - 100,
      size.height / 2,
      200,
      100,
    );

    await Share.share(
      _getInviteMessage(),
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  void _showInviteDialog() async {
    // Show iOS 26+ adaptive dialog with invite options (iOS 26+ liquid glass effect)
    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Invite Friends',
      message:
          'Share Lona with your friends and boost your team\'s productivity together!',
      icon: 'person.2.fill',
      actions: [
        AlertAction(
          title: 'Cancel',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Share',
          style: AlertActionStyle.primary,
          onPressed: () {
            _shareInviteMessage();
          },
        ),
      ],
    );
  }

  void _showInviteOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          'Invite Friend',
          style: TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showEmailInviteDialog();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.mail,
                  color: CupertinoColors.activeBlue,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Email Invite',
                  style: TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: CupertinoColors.activeBlue,
                  ),
                ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showInviteDialog();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.share,
                  color: CupertinoColors.activeBlue,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Share',
                  style: TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: CupertinoColors.activeBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontFamily: '.SF Pro Text',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.activeBlue,
            ),
          ),
        ),
      ),
    );
  }

  void _showEmailInviteDialog() {
    final emailController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text('Invite via Email'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: CupertinoTextField(
            controller: emailController,
            placeholder: 'Recipient Email',
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text('Send Invite'),
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid email address'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }
              Navigator.pop(dialogContext);

              try {
                final userUid = currentUserUid.isNotEmpty
                    ? currentUserUid
                    : (currentUserReference?.id ?? '');
                final referralLink = 'https://lona.club/invite/$userUid';

                await actions.sendResendInvite(
                  email: email,
                  senderName: currentUserDisplayName,
                  referralLink: referralLink,
                );

                // Show success feedback
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Invite sent successfully!'),
                      backgroundColor: Color(0xFF34C759),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to send invite. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedSetting.isEmpty,
      onPopInvoked: (bool didPop) {
        if (!didPop && _selectedSetting.isNotEmpty) {
          // If we're in a sub-page, go back to main settings instead of popping the entire page
          setState(() {
            _selectedSetting = '';
            _openInEditMode = false;
          });
        }
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          // Absorb all scroll notifications to prevent tab bar from minimizing/blurring
          return true;
        },
        child: CupertinoPageScaffold(
          backgroundColor: CupertinoColors.systemGroupedBackground,
          child: SafeArea(
            top: _selectedSetting.isEmpty ? true : false,
            child: _selectedSetting.isEmpty
                ? Column(
                    children: [
                      // iOS-style Header
                      _buildIOSHeader(),
                      // Main Content - cover photo positioned directly below Settings
                      Expanded(
                        child: _buildMainContent(),
                      ),
                    ],
                  )
                : _buildMainContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildIOSHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Large Title - iOS style
          Text(
            'Settings',
            style: CupertinoTheme.of(context)
                .textTheme
                .navLargeTitleTextStyle
                .copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    // Show content based on selected setting
    switch (_selectedSetting) {
      case 'Personal Information':
        return _buildPersonalInformationContent();
      case 'Translation':
        return _buildTranslationContent();
      case 'Notifications':
        // Refresh notification settings when opening notifications page (only if not already loaded)
        if (!_hasLoadedNotificationStatus && !_isLoadingNotificationStatus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadNotificationSettings();
          });
        }
        return _buildNotificationsContent();
      case 'Privacy & Security':
        return _buildPrivacySecurityContent();
      case 'FAQs':
        return _buildFAQsContent();
      case 'Contact Support':
        return _buildContactSupportContent();
      default:
        return _buildMainSettingsPage();
    }
  }

  Widget _buildMainSettingsPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Cover Photo Section - positioned directly below Settings header
          _buildCoverPhotoSection(),
          // Profile Header Section
          _buildProfileHeader(),
          Transform.translate(
            offset: Offset(0, -50), // Move settings list up
            child: _buildSettingsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // iOS Header with Back Button
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
            child: Row(
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.chevron_back, size: 24),
                      Text('Settings', style: TextStyle(fontSize: 17)),
                    ],
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedSetting = '';
                    });
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Text(
              'Translation',
              style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
            ),
          ),
          
          // Language Section
          _buildSectionHeader('TARGET LANGUAGE'),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildLanguageItem('System Default', 'system'),
                _buildDivider(),
                _buildLanguageItem('English', 'en'),
                _buildDivider(),
                _buildLanguageItem('Spanish', 'es'),
                _buildDivider(),
                _buildLanguageItem('French', 'fr'),
                _buildDivider(),
                _buildLanguageItem('German', 'de'),
                _buildDivider(),
                _buildLanguageItem('Chinese (Simplified)', 'zh-cn'),
                _buildDivider(),
                _buildLanguageItem('Chinese (Traditional)', 'zh-tw'),
                _buildDivider(),
                _buildLanguageItem('Japanese', 'ja'),
                _buildDivider(),
                _buildLanguageItem('Korean', 'ko'),
                _buildDivider(),
                _buildLanguageItem('Italian', 'it'),
                _buildDivider(),
                _buildLanguageItem('Portuguese (Brazil)', 'pt-br'),
                _buildDivider(),
                _buildLanguageItem('Portuguese (Portugal)', 'pt-pt'),
                _buildDivider(),
                _buildLanguageItem('Russian', 'ru'),
              ],
            ),
          ),

          // Auto-Translate Section
          _buildSectionHeader('PREFERENCES'),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: _buildSwitchItem(
              'Auto-Translate',
              FFAppState().autoTranslate,
              (value) {
                setState(() {
                  FFAppState().autoTranslate = value;
                });
              },
            ),
          ),
          
          Padding(
             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
             child: Text(
               'When enabled, incoming messages in other languages will be automatically translated to your target language.',
               style: TextStyle(
                 color: Color(0xFF8E8E93),
                 fontSize: 13,
               ),
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Color(0xFF8E8E93),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Color(0xFFE5E5EA), indent: 16);
  }

  Widget _buildLanguageItem(String name, String code) {
    final isSelected = FFAppState().translateLanguage == code;
    return GestureDetector(
      onTap: () {
        setState(() {
          FFAppState().translateLanguage = code;
        });
      },
      child: Container(
        color: Colors.transparent, // For proper touch detection
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 17,
                color: Colors.black,
              ),
            ),
            if (isSelected)
              Icon(CupertinoIcons.checkmark, color: CupertinoColors.activeBlue, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem(String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              color: Colors.black,
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: CupertinoColors.activeBlue,
          ),
        ],
      ),
    );
  }

  String? _getCoverPhotoUrl(UsersRecord? user) {
    if (user == null) return null;
    final userData = user.snapshotData;
    return userData['cover_photo_url'] as String?;
  }

  Widget _buildCoverPhoto(String? coverPhotoUrl) {
    if (coverPhotoUrl != null && coverPhotoUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: coverPhotoUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => _buildDefaultGradient(),
        errorWidget: (context, url, error) => _buildDefaultGradient(),
      );
    }
    return _buildDefaultGradient();
  }

  Widget _buildDefaultGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0077B5), // LinkedIn blue
            Color(0xFF004182),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPhotoSection() {
    return FutureBuilder<UsersRecord?>(
      future: currentUserReference != null
          ? UsersRecord.getDocumentOnce(currentUserReference!)
          : Future.value(null),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final coverPhotoUrl = _getCoverPhotoUrl(user);

        return Container(
          height: 200,
          width: double.infinity,
          child: _buildCoverPhoto(coverPhotoUrl),
        );
      },
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          // Profile Picture - Overlapping the cover photo
          Transform.translate(
            offset: Offset(0, -55), // Overlap with cover photo
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 65,
                    backgroundColor: Color(0xFFF2F2F7),
                    child: currentUserPhoto.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: currentUserPhoto,
                              width: 130,
                              height: 130,
                              fit: BoxFit.cover,
                            ),
                          )
                        : null,
                  ),
                  // Pencil edit icon button
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _openInEditMode = true;
                          _selectedSetting = 'Personal Information';
                        });
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Color(0xFFE5E7EB),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          CupertinoIcons.pencil,
                          size: 16,
                          color: CupertinoColors.systemBlue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(0, -50), // Move name and email up
            child: Column(
              children: [
                // User Name
                Text(
                  currentUserDisplayName.isNotEmpty
                      ? currentUserDisplayName
                      : 'User',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
                SizedBox(height: 4),
                // User Role/Email
                Text(
                  currentUserEmail.isNotEmpty ? currentUserEmail : 'Member',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 16,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: Offset(0, -60), // Move Invite Friend button and settings up
            child: Column(
              children: [
                SizedBox(height: 24),
                // Invite Friend Button with Dropdown
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    color: Color(0xFF007AFF),
                    borderRadius: BorderRadius.circular(12),
                    onPressed: () {
                      _showInviteOptions();
                    },
                    child: Text(
                      'Invite Friend',
                      style: TextStyle(
                        fontFamily: '.SF Pro Text',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList() {
    final settingsItems = [
      {
        'icon': Icons.translate_rounded,
        'label': 'Translation',
        'page': 'Translation',
        'color': Color(0xFF8E8E93),
      },
      {
        'icon': Icons.notifications_outlined,
        'label': 'Notifications',
        'page': 'Notifications',
        'color': Color(0xFF8E8E93),
        'hasBadge': true,
        'badgeCount': 2,
      },
      {
        'icon': Icons.security_outlined,
        'label': 'Privacy & Security',
        'page': 'Privacy & Security',
        'color': Color(0xFF8E8E93),
      },
      {
        'icon': Icons.support_agent_outlined,
        'label': 'Contact Support',
        'page': 'Contact Support',
        'color': Color(0xFF8E8E93),
      },
      {
        'icon': Icons.help_outline_rounded,
        'label': 'FAQs',
        'page': 'FAQs',
        'color': Color(0xFF8E8E93),
      },
      {
        'icon': Icons.logout,
        'label': 'Log Out',
        'page': 'LogOut',
        'color': Color(0xFFFF3B30),
        'isLogout': true,
      },
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: settingsItems.map((item) {
          return Container(
            margin: EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                if (item['page'] == 'LogOut') {
                  _showLogoutDialog();
                } else {
                  setState(() {
                    _selectedSetting = item['page'] as String;
                  });
                }
              },
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      color: item['color'] as Color,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontFamily: 'System',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: item['isLogout'] == true
                              ? Color(0xFFFF3B30)
                              : Color(0xFF1D1D1F),
                        ),
                      ),
                    ),
                    if (item['hasBadge'] == true)
                      Container(
                        margin: EdgeInsets.only(right: 8),
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(0xFFFF3B30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${item['badgeCount']}',
                          style: TextStyle(
                            fontFamily: 'System',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    Icon(
                      Icons.chevron_right,
                      color: Color(0xFF8E8E93),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Log Out',
            style: TextStyle(
              fontFamily: 'System',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1D1F),
            ),
          ),
          content: Text(
            'Are you sure you want to log out?',
            style: TextStyle(
              fontFamily: 'System',
              fontSize: 16,
              color: Color(0xFF1D1D1F),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'System',
                  fontSize: 16,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Implement logout functionality
                try {
                  await authManager.signOut();
                  if (context.mounted) {
                    context.goNamedAuth('Welcome', context.mounted);
                  }
                } catch (e) {
                  // Show error message if logout fails
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to log out: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Log Out',
                style: TextStyle(
                  fontFamily: 'System',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF3B30),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBackButtonHeader(String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedSetting = '';
              });
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Color(0xFF1D1D1F),
                size: 18,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'System',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D1D1F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInformationContent() {
    return Column(
      children: [
        // Back Button Header
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            bottom: 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedSetting = '';
                    _openInEditMode =
                        false; // Reset edit mode when navigating back
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    color: Color(0xFF1D1D1F),
                    size: 18,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Personal Information',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
              ),
            ],
          ),
        ),
        // User Summary Widget - Only owner can edit
        Expanded(
          child: currentUserReference != null
              ? Builder(
                  builder: (context) {
                    // Reset edit mode flag after widget is built
                    if (_openInEditMode) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _openInEditMode = false;
                          });
                        }
                      });
                    }
                    return UserSummaryWidget(
                      userRef: currentUserReference,
                      isEditable: true, // Only owner can edit their own account
                      initialEditMode: _openInEditMode,
                    );
                  },
                )
              : Center(
                  child: Text('Please log in to view your profile'),
                ),
        ),
      ],
    );
  }

  Future<void> _showPhotoOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Profile Photo',
                style: TextStyle(
                  fontFamily: 'System',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D1D1F),
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPhotoOption(
                    icon: Icons.camera_alt,
                    label: 'Take Photo',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildPhotoOption(
                    icon: Icons.photo_library,
                    label: 'Choose from Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  if (currentUserPhoto.isNotEmpty)
                    _buildPhotoOption(
                      icon: Icons.delete,
                      label: 'Remove Photo',
                      onTap: () {
                        Navigator.pop(context);
                        _deletePhoto();
                      },
                      isDestructive: true,
                    ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotoOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDestructive
              ? Color(0xFFFF3B30).withOpacity(0.1)
              : Color(0xFF007AFF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDestructive ? Color(0xFFFF3B30) : Color(0xFF007AFF),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isDestructive ? Color(0xFFFF3B30) : Color(0xFF007AFF),
              size: 24,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'System',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDestructive ? Color(0xFFFF3B30) : Color(0xFF007AFF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        await _uploadPhoto(image);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadPhoto(XFile imageFile) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Upload to Firebase Storage
      final String fileName =
          'profile_photos/${currentUserReference!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = FirebaseStorage.instance.ref().child(fileName);

      await ref.putFile(File(imageFile.path));
      final String downloadUrl = await ref.getDownloadURL();

      // Update user document with new photo URL
      await currentUserReference!.update({
        'photo_url': downloadUrl,
      });

      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile photo updated successfully'),
          backgroundColor: Color(0xFF34C759),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deletePhoto() async {
    try {
      // Show confirmation dialog
      bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              'Remove Profile Photo',
              style: TextStyle(
                fontFamily: 'System',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D1D1F),
              ),
            ),
            content: Text(
              'Are you sure you want to remove your profile photo?',
              style: TextStyle(
                fontFamily: 'System',
                fontSize: 14,
                color: Color(0xFF8E8E93),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 16,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Remove',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF3B30),
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (confirmed == true) {
        // Update user document to remove photo URL
        await currentUserReference!.update({
          'photo_url': '',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile photo removed successfully'),
            backgroundColor: Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildNotificationsContent() {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground,
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator,
            width: 0.5,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            setState(() {
              _selectedSetting = '';
            });
          },
          child: Icon(
            CupertinoIcons.chevron_left,
            color: CupertinoColors.activeBlue,
            size: 28,
          ),
        ),
        middle: Text(
          'Notifications',
          style: TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label,
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 24),
            // Single Notification Option
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _buildIOSSection(
                header: 'NOTIFICATIONS',
                footer:
                    'You will receive notifications for new messages, connection requests, and other updates.',
                children: [
                  _isLoadingNotificationStatus
                      ? Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Center(
                            child: CupertinoActivityIndicator(
                              radius: 12,
                            ),
                          ),
                        )
                      : _buildIOSNotificationTile(
                          title: 'Allow Notifications',
                          subtitle: _pushNotificationsEnabled
                              ? 'Notifications enabled'
                              : 'Notifications disabled',
                          value: _pushNotificationsEnabled,
                          onChanged: (value) =>
                              _handlePushNotificationsToggle(value),
                        ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
          ],
        ),
      ),
    );
  }

  Widget _buildIOSNotificationTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => onChanged(!value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: '.SF Pro Text',
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: CupertinoColors.label,
                      letterSpacing: -0.41,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: '.SF Pro Text',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: CupertinoColors.secondaryLabel,
                      letterSpacing: -0.24,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            PlatformInfo.isIOS26OrHigher()
                ? AdaptiveSwitch(
                    value: value,
                    onChanged: onChanged,
                  )
                : CupertinoSwitch(
                    value: value,
                    onChanged: onChanged,
                    activeColor: CupertinoColors.activeBlue,
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePushNotificationsToggle(bool newValue) async {
    if (newValue) {
      // Turning ON - Request system notification permission
      bool permissionGranted = false;

      if (kIsWeb) {
        // For web, we can't request permissions here
        permissionGranted = false;
      } else if (Platform.isMacOS || Platform.isIOS) {
        // Check current system permission status first
        try {
          final currentStatus = await Permission.notification.status;

          // If already granted, just enable
          if (currentStatus.isGranted) {
            permissionGranted = true;
          }
          // If not determined, request permission (will show system dialog)
          else if (currentStatus.isDenied) {
            final result = await Permission.notification.request();
            permissionGranted = result.isGranted;

            // Also request Firebase Messaging permission
            if (permissionGranted) {
              try {
                await FirebaseMessaging.instance.requestPermission(
                  alert: true,
                  badge: true,
                  sound: true,
                  provisional: false,
                  announcement: false,
                  carPlay: false,
                  criticalAlert: false,
                );
              } catch (e) {
                print('Error requesting Firebase permission: $e');
              }
            }
          }
          // If permanently denied, open system settings
          else if (currentStatus.isPermanentlyDenied) {
            await openAppSettings();
            if (mounted) {
              showCupertinoDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: Text('Enable Notifications'),
                  content: Text(
                    'Please enable notifications in System Settings > Notifications > Lona Club.',
                  ),
                  actions: [
                    CupertinoDialogAction(
                      child: Text('OK'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            }
            permissionGranted = false;
          }
        } catch (e) {
          print('Error requesting notification permission: $e');
          // Fallback to Firebase Messaging
          try {
            final messaging = FirebaseMessaging.instance;
            final currentSettings = await messaging.getNotificationSettings();

            if (currentSettings.authorizationStatus ==
                    AuthorizationStatus.authorized ||
                currentSettings.authorizationStatus ==
                    AuthorizationStatus.provisional) {
              permissionGranted = true;
            } else if (currentSettings.authorizationStatus ==
                AuthorizationStatus.notDetermined) {
              final settings = await messaging.requestPermission(
                alert: true,
                badge: true,
                sound: true,
                provisional: false,
                announcement: false,
                carPlay: false,
                criticalAlert: false,
              );
              permissionGranted = settings.authorizationStatus ==
                      AuthorizationStatus.authorized ||
                  settings.authorizationStatus ==
                      AuthorizationStatus.provisional;
            } else {
              await openAppSettings();
              permissionGranted = false;
            }
          } catch (e2) {
            print('Error in Firebase fallback: $e2');
            permissionGranted = false;
          }
        }
      }

      // Refresh status from system after permission request
      await _loadNotificationSettings();

      // Update Firestore to reflect system permission
      if (currentUserReference != null && mounted) {
        try {
          await currentUserReference!.update({
            'notifications_enabled': _pushNotificationsEnabled,
          });
        } catch (e) {
          print('Error updating Firestore: $e');
        }
      }
    } else {
      // Turning OFF - Open system settings (like WhatsApp, you can't disable from app)
      // Show dialog explaining user needs to disable in system settings
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('Disable Notifications'),
            content: Text(
              'To disable notifications, please go to System Settings > Notifications > Lona Club and turn off notifications.',
            ),
            actions: [
              CupertinoDialogAction(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: Text('Open Settings'),
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
              ),
            ],
          ),
        );
      }

      // Refresh status after user potentially changes settings
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) {
          _loadNotificationSettings();
        }
      });
    }
  }

  Widget _buildPrivacySecurityContent() {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground,
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator,
            width: 0.5,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            setState(() {
              _selectedSetting = '';
            });
          },
          child: Icon(
            CupertinoIcons.chevron_left,
            color: CupertinoColors.activeBlue,
            size: 28,
          ),
        ),
        middle: Text(
          'Privacy & Security',
          style: TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label,
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            // Legal & Policies Section
            _buildIOSSection(
              header: 'LEGAL & POLICIES',
              footer:
                  'Review our terms and policies to understand how we protect your data.',
              children: [
                _buildIOSListTile(
                  icon: CupertinoIcons.lock_shield_fill,
                  iconColor: Color(0xFF007AFF),
                  title: 'Privacy Policy',
                  onTap: () {
                    context.pushNamed(
                      TermsPrivacyWidget.routeName,
                      queryParameters: {
                        'isTerm': serializeParam(false, ParamType.bool),
                      }.withoutNulls,
                    );
                  },
                ),
                _buildIOSListTile(
                  icon: CupertinoIcons.doc_text_fill,
                  iconColor: Color(0xFF34C759),
                  title: 'Terms of Service',
                  onTap: () {
                    context.pushNamed(
                      TermsPrivacyWidget.routeName,
                      queryParameters: {
                        'isTerm': serializeParam(true, ParamType.bool),
                      }.withoutNulls,
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: 32),
            // Danger Zone Section
            _buildIOSSection(
              header: 'DANGER ZONE',
              footer:
                  'Deleting your account is permanent. All your data, messages, and connections will be permanently removed and cannot be recovered.',
              isDanger: true,
              children: [
                _buildIOSListTile(
                  icon: CupertinoIcons.trash_fill,
                  iconColor: Color(0xFFFF3B30),
                  title: 'Delete Account',
                  titleColor: Color(0xFFFF3B30),
                  onTap: () {
                    showCupertinoDialog(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: Text('Delete Account'),
                        content: Text(
                          'Are you sure you want to delete your account? This action cannot be undone.',
                        ),
                        actions: [
                          CupertinoDialogAction(
                            isDefaultAction: true,
                            child: Text('Cancel'),
                            onPressed: () => Navigator.pop(context),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            child: Text('Delete'),
                            onPressed: () {
                              Navigator.pop(context);
                              showDialog(
                                context: context,
                                builder: (context) => DeleteAccountWidget(),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
          ],
        ),
      ),
    );
  }

  Widget _buildIOSSection({
    required String header,
    String? footer,
    required List<Widget> children,
    bool isDanger = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              header,
              style: TextStyle(
                fontFamily: '.SF Pro Text',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isDanger
                    ? Color(0xFFFF3B30)
                    : CupertinoColors.secondaryLabel,
                letterSpacing: -0.08,
              ),
            ),
          ),
          // List Container
          Container(
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: List.generate(children.length * 2 - 1, (index) {
                if (index.isOdd) {
                  return Padding(
                    padding: EdgeInsets.only(left: 52),
                    child: Container(
                      height: 0.5,
                      color: CupertinoColors.separator,
                    ),
                  );
                }
                return children[index ~/ 2];
              }),
            ),
          ),
          // Footer
          if (footer != null)
            Padding(
              padding: EdgeInsets.only(left: 16, top: 8, right: 16),
              child: Text(
                footer,
                style: TextStyle(
                  fontFamily: '.SF Pro Text',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: isDanger
                      ? Color(0xFFFF3B30).withOpacity(0.8)
                      : CupertinoColors.secondaryLabel,
                  letterSpacing: -0.08,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIOSListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                color: CupertinoColors.white,
                size: 16,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: '.SF Pro Text',
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: titleColor ?? CupertinoColors.label,
                  letterSpacing: -0.41,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.tertiaryLabel,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQsContent() {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 0.5,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            setState(() {
              _selectedSetting = '';
            });
          },
          child: Icon(
            Icons.arrow_back_outlined,
            color: Color(0xFF1D1D1F),
            size: 24.0,
          ),
        ),
        middle: Text(
          'FAQs',
          style: TextStyle(
            fontFamily: 'System',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1D1D1F),
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Content
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SummerAI FAQs
                    _buildFAQItem(
                      'What is SummerAI?',
                      'SummerAI is your AI personal project manager that automatically analyzes group chat conversations, detects tasks, prioritizes action items, and generates comprehensive daily summaries. It helps you stay on top of discussions, track important topics, and never miss critical information.',
                    ),
                    SizedBox(height: 16),
                    _buildFAQItem(
                      'How does SummerAI generate summaries?',
                      'SummerAI analyzes all messages from the past 24 hours in your group chats. It identifies key topics, extracts action items, notes who was involved in discussions, and provides insightful observations. The summaries are automatically generated daily at 9 AM EST, or you can manually trigger them anytime.',
                    ),
                    SizedBox(height: 16),
                    _buildFAQItem(
                      'What information does SummerAI include in summaries?',
                      'Each summary includes: topic names with priority levels (High/Medium/Low), details of what was discussed, action items and follow-ups, names of actively involved participants, SummerAI\'s personal insights and observations, and useful links from web searches related to the topics.',
                    ),
                    SizedBox(height: 16),
                    _buildFAQItem(
                      'How do I trigger a SummerAI summary manually?',
                      'In any group chat, you can manually request a summary by tapping the summary button or mentioning SummerAI. The AI will analyze the last 24 hours of conversation and generate a comprehensive summary on demand.',
                    ),
                    SizedBox(height: 16),
                    _buildFAQItem(
                      'Does SummerAI analyze all messages?',
                      'SummerAI only analyzes real user messages and automatically filters out AI-generated messages. This ensures summaries focus on actual human conversations and provide accurate insights into your team\'s discussions.',
                    ),
                    SizedBox(height: 16),
                    _buildFAQItem(
                      'How does SummerAI prioritize topics?',
                      'SummerAI automatically assigns priority levels based on topic type: Technical and Business/Professional topics get High or Medium priority, while Casual/Social topics receive Low priority. This helps you quickly identify what needs immediate attention.',
                    ),
                    SizedBox(height: 16),
                    _buildFAQItem(
                      'Can SummerAI detect tasks and action items?',
                      'Yes! SummerAI automatically identifies tasks, decisions, and follow-ups mentioned in conversations. It extracts action items and presents them clearly in summaries, helping you track what needs to be done without manually reviewing all messages.',
                    ),
                    SizedBox(height: 16),
                    // Chat FAQs
                    _buildFAQItem(
                      'How do I create a group chat?',
                      'In the Chat page, tap the "+" button in the top right corner, select "New Group", enter a group name and select members. Group chats support text, images, videos, voice messages, and file attachments.',
                    ),
                    SizedBox(height: 16),
                    _buildFAQItem(
                      'How do I send different types of messages?',
                      'In any chat, you can send text messages, photos from your gallery, take photos, record voice messages, and attach files. Use the attachment button next to the message input to access all media options.',
                    ),
                    SizedBox(height: 16),
                    // Connections FAQs
                    _buildFAQItem(
                      'How do I connect with other users?',
                      'In the "Connections" page, you can search and browse other users. Tap the "Connect" button on a user\'s card to send a connection request. Once accepted, you can message each other.',
                    ),
                    SizedBox(height: 16),
                    _buildFAQItem(
                      'How do I manage connection requests?',
                      'In the "Connections" page, you can view incoming connection requests. Tap "Accept" or "Decline" to handle requests. Accepted connections will appear in your connections list.',
                    ),
                    SizedBox(height: 16),
                    // Gmail FAQs
                    _buildFAQItem(
                      'How do I connect my Gmail account?',
                      'In the Gmail page, tap "Connect Gmail" and follow the prompts to authorize your Google account. Once connected, you can view and send emails directly within the app without switching applications.',
                    ),
                    SizedBox(height: 16),
                    _buildFAQItem(
                      'What features does Gmail integration support?',
                      'After connecting Gmail, you can view inbox emails, send new emails, reply to messages, and manage email attachments. All operations are completed within the Lona app, keeping your workflow centralized.',
                    ),
                    SizedBox(height: 16),
                    // General FAQs
                    _buildFAQItem(
                      'How do I manage notification settings?',
                      'In Settings, go to "Notifications" to enable or disable push notifications, email notifications, chat message notifications, and other notification types. Customize your preferences based on your needs.',
                    ),
                    SizedBox(height: 16),
                    _buildFAQItem(
                      'How do I update my profile information?',
                      'In Settings, tap your profile picture or go to "Personal Information" to edit your name, email, profile photo, and cover photo. This information will be displayed on your profile.',
                    ),
                    SizedBox(height: 16),
                    _buildFAQItem(
                      'How do I invite friends to use Lona?',
                      'In Settings, tap the "Invite Friend" button to share an invite link through your device\'s sharing options. Inviting friends helps grow your network and makes collaboration smoother.',
                    ),
                    SizedBox(height: 16),
                    _buildFAQItem(
                      'How do I delete my account?',
                      'In Settings, go to "Privacy & Security" and find the "Delete Account" option. Please note that deleting your account is irreversible and will permanently remove all your data.',
                    ),
                    SizedBox(height: 16),
                    _buildFAQItem(
                      'Is my data secure and private?',
                      'Yes, Lona uses industry-standard encryption and security practices. Your messages, files, and personal information are protected. You can review our Privacy Policy in Settings under "Privacy & Security" for more details.',
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

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontFamily: 'System',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1D1F),
            ),
          ),
          SizedBox(height: 8),
          Text(
            answer,
            style: TextStyle(
              fontFamily: 'System',
              fontSize: 14,
              color: Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSupportContent() {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 0.5,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            setState(() {
              _selectedSetting = '';
            });
          },
          child: Icon(
            Icons.arrow_back_outlined,
            color: Color(0xFF1D1D1F),
            size: 24.0,
          ),
        ),
        middle: Text(
          'Contact Support',
          style: TextStyle(
            fontFamily: 'System',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1D1D1F),
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 40),
                // Support Icon
                Container(
                  width: 120.0,
                  height: 120.0,
                  decoration: BoxDecoration(
                    color: Color(0xFF007AFF).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.support_agent,
                    color: Color(0xFF007AFF),
                    size: 60.0,
                  ),
                ),
                SizedBox(height: 24),
                // Company Name
                Text(
                  'TechFlow Solutions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
                SizedBox(height: 16),
                // Description
                Text(
                  'We\'re here to help you with any questions or issues you may have. Our support team is dedicated to providing you with the best assistance possible.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 16,
                    color: Color(0xFF8E8E93),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 32),
                // Email Support Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: Color(0xFFE5E7EB),
                      width: 1.0,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Container(
                          width: 50.0,
                          height: 50.0,
                          decoration: BoxDecoration(
                            color: Color(0xFF007AFF).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.email_outlined,
                            color: Color(0xFF007AFF),
                            size: 24.0,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email Support',
                                style: TextStyle(
                                  fontFamily: 'System',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1D1D1F),
                                ),
                              ),
                              SizedBox(height: 4),
                              GestureDetector(
                                onTap: () async {
                                  final Uri emailUri = Uri(
                                    scheme: 'mailto',
                                    path: 'support@linkedup.club',
                                    query: {
                                      'subject': 'Contact for help',
                                      'body': 'More',
                                    }
                                        .entries
                                        .map((e) =>
                                            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
                                        .join('&'),
                                  );
                                  if (await canLaunchUrl(emailUri)) {
                                    await launchUrl(emailUri);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Unable to open email'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                child: Text(
                                  'support@linkedup.club',
                                  style: TextStyle(
                                    fontFamily: 'System',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF007AFF),
                                  ),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'We typically respond within 24 hours',
                                style: TextStyle(
                                  fontFamily: 'System',
                                  fontSize: 14,
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
                SizedBox(height: 24),
                // Phone Support Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: Color(0xFFE5E7EB),
                      width: 1.0,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Container(
                          width: 50.0,
                          height: 50.0,
                          decoration: BoxDecoration(
                            color: Color(0xFF007AFF).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.phone_outlined,
                            color: Color(0xFF007AFF),
                            size: 24.0,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Phone Support',
                                style: TextStyle(
                                  fontFamily: 'System',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1D1D1F),
                                ),
                              ),
                              SizedBox(height: 4),
                              GestureDetector(
                                onTap: () async {
                                  final Uri phoneUri = Uri(
                                    scheme: 'tel',
                                    path: '(516) 912-2147',
                                  );
                                  if (await canLaunchUrl(phoneUri)) {
                                    await launchUrl(phoneUri);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Unable to make phone call'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                child: Text(
                                  '(516) 912-2147',
                                  style: TextStyle(
                                    fontFamily: 'System',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF007AFF),
                                  ),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Monday - Friday, 9 AM - 6 PM EST',
                                style: TextStyle(
                                  fontFamily: 'System',
                                  fontSize: 14,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
