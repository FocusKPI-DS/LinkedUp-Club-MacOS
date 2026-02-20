// Automatic FlutterFlow imports
import '/backend/backend.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your widget name, define your parameter, and then add the
// boilerplate code using the green button on the right!

import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'attendee_display.dart';

class EnhancedAllAttendees extends StatefulWidget {
  const EnhancedAllAttendees({
    super.key,
    this.width,
    this.height,
    required this.event,
    required this.eventRef,
    this.eventbriteId,
    this.useEventbriteTicketing,
    this.showEventbriteControls = false,
    this.onSyncAttendees,
    this.onUpdateTicketingMode,
  });

  final double? width;
  final double? height;
  final EventsRecord event;
  final DocumentReference eventRef;
  final String? eventbriteId;
  final bool? useEventbriteTicketing;
  final bool showEventbriteControls;
  final Future Function()? onSyncAttendees;
  final Future Function(bool useEventbrite)? onUpdateTicketingMode;

  @override
  State<EnhancedAllAttendees> createState() => _EnhancedAllAttendeesState();
}

class _EnhancedAllAttendeesState extends State<EnhancedAllAttendees>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSyncing = false;
  List<DocumentSnapshot> _speakers = [];
  List<DocumentSnapshot> _connections = [];
  bool _isLoadingExtras = true;
  List<DocumentReference> _sentRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadExtraData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadExtraData() async {
    try {
      // Load speakers (participants with role == 'speaker')
      final participantsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventRef.id)
          .collection('participant')
          .where('role', isEqualTo: 'speaker')
          .get();

      _speakers = participantsSnapshot.docs;

      // Load connections and sent requests
      if (currentUserDocument != null) {
        final friends = currentUserDocument?.friends ?? [];
        final connectionSnapshots = await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventRef.id)
            .collection('participant')
            .where('user_ref', whereIn: friends.isEmpty ? ['dummy'] : friends)
            .get();

        _connections = connectionSnapshots.docs;

        // Load sent friend requests
        _sentRequests = currentUserDocument!.sentRequests.toList();
      }

      if (mounted) {
        setState(() {
          _isLoadingExtras = false;
        });
      }
    } catch (e) {
      print('Error loading extra data: $e');
      if (mounted) {
        setState(() {
          _isLoadingExtras = false;
        });
      }
    }
  }

  Future<void> _handleSyncAttendees() async {
    if (_isSyncing || widget.eventbriteId == null) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      if (widget.onSyncAttendees != null) {
        await widget.onSyncAttendees!();
      } else {
        // Default sync implementation
        await syncEventbriteAttendees(widget.eventbriteId!);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Attendees synced successfully'),
          backgroundColor: FlutterFlowTheme.of(context).success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sync attendees: ${e.toString()}'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Widget _buildEventbriteControls() {
    // Only show EventBrite controls for actual EventBrite events
    if (!widget.showEventbriteControls ||
        widget.eventbriteId == null ||
        widget.eventbriteId!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.only(bottom: 16, top: 75, right: 16, left: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF4E6),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFFFB74D),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FaIcon(
                FontAwesomeIcons.calendar,
                color: Color(0xFFFF6F00),
                size: 20.0,
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EventBrite Synced Event',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                            color: const Color(0xFFE65100),
                            letterSpacing: 0.0,
                          ),
                    ),
                    Text(
                      'Attendees from EventBrite are automatically synced',
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            font: GoogleFonts.inter(),
                            color: const Color(0xFFFF8F00),
                            letterSpacing: 0.0,
                          ),
                    ),
                  ],
                ),
              ),
              FFButtonWidget(
                onPressed: _isSyncing ? null : _handleSyncAttendees,
                text: _isSyncing ? 'Syncing...' : 'Sync Now',
                icon: const Icon(
                  Icons.sync,
                  size: 16.0,
                ),
                options: FFButtonOptions(
                  height: 36.0,
                  padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                  iconPadding:
                      const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 8.0, 0.0),
                  color: const Color(0xFFFF6F00),
                  textStyle: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                        ),
                        color: Colors.white,
                        letterSpacing: 0.0,
                      ),
                  elevation: 0.0,
                  borderRadius: BorderRadius.circular(18.0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakersList() {
    if (_isLoadingExtras) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            FlutterFlowTheme.of(context).primary,
          ),
        ),
      );
    }

    if (_speakers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_off,
              size: 48.0,
              color: FlutterFlowTheme.of(context).secondaryText,
            ),
            const SizedBox(height: 16.0),
            Text(
              'No speakers for this event',
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    font: GoogleFonts.inter(),
                    color: FlutterFlowTheme.of(context).secondaryText,
                    letterSpacing: 0.0,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _speakers.length,
      itemBuilder: (context, index) {
        final speaker = _speakers[index].data() as Map<String, dynamic>;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
              Container(
                width: 48.0,
                height: 48.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FlutterFlowTheme.of(context).primary,
                ),
                child: ClipOval(
                  child: speaker['image'] != null
                      ? CachedNetworkImage(
                          imageUrl: speaker['image'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Icon(
                            Icons.mic,
                            color: Colors.white,
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.mic,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.mic,
                          color: Colors.white,
                        ),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      speaker['name'] ?? 'Speaker',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                            letterSpacing: 0.0,
                          ),
                    ),
                    if (speaker['bio'] != null && speaker['bio'].isNotEmpty)
                      Text(
                        speaker['bio'],
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              font: GoogleFonts.inter(),
                              color: FlutterFlowTheme.of(context).secondaryText,
                              letterSpacing: 0.0,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 4.0,
                ),
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Text(
                  'Speaker',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context).primary,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionsList() {
    if (_isLoadingExtras) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            FlutterFlowTheme.of(context).primary,
          ),
        ),
      );
    }

    if (_connections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 48.0,
              color: FlutterFlowTheme.of(context).secondaryText,
            ),
            const SizedBox(height: 16.0),
            Text(
              'No connections attending',
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    font: GoogleFonts.inter(),
                    color: FlutterFlowTheme.of(context).secondaryText,
                    letterSpacing: 0.0,
                  ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'Your friends who are attending will appear here',
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.inter(),
                    color: FlutterFlowTheme.of(context).secondaryText,
                    letterSpacing: 0.0,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _connections.length,
      itemBuilder: (context, index) {
        final connection = _connections[index].data() as Map<String, dynamic>;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
              Container(
                width: 48.0,
                height: 48.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FlutterFlowTheme.of(context).alternate,
                ),
                child: ClipOval(
                  child: connection['image'] != null
                      ? CachedNetworkImage(
                          imageUrl: connection['image'],
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
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection['name'] ?? 'Friend',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                            ),
                            letterSpacing: 0.0,
                          ),
                    ),
                    if (connection['bio'] != null &&
                        connection['bio'].isNotEmpty)
                      Text(
                        connection['bio'],
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              font: GoogleFonts.inter(),
                              color: FlutterFlowTheme.of(context).secondaryText,
                              letterSpacing: 0.0,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.favorite,
                color: FlutterFlowTheme.of(context).tertiary,
                size: 20.0,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Column(
        children: [
          // EventBrite Controls (if applicable)
          _buildEventbriteControls(),

          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              border: Border(
                bottom: BorderSide(
                  color: FlutterFlowTheme.of(context).alternate,
                  width: 1.0,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: FlutterFlowTheme.of(context).primary,
              unselectedLabelColor: FlutterFlowTheme.of(context).secondaryText,
              labelStyle: FlutterFlowTheme.of(context).titleMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                    ),
                    fontSize: 15.0,
                    letterSpacing: 0.0,
                  ),
              indicatorColor: FlutterFlowTheme.of(context).primary,
              tabs: const [
                Tab(text: 'All Attendees'),
                Tab(text: 'Speakers'),
                Tab(text: 'Connections'),
              ],
            ),
          ),

          // Tab Bar View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All Attendees Tab
                AttendeeDisplay(
                  eventRef: widget.eventRef,
                  eventbriteEventId: widget.eventbriteId,
                  showPendingUsers: true,
                  showEventbriteBadge: true,
                  currentUserRef: currentUserReference,
                  currentUserFriends: currentUserDocument?.friends,
                  currentUserSentRequests: _sentRequests,
                  onInvitePending: (email, name) async {
                    // Handle inviting pending users
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Invite sent to $name'),
                        backgroundColor: FlutterFlowTheme.of(context).success,
                      ),
                    );
                  },
                  onConnectUser: (userRef) async {
                    // Send friend request
                    try {
                      // Update local state first
                      if (!_sentRequests.contains(userRef)) {
                        setState(() {
                          _sentRequests.add(userRef);
                        });
                      }

                      // Update current user's sent_requests
                      await currentUserReference!.update({
                        'sent_requests': FieldValue.arrayUnion([userRef]),
                      });

                      // Update target user's friend_requests
                      await userRef.update({
                        'friend_requests':
                            FieldValue.arrayUnion([currentUserReference]),
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Friend request sent'),
                          backgroundColor: FlutterFlowTheme.of(context).success,
                        ),
                      );
                    } catch (e) {
                      // Revert local state on error
                      setState(() {
                        _sentRequests.remove(userRef);
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Failed to send friend request'),
                          backgroundColor: FlutterFlowTheme.of(context).error,
                        ),
                      );
                    }
                  },
                  onCancelRequest: (userRef) async {
                    // Cancel friend request
                    try {
                      // Update local state first
                      setState(() {
                        _sentRequests.remove(userRef);
                      });

                      // Update current user's sent_requests
                      await currentUserReference!.update({
                        'sent_requests': FieldValue.arrayRemove([userRef]),
                      });

                      // Update target user's friend_requests
                      await userRef.update({
                        'friend_requests':
                            FieldValue.arrayRemove([currentUserReference]),
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Friend request cancelled'),
                          backgroundColor:
                              FlutterFlowTheme.of(context).secondaryText,
                        ),
                      );
                    } catch (e) {
                      // Revert local state on error
                      if (!_sentRequests.contains(userRef)) {
                        setState(() {
                          _sentRequests.add(userRef);
                        });
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Failed to cancel request'),
                          backgroundColor: FlutterFlowTheme.of(context).error,
                        ),
                      );
                    }
                  },
                ),

                // Speakers Tab
                _buildSpeakersList(),

                // Connections Tab
                _buildConnectionsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
