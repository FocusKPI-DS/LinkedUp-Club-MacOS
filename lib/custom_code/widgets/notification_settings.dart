// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your widget name, define your parameter, and then add the
// boilerplate code using the green button on the right!

import 'package:cloud_firestore/cloud_firestore.dart';
import '/auth/firebase_auth/auth_util.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:badges/badges.dart' as badges;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'paginated_notifications.dart';
import 'in_app_notification_service.dart';

class NotificationSettings extends StatefulWidget {
  const NotificationSettings({
    super.key,
    this.width,
    this.height,
    this.navigationAction,
  });

  final double? width;
  final double? height;
  final Future Function(String? pageParam, String? pageName)? navigationAction;

  @override
  _NotificationSettingsState createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings> {
  bool _eventUpdateValue = false;
  bool _newMessageValue = false;
  bool _connectionRequestsValue = false;
  bool _isLoading = true;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _loadUserSettings() {
    // Listen to user document changes
    _userSubscription = currentUserReference!.snapshots().listen((snapshot) {
      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _eventUpdateValue = data['notifications_enabled'] ?? false;
          _newMessageValue = data['new_message_enabled'] ?? false;
          _connectionRequestsValue =
              data['connection_requests_enabled'] ?? false;
          _isLoading = false;
        });
      }
    });
  }

  void _subscribeToNotifications() {
    if (currentUserReference != null) {
      String userPath = currentUserReference!.path;

      // Count unread notifications from ff_user_push_notifications
      _notificationSubscription = FirebaseFirestore.instance
          .collection('ff_user_push_notifications')
          .where('user_refs', arrayContains: userPath)
          .where('status', isEqualTo: 'succeeded')
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _unreadCount = snapshot.docs.length;
          });
        }
      });
    }
  }

  Future<void> _updateSetting(String field, bool value) async {
    try {
      await currentUserReference!.update({
        field: value,
      });
    } catch (e) {
      print('Error updating notification setting: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error updating settings. Please try again.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    }
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56.0,
                    height: 56.0,
                    decoration: const BoxDecoration(
                      color: Color(0x1A4169E1),
                      shape: BoxShape.circle,
                    ),
                    child: Align(
                      alignment: const AlignmentDirectional(0.0, 0.0),
                      child: Icon(
                        icon,
                        color: FlutterFlowTheme.of(context).primary,
                        size: 25.0,
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                        ),
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.5,
                          ),
                          child: Text(
                            subtitle,
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                          ),
                        ),
                      ].divide(const SizedBox(height: 4.0)),
                    ),
                  ),
                ].divide(const SizedBox(width: 12.0)),
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: FlutterFlowTheme.of(context).primary,
              activeTrackColor: FlutterFlowTheme.of(context).primary,
              inactiveTrackColor: FlutterFlowTheme.of(context).accent2,
              inactiveThumbColor: FlutterFlowTheme.of(context).alternate,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        child: Center(
          child: CircularProgressIndicator(
            color: FlutterFlowTheme.of(context).primary,
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding:
                  const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notification Settings',
                    textAlign: TextAlign.center,
                    style: FlutterFlowTheme.of(context).headlineMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontStyle: FlutterFlowTheme.of(context)
                                .headlineMedium
                                .fontStyle,
                          ),
                          color: const Color(0xFF111827),
                          fontSize: 18.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.bold,
                          fontStyle: FlutterFlowTheme.of(context)
                              .headlineMedium
                              .fontStyle,
                        ),
                  ),
                  Text(
                    'Enable notifications to never miss out on exclusive events and updates from your network.',
                    textAlign: TextAlign.start,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FontWeight.normal,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                          ),
                          color: const Color(0xFF6B7280),
                          fontSize: 14.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.normal,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                  ),
                ].divide(const SizedBox(height: 9.0)),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                _buildNotificationTile(
                  icon: Icons.color_lens,
                  title: 'Event Updates',
                  subtitle: 'Changes to events you\'re attending',
                  value: _eventUpdateValue,
                  onChanged: (newValue) async {
                    setState(() => _eventUpdateValue = newValue);
                    await _updateSetting('notifications_enabled', newValue);
                  },
                ),
                _buildNotificationTile(
                  icon: Icons.message_rounded,
                  title: 'New Message',
                  subtitle: 'Notifications about new messages in chat groups',
                  value: _newMessageValue,
                  onChanged: (newValue) async {
                    setState(() => _newMessageValue = newValue);
                    await _updateSetting('new_message_enabled', newValue);
                  },
                ),
                _buildNotificationTile(
                  icon: Icons.person_add_alt_rounded,
                  title: 'Connection Requests',
                  subtitle: 'When someone wants to connect',
                  value: _connectionRequestsValue,
                  onChanged: (newValue) async {
                    setState(() => _connectionRequestsValue = newValue);
                    await _updateSetting(
                        'connection_requests_enabled', newValue);
                  },
                ),
              ].divide(const SizedBox(height: 16.0)),
            ),
            Padding(
              padding:
                  const EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'All Notifications',
                        textAlign: TextAlign.center,
                        style: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .override(
                              font: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .headlineMedium
                                    .fontStyle,
                              ),
                              color: const Color(0xFF111827),
                              fontSize: 18.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.bold,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .headlineMedium
                                  .fontStyle,
                            ),
                      ),
                      InkWell(
                        onTap: () async {
                          // Just refresh the widget or navigate to the current page
                          // Removing the navigation as it causes conflicts
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: _unreadCount > 0
                                ? FlutterFlowTheme.of(context)
                                    .primary
                                    .withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: badges.Badge(
                            showBadge: _unreadCount > 0,
                            badgeContent: Text(
                              _unreadCount > 99
                                  ? '99+'
                                  : _unreadCount.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _unreadCount > 99 ? 10 : 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            badgeColor: FlutterFlowTheme.of(context).error,
                            padding: EdgeInsets.all(_unreadCount > 99 ? 4 : 5),
                            borderRadius: BorderRadius.circular(12),
                            elevation: 2,
                            position:
                                badges.BadgePosition.topEnd(top: -8, end: -8),
                            child: Icon(
                              _unreadCount > 0
                                  ? Icons.notifications_active
                                  : Icons.notifications_outlined,
                              color: _unreadCount > 0
                                  ? FlutterFlowTheme.of(context).primary
                                  : FlutterFlowTheme.of(context).primaryText,
                              size: 28.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: Text(
                          'View all of your notifications below:',
                          textAlign: TextAlign.start,
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.normal,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: const Color(0xFF6B7280),
                                    fontSize: 14.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  // Test In-App Notification Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: InkWell(
                      onTap: () async {
                        await _testInAppNotification();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Icon(
                              Icons.notifications_active,
                              color: Colors.white,
                              size: 24.0,
                            ),
                            SizedBox(width: 12.0),
                            Expanded(
                              child: Text(
                                'Test In-App Notification (TOP)',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      color: Colors.white,
                                      fontSize: 16.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 16.0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // PaginatedNotifications with dynamic height
                  PaginatedNotifications(
                    width: double.infinity,
                    height: 400.0, // Fixed height to prevent scrolling issues
                    userRef: currentUserReference!,
                    navigationAction: widget.navigationAction,
                  ),
                ].divide(const SizedBox(height: 9.0)),
              ),
            ),
          ].addToEnd(const SizedBox(height: 24.0)),
        ),
      ),
    );
  }

  /// Test in-app notification function
  Future<void> _testInAppNotification() async {
    try {
      print('🔔 Testing in-app notification...');

      // Show in-app notification overlay from top
      InAppNotificationService.showInAppNotification(
        context: context,
        title: '🎉 Test Notification',
        body: 'In-app notifications are working perfectly!',
        soundFile: 'new-notification-3-398649.mp3',
        duration: Duration(seconds: 3),
      );
    } catch (e) {
      print('❌ Error testing in-app notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
