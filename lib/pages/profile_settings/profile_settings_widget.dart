import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/backend/push_notifications/push_notifications_util.dart';
import '/custom_code/services/web_notification_service.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
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

  // Notification settings state - synced with system
  bool _notificationsEnabled = false;
  bool _isLoadingNotificationStatus = true;

  // Cover photo dropdown state
  final GlobalKey _coverPhotoDropdownKey = GlobalKey();

  // Constants for profile layout
  static const double _coverPhotoHeight = 280.0;
  static const double _profilePictureSize = 140.0;
  static const double _profilePictureBorderWidth = 5.0;
  static const double _profilePictureOffset = -100.0;
  static const double _borderRadius = 16.0;
  static const double _coverPhotoButtonBorderRadius = 10.0;

  // Color constants
  static const Color _errorColor = Color(0xFFEF4444);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _textColorPrimary = Color(0xFF374151);
  static const Color _textColorSecondary = Color(0xFF9CA3AF);
  static const Color _backgroundColor = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileSettingsModel());
    _model.selectedSetting = 'Personal Information';
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    setState(() {
      _isLoadingNotificationStatus = true;
    });

    // Check actual system notification permission status
    bool systemNotificationEnabled = false;

    if (kIsWeb) {
      // For web, check browser notification permission
      try {
        final permission = WebNotificationService.instance.permissionStatus;
        systemNotificationEnabled = permission == 'granted';
      } catch (e) {
        print('Error checking web notification permission: $e');
      }
    } else if (Platform.isMacOS || Platform.isIOS) {
      // For macOS/iOS, check Firebase Messaging permission
      try {
        final messaging = FirebaseMessaging.instance;
        final settings = await messaging.getNotificationSettings();
        systemNotificationEnabled =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
                settings.authorizationStatus == AuthorizationStatus.provisional;
      } catch (e) {
        print('Error checking notification permission: $e');
      }
    }

    // Update state to match system permission
    setState(() {
      _notificationsEnabled = systemNotificationEnabled;
      _isLoadingNotificationStatus = false;
    });

    // Also update Firestore to match system permission
    if (currentUserReference != null) {
      await currentUserReference!.update({
        'notifications_enabled': systemNotificationEnabled,
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
        color: Colors.white,
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
              color: FlutterFlowTheme.of(context).primary,
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
                        color: isSelected
                            ? FlutterFlowTheme.of(context)
                                .primary
                                .withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(
                                color: FlutterFlowTheme.of(context).primary,
                                width: 1,
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item['icon'] as IconData,
                            color: isSelected
                                ? FlutterFlowTheme.of(context).primary
                                : FlutterFlowTheme.of(context).secondaryText,
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
                                        ? FlutterFlowTheme.of(context).primary
                                        : FlutterFlowTheme.of(context)
                                            .secondaryText,
                                  ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: FlutterFlowTheme.of(context).primary,
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
    // For Personal Information, we want full-width cover photo
    if (_model.selectedSetting == 'Personal Information') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content without padding for full-width cover photo
          Expanded(
            child: _buildSettingContent(_model.selectedSetting),
          ),
        ],
      );
    }

    // For other settings, use normal padding
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
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
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

        final user = userSnapshot.data!;

        // Initialize controllers with current user data if not already set
        if (_model.displayNameController?.text.isEmpty ?? true) {
          _model.displayNameController?.text = user.displayName;
        }
        if (_model.locationController?.text.isEmpty ?? true) {
          _model.locationController?.text = user.location;
        }
        if (_model.bioController?.text.isEmpty ?? true) {
          _model.bioController?.text = user.bio;
        }
        if (_model.emailController?.text.isEmpty ?? true) {
          _model.emailController?.text = currentUserEmail;
        }
        if (_model.websiteController?.text.isEmpty ?? true) {
          _model.websiteController?.text =
              user.snapshotData['website']?.toString() ?? '';
        }
        if (_model.roleController?.text.isEmpty ?? true) {
          _model.roleController?.text = '';
        }

        // Get user's role from workspace
        return StreamBuilder<UsersRecord>(
          stream: UsersRecord.getDocument(currentUserReference!),
          builder: (context, snapshot) {
            String userRole = '';

            if (snapshot.hasData &&
                snapshot.data!.currentWorkspaceRef != null) {
              return StreamBuilder<List<WorkspaceMembersRecord>>(
                stream: queryWorkspaceMembersRecord(
                  queryBuilder: (workspaceMembers) => workspaceMembers
                      .where('workspace_ref',
                          isEqualTo: snapshot.data!.currentWorkspaceRef)
                      .where('user_ref', isEqualTo: currentUserReference),
                ),
                builder: (context, membersSnapshot) {
                  if (membersSnapshot.hasData &&
                      membersSnapshot.data!.isNotEmpty) {
                    userRole = membersSnapshot.data!.first.role;
                  }

                  return _buildModernProfileLayout(user, userRole);
                },
              );
            }

            return _buildModernProfileLayout(user, userRole);
          },
        );
      },
    );
  }

  Widget _buildModernProfileLayout(UsersRecord user, String role) {
    final coverPhotoUrl = _getCoverPhotoUrl(user);

    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(0xFFE0E0E0), width: 1),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                _buildLinkedInCoverPhotoSection(coverPhotoUrl),
                _buildLinkedInProfileInfoSection(user, role),
              ],
            ),
            // Profile picture positioned to overlap cover photo - CENTERED
            Positioned(
              top:
                  140, // Position at bottom of 200px cover photo minus half of profile picture
              left: 0,
              right: 0,
              child: Center(
                child: Stack(
                  children: [
                    _buildLinkedInProfilePicture(),
                    if (_model.isEditingProfile)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () =>
                              context.pushNamed(EditProfileWidget.routeName),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(0xFF0077B5),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileLayout(UsersRecord user, String role) {
    final coverPhotoUrl = _getCoverPhotoUrl(user);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCoverPhotoSection(coverPhotoUrl),
          _buildProfileInfoSection(user, role),
        ],
      ),
    );
  }

  /// Retrieves the cover photo URL from user record
  String? _getCoverPhotoUrl(UsersRecord user) {
    final userData = user.snapshotData;
    return userData['cover_photo_url'] as String?;
  }

  /// Builds the cover photo section with image or gradient fallback
  Widget _buildCoverPhotoSection(String? coverPhotoUrl) {
    return Container(
      height: _coverPhotoHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(_borderRadius),
          topRight: Radius.circular(_borderRadius),
        ),
      ),
      child: Stack(
        children: [
          _buildCoverPhotoContent(coverPhotoUrl),
          if (_model.isEditingProfile)
            Positioned(
              top: 20,
              right: 20,
              child: _buildCoverPhotoEditButton(),
            ),
        ],
      ),
    );
  }

  /// Builds the cover photo content (image or gradient)
  Widget _buildCoverPhotoContent(String? coverPhotoUrl) {
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(_borderRadius),
      topRight: Radius.circular(_borderRadius),
    );

    if (coverPhotoUrl != null && coverPhotoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: CachedNetworkImage(
          imageUrl: coverPhotoUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => _buildDefaultGradient(),
          errorWidget: (context, url, error) => _buildDefaultGradient(),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
      ),
      child: _buildDefaultGradient(),
    );
  }

  /// Builds the default gradient for cover photo
  Widget _buildDefaultGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).primary,
            FlutterFlowTheme.of(context).primary.withOpacity(0.7),
          ],
        ),
      ),
    );
  }

  /// Builds the modern cover photo section with beautiful gradients
  Widget _buildModernCoverPhotoSection(String? coverPhotoUrl) {
    return Container(
      height: 280,
      width: double.infinity,
      child: Stack(
        children: [
          _buildModernCoverPhotoContent(coverPhotoUrl),
          if (_model.isEditingProfile)
            Positioned(
              top: 20,
              right: 20,
              child: _buildCoverPhotoEditButton(),
            ),
        ],
      ),
    );
  }

  /// Builds the modern cover photo content with gradient templates
  Widget _buildModernCoverPhotoContent(String? coverPhotoUrl) {
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
    );

    if (coverPhotoUrl != null && coverPhotoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: CachedNetworkImage(
          imageUrl: coverPhotoUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => _buildBeautifulGradient(),
          errorWidget: (context, url, error) => _buildBeautifulGradient(),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
      ),
      child: _buildBeautifulGradient(),
    );
  }

  /// Builds beautiful gradient templates for cover photos
  Widget _buildBeautifulGradient() {
    // Create a list of beautiful gradient templates
    final gradients = [
      // LinkedIn-style professional gradients
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0077B5), // LinkedIn blue
          Color(0xFF004182),
        ],
      ),
      // Professional dark gradient
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF2C3E50),
          Color(0xFF34495E),
        ],
      ),
      // Modern tech gradient
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF667eea),
          Color(0xFF764ba2),
        ],
      ),
      // Professional green
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF11998e),
          Color(0xFF38ef7d),
        ],
      ),
      // Corporate purple
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF8360c3),
          Color(0xFF2ebf91),
        ],
      ),
    ];

    // Use user ID to consistently pick the same gradient
    final userHash = currentUserUid.hashCode;
    final selectedGradient = gradients[userHash.abs() % gradients.length];

    return Container(
      decoration: BoxDecoration(
        gradient: selectedGradient,
      ),
    );
  }

  /// Builds LinkedIn-style cover photo section
  Widget _buildLinkedInCoverPhotoSection(String? coverPhotoUrl) {
    return Container(
      height: 200,
      width: double.infinity,
      child: Stack(
        children: [
          _buildLinkedInCoverPhotoContent(coverPhotoUrl),
          if (_model.isEditingProfile)
            Positioned(
              top: 16,
              right: 16,
              child: _buildCoverPhotoEditButton(),
            ),
        ],
      ),
    );
  }

  /// Builds LinkedIn-style cover photo content
  Widget _buildLinkedInCoverPhotoContent(String? coverPhotoUrl) {
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(8),
      topRight: Radius.circular(8),
    );

    if (coverPhotoUrl != null && coverPhotoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: CachedNetworkImage(
          imageUrl: coverPhotoUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => _buildBeautifulGradient(),
          errorWidget: (context, url, error) => _buildBeautifulGradient(),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
      ),
      child: _buildBeautifulGradient(),
    );
  }

  /// Builds LinkedIn-style profile info section
  Widget _buildLinkedInProfileInfoSection(UsersRecord user, String role) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 40, 24,
          24), // Reduced top padding for overlapping profile picture
      child: Column(
        children: [
          // Profile picture space (handled by positioned widget)
          SizedBox(
              height: 30), // Reduced space for the overlapping profile picture

          // Name - Centered and Bigger
          if (_model.isEditingProfile)
            Container(
              width: double.infinity,
              child: TextField(
                controller: _model.displayNameController,
                style: FlutterFlowTheme.of(context).headlineLarge.override(
                      fontFamily: 'Inter',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      color: Color(0xFF000000),
                    ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                  hintText: 'Enter your full name',
                  hintStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        color: Color(0xFF999999),
                        fontWeight: FontWeight.w400,
                      ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFFDDDDDD)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFF0077B5), width: 2),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            )
          else
            Text(
              user.displayName,
              style: FlutterFlowTheme.of(context).headlineLarge.override(
                    fontFamily: 'Inter',
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    color: Color(0xFF000000),
                  ),
              textAlign: TextAlign.center,
            ),

          SizedBox(height: 16),

          // Bio/About Section - Multiple lines, centered
          if (_model.isEditingProfile)
            Container(
              width: double.infinity,
              constraints: BoxConstraints(maxWidth: 600),
              child: TextField(
                controller: _model.bioController,
                maxLines: 4,
                style: FlutterFlowTheme.of(context)
                    .bodyLarge
                    .override(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      letterSpacing: 0,
                      color: Color(0xFF374151),
                    )
                    .copyWith(height: 1.5),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  labelStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                  hintText: 'Tell us about yourself...',
                  hintStyle: FlutterFlowTheme.of(context)
                      .bodyMedium
                      .override(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Color(0xFF999999),
                        fontWeight: FontWeight.w400,
                      )
                      .copyWith(height: 1.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFFDDDDDD)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFF0077B5), width: 2),
                  ),
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            )
          else if (user.bio.isNotEmpty)
            Container(
              constraints: BoxConstraints(maxWidth: 600),
              child: Text(
                user.bio,
                style: FlutterFlowTheme.of(context)
                    .bodyLarge
                    .override(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      letterSpacing: 0,
                      color: Color(0xFF374151),
                    )
                    .copyWith(height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),

          SizedBox(height: 20),

          // Location - Centered with bold label
          if (user.location.isNotEmpty || _model.isEditingProfile)
            if (_model.isEditingProfile)
              Container(
                width: 300,
                child: TextField(
                  controller: _model.locationController,
                  style: FlutterFlowTheme.of(context).bodyLarge.override(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF000000),
                      ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    labelStyle:
                        FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                    hintText: 'Enter your location (e.g., New York, NY, USA)',
                    hintStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          color: Color(0xFF999999),
                          fontWeight: FontWeight.w400,
                        ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFFDDDDDD)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Color(0xFF0077B5), width: 2),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              )
            else
              Column(
                children: [
                  Text(
                    'Location: ${user.location}',
                    style: FlutterFlowTheme.of(context).bodyLarge.override(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF000000),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

          SizedBox(height: 24),

          // Contact Information
          _buildLinkedInContactInfo(user),

          SizedBox(height: 24),

          // Action Buttons
          if (_model.isEditingProfile)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FFButtonWidget(
                  onPressed: () {
                    setState(() {
                      _model.isEditingProfile = false;
                    });
                  },
                  text: 'Cancel',
                  options: FFButtonOptions(
                    height: 40,
                    padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                    color: Colors.transparent,
                    textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                          fontFamily: 'Inter',
                          color: Color(0xFF0077B5),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                    elevation: 0,
                    borderSide: BorderSide(
                      color: Color(0xFF0077B5),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                SizedBox(width: 16),
                FFButtonWidget(
                  onPressed: () async {
                    await _saveModernProfileChanges(user);
                  },
                  text: 'Save',
                  options: FFButtonOptions(
                    height: 40,
                    padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                    color: Color(0xFF0077B5),
                    textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                    elevation: 0,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            )
          else
            FFButtonWidget(
              onPressed: () {
                setState(() {
                  _model.isEditingProfile = true;
                });
              },
              text: 'Edit Profile',
              icon: Icon(Icons.edit_outlined, size: 16, color: Colors.white),
              options: FFButtonOptions(
                height: 40,
                padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                color: Color(0xFF0077B5),
                textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                elevation: 0,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds LinkedIn-style profile picture
  Widget _buildLinkedInProfilePicture() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          fadeInDuration: const Duration(milliseconds: 500),
          fadeOutDuration: const Duration(milliseconds: 500),
          imageUrl: valueOrDefault<String>(
            currentUserPhoto,
            'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
          ),
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Color(0xFFF3F4F6),
            child: Icon(
              Icons.person,
              color: Color(0xFF9CA3AF),
              size: 40,
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Color(0xFFF3F4F6),
            child: Icon(
              Icons.person,
              color: Color(0xFF9CA3AF),
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds LinkedIn-style contact information
  Widget _buildLinkedInContactInfo(UsersRecord user) {
    return Container(
      constraints: BoxConstraints(maxWidth: 500),
      child: Column(
        children: [
          // Website
          if (_model.isEditingProfile ||
              (_model.websiteController?.text.isNotEmpty ?? false))
            Container(
              margin: EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_model.isEditingProfile)
                    Expanded(
                      child: TextField(
                        controller: _model.websiteController,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              letterSpacing: 0,
                              color: Color(0xFF000000),
                            ),
                        textAlign: TextAlign.left,
                        decoration: InputDecoration(
                          labelText: 'Website',
                          labelStyle:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                          hintText: 'https://www.example.com',
                          hintStyle:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    color: Color(0xFF999999),
                                    fontWeight: FontWeight.w400,
                                  ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Color(0xFFDDDDDD)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide:
                                BorderSide(color: Color(0xFF0077B5), width: 2),
                          ),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Website:',
                          style:
                              FlutterFlowTheme.of(context).bodyLarge.override(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                    color: Color(0xFF000000),
                                  ),
                        ),
                        SizedBox(width: 16),
                        Text(
                          _model.websiteController?.text ?? '',
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    letterSpacing: 0,
                                    color: Color(0xFF000000),
                                  ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

          // Email
          Container(
            margin: EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Email:',
                  style: FlutterFlowTheme.of(context).bodyLarge.override(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: Color(0xFF000000),
                      ),
                ),
                SizedBox(width: 16),
                Text(
                  currentUserEmail,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        letterSpacing: 0,
                        color: Color(0xFF000000),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the profile picture widget
  Widget _buildProfilePicture() {
    return Transform.translate(
      offset: Offset(0, _profilePictureOffset),
      child: Center(
        child: Stack(
          children: [
            AuthUserStreamWidget(
              builder: (context) => _buildProfilePictureContainer(),
            ),
            if (_model.isEditingProfile) _buildProfilePictureEditButton(),
          ],
        ),
      ),
    );
  }

  /// Builds the profile picture container
  Widget _buildProfilePictureContainer() {
    return Container(
      width: _profilePictureSize,
      height: _profilePictureSize,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: _profilePictureBorderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: CachedNetworkImage(
        fadeInDuration: const Duration(milliseconds: 500),
        fadeOutDuration: const Duration(milliseconds: 500),
        imageUrl: valueOrDefault<String>(
          currentUserPhoto,
          'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
        ),
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildProfilePicturePlaceholder(),
        errorWidget: (context, url, error) => _buildProfilePicturePlaceholder(),
      ),
    );
  }

  /// Builds the profile picture placeholder
  Widget _buildProfilePicturePlaceholder() {
    return Container(
      color: _backgroundColor,
      child: Icon(
        Icons.person,
        color: _textColorSecondary,
        size: 50,
      ),
    );
  }

  /// Builds the profile picture edit button
  Widget _buildProfilePictureEditButton() {
    return Positioned(
      bottom: 4,
      right: 4,
      child: InkWell(
        onTap: () => context.pushNamed(EditProfileWidget.routeName),
        child: Container(
          width: 40.0,
          height: 40.0,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primary,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 3.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.camera_alt_rounded,
            color: Colors.white,
            size: 20.0,
          ),
        ),
      ),
    );
  }

  /// Builds the profile info section with picture and details
  Widget _buildProfileInfoSection(UsersRecord user, String role) {
    return Container(
      padding: EdgeInsets.fromLTRB(32, 80, 32, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_borderRadius),
          bottomRight: Radius.circular(_borderRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfilePicture(),
          SizedBox(height: 12),
          // Name, Role, Bio, and Location - all centered
          Center(
            child: Column(
              children: [
                // Name
                if (_model.isEditingProfile)
                  TextField(
                    controller: _model.displayNameController,
                    style: FlutterFlowTheme.of(context).headlineMedium.override(
                          fontFamily: 'Inter',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  )
                else
                  Text(
                    user.displayName,
                    style: FlutterFlowTheme.of(context).headlineMedium.override(
                          fontFamily: 'Inter',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                    textAlign: TextAlign.center,
                  ),
                SizedBox(height: 8),
                // Role
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        FlutterFlowTheme.of(context).primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    role.isNotEmpty ? role : 'Member',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: FlutterFlowTheme.of(context).primary,
                          letterSpacing: 0,
                        ),
                  ),
                ),
                SizedBox(height: 12),
                // Bio (centered, multi-line, no label)
                if (_model.isEditingProfile)
                  SizedBox(
                    width: double.infinity,
                    child: TextField(
                      controller: _model.bioController,
                      maxLines: null,
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            letterSpacing: 0,
                          ),
                      decoration: InputDecoration(
                        hintText: 'Tell us about yourself...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  )
                else
                  user.bio.isNotEmpty
                      ? Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            user.bio,
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  letterSpacing: 0,
                                  color: Color(0xFF374151),
                                ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : SizedBox.shrink(),
                SizedBox(height: 12),
                // Location (centered with icon)
                if (user.location.isNotEmpty || _model.isEditingProfile)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: FlutterFlowTheme.of(context).secondaryText,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      _model.isEditingProfile
                          ? SizedBox(
                              width: 200,
                              child: TextField(
                                controller: _model.locationController,
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      letterSpacing: 0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: 'Location',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                              ),
                            )
                          : Text(
                              user.location,
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    letterSpacing: 0,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF374151),
                                  ),
                            ),
                    ],
                  ),
              ],
            ),
          ),
          SizedBox(height: 32),
          _buildProfileActionButtons(user),
        ],
      ),
    );
  }

  /// Builds the profile action buttons (Edit/Save/Cancel)
  Widget _buildProfileActionButtons(UsersRecord user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!_model.isEditingProfile)
          _buildEditProfileButton()
        else
          ..._buildSaveCancelButtons(user),
      ],
    );
  }

  /// Builds the edit profile button
  Widget _buildEditProfileButton() {
    return FFButtonWidget(
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
    );
  }

  /// Builds the save and cancel buttons
  List<Widget> _buildSaveCancelButtons(UsersRecord user) {
    return [
      _buildCancelButton(),
      SizedBox(width: 12),
      _buildSaveButton(user),
    ];
  }

  /// Builds the cancel button
  Widget _buildCancelButton() {
    return FFButtonWidget(
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
    );
  }

  /// Builds the save button
  Widget _buildSaveButton(UsersRecord user) {
    return FFButtonWidget(
      onPressed: () => _saveProfileChanges(user),
      text: 'Save',
      icon: Icon(Icons.check, size: 16),
      options: FFButtonOptions(
        height: 44,
        padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
        iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 8, 0),
        color: Colors.green,
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
    );
  }

  /// Builds the modern profile info section
  Widget _buildModernProfileInfoSection(UsersRecord user, String role) {
    return Container(
      padding: EdgeInsets.fromLTRB(32, 0, 32, 32),
      child: Column(
        children: [
          // Profile Picture (overlapping the cover photo)
          Transform.translate(
            offset: Offset(0, -70),
            child: _buildModernProfilePicture(),
          ),

          // Name
          Transform.translate(
            offset: Offset(0, -50),
            child: Column(
              children: [
                if (_model.isEditingProfile)
                  Container(
                    width: 300,
                    child: TextField(
                      controller: _model.displayNameController,
                      style:
                          FlutterFlowTheme.of(context).headlineMedium.override(
                                fontFamily: 'Inter',
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).alternate),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).primary,
                              width: 2),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  )
                else
                  Text(
                    user.displayName,
                    style: FlutterFlowTheme.of(context).headlineMedium.override(
                          fontFamily: 'Inter',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          color: Color(0xFF1F2937),
                        ),
                    textAlign: TextAlign.center,
                  ),

                SizedBox(height: 12),

                // Role (Optional)
                if (_model.isEditingProfile)
                  Container(
                    width: 250,
                    child: TextField(
                      controller: _model.roleController,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'Role (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).alternate),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).primary,
                              width: 2),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  )
                else if (role.isNotEmpty ||
                    (_model.roleController?.text.isNotEmpty ?? false))
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          FlutterFlowTheme.of(context).primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: FlutterFlowTheme.of(context)
                            .primary
                            .withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _model.roleController?.text.isNotEmpty == true
                          ? _model.roleController!.text
                          : role,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: FlutterFlowTheme.of(context).primary,
                            letterSpacing: 0,
                          ),
                    ),
                  ),

                SizedBox(height: 16),

                // Bio
                if (_model.isEditingProfile)
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxWidth: 500),
                    child: TextField(
                      controller: _model.bioController,
                      maxLines: 3,
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context)
                          .bodyMedium
                          .override(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            letterSpacing: 0,
                          )
                          .copyWith(height: 1.5),
                      decoration: InputDecoration(
                        hintText: 'Tell us about yourself...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).alternate),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).primary,
                              width: 2),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  )
                else if (user.bio.isNotEmpty)
                  Container(
                    constraints: BoxConstraints(maxWidth: 500),
                    child: Text(
                      user.bio,
                      style: FlutterFlowTheme.of(context)
                          .bodyMedium
                          .override(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            letterSpacing: 0,
                            color: Color(0xFF6B7280),
                          )
                          .copyWith(height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ),

                SizedBox(height: 20),

                // Location
                if (user.location.isNotEmpty || _model.isEditingProfile)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFF6B7280),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      _model.isEditingProfile
                          ? Container(
                              width: 200,
                              child: TextField(
                                controller: _model.locationController,
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      letterSpacing: 0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: 'Location',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context)
                                            .primary,
                                        width: 2),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                              ),
                            )
                          : Text(
                              user.location,
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    letterSpacing: 0,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF374151),
                                  ),
                            ),
                    ],
                  ),

                SizedBox(height: 24),

                // Contact Information
                _buildContactInfo(user),

                SizedBox(height: 32),

                // Action Buttons
                _buildModernActionButtons(user),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the modern profile picture
  Widget _buildModernProfilePicture() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                fadeInDuration: const Duration(milliseconds: 500),
                fadeOutDuration: const Duration(milliseconds: 500),
                imageUrl: valueOrDefault<String>(
                  currentUserPhoto,
                  'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                ),
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Color(0xFFF3F4F6),
                  child: Icon(
                    Icons.person,
                    color: Color(0xFF9CA3AF),
                    size: 50,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Color(0xFFF3F4F6),
                  child: Icon(
                    Icons.person,
                    color: Color(0xFF9CA3AF),
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
          if (_model.isEditingProfile)
            Positioned(
              bottom: 8,
              right: 8,
              child: InkWell(
                onTap: () => context.pushNamed(EditProfileWidget.routeName),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds contact information section
  Widget _buildContactInfo(UsersRecord user) {
    return Column(
      children: [
        // Website (Optional)
        if (_model.isEditingProfile ||
            (_model.websiteController?.text.isNotEmpty ?? false))
          Container(
            margin: EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.language,
                    color: Color(0xFF6B7280),
                    size: 18,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Website:',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                        letterSpacing: 0,
                      ),
                ),
                SizedBox(width: 8),
                _model.isEditingProfile
                    ? Container(
                        width: 250,
                        child: TextField(
                          controller: _model.websiteController,
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    letterSpacing: 0,
                                  ),
                          decoration: InputDecoration(
                            hintText: 'www.example.com (Optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color:
                                      FlutterFlowTheme.of(context).alternate),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).primary,
                                  width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      )
                    : Text(
                        _model.websiteController?.text ?? '',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              letterSpacing: 0,
                              color: FlutterFlowTheme.of(context).primary,
                            ),
                      ),
              ],
            ),
          ),

        // Email (Optional)
        Container(
          margin: EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.email_outlined,
                  color: Color(0xFF6B7280),
                  size: 18,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Email:',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                      letterSpacing: 0,
                    ),
              ),
              SizedBox(width: 8),
              Text(
                currentUserEmail,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      letterSpacing: 0,
                      color: Color(0xFF6B7280),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds modern action buttons
  Widget _buildModernActionButtons(UsersRecord user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!_model.isEditingProfile)
          FFButtonWidget(
            onPressed: () {
              setState(() {
                _model.isEditingProfile = true;
              });
            },
            text: 'Edit Profile',
            icon: Icon(Icons.edit_outlined, size: 18),
            options: FFButtonOptions(
              height: 48,
              padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
              iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 8, 0),
              color: FlutterFlowTheme.of(context).primary,
              textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
              elevation: 0,
              borderRadius: BorderRadius.circular(12),
            ),
          )
        else ...[
          FFButtonWidget(
            onPressed: () {
              setState(() {
                _model.isEditingProfile = false;
              });
            },
            text: 'Cancel',
            options: FFButtonOptions(
              height: 48,
              padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
              color: Color(0xFF6B7280),
              textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
              elevation: 0,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          SizedBox(width: 16),
          FFButtonWidget(
            onPressed: () async {
              await _saveModernProfileChanges(user);
            },
            text: 'Save Changes',
            icon: Icon(Icons.check, size: 18),
            options: FFButtonOptions(
              height: 48,
              padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
              iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 8, 0),
              color: Color(0xFF10B981),
              textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
              elevation: 0,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ],
    );
  }

  /// Saves profile changes to Firestore
  Future<void> _saveProfileChanges(UsersRecord user) async {
    try {
      await user.reference.update({
        'display_name': _model.displayNameController?.text ?? user.displayName,
        'location': _model.locationController?.text ?? user.location,
        'bio': _model.bioController?.text ?? user.bio,
      });

      // Exit edit mode first
      if (mounted) {
        setState(() {
          _model.isEditingProfile = false;
        });
      }

      // Show success message using the safe helper method
      _showSuccessSnackBar('Profile updated successfully');
    } catch (e) {
      // Handle error and exit edit mode
      if (mounted) {
        setState(() {
          _model.isEditingProfile = false;
        });
      }

      // Show error message using the safe helper method
      _showErrorSnackBar('Failed to update profile. Please try again.');
    }
  }

  /// Saves modern profile changes to Firestore
  Future<void> _saveModernProfileChanges(UsersRecord user) async {
    try {
      await user.reference.update({
        'display_name': _model.displayNameController?.text ?? user.displayName,
        'location': _model.locationController?.text ?? user.location,
        'bio': _model.bioController?.text ?? user.bio,
        'website': _model.websiteController?.text ?? '',
        'role': _model.roleController?.text ?? '',
      });

      // Exit edit mode first
      if (mounted) {
        setState(() {
          _model.isEditingProfile = false;
        });
      }

      // Show success message using the safe helper method
      _showSuccessSnackBar('Profile updated successfully!');
    } catch (e) {
      // Handle error and exit edit mode
      if (mounted) {
        setState(() {
          _model.isEditingProfile = false;
        });
      }

      // Show error message using the safe helper method
      _showErrorSnackBar('Failed to update profile. Please try again.');
    }
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
            'Enable or disable notifications. This setting syncs with your system notification preferences.',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
          ),
          SizedBox(height: 24),
          _isLoadingNotificationStatus
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _buildNotificationToggle(
                  'Notifications', _notificationsEnabled),
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

  Widget _buildNotificationToggle(String label, bool value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              SizedBox(height: 4),
              Text(
                value
                    ? 'Notifications are enabled in system settings'
                    : 'Notifications are disabled in system settings',
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: (newValue) async {
            if (newValue) {
              // Turning ON - Request system notification permission
              bool permissionGranted = false;

              if (kIsWeb) {
                // For web, request browser notification permission (will show browser dialog)
                try {
                  final permission =
                      await WebNotificationService.instance.requestPermission();
                  permissionGranted = permission == 'granted';

                  if (mounted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          permissionGranted
                              ? '✅ Notifications enabled'
                              : '❌ Permission denied. Please allow notifications in your browser.',
                        ),
                        backgroundColor: permissionGranted
                            ? Color(0xFF10B981)
                            : Color(0xFFEF4444),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  print('Error requesting web notification permission: $e');
                  permissionGranted = false;
                }
              } else if (Platform.isMacOS || Platform.isIOS) {
                // For macOS/iOS, check current status first
                try {
                  final messaging = FirebaseMessaging.instance;
                  final currentSettings =
                      await messaging.getNotificationSettings();

                  // If already authorized, just enable
                  if (currentSettings.authorizationStatus ==
                          AuthorizationStatus.authorized ||
                      currentSettings.authorizationStatus ==
                          AuthorizationStatus.provisional) {
                    permissionGranted = true;
                  }
                  // If not determined, request permission (will show system dialog)
                  else if (currentSettings.authorizationStatus ==
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
                  }
                  // If denied, open system settings
                  else {
                    // Permission was denied, open system settings
                    final settingsOpened = await openAppSettings();
                    if (mounted && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            settingsOpened
                                ? 'Opening system settings... Please enable notifications there.'
                                : 'Please enable notifications in System Settings > Notifications.',
                          ),
                          backgroundColor: Color(0xFFEF4444),
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                    permissionGranted = false;
                  }
                } catch (e) {
                  print('Error requesting notification permission: $e');
                  permissionGranted = false;
                }
              }

              // Update state based on actual permission result
              setState(() {
                _notificationsEnabled = permissionGranted;
              });

              // Update Firestore
              if (currentUserReference != null) {
                await currentUserReference!.update({
                  'notifications_enabled': permissionGranted,
                });
              }

              // Show success feedback if permission was granted
              if (permissionGranted && mounted && context.mounted && !kIsWeb) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Notifications enabled'),
                    backgroundColor: Color(0xFF10B981),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } else {
              // Turning OFF - Open system settings to disable
              setState(() {
                _notificationsEnabled = false;
              });

              // Update Firestore first
              if (currentUserReference != null) {
                await currentUserReference!.update({
                  'notifications_enabled': false,
                });
              }

              // Open system settings so user can disable notifications
              bool settingsOpened = false;

              if (kIsWeb) {
                // For web, show message (can't programmatically revoke)
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please disable notifications in your browser settings.',
                      ),
                      backgroundColor: Color(0xFFEF4444),
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              } else {
                // For macOS/iOS, open system settings
                try {
                  settingsOpened = await openAppSettings();
                } catch (e) {
                  print('Error opening system settings: $e');
                }

                // Show feedback
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        settingsOpened
                            ? 'Opening system settings... Please disable notifications there.'
                            : 'Please disable notifications in System Settings > Notifications.',
                      ),
                      backgroundColor: Color(0xFFEF4444),
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              }
            }

            // Reload to sync with system after a delay
            Future.delayed(Duration(seconds: 2), () {
              if (mounted) {
                _loadNotificationSettings();
              }
            });
          },
          activeThumbColor: const Color(0xFF2563EB),
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
                          'inviterName': currentUserDisplayName,
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

  /// Builds the modern cover photo edit button with dropdown menu
  Widget _buildCoverPhotoEditButton() {
    return PopupMenuButton<String>(
      key: _coverPhotoDropdownKey,
      tooltip: 'Edit cover photo',
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      offset: Offset(0, 50),
      child: _buildCoverPhotoButtonContent(),
      itemBuilder: (BuildContext context) => _buildCoverPhotoMenuItems(),
      onSelected: _handleCoverPhotoMenuSelection,
    );
  }

  /// Builds the cover photo button content
  Widget _buildCoverPhotoButtonContent() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_coverPhotoButtonBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.camera_alt_rounded,
            color: FlutterFlowTheme.of(context).primary,
            size: 18,
          ),
          SizedBox(width: 8),
          Text(
            'Edit Cover',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: FlutterFlowTheme.of(context).primary,
            ),
          ),
          SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: FlutterFlowTheme.of(context).primary,
            size: 18,
          ),
        ],
      ),
    );
  }

  /// Builds the cover photo menu items
  List<PopupMenuItem<String>> _buildCoverPhotoMenuItems() {
    return [
      PopupMenuItem<String>(
        value: 'template',
        child: _buildMenuItemContent(
          icon: Icons.palette_outlined,
          text: 'Choose from Template',
        ),
      ),
      PopupMenuItem<String>(
        value: 'upload',
        child: _buildMenuItemContent(
          icon: Icons.upload_outlined,
          text: 'Upload Photo',
        ),
      ),
    ];
  }

  /// Builds menu item content with icon and text
  Widget _buildMenuItemContent({
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: FlutterFlowTheme.of(context).primary,
          size: 20,
        ),
        SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textColorPrimary,
          ),
        ),
      ],
    );
  }

  /// Handles cover photo menu selection
  void _handleCoverPhotoMenuSelection(String value) {
    if (value == 'upload') {
      _pickCoverPhoto();
    } else if (value == 'template') {
      _showCoverPhotoTemplates();
    }
  }

  /// Picks cover photo from device gallery
  Future<void> _pickCoverPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        await _uploadCoverPhoto(image);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error picking image: $e');
      }
    }
  }

  /// Uploads cover photo to Firebase Storage
  Future<void> _uploadCoverPhoto(XFile imageFile) async {
    if (!mounted || !context.mounted) return;

    // Check if currentUserReference is available
    final currentUser = currentUserReference;
    if (currentUser == null) {
      if (mounted && context.mounted) {
        _showErrorSnackBar('Error: User not found. Please log in again.');
      }
      return;
    }

    BuildContext? dialogContext;
    try {
      if (mounted && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogBuildContext) {
            dialogContext = dialogBuildContext;
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  FlutterFlowTheme.of(context).primary,
                ),
              ),
            );
          },
        );
      }

      final downloadUrl = await _performImageUpload(imageFile);
      await _updateCoverPhotoUrl(downloadUrl);

      if (mounted && context.mounted && dialogContext != null) {
        if (Navigator.canPop(dialogContext!)) {
          Navigator.of(dialogContext!).pop();
        }
        _showSuccessSnackBar('Cover photo updated successfully');
      }
    } catch (e) {
      if (mounted && context.mounted && dialogContext != null) {
        if (Navigator.canPop(dialogContext!)) {
          Navigator.of(dialogContext!).pop();
        }
        if (mounted && context.mounted) {
          _showErrorSnackBar('Error uploading cover photo: $e');
        }
      }
    }
  }

  /// Performs the image upload to Firebase Storage
  Future<String> _performImageUpload(XFile imageFile) async {
    final currentUser = currentUserReference;
    if (currentUser == null) {
      throw Exception('User not found');
    }

    try {
      final fileName =
          'cover_photos/${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        uploadTask = ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        final file = File(imageFile.path);
        if (!await file.exists()) {
          throw Exception('Image file does not exist');
        }
        uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      // Wait for upload to complete and check for errors
      final snapshot = await uploadTask.whenComplete(() {});

      // Check if upload was successful
      if (snapshot.state != TaskState.success) {
        throw Exception('Upload failed with state: ${snapshot.state}');
      }

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      if (downloadUrl.isEmpty) {
        throw Exception('Failed to get download URL');
      }

      return downloadUrl;
    } catch (e) {
      // Provide more detailed error information
      print('Firebase Storage upload error: $e');
      if (e is FirebaseException) {
        throw Exception('Firebase Storage error: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  /// Updates the cover photo URL in user document
  Future<void> _updateCoverPhotoUrl(String downloadUrl) async {
    final currentUser = currentUserReference;
    if (currentUser == null) {
      throw Exception('User not found');
    }

    await currentUser.update({
      'cover_photo_url': downloadUrl,
      'cover_photo_template': '', // Clear template when uploading custom photo
    });
  }

  /// Shows success snackbar
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    // Use SchedulerBinding to ensure we're in a safe state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: _successColor,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        } catch (e) {
          // Silently fail if context is invalid
          print('Error showing success snackbar: $e');
        }
      }
    });
  }

  /// Shows error snackbar
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    // Use SchedulerBinding to ensure we're in a safe state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: _errorColor,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        } catch (e) {
          // Silently fail if context is invalid
          print('Error showing error snackbar: $e');
        }
      }
    });
  }

  /// Gets the list of cover photo templates
  List<Map<String, dynamic>> _getCoverPhotoTemplates() {
    return [
      // Sober Templates - Black Gradients
      {
        'name': 'Black Deep',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF000000), Color(0xFF1A1A1A)],
        ),
      },
      {
        'name': 'Black Elegant',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
        ),
      },
      {
        'name': 'Charcoal',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C2C2C), Color(0xFF4A4A4A)],
        ),
      },
      // Sober Templates - White Gradients
      {
        'name': 'White Pure',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF5F5F5)],
        ),
      },
      {
        'name': 'White Soft',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8F8F8), Color(0xFFE5E5E5)],
        ),
      },
      {
        'name': 'Pearl',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0F0F0), Color(0xFFD0D0D0)],
        ),
      },
      // Sober Templates - Brown Gradients
      {
        'name': 'Brown Rich',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5D4037), Color(0xFF3E2723)],
        ),
      },
      {
        'name': 'Brown Warm',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8D6E63), Color(0xFF6D4C41)],
        ),
      },
      {
        'name': 'Brown Mocha',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6F4E37), Color(0xFF4A3428)],
        ),
      },
      // Sober Templates - Gray Gradients
      {
        'name': 'Gray Classic',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF616161), Color(0xFF424242)],
        ),
      },
      {
        'name': 'Gray Modern',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF757575), Color(0xFF616161)],
        ),
      },
      {
        'name': 'Gray Slate',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF546E7A), Color(0xFF37474F)],
        ),
      },
      // Colorful Templates
      {
        'name': 'Gradient Blue',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
        ),
      },
      {
        'name': 'Gradient Purple',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
        ),
      },
      {
        'name': 'Gradient Green',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
      },
      {
        'name': 'Gradient Orange',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        ),
      },
      {
        'name': 'Gradient Pink',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
        ),
      },
      {
        'name': 'Gradient Teal',
        'gradient': LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
        ),
      },
    ];
  }

  /// Shows cover photo template selection dialog
  void _showCoverPhotoTemplates() {
    if (mounted) {
      final templates = _getCoverPhotoTemplates();

      showDialog(
        context: context,
        builder: (context) => _buildTemplateSelectionDialog(templates),
      );
    }
  }

  /// Builds the template selection dialog
  Widget _buildTemplateSelectionDialog(List<Map<String, dynamic>> templates) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
      ),
      child: Container(
        width: 600,
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTemplateDialogHeader(),
            SizedBox(height: 20),
            _buildTemplateGrid(templates),
          ],
        ),
      ),
    );
  }

  /// Builds the template dialog header
  Widget _buildTemplateDialogHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Choose a Template',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        IconButton(
          icon: Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
          color: Color(0xFF6B7280),
        ),
      ],
    );
  }

  /// Builds the template grid
  Widget _buildTemplateGrid(List<Map<String, dynamic>> templates) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.8,
      ),
      itemCount: templates.length,
      itemBuilder: (context, index) => _buildTemplateItem(templates[index]),
    );
  }

  /// Builds a single template item
  Widget _buildTemplateItem(Map<String, dynamic> template) {
    final gradient = template['gradient'];
    if (gradient is! LinearGradient) {
      return Container(); // Return empty container if gradient is invalid
    }

    final textColor = _getTextColorForGradient(gradient);

    return InkWell(
      onTap: () async {
        // Check if widget is still mounted before proceeding
        if (!mounted) return;

        // Get the dialog context before closing
        final dialogContext = context;

        try {
          // Close the template dialog first
          if (Navigator.canPop(dialogContext)) {
            Navigator.of(dialogContext).pop();
          }

          // Wait for the dialog to fully close
          await Future.delayed(Duration(milliseconds: 300));

          // Check if widget is still mounted before proceeding
          if (mounted) {
            await _applyCoverPhotoTemplate(gradient);
          }
        } catch (e) {
          // Handle any errors during template application
          if (mounted && context.mounted) {
            _showErrorSnackBar('Error selecting template: $e');
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: textColor == Colors.white
                ? Colors.white.withOpacity(0.3)
                : Colors.black.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            template['name'] as String,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  /// Determines appropriate text color based on gradient brightness
  Color _getTextColorForGradient(LinearGradient gradient) {
    // Get the first color from the gradient
    if (gradient.colors.isEmpty) {
      return Colors.white; // Default to white if no colors
    }

    final firstColor = gradient.colors.first;

    // Calculate luminance (brightness) of the color
    // Formula: 0.299*R + 0.587*G + 0.114*B
    final luminance = (0.299 * firstColor.red +
            0.587 * firstColor.green +
            0.114 * firstColor.blue) /
        255;

    // If luminance is high (light color), use dark text, otherwise use white
    return luminance > 0.5 ? Color(0xFF111827) : Colors.white;
  }

  /// Applies the selected cover photo template
  Future<void> _applyCoverPhotoTemplate(LinearGradient gradient) async {
    if (!mounted || !context.mounted) return;

    // Check if currentUserReference is available
    final currentUser = currentUserReference;
    if (currentUser == null) {
      if (mounted && context.mounted) {
        _showErrorSnackBar('Error: User not found. Please log in again.');
      }
      return;
    }

    // Show loading dialog
    BuildContext? dialogContext;
    if (mounted && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogBuildContext) {
          dialogContext = dialogBuildContext;
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                FlutterFlowTheme.of(context).primary,
              ),
            ),
          );
        },
      );
    }

    try {
      // Validate gradient has colors
      if (gradient.colors.isEmpty) {
        throw Exception('Invalid gradient: no colors found');
      }

      // Store gradient colors as a template identifier
      // Convert gradient to a simple identifier based on first color
      final firstColor = gradient.colors.first;
      final secondColor =
          gradient.colors.length > 1 ? gradient.colors[1] : firstColor;

      // Create a template identifier from colors
      final templateId = 'gradient_${firstColor.value}_${secondColor.value}';

      // For template gradients, clear the URL and store template info
      await currentUser.update({
        'cover_photo_url': '', // Clear to show gradient
        'cover_photo_template': templateId, // Store template identifier
      });

      // Close loading dialog if still mounted
      if (mounted && context.mounted && dialogContext != null) {
        if (Navigator.canPop(dialogContext!)) {
          Navigator.of(dialogContext!).pop();
        }
        _showSuccessSnackBar('Cover photo template applied successfully');
      }
    } catch (e) {
      // Close loading dialog if still mounted
      if (mounted && context.mounted && dialogContext != null) {
        if (Navigator.canPop(dialogContext!)) {
          Navigator.of(dialogContext!).pop();
        }
        if (mounted && context.mounted) {
          _showErrorSnackBar('Error applying template: $e');
        }
      }
    }
  }
}
