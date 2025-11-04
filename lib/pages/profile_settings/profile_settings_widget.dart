import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/backend/push_notifications/push_notifications_util.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:math';
import '/index.dart';
import 'profile_settings_model.dart';

class ProfileSettingsWidget extends StatefulWidget {
  const ProfileSettingsWidget({super.key});

  @override
  State<ProfileSettingsWidget> createState() => _ProfileSettingsWidgetState();
}

class _ProfileSettingsWidgetState extends State<ProfileSettingsWidget> {
  late ProfileSettingsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Notification settings state
  bool _notificationsEnabled = true;
  bool _newMessageEnabled = true;
  bool _emailNotificationsEnabled = true;
  bool _eventRemindersEnabled = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileSettingsModel());
    _model.selectedSetting = 'Personal Information';
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    if (currentUserDocument != null) {
      setState(() {
        _notificationsEnabled = currentUserDocument!.notificationsEnabled;
        _newMessageEnabled = currentUserDocument!.newMessageEnabled;
        // Email notifications default to true (field doesn't exist yet in schema)
        _emailNotificationsEnabled = true;
        // Event reminders uses notifications_enabled
        _eventRemindersEnabled = currentUserDocument!.notificationsEnabled;
      });
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _model.unfocusNode.canRequestFocus
          ? FocusScope.of(context).requestFocus(_model.unfocusNode)
          : FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          top: true,
          child: Row(
            children: [
              // Left Sidebar - Settings Navigation
              _buildSettingsSidebar(),

              // Right Content Area
              Expanded(
                child: _buildSettingsContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSidebar() {
    final settingsItems = [
      {
        'icon': Icons.person_outline_rounded,
        'label': 'Personal Information',
        'page': 'Personal Information',
      },
      {
        'icon': Icons.notifications_outlined,
        'label': 'Notifications',
        'page': 'Notifications',
      },
      {
        'icon': Icons.support_agent_outlined,
        'label': 'Contact Support',
        'page': 'Contact Support',
      },
      {
        'icon': Icons.security_outlined,
        'label': 'Privacy & Security',
        'page': 'Privacy & Security',
      },
      {
        'icon': Icons.help_outline_rounded,
        'label': 'FAQs',
        'page': 'FAQs',
      },
      {
        'icon': Icons.business_outlined,
        'label': 'Workspace Management',
        'page': 'Workspace Management',
      },
    ];

    return Container(
      width: 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Color(0xFF374151),
        border: Border(
          right: BorderSide(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Color(0xFF374151),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.settings_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Profile Settings',
                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: Colors.white,
                      ),
                ),
              ],
            ),
          ),

          // Settings List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 8),
              itemCount: settingsItems.length,
              itemBuilder: (context, index) {
                final item = settingsItems[index];
                final isSelected = _model.selectedSetting == item['page'];

                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _model.selectedSetting = item['page'] as String;
                      });
                    },
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(
                                color: Colors.white,
                                width: 1,
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item['icon'] as IconData,
                            color: isSelected
                                ? Colors.black
                                : Colors.white.withOpacity(0.7),
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item['label'] as String,
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    letterSpacing: 0,
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white.withOpacity(0.7),
                                  ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.black,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent() {
    return Container(
      padding: EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content Header
          Row(
            children: [
              Icon(
                _getSettingIcon(_model.selectedSetting),
                color: FlutterFlowTheme.of(context).secondaryText,
                size: 28,
              ),
              SizedBox(width: 16),
              Text(
                _model.selectedSetting,
                style: FlutterFlowTheme.of(context).headlineMedium.override(
                      fontFamily: 'Inter',
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Content based on selected setting
          Expanded(
            child: _buildSettingContent(_model.selectedSetting),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingContent(String setting) {
    switch (setting) {
      case 'Personal Information':
        return _buildPersonalInformationContent();
      case 'Notifications':
        return _buildNotificationsContent();
      case 'Contact Support':
        return _buildContactSupportContent();
      case 'Privacy & Security':
        return _buildPrivacySecurityContent();
      case 'FAQs':
        return _buildFAQsContent();
      case 'Workspace Management':
        return _buildWorkspaceManagementContent();
      default:
        return _buildDefaultContent();
    }
  }

  Widget _buildPersonalInformationContent() {
    return StreamBuilder<UsersRecord>(
      stream: UsersRecord.getDocument(currentUserReference!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: FlutterFlowTheme.of(context).alternate,
                width: 1,
              ),
            ),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data!;

        // Initialize controllers with current user data if not already set
        if (_model.displayNameController?.text.isEmpty ?? true) {
          _model.displayNameController?.text = user.displayName;
        }
        if (_model.emailController?.text.isEmpty ?? true) {
          _model.emailController?.text = user.email;
        }
        if (_model.locationController?.text.isEmpty ?? true) {
          _model.locationController?.text = user.location;
        }

        return Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: FlutterFlowTheme.of(context).alternate,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Information',
                style: FlutterFlowTheme.of(context).titleLarge.override(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
              ),
              SizedBox(height: 16),
              Text(
                'Manage your personal details and profile information.',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
              ),
              SizedBox(height: 24),

              // Profile Photo Section
              Row(
                children: [
                  // Left side - Info cards
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _buildEditableInfoField(
                          'Display Name',
                          _model.displayNameController!,
                          Icons.person_outline,
                          enabled: _model.isEditingProfile,
                        ),
                        SizedBox(height: 16),
                        _buildEditableInfoField(
                          'Email',
                          _model.emailController!,
                          Icons.email_outlined,
                          enabled: false, // Email cannot be changed
                        ),
                        SizedBox(height: 16),
                        _buildEditableInfoField(
                          'Location',
                          _model.locationController!,
                          Icons.location_on_outlined,
                          enabled: _model.isEditingProfile,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 24),

                  // Right side - Profile Photo
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        Text(
                          'Profile Photo',
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                  ),
                        ),
                        SizedBox(height: 12),
                        InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            context.pushNamed(EditProfileWidget.routeName);
                          },
                          child: Stack(
                            alignment: const AlignmentDirectional(1.0, 1.0),
                            children: [
                              AuthUserStreamWidget(
                                builder: (context) => Container(
                                  width: 120.0,
                                  height: 120.0,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                  ),
                                  child: CachedNetworkImage(
                                    fadeInDuration:
                                        const Duration(milliseconds: 500),
                                    fadeOutDuration:
                                        const Duration(milliseconds: 500),
                                    imageUrl: valueOrDefault<String>(
                                      currentUserPhoto,
                                      'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                                    ),
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      child: Icon(
                                        Icons.person,
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        size: 40,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      child: Icon(
                                        Icons.person,
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 30.0,
                                height: 30.0,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context).primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    width: 2.0,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap to upload photo',
                          style: FlutterFlowTheme.of(context)
                              .bodySmall
                              .override(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Spacer(),
                  if (!_model.isEditingProfile)
                    FFButtonWidget(
                      onPressed: () {
                        setState(() {
                          _model.isEditingProfile = true;
                        });
                      },
                      text: 'Edit Profile',
                      icon: Icon(Icons.edit_outlined, size: 16),
                      options: FFButtonOptions(
                        height: 44,
                        padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
                        iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 8, 0),
                        color: FlutterFlowTheme.of(context).primary,
                        textStyle:
                            FlutterFlowTheme.of(context).titleSmall.override(
                                  fontFamily: 'Inter',
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                        elevation: 0,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  if (_model.isEditingProfile) ...[
                    FFButtonWidget(
                      onPressed: () {
                        setState(() {
                          _model.isEditingProfile = false;
                        });
                      },
                      text: 'Cancel',
                      icon: Icon(Icons.close, size: 16),
                      options: FFButtonOptions(
                        height: 44,
                        padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
                        iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 8, 0),
                        color: FlutterFlowTheme.of(context).secondaryText,
                        textStyle:
                            FlutterFlowTheme.of(context).titleSmall.override(
                                  fontFamily: 'Inter',
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                        elevation: 0,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    SizedBox(width: 12),
                    FFButtonWidget(
                      onPressed: () async {
                        // Save the changes
                        await user.reference.update({
                          'display_name': _model.displayNameController?.text ??
                              user.displayName,
                          'location':
                              _model.locationController?.text ?? user.location,
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Profile updated successfully')),
                        );
                        setState(() {
                          _model.isEditingProfile = false;
                        });
                      },
                      text: 'Save',
                      icon: Icon(Icons.check, size: 16),
                      options: FFButtonOptions(
                        height: 44,
                        padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
                        iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 8, 0),
                        color: Colors.green,
                        textStyle:
                            FlutterFlowTheme.of(context).titleSmall.override(
                                  fontFamily: 'Inter',
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                        elevation: 0,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationsContent() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notification Settings',
            style: FlutterFlowTheme.of(context).titleLarge.override(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
          ),
          SizedBox(height: 16),
          Text(
            'Customize how you receive notifications.',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
          ),
          SizedBox(height: 24),
          _buildNotificationToggle('Push Notifications', _notificationsEnabled),
          SizedBox(height: 16),
          _buildNotificationToggle(
              'Email Notifications', _emailNotificationsEnabled),
          SizedBox(height: 16),
          _buildNotificationToggle('New Message Alerts', _newMessageEnabled),
          SizedBox(height: 16),
          _buildNotificationToggle('Event Reminders', _eventRemindersEnabled),
          SizedBox(height: 24),
          FFButtonWidget(
            onPressed: () async {
              print('🔍 PROFILE SETTINGS BUTTON PRESSED!');
              try {
                triggerPushNotification(
                  notificationTitle: '🔔 Test Push Notification',
                  notificationText:
                      'This is a test push notification from Profile Settings!',
                  notificationSound: 'default',
                  userRefs: [currentUserReference!],
                  initialPageName: 'ProfileSettings',
                  parameterData: {},
                );

                // DEBUG: Check currentUserReference
                print(
                    '🔍 DEBUG: currentUserReference = ${currentUserReference}');
                print('🔍 DEBUG: User ID = ${currentUserReference?.id}');

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        '✅ Push notification triggered! Check your device in a few seconds...'),
                    duration: Duration(seconds: 4),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error sending push notification: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
            text: '🔔 Test Push Notification',
            options: FFButtonOptions(
              height: 44,
              padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
              color: Color(0xFF10B981),
              textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
              elevation: 0,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSupportContent() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Support',
            style: FlutterFlowTheme.of(context).titleLarge.override(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
          ),
          SizedBox(height: 16),
          Text(
            'Get help and support from our team.',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
          ),
          SizedBox(height: 24),
          InkWell(
            onTap: () async {
              context.pushNamed(ContactWidget.routeName);
            },
            child: _buildSupportCard(
                'Email Support', 'support@linkedup.com', Icons.email_outlined),
          ),
          SizedBox(height: 16),
          InkWell(
            onTap: () async {
              context.pushNamed(ContactWidget.routeName);
            },
            child: _buildSupportCard(
                'Live Chat', 'Available 24/7', Icons.chat_outlined),
          ),
          SizedBox(height: 16),
          InkWell(
            onTap: () async {
              context.pushNamed(ContactWidget.routeName);
            },
            child: _buildSupportCard(
                'Help Center', 'Browse documentation', Icons.help_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySecurityContent() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Privacy & Security',
            style: FlutterFlowTheme.of(context).titleLarge.override(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
          ),
          SizedBox(height: 16),
          Text(
            'Manage your privacy settings and security preferences.',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
          ),
          SizedBox(height: 24),
          InkWell(
            onTap: () async {
              context.pushNamed(PrivacyAndPolicyWidget.routeName);
            },
            child: _buildSecurityCard('Two-Factor Authentication',
                'Enable 2FA for extra security', Icons.security),
          ),
          SizedBox(height: 16),
          InkWell(
            onTap: () async {
              // Data export functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data export feature coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: _buildSecurityCard(
                'Data Export', 'Download your data', Icons.download_outlined),
          ),
          SizedBox(height: 16),
          InkWell(
            onTap: () async {
              // Account deletion functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion feature coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: _buildSecurityCard('Account Deletion',
                'Permanently delete account', Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQsContent() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frequently Asked Questions',
            style: FlutterFlowTheme.of(context).titleLarge.override(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
          ),
          SizedBox(height: 16),
          Text(
            'Find answers to common questions.',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
          ),
          SizedBox(height: 24),
          _buildFAQItem('How do I change my password?',
              'Go to Security settings and click "Change Password"'),
          SizedBox(height: 16),
          _buildFAQItem('How do I enable notifications?',
              'Go to Notification settings and toggle the options you want'),
          SizedBox(height: 16),
          _buildFAQItem('How do I delete my account?',
              'Go to Privacy & Security and click "Account Deletion"'),
        ],
      ),
    );
  }

  Widget _buildWorkspaceManagementContent() {
    if (_model.isCreatingWorkspace) {
      return _buildCreateWorkspaceContent();
    }

    if (_model.isDeletingWorkspace) {
      return _buildDeleteWorkspaceContent();
    }

    if (_model.isJoiningWorkspace) {
      return _buildJoinWorkspaceContent();
    }

    return _buildWorkspaceManagementView();
  }

  Widget _buildWorkspaceManagementView() {
    return StreamBuilder<UsersRecord>(
      stream: UsersRecord.getDocument(currentUserReference!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: FlutterFlowTheme.of(context).alternate,
                width: 1,
              ),
            ),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final currentUser = snapshot.data!;

        // Handle case where user has no current workspace
        if (!currentUser.hasCurrentWorkspaceRef()) {
          return Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: FlutterFlowTheme.of(context).alternate,
                width: 1,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.business_outlined,
                        size: 32,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'No Workspace Selected',
                        style:
                            FlutterFlowTheme.of(context).headlineSmall.override(
                                  fontFamily: 'Inter',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                      ),
                      Spacer(),
                      FFButtonWidget(
                        onPressed: () async {
                          setState(() {
                            _model.isJoiningWorkspace = true;
                          });
                        },
                        text: 'Join Workspace',
                        icon: Icon(Icons.group_add, size: 16),
                        options: FFButtonOptions(
                          height: 36,
                          padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
                          iconPadding:
                              EdgeInsetsDirectional.fromSTEB(0, 0, 8, 0),
                          color: FlutterFlowTheme.of(context).secondaryText,
                          textStyle:
                              FlutterFlowTheme.of(context).titleSmall.override(
                                    fontFamily: 'Inter',
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                  ),
                          elevation: 0,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      SizedBox(width: 12),
                      FFButtonWidget(
                        onPressed: () async {
                          setState(() {
                            _model.isCreatingWorkspace = true;
                          });
                        },
                        text: 'Create New',
                        icon: Icon(Icons.add, size: 16),
                        options: FFButtonOptions(
                          height: 36,
                          padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
                          iconPadding:
                              EdgeInsetsDirectional.fromSTEB(0, 0, 8, 0),
                          color: FlutterFlowTheme.of(context).primary,
                          textStyle:
                              FlutterFlowTheme.of(context).titleSmall.override(
                                    fontFamily: 'Inter',
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                  ),
                          elevation: 0,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),

                  // Available Workspaces
                  Text(
                    'Available Workspaces',
                    style: FlutterFlowTheme.of(context).titleMedium.override(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                  ),
                  SizedBox(height: 16),

                  // List of available workspaces
                  StreamBuilder<List<WorkspaceMembersRecord>>(
                    stream: queryWorkspaceMembersRecord(
                      queryBuilder: (workspaceMembersRecord) =>
                          workspaceMembersRecord.where('user_ref',
                              isEqualTo: currentUser.reference),
                    ),
                    builder: (context, availableWorkspacesSnapshot) {
                      if (availableWorkspacesSnapshot.hasData &&
                          availableWorkspacesSnapshot.data!.isNotEmpty) {
                        final workspaceMembers =
                            availableWorkspacesSnapshot.data!;

                        return Column(
                          children: workspaceMembers.map((member) {
                            if (member.workspaceRef == null) {
                              return SizedBox.shrink();
                            }

                            return StreamBuilder<WorkspacesRecord>(
                              stream: WorkspacesRecord.getDocument(
                                  member.workspaceRef!),
                              builder: (context, workspaceSnapshot) {
                                if (workspaceSnapshot.hasData) {
                                  final workspace = workspaceSnapshot.data!;

                                  return Container(
                                    margin: EdgeInsets.only(bottom: 12),
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Workspace Logo
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: workspace.hasLogoUrl() &&
                                                  workspace.logoUrl.isNotEmpty
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  child: CachedNetworkImage(
                                                    imageUrl: workspace.logoUrl,
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (context, url) =>
                                                            Center(
                                                      child: Text(
                                                        workspace
                                                                .name.isNotEmpty
                                                            ? workspace.name[0]
                                                                .toUpperCase()
                                                            : 'W',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            Center(
                                                      child: Text(
                                                        workspace
                                                                .name.isNotEmpty
                                                            ? workspace.name[0]
                                                                .toUpperCase()
                                                            : 'W',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Center(
                                                  child: Text(
                                                    workspace.name.isNotEmpty
                                                        ? workspace.name[0]
                                                            .toUpperCase()
                                                        : 'W',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                workspace.name,
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyLarge
                                                        .override(
                                                          fontFamily: 'Inter',
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          letterSpacing: 0,
                                                        ),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                'Your role: ${member.role}',
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .override(
                                                          fontFamily: 'Inter',
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          letterSpacing: 0,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                        ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        FFButtonWidget(
                                          onPressed: () async {
                                            // Switch to this workspace
                                            await currentUser.reference.update({
                                              'current_workspace_ref':
                                                  workspace.reference,
                                            });
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Switched to ${workspace.name}')),
                                            );
                                            setState(() {}); // Refresh the UI
                                          },
                                          text: 'Switch',
                                          options: FFButtonOptions(
                                            height: 32,
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    12, 0, 12, 0),
                                            iconPadding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0, 0, 0, 0),
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                            textStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .override(
                                                      fontFamily: 'Inter',
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      letterSpacing: 0,
                                                    ),
                                            elevation: 0,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return SizedBox.shrink();
                              },
                            );
                          }).toList(),
                        );
                      }
                      return Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).primaryBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.business_outlined,
                                size: 48,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No workspaces found',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                    ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Create your first workspace to get started',
                                style: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .override(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: FlutterFlowTheme.of(context).alternate,
              width: 1,
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Workspace Management',
                      style: FlutterFlowTheme.of(context).titleLarge.override(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                    ),
                    Spacer(),
                    FFButtonWidget(
                      onPressed: () async {
                        setState(() {
                          _model.isJoiningWorkspace = true;
                        });
                      },
                      text: 'Join Workspace',
                      icon: Icon(Icons.group_add, size: 16),
                      options: FFButtonOptions(
                        height: 36,
                        padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
                        iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 8, 0),
                        color: FlutterFlowTheme.of(context).primary,
                        textStyle:
                            FlutterFlowTheme.of(context).titleSmall.override(
                                  fontFamily: 'Inter',
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                        elevation: 0,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    SizedBox(width: 12),
                    FFButtonWidget(
                      onPressed: () async {
                        setState(() {
                          _model.isCreatingWorkspace = true;
                        });
                      },
                      text: 'Create New Workspace',
                      icon: Icon(Icons.add, size: 16),
                      options: FFButtonOptions(
                        height: 36,
                        padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
                        iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 8, 0),
                        color: FlutterFlowTheme.of(context).primary,
                        textStyle:
                            FlutterFlowTheme.of(context).titleSmall.override(
                                  fontFamily: 'Inter',
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                        elevation: 0,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Manage your workspaces and team members.',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                ),
                SizedBox(height: 24),

                // All Workspaces Section
                Row(
                  children: [
                    Text(
                      'All Workspaces',
                      style: FlutterFlowTheme.of(context).titleMedium.override(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // List of all workspaces user belongs to
                StreamBuilder<List<WorkspaceMembersRecord>>(
                  stream: queryWorkspaceMembersRecord(
                    queryBuilder: (workspaceMembersRecord) =>
                        workspaceMembersRecord.where('user_ref',
                            isEqualTo: currentUser.reference),
                  ),
                  builder: (context, allWorkspacesSnapshot) {
                    if (allWorkspacesSnapshot.hasData &&
                        allWorkspacesSnapshot.data!.isNotEmpty) {
                      final workspaceMembers = allWorkspacesSnapshot.data!;

                      return Column(
                        children: workspaceMembers.map((member) {
                          if (member.workspaceRef == null) {
                            return SizedBox.shrink();
                          }

                          return StreamBuilder<WorkspacesRecord>(
                            stream: WorkspacesRecord.getDocument(
                                member.workspaceRef!),
                            builder: (context, workspaceSnapshot) {
                              if (workspaceSnapshot.hasData) {
                                final workspace = workspaceSnapshot.data!;
                                final isCurrentWorkspace =
                                    currentUser.hasCurrentWorkspaceRef() &&
                                        currentUser.currentWorkspaceRef ==
                                            workspace.reference;

                                return Container(
                                  margin: EdgeInsets.only(bottom: 12),
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isCurrentWorkspace
                                        ? FlutterFlowTheme.of(context)
                                            .primary
                                            .withOpacity(0.1)
                                        : FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isCurrentWorkspace
                                          ? FlutterFlowTheme.of(context).primary
                                          : FlutterFlowTheme.of(context)
                                              .alternate,
                                      width: isCurrentWorkspace ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Workspace Logo
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: workspace.hasLogoUrl() &&
                                                workspace.logoUrl.isNotEmpty
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: CachedNetworkImage(
                                                  imageUrl: workspace.logoUrl,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      Center(
                                                    child: Text(
                                                      workspace.name.isNotEmpty
                                                          ? workspace.name[0]
                                                              .toUpperCase()
                                                          : 'W',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          Center(
                                                    child: Text(
                                                      workspace.name.isNotEmpty
                                                          ? workspace.name[0]
                                                              .toUpperCase()
                                                          : 'W',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : Center(
                                                child: Text(
                                                  workspace.name.isNotEmpty
                                                      ? workspace.name[0]
                                                          .toUpperCase()
                                                      : 'W',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  workspace.name,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyLarge
                                                      .override(
                                                        fontFamily: 'Inter',
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        letterSpacing: 0,
                                                      ),
                                                ),
                                                if (isCurrentWorkspace) ...[
                                                  SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: Text(
                                                      'Current',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Your role: ${member.role}',
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .bodySmall
                                                  .override(
                                                    fontFamily: 'Inter',
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w400,
                                                    letterSpacing: 0,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .secondaryText,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isCurrentWorkspace)
                                        FFButtonWidget(
                                          onPressed: () async {
                                            // Switch to this workspace
                                            await currentUser.reference.update({
                                              'current_workspace_ref':
                                                  workspace.reference,
                                            });
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Switched to ${workspace.name}')),
                                            );
                                          },
                                          text: 'Switch',
                                          options: FFButtonOptions(
                                            height: 32,
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    12, 0, 12, 0),
                                            iconPadding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0, 0, 0, 0),
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                            textStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .override(
                                                      fontFamily: 'Inter',
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      letterSpacing: 0,
                                                    ),
                                            elevation: 0,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                        ),
                                      SizedBox(width: 8),
                                      // 3-dot settings menu
                                      PopupMenuButton<String>(
                                        onSelected: (String value) async {
                                          if (value == 'invite') {
                                            // Show invite users dialog
                                            _showInviteUsersDialog(
                                                context, currentUser);
                                          } else if (value == 'delete') {
                                            // Show delete workspace confirmation for this specific workspace
                                            _showDeleteWorkspaceDialog(
                                                context, workspace, member);
                                          }
                                        },
                                        itemBuilder: (BuildContext context) => [
                                          PopupMenuItem<String>(
                                            value: 'invite',
                                            child: Row(
                                              children: [
                                                Icon(Icons.person_add,
                                                    size: 18),
                                                SizedBox(width: 12),
                                                Text('Invite Users'),
                                              ],
                                            ),
                                          ),
                                          if (member.role == 'owner')
                                            PopupMenuItem<String>(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_outline,
                                                      size: 18,
                                                      color: Colors.red),
                                                  SizedBox(width: 12),
                                                  Text('Delete Workspace',
                                                      style: TextStyle(
                                                          color: Colors.red)),
                                                ],
                                              ),
                                            ),
                                        ],
                                        icon: Icon(
                                          Icons.more_vert,
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return SizedBox.shrink();
                            },
                          );
                        }).toList(),
                      );
                    }
                    return Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: FlutterFlowTheme.of(context).alternate,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 48,
                              color: FlutterFlowTheme.of(context).secondaryText,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No workspaces found',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                  ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Create your first workspace to get started',
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                SizedBox(height: 24),

                // Workspace Members with Search Bar
                Row(
                  children: [
                    Text(
                      'Workspace Members',
                      style: FlutterFlowTheme.of(context).titleMedium.override(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                    ),
                    Spacer(),
                    Container(
                      width: 250,
                      height: 36,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: FlutterFlowTheme.of(context).alternate,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _model.searchController,
                        onChanged: (value) {
                          setState(() {
                            _model.searchQuery = value.toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search members...',
                          hintStyle: FlutterFlowTheme.of(context)
                              .bodySmall
                              .override(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 18,
                            color: FlutterFlowTheme.of(context).secondaryText,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                            ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Members List
                StreamBuilder<List<WorkspaceMembersRecord>>(
                  stream: queryWorkspaceMembersRecord(
                    queryBuilder: (workspaceMembersRecord) =>
                        workspaceMembersRecord.where('workspace_ref',
                            isEqualTo: currentUser.currentWorkspaceRef),
                  ),
                  builder: (context, membersSnapshot) {
                    if (membersSnapshot.hasData) {
                      final allMembers = membersSnapshot.data!;

                      // Sort members by role: owner first, then moderator, then member
                      allMembers.sort((a, b) {
                        const roleOrder = {
                          'owner': 0,
                          'moderator': 1,
                          'member': 2
                        };
                        final aOrder = roleOrder[a.role] ?? 3;
                        final bOrder = roleOrder[b.role] ?? 3;
                        return aOrder.compareTo(bOrder);
                      });

                      // Filter members based on search query
                      final members = _model.searchQuery.isEmpty
                          ? allMembers
                          : allMembers.where((member) {
                              // We'll filter in the StreamBuilder for each member
                              return true; // This will be handled in the individual member cards
                            }).toList();

                      return Column(
                        children: [
                          // Member count header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _model.searchQuery.isEmpty
                                    ? '${allMembers.length} members'
                                    : '${members.length} of ${allMembers.length} members',
                                style: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .override(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                    ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          // Members list - Scrollable container
                          Container(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height *
                                  0.4, // 40% of screen height
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                children: members.map((member) {
                                  return StreamBuilder<UsersRecord>(
                                    stream: UsersRecord.getDocument(
                                        member.userRef!),
                                    builder: (context, userSnapshot) {
                                      if (userSnapshot.hasData) {
                                        final user = userSnapshot.data!;

                                        // Filter by search query
                                        if (_model.searchQuery.isNotEmpty) {
                                          final searchLower =
                                              _model.searchQuery.toLowerCase();
                                          final nameMatch = user.displayName
                                              .toLowerCase()
                                              .contains(searchLower);
                                          final emailMatch = user.email
                                              .toLowerCase()
                                              .contains(searchLower);
                                          if (!nameMatch && !emailMatch) {
                                            return SizedBox.shrink();
                                          }
                                        }

                                        final isCurrentUser = user.reference ==
                                            currentUserReference;

                                        // Find current user's role in this workspace
                                        final currentUserMember =
                                            members.firstWhere(
                                          (m) =>
                                              m.userRef == currentUserReference,
                                          orElse: () => WorkspaceMembersRecord
                                              .getDocumentFromData(
                                                  {'role': 'member'},
                                                  FirebaseFirestore.instance
                                                      .collection(
                                                          'workspace_members')
                                                      .doc()),
                                        );
                                        final currentUserRole =
                                            currentUserMember.role;
                                        final canManageUsers =
                                            currentUserRole == 'owner' ||
                                                currentUserRole == 'moderator';

                                        return Container(
                                          margin: EdgeInsets.only(bottom: 8),
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .alternate,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundImage: user
                                                            .hasPhotoUrl() &&
                                                        user.photoUrl.isNotEmpty
                                                    ? CachedNetworkImageProvider(
                                                        user.photoUrl)
                                                    : null,
                                                child: user.hasPhotoUrl() &&
                                                        user.photoUrl.isNotEmpty
                                                    ? null
                                                    : Text(
                                                        user.displayName
                                                                .isNotEmpty
                                                            ? user
                                                                .displayName[0]
                                                                .toUpperCase()
                                                            : 'U',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                              ),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      user.displayName,
                                                      style: FlutterFlowTheme
                                                              .of(context)
                                                          .bodyMedium
                                                          .override(
                                                            fontFamily: 'Inter',
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            letterSpacing: 0,
                                                          ),
                                                    ),
                                                    Text(
                                                      user.email,
                                                      style: FlutterFlowTheme
                                                              .of(context)
                                                          .bodySmall
                                                          .override(
                                                            fontFamily: 'Inter',
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            letterSpacing: 0,
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .secondaryText,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: member.role == 'owner'
                                                      ? Color(
                                                          0xFF10B981) // Green for owner
                                                      : member.role ==
                                                              'moderator'
                                                          ? Color(
                                                              0xFF3B82F6) // Blue for moderator
                                                          : FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryText, // Grey for member
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  member.role.toUpperCase(),
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),

                                              // Action dropdown for owners and moderators
                                              if (!isCurrentUser &&
                                                  canManageUsers) ...[
                                                SizedBox(width: 8),
                                                PopupMenuButton<String>(
                                                  onSelected: (value) {
                                                    switch (value) {
                                                      case 'change_role':
                                                        _showChangeRoleDialog(
                                                            context,
                                                            member,
                                                            user);
                                                        break;
                                                      case 'remove':
                                                        _showRemoveUserDialog(
                                                            context,
                                                            member,
                                                            user);
                                                        break;
                                                    }
                                                  },
                                                  itemBuilder: (context) => [
                                                    PopupMenuItem(
                                                      value: 'change_role',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .admin_panel_settings,
                                                              size: 18,
                                                              color:
                                                                  Colors.blue),
                                                          SizedBox(width: 8),
                                                          Text('Change Role'),
                                                        ],
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'remove',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .person_remove,
                                                              size: 18,
                                                              color:
                                                                  Colors.red),
                                                          SizedBox(width: 8),
                                                          Text('Remove User',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .red)),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                  child: Container(
                                                    width: 32,
                                                    height: 32,
                                                    decoration: BoxDecoration(
                                                      color: FlutterFlowTheme
                                                              .of(context)
                                                          .primaryBackground,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                      border: Border.all(
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .alternate,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Icon(Icons.more_vert,
                                                        size: 16,
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      }
                                      return SizedBox.shrink();
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: FlutterFlowTheme.of(context).alternate,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'No members found',
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                        ),
                      ),
                    );
                  },
                ),

                SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: FFButtonWidget(
                        onPressed: () async {
                          // Get current workspace
                          final currentUser = currentUserDocument;
                          if (currentUser == null ||
                              !currentUser.hasCurrentWorkspaceRef()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'No workspace selected. Please select a workspace first.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          // Fetch workspace data
                          final workspaceSnapshot =
                              await currentUser.currentWorkspaceRef!.get();

                          if (!workspaceSnapshot.exists) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Workspace not found.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final workspace =
                              WorkspacesRecord.fromSnapshot(workspaceSnapshot);
                          _showInviteUserDialog(context, workspace);
                        },
                        text: 'Invite User',
                        icon: Icon(Icons.person_add, size: 16),
                        options: FFButtonOptions(
                          height: 44,
                          padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
                          iconPadding:
                              EdgeInsetsDirectional.fromSTEB(0, 0, 8, 0),
                          color: FlutterFlowTheme.of(context).primary,
                          textStyle:
                              FlutterFlowTheme.of(context).titleSmall.override(
                                    fontFamily: 'Inter',
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                  ),
                          elevation: 0,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: FFButtonWidget(
                        onPressed: () async {
                          await _generateAndCopyInviteCode();
                        },
                        text: 'Copy Invite Code',
                        icon: Icon(Icons.copy, size: 16),
                        options: FFButtonOptions(
                          height: 44,
                          padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
                          iconPadding:
                              EdgeInsetsDirectional.fromSTEB(0, 0, 8, 0),
                          color: FlutterFlowTheme.of(context).secondaryText,
                          textStyle:
                              FlutterFlowTheme.of(context).titleSmall.override(
                                    fontFamily: 'Inter',
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                  ),
                          elevation: 0,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultContent() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings_outlined,
              color: FlutterFlowTheme.of(context).secondaryText,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Select a setting to get started',
              style: FlutterFlowTheme.of(context).headlineSmall.override(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widgets
  Widget _buildEditableInfoField(
      String title, TextEditingController controller, IconData icon,
      {bool enabled = true}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: FlutterFlowTheme.of(context).secondaryText,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                title,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
              ),
            ],
          ),
          SizedBox(height: 8),
          TextField(
            controller: controller,
            enabled: enabled,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: enabled
                      ? FlutterFlowTheme.of(context).alternate
                      : FlutterFlowTheme.of(context)
                          .secondaryText
                          .withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: FlutterFlowTheme.of(context).alternate,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: FlutterFlowTheme.of(context).primary,
                  width: 2,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: FlutterFlowTheme.of(context)
                      .secondaryText
                      .withOpacity(0.3),
                ),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              hintText: enabled ? 'Enter $title' : 'Cannot be changed',
            ),
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  color: enabled
                      ? FlutterFlowTheme.of(context).primaryText
                      : FlutterFlowTheme.of(context).secondaryText,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationToggle(String label, bool value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
        ),
        Switch(
          value: value,
          onChanged: (newValue) async {
            // Map label to Firestore field and state variable
            String field = '';
            if (label == 'Push Notifications') {
              field = 'notifications_enabled';
              setState(() => _notificationsEnabled = newValue);
            } else if (label == 'Event Reminders') {
              field = 'notifications_enabled';
              setState(() => _eventRemindersEnabled = newValue);
            } else if (label == 'New Message Alerts') {
              field = 'new_message_enabled';
              setState(() => _newMessageEnabled = newValue);
            } else if (label == 'Email Notifications') {
              field = 'email_notifications_enabled';
              setState(() => _emailNotificationsEnabled = newValue);
            }

            if (field.isNotEmpty && currentUserReference != null) {
              await currentUserReference!.update({field: newValue});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('✅ $label ${newValue ? 'enabled' : 'disabled'}'),
                  backgroundColor: Color(0xFF10B981),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          activeColor: FlutterFlowTheme.of(context).secondaryText,
        ),
      ],
    );
  }

  Widget _buildSupportCard(String title, String subtitle, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: FlutterFlowTheme.of(context).secondaryText, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard(String title, String subtitle, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: FlutterFlowTheme.of(context).secondaryText, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: FlutterFlowTheme.of(context).secondaryText,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
          ),
          SizedBox(height: 8),
          Text(
            answer,
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
          ),
        ],
      ),
    );
  }

  IconData _getSettingIcon(String setting) {
    switch (setting) {
      case 'Personal Information':
        return Icons.person_outline_rounded;
      case 'Notifications':
        return Icons.notifications_outlined;
      case 'Contact Support':
        return Icons.support_agent_outlined;
      case 'Privacy & Security':
        return Icons.security_outlined;
      case 'FAQs':
        return Icons.help_outline_rounded;
      case 'Workspace Management':
        return Icons.business_outlined;
      default:
        return Icons.settings_outlined;
    }
  }

  // Workspace Management Dialog Methods
  void _showChangeRoleDialog(
      BuildContext context, WorkspaceMembersRecord member, UsersRecord user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select new role for ${user.displayName}:'),
            SizedBox(height: 16),
            ...['owner', 'moderator', 'member']
                .map(
                  (role) => RadioListTile<String>(
                    title: Text(role.toUpperCase()),
                    subtitle: Text(_getRoleDescription(role)),
                    value: role,
                    groupValue: member.role,
                    onChanged: (value) async {
                      if (value != null) {
                        await member.reference.update({'role': value});
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Role updated successfully')),
                        );
                      }
                    },
                  ),
                )
                .toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showRemoveUserDialog(
      BuildContext context, WorkspaceMembersRecord member, UsersRecord user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove User'),
        content: Text(
            'Are you sure you want to remove ${user.displayName} from this workspace?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await member.reference.delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('User removed successfully')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showInviteUserDialog(BuildContext context, WorkspacesRecord workspace) {
    final emailController = TextEditingController();
    bool isLoading = false;
    bool emailSent = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(
                Icons.person_add,
                color: FlutterFlowTheme.of(context).primary,
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Invite User to Workspace',
                  style: FlutterFlowTheme.of(context).titleLarge.override(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite someone to join "${workspace.name}" workspace',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: FlutterFlowTheme.of(context).secondaryText,
                        letterSpacing: 0,
                      ),
                ),
                SizedBox(height: 24),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'user@example.com',
                    prefixIcon: Icon(
                      Icons.email,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: FlutterFlowTheme.of(context).alternate,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: FlutterFlowTheme.of(context).alternate,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: FlutterFlowTheme.of(context).primary,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    labelStyle:
                        FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Inter',
                              color: FlutterFlowTheme.of(context).secondaryText,
                              letterSpacing: 0,
                            ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isLoading,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'Inter',
                        letterSpacing: 0,
                      ),
                ),
                if (emailSent) ...[
                  SizedBox(height: 24),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Invitation email sent successfully!',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'Inter',
                                  color: Colors.green[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isLoading) ...[
                  SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            FlutterFlowTheme.of(context).primary,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Sending invitation email...',
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Inter',
                      color: FlutterFlowTheme.of(context).secondaryText,
                      letterSpacing: 0,
                    ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: isLoading
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      if (email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please enter an email address'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Basic email validation
                      final emailRegex = RegExp(
                        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                      );
                      if (!emailRegex.hasMatch(email)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please enter a valid email address'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        emailSent = false;
                      });

                      try {
                        // Call Cloud Function to send email with invite code
                        final callable = FirebaseFunctions.instance
                            .httpsCallable('sendWorkspaceInviteEmail');

                        final result = await callable.call({
                          'email': email,
                          'workspaceId': workspace.reference.id,
                          'workspaceName': workspace.name,
                          'inviterUserId': currentUserUid,
                          'inviterName': currentUserDisplayName ?? '',
                        });

                        final data = result.data as Map<String, dynamic>?;

                        if (data != null && data['success'] == true) {
                          setDialogState(() {
                            emailSent = true;
                            isLoading = false;
                          });
                        } else {
                          setDialogState(() {
                            isLoading = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                data?['message'] as String? ??
                                    'Failed to send invitation email. Please try again.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isLoading = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error sending email: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              icon: Icon(Icons.send, size: 18),
              label: Text(emailSent ? 'Email Sent' : 'Send Invite'),
              style: ElevatedButton.styleFrom(
                backgroundColor: emailSent
                    ? Colors.green
                    : FlutterFlowTheme.of(context).primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteUsersDialog(BuildContext context, UsersRecord currentUser) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.construction, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Under Development'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invite Users Feature',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'This feature is currently under development and will be available soon.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Coming soon: Invite users by email and generate invite codes!',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDeleteWorkspaceDialog(BuildContext context,
      WorkspacesRecord workspace, WorkspaceMembersRecord member) {
    final TextEditingController confirmationController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete Workspace'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${workspace.name}"?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'This action cannot be undone. All data associated with this workspace will be permanently deleted.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Type "${workspace.name}" to confirm:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: confirmationController,
              decoration: InputDecoration(
                hintText: 'Enter workspace name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (confirmationController.text == workspace.name) {
                // TODO: Implement workspace deletion logic
                // This should delete the workspace and all related data
                await workspace.reference.delete();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Workspace "${workspace.name}" has been deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Workspace name does not match'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                Text('Delete Workspace', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'owner':
        return 'Full control over workspace';
      case 'moderator':
        return 'Can manage users and content';
      case 'member':
        return 'Basic workspace access';
      default:
        return '';
    }
  }

  Widget _buildCreateWorkspaceContent() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with back button
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _model.isCreatingWorkspace = false;
                      });
                    },
                    icon: Icon(
                      Icons.arrow_back,
                      color: FlutterFlowTheme.of(context).primaryText,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Create New Workspace',
                    style: FlutterFlowTheme.of(context).headlineSmall.override(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Form
              Text(
                'Set up your new workspace',
                style: FlutterFlowTheme.of(context).headlineSmall.override(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
              ),
              SizedBox(height: 8),
              Text(
                'Create a workspace where your team can collaborate and communicate.',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
              ),
              SizedBox(height: 32),

              // Workspace Name Field
              Text(
                'Workspace Name',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _model.workspaceNameController,
                autofocus: false,
                obscureText: false,
                decoration: InputDecoration(
                  hintText: 'Enter workspace name...',
                  hintStyle: FlutterFlowTheme.of(context).bodySmall.override(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).alternate,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).primary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).error,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).error,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
                ),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                    ),
              ),
              SizedBox(height: 24),

              // Description Field
              Text(
                'Description (Optional)',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _model.workspaceDescriptionController,
                autofocus: false,
                obscureText: false,
                decoration: InputDecoration(
                  hintText: 'Describe what this workspace is for...',
                  hintStyle: FlutterFlowTheme.of(context).bodySmall.override(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).alternate,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).primary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).error,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).error,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
                ),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                    ),
                maxLines: 4,
              ),
              SizedBox(height: 32),

              // Info Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: FlutterFlowTheme.of(context).primary,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You will be the owner of this workspace and can invite team members later.',
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                              color: FlutterFlowTheme.of(context).secondaryText,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: FFButtonWidget(
                      onPressed: () async {
                        setState(() {
                          _model.isCreatingWorkspace = false;
                        });
                      },
                      text: 'Cancel',
                      options: FFButtonOptions(
                        height: 48,
                        padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                        iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        textStyle: FlutterFlowTheme.of(context)
                            .titleSmall
                            .override(
                              fontFamily: 'Inter',
                              color: FlutterFlowTheme.of(context).primaryText,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
                        elevation: 0,
                        borderSide: BorderSide(
                          color: FlutterFlowTheme.of(context).alternate,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: FFButtonWidget(
                      onPressed: () async {
                        await _createWorkspace();
                      },
                      text: 'Create Workspace',
                      options: FFButtonOptions(
                        height: 48,
                        padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                        iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                        color: FlutterFlowTheme.of(context).primary,
                        textStyle:
                            FlutterFlowTheme.of(context).titleSmall.override(
                                  fontFamily: 'Inter',
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                        elevation: 0,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createWorkspace() async {
    if (_model.workspaceNameController?.text.isEmpty ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a workspace name')),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get current user
      final currentUser = currentUserReference;
      if (currentUser == null) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please log in to create a workspace')),
        );
        return;
      }

      // Create workspace document
      final workspaceData = {
        'name': _model.workspaceNameController?.text.trim() ?? '',
        'description': _model.workspaceDescriptionController?.text.trim() ?? '',
        'created_time': getCurrentTimestamp,
        'owner_ref': currentUser,
        'logo_url': '',
        'member_count': 1,
      };

      final workspaceRef = await FirebaseFirestore.instance
          .collection('workspaces')
          .add(workspaceData);

      // Add current user as owner to workspace members
      final memberData = {
        'user_ref': currentUser,
        'workspace_ref': workspaceRef,
        'role': 'owner',
        'joined_time': getCurrentTimestamp,
      };

      await FirebaseFirestore.instance
          .collection('workspace_members')
          .add(memberData);

      // Update user's current workspace
      await currentUser.update({
        'current_workspace_ref': workspaceRef,
      });

      // Clear form
      _model.workspaceNameController?.clear();
      _model.workspaceDescriptionController?.clear();

      Navigator.pop(context); // Close loading dialog

      // Return to workspace management view
      setState(() {
        _model.isCreatingWorkspace = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Workspace created successfully!')),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating workspace: $e')),
      );
    }
  }

  Widget _buildDeleteWorkspaceContent() {
    return StreamBuilder<UsersRecord>(
      stream: UsersRecord.getDocument(currentUserReference!),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).primaryBackground,
            ),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final currentUser = userSnapshot.data!;

        return StreamBuilder<WorkspacesRecord>(
          stream:
              WorkspacesRecord.getDocument(currentUser.currentWorkspaceRef!),
          builder: (context, workspaceSnapshot) {
            if (!workspaceSnapshot.hasData) {
              return Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                ),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final workspace = workspaceSnapshot.data!;

            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).primaryBackground,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with back button
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _model.isDeletingWorkspace = false;
                              });
                            },
                            icon: Icon(
                              Icons.arrow_back,
                              color: FlutterFlowTheme.of(context).primaryText,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete Workspace',
                            style: FlutterFlowTheme.of(context)
                                .headlineSmall
                                .override(
                                  fontFamily: 'Inter',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),

                      // Warning Card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_outlined,
                              color: Colors.red.shade600,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'This action cannot be undone',
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'Inter',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0,
                                          color: Colors.red.shade700,
                                        ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'This will permanently delete the workspace "${workspace.name}" and all of its data including messages, files, and member information.',
                                    style: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .override(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          letterSpacing: 0,
                                          color: Colors.red.shade600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32),

                      // Confirmation Text
                      Text(
                        'To confirm, please type the workspace name below:',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Type "${workspace.name}" to confirm deletion',
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                              color: FlutterFlowTheme.of(context).secondaryText,
                            ),
                      ),
                      SizedBox(height: 16),

                      // Confirmation Input Field
                      TextFormField(
                        controller: _model.deleteConfirmationController,
                        autofocus: false,
                        obscureText: false,
                        decoration: InputDecoration(
                          hintText: 'Enter workspace name...',
                          hintStyle: FlutterFlowTheme.of(context)
                              .bodySmall
                              .override(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).alternate,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.red,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding:
                              EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
                        ),
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                            ),
                        onChanged: (value) {
                          setState(
                              () {}); // Trigger rebuild to enable/disable button
                        },
                      ),
                      SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: FFButtonWidget(
                              onPressed: () async {
                                setState(() {
                                  _model.isDeletingWorkspace = false;
                                });
                              },
                              text: 'Cancel',
                              options: FFButtonOptions(
                                height: 48,
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    24, 0, 24, 0),
                                iconPadding:
                                    EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                                textStyle: FlutterFlowTheme.of(context)
                                    .titleSmall
                                    .override(
                                      fontFamily: 'Inter',
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                    ),
                                elevation: 0,
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).alternate,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: FFButtonWidget(
                              onPressed: (_model
                                          .deleteConfirmationController?.text
                                          .trim() ==
                                      workspace.name)
                                  ? () async {
                                      await _deleteWorkspace(workspace);
                                    }
                                  : null,
                              text: 'Delete Workspace',
                              options: FFButtonOptions(
                                height: 48,
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    24, 0, 24, 0),
                                iconPadding:
                                    EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                                color: Colors.red,
                                textStyle: FlutterFlowTheme.of(context)
                                    .titleSmall
                                    .override(
                                      fontFamily: 'Inter',
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                    ),
                                elevation: 0,
                                borderRadius: BorderRadius.circular(8),
                              ),
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
      },
    );
  }

  Future<void> _deleteWorkspace(WorkspacesRecord workspace) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get current user
      final currentUser = currentUserReference;
      if (currentUser == null) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please log in to delete a workspace')),
        );
        return;
      }

      // Delete all workspace members
      final membersQuery = await FirebaseFirestore.instance
          .collection('workspace_members')
          .where('workspace_ref', isEqualTo: workspace.reference)
          .get();

      for (var memberDoc in membersQuery.docs) {
        await memberDoc.reference.delete();
      }

      // Delete all chats in this workspace
      final chatsQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('workspace_ref', isEqualTo: workspace.reference)
          .get();

      for (var chatDoc in chatsQuery.docs) {
        await chatDoc.reference.delete();
      }

      // Clear current workspace reference from users who have this as their current workspace
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('current_workspace_ref', isEqualTo: workspace.reference)
          .get();

      for (var userDoc in usersQuery.docs) {
        // Check if user has other workspaces
        final userOtherWorkspacesQuery = await FirebaseFirestore.instance
            .collection('workspace_members')
            .where('user_ref', isEqualTo: userDoc.reference)
            .get();

        if (userOtherWorkspacesQuery.docs.isNotEmpty) {
          // User has other workspaces, switch to the first one
          final newWorkspaceRef =
              userOtherWorkspacesQuery.docs.first.data()['workspace_ref'];
          await userDoc.reference.update({
            'current_workspace_ref': newWorkspaceRef,
          });
        } else {
          // User has no other workspaces, clear the reference
          await userDoc.reference.update({
            'current_workspace_ref': null,
          });
        }
      }

      // Finally delete the workspace itself
      await workspace.reference.delete();

      // Clear form
      _model.deleteConfirmationController?.clear();

      Navigator.pop(context); // Close loading dialog

      // Return to workspace management view
      setState(() {
        _model.isDeletingWorkspace = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Workspace deleted successfully')),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting workspace: $e')),
      );
    }
  }

  Future<void> _generateAndCopyInviteCode() async {
    try {
      // Get current user
      final currentUser = currentUserReference;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please log in to generate invite code')),
        );
        return;
      }

      // Get current workspace
      final userDoc = await currentUser.get();
      final userData = userDoc.data() as Map<String, dynamic>;
      final currentWorkspaceRef =
          userData['current_workspace_ref'] as DocumentReference?;

      if (currentWorkspaceRef == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a workspace first')),
        );
        return;
      }

      // Get workspace document
      final workspaceDoc = await currentWorkspaceRef.get();
      final workspaceData = workspaceDoc.data() as Map<String, dynamic>;

      String inviteCode = workspaceData['invite_code'] as String? ?? '';

      // Generate new invite code if none exists
      if (inviteCode.isEmpty) {
        inviteCode = _generateRandomCode();

        // Update workspace with new invite code
        await currentWorkspaceRef.update({
          'invite_code': inviteCode,
        });
      }

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: inviteCode));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invite code copied to clipboard: $inviteCode'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating invite code: $e')),
      );
    }
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
          6, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  Widget _buildJoinWorkspaceContent() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with back button
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _model.isJoiningWorkspace = false;
                      });
                    },
                    icon: Icon(
                      Icons.arrow_back,
                      color: FlutterFlowTheme.of(context).primaryText,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Join Workspace',
                    style: FlutterFlowTheme.of(context).headlineSmall.override(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Info Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: FlutterFlowTheme.of(context).primary,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Join with Invite Code',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Enter the 6-character invite code shared by a workspace member to join their workspace.',
                            style:
                                FlutterFlowTheme.of(context).bodySmall.override(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),

              // Invite Code Input
              Text(
                'Invite Code',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _model.inviteCodeController,
                autofocus: false,
                obscureText: false,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Enter 6-character code (e.g., A3K9M2)',
                  hintStyle: FlutterFlowTheme.of(context).bodySmall.override(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).alternate,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).primary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.red,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.red,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
                ),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                maxLength: 6,
                onChanged: (value) {
                  setState(() {}); // Trigger rebuild to enable/disable button
                },
              ),
              SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: FFButtonWidget(
                      onPressed: () async {
                        setState(() {
                          _model.isJoiningWorkspace = false;
                        });
                      },
                      text: 'Cancel',
                      options: FFButtonOptions(
                        height: 48,
                        padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                        iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        textStyle: FlutterFlowTheme.of(context)
                            .titleSmall
                            .override(
                              fontFamily: 'Inter',
                              color: FlutterFlowTheme.of(context).primaryText,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
                        elevation: 0,
                        borderSide: BorderSide(
                          color: FlutterFlowTheme.of(context).alternate,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: FFButtonWidget(
                      onPressed:
                          (_model.inviteCodeController?.text.trim().length == 6)
                              ? () async {
                                  await _joinWorkspaceWithCode();
                                }
                              : null,
                      text: 'Join Workspace',
                      options: FFButtonOptions(
                        height: 48,
                        padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                        iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                        color: FlutterFlowTheme.of(context).primary,
                        textStyle:
                            FlutterFlowTheme.of(context).titleSmall.override(
                                  fontFamily: 'Inter',
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                        elevation: 0,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _joinWorkspaceWithCode() async {
    try {
      final inviteCode =
          _model.inviteCodeController?.text.trim().toUpperCase() ?? '';

      if (inviteCode.length != 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Please enter a valid 6-character invite code')),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get current user
      final currentUser = currentUserReference;
      if (currentUser == null) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please log in to join a workspace')),
        );
        return;
      }

      // Find workspace with this invite code
      final workspaceQuery = await FirebaseFirestore.instance
          .collection('workspaces')
          .where('invite_code', isEqualTo: inviteCode)
          .get();

      if (workspaceQuery.docs.isEmpty) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Invalid invite code. Please check and try again.')),
        );
        return;
      }

      final workspaceDoc = workspaceQuery.docs.first;
      final workspaceRef = workspaceDoc.reference;

      // Check if user is already a member
      final memberQuery = await FirebaseFirestore.instance
          .collection('workspace_members')
          .where('workspace_ref', isEqualTo: workspaceRef)
          .where('user_ref', isEqualTo: currentUser)
          .get();

      if (memberQuery.docs.isNotEmpty) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You are already a member of this workspace')),
        );
        return;
      }

      // Add user as a member
      final memberData = {
        'workspace_ref': workspaceRef,
        'user_ref': currentUser,
        'role': 'member',
        'joined_time': getCurrentTimestamp,
      };

      await FirebaseFirestore.instance
          .collection('workspace_members')
          .add(memberData);

      // Update user's current workspace
      await currentUser.update({
        'current_workspace_ref': workspaceRef,
      });

      // Update workspace member count
      await workspaceRef.update({
        'member_count': FieldValue.increment(1),
      });

      // Clear form
      _model.inviteCodeController?.clear();

      Navigator.pop(context); // Close loading dialog

      // Return to workspace management view
      setState(() {
        _model.isJoiningWorkspace = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully joined workspace!')),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining workspace: $e')),
      );
    }
  }
}
