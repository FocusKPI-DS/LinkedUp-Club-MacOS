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

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/auth/firebase_auth/auth_util.dart';

class EventbriteDashboard extends StatefulWidget {
  const EventbriteDashboard({
    super.key,
    this.width,
    this.height,
    this.onEventSync,
    this.onSettingsClick,
  });

  final double? width;
  final double? height;
  final Future Function(String eventId)? onEventSync;
  final Future Function(String eventId)? onSettingsClick;

  @override
  State<EventbriteDashboard> createState() => _EventbriteDashboardState();
}

class _EventbriteDashboardState extends State<EventbriteDashboard> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, bool> _syncedEvents = {};
  final Map<String, bool> _syncingEvents = {};
  String? _eventbriteUserName;
  bool _autoSyncEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadEvents();
  }

  Future<void> _loadUserInfo() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid)
          .get();

      if (userDoc.exists) {
        setState(() {
          _eventbriteUserName = userDoc.data()?['eventbrite_user_name'];
          _autoSyncEnabled = userDoc.data()?['eventbrite_auto_sync'] ?? false;
        });
      }
    } catch (e) {
      print('Error loading user info: $e');
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch EventBrite events
      final events = await fetchEventbriteEvents();

      // Check which events are already synced
      final syncedEventIds = await checkSyncedEvents(
        events.map((e) => e['id'].toString()).toList(),
      );

      setState(() {
        _events = List<Map<String, dynamic>>.from(events);
        _syncedEvents = {
          for (var id in syncedEventIds) id: true,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load EventBrite events: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _syncEvent(Map<String, dynamic> event) async {
    final eventId = event['id'].toString();

    setState(() {
      _syncingEvents[eventId] = true;
    });

    try {
      // Sync the event to LinkedUp
      await syncEventbriteEvent(eventId);

      // Call callback if provided
      if (widget.onEventSync != null) {
        await widget.onEventSync!(eventId);
      }

      setState(() {
        _syncedEvents[eventId] = true;
        _syncingEvents[eventId] = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Event synced successfully!'),
          backgroundColor: FlutterFlowTheme.of(context).success,
        ),
      );
    } catch (e) {
      setState(() {
        _syncingEvents[eventId] = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sync event: $e'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _handleDisconnect() async {
    // Show confirmation dialog
    final bool? shouldDisconnect = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Disconnect EventBrite?'),
          content: const Text(
              'Are you sure you want to disconnect your EventBrite account? You\'ll need to reconnect to sync events again.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Disconnect',
                style: TextStyle(color: FlutterFlowTheme.of(context).error),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDisconnect != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update user document to remove EventBrite connection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid)
          .update({
        'eventbrite_connected': false,
        'eventbrite_access_token': FieldValue.delete(),
        'eventbrite_refresh_token': FieldValue.delete(),
        'eventbrite_user_id': FieldValue.delete(),
        'eventbrite_user_name': FieldValue.delete(),
        'eventbrite_connected_at': FieldValue.delete(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Disconnected from EventBrite'),
          backgroundColor: FlutterFlowTheme.of(context).success,
        ),
      );

      // Navigate back to profile
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to disconnect. Please try again.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    }
  }

  Future<void> _handleSwitchAccount() async {
    // Show confirmation dialog
    final bool? shouldSwitch = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Switch EventBrite Account?'),
          content: const Text(
              'This will disconnect your current EventBrite account and allow you to connect a different one. Continue?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Switch Account',
                style: TextStyle(color: FlutterFlowTheme.of(context).primary),
              ),
            ),
          ],
        );
      },
    );

    if (shouldSwitch != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // First disconnect the current account
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid)
          .update({
        'eventbrite_connected': false,
        'eventbrite_access_token': FieldValue.delete(),
        'eventbrite_refresh_token': FieldValue.delete(),
        'eventbrite_user_id': FieldValue.delete(),
        'eventbrite_user_name': FieldValue.delete(),
        'eventbrite_connected_at': FieldValue.delete(),
      });

      // Navigate back to profile with a message
      Navigator.of(context).pop();

      // Show success message after navigation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Account disconnected. Click "Connect EventBrite" to connect a new account.'),
          backgroundColor: FlutterFlowTheme.of(context).success,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to switch accounts. Please try again.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF6F00), Color(0xFFE65100)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: const FaIcon(
                              FontAwesomeIcons.calendar,
                              color: Colors.white,
                              size: 20.0,
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Text(
                              'EventBrite Events',
                              style: FlutterFlowTheme.of(context)
                                  .headlineSmall
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    color: Colors.white,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.white,
                          ),
                          onPressed: _loadEvents,
                          tooltip: 'Refresh',
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                          ),
                          onSelected: (value) async {
                            if (value == 'disconnect') {
                              await _handleDisconnect();
                            } else if (value == 'switch_account') {
                              await _handleSwitchAccount();
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem<String>(
                              value: 'switch_account',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.swap_horiz,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 20.0,
                                  ),
                                  const SizedBox(width: 12.0),
                                  Text(
                                    'Switch Account',
                                    style: TextStyle(
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem<String>(
                              value: 'disconnect',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.logout,
                                    color: FlutterFlowTheme.of(context).error,
                                    size: 20.0,
                                  ),
                                  const SizedBox(width: 12.0),
                                  Text(
                                    'Disconnect',
                                    style: TextStyle(
                                      color: FlutterFlowTheme.of(context).error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_eventbriteUserName != null) ...[
                        Icon(
                          Icons.account_circle,
                          size: 16.0,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 6.0),
                        Flexible(
                          child: Text(
                            _eventbriteUserName!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13.0,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8.0),
                          width: 1.0,
                          height: 12.0,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ],
                      Text(
                        '${_events.length} events',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        FlutterFlowTheme.of(context).primary,
                      ),
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48.0,
                              color: FlutterFlowTheme.of(context).error,
                            ),
                            const SizedBox(height: 16.0),
                            Text(
                              _errorMessage!,
                              style: FlutterFlowTheme.of(context).bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16.0),
                            ElevatedButton(
                              onPressed: _loadEvents,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _events.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.calendarXmark,
                                  size: 48.0,
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                ),
                                const SizedBox(height: 16.0),
                                Text(
                                  'No events found',
                                  style: FlutterFlowTheme.of(context).bodyLarge,
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  'Create events on EventBrite to see them here',
                                  style: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .override(
                                        font: GoogleFonts.inter(),
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        letterSpacing: 0.0,
                                      ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _events.length,
                            itemBuilder: (context, index) {
                              final event = _events[index];
                              final eventId = event['id'].toString();
                              final isSynced = _syncedEvents[eventId] ?? false;
                              final isSyncing =
                                  _syncingEvents[eventId] ?? false;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12.0),
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context)
                                      .primaryBackground,
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(
                                    color: isSynced
                                        ? FlutterFlowTheme.of(context).success
                                        : FlutterFlowTheme.of(context)
                                            .alternate,
                                    width: 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Event Image
                                    if (event['logo']?['url'] != null)
                                      ClipRRect(
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(12.0),
                                          topRight: Radius.circular(12.0),
                                        ),
                                        child: CachedNetworkImage(
                                          imageUrl: event['logo']['url'],
                                          height: 150.0,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),

                                    // Event Details
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            event['name']['text'] ??
                                                'Untitled Event',
                                            style: FlutterFlowTheme.of(context)
                                                .titleMedium
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  letterSpacing: 0.0,
                                                ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8.0),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 16.0,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                              ),
                                              const SizedBox(width: 4.0),
                                              Text(
                                                _formatDate(event['start']
                                                        ['local'] ??
                                                    ''),
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodySmall
                                                    .override(
                                                      font: GoogleFonts.inter(),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      letterSpacing: 0.0,
                                                    ),
                                              ),
                                            ],
                                          ),
                                          if (event['venue'] != null) ...[
                                            const SizedBox(height: 4.0),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.location_on,
                                                  size: 16.0,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                ),
                                                const SizedBox(width: 4.0),
                                                Expanded(
                                                  child: Text(
                                                    event['venue']['name'] ??
                                                        'Online Event',
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodySmall
                                                        .override(
                                                          font: GoogleFonts
                                                              .inter(),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          letterSpacing: 0.0,
                                                        ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          const SizedBox(height: 12.0),

                                          // Action Buttons
                                          Row(
                                            children: [
                                              // Sync Button
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: isSynced ||
                                                          isSyncing
                                                      ? null
                                                      : () => _syncEvent(event),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: isSynced
                                                        ? FlutterFlowTheme.of(
                                                                context)
                                                            .success
                                                        : FlutterFlowTheme.of(
                                                                context)
                                                            .primary,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                            vertical: 12.0),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      if (isSyncing)
                                                        const SizedBox(
                                                          width: 16.0,
                                                          height: 16.0,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2.0,
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                    Color>(
                                                              Colors.white,
                                                            ),
                                                          ),
                                                        )
                                                      else
                                                        Icon(
                                                          isSynced
                                                              ? Icons.check
                                                              : Icons.sync,
                                                          size: 16.0,
                                                          color: Colors.white,
                                                        ),
                                                      const SizedBox(width: 8.0),
                                                      Text(
                                                        isSyncing
                                                            ? 'Syncing...'
                                                            : (isSynced
                                                                ? 'Synced'
                                                                : 'Sync to LinkedUp'),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 14.0,
                                                          fontWeight:
                                                              FontWeight.w500,
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
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),

          // Footer with auto-sync toggle
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).primaryBackground,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16.0),
                bottomRight: Radius.circular(16.0),
              ),
              border: Border(
                top: BorderSide(
                  color: FlutterFlowTheme.of(context).alternate,
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.sync,
                      size: 20.0,
                      color: Color(0xFFFF6F00),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Auto-Sync New Events',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  letterSpacing: 0.0,
                                ),
                          ),
                          Text(
                            'Automatically import new EventBrite events',
                            style:
                                FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.inter(),
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      letterSpacing: 0.0,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _autoSyncEnabled,
                      onChanged: (value) async {
                        setState(() {
                          _autoSyncEnabled = value;
                        });
                        try {
                          await setupEventbriteAutoSync(value);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(value
                                  ? 'Auto-sync enabled'
                                  : 'Auto-sync disabled'),
                              backgroundColor:
                                  FlutterFlowTheme.of(context).success,
                            ),
                          );
                        } catch (e) {
                          setState(() {
                            _autoSyncEnabled = !value;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  const Text('Failed to update auto-sync setting'),
                              backgroundColor:
                                  FlutterFlowTheme.of(context).error,
                            ),
                          );
                        }
                      },
                      activeThumbColor: const Color(0xFFFF6F00),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
