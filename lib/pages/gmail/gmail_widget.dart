import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/gmail/gmail_model.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:flutter/gestures.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:pdfx/pdfx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
export '/pages/gmail/gmail_model.dart';

class GmailWidget extends StatefulWidget {
  const GmailWidget({super.key});

  @override
  _GmailWidgetState createState() => _GmailWidgetState();
}

class _GmailWidgetState extends State<GmailWidget> {
  late GmailModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map<String, dynamic>> _emails = [];
  List<Map<String, dynamic>> _allEmails = []; // Store all emails for search
  bool _isLoading = false;
  String? _nextPageToken;
  String? _selectedEmailId;
  Map<String, dynamic>? _selectedEmail;
  bool _isLoadingEmail = false;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All'; // All, Unread, Read
  bool _showCalendar = false; // Track calendar visibility
  List<Map<String, dynamic>> _calendarEvents = [];
  bool _isLoadingCalendar = false;
  DateTime _selectedCalendarDate =
      DateTime.now(); // Selected date for calendar view

  // Cache management
  StreamSubscription<DocumentSnapshot>? _cacheSubscription;
  Timer? _autoRefreshTimer;
  final Map<String, Map<String, dynamic>> _emailBodyCache =
      {}; // In-memory cache for full email bodies (session only)

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GmailModel());
    // Only check Gmail connection if user is already signed in
    // This prevents Gmail OAuth from interfering with initial sign-in
    if (currentUser != null && currentUserUid.isNotEmpty) {
      _initializeGmailCache();
      _checkGmailConnection();
    }
  }

  @override
  void dispose() {
    _cacheSubscription?.cancel();
    _autoRefreshTimer?.cancel();
    _emailBodyCache.clear(); // Clear in-memory cache on dispose
    _model.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Filter emails based on search query and selected filter
  List<Map<String, dynamic>> _getFilteredEmails() {
    List<Map<String, dynamic>> filtered = _emails;

    // Apply filter (All, Unread, Read) using Gmail labels
    if (_selectedFilter == 'Unread') {
      filtered = filtered.where((email) {
        final labels = email['labels'] as List?;
        if (labels == null) return false;
        // UNREAD label means unread, absence means read
        return labels.contains('UNREAD');
      }).toList();
    } else if (_selectedFilter == 'Read') {
      filtered = filtered.where((email) {
        final labels = email['labels'] as List?;
        if (labels == null) return false;
        // Read emails don't have UNREAD label
        return !labels.contains('UNREAD');
      }).toList();
    }

    // Apply search query
    final query = _searchController.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      filtered = filtered.where((email) {
        final subject = (email['subject'] ?? '').toString().toLowerCase();
        final from = (email['from'] ?? '').toString().toLowerCase();
        final snippet = (email['snippet'] ?? '').toString().toLowerCase();
        final to = (email['to'] ?? '').toString().toLowerCase();

        return subject.contains(query) ||
            from.contains(query) ||
            snippet.contains(query) ||
            to.contains(query);
      }).toList();
    }

    return filtered;
  }

  // Check if email is unread based on Gmail labels
  bool _isUnread(Map<String, dynamic> email) {
    final labels = email['labels'] as List?;
    if (labels == null) return false;
    return labels.contains('UNREAD');
  }

  // Check if email is starred based on Gmail labels
  bool _isStarred(Map<String, dynamic> email) {
    final labels = email['labels'] as List?;
    if (labels == null) return false;
    return labels.contains('STARRED');
  }

  /// Initialize Gmail cache - read from Firestore and set up auto-refresh
  void _initializeGmailCache() {
    if (currentUser == null || currentUserUid.isEmpty) {
      return;
    }

    // Listen to Firestore cache for real-time updates
    _cacheSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserUid)
        .collection('gmail_cache')
        .doc('recent')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        if (data != null && data['emails'] != null) {
          final cachedEmails = List<Map<String, dynamic>>.from(
            (data['emails'] as List).map((e) => _convertMap(e as Map)),
          );

          final newNextPageToken = data['next_page_token']?.toString();

          setState(() {
            _emails = cachedEmails;
            _allEmails = cachedEmails;
            _nextPageToken = newNextPageToken;
          });

          print('✅ Gmail cache updated: ${cachedEmails.length} emails');

          // Automatically trigger background loading if we have less than 50 emails and a nextPageToken
          if (cachedEmails.length < 50 &&
              newNextPageToken != null &&
              !_isLoading) {
            // Delay to avoid immediate re-triggering
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted && _emails.length < 50 && _nextPageToken != null) {
                _loadMoreEmailsInBackground();
              }
            });
          }
        }
      }
    });

    // Set up auto-refresh timer (every 3 minutes - lightweight check)
    // Uses lightweight check that only fetches top 10 emails
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      if (mounted && currentUser != null && currentUserUid.isNotEmpty) {
        _checkForNewEmails(); // Lightweight check (top 10 only)
        // Gmail Watch API temporarily removed
        // _checkAndRenewWatch(); // Check watch expiration
      }
    });
  }

  /// Load emails from cache first, then refresh in background
  Future<void> _loadEmailsFromCache() async {
    if (currentUser == null || currentUserUid.isEmpty) {
      return;
    }

    try {
      final cacheDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid)
          .collection('gmail_cache')
          .doc('recent')
          .get();

      if (cacheDoc.exists) {
        final data = cacheDoc.data();
        if (data != null && data['emails'] != null) {
          final cachedEmails = List<Map<String, dynamic>>.from(
            (data['emails'] as List).map((e) => _convertMap(e as Map)),
          );

          final lastFetched = data['last_fetched'] as Timestamp?;
          final cacheAge = lastFetched != null
              ? DateTime.now().difference(lastFetched.toDate()).inMinutes
              : 999;

          setState(() {
            _emails = cachedEmails;
            _allEmails = cachedEmails;
            _nextPageToken = data['next_page_token']?.toString();
          });

          print(
              '✅ Loaded ${cachedEmails.length} emails from cache (age: ${cacheAge}m)');

          // Continue fetching more emails in background (up to 50 total)
          if (_nextPageToken != null && _emails.length < 50) {
            _loadMoreEmailsInBackground();
          }

          // Note: New email check happens in _checkGmailConnection() when opening Gmail section
        } else {
          // No cache, trigger priority fetch
          _triggerPriorityFetch();
        }
      } else {
        // No cache, trigger priority fetch
        _triggerPriorityFetch();
      }
    } catch (e) {
      print('❌ Error loading from cache: $e');
      // Fallback to direct API call
      _loadEmails(refresh: true);
    }
  }

  /// Trigger priority fetch (top 10 emails)
  Future<void> _triggerPriorityFetch() async {
    try {
      print('📧 Triggering priority fetch...');
      final result = await actions.gmailPrefetchPriority();
      if (result != null && result['success'] == true) {
        print('✅ Priority fetch completed');
        // Cache will be updated via Firestore stream

        // Trigger background loading for remaining emails (up to 50 total)
        final nextPageToken = result['nextPageToken']?.toString();
        if (nextPageToken != null) {
          // Wait a moment for the cache to update via stream, then trigger background loading
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _emails.length < 50) {
              setState(() {
                _nextPageToken = nextPageToken;
              });
              _loadMoreEmailsInBackground();
            }
          });
        }
      }
    } catch (e) {
      print('❌ Error in priority fetch: $e');
    }
  }

  /// Load more emails in background (progressive loading)
  Future<void> _loadMoreEmailsInBackground() async {
    if (_nextPageToken == null || _isLoading) {
      return;
    }

    try {
      print('📧 Loading more emails in background...');
      final result = await actions.gmailPrefetchBatch(
        pageToken: _nextPageToken!,
        maxResults: 20,
      );

      if (result != null && result['success'] == true) {
        final newNextPageToken = result['nextPageToken']?.toString();
        setState(() {
          _nextPageToken = newNextPageToken;
        });
        print('✅ Background batch loaded');

        // Stop after 50 emails total - limit background caching
        if (newNextPageToken != null && _emails.length < 50) {
          Future.delayed(const Duration(seconds: 2), () {
            _loadMoreEmailsInBackground();
          });
        } else if (_emails.length >= 50) {
          print('✅ Reached 50 email limit - stopping background fetch');
        }
      }
    } catch (e) {
      print('❌ Error loading more emails: $e');
    }
  }

  /// Lightweight check for new emails (cost efficient - only top 10)
  Future<void> _checkForNewEmails() async {
    try {
      print('📧 Checking for new emails (lightweight check)...');
      final result = await actions.gmailCheckForNewEmails();
      if (result != null && result['success'] == true) {
        if (result['skipped'] == true) {
          print('✅ No cache exists, skipping check');
        } else if (result['hasNewEmails'] == true) {
          print('✅ Found ${result['newEmailsCount']} new email(s)');
          // Cache will be updated via Firestore stream automatically
        } else {
          print('✅ No new emails found');
        }
      }
    } catch (e) {
      print('❌ Error checking for new emails: $e');
    }
  }

  /// Refresh cache in background (auto-refresh)
  Future<void> _refreshCacheInBackground({bool forceRefresh = false}) async {
    try {
      print('📧 Refreshing Gmail cache in background...');
      final result =
          await actions.gmailRefreshCache(forceRefresh: forceRefresh);
      if (result != null && result['success'] == true) {
        if (result['skipped'] == true) {
          print('✅ Cache is fresh, no refresh needed');
        } else {
          print(
              '✅ Cache refreshed: ${result['newEmails']} new, ${result['updatedEmails']} updated');
        }
        // Cache will be updated via Firestore stream
      }
    } catch (e) {
      print('❌ Error refreshing cache: $e');
    }
  }

  Future<void> _checkGmailConnection() async {
    // CRITICAL: Only proceed if user is authenticated
    // This prevents Gmail OAuth from interfering with Firebase Auth sign-in
    if (currentUser == null || currentUserUid.isEmpty) {
      print('⚠️ Cannot check Gmail connection: User not authenticated');
      return;
    }

    if (currentUserDocument == null) {
      print('⚠️ Cannot check Gmail connection: User document not available');
      return;
    }

    // Check if Gmail is connected by fetching user document
    final userDoc = await currentUserDocument!.reference.get();
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>?;
      final isConnected = userData?['gmail_connected'] == true;

      if (isConnected) {
        // Load from cache first (instant), then check for new emails in background
        _loadEmailsFromCache();
        // Lightweight check for new emails (only top 10, cost efficient)
        _checkForNewEmails();
        // Gmail Watch API temporarily removed
        // _setupGmailWatch();
      }
    }
  }

  // Gmail Watch API functions temporarily removed
  // They can be restored later when Gmail Watch is fixed.
  /*
  /// Set up Gmail Watch API for real-time push notifications
  Future<void> _setupGmailWatch() async {
    try {
      // Check if watch already exists
      final watchDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid)
          .collection('gmail_watch')
          .doc('current')
          .get();

      if (watchDoc.exists) {
        final watchData = watchDoc.data();
        final expiresAt = watchData?['expires_at'] as Timestamp?;

        if (expiresAt != null) {
          final expirationDate = expiresAt.toDate();
          final now = DateTime.now();
          final daysUntilExpiration = expirationDate.difference(now).inDays;

          // Renew if expires within 1 day
          if (daysUntilExpiration <= 1) {
            print('📧 Gmail Watch expires soon, renewing...');
            await actions.gmailRenewWatch();
          } else {
            print(
                '✅ Gmail Watch is active (expires in ${daysUntilExpiration} days)');
            return; // Watch is still valid
          }
        }
      } else {
        // No watch exists, set up new one
        print('📧 Setting up Gmail Watch API...');
        final result = await actions.gmailSetupWatch();
        if (result != null && result['success'] == true) {
          print('✅ Gmail Watch API set up successfully');
        } else {
          print(
              '⚠️ Failed to set up Gmail Watch (non-critical): ${result?['error']}');
        }
      }
    } catch (e) {
      print('⚠️ Error setting up Gmail Watch (non-critical): $e');
      // Non-critical - app will still work with polling
    }
  }

  /// Check and renew Gmail Watch if needed
  Future<void> _checkAndRenewWatch() async {
    try {
      final watchDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid)
          .collection('gmail_watch')
          .doc('current')
          .get();

      if (watchDoc.exists) {
        final watchData = watchDoc.data();
        final expiresAt = watchData?['expires_at'] as Timestamp?;

        if (expiresAt != null) {
          final expirationDate = expiresAt.toDate();
          final now = DateTime.now();
          final daysUntilExpiration = expirationDate.difference(now).inDays;

          // Renew if expires within 1 day
          if (daysUntilExpiration <= 1) {
            print('📧 Gmail Watch expires soon, renewing...');
            await actions.gmailRenewWatch();
          }
        }
      }
    } catch (e) {
      print('⚠️ Error checking Gmail Watch (non-critical): $e');
    }
  }
  */

  Future<void> _loadEmails({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _emails = [];
        _nextPageToken = null;
        // Clear selected email and return to "select an email to view" state
        _selectedEmail = null;
        _selectedEmailId = null;
        _isLoadingEmail = false;
      }
    });

    try {
      final result = await actions.gmailListEmails(
        maxResults: 50,
        pageToken: refresh ? null : _nextPageToken,
      );

      if (result != null && result['success'] == true) {
        // Convert emails list properly
        final emailsList = result['emails'];
        List<Map<String, dynamic>> newEmails = [];

        if (emailsList != null && emailsList is List) {
          for (var email in emailsList) {
            if (email is Map) {
              // Convert Map<Object?, Object?> to Map<String, dynamic> recursively
              newEmails.add(_convertMap(email));
            }
          }
        }

        setState(() {
          if (refresh) {
            _emails = newEmails;
            _allEmails = newEmails;
          } else {
            _emails.addAll(newEmails);
            _allEmails.addAll(newEmails);
          }
          _nextPageToken = result['nextPageToken']?.toString();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        _showError(result?['error'] ?? 'Failed to load emails');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error loading emails: $e');
    }
  }

  Future<void> _loadEmailDetail(String messageId) async {
    if (_isLoadingEmail) return;

    // Close calendar if it's open when email is clicked
    if (_showCalendar) {
      if (!mounted) return;
      setState(() {
        _showCalendar = false;
      });
    }

    // Check in-memory cache first (session only)
    if (_emailBodyCache.containsKey(messageId)) {
      print('✅ Loading email from in-memory cache');
      if (!mounted) return;
      setState(() {
        _selectedEmailId = messageId;
        _selectedEmail = _emailBodyCache[messageId];
        _isLoadingEmail = false;
      });
      return;
    }

    // Clear selected email and set loading state immediately for smooth UI transition
    if (!mounted) return;
    setState(() {
      _selectedEmailId = messageId;
      _selectedEmail = null; // Clear old email to show loading immediately
      _isLoadingEmail = true;
    });

    // Ensure UI frame is rendered before starting async operations
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      // Mark email as read when opened
      final markAsReadResult = await actions.gmailMarkAsRead(messageId);
      if (markAsReadResult != null && markAsReadResult['success'] == true) {
        // Update email's read status in local state without reloading entire list
        if (mounted) {
          setState(() {
            final emailIndex = _emails
                .indexWhere((email) => email['id']?.toString() == messageId);
            if (emailIndex != -1) {
              final labels =
                  List<String>.from(_emails[emailIndex]['labels'] ?? []);
              labels.remove('UNREAD');
              _emails[emailIndex] = {
                ..._emails[emailIndex],
                'labels': labels,
              };
              // Also update _allEmails for search consistency
              final allEmailIndex = _allEmails
                  .indexWhere((email) => email['id']?.toString() == messageId);
              if (allEmailIndex != -1) {
                final allLabels = List<String>.from(
                    _allEmails[allEmailIndex]['labels'] ?? []);
                allLabels.remove('UNREAD');
                _allEmails[allEmailIndex] = {
                  ..._allEmails[allEmailIndex],
                  'labels': allLabels,
                };
              }
            }
          });
        }
        // Cache will be updated by cloud function, but trigger a refresh to sync
        // The Firestore stream listener will pick up the change automatically
      }

      final result = await actions.gmailGetEmail(messageId);

      if (result != null && result['success'] == true) {
        // Convert email map properly with recursive conversion
        final emailData = result['email'];
        Map<String, dynamic>? emailMap;

        if (emailData is Map) {
          emailMap = _convertMap(emailData);
        }

        // Store in in-memory cache (session only)
        if (emailMap != null) {
          _emailBodyCache[messageId] = emailMap;
        }

        if (mounted) {
          setState(() {
            _selectedEmail = emailMap;
            _isLoadingEmail = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingEmail = false;
            // Keep selectedEmailId but clear selectedEmail on error
            _selectedEmail = null;
          });
        }
        _showError(result?['error'] ?? 'Failed to load email');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEmail = false;
          // Keep selectedEmailId but clear selectedEmail on error
          _selectedEmail = null;
        });
      }
      _showError('Error loading email: $e');
    }
  }

  Future<void> _loadCalendarEvents(
      {bool refresh = false, DateTime? forDate}) async {
    if (_isLoadingCalendar) return;

    final targetDate = forDate ?? _selectedCalendarDate;
    // Use local timezone for start/end of day
    final startOfDay = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      0,
      0,
      0,
    );
    final endOfDay = startOfDay
        .add(const Duration(days: 1))
        .subtract(const Duration(seconds: 1));

    // Convert to UTC for API call (Google Calendar API expects UTC)
    final startOfDayUtc = startOfDay.toUtc();
    final endOfDayUtc = endOfDay.toUtc();

    setState(() {
      _isLoadingCalendar = true;
      if (refresh) {
        _calendarEvents = [];
      }
    });

    try {
      final result = await actions.calendarListEvents(
        calendarId: 'primary',
        timeMin: startOfDayUtc.toIso8601String(),
        timeMax: endOfDayUtc.toIso8601String(),
        maxResults: 100,
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

        // Sort events by start time
        newEvents.sort((a, b) {
          final aStart = a['start'];
          final bStart = b['start'];
          if (aStart == null || bStart == null) return 0;

          DateTime? aTime;
          DateTime? bTime;

          if (aStart['dateTime'] != null) {
            try {
              aTime = DateTime.parse(aStart['dateTime']);
            } catch (e) {}
          } else if (aStart['date'] != null) {
            try {
              aTime = DateTime.parse(aStart['date']);
            } catch (e) {}
          }

          if (bStart['dateTime'] != null) {
            try {
              bTime = DateTime.parse(bStart['dateTime']);
            } catch (e) {}
          } else if (bStart['date'] != null) {
            try {
              bTime = DateTime.parse(bStart['date']);
            } catch (e) {}
          }

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return aTime.compareTo(bTime);
        });

        setState(() {
          _calendarEvents = newEvents;
          _isLoadingCalendar = false;
        });
      } else {
        setState(() {
          _isLoadingCalendar = false;
        });
        _showError(result?['error'] ?? 'Failed to load calendar events');
      }
    } catch (e) {
      setState(() {
        _isLoadingCalendar = false;
      });
      _showError('Error loading calendar events: $e');
    }
  }

  List<Map<String, dynamic>> _getEventsForSelectedDate() {
    // Get the selected date in local timezone (start of day)
    final selectedDateLocal = DateTime(
      _selectedCalendarDate.year,
      _selectedCalendarDate.month,
      _selectedCalendarDate.day,
    );

    return _calendarEvents.where((event) {
      final start = event['start'];
      if (start == null) return false;

      DateTime? eventDate;
      if (start['dateTime'] != null) {
        try {
          // Parse and convert to local timezone
          final parsed = DateTime.parse(start['dateTime']);
          eventDate = parsed.toLocal();
        } catch (e) {
          return false;
        }
      } else if (start['date'] != null) {
        try {
          // All-day events - parse and convert to local
          final parsed = DateTime.parse(start['date']);
          eventDate = parsed.toLocal();
        } catch (e) {
          return false;
        }
      } else {
        return false;
      }

      // Compare dates in local timezone
      return eventDate.year == selectedDateLocal.year &&
          eventDate.month == selectedDateLocal.month &&
          eventDate.day == selectedDateLocal.day;
    }).toList();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      // Try to parse RFC 2822 format first (e.g., "Tue, 04 Nov 2025 00:21:59 +0000")
      DateTime? date;

      // Remove common suffixes like "(UTC)" or timezone names
      String cleanedDate =
          dateString.replaceAll(RegExp(r'\s*\([^)]+\)\s*'), '').trim();

      // Try parsing different date formats
      // First check if it's RFC 2822 format with timezone (we need to handle this specially)
      final rfcMatch = RegExp(
        r'(\w+),\s*(\d+)\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s*([\+\-]?\d{4})',
      ).firstMatch(cleanedDate);

      if (rfcMatch != null) {
        // Handle RFC 2822 format with timezone
        final months = {
          'Jan': 1,
          'Feb': 2,
          'Mar': 3,
          'Apr': 4,
          'May': 5,
          'Jun': 6,
          'Jul': 7,
          'Aug': 8,
          'Sep': 9,
          'Oct': 10,
          'Nov': 11,
          'Dec': 12
        };

        final month = months[rfcMatch.group(3)] ?? 1;
        final day = int.parse(rfcMatch.group(2)!);
        final year = int.parse(rfcMatch.group(4)!);
        final hour = int.parse(rfcMatch.group(5)!);
        final minute = int.parse(rfcMatch.group(6)!);
        final second = int.parse(rfcMatch.group(7)!);

        // Parse timezone offset (e.g., "+0000", "-0700")
        // RFC 2822: The timezone offset is FROM UTC
        // "+0000" = UTC, "-0700" = UTC-7 (MST)
        // The time in the email is in the specified timezone
        final tzOffset = rfcMatch.group(8)!;
        final isNegative = tzOffset.startsWith('-');
        final offsetHours = int.parse(tzOffset.substring(1, 3));
        final offsetMinutes = int.parse(tzOffset.substring(3, 5));
        final totalOffsetMinutes =
            (offsetHours * 60 + offsetMinutes) * (isNegative ? -1 : 1);

        // Convert the time in the specified timezone to UTC
        // Example: "19:43:00 +0000" = 19:43 UTC, subtract 0 = 19:43 UTC
        // Example: "12:43:00 -0700" = 12:43 MST, subtract -420 = add 420 minutes = 19:43 UTC
        date = DateTime.utc(year, month, day, hour, minute, second)
            .subtract(Duration(minutes: totalOffsetMinutes));
      } else {
        // Try standard DateTime.parse for other formats
        try {
          date = DateTime.parse(cleanedDate);
          // If parsed successfully but doesn't have timezone info, assume UTC
          if (!cleanedDate.contains('Z') &&
              !cleanedDate.contains('+') &&
              !cleanedDate.contains('-', 1)) {
            date = DateTime.utc(date.year, date.month, date.day, date.hour,
                date.minute, date.second);
          }
        } catch (e) {
          // Try ISO format
          try {
            date = DateTime.parse(cleanedDate.split(' ').take(2).join(' '));
            // If parsed successfully but doesn't have timezone info, assume UTC
            if (!cleanedDate.contains('Z') &&
                !cleanedDate.contains('+') &&
                !cleanedDate.contains('-', 1)) {
              date = DateTime.utc(date.year, date.month, date.day, date.hour,
                  date.minute, date.second);
            }
          } catch (e3) {
            // If all parsing fails, return original
            return dateString.length > 20
                ? dateString.substring(0, 20)
                : dateString;
          }
        }
      }

      final now = DateTime.now();
      final difference = now.difference(date);
      final dateLocal = date.toLocal();

      if (difference.inDays == 0) {
        // Today - show time
        return DateFormat('h:mm a').format(dateLocal);
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        // This week - show day name
        return DateFormat('EEEE').format(dateLocal);
      } else if (difference.inDays < 365) {
        // This year - show month and day
        return DateFormat('MMM d').format(dateLocal);
      } else {
        // Older - show full date
        return DateFormat('MMM d, yyyy').format(dateLocal);
      }
    } catch (e) {
      // If date is too long, truncate it
      if (dateString.length > 20) {
        return '${dateString.substring(0, 20)}...';
      }
      return dateString;
    }
  }

  String _parseEmailAddress(String? from) {
    if (from == null || from.isEmpty) return '';
    try {
      final match = RegExp(r'<(.+)>').firstMatch(from);
      return match != null ? match.group(1)! : from;
    } catch (e) {
      return from;
    }
  }

  String _parseEmailName(String? from) {
    if (from == null || from.isEmpty) return '';
    try {
      final match = RegExp(r'^(.+?)\s*<').firstMatch(from);
      return match != null ? match.group(1)!.trim() : from;
    } catch (e) {
      return from;
    }
  }

  Color _getAvatarColor(String? from) {
    final initial = _getInitials(from);
    if (initial.isEmpty || initial == '?') {
      return const Color(0xFF8E8E93);
    }

    // Generate consistent color based on the first character
    final char = initial[0].toUpperCase();
    final colors = [
      const Color(0xFF007AFF), // Blue
      const Color(0xFF34C759), // Green
      const Color(0xFFFF9500), // Orange
      const Color(0xFFFF3B30), // Red
      const Color(0xFFAF52DE), // Purple
      const Color(0xFFFF2D55), // Pink
      const Color(0xFF5AC8FA), // Light Blue
      const Color(0xFFFFCC00), // Yellow
      const Color(0xFF5856D6), // Indigo
      const Color(0xFFFF9500), // Orange
      const Color(0xFF00C7BE), // Teal
      const Color(0xFFFF6B6B), // Coral
      const Color(0xFF4ECDC4), // Turquoise
      const Color(0xFF45B7D1), // Sky Blue
      const Color(0xFF96CEB4), // Mint
      const Color(0xFFFFEAA7), // Light Yellow
      const Color(0xFFDDA0DD), // Plum
      const Color(0xFF98D8C8), // Aqua
      const Color(0xFFF7DC6F), // Gold
      const Color(0xFFBB8FCE), // Lavender
    ];

    // Use character code to get consistent color
    final index = char.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  String _getInitials(String? from) {
    final name = _parseEmailName(from);
    if (name.isEmpty) {
      final email = _parseEmailAddress(from);
      return email.isNotEmpty ? email[0].toUpperCase() : '?';
    }
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name[0].toUpperCase();
  }

  // Get Inter font with system fallbacks
  String get _interFont {
    return 'Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';
  }

  Widget _buildFilterButton(String filter) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          border: isSelected
              ? Border.all(
                  color: const Color(0xFFDADCE0), // Light grey border
                  width: 1,
                )
              : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          filter,
          style: TextStyle(
            fontFamily: _interFont,
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: isSelected
                ? const Color(0xFF1F1F1F) // Dark grey when selected
                : const Color(0xFF9AA0A6), // Light grey when not selected
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  String _formatFullDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      // Reuse the same parsing logic as _formatDate
      DateTime? date;
      String cleanedDate =
          dateString.replaceAll(RegExp(r'\s*\([^)]+\)\s*'), '').trim();

      // First check if it's RFC 2822 format with timezone (we need to handle this specially)
      final rfcMatch = RegExp(
        r'(\w+),\s*(\d+)\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s*([\+\-]?\d{4})',
      ).firstMatch(cleanedDate);

      if (rfcMatch != null) {
        // Handle RFC 2822 format with timezone
        final months = {
          'Jan': 1,
          'Feb': 2,
          'Mar': 3,
          'Apr': 4,
          'May': 5,
          'Jun': 6,
          'Jul': 7,
          'Aug': 8,
          'Sep': 9,
          'Oct': 10,
          'Nov': 11,
          'Dec': 12
        };

        final month = months[rfcMatch.group(3)] ?? 1;
        final day = int.parse(rfcMatch.group(2)!);
        final year = int.parse(rfcMatch.group(4)!);
        final hour = int.parse(rfcMatch.group(5)!);
        final minute = int.parse(rfcMatch.group(6)!);
        final second = int.parse(rfcMatch.group(7)!);

        // Parse timezone offset (e.g., "+0000", "-0700")
        final tzOffset = rfcMatch.group(8)!;
        final isNegative = tzOffset.startsWith('-');
        final offsetHours = int.parse(tzOffset.substring(1, 3));
        final offsetMinutes = int.parse(tzOffset.substring(3, 5));
        final totalOffsetMinutes =
            (offsetHours * 60 + offsetMinutes) * (isNegative ? -1 : 1);

        // Convert the time in the specified timezone to UTC
        date = DateTime.utc(year, month, day, hour, minute, second)
            .subtract(Duration(minutes: totalOffsetMinutes));
      } else {
        // Try standard DateTime.parse for other formats
        try {
          date = DateTime.parse(cleanedDate);
          // If parsed successfully but doesn't have timezone info, assume UTC
          if (!cleanedDate.contains('Z') &&
              !cleanedDate.contains('+') &&
              !cleanedDate.contains('-', 1)) {
            date = DateTime.utc(date.year, date.month, date.day, date.hour,
                date.minute, date.second);
          }
        } catch (e) {
          // Try ISO format
          try {
            date = DateTime.parse(cleanedDate.split(' ').take(2).join(' '));
            // If parsed successfully but doesn't have timezone info, assume UTC
            if (!cleanedDate.contains('Z') &&
                !cleanedDate.contains('+') &&
                !cleanedDate.contains('-', 1)) {
              date = DateTime.utc(date.year, date.month, date.day, date.hour,
                  date.minute, date.second);
            }
          } catch (e3) {
            return dateString.length > 30
                ? dateString.substring(0, 30)
                : dateString;
          }
        }
      }

      // At this point, date is guaranteed to be non-null
      // (if parsing failed, we would have returned early)
      final dateLocal = date.toLocal();
      return DateFormat('EEEE, MMMM d, yyyy \'at\' h:mm a').format(dateLocal);
    } catch (e) {
      return dateString.length > 30 ? dateString.substring(0, 30) : dateString;
    }
  }

  String _stripHtml(String htmlString) {
    try {
      final document = html_parser.parse(htmlString);
      return document.body?.text ?? htmlString;
    } catch (e) {
      return htmlString;
    }
  }

  // Helper function to recursively convert Map<Object?, Object?> to Map<String, dynamic>
  Map<String, dynamic> _convertMap(Map map) {
    final converted = <String, dynamic>{};
    map.forEach((key, value) {
      final stringKey = key.toString();
      if (value is Map) {
        converted[stringKey] = _convertMap(value);
      } else if (value is List) {
        converted[stringKey] = _convertList(value);
      } else {
        converted[stringKey] = value;
      }
    });
    return converted;
  }

  // Helper function to recursively convert List with nested maps
  List _convertList(List list) {
    return list.map((item) {
      if (item is Map) {
        return _convertMap(item);
      } else if (item is List) {
        return _convertList(item);
      } else {
        return item;
      }
    }).toList();
  }

  // Generate Gmail avatar URL from email
  // Uses Google's profile picture API if available, otherwise falls back to Gravatar
  String _getGmailAvatarUrl(String email) {
    if (email.isEmpty) return '';

    // Try to get stored profile picture URL from Firestore first
    final userData = currentUserDocument;
    if (userData != null) {
      final profilePic =
          (userData.snapshotData['gmail_profile_picture'] as String?);
      if (profilePic != null && profilePic.isNotEmpty) {
        return profilePic;
      }
    }

    // Fallback: Use Google's profile picture URL pattern
    // This uses the email to generate a consistent avatar
    // Note: This won't show the actual Google profile picture, but a consistent placeholder
    // Use a more Google-like avatar placeholder
    // You can also use: https://ui-avatars.com/api/?name=${Uri.encodeComponent(email.split('@')[0])}&background=4285f4&color=fff
    return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(email.split('@')[0])}&background=4285f4&color=fff&size=128';
  }

  // Handle Gmail logout/disconnect
  Future<void> _handleGmailLogout() async {
    // Show confirmation dialog
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.logout_rounded,
                  color: FlutterFlowTheme.of(context).error),
              const SizedBox(width: 12),
              const Text(
                'Disconnect Gmail?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to disconnect your Gmail account? You\'ll need to reconnect to access your emails again.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Disconnect',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: FlutterFlowTheme.of(context).error,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Update user document to remove Gmail connection
      if (currentUserDocument != null) {
        await currentUserDocument!.reference.update({
          'gmail_connected': false,
          'gmail_access_token': FieldValue.delete(),
          'gmail_refresh_token': FieldValue.delete(),
          'gmail_email': FieldValue.delete(),
          'gmail_connected_at': FieldValue.delete(),
        });

        // Clear email state
        setState(() {
          _emails = [];
          _selectedEmail = null;
          _selectedEmailId = null;
          _nextPageToken = null;
        });

        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Gmail disconnected successfully',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to disconnect Gmail. Please try again.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset(
              'assets/images/google.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Text(
              'Gmail',
              style: FlutterFlowTheme.of(context).headlineMedium.override(
                    fontFamily: _interFont,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showCalendar = !_showCalendar;
                  // Clear selected email when showing calendar
                  if (_showCalendar) {
                    _selectedEmail = null;
                    _selectedEmailId = null;
                    _selectedCalendarDate = DateTime.now(); // Reset to today
                    // Load calendar events when showing calendar
                    _loadCalendarEvents(refresh: true, forDate: DateTime.now());
                  }
                });
              },
              icon: Image.asset(
                'assets/images/google-calendar.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
              label: Text(
                'Calendar',
                style: TextStyle(
                  fontFamily: _interFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1F1F1F),
                ),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF1F1F1F), // Dark grey
            ),
            onPressed: () => _loadEmails(refresh: true),
            tooltip: 'Refresh inbox',
          ),
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: Color(0xFF1F1F1F), // Dark grey
            ),
            onPressed: () => _showComposeDialog(),
            tooltip: 'Compose new email',
          ),
          // Gmail user avatar and logout
          StreamBuilder<UsersRecord>(
            stream: currentUserDocument != null
                ? UsersRecord.getDocument(currentUserDocument!.reference)
                : Stream<UsersRecord>.value(UsersRecord.getDocumentFromData(
                    {},
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc('dummy'))),
            builder: (context, snapshot) {
              final userData = snapshot.data;
              // Get Gmail email from snapshot data
              final userGmailEmail =
                  (userData?.snapshotData['gmail_email'] as String?) ?? '';
              final userGmailAvatarUrl = userGmailEmail.isNotEmpty
                  ? _getGmailAvatarUrl(userGmailEmail)
                  : '';

              if (userGmailEmail.isEmpty) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PopupMenuButton<String>(
                  offset: const Offset(0, 50),
                  color: const Color(0xFFF5F5F7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: FlutterFlowTheme.of(context).primary,
                          backgroundImage: userGmailAvatarUrl.isNotEmpty
                              ? NetworkImage(userGmailAvatarUrl)
                              : null,
                          child: userGmailAvatarUrl.isEmpty
                              ? Text(
                                  userGmailEmail.isNotEmpty
                                      ? userGmailEmail[0].toUpperCase()
                                      : 'G',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 20,
                          color: Color(0xFF9CA3AF),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor:
                                    FlutterFlowTheme.of(context).primary,
                                backgroundImage: userGmailAvatarUrl.isNotEmpty
                                    ? NetworkImage(userGmailAvatarUrl)
                                    : null,
                                child: userGmailAvatarUrl.isEmpty
                                    ? Text(
                                        userGmailEmail.isNotEmpty
                                            ? userGmailEmail[0].toUpperCase()
                                            : 'G',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Gmail Account',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      userGmailEmail,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            size: 20,
                            color: FlutterFlowTheme.of(context).error,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Disconnect Gmail',
                            style: TextStyle(
                              fontSize: 14,
                              color: FlutterFlowTheme.of(context).error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (String value) {
                    if (value == 'logout') {
                      _handleGmailLogout();
                    }
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<UsersRecord>(
        stream: currentUserDocument != null
            ? UsersRecord.getDocument(currentUserDocument!.reference)
            : Stream<UsersRecord>.value(UsersRecord.getDocumentFromData({},
                FirebaseFirestore.instance.collection('users').doc('dummy'))),
        builder: (context, snapshot) {
          if (!snapshot.hasData || currentUserDocument == null) {
            return _buildNotConnectedState();
          }

          final userData = snapshot.data!;
          // Check Gmail connection from raw data
          final gmailConnected =
              (userData.snapshotData['gmail_connected'] as bool?) ?? false;

          if (!gmailConnected) {
            return _buildNotConnectedState();
          }

          return _buildEmailList();
        },
      ),
    );
  }

  Widget _buildNotConnectedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/google.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 32),
            Text(
              'Gmail Not Connected',
              style: FlutterFlowTheme.of(context).headlineMedium.override(
                    fontFamily: _interFont,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Connect your Gmail account to access and manage your emails directly from Lona',
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: _interFont,
                    fontSize: 16,
                    color: FlutterFlowTheme.of(context).secondaryText,
                    letterSpacing: 0,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () async {
                final success = await actions.gmailOAuthConnect(context);
                if (success && mounted) {
                  setState(() {});
                  _loadEmails();
                }
              },
              icon: const Icon(Icons.email_outlined, size: 20),
              label: const Text(
                'Connect Gmail',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailList() {
    if (_emails.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: FlutterFlowTheme.of(context).secondaryText,
            ),
            const SizedBox(height: 24),
            Text(
              'Your inbox is empty',
              style: FlutterFlowTheme.of(context).headlineSmall.override(
                    fontFamily: _interFont,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: FlutterFlowTheme.of(context).primaryText,
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'New emails will appear here',
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: _interFont,
                    fontSize: 14,
                    color: FlutterFlowTheme.of(context).secondaryText,
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _loadEmails(refresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Refresh',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Email List
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).primaryBackground,
              border: Border(
                right: BorderSide(
                  color: FlutterFlowTheme.of(context).alternate,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Search bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        // Trigger rebuild to filter emails
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search emails...',
                      hintStyle: TextStyle(
                        color: const Color(0xFF9AA0A6), // Light grey
                        fontSize: 14,
                        fontFamily: _interFont,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF9AA0A6), // Light grey
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: Color(0xFF9AA0A6),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                });
                              },
                              tooltip: 'Clear search',
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFFDADCE0), // Light grey border
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFFDADCE0), // Light grey border
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFFDADCE0), // Light grey border
                          width: 1,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: TextStyle(
                      color: const Color(0xFF1F1F1F), // Dark grey
                      fontSize: 14,
                      fontFamily: _interFont,
                    ),
                  ),
                ),
                // Filter buttons
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.white,
                  child: Row(
                    children: [
                      _buildFilterButton('All'),
                      const SizedBox(width: 16),
                      _buildFilterButton('Unread'),
                      const SizedBox(width: 16),
                      _buildFilterButton('Read'),
                    ],
                  ),
                ),
                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFE8EAED)),
                // Email list
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final filteredEmails = _getFilteredEmails();
                      final hasSearchQuery = _searchController.text.isNotEmpty;

                      if (_isLoading && _emails.isEmpty) {
                        return _buildLoadingExperience();
                      }

                      if (hasSearchQuery && filteredEmails.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 64,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No emails found',
                                style: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      fontFamily: _interFont,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      letterSpacing: 0,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your search terms',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: _interFont,
                                      fontSize: 14,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      letterSpacing: 0,
                                    ),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () => _loadEmails(refresh: true),
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: filteredEmails.length +
                              (_isLoading && !hasSearchQuery ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == filteredEmails.length &&
                                !hasSearchQuery) {
                              // Load more indicator (only show when not searching)
                              if (_nextPageToken != null) {
                                _loadEmails();
                              }
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      FlutterFlowTheme.of(context).primary,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final email = filteredEmails[index];
                            final emailId = email['id']?.toString() ?? '';
                            final isSelected = _selectedEmailId == emailId;
                            final isStarred = _isStarred(email);
                            final isUnread = _isUnread(email);
                            final hasAttachment =
                                email['attachments'] != null &&
                                    (email['attachments'] as List).isNotEmpty;

                            return InkWell(
                              onTap: () {
                                _loadEmailDetail(emailId);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(
                                          0xFFF8F9FA) // Light grey background when selected
                                      : isUnread
                                          ? const Color(
                                              0xFFFAFAFA) // Very light grey for unread
                                          : Colors.white,
                                  border: const Border(
                                    bottom: BorderSide(
                                      color: Color(
                                          0xFFE8EAED), // Light grey divider
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Unread indicator dot
                                    if (isUnread)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(
                                            right: 8, top: 6),
                                        decoration: const BoxDecoration(
                                          color: Color(
                                              0xFF1F1F1F), // Dark grey dot for unread (no blue)
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    else
                                      const SizedBox(width: 8),
                                    // Avatar
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor:
                                          _getAvatarColor(email['from']),
                                      child: Text(
                                        _getInitials(email['from']),
                                        style: TextStyle(
                                          color: Colors
                                              .white, // White text on colored background
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                          fontFamily: _interFont,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Email content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    // Sender name
                                                    Text(
                                                      _parseEmailName(
                                                          email['from']),
                                                      style: TextStyle(
                                                        fontFamily: _interFont,
                                                        fontSize: 14,
                                                        fontWeight: isUnread
                                                            ? FontWeight
                                                                .w600 // Medium weight for unread
                                                            : FontWeight
                                                                .w500, // Lighter for read
                                                        color: isUnread
                                                            ? const Color(
                                                                0xFF1F1F1F) // Dark grey for unread
                                                            : const Color(
                                                                0xFF5F6368), // Lighter grey for read
                                                        letterSpacing: 0,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    // Subject
                                                    Text(
                                                      email['subject'] ??
                                                          '(No Subject)',
                                                      style: TextStyle(
                                                        fontFamily: _interFont,
                                                        fontSize: 14,
                                                        fontWeight: isUnread
                                                            ? FontWeight
                                                                .w600 // Medium weight for unread
                                                            : FontWeight
                                                                .w500, // Lighter for read
                                                        color: isUnread
                                                            ? const Color(
                                                                0xFF1F1F1F) // Dark grey for unread
                                                            : const Color(
                                                                0xFF5F6368), // Lighter grey for read
                                                        letterSpacing: 0,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    // Preview text with attachment icon
                                                    Row(
                                                      children: [
                                                        if (hasAttachment) ...[
                                                          const Icon(
                                                            Icons.attach_file,
                                                            size: 14,
                                                            color: Color(
                                                                0xFF9AA0A6), // Light grey
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                        ],
                                                        Expanded(
                                                          child: Text(
                                                            email['snippet'] ??
                                                                '',
                                                            style:
                                                                const TextStyle(
                                                              fontFamily:
                                                                  'Inter',
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .normal,
                                                              color: Color(
                                                                  0xFF5F6368), // Lighter grey
                                                              letterSpacing: 0,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Timestamp and Star
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    _formatRelativeDate(
                                                        email['date']),
                                                    style: TextStyle(
                                                      fontFamily: _interFont,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      color: const Color(
                                                          0xFF5F6368), // Lighter grey
                                                      letterSpacing: 0,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  GestureDetector(
                                                    onTap: () {
                                                      // TODO: Implement star toggle via Gmail API
                                                      // For now, just refresh to get updated labels
                                                      _loadEmails(
                                                          refresh: true);
                                                    },
                                                    child: Icon(
                                                      isStarred
                                                          ? Icons.star_rounded
                                                          : Icons
                                                              .star_border_rounded,
                                                      size: 20,
                                                      color: isStarred
                                                          ? const Color(
                                                              0xFFF4B400) // Yellow (no blue)
                                                          : const Color(
                                                              0xFF9AA0A6), // Light grey
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // Email Detail or Calendar
        Expanded(
          flex: 3,
          child: _showCalendar
              ? _buildCalendarView()
              : ((_selectedEmail != null || _isLoadingEmail)
                  ? _buildEmailDetail()
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 80,
                            color: FlutterFlowTheme.of(context).secondaryText,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Select an email to view',
                            style: FlutterFlowTheme.of(context)
                                .titleMedium
                                .override(
                                  fontFamily: _interFont,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  letterSpacing: 0,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Click on any email from the list to read its content',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: _interFont,
                                  fontSize: 14,
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                  letterSpacing: 0,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )),
        ),
      ],
    );
  }

  Widget _buildEmailDetail() {
    if (_isLoadingEmail) {
      return _buildEmailContentLoading();
    }

    final email = _selectedEmail!;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Email Header Section - Matching Design
          _buildEmailHeader(email),
          const SizedBox(height: 24),
          // Email Content Section - Matching Design
          Expanded(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 0,
                ),
                child: _buildEmailContent(email),
              ),
            ),
          ),
          // Reply and Forward buttons at bottom left
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                _buildActionButton(
                  icon: Icons.arrow_back_rounded,
                  label: 'Reply',
                  onPressed: () {
                    _showReplyDialog(email);
                  },
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.arrow_forward_rounded,
                  label: 'Forward',
                  onPressed: () {
                    _showForwardDialog(email);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView() {
    final isToday = _selectedCalendarDate.year == DateTime.now().year &&
        _selectedCalendarDate.month == DateTime.now().month &&
        _selectedCalendarDate.day == DateTime.now().day;

    final dateStr = isToday
        ? 'Today'
        : DateFormat('EEEE, MMMM d, yyyy').format(_selectedCalendarDate);

    final dayEvents = _getEventsForSelectedDate();

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Navigation Header - Matching Gmail style
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFE8EAED),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    color: Color(0xFF1F1F1F),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedCalendarDate = _selectedCalendarDate
                          .subtract(const Duration(days: 1));
                    });
                    _loadCalendarEvents(
                        refresh: true, forDate: _selectedCalendarDate);
                  },
                  tooltip: 'Previous day',
                ),
                Expanded(
                  child: Text(
                    dateStr,
                    style: FlutterFlowTheme.of(context).titleMedium.override(
                          fontFamily: _interFont,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF1F1F1F),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedCalendarDate =
                          _selectedCalendarDate.add(const Duration(days: 1));
                    });
                    _loadCalendarEvents(
                        refresh: true, forDate: _selectedCalendarDate);
                  },
                  tooltip: 'Next day',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF1F1F1F),
                  ),
                  onPressed: () => _loadCalendarEvents(
                      refresh: true, forDate: _selectedCalendarDate),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          // Calendar Events List
          Expanded(
            child: _isLoadingCalendar
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Loading events...',
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                fontFamily: _interFont,
                                fontSize: 14,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                        ),
                      ],
                    ),
                  )
                : dayEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_available_rounded,
                              size: 64,
                              color: FlutterFlowTheme.of(context).secondaryText,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No events',
                              style: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .override(
                                    fontFamily: _interFont,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You have no events scheduled for this day.',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: _interFont,
                                    fontSize: 14,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadCalendarEvents(
                            refresh: true, forDate: _selectedCalendarDate),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: dayEvents.length,
                          itemBuilder: (context, index) {
                            final event = dayEvents[index];
                            return _buildCalendarEventItem(event);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarEventItem(Map<String, dynamic> event) {
    final summary = event['summary'] ?? '(No Title)';
    final description = event['description'] ?? '';
    final location = event['location'] ?? '';
    final start = event['start'];
    final end = event['end'];
    final htmlLink = event['htmlLink'] ?? '';
    final hangoutLink = event['hangoutLink'] ?? '';
    final conferenceData = event['conferenceData'];

    // Extract meeting link from hangoutLink or conferenceData
    String? meetingLink;
    if (hangoutLink.isNotEmpty) {
      meetingLink = hangoutLink;
    } else if (conferenceData != null) {
      final entryPoints = conferenceData['entryPoints'];
      if (entryPoints != null &&
          entryPoints is List &&
          entryPoints.isNotEmpty) {
        for (var entry in entryPoints) {
          if (entry['entryPointType'] == 'video' && entry['uri'] != null) {
            meetingLink = entry['uri'];
            break;
          }
        }
      }
    }

    // Parse times with timezone conversion
    DateTime? startTime;
    DateTime? endTime;
    bool isAllDay = false;

    if (start != null) {
      if (start['dateTime'] != null) {
        try {
          // Parse the ISO 8601 string (may include timezone)
          final parsed = DateTime.parse(start['dateTime']);
          // Convert to local timezone
          startTime = parsed.toLocal();
        } catch (e) {
          print('Error parsing start dateTime: $e');
        }
      } else if (start['date'] != null) {
        try {
          // All-day events use date only (no time)
          final parsed = DateTime.parse(start['date']);
          startTime = parsed.toLocal();
          isAllDay = true;
        } catch (e) {
          print('Error parsing start date: $e');
        }
      }
    }

    if (end != null) {
      if (end['dateTime'] != null) {
        try {
          // Parse the ISO 8601 string (may include timezone)
          final parsed = DateTime.parse(end['dateTime']);
          // Convert to local timezone
          endTime = parsed.toLocal();
        } catch (e) {
          print('Error parsing end dateTime: $e');
        }
      } else if (end['date'] != null) {
        try {
          // All-day events use date only (no time)
          final parsed = DateTime.parse(end['date']);
          endTime = parsed.toLocal();
        } catch (e) {
          print('Error parsing end date: $e');
        }
      }
    }

    String timeStr = '';
    if (isAllDay) {
      timeStr = 'All day';
    } else if (startTime != null) {
      // Format in local timezone (DateFormat automatically uses local timezone)
      timeStr = DateFormat('h:mm a').format(startTime);
      if (endTime != null) {
        timeStr += ' - ${DateFormat('h:mm a').format(endTime)}';
      }
    }

    return InkWell(
      onTap: htmlLink.isNotEmpty
          ? () async {
              final uri = Uri.parse(htmlLink);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFE8EAED),
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time column - matching Gmail style
            Container(
              width: 80,
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                timeStr,
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      fontFamily: _interFont,
                      fontSize: 13,
                      color: FlutterFlowTheme.of(context).secondaryText,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            const SizedBox(width: 16),
            // Event content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary,
                    style: FlutterFlowTheme.of(context).bodyLarge.override(
                          fontFamily: _interFont,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                  ),
                  if (meetingLink != null && meetingLink.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final uri = Uri.parse(meetingLink!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Row(
                        children: [
                          const Icon(
                            Icons.videocam_rounded,
                            size: 14,
                            color: Color(0xFF1A73E8),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Join with Google Meet',
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    fontFamily: _interFont,
                                    fontSize: 13,
                                    color: const Color(0xFF1A73E8),
                                    fontWeight: FontWeight.w500,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style:
                                FlutterFlowTheme.of(context).bodySmall.override(
                                      fontFamily: _interFont,
                                      fontSize: 13,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description.length > 100
                          ? '${description.substring(0, 100)}...'
                          : description,
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            fontFamily: _interFont,
                            fontSize: 13,
                            color: FlutterFlowTheme.of(context).secondaryText,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarEventCard(Map<String, dynamic> event) {
    final summary = event['summary'] ?? '(No Title)';
    final description = event['description'] ?? '';
    final location = event['location'] ?? '';
    final start = event['start'];
    final end = event['end'];
    final htmlLink = event['htmlLink'] ?? '';

    // Parse start and end times
    String startTime = '';
    String endTime = '';
    String dateStr = '';

    if (start != null) {
      if (start['dateTime'] != null) {
        try {
          final startDate = DateTime.parse(start['dateTime']);
          dateStr = DateFormat('MMM d, yyyy').format(startDate);
          startTime = DateFormat('h:mm a').format(startDate);
        } catch (e) {
          startTime = 'All day';
        }
      } else if (start['date'] != null) {
        try {
          final startDate = DateTime.parse(start['date']);
          dateStr = DateFormat('MMM d, yyyy').format(startDate);
          startTime = 'All day';
        } catch (e) {
          dateStr = 'Date TBD';
        }
      }
    }

    if (end != null && end['dateTime'] != null) {
      try {
        final endDate = DateTime.parse(end['dateTime']);
        endTime = DateFormat('h:mm a').format(endDate);
      } catch (e) {
        // Ignore
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(
          color: Color(0xFFE8EAED),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: htmlLink.isNotEmpty
            ? () async {
                final uri = Uri.parse(htmlLink);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary,
                          style: FlutterFlowTheme.of(context)
                              .titleMedium
                              .override(
                                fontFamily: _interFont,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: FlutterFlowTheme.of(context).primaryText,
                              ),
                        ),
                        if (dateStr.isNotEmpty || startTime.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                dateStr.isNotEmpty
                                    ? '$dateStr${startTime != 'All day' ? ' • $startTime' : ''}${endTime.isNotEmpty ? ' - $endTime' : ''}'
                                    : startTime,
                                style: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .override(
                                      fontFamily: _interFont,
                                      fontSize: 13,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                    ),
                              ),
                            ],
                          ),
                        ],
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 16,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  location,
                                  style: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .override(
                                        fontFamily: _interFont,
                                        fontSize: 13,
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description.length > 150
                                ? '${description.substring(0, 150)}...'
                                : description,
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: _interFont,
                                  fontSize: 13,
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
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

  Widget _buildEmailHeader(Map<String, dynamic> email) {
    final senderName = _parseEmailName(email['from']);
    final senderEmail = _parseEmailAddress(email['from']);
    final senderInitials = senderName.isNotEmpty
        ? senderName.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
        : senderEmail.isNotEmpty
            ? senderEmail[0].toUpperCase()
            : '?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subject and Action Buttons Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject Line
                  Text(
                    email['subject'] ?? '(No Subject)',
                    style: TextStyle(
                      fontFamily: _interFont,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F1F1F), // Dark grey
                      letterSpacing: 0,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            // Star and Menu Icons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(
                  builder: (context) {
                    final isStarred = _isStarred(email);
                    return IconButton(
                      icon: Icon(
                        isStarred
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: isStarred
                            ? const Color(0xFFF4B400) // Yellow when starred
                            : const Color(
                                0xFF5F6368), // Dark grey when not starred
                      ),
                      onPressed: () {
                        // TODO: Implement star toggle via Gmail API
                        // For now, just refresh to get updated labels
                        _loadEmails(refresh: true);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Color(0xFF5F6368), // Dark grey
                  ),
                  onPressed: () {
                    // TODO: Implement menu
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Sender Information Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: _getAvatarColor(_selectedEmail?['from']),
              child: Text(
                senderInitials,
                style: TextStyle(
                  color: Colors.white, // White text on colored background
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: _interFont,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Sender Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senderName,
                    style: TextStyle(
                      fontFamily: _interFont,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F1F1F), // Dark grey
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    senderEmail,
                    style: TextStyle(
                      fontFamily: _interFont,
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                      color: const Color(0xFF5F6368), // Lighter grey
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // To and CC
                  if (email['to'] != null && email['to'].toString().isNotEmpty)
                    Text(
                      'To: ${email['to']}',
                      style: TextStyle(
                        fontFamily: _interFont,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: const Color(0xFF5F6368), // Lighter grey
                        letterSpacing: 0,
                      ),
                    ),
                  if (email['cc'] != null &&
                      email['cc'].toString().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'CC: ${email['cc']}',
                      style: TextStyle(
                        fontFamily: _interFont,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: const Color(0xFF5F6368), // Lighter grey
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Timestamp
            Text(
              _formatRelativeDate(email['date']),
              style: TextStyle(
                fontFamily: _interFont,
                fontSize: 15,
                fontWeight: FontWeight.normal,
                color: const Color(0xFF5F6368), // Lighter grey
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        // Separator line
        const SizedBox(height: 16),
        const Divider(
          height: 1,
          thickness: 2,
          color: Color(0xFF000000), // Black
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isWider = false,
  }) {
    return Material(
      color: const Color(0xFFF1F3F4), // Light grey background
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isWider ? 14 : 12,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: const Color(0xFF1F1F1F), // Dark grey
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: _interFont,
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: const Color(0xFF1F1F1F), // Dark grey
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailContent(Map<String, dynamic> email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Email Body - Clean white background
        _buildEmailBody(email),
        const SizedBox(height: 24),
        // Attachments
        if (email['attachments'] != null &&
            (email['attachments'] as List).isNotEmpty)
          _buildAttachmentsSection(email),
      ],
    );
  }

  String _formatRelativeDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      DateTime? date;
      String cleanedDate =
          dateString.replaceAll(RegExp(r'\s*\([^)]+\)\s*'), '').trim();

      final rfcMatch = RegExp(
        r'(\w+),\s*(\d+)\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s*([\+\-]?\d{4})',
      ).firstMatch(cleanedDate);

      if (rfcMatch != null) {
        final months = {
          'Jan': 1,
          'Feb': 2,
          'Mar': 3,
          'Apr': 4,
          'May': 5,
          'Jun': 6,
          'Jul': 7,
          'Aug': 8,
          'Sep': 9,
          'Oct': 10,
          'Nov': 11,
          'Dec': 12
        };

        final month = months[rfcMatch.group(3)] ?? 1;
        final day = int.parse(rfcMatch.group(2)!);
        final year = int.parse(rfcMatch.group(4)!);
        final hour = int.parse(rfcMatch.group(5)!);
        final minute = int.parse(rfcMatch.group(6)!);
        final second = int.parse(rfcMatch.group(7)!);

        final tzOffset = rfcMatch.group(8)!;
        final isNegative = tzOffset.startsWith('-');
        final offsetHours = int.parse(tzOffset.substring(1, 3));
        final offsetMinutes = int.parse(tzOffset.substring(3, 5));
        final totalOffsetMinutes =
            (offsetHours * 60 + offsetMinutes) * (isNegative ? -1 : 1);

        date = DateTime.utc(year, month, day, hour, minute, second)
            .subtract(Duration(minutes: totalOffsetMinutes));
      } else {
        try {
          date = DateTime.parse(cleanedDate);
          if (!cleanedDate.contains('Z') &&
              !cleanedDate.contains('+') &&
              !cleanedDate.contains('-', 1)) {
            date = DateTime.utc(date.year, date.month, date.day, date.hour,
                date.minute, date.second);
          }
        } catch (e) {
          return dateString.length > 20
              ? dateString.substring(0, 20)
              : dateString;
        }
      }

      final now = DateTime.now();
      final difference = now.difference(date);
      final dateLocal = date.toLocal();

      if (difference.inMinutes < 1) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        return 'about ${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      } else if (difference.inHours < 24) {
        return 'about ${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inDays == 1) {
        return '1 day ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 365) {
        return DateFormat('MMM d').format(dateLocal);
      } else {
        return DateFormat('MMM d, yyyy').format(dateLocal);
      }
    } catch (e) {
      return dateString.length > 20 ? dateString.substring(0, 20) : dateString;
    }
  }

  Widget _buildEmailBody(Map<String, dynamic> email) {
    final body = email['body']?.toString() ?? '';
    final snippet = email['snippet']?.toString() ?? '';

    if (body.isEmpty && snippet.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No content available',
          style: TextStyle(
            fontFamily: _interFont,
            fontSize: 14,
            color: FlutterFlowTheme.of(context).secondaryText,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // Check if body contains HTML - improved detection
    final isHtml = body.trim().isNotEmpty &&
        body.contains('<') &&
        (body.contains('<html') ||
            body.contains('<div') ||
            body.contains('<p') ||
            body.contains('<br') ||
            body.contains('<span') ||
            body.contains('<a ') ||
            body.contains('<img') ||
            body.contains('<table') ||
            body.contains('<style') ||
            body.contains('</'));

    // Use WebView for HTML emails to display rich content
    if (isHtml && body.isNotEmpty) {
      return _buildHtmlEmailWebView(body);
    } else if (body.isNotEmpty) {
      // Plain text email - keep as is
      return SelectableText(
        body,
        style: TextStyle(
          fontFamily: _interFont,
          fontSize: 14,
          height: 1.6,
          color: const Color(0xFF1F1F1F), // Dark grey
          letterSpacing: 0,
          fontWeight: FontWeight.normal,
        ),
      );
    } else {
      // Fallback to snippet
      return SelectableText(
        snippet,
        style: TextStyle(
          fontFamily: _interFont,
          fontSize: 14,
          height: 1.6,
          color: const Color(0xFF1F1F1F), // Dark grey
          letterSpacing: 0,
          fontWeight: FontWeight.normal,
        ),
      );
    }
  }

  Widget _buildHtmlEmailWebView(String htmlContent) {
    // Use flutter_widget_from_html for professional HTML rendering
    // Wrap in LayoutBuilder to get proper constraints and prevent NaN errors
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ensure we have valid constraints
        final screenWidth = MediaQuery.of(context).size.width;
        final maxWidth = constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0 &&
                !constraints.maxWidth.isInfinite
            ? constraints.maxWidth - 32 // Account for padding
            : screenWidth - 80; // Fallback with safe margin

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth > 0 && maxWidth.isFinite ? maxWidth : 600,
              minWidth: 0,
            ),
            child: HtmlWidget(
              htmlContent,
              // Use base text style but let HTML override it
              textStyle: TextStyle(
                fontFamily: _interFont,
                fontSize: 14,
                height: 1.6,
                color: const Color(0xFF1F1F1F),
              ),
              onTapUrl: (url) async {
                if (url.startsWith('http://') ||
                    url.startsWith('https://') ||
                    url.startsWith('mailto:')) {
                  await launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                  return true;
                }
                return false;
              },
              // Minimal custom styles - only for images to ensure responsiveness
              // Don't override other styles to preserve email's original formatting
              customStylesBuilder: (element) {
                // Only style images for responsiveness
                if (element.localName == 'img') {
                  return {
                    'max-width': '100%',
                    'height': 'auto',
                  };
                }
                // Return null for everything else to preserve original inline styles
                return null;
              },
              // Enable text selection
              enableCaching: true,
              // Handle images asynchronously
              buildAsync: true,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentsSection(Map<String, dynamic> email) {
    final attachmentsRaw = email['attachments'];
    if (attachmentsRaw == null) {
      return const SizedBox.shrink();
    }

    // Convert attachments list properly
    List attachments;
    if (attachmentsRaw is List) {
      attachments = attachmentsRaw.map((item) {
        if (item is Map) {
          return _convertMap(item);
        }
        return item;
      }).toList();
    } else {
      attachments = [];
    }

    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    final messageId = email['id']?.toString() ?? '';

    // Display attachment cards
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${attachments.length} ${attachments.length == 1 ? 'Attachment' : 'Attachments'}',
            style: TextStyle(
              fontFamily: _interFont,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1F1F1F), // Dark grey
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          ...attachments.map((attachment) {
            if (attachment is Map) {
              return _buildAttachmentCard(
                  Map<String, dynamic>.from(attachment), messageId);
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _buildAttachmentCard(
      Map<String, dynamic> attachment, String messageId) {
    final filename = attachment['filename']?.toString() ?? 'Unknown';
    final mimeType = attachment['mimeType']?.toString() ?? '';
    // Safely convert size to int
    final sizeRaw = attachment['size'];
    final size = sizeRaw is int
        ? sizeRaw
        : (sizeRaw is num
            ? sizeRaw.toInt()
            : (sizeRaw != null ? int.tryParse(sizeRaw.toString()) ?? 0 : 0));
    final attachmentId = attachment['attachmentId']?.toString();

    final isPdf = mimeType.toLowerCase().contains('pdf') ||
        filename.toLowerCase().endsWith('.pdf');

    IconData fileIcon;
    Color iconColor;

    if (isPdf) {
      fileIcon = Icons.picture_as_pdf_rounded;
      iconColor = Colors.red;
    } else if (mimeType.startsWith('image/')) {
      fileIcon = Icons.image_rounded;
      iconColor = const Color(0xFF5F6368); // Dark grey (no blue)
    } else if (mimeType.startsWith('video/')) {
      fileIcon = Icons.video_file_rounded;
      iconColor = Colors.purple;
    } else {
      fileIcon = Icons.insert_drive_file_rounded;
      iconColor = FlutterFlowTheme.of(context).primary;
    }

    String sizeText = '';
    if (size > 0) {
      if (size < 1024) {
        sizeText = '$size B';
      } else if (size < 1024 * 1024) {
        sizeText = '${(size / 1024).toStringAsFixed(1)} KB';
      } else {
        sizeText = '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              fileIcon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: _interFont,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: FlutterFlowTheme.of(context).primaryText,
                        letterSpacing: 0,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sizeText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    sizeText,
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          fontFamily: _interFont,
                          fontSize: 12,
                          color: FlutterFlowTheme.of(context).secondaryText,
                          letterSpacing: 0,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (attachmentId != null && attachmentId.isNotEmpty) ...[
            if (isPdf)
              IconButton(
                icon: const Icon(Icons.preview_rounded),
                onPressed: () => _previewPdf(messageId, attachmentId, filename),
                tooltip: 'Preview PDF',
                color: FlutterFlowTheme.of(context).primary,
              ),
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: () => _downloadAttachment(
                messageId,
                attachmentId,
                filename,
                mimeType,
              ),
              tooltip: 'Download',
              color: FlutterFlowTheme.of(context).primary,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _downloadAttachment(
    String messageId,
    String attachmentId,
    String filename,
    String mimeType,
  ) async {
    try {
      // Show loading with nice animation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _DocumentLoadingDialog(
          message: 'Downloading $filename...',
        ),
      );

      final result = await actions.gmailDownloadAttachment(
        messageId,
        attachmentId,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      if (result != null && result['success'] == true) {
        final data = result['data'] as String;
        final bytes = base64Decode(data);

        // Get directory
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$filename');

        // Write file
        await file.writeAsBytes(bytes);

        // Open file
        final openResult = await OpenFilex.open(file.path);

        if (mounted) {
          if (openResult.type != ResultType.done) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File saved to: ${file.path}'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          _showError(result?['error'] ?? 'Failed to download attachment');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if still open
        _showError('Error downloading attachment: $e');
      }
    }
  }

  Future<void> _previewPdf(
    String messageId,
    String attachmentId,
    String filename,
  ) async {
    try {
      // Show loading with nice animation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _DocumentLoadingDialog(
          message: 'Loading PDF preview...',
        ),
      );

      final result = await actions.gmailDownloadAttachment(
        messageId,
        attachmentId,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      if (result != null && result['success'] == true) {
        final data = result['data'] as String;
        final bytes = base64Decode(data);

        // Get directory
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$filename');

        // Write file
        await file.writeAsBytes(bytes);

        // Show PDF preview
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.9,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: FlutterFlowTheme.of(context).alternate,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              filename,
                              style: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .override(
                                    fontFamily: _interFont,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    // PDF Viewer
                    Expanded(
                      child: FutureBuilder<PdfDocument>(
                        future: PdfDocument.openFile(file.path),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError || !snapshot.hasData) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline,
                                      size: 48, color: Colors.red),
                                  SizedBox(height: 16),
                                  Text('Failed to load PDF'),
                                ],
                              ),
                            );
                          }
                          return PdfViewPinch(
                            controller: PdfControllerPinch(
                              document: PdfDocument.openFile(file.path),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          _showError(result?['error'] ?? 'Failed to load PDF');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if still open
        _showError('Error previewing PDF: $e');
      }
    }
  }

  void _showComposeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ComposeEmailDialog(
        onSend: (to, cc, subject, body, attachments) async {
          Navigator.pop(dialogContext);
          await _sendEmail(to, cc, subject, body, attachments);
        },
        onDiscard: () {
          Navigator.pop(dialogContext);
        },
      ),
    );
  }

  void _showReplyDialog(Map<String, dynamic> email) {
    // Extract sender email address
    final senderEmail = _parseEmailAddress(email['from']);
    final originalSubject = email['subject']?.toString() ?? '(No Subject)';
    final messageId = email['id']?.toString() ?? '';

    if (messageId.isEmpty) {
      _showError('Cannot reply: Email ID is missing');
      return;
    }

    // Add "Re: " prefix if not already present
    final replySubject = originalSubject.startsWith('Re: ')
        ? originalSubject
        : 'Re: $originalSubject';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ComposeEmailDialog(
        initialTo: senderEmail,
        initialSubject: replySubject,
        onSend: (to, cc, subject, body, attachments) async {
          Navigator.pop(dialogContext);
          await _replyToEmail(messageId, body, attachments);
        },
        onDiscard: () {
          Navigator.pop(dialogContext);
        },
      ),
    );
  }

  void _showForwardDialog(Map<String, dynamic> email) {
    final originalSubject = email['subject']?.toString() ?? '(No Subject)';
    final messageId = email['id']?.toString() ?? '';

    if (messageId.isEmpty) {
      _showError('Cannot forward: Email ID is missing');
      return;
    }

    // Add "Fwd: " prefix if not already present
    final forwardSubject = originalSubject.startsWith('Fwd: ') ||
            originalSubject.startsWith('Fw: ')
        ? originalSubject
        : 'Fwd: $originalSubject';

    // Get original email details for the forward body
    final originalFrom = email['from']?.toString() ?? 'Unknown sender';
    final originalDate = email['date']?.toString() ?? '';
    final originalBody = email['body']?.toString() ?? '';

    // Format the forward body with original email content
    final forwardBody = _formatForwardBody(
      originalFrom: originalFrom,
      originalDate: originalDate,
      originalSubject: originalSubject,
      originalBody: originalBody,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ComposeEmailDialog(
        initialSubject: forwardSubject,
        initialBody: forwardBody,
        onSend: (to, cc, subject, body, attachments) async {
          Navigator.pop(dialogContext);
          await _forwardEmail(to, cc, subject, body, attachments);
        },
        onDiscard: () {
          Navigator.pop(dialogContext);
        },
      ),
    );
  }

  String _formatForwardBody({
    required String originalFrom,
    required String originalDate,
    required String originalSubject,
    required String originalBody,
  }) {
    // Format the forward body similar to Gmail's format
    final buffer = StringBuffer();
    buffer.writeln('---------- Forwarded message ----------');
    buffer.writeln('From: $originalFrom');
    if (originalDate.isNotEmpty) {
      buffer.writeln('Date: $originalDate');
    }
    buffer.writeln('Subject: $originalSubject');
    buffer.writeln('To: ');
    buffer.writeln('');
    buffer.writeln(originalBody);
    return buffer.toString();
  }

  Future<void> _forwardEmail(
    String to,
    String? cc,
    String subject,
    String body,
    List<PlatformFile> attachments,
  ) async {
    // Validate required fields
    if (to.trim().isEmpty) {
      _showError('Please enter a recipient email address');
      return;
    }
    if (subject.trim().isEmpty) {
      _showError('Please enter a subject');
      return;
    }
    if (body.trim().isEmpty) {
      _showError('Please enter a message body');
      return;
    }

    // Use the regular send email function for forwarding
    await _sendEmail(to, cc, subject, body, attachments);
  }

  Future<void> _replyToEmail(
    String messageId,
    String body,
    List<PlatformFile> attachments,
  ) async {
    // Validate required fields
    if (body.trim().isEmpty) {
      _showError('Please enter a message body');
      return;
    }

    // Note: Attachments in replies are not currently supported by the backend
    // The backend gmailReply function only supports messageId, replyBody, and isHtml
    if (attachments.isNotEmpty) {
      _showError(
          'Attachments in replies are not currently supported. Please send a new email to include attachments.');
      return;
    }

    try {
      // Check if body contains HTML
      final isHtml = body.trim().isNotEmpty &&
          body.contains('<') &&
          (body.contains('<html') ||
              body.contains('<div') ||
              body.contains('<p') ||
              body.contains('<br') ||
              body.contains('<span') ||
              body.contains('<a ') ||
              body.contains('<img') ||
              body.contains('<table') ||
              body.contains('<style') ||
              body.contains('</'));

      // Call gmailReply action
      final success = await actions.gmailReply(
        messageId: messageId,
        replyBody: body,
        isHtml: isHtml,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Reply sent successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          _showError('Failed to send reply');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Error sending reply: $e');
      }
    }
  }

  Future<void> _sendEmail(
    String to,
    String? cc,
    String subject,
    String body,
    List<PlatformFile> attachments,
  ) async {
    // Validate required fields
    if (to.trim().isEmpty) {
      _showError('Please enter a recipient email address');
      return;
    }
    if (subject.trim().isEmpty) {
      _showError('Please enter a subject');
      return;
    }
    if (body.trim().isEmpty) {
      _showError('Please enter a message body');
      return;
    }

    // Show loading dialog - simple for attachments, airplane animation for text-only
    BuildContext? dialogContext;
    ValueNotifier<String>? messageNotifier;

    if (attachments.isNotEmpty) {
      messageNotifier = ValueNotifier<String>(
          'Uploading ${attachments.length} attachment${attachments.length > 1 ? 's' : ''}...');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          dialogContext = context;
          return _SimpleSendingDialog(
            messageNotifier: messageNotifier!,
          );
        },
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _EmailSendingDialog(
          message: 'Sending email...',
        ),
      );
    }

    try {
      // Send email with attachments and CC
      // The upload happens inside gmailSendEmail first, then email is sent
      final sendFuture = actions.gmailSendEmail(
        to: to,
        cc: cc,
        subject: subject,
        body: body,
        isHtml: false,
        attachments: attachments,
      );

      // Update message to "Sending email..." after a short delay
      // (uploads typically complete quickly, then email sending happens)
      if (attachments.isNotEmpty && messageNotifier != null) {
        final notifier = messageNotifier;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            notifier.value = 'Sending email...';
          }
        });
      }

      final success = await sendFuture;

      if (mounted) {
        // Show success message briefly before closing
        if (success) {
          if (attachments.isNotEmpty && messageNotifier != null) {
            final notifier = messageNotifier;
            notifier.value = 'Email sent successfully!';
            // Dispose notifier
            notifier.dispose();
            messageNotifier = null;
          }

          if (dialogContext != null) {
            Navigator.of(dialogContext!).pop();
          } else {
            Navigator.pop(context);
          }

          // Show success snackbar only
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Email sent successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          if (messageNotifier != null) {
            final notifier = messageNotifier;
            notifier.dispose();
            messageNotifier = null;
          }
          if (dialogContext != null) {
            Navigator.of(dialogContext!).pop();
          } else {
            Navigator.pop(context);
          }
          _showError('Failed to send email');
        }
      }
    } catch (e) {
      if (mounted) {
        if (messageNotifier != null) {
          final notifier = messageNotifier;
          notifier.dispose();
          messageNotifier = null;
        }
        if (dialogContext != null) {
          Navigator.of(dialogContext!).pop();
        } else {
          Navigator.pop(context);
        }
        _showError('Error sending email: $e');
      }
    }
  }

  Widget _buildLoadingExperience() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primaryBackground,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing Gmail Icon
                _PulsingGmailIcon(),
                const SizedBox(height: 40),
                // Animated Loading Text
                _AnimatedLoadingText(),
                const SizedBox(height: 40),
                // Shimmer Email Cards
                ...List.generate(
                    3,
                    (index) => _ShimmerEmailCard(
                        delay: Duration(milliseconds: index * 200))),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Compose Email Dialog Widget
class _ComposeEmailDialog extends StatefulWidget {
  final Function(String to, String? cc, String subject, String body,
      List<PlatformFile> attachments) onSend;
  final VoidCallback onDiscard;
  final String? initialTo;
  final String? initialSubject;
  final String? initialBody;

  const _ComposeEmailDialog({
    required this.onSend,
    required this.onDiscard,
    this.initialTo,
    this.initialSubject,
    this.initialBody,
  });

  @override
  State<_ComposeEmailDialog> createState() => _ComposeEmailDialogState();
}

class _ComposeEmailDialogState extends State<_ComposeEmailDialog> {
  late final TextEditingController _toController;
  late final TextEditingController _ccController;
  late final TextEditingController _subjectController;
  final _bodyController = TextEditingController();
  final _toFocusNode = FocusNode();
  final _ccFocusNode = FocusNode();
  final _subjectFocusNode = FocusNode();
  final _bodyFocusNode = FocusNode();

  bool _showCc = false;
  bool _isBold = false;
  bool _isItalic = false;
  final List<PlatformFile> _attachments = [];

  String get _interFont =>
      'Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';

  @override
  void initState() {
    super.initState();
    // Initialize controllers with initial values if provided
    _toController = TextEditingController(text: widget.initialTo ?? '');
    _ccController = TextEditingController();
    _subjectController =
        TextEditingController(text: widget.initialSubject ?? '');
    _bodyController.text = widget.initialBody ?? '';
  }

  @override
  void dispose() {
    _toController.dispose();
    _ccController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    _toFocusNode.dispose();
    _ccFocusNode.dispose();
    _subjectFocusNode.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachments.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking files: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE8EAED), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'New Message',
                    style: TextStyle(
                      fontFamily: _interFont,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F1F1F),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: const Color(0xFF5F6368),
                    onPressed: widget.onDiscard,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // To field
                    Focus(
                      onFocusChange: (hasFocus) {
                        setState(() {});
                      },
                      child: TextField(
                        controller: _toController,
                        focusNode: _toFocusNode,
                        decoration: InputDecoration(
                          hintText: 'To',
                          hintStyle: TextStyle(
                            fontFamily: _interFont,
                            fontSize: 14,
                            color: const Color(0xFF9AA0A6),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(
                              color: _toFocusNode.hasFocus
                                  ? const Color(0xFF1A73E8) // Blue when focused
                                  : const Color(0xFFDADCE0),
                              width: _toFocusNode.hasFocus ? 2 : 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(
                              color: Color(0xFFDADCE0),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(
                              color: Color(0xFF1A73E8), // Blue when focused
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        style: TextStyle(
                          fontFamily: _interFont,
                          fontSize: 14,
                          color: const Color(0xFF1F1F1F),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Cc toggle and field
                    Row(
                      children: [
                        if (!_showCc)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showCc = true;
                              });
                            },
                            child: Text(
                              'Cc',
                              style: TextStyle(
                                fontFamily: _interFont,
                                fontSize: 14,
                                color: const Color(0xFF1A73E8), // Blue
                              ),
                            ),
                          ),
                        if (_showCc) ...[
                          Expanded(
                            child: TextField(
                              controller: _ccController,
                              focusNode: _ccFocusNode,
                              decoration: InputDecoration(
                                hintText: 'Cc',
                                hintStyle: TextStyle(
                                  fontFamily: _interFont,
                                  fontSize: 14,
                                  color: const Color(0xFF9AA0A6),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFDADCE0),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFDADCE0),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF1A73E8),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              style: TextStyle(
                                fontFamily: _interFont,
                                fontSize: 14,
                                color: const Color(0xFF1F1F1F),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Subject field
                    TextField(
                      controller: _subjectController,
                      focusNode: _subjectFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Subject',
                        hintStyle: TextStyle(
                          fontFamily: _interFont,
                          fontSize: 14,
                          color: const Color(0xFF9AA0A6),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(
                            color: Color(0xFFDADCE0),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(
                            color: Color(0xFFDADCE0),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(
                            color: Color(0xFF1A73E8),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(
                        fontFamily: _interFont,
                        fontSize: 14,
                        color: const Color(0xFF1F1F1F),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Rich text editor toolbar
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom:
                              BorderSide(color: Color(0xFFE8EAED), width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.format_bold_rounded,
                              size: 20,
                              color: _isBold
                                  ? const Color(0xFF1A73E8)
                                  : const Color(0xFF5F6368),
                            ),
                            onPressed: () {
                              setState(() {
                                _isBold = !_isBold;
                              });
                              // TODO: Apply bold formatting
                            },
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.format_italic_rounded,
                              size: 20,
                              color: _isItalic
                                  ? const Color(0xFF1A73E8)
                                  : const Color(0xFF5F6368),
                            ),
                            onPressed: () {
                              setState(() {
                                _isItalic = !_isItalic;
                              });
                              // TODO: Apply italic formatting
                            },
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.link_rounded,
                              size: 20,
                              color: Color(0xFF5F6368),
                            ),
                            onPressed: () {
                              // TODO: Insert link
                            },
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.attach_file_rounded,
                              size: 20,
                              color: Color(0xFF5F6368),
                            ),
                            onPressed: _pickFiles,
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Message body
                    TextField(
                      controller: _bodyController,
                      focusNode: _bodyFocusNode,
                      maxLines: null,
                      minLines: 10,
                      decoration: InputDecoration(
                        hintText: 'Compose your message...',
                        hintStyle: TextStyle(
                          fontFamily: _interFont,
                          fontSize: 14,
                          color: const Color(0xFF9AA0A6),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(
                            color: Color(0xFFDADCE0),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(
                            color: Color(0xFFDADCE0),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(
                            color: Color(0xFF1A73E8),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      style: TextStyle(
                        fontFamily: _interFont,
                        fontSize: 14,
                        color: const Color(0xFF1F1F1F),
                        height: 1.5,
                      ),
                    ),
                    // Attachments
                    if (_attachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _attachments.asMap().entries.map((entry) {
                          final index = entry.key;
                          final file = entry.value;
                          return Chip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.attach_file, size: 16),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    file.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _removeAttachment(index),
                                  child: const Icon(Icons.close, size: 16),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFFF1F3F4),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Footer buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE8EAED), width: 1),
                ),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: widget.onDiscard,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      side: const BorderSide(color: Color(0xFFDADCE0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'Discard',
                      style: TextStyle(
                        fontFamily: _interFont,
                        fontSize: 14,
                        color: const Color(0xFF1F1F1F),
                      ),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () {
                      // TODO: Save draft
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      side: const BorderSide(color: Color(0xFFDADCE0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'Save Draft',
                      style: TextStyle(
                        fontFamily: _interFont,
                        fontSize: 14,
                        color: const Color(0xFF1F1F1F),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      // Validate before sending
                      final to = _toController.text.trim();
                      final subject = _subjectController.text.trim();
                      final body = _bodyController.text.trim();

                      if (to.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Please enter a recipient email address'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (subject.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a subject'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (body.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a message body'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      widget.onSend(
                        to,
                        _ccController.text.trim().isEmpty
                            ? null
                            : _ccController.text.trim(),
                        subject,
                        body,
                        _attachments,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A73E8), // Blue
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'Send',
                      style: TextStyle(
                        fontFamily: _interFont,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildLoadingExperience() {
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: 1.0),
    duration: const Duration(milliseconds: 1200),
    curve: Curves.easeInOut,
    builder: (context, value, child) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FlutterFlowTheme.of(context).primaryBackground,
              FlutterFlowTheme.of(context).primaryBackground,
              FlutterFlowTheme.of(context).primaryBackground.withOpacity(0.95),
            ],
            stops: [0.0, 0.5 * value, 1.0],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Gmail Icon with Pulsing Effect
            _PulsingGmailIcon(),
            const SizedBox(height: 40),
            // Animated Text
            _AnimatedLoadingText(),
            const SizedBox(height: 60),
            // Shimmer Email Skeleton Cards
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                itemBuilder: (context, index) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(
                      milliseconds: 800 + (index * 150),
                    ),
                    curve: Curves.easeOut,
                    builder: (context, opacity, child) {
                      return Opacity(
                        opacity: opacity,
                        child: _ShimmerEmailCard(
                          delay: Duration(milliseconds: index * 100),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildEmailContentLoading() {
  return Container(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Animated email icon
        Center(
          child: _PulsingEmailIcon(),
        ),
        const SizedBox(height: 32),
        // Shimmer header with staggered animation
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(
                    width: double.infinity,
                    height: 32,
                    borderRadius: 8,
                  ),
                  SizedBox(height: 16),
                  _ShimmerBox(
                    width: 200,
                    height: 20,
                    borderRadius: 8,
                  ),
                  SizedBox(height: 8),
                  _ShimmerBox(
                    width: 150,
                    height: 16,
                    borderRadius: 8,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 24),
        // Shimmer body with staggered animation
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(
                      width: double.infinity,
                      height: 16,
                      borderRadius: 8,
                    ),
                    SizedBox(height: 12),
                    _ShimmerBox(
                      width: double.infinity,
                      height: 16,
                      borderRadius: 8,
                    ),
                    SizedBox(height: 12),
                    _ShimmerBox(
                      width: double.infinity,
                      height: 16,
                      borderRadius: 8,
                    ),
                    SizedBox(height: 12),
                    _ShimmerBox(
                      width: 80,
                      height: 16,
                      borderRadius: 8,
                    ),
                    SizedBox(height: 24),
                    _ShimmerBox(
                      width: double.infinity,
                      height: 200,
                      borderRadius: 12,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

// Animated Loading Text Widget
class _AnimatedLoadingText extends StatefulWidget {
  @override
  _AnimatedLoadingTextState createState() => _AnimatedLoadingTextState();
}

class _AnimatedLoadingTextState extends State<_AnimatedLoadingText> {
  final List<String> _loadingMessages = [
    'Fetching your emails...',
    'Organizing your inbox...',
    'Almost there...',
    'Loading messages...',
  ];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() {
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _loadingMessages.length;
        });
        _startAnimation();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.3),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        _loadingMessages[_currentIndex],
        key: ValueKey(_currentIndex),
        style: FlutterFlowTheme.of(context).titleMedium.override(
              fontFamily:
                  'Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: FlutterFlowTheme.of(context).primaryText,
              letterSpacing: 0,
            ),
      ),
    );
  }
}

// Shimmer Email Card Widget
class _ShimmerEmailCard extends StatefulWidget {
  final Duration delay;

  const _ShimmerEmailCard({required this.delay});

  @override
  _ShimmerEmailCardState createState() => _ShimmerEmailCardState();
}

class _ShimmerEmailCardState extends State<_ShimmerEmailCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar shimmer
          _ShimmerBox(
            width: 44,
            height: 44,
            borderRadius: 22,
          ),
          SizedBox(width: 12),
          // Content shimmer
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ShimmerBox(
                        width: double.infinity,
                        height: 16,
                        borderRadius: 8,
                      ),
                    ),
                    SizedBox(width: 12),
                    _ShimmerBox(
                      width: 60,
                      height: 14,
                      borderRadius: 7,
                    ),
                  ],
                ),
                SizedBox(height: 8),
                _ShimmerBox(
                  width: double.infinity,
                  height: 16,
                  borderRadius: 8,
                ),
                SizedBox(height: 6),
                _ShimmerBox(
                  width: 200,
                  height: 14,
                  borderRadius: 7,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Shimmer Box Widget
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  _ShimmerBoxState createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 - _controller.value * 2, 0.0),
              end: Alignment(1.0 - _controller.value * 2, 0.0),
              colors: [
                FlutterFlowTheme.of(context).alternate.withOpacity(0.1),
                FlutterFlowTheme.of(context).alternate.withOpacity(0.3),
                FlutterFlowTheme.of(context).alternate.withOpacity(0.1),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// Pulsing Gmail Icon Widget
class _PulsingGmailIcon extends StatefulWidget {
  @override
  _PulsingGmailIconState createState() => _PulsingGmailIconState();
}

class _PulsingGmailIconState extends State<_PulsingGmailIcon>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Scale animation for initial entrance
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );

    // Pulse animation for continuous effect
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _scaleController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value * _pulseAnimation.value,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFE8EAED)
                      .withOpacity(0.3 + (_pulseAnimation.value - 1.0) * 0.1),
                  const Color(0xFFDADCE0)
                      .withOpacity(0.3 + (_pulseAnimation.value - 1.0) * 0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: FlutterFlowTheme.of(context)
                      .primary
                      .withOpacity(0.3 * _pulseAnimation.value),
                  blurRadius: 20 * _pulseAnimation.value,
                  spreadRadius: 5 * _pulseAnimation.value,
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                'assets/images/google.png',
                width: 48,
                height: 48,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}

// Pulsing Email Icon Widget for Email Content Loading
class _PulsingEmailIcon extends StatefulWidget {
  @override
  _PulsingEmailIconState createState() => _PulsingEmailIconState();
}

class _PulsingEmailIconState extends State<_PulsingEmailIcon>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Scale animation for initial entrance
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );

    // Pulse animation for continuous effect
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _scaleController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value * _pulseAnimation.value,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FlutterFlowTheme.of(context)
                      .primary
                      .withOpacity(0.2 + (_pulseAnimation.value - 1.0) * 0.1),
                  FlutterFlowTheme.of(context)
                      .primary
                      .withOpacity(0.15 + (_pulseAnimation.value - 1.0) * 0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: FlutterFlowTheme.of(context)
                      .primary
                      .withOpacity(0.3 * _pulseAnimation.value),
                  blurRadius: 15 * _pulseAnimation.value,
                  spreadRadius: 3 * _pulseAnimation.value,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.email_rounded,
                size: 36,
                color: FlutterFlowTheme.of(context).primary,
              ),
            ),
          ),
        );
      },
    );
  }
}

// Document Loading Dialog Widget
class _DocumentLoadingDialog extends StatefulWidget {
  final String message;

  const _DocumentLoadingDialog({required this.message});

  @override
  _DocumentLoadingDialogState createState() => _DocumentLoadingDialogState();
}

class _DocumentLoadingDialogState extends State<_DocumentLoadingDialog>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Rotation animation for document icon
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _rotationController,
        curve: Curves.linear,
      ),
    );

    // Pulse animation for container
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rotationAnimation, _pulseAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).primaryBackground,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated document icon
                  Transform.rotate(
                    angle: _rotationAnimation.value * 0.1,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            FlutterFlowTheme.of(context)
                                .primary
                                .withOpacity(0.2),
                            FlutterFlowTheme.of(context)
                                .primary
                                .withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.description_rounded,
                          size: 40,
                          color: FlutterFlowTheme.of(context).primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Loading text
                  Text(
                    widget.message,
                    style: FlutterFlowTheme.of(context).titleMedium.override(
                          fontFamily:
                              'Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: FlutterFlowTheme.of(context).primaryText,
                          letterSpacing: 0,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Progress indicator
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        FlutterFlowTheme.of(context).primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Email Sending Dialog with Airplane Animation
class _EmailSendingDialog extends StatefulWidget {
  final String message;

  const _EmailSendingDialog({
    required this.message,
  });

  @override
  State<_EmailSendingDialog> createState() => _EmailSendingDialogState();
}

class _EmailSendingDialogState extends State<_EmailSendingDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flyingAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _flyingAnimation = Tween<double>(begin: -100, end: 100).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const String interFont =
        'Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated airplane flying across
                SizedBox(
                  height: 120,
                  width: 300,
                  child: Stack(
                    children: [
                      // Cloud trail
                      Positioned(
                        left: 50 + _flyingAnimation.value * 0.5,
                        top: 40,
                        child: const Opacity(
                          opacity: 0.3,
                          child: Icon(
                            Icons.cloud_outlined,
                            size: 40,
                            color: Color(0xFF1A73E8),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 100 + _flyingAnimation.value * 0.5,
                        top: 50,
                        child: const Opacity(
                          opacity: 0.2,
                          child: Icon(
                            Icons.cloud_outlined,
                            size: 30,
                            color: Color(0xFF1A73E8),
                          ),
                        ),
                      ),
                      // Airplane
                      Positioned(
                        left: 100 + _flyingAnimation.value,
                        top: 30,
                        child: Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Transform.rotate(
                            angle: 0.1 * (1 - _pulseAnimation.value),
                            child: const Icon(
                              Icons.flight_rounded,
                              size: 60,
                              color: Color(0xFF1A73E8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Loading text
                Text(
                  widget.message,
                  style: const TextStyle(
                    fontFamily: interFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F1F1F),
                    letterSpacing: 0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Progress bar
                Container(
                  width: 200,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: const Color(0xFFE8EAED),
                  ),
                  child: Stack(
                    children: [
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return FractionallySizedBox(
                            widthFactor:
                                0.3 + (0.7 * ((_controller.value * 2) % 1)),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1A73E8),
                                    Color(0xFF4285F4),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Simple Sending Dialog for attachments (no airplane animation)
class _SimpleSendingDialog extends StatelessWidget {
  final String? message;
  final ValueNotifier<String>? messageNotifier;
  final bool isSuccess;

  const _SimpleSendingDialog({
    super.key,
    this.message,
    this.messageNotifier,
    this.isSuccess = false,
  }) : assert(message != null || messageNotifier != null,
            'Either message or messageNotifier must be provided');

  @override
  Widget build(BuildContext context) {
    const String interFont =
        'Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon or loading indicator
            SizedBox(
              width: 60,
              height: 60,
              child: isSuccess
                  ? const Icon(
                      Icons.check_circle_rounded,
                      size: 60,
                      color: Color(0xFF34A853), // Green for success
                    )
                  : const CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF1A73E8)),
                    ),
            ),
            const SizedBox(height: 24),
            // Loading text - use ValueListenableBuilder if messageNotifier is provided
            messageNotifier != null
                ? ValueListenableBuilder<String>(
                    valueListenable: messageNotifier!,
                    builder: (context, currentMessage, child) {
                      return Text(
                        currentMessage,
                        style: const TextStyle(
                          fontFamily: interFont,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1F1F1F),
                          letterSpacing: 0,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  )
                : Text(
                    message!,
                    style: TextStyle(
                      fontFamily: interFont,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isSuccess
                          ? const Color(0xFF34A853)
                          : const Color(0xFF1F1F1F),
                      letterSpacing: 0,
                    ),
                    textAlign: TextAlign.center,
                  ),
            if (!isSuccess) ...[
              const SizedBox(height: 16),
              const Text(
                'This may take a moment...',
                style: TextStyle(
                  fontFamily: interFont,
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Color(0xFF5F6368),
                  letterSpacing: 0,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
