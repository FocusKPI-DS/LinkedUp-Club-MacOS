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

// Set your widget name, define your parameter, and then add the
// boilerplate code using the green button on the right!

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
// import '/auth/firebase_auth/auth_util.dart';

/// A comprehensive attendee display widget that merges data from: -
/// events/{eventId}/participant subcollection (LinkedUp users) -
/// event_attendees collection (EventBrite attendees)
///
/// Features: - Deduplicates attendees by email - Shows badges for
/// EventBrite/LinkedUp users - Displays pending users (EventBrite users
/// without LinkedUp accounts) - Allows inviting pending users to LinkedUp
///
/// Parameters: - eventRef: Reference to the event document -
/// eventbriteEventId: The EventBrite event ID (if applicable) -
/// showPendingUsers: Whether to show non-LinkedUp EventBrite attendees -
/// showEventbriteBadge: Whether to show an EventBrite indicator -
/// onInvitePending: Async callback when inviting a pending user (returns
/// Future) - emptyMessage: Custom message to show when no attendees (default:
/// 'No attendees yet')
class AttendeeDisplay extends StatefulWidget {
  const AttendeeDisplay({
    super.key,
    this.width,
    this.height,
    required this.eventRef,
    this.eventbriteEventId,
    this.showPendingUsers = true,
    this.showEventbriteBadge = true,
    this.onInvitePending,
    this.onConnectUser,
    this.onCancelRequest,
    this.currentUserRef,
    this.currentUserFriends,
    this.currentUserSentRequests,
    this.emptyMessage = 'No attendees yet',
  });

  final double? width;
  final double? height;
  final DocumentReference eventRef;
  final String? eventbriteEventId;
  final bool showPendingUsers;
  final bool showEventbriteBadge;
  final Future Function(String email, String name)? onInvitePending;
  final Future Function(DocumentReference userRef)? onConnectUser;
  final Future Function(DocumentReference userRef)? onCancelRequest;
  final DocumentReference? currentUserRef;
  final List<DocumentReference>? currentUserFriends;
  final List<DocumentReference>? currentUserSentRequests;
  final String emptyMessage;

  @override
  State<AttendeeDisplay> createState() => _AttendeeDisplayState();
}

class _AttendeeItem {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final String? bio;
  final DocumentReference? userRef;
  final bool isLinkedUpUser;
  final bool isEventbriteUser;
  final bool isPendingVerification;
  final String? ticketClass;
  final bool checkedIn;

  _AttendeeItem({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.bio,
    this.userRef,
    required this.isLinkedUpUser,
    required this.isEventbriteUser,
    required this.isPendingVerification,
    this.ticketClass,
    required this.checkedIn,
  });
}

class _AttendeeDisplayState extends State<AttendeeDisplay> {
  List<_AttendeeItem> _attendees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttendees();
  }

  Future<void> _loadAttendees() async {
    try {
      final Map<String, _AttendeeItem> attendeeMap = {};

      // 1. Load LinkedUp participants from subcollection
      final participantsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventRef.id)
          .collection('participant')
          .get();

      for (var doc in participantsSnapshot.docs) {
        final data = doc.data();
        final userRef = data['user_ref'] as DocumentReference?;

        // Get user details
        UsersRecord? userRecord;
        if (userRef != null) {
          try {
            final userDoc = await userRef.get();
            if (userDoc.exists) {
              userRecord = UsersRecord.getDocumentFromData(
                userDoc.data() as Map<String, dynamic>,
                userRef,
              );
            }
          } catch (e) {
            print('Error fetching user record: $e');
          }
        }

        final email = userRecord?.email ?? '';
        if (email.isNotEmpty) {
          attendeeMap[email] = _AttendeeItem(
            id: doc.id,
            name: data['name'] ?? userRecord?.displayName ?? 'Unknown',
            email: email,
            photoUrl: data['image'] ?? userRecord?.photoUrl,
            bio: data['bio'] ?? userRecord?.bio,
            userRef: userRef,
            isLinkedUpUser: true,
            isEventbriteUser: false,
            isPendingVerification: false,
            checkedIn: false,
          );
        }
      }

      // 2. Load EventBrite attendees if applicable
      if (widget.eventbriteEventId != null &&
          widget.eventbriteEventId!.isNotEmpty) {
        final eventbriteSnapshot = await FirebaseFirestore.instance
            .collection('event_attendees')
            .where('event_id', isEqualTo: widget.eventbriteEventId)
            .get();

        for (var doc in eventbriteSnapshot.docs) {
          final data = doc.data();
          final email = data['email'] ?? '';

          if (email.isEmpty) continue;

          // Check if this attendee already exists (LinkedUp user)
          if (!attendeeMap.containsKey(email)) {
            // Only add if showing pending users or if they have a LinkedUp account
            if (widget.showPendingUsers || data['user_ref'] != null) {
              attendeeMap[email] = _AttendeeItem(
                id: doc.id,
                name: data['name'] ?? 'EventBrite Attendee',
                email: email,
                photoUrl: null,
                bio: null,
                userRef: data['user_ref'] as DocumentReference?,
                isLinkedUpUser: data['user_ref'] != null,
                isEventbriteUser: true,
                isPendingVerification: data['is_pending_verification'] ?? true,
                ticketClass: data['ticket_class'],
                checkedIn: data['checked_in'] ?? false,
              );
            }
          } else {
            // Update existing entry to show they're also an EventBrite attendee
            final existing = attendeeMap[email]!;
            attendeeMap[email] = _AttendeeItem(
              id: existing.id,
              name: existing.name,
              email: existing.email,
              photoUrl: existing.photoUrl,
              bio: existing.bio,
              userRef: existing.userRef,
              isLinkedUpUser: existing.isLinkedUpUser,
              isEventbriteUser: true, // Mark as EventBrite user too
              isPendingVerification: false,
              ticketClass: data['ticket_class'],
              checkedIn: data['checked_in'] ?? false,
            );
          }
        }
      }

      // Convert map to list and sort
      _attendees = attendeeMap.values.toList()
        ..sort((a, b) {
          // Sort order: LinkedUp users first, then by name
          if (a.isLinkedUpUser && !b.isLinkedUpUser) return -1;
          if (!a.isLinkedUpUser && b.isLinkedUpUser) return 1;
          return a.name.compareTo(b.name);
        });

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading attendees: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildAttendeeItem(_AttendeeItem attendee) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        border: Border(
          bottom: BorderSide(
            color: FlutterFlowTheme.of(context).alternate,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48.0,
            height: 48.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: FlutterFlowTheme.of(context).alternate,
            ),
            child: ClipOval(
              child: attendee.photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: attendee.photoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Icon(
                        Icons.person,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                      errorWidget: (context, url, error) => Icon(
                        Icons.person,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                    )
                  : Icon(
                      Icons.person,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
            ),
          ),
          SizedBox(width: 12.0),
          // Name and details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        attendee.name,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                              ),
                              letterSpacing: 0.0,
                            ),
                      ),
                    ),
                    // Badges
                    if (widget.showEventbriteBadge && attendee.isEventbriteUser)
                      Container(
                        margin: EdgeInsets.only(left: 8.0),
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFFFF6F00),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Text(
                          'EventBrite',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (attendee.checkedIn)
                      Container(
                        margin: EdgeInsets.only(left: 8.0),
                        child: Icon(
                          Icons.check_circle,
                          color: FlutterFlowTheme.of(context).success,
                          size: 16.0,
                        ),
                      ),
                  ],
                ),
                if (attendee.bio != null && attendee.bio!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Text(
                      attendee.bio!,
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            font: GoogleFonts.inter(),
                            color: FlutterFlowTheme.of(context).secondaryText,
                            letterSpacing: 0.0,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (attendee.ticketClass != null)
                  Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Text(
                      attendee.ticketClass!,
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            font: GoogleFonts.inter(),
                            color: FlutterFlowTheme.of(context).primary,
                            letterSpacing: 0.0,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          // Action buttons
          if (attendee.isPendingVerification && widget.onInvitePending != null)
            TextButton(
              onPressed: () async {
                await widget.onInvitePending!(
                  attendee.email,
                  attendee.name,
                );
              },
              child: Text(
                'Invite',
                style: TextStyle(
                  color: FlutterFlowTheme.of(context).primary,
                  fontSize: 14.0,
                ),
              ),
            )
          else if (attendee.isLinkedUpUser &&
              attendee.userRef != null &&
              widget.currentUserRef != null &&
              attendee.userRef != widget.currentUserRef)
            // Check if already friends
            widget.currentUserFriends?.contains(attendee.userRef) == true
                ? Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color:
                          FlutterFlowTheme.of(context).success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check,
                          size: 14.0,
                          color: FlutterFlowTheme.of(context).success,
                        ),
                        SizedBox(width: 4.0),
                        Text(
                          'Connected',
                          style: TextStyle(
                            color: FlutterFlowTheme.of(context).success,
                            fontSize: 12.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                // Check if request is pending
                : widget.currentUserSentRequests?.contains(attendee.userRef) ==
                        true
                    ? Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context)
                              .warning
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: InkWell(
                          onTap: widget.onCancelRequest != null
                              ? () async {
                                  await widget
                                      .onCancelRequest!(attendee.userRef!);
                                }
                              : null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_sharp,
                                size: 14.0,
                                color: FlutterFlowTheme.of(context).warning,
                              ),
                              SizedBox(width: 4.0),
                              Text(
                                'Pending',
                                style: TextStyle(
                                  color: FlutterFlowTheme.of(context).warning,
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : widget.onConnectUser != null
                        ? TextButton(
                            onPressed: () async {
                              await widget.onConnectUser!(attendee.userRef!);
                            },
                            child: Text(
                              'Connect',
                              style: TextStyle(
                                color: FlutterFlowTheme.of(context).primary,
                                fontSize: 14.0,
                              ),
                            ),
                          )
                        : SizedBox.shrink(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: widget.width ?? double.infinity,
        height: widget.height ?? 200.0,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              FlutterFlowTheme.of(context).primary,
            ),
          ),
        ),
      );
    }

    if (_attendees.isEmpty) {
      return Container(
        width: widget.width ?? double.infinity,
        height: widget.height ?? 200.0,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 48.0,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
              SizedBox(height: 16.0),
              Text(
                widget.emptyMessage,
                style: FlutterFlowTheme.of(context).titleMedium.override(
                      font: GoogleFonts.inter(),
                      color: FlutterFlowTheme.of(context).secondaryText,
                      letterSpacing: 0.0,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Group attendees by type
    final linkedUpAttendees =
        _attendees.where((a) => a.isLinkedUpUser).toList();
    final pendingAttendees =
        _attendees.where((a) => a.isPendingVerification).toList();

    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // LinkedUp Users Section
          if (linkedUpAttendees.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(16.0),
              color: FlutterFlowTheme.of(context).primaryBackground,
              child: Text(
                'LinkedUp Members (${linkedUpAttendees.length})',
                style: FlutterFlowTheme.of(context).titleSmall.override(
                      font: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                      ),
                      letterSpacing: 0.0,
                    ),
              ),
            ),
            ...linkedUpAttendees.map(_buildAttendeeItem),
          ],
          // Pending Users Section
          if (pendingAttendees.isNotEmpty && widget.showPendingUsers) ...[
            Container(
              padding: EdgeInsets.all(16.0),
              color: FlutterFlowTheme.of(context).primaryBackground,
              child: Text(
                'EventBrite Attendees (${pendingAttendees.length})',
                style: FlutterFlowTheme.of(context).titleSmall.override(
                      font: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                      ),
                      letterSpacing: 0.0,
                    ),
              ),
            ),
            ...pendingAttendees.map(_buildAttendeeItem),
          ],
        ],
      ),
    );
  }
}
