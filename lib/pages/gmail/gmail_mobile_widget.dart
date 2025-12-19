import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:intl/intl.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GmailMobileWidget extends StatefulWidget {
  const GmailMobileWidget({Key? key}) : super(key: key);

  @override
  _GmailMobileWidgetState createState() => _GmailMobileWidgetState();
}

class _GmailMobileWidgetState extends State<GmailMobileWidget> {
  List<Map<String, dynamic>> _emails = [];
  List<Map<String, dynamic>> _allEmails = [];
  bool _isLoading = false;
  String? _nextPageToken;
  Map<String, dynamic>? _selectedEmail;
  bool _isLoadingEmail = false;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  bool _isConnecting = false;
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (currentUser != null && currentUserUid.isNotEmpty) {
      _checkGmailConnection();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        _nextPageToken != null &&
        !_isLoading) {
      _loadEmails();
    }
  }

  Future<void> _checkGmailConnection() async {
    if (currentUser == null || currentUserUid.isEmpty) return;
    if (currentUserDocument == null) return;

    final userDoc = await currentUserDocument!.reference.get();
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>?;
      final isConnected = userData?['gmail_connected'] == true;

      if (isConnected) {
        _loadEmails();
      }
    }
  }

  Future<void> _connectGmail() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      final success = await actions.gmailOAuthConnect(context);
      if (success && mounted) {
        await _checkGmailConnection();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gmail connected successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect Gmail. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error connecting Gmail: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _loadEmails({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _emails = [];
        _allEmails = [];
        _nextPageToken = null;
        _selectedEmail = null;
      }
    });

    try {
      final result = await actions.gmailListEmails(
        maxResults: 50,
        pageToken: refresh ? null : _nextPageToken,
      );

      if (result != null && result['success'] == true) {
        final emailsList = result['emails'];
        List<Map<String, dynamic>> newEmails = [];

        if (emailsList != null && emailsList is List) {
          for (var email in emailsList) {
            if (email is Map) {
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

    setState(() {
      _selectedEmail = null;
      _isLoadingEmail = true;
    });

    try {
      // Mark as read when opened
      await actions.gmailMarkAsRead(messageId);

      // Update local state
      setState(() {
        final emailIndex =
            _emails.indexWhere((email) => email['id']?.toString() == messageId);
        if (emailIndex != -1) {
          final labels = List<String>.from(_emails[emailIndex]['labels'] ?? []);
          labels.remove('UNREAD');
          _emails[emailIndex] = {
            ..._emails[emailIndex],
            'labels': labels,
          };
        }
      });

      final result = await actions.gmailGetEmail(messageId);

      if (result != null && result['success'] == true) {
        final emailData = result['email'];
        Map<String, dynamic>? emailMap;

        if (emailData is Map) {
          emailMap = _convertMap(emailData);
        }

        setState(() {
          _selectedEmail = emailMap;
          _isLoadingEmail = false;
        });
      } else {
        setState(() {
          _isLoadingEmail = false;
        });
        _showError(result?['error'] ?? 'Failed to load email');
      }
    } catch (e) {
      setState(() {
        _isLoadingEmail = false;
      });
      _showError('Error loading email: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredEmails() {
    List<Map<String, dynamic>> filtered = _emails;

    if (_selectedFilter == 'Unread') {
      filtered = filtered.where((email) {
        final labels = email['labels'] as List?;
        return labels != null && labels.contains('UNREAD');
      }).toList();
    } else if (_selectedFilter == 'Read') {
      filtered = filtered.where((email) {
        final labels = email['labels'] as List?;
        return labels == null || !labels.contains('UNREAD');
      }).toList();
    }

    final query = _searchController.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      filtered = filtered.where((email) {
        final subject = (email['subject'] ?? '').toString().toLowerCase();
        final from = (email['from'] ?? '').toString().toLowerCase();
        final snippet = (email['snippet'] ?? '').toString().toLowerCase();
        return subject.contains(query) ||
            from.contains(query) ||
            snippet.contains(query);
      }).toList();
    }

    return filtered;
  }

  bool _isUnread(Map<String, dynamic> email) {
    final labels = email['labels'] as List?;
    return labels != null && labels.contains('UNREAD');
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      DateTime? date;
      String cleanedDate =
          dateString.replaceAll(RegExp(r'\s*\([^)]+\)\s*'), '').trim();

      // Try RFC 2822 format first
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

        // RFC 2822 dates include timezone offset
        // Create the date in the specified timezone, then convert to UTC, then to local
        // The date string represents the time in that timezone
        // So we create UTC time and add the offset to get the actual UTC time
        date = DateTime.utc(year, month, day, hour, minute, second)
            .subtract(Duration(minutes: totalOffsetMinutes));
        // Now convert from UTC to user's local timezone
        date = date.toLocal();
      } else {
        // Try ISO format or other standard formats
        try {
          // Handle formats like "10 Nov 2025 16:26:10"
          final simpleMatch = RegExp(
            r'(\d+)\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)',
          ).firstMatch(cleanedDate);

          if (simpleMatch != null) {
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
            final day = int.parse(simpleMatch.group(1)!);
            final month = months[simpleMatch.group(2)] ?? 1;
            final year = int.parse(simpleMatch.group(3)!);
            final hour = int.parse(simpleMatch.group(4)!);
            final minute = int.parse(simpleMatch.group(5)!);
            final second = int.parse(simpleMatch.group(6)!);
            // Assume UTC if no timezone info, then convert to local
            date =
                DateTime.utc(year, month, day, hour, minute, second).toLocal();
          } else {
            // Try standard DateTime.parse
            date = DateTime.parse(cleanedDate);
            // If no timezone info, assume UTC and convert to local
            if (!cleanedDate.contains('Z') &&
                !cleanedDate.contains('+') &&
                !cleanedDate.contains('-', 1)) {
              date = DateTime.utc(date.year, date.month, date.day, date.hour,
                      date.minute, date.second)
                  .toLocal();
            } else {
              // If timezone info exists, ensure it's converted to local
              date = date.toLocal();
            }
          }
        } catch (e) {
          // If all parsing fails, return a cleaned version
          if (cleanedDate.length > 15) {
            return cleanedDate.substring(0, 15);
          }
          return cleanedDate;
        }
      }

      // Ensure date is in local timezone
      final dateLocal = date.toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateLocal);

      if (difference.inDays == 0) {
        return DateFormat('h:mm a').format(dateLocal);
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return DateFormat('EEE').format(dateLocal);
      } else if (difference.inDays < 365) {
        return DateFormat('MMM d').format(dateLocal);
      } else {
        return DateFormat('MMM d, yyyy').format(dateLocal);
      }
    } catch (e) {
      // Return a safe fallback
      if (dateString.length > 15) {
        return dateString.substring(0, 15);
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

  Color _getAvatarColor(String? from) {
    final initial = _getInitials(from);
    if (initial.isEmpty || initial == '?') {
      return Color(0xFF8E8E93);
    }

    // Generate consistent color based on the first character
    final char = initial[0].toUpperCase();
    final colors = [
      Color(0xFF007AFF), // Blue
      Color(0xFF34C759), // Green
      Color(0xFFFF9500), // Orange
      Color(0xFFFF3B30), // Red
      Color(0xFFAF52DE), // Purple
      Color(0xFFFF2D55), // Pink
      Color(0xFF5AC8FA), // Light Blue
      Color(0xFFFFCC00), // Yellow
      Color(0xFF5856D6), // Indigo
      Color(0xFFFF9500), // Orange
      Color(0xFF00C7BE), // Teal
      Color(0xFFFF6B6B), // Coral
      Color(0xFF4ECDC4), // Turquoise
      Color(0xFF45B7D1), // Sky Blue
      Color(0xFF96CEB4), // Mint
      Color(0xFFFFEAA7), // Light Yellow
      Color(0xFFDDA0DD), // Plum
      Color(0xFF98D8C8), // Aqua
      Color(0xFFF7DC6F), // Gold
      Color(0xFFBB8FCE), // Lavender
    ];

    // Use character code to get consistent color
    final index = char.codeUnitAt(0) % colors.length;
    return colors[index];
  }

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

  List _convertList(List list) {
    return list.map((item) {
      if (item is Map) {
        return _convertMap(item);
      } else if (item is List) {
        return _convertList(item);
      }
      return item;
    }).toList();
  }

  Future<void> _disconnectGmail() async {
    if (currentUserDocument == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disconnect Gmail'),
        content:
            Text('Are you sure you want to disconnect your Gmail account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Disconnect', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await currentUserDocument!.reference.update({
          'gmail_connected': false,
          'gmail_access_token': FieldValue.delete(),
          'gmail_refresh_token': FieldValue.delete(),
          'gmail_email': FieldValue.delete(),
          'gmail_connected_at': FieldValue.delete(),
        });

        setState(() {
          _emails = [];
          _allEmails = [];
          _selectedEmail = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gmail disconnected successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        _showError('Error disconnecting Gmail: $e');
      }
    }
  }

  void _showComposeDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ComposeEmailSheet(
        onSend: (to, subject, body, attachments) async {
          Navigator.pop(context);
          final success = await actions.gmailSendEmail(
            to: to,
            subject: subject,
            body: body,
            attachments: attachments,
          );
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Email sent successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            _loadEmails(refresh: true);
          } else if (mounted) {
            _showError('Failed to send email');
          }
        },
      ),
    );
  }

  void _showReplyDialog(Map<String, dynamic> email) {
    final from = _parseEmailAddress(email['from']);
    final subject = email['subject'] ?? '';
    final replySubject = subject.startsWith('Re:') ? subject : 'Re: $subject';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ComposeEmailSheet(
        to: from,
        subject: replySubject,
        isReply: true,
        onSend: (to, subject, body, attachments) async {
          Navigator.pop(context);
          final success = await actions.gmailReply(
            messageId: email['id']?.toString() ?? '',
            replyBody: body,
          );
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Reply sent successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            _loadEmails(refresh: true);
          } else if (mounted) {
            _showError('Failed to send reply');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      body: StreamBuilder<UsersRecord>(
        stream: currentUserDocument != null
            ? UsersRecord.getDocument(currentUserDocument!.reference)
            : Stream<UsersRecord>.value(UsersRecord.getDocumentFromData({},
                FirebaseFirestore.instance.collection('users').doc('dummy'))),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!;
          final gmailConnected =
              (userData.snapshotData['gmail_connected'] as bool?) ?? false;

          if (!gmailConnected) {
            return _buildNotConnectedState();
          }

          if (_selectedEmail != null || _isLoadingEmail) {
            return _buildEmailDetailView();
          }

          return _buildEmailListView();
        },
      ),
    );
  }

  Widget _buildNotConnectedState() {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F7),
      body: Column(
        children: [
          _buildIOSHeader(),
          Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/google.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(height: 32),
                    Text(
                      'Gmail Not Connected',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D1D1F),
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Connect your Gmail account to access and manage your emails directly from Lona',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 16,
                        color: Color(0xFF8E8E93),
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 40),
                    ElevatedButton.icon(
                      onPressed: _isConnecting ? null : _connectGmail,
                      icon: _isConnecting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.email_outlined, size: 20),
                      label: Text(
                        _isConnecting ? 'Connecting...' : 'Connect Gmail',
                        style: TextStyle(
                          fontFamily: 'SF Pro Text',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        backgroundColor: Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailListView() {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F7),
      body: Column(
        children: [
          // iOS-style header with liquid glass
          _buildIOSHeader(),
          // Search bar with liquid glass (only when visible)
          if (_isSearchVisible) _buildSearchBar(),
          // Navigation tabs with blue gradient
          _buildNavigationTabs(),
          // Email list
          Expanded(
            child: _isLoading && _emails.isEmpty
                ? _buildLoadingExperience()
                : _emails.isEmpty && !_isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 64, color: Color(0xFF8E8E93)),
                            SizedBox(height: 16),
                            Text(
                              'Your inbox is empty',
                              style: TextStyle(
                                fontFamily: 'SF Pro Text',
                                fontSize: 17,
                                color: Color(0xFF1D1D1F),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 24),
                            OutlinedButton.icon(
                              onPressed: () => _loadEmails(refresh: true),
                              icon:
                                  Icon(Icons.refresh, color: Color(0xFF007AFF)),
                              label: Text(
                                'Refresh',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Text',
                                  color: Color(0xFF007AFF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Color(0xFF007AFF)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadEmails(refresh: true),
                        color: Color(0xFF007AFF),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.zero,
                          itemCount: _getFilteredEmails().length +
                              (_isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _getFilteredEmails().length) {
                              if (_nextPageToken != null) {
                                _loadEmails();
                              }
                              return Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF007AFF),
                                  ),
                                ),
                              );
                            }

                            final email = _getFilteredEmails()[index];
                            final isUnread = _isUnread(email);
                            final hasAttachment =
                                email['attachments'] != null &&
                                    (email['attachments'] as List).isNotEmpty;

                            return Container(
                              margin: EdgeInsets.fromLTRB(
                                  16, index == 0 ? 0 : 4, 16, 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                dense: false,
                                leading: CircleAvatar(
                                  backgroundColor:
                                      _getAvatarColor(email['from']),
                                  radius: 24,
                                  child: Text(
                                    _getInitials(email['from']),
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Text',
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    if (isUnread)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF007AFF),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        _parseEmailName(email['from']),
                                        style: TextStyle(
                                          fontFamily: 'SF Pro Text',
                                          fontWeight: isUnread
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          fontSize: 17,
                                          color: Color(0xFF1D1D1F),
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (hasAttachment) ...[
                                          Icon(Icons.attach_file,
                                              size: 14,
                                              color: Color(0xFF8E8E93)),
                                          SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Text(
                                            email['subject'] ?? '(No Subject)',
                                            style: TextStyle(
                                              fontFamily: 'SF Pro Text',
                                              fontWeight: isUnread
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                              fontSize: 15,
                                              color: Color(0xFF1D1D1F),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      email['snippet'] ?? '',
                                      style: TextStyle(
                                        fontFamily: 'SF Pro Text',
                                        fontSize: 13,
                                        color: Color(0xFF8E8E93),
                                        fontWeight: FontWeight.w400,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                trailing: Text(
                                  _formatDate(email['date']),
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Text',
                                    fontSize: 13,
                                    color: Color(0xFF8E8E93),
                                  ),
                                ),
                                onTap: () => _loadEmailDetail(
                                    email['id']?.toString() ?? ''),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showComposeDialog,
        backgroundColor: Color(0xFF007AFF),
        elevation: 4,
        child: Icon(
          Icons.edit_outlined,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildIOSHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A1D29).withOpacity(0.95),
                Color(0xFF2D3142).withOpacity(0.95),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Container(
              height: 56,
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/google.png',
                          width: 28,
                          height: 28,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Gmail',
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeaderButton(
                        icon: Icons.search_rounded,
                        isActive: _isSearchVisible,
                        onTap: () {
                          setState(() {
                            _isSearchVisible = !_isSearchVisible;
                            if (!_isSearchVisible) {
                              _searchController.clear();
                            }
                          });
                        },
                      ),
                      SizedBox(width: 12),
                      _buildHeaderButton(
                        icon: Icons.refresh_rounded,
                        onTap: () => _loadEmails(refresh: true),
                      ),
                      SizedBox(width: 12),
                      _buildHeaderButton(
                        icon: Icons.more_vert,
                        onTap: () => _showDisconnectMenu(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive
              ? Color(0xFF007AFF).withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? Color(0xFF007AFF).withOpacity(0.3)
                : Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? Color(0xFF007AFF) : Colors.white,
          size: 22,
        ),
      ),
    );
  }

  void _showDisconnectMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 5,
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Color(0xFFFF3B30)),
              title: Text(
                'Disconnect Gmail',
                style: TextStyle(
                  fontFamily: 'SF Pro Text',
                  color: Color(0xFFFF3B30),
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _disconnectGmail();
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.9),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search emails...',
                hintStyle: TextStyle(
                  fontFamily: 'SF Pro Text',
                  color: Color(0xFF8E8E93),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 16, right: 12),
                  child: Icon(
                    Icons.search_rounded,
                    color: Color(0xFF8E8E93),
                    size: 22,
                  ),
                ),
                suffixIcon: Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _searchController.clear()),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(0xFF8E8E93).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: Color(0xFF8E8E93),
                              size: 18,
                            ),
                          ),
                        ),
                      if (_searchController.text.isNotEmpty) SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isSearchVisible = false;
                            _searchController.clear();
                          });
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(0xFF8E8E93).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            color: Color(0xFF8E8E93),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                color: Color(0xFF1D1D1F),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationTabs() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  blurRadius: 6,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            padding: EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(child: _buildTab('All', 0)),
                SizedBox(width: 4),
                Expanded(child: _buildTab('Unread', 1)),
                SizedBox(width: 4),
                Expanded(child: _buildTab('Read', 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String text, int index) {
    final filters = ['All', 'Unread', 'Read'];
    final isSelected = _selectedFilter == filters[index];

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filters[index];
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        height: 36,
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    Color(0xFF5AC8FA),
                    Color(0xFF007AFF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Color(0xFF5AC8FA).withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            style: TextStyle(
              fontFamily: 'SF Pro Text',
              color: isSelected ? Colors.white : Color(0xFF6B7280),
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: -0.2,
            ),
            child: Text(text),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailDetailView() {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F7),
      body: Column(
        children: [
          _buildEmailDetailHeader(),
          Expanded(
            child: _isLoadingEmail
                ? _buildEmailContentLoading()
                : _selectedEmail != null
                    ? SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Subject
                              Text(
                                _selectedEmail!['subject'] ?? '(No Subject)',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Text',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1D1D1F),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 20),
                              // From
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: _getAvatarColor(
                                        _selectedEmail!['from']),
                                    radius: 24,
                                    child: Text(
                                      _getInitials(_selectedEmail!['from']),
                                      style: TextStyle(
                                        fontFamily: 'SF Pro Text',
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
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
                                          _parseEmailName(
                                              _selectedEmail!['from']),
                                          style: TextStyle(
                                            fontFamily: 'SF Pro Text',
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: Color(0xFF1D1D1F),
                                          ),
                                        ),
                                        Text(
                                          _parseEmailAddress(
                                              _selectedEmail!['from']),
                                          style: TextStyle(
                                            fontFamily: 'SF Pro Text',
                                            fontSize: 13,
                                            color: Color(0xFF8E8E93),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatDate(_selectedEmail!['date']),
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Text',
                                      fontSize: 13,
                                      color: Color(0xFF8E8E93),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20),
                              Divider(color: Color(0xFFE5E5EA)),
                              SizedBox(height: 20),
                              // Email body
                              HtmlWidget(
                                _selectedEmail!['body'] ??
                                    _selectedEmail!['snippet'] ??
                                    '',
                                textStyle: TextStyle(
                                  fontFamily: 'SF Pro Text',
                                  fontSize: 15,
                                  color: Color(0xFF1D1D1F),
                                  height: 1.5,
                                ),
                              ),
                              // Attachments
                              if (_selectedEmail!['attachments'] != null &&
                                  (_selectedEmail!['attachments'] as List)
                                      .isNotEmpty) ...[
                                SizedBox(height: 24),
                                Divider(color: Color(0xFFE5E5EA)),
                                SizedBox(height: 16),
                                Text(
                                  'Attachments',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Text',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1D1D1F),
                                  ),
                                ),
                                SizedBox(height: 12),
                                ...(_selectedEmail!['attachments'] as List)
                                    .map((attachment) {
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 8),
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF2F2F7),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.attachment,
                                            color: Color(0xFF007AFF), size: 20),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            attachment['filename'] ??
                                                'Attachment',
                                            style: TextStyle(
                                              fontFamily: 'SF Pro Text',
                                              fontSize: 15,
                                              color: Color(0xFF1D1D1F),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.download,
                                              color: Color(0xFF007AFF)),
                                          onPressed: () async {
                                            // TODO: Implement download
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Download feature coming soon'),
                                                backgroundColor:
                                                    Color(0xFF1D1D1F),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ],
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          'No email selected',
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailDetailHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedEmail = null;
                  });
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios,
                    color: Color(0xFF007AFF),
                    size: 18,
                  ),
                ),
              ),
              Spacer(),
              // Reply button
              if (_selectedEmail != null)
                GestureDetector(
                  onTap: () => _showReplyDialog(_selectedEmail!),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.reply,
                      color: Color(0xFF007AFF),
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingExperience() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF5F5F7),
                Color(0xFFF5F5F7),
                Color(0xFFF5F5F7).withOpacity(0.95),
              ],
              stops: [0.0, 0.5 * value, 1.0],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Gmail Icon with Pulsing Effect
              _PulsingGmailIcon(),
              SizedBox(height: 40),
              // Animated Text
              _AnimatedLoadingText(),
              SizedBox(height: 60),
              // Shimmer Email Skeleton Cards
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Animated email icon
          Center(
            child: _PulsingEmailIcon(),
          ),
          SizedBox(height: 32),
          // Shimmer header with staggered animation
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Column(
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
          SizedBox(height: 32),
          Divider(color: Color(0xFFE5E5EA)),
          SizedBox(height: 24),
          // Shimmer body with staggered animation
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Column(
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
        ],
      ),
    );
  }
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
    Future.delayed(Duration(milliseconds: 2000), () {
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
      duration: Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0.0, 0.3),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        _loadingMessages[_currentIndex],
        key: ValueKey(_currentIndex),
        style: TextStyle(
          fontFamily: 'SF Pro Text',
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1D1D1F),
          letterSpacing: -0.2,
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
      duration: Duration(milliseconds: 1500),
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
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFFE5E5EA).withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar shimmer
          _ShimmerBox(
            width: 48,
            height: 48,
            borderRadius: 24,
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
      duration: Duration(milliseconds: 1500),
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
                Color(0xFFE5E5EA).withOpacity(0.3),
                Color(0xFFD1D1D6).withOpacity(0.5),
                Color(0xFFE5E5EA).withOpacity(0.3),
              ],
              stops: [0.0, 0.5, 1.0],
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
      duration: Duration(milliseconds: 1500),
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
      duration: Duration(milliseconds: 2000),
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
                  Color(0xFFE5E5EA)
                      .withOpacity(0.3 + (_pulseAnimation.value - 1.0) * 0.1),
                  Color(0xFFD1D1D6)
                      .withOpacity(0.3 + (_pulseAnimation.value - 1.0) * 0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF007AFF)
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
      duration: Duration(milliseconds: 1200),
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
      duration: Duration(milliseconds: 1800),
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
                  Color(0xFF007AFF)
                      .withOpacity(0.2 + (_pulseAnimation.value - 1.0) * 0.1),
                  Color(0xFF5AC8FA)
                      .withOpacity(0.15 + (_pulseAnimation.value - 1.0) * 0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF007AFF)
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
                color: Color(0xFF007AFF),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ComposeEmailSheet extends StatefulWidget {
  final String? to;
  final String? subject;
  final bool isReply;
  final Function(String, String, String, List<PlatformFile>?) onSend;

  const _ComposeEmailSheet({
    Key? key,
    this.to,
    this.subject,
    this.isReply = false,
    required this.onSend,
  }) : super(key: key);

  @override
  _ComposeEmailSheetState createState() => _ComposeEmailSheetState();
}

class _ComposeEmailSheetState extends State<_ComposeEmailSheet> {
  final _toController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  List<PlatformFile> _attachments = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _toController.text = widget.to ?? '';
    _subjectController.text = widget.subject ?? '';
  }

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        _attachments.addAll(result.files);
      });
    }
  }

  Future<void> _sendEmail() async {
    if (_toController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a recipient')),
      );
      return;
    }

    if (_subjectController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a subject')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    await widget.onSend(
      _toController.text.trim(),
      _subjectController.text.trim(),
      _bodyController.text.trim(),
      _attachments.isEmpty ? null : _attachments,
    );

    setState(() {
      _isSending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                Spacer(),
                Text(
                  widget.isReply ? 'Reply' : 'Compose',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                TextButton(
                  onPressed: _isSending ? null : _sendEmail,
                  child: _isSending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Send'),
                ),
              ],
            ),
          ),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _toController,
                    decoration: InputDecoration(
                      labelText: 'To',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !widget.isReply,
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Attachments
                  if (_attachments.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      children: _attachments.map((file) {
                        return Chip(
                          label: Text(file.name),
                          onDeleted: () {
                            setState(() {
                              _attachments.remove(file);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),
                  ],
                  TextButton.icon(
                    onPressed: _pickAttachments,
                    icon: Icon(Icons.attach_file),
                    label: Text('Attach files'),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _bodyController,
                    decoration: InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 10,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
