import 'package:flutter/material.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'
    show canLaunchUrl, launchUrl, LaunchMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_util.dart';

// Custom painter for dashed line
class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFFEF4444)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class TodaysCalendarEvents extends StatefulWidget {
  const TodaysCalendarEvents({Key? key}) : super(key: key);

  @override
  State<TodaysCalendarEvents> createState() => _TodaysCalendarEventsState();
}

class _TodaysCalendarEventsState extends State<TodaysCalendarEvents> {
  List<Map<String, dynamic>> _todayEvents = [];
  bool _isLoading = false;
  bool _hasError = false;

  // Cache keys
  static const String _cacheKey = 'calendar_events_today';
  static const String _cacheTimestampKey = 'calendar_events_timestamp';
  static const String _cacheDateKey = 'calendar_events_date';
  static const Duration _cacheValidityDuration = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    _loadTodaysEvents(forceRefresh: false);
  }

  /// Load cached events if available and valid
  Future<List<Map<String, dynamic>>?> _loadCachedEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedEventsJson = prefs.getString(_cacheKey);
      final cachedTimestampStr = prefs.getString(_cacheTimestampKey);
      final cachedDateStr = prefs.getString(_cacheDateKey);

      if (cachedEventsJson == null ||
          cachedTimestampStr == null ||
          cachedDateStr == null) {
        return null;
      }

      // Check if cache is for today
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month}-${now.day}';
      if (cachedDateStr != todayStr) {
        return null; // Cache is for a different day
      }

      // Check if cache is still valid (not expired)
      final cachedTimestamp = DateTime.parse(cachedTimestampStr);
      final cacheAge = now.difference(cachedTimestamp);
      if (cacheAge > _cacheValidityDuration) {
        return null; // Cache expired
      }

      // Parse and return cached events
      final List<dynamic> eventsList = json.decode(cachedEventsJson);
      return eventsList.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print('Error loading cached events: $e');
      return null;
    }
  }

  /// Save events to cache
  Future<void> _saveEventsToCache(List<Map<String, dynamic>> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month}-${now.day}';

      final eventsJson = json.encode(events);
      await prefs.setString(_cacheKey, eventsJson);
      await prefs.setString(_cacheTimestampKey, now.toIso8601String());
      await prefs.setString(_cacheDateKey, todayStr);
    } catch (e) {
      print('Error saving events to cache: $e');
    }
  }

  Future<void> _loadTodaysEvents({bool forceRefresh = false}) async {
    if (_isLoading || currentUser == null) return;

    // Check if user has Gmail/Google account connected
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserUid)
        .get();

    if (!userDoc.exists || !userDoc.data()?['gmail_connected']) {
      setState(() {
        _hasError = false; // Not an error, just not connected
        _isLoading = false;
      });
      return;
    }

    // Try to load from cache first (unless force refresh)
    if (!forceRefresh) {
      final cachedEvents = await _loadCachedEvents();
      if (cachedEvents != null) {
        setState(() {
          _todayEvents = cachedEvents;
          _isLoading = false;
          _hasError = false;
        });
        return; // Use cached data, no API call needed
      }
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final endOfDay =
          startOfDay.add(Duration(days: 1)).subtract(Duration(seconds: 1));

      final startOfDayUtc = startOfDay.toUtc();
      final endOfDayUtc = endOfDay.toUtc();

      final result = await actions.calendarListEvents(
        calendarId: 'primary',
        timeMin: startOfDayUtc.toIso8601String(),
        timeMax: endOfDayUtc.toIso8601String(),
        maxResults: 10,
        singleEvents: true,
        orderBy: 'startTime',
      );

      if (result != null && result['success'] == true) {
        final eventsList = result['events'];
        List<Map<String, dynamic>> newEvents = [];

        if (eventsList != null && eventsList is List) {
          for (var event in eventsList) {
            if (event is Map) {
              newEvents.add(Map<String, dynamic>.from(event));
            }
          }
        }

        // Sort by start time
        newEvents.sort((a, b) {
          final aStart = a['start'];
          final bStart = b['start'];
          if (aStart == null || bStart == null) return 0;

          DateTime? aTime;
          DateTime? bTime;

          if (aStart['dateTime'] != null) {
            try {
              aTime = DateTime.parse(aStart['dateTime']).toLocal();
            } catch (e) {}
          } else if (aStart['date'] != null) {
            try {
              aTime = DateTime.parse(aStart['date']).toLocal();
            } catch (e) {}
          }

          if (bStart['dateTime'] != null) {
            try {
              bTime = DateTime.parse(bStart['dateTime']).toLocal();
            } catch (e) {}
          } else if (bStart['date'] != null) {
            try {
              bTime = DateTime.parse(bStart['date']).toLocal();
            } catch (e) {}
          }

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return aTime.compareTo(bTime);
        });

        // Save to cache
        await _saveEventsToCache(newEvents);

        setState(() {
          _todayEvents = newEvents;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  String _formatEventTime(Map<String, dynamic> event) {
    final start = event['start'];
    if (start == null) return '';

    DateTime? startTime;
    DateTime? endTime;
    bool isAllDay = false;

    if (start['dateTime'] != null) {
      try {
        startTime = DateTime.parse(start['dateTime']).toLocal();
      } catch (e) {}
    } else if (start['date'] != null) {
      try {
        startTime = DateTime.parse(start['date']).toLocal();
        isAllDay = true;
      } catch (e) {}
    }

    if (event['end'] != null && event['end']['dateTime'] != null) {
      try {
        endTime = DateTime.parse(event['end']['dateTime']).toLocal();
      } catch (e) {}
    }

    if (isAllDay) {
      return 'All day';
    } else if (startTime != null) {
      String timeStr = DateFormat('h:mm a').format(startTime);
      if (endTime != null) {
        timeStr += ' - ${DateFormat('h:mm a').format(endTime)}';
      }
      return timeStr;
    }
    return '';
  }

  String? _getMeetingLink(Map<String, dynamic> event) {
    final hangoutLink = event['hangoutLink'] ?? '';
    final conferenceData = event['conferenceData'];

    if (hangoutLink.isNotEmpty) {
      return hangoutLink;
    } else if (conferenceData != null) {
      final entryPoints = conferenceData['entryPoints'];
      if (entryPoints != null &&
          entryPoints is List &&
          entryPoints.isNotEmpty) {
        for (var entry in entryPoints) {
          if (entry['entryPointType'] == 'video' && entry['uri'] != null) {
            return entry['uri'];
          }
        }
      }
    }
    return null;
  }

  // Get the earliest and latest event times to determine schedule range
  Map<String, DateTime> _getScheduleRange() {
    DateTime? earliestTime;
    DateTime? latestTime;

    for (var event in _todayEvents) {
      final start = event['start'];
      DateTime? startTime;
      DateTime? endTime;

      if (start != null && start['dateTime'] != null) {
        try {
          startTime = DateTime.parse(start['dateTime']).toLocal();
        } catch (e) {}
      }
      if (event['end'] != null && event['end']['dateTime'] != null) {
        try {
          endTime = DateTime.parse(event['end']['dateTime']).toLocal();
        } catch (e) {}
      }

      if (startTime != null) {
        if (earliestTime == null || startTime.isBefore(earliestTime)) {
          earliestTime = startTime;
        }
      }
      if (endTime != null) {
        if (latestTime == null || endTime.isAfter(latestTime)) {
          latestTime = endTime;
        }
      }
    }

    // Default to 8 AM - 5 PM if no events
    final now = DateTime.now();
    final defaultStart = DateTime(now.year, now.month, now.day, 8, 0);
    final defaultEnd = DateTime(now.year, now.month, now.day, 17, 0);

    // Start 1 hour before first meeting (rounded down to hour)
    final scheduleStart = earliestTime != null
        ? DateTime(
            earliestTime.year,
            earliestTime.month,
            earliestTime.day,
            earliestTime.hour - 1 < 0 ? 0 : earliestTime.hour - 1,
            0,
          )
        : defaultStart;

    // End 1 hour after last meeting (rounded up to hour), but at least until 5 PM
    final scheduleEnd = latestTime != null
        ? DateTime(
            latestTime.year,
            latestTime.month,
            latestTime.day,
            latestTime.hour + 1 > 23 ? 23 : latestTime.hour + 1,
            0,
          )
        : defaultEnd;

    // Ensure minimum 4 hours of schedule shown
    final minEnd = scheduleStart.add(Duration(hours: 4));
    final finalEnd = scheduleEnd.isAfter(minEnd) ? scheduleEnd : minEnd;

    return {'start': scheduleStart, 'end': finalEnd};
  }

  // Calculate event position and height based on time
  Map<String, double> _calculateEventPosition(Map<String, dynamic> event,
      DateTime scheduleStart, DateTime scheduleEnd) {
    final start = event['start'];
    DateTime? startTime;
    DateTime? endTime;

    if (start != null && start['dateTime'] != null) {
      try {
        startTime = DateTime.parse(start['dateTime']).toLocal();
      } catch (e) {}
    }
    if (event['end'] != null && event['end']['dateTime'] != null) {
      try {
        endTime = DateTime.parse(event['end']['dateTime']).toLocal();
      } catch (e) {}
    }

    if (startTime == null || endTime == null) {
      return {'top': 0, 'height': 60};
    }

    // Start of day (8 AM)
    final startOfDay =
        DateTime(startTime.year, startTime.month, startTime.day, 8, 0);
    // End of day (5 PM = 17:00)
    final endOfDay =
        DateTime(startTime.year, startTime.month, startTime.day, 17, 0);

    // Calculate minutes from start of day
    final startMinutes = startTime.difference(startOfDay).inMinutes;
    final durationMinutes = endTime.difference(startTime).inMinutes;

    // Total minutes in view (8 AM to 5 PM = 9 hours = 540 minutes)
    final totalMinutes = endOfDay.difference(startOfDay).inMinutes;

    // Fixed height for the schedule area (100px)
    final scheduleHeight = 100.0;
    final pixelsPerMinute = scheduleHeight / totalMinutes;

    final top = startMinutes * pixelsPerMinute;
    final height = durationMinutes * pixelsPerMinute;

    return {'top': top, 'height': height};
  }

  // Get blue shade based on index
  Color _getBlueShade(int index) {
    final shades = [
      Color(0xFFE3F2FD), // Light blue
      Color(0xFFBBDEFB), // Medium light blue
      Color(0xFF90CAF9), // Medium blue
      Color(0xFF64B5F6), // Bright blue
      Color(0xFF42A5F5), // Deeper blue
    ];
    return shades[index % shades.length];
  }

  // Get icon based on event type
  Widget _getEventIcon(Map<String, dynamic> event) {
    final meetingLink = _getMeetingLink(event);
    final location = event['location'] ?? '';

    // Video call icon if meeting link exists
    if (meetingLink != null) {
      return Icon(
        Icons.videocam,
        size: 20,
        color: Color(0xFF2563EB),
      );
    }
    // Location icon if location exists
    else if (location.isNotEmpty) {
      return Icon(
        Icons.location_on,
        size: 20,
        color: Color(0xFF2563EB),
      );
    }
    // Default group/people icon
    else {
      return Icon(
        Icons.people,
        size: 20,
        color: Color(0xFF2563EB),
      );
    }
  }

  // Get platform/source name from event
  String _getEventPlatform(Map<String, dynamic> event) {
    // Check for organizer email to determine platform
    final organizer = event['organizer'];
    if (organizer != null && organizer['email'] != null) {
      final email = organizer['email'].toString().toLowerCase();
      if (email.contains('zoom')) {
        return 'Zoom';
      } else if (email.contains('teams') || email.contains('microsoft')) {
        return 'Microsoft Teams';
      } else if (email.contains('google')) {
        return 'Google Calendar';
      }
    }

    // Check for conference data type
    final conferenceData = event['conferenceData'];
    if (conferenceData != null) {
      final entryPoints = conferenceData['entryPoints'];
      if (entryPoints != null && entryPoints is List) {
        for (var entry in entryPoints) {
          if (entry['entryPointType'] == 'video') {
            final uri = entry['uri']?.toString().toLowerCase() ?? '';
            if (uri.contains('zoom')) {
              return 'Zoom';
            } else if (uri.contains('teams')) {
              return 'Microsoft Teams';
            }
          }
        }
      }
    }

    // Default to Google Calendar (current implementation)
    return 'Google Calendar';
  }

  Widget _buildMeetingCard(Map<String, dynamic> event, int index) {
    final summary = event['summary'] ?? '(No Title)';
    final timeStr = _formatEventTime(event);
    final meetingLink = _getMeetingLink(event);
    final description = event['description'] ?? '';
    final location = event['location'] ?? '';
    final platform = _getEventPlatform(event);

    // Get start time for display - format as "1:00" and "PM" on separate lines
    String timeHour = '';
    String timePeriod = '';
    final start = event['start'];
    if (start != null && start['dateTime'] != null) {
      try {
        final startTime = DateTime.parse(start['dateTime']).toLocal();
        final formatted = DateFormat('h:mm a').format(startTime);
        final parts = formatted.split(' ');
        if (parts.length == 2) {
          timeHour = parts[0]; // "1:00"
          timePeriod = parts[1]; // "PM"
        }
      } catch (e) {}
    }
    if (timeHour.isEmpty) {
      final firstPart = timeStr.split(' - ')[0]; // Get first part of time range
      final parts = firstPart.split(' ');
      if (parts.length >= 2) {
        timeHour = parts[0];
        timePeriod = parts[1];
      } else {
        timeHour = firstPart;
      }
    }

    return InkWell(
      onTap: meetingLink != null
          ? () async {
              final uri = Uri.parse(meetingLink);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          : null,
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFFF8F9FA), // Light grey background
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time on the left - stacked format
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeHour,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w600, // Less bold
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  if (timePeriod.isNotEmpty)
                    Text(
                      timePeriod,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400, // Less bold
                        color: Color(0xFF1E293B),
                      ),
                    ),
                ],
              ),
            ),
            // Vertical blue line
            Container(
              width: 3,
              height: 45,
              margin: EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Content in the middle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event title
                  Text(
                    summary,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  // Platform indicator
                  Text(
                    platform,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  if (description.isNotEmpty || location.isNotEmpty) ...[
                    SizedBox(height: 2),
                    // Description or location
                    Text(
                      description.isNotEmpty
                          ? description
                          : (location.isNotEmpty ? location : ''),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Icon on the right
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(0xFFE3F2FD), // Light blue background
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _getEventIcon(event),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if user is not connected to Google or if there are no events
    if (!_isLoading && _todayEvents.isEmpty && !_hasError) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFFE8EAED),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1E293B).withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Schedule",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (_isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  color: const Color(0xFF64748B),
                  onPressed: () {
                    // TODO: Implement add event
                  },
                  tooltip: 'Add Event',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          SizedBox(height: 12),
          if (_isLoading && _todayEvents.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
              ),
            )
          else if (_hasError)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Failed to load events',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                    ),
                  ],
                ),
              ),
            )
          else if (_todayEvents.isEmpty)
            const SizedBox.shrink() // Hide completely if no events
          else ...[
            // Meeting cards - show up to 3, then "View all" link
            ...List.generate(
              _todayEvents.length > 3 ? 3 : _todayEvents.length,
              (index) => _buildMeetingCard(_todayEvents[index], index),
            ),
            // View all link if more than 3 events
            if (_todayEvents.length > 3)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Center(
                  child: InkWell(
                    onTap: () {
                      // TODO: Navigate to full schedule view
                    },
                    child: Text(
                      'View all',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
