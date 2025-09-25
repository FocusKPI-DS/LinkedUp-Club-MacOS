// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your widget name, define your parameter, and then add the
// boilerplate code using the green button on the right!

import 'package:cloud_firestore/cloud_firestore.dart';
import '/auth/firebase_auth/auth_util.dart';
import 'package:badges/badges.dart' as badges;

class NotificationBadge extends StatefulWidget {
  const NotificationBadge({
    Key? key,
    this.width,
    this.height,
    this.onTap,
    this.iconColor,
    this.iconSize,
    this.badgeColor,
    this.badgeTextColor,
  }) : super(key: key);

  final double? width;
  final double? height;
  final Future Function()? onTap;
  final Color? iconColor;
  final double? iconSize;
  final Color? badgeColor;
  final Color? badgeTextColor;

  @override
  _NotificationBadgeState createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: widget.width ?? 48.0,
        height: widget.height ?? 48.0,
        padding: EdgeInsets.all(8.0),
        child: badges.Badge(
          showBadge: _unreadCount > 0,
          badgeContent: Text(
            _unreadCount > 99 ? '99+' : _unreadCount.toString(),
            style: TextStyle(
              color: widget.badgeTextColor ?? Colors.white,
              fontSize: _unreadCount > 99 ? 10 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          badgeColor: widget.badgeColor ?? FlutterFlowTheme.of(context).error,
          padding: EdgeInsets.all(_unreadCount > 99 ? 4 : 5),
          borderRadius: BorderRadius.circular(12),
          elevation: 2,
          position: badges.BadgePosition.topEnd(top: -5, end: -5),
          child: Icon(
            Icons.notifications_outlined,
            color: widget.iconColor ?? FlutterFlowTheme.of(context).primaryText,
            size: widget.iconSize ?? 24.0,
          ),
        ),
      ),
    );
  }
}
