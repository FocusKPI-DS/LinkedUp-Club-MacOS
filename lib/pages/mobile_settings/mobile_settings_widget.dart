import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:math';

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

class _MobileSettingsWidgetState extends State<MobileSettingsWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  // State variables
  String _selectedSetting = '';
  bool _isCreatingWorkspace = false;
  bool _isDeletingWorkspace = false;
  bool _isJoiningWorkspace = false;
  String _searchQuery = '';

  // Controllers
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _workspaceNameController =
      TextEditingController();
  final TextEditingController _workspaceDescriptionController =
      TextEditingController();
  final TextEditingController _deleteConfirmationController =
      TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();

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
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _workspaceNameController.dispose();
    _workspaceDescriptionController.dispose();
    _deleteConfirmationController.dispose();
    _inviteCodeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userDoc = await UsersRecord.getDocumentOnce(currentUserReference!);
    _displayNameController.text = userDoc.displayName;
    _emailController.text = userDoc.email;
    _locationController.text = userDoc.location;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.white,
      body: SafeArea(
        top: _selectedSetting.isEmpty ? true : false,
        child: _selectedSetting.isEmpty
            ? Column(
                children: [
                  // iOS-style Header
                  _buildIOSHeader(),
                  // Main Content
                  Expanded(
                    child: _buildMainContent(),
                  ),
                ],
              )
            : _buildMainContent(),
      ),
    );
  }

  Widget _buildIOSHeader() {
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
          // Title - only show for main settings page
          if (_selectedSetting.isEmpty)
            Expanded(
              child: Text(
                'Settings',
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

  Widget _buildMainContent() {
    if (_isCreatingWorkspace) {
      return _buildCreateWorkspaceContent();
    }
    if (_isDeletingWorkspace) {
      return _buildDeleteWorkspaceContent();
    }
    if (_isJoiningWorkspace) {
      return _buildJoinWorkspaceContent();
    }

    // Show content based on selected setting
    switch (_selectedSetting) {
      case 'Personal Information':
        return _buildPersonalInformationContent();
      case 'Workspace Management':
        return _buildWorkspaceManagementContent();
      case 'Notifications':
        return _buildNotificationsContent();
      case 'Privacy & Security':
        return _buildPrivacySecurityContent();
      case 'Contact Support':
        return _buildContactSupportContent();
      case 'FAQs':
        return _buildFAQsContent();
      default:
        return _buildMainSettingsPage();
    }
  }

  Widget _buildMainSettingsPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Profile Header Section
          _buildProfileHeader(),
          SizedBox(height: 24),
          // Community Section
          _buildCommunitySection(),
          SizedBox(height: 24),
          // Settings List
          _buildSettingsList(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          // Profile Picture
          GestureDetector(
            onTap: _showPhotoOptions,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFFF2F2F7),
                  child: currentUserPhoto.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: currentUserPhoto,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: 50,
                          color: Color(0xFF8E8E93),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(0xFF007AFF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          // User Name
          Text(
            currentUserDisplayName.isNotEmpty ? currentUserDisplayName : 'User',
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
          SizedBox(height: 24),
          // Invite Friend Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // TODO: Implement invite friend functionality
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF007AFF),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Invite Friend',
                style: TextStyle(
                  fontFamily: 'System',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunitySection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Workspace Management Card
          _buildCommunityCard(
            icon: Icons.business,
            iconColor: Color(0xFF007AFF),
            title: 'Workspace Management',
            subtitle: 'Manage your workspaces and members',
            hasChevron: true,
            onTap: () {
              setState(() {
                _selectedSetting = 'Workspace Management';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool hasStatusDot = false,
    Color? statusColor,
    bool hasChevron = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'System',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'System',
                      fontSize: 14,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
            if (hasStatusDot)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
            if (hasChevron)
              Icon(
                Icons.chevron_right,
                color: Color(0xFF8E8E93),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsList() {
    final settingsItems = [
      {
        'icon': Icons.person_outline_rounded,
        'label': 'Personal Information',
        'page': 'Personal Information',
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
        'icon': Icons.integration_instructions_outlined,
        'label': 'Integrations',
        'page': 'Integrations',
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
    return SingleChildScrollView(
      child: Column(
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
          // Content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Picture Section
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _showPhotoOptions,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Color(0xFFF2F2F7),
                              child: currentUserPhoto.isNotEmpty
                                  ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: currentUserPhoto,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Color(0xFF8E8E93),
                                    ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Color(0xFF007AFF),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Tap to change photo',
                        style: TextStyle(
                          fontFamily: 'System',
                          fontSize: 14,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
                // Form Fields
                _buildFormField(
                  label: 'Display Name',
                  controller: _displayNameController,
                  icon: Icons.person_outline,
                  onChanged: (value) => _autoSaveProfile(),
                ),
                SizedBox(height: 16),
                _buildFormField(
                  label: 'Email',
                  controller: _emailController,
                  icon: Icons.email_outlined,
                  enabled: false, // Email is usually not editable
                ),
                SizedBox(height: 16),
                _buildFormField(
                  label: 'Location',
                  controller: _locationController,
                  icon: Icons.location_on_outlined,
                  onChanged: (value) => _autoSaveProfile(),
                ),
                SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'System',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1D1D1F),
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFE5E7EB)),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Color(0xFF8E8E93), size: 20),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: TextStyle(
              fontFamily: 'System',
              fontSize: 16,
              color: Color(0xFF1D1D1F),
            ),
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

  Future<void> _autoSaveProfile() async {
    try {
      // Debounce the save operation to avoid too many API calls
      await Future.delayed(Duration(milliseconds: 500));

      final currentUser = currentUserReference;
      if (currentUser == null) return;

      await currentUser.update({
        'display_name': _displayNameController.text.trim(),
        'location': _locationController.text.trim(),
      });
    } catch (e) {
      // Show error feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildWorkspaceManagementContent() {
    return StreamBuilder<UsersRecord>(
      stream: UsersRecord.getDocument(currentUserReference!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final currentUser = snapshot.data!;

        if (currentUser.currentWorkspaceRef == null) {
          return _buildNoWorkspaceView();
        }

        return _buildWorkspaceManagementView();
      },
    );
  }

  Widget _buildNoWorkspaceView() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_outlined,
            size: 64,
            color: Color(0xFF8E8E93),
          ),
          SizedBox(height: 16),
          Text(
            'No Workspace',
            style: TextStyle(
              fontFamily: 'System',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1D1F),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You are not currently part of any workspace.',
            style: TextStyle(
              fontFamily: 'System',
              fontSize: 16,
              color: Color(0xFF8E8E93),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _isCreatingWorkspace = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF007AFF),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Create Workspace',
                style: TextStyle(
                  fontFamily: 'System',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _isJoiningWorkspace = true;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Color(0xFF007AFF),
                side: BorderSide(color: Color(0xFF007AFF)),
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Join Workspace',
                style: TextStyle(
                  fontFamily: 'System',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceManagementView() {
    return SingleChildScrollView(
      child: Column(
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
                    'Workspace Management',
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
          // Content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Create and Join Buttons
                Row(
                  children: [
                    Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isJoiningWorkspace = true;
                        });
                      },
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Color(0xFF007AFF), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.group_add,
                                color: Color(0xFF007AFF), size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Join',
                              style: TextStyle(
                                fontFamily: 'System',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isCreatingWorkspace = true;
                        });
                      },
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF007AFF),
                              Color(0xFF0056CC),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Create',
                              style: TextStyle(
                                fontFamily: 'System',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Manage your workspaces and team members.',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 14,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                SizedBox(height: 16),

                // Current Workspace Info
                StreamBuilder<UsersRecord>(
                  stream: UsersRecord.getDocument(currentUserReference!),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final user = userSnapshot.data!;
                    if (user.currentWorkspaceRef == null) {
                      return _buildNoWorkspaceView();
                    }

                    return StreamBuilder<WorkspacesRecord>(
                      stream: WorkspacesRecord.getDocument(
                          user.currentWorkspaceRef!),
                      builder: (context, workspaceSnapshot) {
                        if (!workspaceSnapshot.hasData) {
                          return Center(child: CircularProgressIndicator());
                        }

                        final workspace = workspaceSnapshot.data!;
                        return _buildCurrentWorkspaceCard(workspace);
                      },
                    );
                  },
                ),

                SizedBox(height: 16),

                SizedBox(height: 16),

                SizedBox(height: 16),

                // Workspace Members Section
                Text(
                  'Workspace Members',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
                SizedBox(height: 16),

                // Search Bar
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFFE5E7EB)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search members...',
                      hintStyle: TextStyle(
                        fontFamily: 'System',
                        fontSize: 14,
                        color: Color(0xFF8E8E93),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: Color(0xFF8E8E93),
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    style: TextStyle(
                      fontFamily: 'System',
                      fontSize: 14,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Members List
                StreamBuilder<UsersRecord>(
                  stream: UsersRecord.getDocument(currentUserReference!),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData ||
                        userSnapshot.data!.currentWorkspaceRef == null) {
                      return Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'No workspace selected',
                            style: TextStyle(
                              fontFamily: 'System',
                              fontSize: 16,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ),
                      );
                    }

                    return StreamBuilder<List<WorkspaceMembersRecord>>(
                      stream: queryWorkspaceMembersRecord(
                        queryBuilder: (workspaceMembersRecord) =>
                            workspaceMembersRecord.where('workspace_ref',
                                isEqualTo:
                                    userSnapshot.data!.currentWorkspaceRef),
                      ),
                      builder: (context, membersSnapshot) {
                        if (!membersSnapshot.hasData) {
                          return Center(child: CircularProgressIndicator());
                        }

                        final allMembers = membersSnapshot.data!;
                        if (allMembers.isEmpty) {
                          return Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'No members found',
                                style: TextStyle(
                                  fontFamily: 'System',
                                  fontSize: 16,
                                  color: Color(0xFF8E8E93),
                                ),
                              ),
                            ),
                          );
                        }

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
                        final filteredMembers = _searchQuery.isEmpty
                            ? allMembers
                            : allMembers.where((member) {
                                // We'll filter in the individual member cards based on user data
                                return true;
                              }).toList();

                        return Column(
                          children: [
                            // Member count
                            Row(
                              children: [
                                Text(
                                  _searchQuery.isEmpty
                                      ? '${allMembers.length} members'
                                      : '${filteredMembers.length} of ${allMembers.length} members',
                                  style: TextStyle(
                                    fontFamily: 'System',
                                    fontSize: 14,
                                    color: Color(0xFF8E8E93),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            // Members list
                            ...filteredMembers
                                .map((member) => _buildMemberItem(member))
                                .toList(),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentWorkspaceCard(WorkspacesRecord workspace) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF007AFF), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    workspace.name.isNotEmpty
                        ? workspace.name[0].toUpperCase()
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          workspace.name,
                          style: TextStyle(
                            fontFamily: 'System',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Current',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      workspace.description,
                      style: TextStyle(
                        fontFamily: 'System',
                        fontSize: 14,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Delete (bin) icon
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isDeletingWorkspace = true;
                      });
                    },
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    tooltip: 'Delete Workspace',
                  ),
                  SizedBox(width: 4),
                  // Dropdown menu
                  StreamBuilder<List<WorkspaceMembersRecord>>(
                    stream: queryWorkspaceMembersRecord(
                      queryBuilder: (workspaceMembersRecord) =>
                          workspaceMembersRecord.where('user_ref',
                              isEqualTo: currentUserReference),
                    ),
                    builder: (context, workspaceMembersSnapshot) {
                      // Always show the dropdown icon, no loading state
                      final workspaceMembers =
                          workspaceMembersSnapshot.data ?? [];
                      final otherWorkspaces = workspaceMembers
                          .where((member) =>
                              member.workspaceRef?.id != workspace.reference.id)
                          .toList();

                      return PopupMenuButton<String>(
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFF8E8E93),
                          size: 20,
                        ),
                        onSelected: (String workspaceId) async {
                          if (workspaceId != workspace.reference.id) {
                            await _switchWorkspace(workspaceId);
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          List<PopupMenuEntry<String>> items = [
                            PopupMenuItem<String>(
                              value: workspace.reference.id,
                              child: _buildWorkspaceMenuItem(
                                workspace: workspace,
                                isCurrent: true,
                              ),
                            ),
                          ];

                          if (otherWorkspaces.isNotEmpty) {
                            items.add(PopupMenuDivider());
                            items.addAll(otherWorkspaces.map((member) {
                              return PopupMenuItem<String>(
                                value: member.workspaceRef!.id,
                                child: StreamBuilder<WorkspacesRecord>(
                                  stream: WorkspacesRecord.getDocument(
                                      member.workspaceRef!),
                                  builder: (context, workspaceSnapshot) {
                                    if (!workspaceSnapshot.hasData) {
                                      return SizedBox.shrink();
                                    }

                                    final otherWorkspace =
                                        workspaceSnapshot.data!;
                                    // Filter out deleted/inactive workspaces
                                    if (!otherWorkspace.isActive) {
                                      return SizedBox.shrink();
                                    }
                                    return _buildWorkspaceMenuItem(
                                      workspace: otherWorkspace,
                                      isCurrent: false,
                                    );
                                  },
                                ),
                              );
                            }).toList());
                          }

                          return items;
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _generateAndCopyInviteCode();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF007AFF),
                    side: BorderSide(color: Color(0xFF007AFF), width: 1),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.copy, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Copy Invite Code',
                        style: TextStyle(
                          fontFamily: 'System',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _showEmailInviteDialog();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF007AFF),
                    side: BorderSide(color: Color(0xFF007AFF), width: 1),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.email_outlined, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Email Invite',
                        style: TextStyle(
                          fontFamily: 'System',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoWorkspacesFound() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.business_outlined,
              size: 48,
              color: Color(0xFF8E8E93),
            ),
            SizedBox(height: 12),
            Text(
              'No workspaces found',
              style: TextStyle(
                fontFamily: 'System',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D1D1F),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Create your first workspace to get started',
              style: TextStyle(
                fontFamily: 'System',
                fontSize: 14,
                color: Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceListItem(WorkspacesRecord workspace,
      WorkspaceMembersRecord member, bool isCurrentWorkspace) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentWorkspace
            ? Color(0xFF007AFF).withOpacity(0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentWorkspace ? Color(0xFF007AFF) : Color(0xFFE5E7EB),
          width: isCurrentWorkspace ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFF007AFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                workspace.name.isNotEmpty
                    ? workspace.name[0].toUpperCase()
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      workspace.name,
                      style: TextStyle(
                        fontFamily: 'System',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                    if (isCurrentWorkspace) ...[
                      SizedBox(width: 8),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(0xFF007AFF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Current',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  'Your role: ${member.role}',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 14,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          if (!isCurrentWorkspace)
            GestureDetector(
              onTap: () async {
                await currentUserReference!.update({
                  'current_workspace_ref': workspace.reference,
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Switched to ${workspace.name}')),
                );
                setState(() {}); // Refresh the UI
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Switch',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberItem(WorkspaceMembersRecord member) {
    return StreamBuilder<UsersRecord>(
      stream: UsersRecord.getDocument(member.userRef!),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return SizedBox.shrink();
        }

        final user = userSnapshot.data!;
        final isCurrentUser = user.reference == currentUserReference;

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          final searchLower = _searchQuery.toLowerCase();
          final nameMatch =
              user.displayName.toLowerCase().contains(searchLower);
          final emailMatch = user.email.toLowerCase().contains(searchLower);
          final roleMatch = member.role.toLowerCase().contains(searchLower);
          if (!nameMatch && !emailMatch && !roleMatch) {
            return SizedBox.shrink();
          }
        }

        // Get role color
        Color roleColor;
        switch (member.role.toLowerCase()) {
          case 'owner':
            roleColor = Color(0xFF34C759); // Green
            break;
          case 'moderator':
            roleColor = Color(0xFFFF9500); // Orange
            break;
          case 'member':
            roleColor = Color(0xFF8E8E93); // Gray
            break;
          default:
            roleColor = Color(0xFF8E8E93);
        }

        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFF2F2F7),
                child: user.photoUrl.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: user.photoUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Text(
                        user.displayName.isNotEmpty
                            ? user.displayName[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user.displayName,
                          style: TextStyle(
                            fontFamily: 'System',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        if (isCurrentUser) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(0xFF007AFF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'You',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleColor,
                            borderRadius: BorderRadius.circular(4),
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
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            user.email,
                            style: TextStyle(
                              fontFamily: 'System',
                              fontSize: 12,
                              color: Color(0xFF8E8E93),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 3-dots menu for owners
              if (!isCurrentUser) _buildMemberMenu(member, user),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMemberMenu(WorkspaceMembersRecord member, UsersRecord user) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'upgrade_to_moderator':
            _upgradeMemberToModerator(member);
            break;
          case 'upgrade_to_owner':
            _upgradeMemberToOwner(member);
            break;
          case 'downgrade_to_member':
            _downgradeMemberToMember(member);
            break;
          case 'remove_member':
            _removeMember(member, user);
            break;
        }
      },
      itemBuilder: (BuildContext context) {
        List<PopupMenuEntry<String>> items = [];

        // Upgrade options
        if (member.role == 'member') {
          items.add(PopupMenuItem<String>(
            value: 'upgrade_to_moderator',
            child: Row(
              children: [
                Icon(Icons.star_outline, color: Color(0xFFFF9500), size: 18),
                SizedBox(width: 8),
                Text(
                  'Upgrade to Moderator',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 14,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
              ],
            ),
          ));
          items.add(PopupMenuItem<String>(
            value: 'upgrade_to_owner',
            child: Row(
              children: [
                Icon(Icons.star, color: Color(0xFF34C759), size: 18),
                SizedBox(width: 8),
                Text(
                  'Upgrade to Owner',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 14,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
              ],
            ),
          ));
        } else if (member.role == 'moderator') {
          items.add(PopupMenuItem<String>(
            value: 'upgrade_to_owner',
            child: Row(
              children: [
                Icon(Icons.star, color: Color(0xFF34C759), size: 18),
                SizedBox(width: 8),
                Text(
                  'Upgrade to Owner',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 14,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
              ],
            ),
          ));
          items.add(PopupMenuItem<String>(
            value: 'downgrade_to_member',
            child: Row(
              children: [
                Icon(Icons.star_border, color: Color(0xFF8E8E93), size: 18),
                SizedBox(width: 8),
                Text(
                  'Downgrade to Member',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 14,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
              ],
            ),
          ));
        } else if (member.role == 'owner') {
          items.add(PopupMenuItem<String>(
            value: 'downgrade_to_member',
            child: Row(
              children: [
                Icon(Icons.star_border, color: Color(0xFF8E8E93), size: 18),
                SizedBox(width: 8),
                Text(
                  'Downgrade to Member',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 14,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
              ],
            ),
          ));
        }

        // Remove member option
        items.add(PopupMenuDivider());
        items.add(PopupMenuItem<String>(
          value: 'remove_member',
          child: Row(
            children: [
              Icon(Icons.person_remove, color: Color(0xFFFF3B30), size: 18),
              SizedBox(width: 8),
              Text(
                'Remove Member',
                style: TextStyle(
                  fontFamily: 'System',
                  fontSize: 14,
                  color: Color(0xFFFF3B30),
                ),
              ),
            ],
          ),
        ));

        return items;
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.more_horiz,
          color: Color(0xFF8E8E93),
          size: 18,
        ),
      ),
    );
  }

  Widget _buildCreateWorkspaceContent() {
    return Column(
      children: [
        // Header with proper safe area
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
                    _isCreatingWorkspace = false;
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
                  'Create Workspace',
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
        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Form Fields
                _buildFormField(
                  label: 'Workspace Name',
                  controller: _workspaceNameController,
                  icon: Icons.business_outlined,
                ),
                SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description',
                      style: TextStyle(
                        fontFamily: 'System',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFFE5E7EB)),
                      ),
                      child: TextField(
                        controller: _workspaceDescriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.description_outlined,
                              color: Color(0xFF8E8E93), size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        style: TextStyle(
                          fontFamily: 'System',
                          fontSize: 16,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32),
                // Create Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _createWorkspace,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Create Workspace',
                      style: TextStyle(
                        fontFamily: 'System',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteWorkspaceContent() {
    return Column(
      children: [
        // Header with proper safe area
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
                    _isDeletingWorkspace = false;
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
                  'Delete Workspace',
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
        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Warning
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF3F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFFF3B30)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_outlined,
                        color: Color(0xFFFF3B30),
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This action cannot be undone. All data will be permanently deleted.',
                          style: TextStyle(
                            fontFamily: 'System',
                            fontSize: 14,
                            color: Color(0xFFFF3B30),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                _buildFormField(
                  label: 'Type "DELETE" to confirm',
                  controller: _deleteConfirmationController,
                  icon: Icons.edit_outlined,
                ),
                SizedBox(height: 32),
                // Delete Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _deleteWorkspace,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFF3B30),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Delete Workspace',
                      style: TextStyle(
                        fontFamily: 'System',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJoinWorkspaceContent() {
    return Column(
      children: [
        // Header with proper safe area
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
                    _isJoiningWorkspace = false;
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
                  'Join Workspace',
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
        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFormField(
                  label: 'Invite Code',
                  controller: _inviteCodeController,
                  icon: Icons.vpn_key_outlined,
                ),
                SizedBox(height: 32),
                // Join Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _joinWorkspace,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Join Workspace',
                      style: TextStyle(
                        fontFamily: 'System',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsContent() {
    return SingleChildScrollView(
      child: Column(
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
                    'Notifications',
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
          // Content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNotificationOption(
                  'Push Notifications',
                  'Receive notifications on your device',
                  true,
                ),
                SizedBox(height: 16),
                _buildNotificationOption(
                  'Email Notifications',
                  'Receive notifications via email',
                  true,
                ),
                SizedBox(height: 16),
                _buildNotificationOption(
                  'Chat Messages',
                  'Get notified about new messages',
                  true,
                ),
                SizedBox(height: 16),
                _buildNotificationOption(
                  'Workspace Updates',
                  'Get notified about workspace changes',
                  false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationOption(String title, String subtitle, bool value) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 14,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (newValue) {
              // TODO: Implement notification toggle
            },
            activeColor: Color(0xFF007AFF),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySecurityContent() {
    return SingleChildScrollView(
      child: Column(
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
                    'Privacy & Security',
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
          // Content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSecurityOption(
                  'Change Password',
                  'Update your account password',
                  Icons.lock_outline,
                ),
                SizedBox(height: 16),
                _buildSecurityOption(
                  'Two-Factor Authentication',
                  'Add an extra layer of security',
                  Icons.security_outlined,
                ),
                SizedBox(height: 16),
                _buildSecurityOption(
                  'Privacy Settings',
                  'Control who can see your information',
                  Icons.privacy_tip_outlined,
                ),
                SizedBox(height: 16),
                _buildSecurityOption(
                  'Data & Storage',
                  'Manage your data and storage',
                  Icons.storage_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityOption(String title, String subtitle, IconData icon) {
    return GestureDetector(
      onTap: () {
        // TODO: Implement security option
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: Color(0xFF8E8E93),
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'System',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'System',
                      fontSize: 14,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
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
    );
  }

  Widget _buildContactSupportContent() {
    return SingleChildScrollView(
      child: Column(
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
                    'Contact Support',
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
          // Content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSupportOption(
                  'Email Support',
                  'support@linkedup.com',
                  Icons.email_outlined,
                ),
                SizedBox(height: 16),
                _buildSupportOption(
                  'Live Chat',
                  'Chat with our support team',
                  Icons.chat_outlined,
                ),
                SizedBox(height: 16),
                _buildSupportOption(
                  'Report a Bug',
                  'Help us improve the app',
                  Icons.bug_report_outlined,
                ),
                SizedBox(height: 16),
                _buildSupportOption(
                  'Feature Request',
                  'Suggest new features',
                  Icons.lightbulb_outline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportOption(String title, String subtitle, IconData icon) {
    return GestureDetector(
      onTap: () {
        // TODO: Implement support option
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'System',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'System',
                      fontSize: 14,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
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
    );
  }

  Widget _buildFAQsContent() {
    return SingleChildScrollView(
      child: Column(
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
                    'FAQs',
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
          // Content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFAQItem(
                  'How do I create a workspace?',
                  'Tap on "Create Workspace" in the workspace management section and fill in the required details.',
                ),
                SizedBox(height: 16),
                _buildFAQItem(
                  'How do I invite members to my workspace?',
                  'Go to workspace management and tap "Invite Members" to generate and copy an invite code.',
                ),
                SizedBox(height: 16),
                _buildFAQItem(
                  'How do I switch between workspaces?',
                  'Use the workspace switcher in the chat interface to switch between your workspaces.',
                ),
                SizedBox(height: 16),
                _buildFAQItem(
                  'How do I delete a workspace?',
                  'Only workspace owners can delete workspaces. Go to workspace management and tap "Delete Workspace".',
                ),
              ],
            ),
          ),
        ],
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

  // Action Methods

  Future<void> _createWorkspace() async {
    if (_workspaceNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a workspace name')),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      final workspaceData = {
        'name': _workspaceNameController.text.trim(),
        'description': _workspaceDescriptionController.text.trim(),
        'created_time': getCurrentTimestamp,
        'owner_ref': currentUserReference,
        'logo_url': '',
        'member_count': 1,
      };

      final workspaceRef = await FirebaseFirestore.instance
          .collection('workspaces')
          .add(workspaceData);

      final memberData = {
        'user_ref': currentUserReference,
        'workspace_ref': workspaceRef,
        'role': 'owner',
        'joined_time': getCurrentTimestamp,
      };

      await FirebaseFirestore.instance
          .collection('workspace_members')
          .add(memberData);

      await currentUserReference!.update({
        'current_workspace_ref': workspaceRef,
      });

      _workspaceNameController.clear();
      _workspaceDescriptionController.clear();

      Navigator.pop(context);
      setState(() {
        _isCreatingWorkspace = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Workspace created successfully')),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating workspace: $e')),
      );
    }
  }

  Future<void> _deleteWorkspace() async {
    if (_deleteConfirmationController.text != 'DELETE') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please type "DELETE" to confirm')),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      final userDoc = await UsersRecord.getDocumentOnce(currentUserReference!);
      if (userDoc.currentWorkspaceRef == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No workspace selected')),
        );
        return;
      }

      final workspaceRef = userDoc.currentWorkspaceRef!;

      // Delete all workspace members
      final membersQuery = await FirebaseFirestore.instance
          .collection('workspace_members')
          .where('workspace_ref', isEqualTo: workspaceRef)
          .get();

      for (var memberDoc in membersQuery.docs) {
        await memberDoc.reference.delete();
      }

      // Delete all chats in this workspace
      final chatsQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('workspace_ref', isEqualTo: workspaceRef)
          .get();

      for (var chatDoc in chatsQuery.docs) {
        await chatDoc.reference.delete();
      }

      // Clear current workspace reference from users
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('current_workspace_ref', isEqualTo: workspaceRef)
          .get();

      for (var userDoc in usersQuery.docs) {
        await userDoc.reference.update({
          'current_workspace_ref': null,
        });
      }

      // Delete the workspace itself
      await workspaceRef.delete();

      _deleteConfirmationController.clear();

      Navigator.pop(context);
      setState(() {
        _isDeletingWorkspace = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Workspace deleted successfully')),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting workspace: $e')),
      );
    }
  }

  Future<void> _joinWorkspace() async {
    if (_inviteCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter an invite code')),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Find workspace by invite code
      final workspaceQuery = await FirebaseFirestore.instance
          .collection('workspaces')
          .where('invite_code', isEqualTo: _inviteCodeController.text.trim())
          .limit(1)
          .get();

      if (workspaceQuery.docs.isEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid invite code')),
        );
        return;
      }

      final workspaceDoc = workspaceQuery.docs.first;
      final workspaceRef = workspaceDoc.reference;

      // Check if user is already a member
      final memberQuery = await FirebaseFirestore.instance
          .collection('workspace_members')
          .where('user_ref', isEqualTo: currentUserReference)
          .where('workspace_ref', isEqualTo: workspaceRef)
          .limit(1)
          .get();

      if (memberQuery.docs.isNotEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You are already a member of this workspace')),
        );
        return;
      }

      // Add user as member
      final memberData = {
        'user_ref': currentUserReference,
        'workspace_ref': workspaceRef,
        'role': 'member',
        'joined_time': getCurrentTimestamp,
      };

      await FirebaseFirestore.instance
          .collection('workspace_members')
          .add(memberData);

      // Update user's current workspace
      await currentUserReference!.update({
        'current_workspace_ref': workspaceRef,
      });

      // Update workspace member count
      await workspaceRef.update({
        'member_count': FieldValue.increment(1),
      });

      _inviteCodeController.clear();

      Navigator.pop(context);
      setState(() {
        _isJoiningWorkspace = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully joined workspace')),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining workspace: $e')),
      );
    }
  }

  Future<void> _generateAndCopyInviteCode() async {
    try {
      final userDoc = await UsersRecord.getDocumentOnce(currentUserReference!);
      if (userDoc.currentWorkspaceRef == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No workspace selected')),
        );
        return;
      }

      final workspaceRef = userDoc.currentWorkspaceRef!;
      final workspaceDoc = await workspaceRef.get();
      final workspaceData = workspaceDoc.data() as Map<String, dynamic>;

      String inviteCode = workspaceData['invite_code'] ?? '';

      if (inviteCode.isEmpty) {
        // Generate new invite code
        inviteCode = _generateInviteCode();
        await workspaceRef.update({
          'invite_code': inviteCode,
        });
      }

      await Clipboard.setData(ClipboardData(text: inviteCode));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite code copied to clipboard: $inviteCode')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating invite code: $e')),
      );
    }
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
          8, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  // Member Management Actions
  Future<void> _upgradeMemberToModerator(WorkspaceMembersRecord member) async {
    try {
      await member.reference.update({
        'role': 'moderator',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Member upgraded to Moderator')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error upgrading member: $e')),
      );
    }
  }

  Future<void> _upgradeMemberToOwner(WorkspaceMembersRecord member) async {
    try {
      await member.reference.update({
        'role': 'owner',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Member upgraded to Owner')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error upgrading member: $e')),
      );
    }
  }

  Future<void> _downgradeMemberToMember(WorkspaceMembersRecord member) async {
    try {
      await member.reference.update({
        'role': 'member',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Member downgraded to Member')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downgrading member: $e')),
      );
    }
  }

  Future<void> _removeMember(
      WorkspaceMembersRecord member, UsersRecord user) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Remove Member',
            style: TextStyle(
              fontFamily: 'System',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1D1F),
            ),
          ),
          content: Text(
            'Are you sure you want to remove ${user.displayName} from this workspace?',
            style: TextStyle(
              fontFamily: 'System',
              fontSize: 16,
              color: Color(0xFF1D1D1F),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
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
              onPressed: () => Navigator.of(context).pop(true),
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
      try {
        // Remove the member from workspace
        await member.reference.delete();

        // If this was their current workspace, clear it
        if (user.currentWorkspaceRef == member.workspaceRef) {
          await user.reference.update({
            'current_workspace_ref': null,
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Member removed from workspace')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing member: $e')),
        );
      }
    }
  }

  Widget _buildWorkspaceMenuItem({
    required WorkspacesRecord workspace,
    required bool isCurrent,
  }) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCurrent ? Color(0xFF007AFF) : Color(0xFF8E8E93),
            borderRadius: BorderRadius.circular(4),
          ),
          child: workspace.logoUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: workspace.logoUrl,
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: Text(
                        workspace.name.isNotEmpty
                            ? workspace.name[0].toUpperCase()
                            : 'W',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Text(
                        workspace.name.isNotEmpty
                            ? workspace.name[0].toUpperCase()
                            : 'W',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    workspace.name.isNotEmpty
                        ? workspace.name[0].toUpperCase()
                        : 'W',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                workspace.name,
                style: TextStyle(
                  fontFamily: 'System',
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                  color: Color(0xFF1D1D1F),
                ),
              ),
              if (isCurrent)
                Text(
                  'Current',
                  style: TextStyle(
                    fontFamily: 'System',
                    fontSize: 12,
                    color: Color(0xFF007AFF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _switchWorkspace(String workspaceId) async {
    try {
      // Update the current user's workspace reference
      await currentUserReference!.update({
        'current_workspace_ref':
            FirebaseFirestore.instance.doc('workspaces/$workspaceId'),
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Workspace switched successfully'),
          backgroundColor: Color(0xFF34C759),
        ),
      );

      // Refresh the UI
      setState(() {});
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to switch workspace: $e'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
    }
  }

  void _showEmailInviteDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Email Invite',
            style: TextStyle(
              fontFamily: 'System',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1D1F),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the email address of the person you want to invite to this workspace:',
                style: TextStyle(
                  fontFamily: 'System',
                  fontSize: 14,
                  color: Color(0xFF8E8E93),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'user@example.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'System',
                  fontSize: 16,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (emailController.text.isNotEmpty &&
                    emailController.text.contains('@')) {
                  Navigator.pop(context);
                  await _sendEmailInvite(emailController.text);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid email address'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF007AFF),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Send Invite',
                style: TextStyle(
                  fontFamily: 'System',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendEmailInvite(String email) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      // TODO: Implement actual email invitation logic
      await Future.delayed(Duration(seconds: 2)); // Simulate API call

      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invitation sent to $email'),
          backgroundColor: Color(0xFF34C759),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending invitation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
