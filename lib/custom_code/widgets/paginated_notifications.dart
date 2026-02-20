// Automatic FlutterFlow imports
import '/backend/backend.dart';
// Imports other custom widgets
// Imports custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your widget name, define your parameter, and then add the
// boilerplate code using the green button on the right!

import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:convert';

class PaginatedNotifications extends StatefulWidget {
  const PaginatedNotifications(
      {super.key,
      this.width,
      this.height,
      required this.userRef,
      this.navigationAction});

  final double? width;
  final double? height;
  final DocumentReference userRef;
  final Future Function(String? pageParam, String? pageName)? navigationAction;

  @override
  _PaginatedNotificationsState createState() => _PaginatedNotificationsState();
}

class _PaginatedNotificationsState extends State<PaginatedNotifications> {
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _allNotifications = [];
  final Map<String, Map<String, dynamic>> _userCache = {};
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _lastLoadedIndex = 0;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadInitialNotifications();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadMoreNotifications();
      }
    }
  }

  Future<void> _loadInitialNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String userPath = widget.userRef.path;

      // Load from both collections
      List<Map<String, dynamic>> userNotifications =
          await _loadUserNotifications(userPath, 50);
      List<Map<String, dynamic>> systemNotifications =
          await _loadSystemNotifications(50);

      // Combine and sort
      _allNotifications.clear();
      _allNotifications.addAll(userNotifications);
      _allNotifications.addAll(systemNotifications);
      _allNotifications
          .sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

      // Preload user data for first batch
      await _preloadUserData(_allNotifications.take(20).toList());

      _lastLoadedIndex = _pageSize;
      _hasMore = _allNotifications.length > _pageSize;
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _errorMessage = 'Error loading notifications';
      });
    }

    setState(() => _isLoading = false);
  }

  Future<List<Map<String, dynamic>>> _loadUserNotifications(
      String userPath, int limit) async {
    List<Map<String, dynamic>> notifications = [];

    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('ff_user_push_notifications')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    for (var doc in querySnapshot.docs) {
      Map<String, dynamic> data = Map<String, dynamic>.from(doc.data() as Map);
      String userRefs = data['user_refs'] ?? '';

      if (userRefs.contains(userPath)) {
        data['document_id'] = doc.id;
        data['notification_type'] = 'user';

        // Ensure timestamp is DateTime
        if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
          data['timestamp'] = (data['timestamp'] as Timestamp).toDate();
        }

        // Store sender as DocumentReference if it's a string path
        if (data['sender'] != null && data['sender'] is String) {
          data['sender_ref'] = FirebaseFirestore.instance.doc(data['sender']);
        } else if (data['sender'] != null &&
            data['sender'] is DocumentReference) {
          data['sender_ref'] = data['sender'];
        }

        notifications.add(data);
      }
    }

    return notifications;
  }

  Future<List<Map<String, dynamic>>> _loadSystemNotifications(int limit) async {
    List<Map<String, dynamic>> notifications = [];

    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('ff_push_notifications')
        .where('target_audience', isEqualTo: 'All')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    for (var doc in querySnapshot.docs) {
      Map<String, dynamic> data = Map<String, dynamic>.from(doc.data() as Map);
      data['document_id'] = doc.id;
      data['notification_type'] = 'system';

      // Ensure timestamp is DateTime
      if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
        data['timestamp'] = (data['timestamp'] as Timestamp).toDate();
      }

      notifications.add(data);
    }

    return notifications;
  }

  Future<void> _preloadUserData(
      List<Map<String, dynamic>> notifications) async {
    Set<DocumentReference> userRefs = {};

    for (var notification in notifications) {
      if (notification['sender_ref'] != null &&
          notification['sender_ref'] is DocumentReference) {
        userRefs.add(notification['sender_ref']);
      }
    }

    // Batch fetch user data
    List<Future<void>> futures = [];
    for (DocumentReference ref in userRefs) {
      String path = ref.path;
      if (!_userCache.containsKey(path)) {
        futures.add(_fetchUserData(ref));
      }
    }

    await Future.wait(futures);
  }

  Future<void> _fetchUserData(DocumentReference userRef) async {
    try {
      DocumentSnapshot userDoc = await userRef.get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        _userCache[userRef.path] = userData;
        print(
            'Cached user data for ${userRef.path}: photo_url = ${userData['photo_url']}');
      }
    } catch (e) {
      print('Error loading user data for ${userRef.path}: $e');
    }
  }

  void _loadMoreNotifications() {
    if (_lastLoadedIndex < _allNotifications.length) {
      setState(() {
        _isLoading = true;
      });

      int endIndex =
          (_lastLoadedIndex + _pageSize).clamp(0, _allNotifications.length);
      _preloadUserData(_allNotifications.sublist(_lastLoadedIndex, endIndex))
          .then((_) {
        setState(() {
          _lastLoadedIndex = endIndex;
          _hasMore = _lastLoadedIndex < _allNotifications.length;
          _isLoading = false;
        });
      });
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) async {
    if (widget.navigationAction == null) return;

    String? pageName = notification['initial_page_name'];
    String? parameterData = notification['parameter_data'];
    String? paramValue;

    // Check if we have a valid page name to navigate to
    if (pageName == null || pageName.isEmpty) {
      print('No page name provided for navigation');
      return;
    }

    // Parse parameter data if it exists
    if (parameterData != null && parameterData.isNotEmpty) {
      try {
        // Parse the JSON parameter data
        Map<String, dynamic> params = json.decode(parameterData);

        // Get the first value from the parameters
        if (params.isNotEmpty) {
          var firstValue = params.values.first;

          // Extract just the ID from the path (e.g., "chats/rumviYLDNOoTNhp7Ei6D" -> "rumviYLDNOoTNhp7Ei6D")
          if (firstValue is String) {
            if (firstValue.contains('/')) {
              paramValue = firstValue.split('/').last;
            } else {
              paramValue = firstValue;
            }
          }
        }
      } catch (e) {
        print('Error parsing parameter data: $e');
      }
    }

    // For certain page types, parameter is required
    bool isParameterRequired = ['EventDetail', 'ChatDetail'].contains(pageName);

    if (isParameterRequired && (paramValue == null || paramValue.isEmpty)) {
      print('Required parameter missing for $pageName navigation');
      return;
    }

    // Call the navigation action with both parameters
    print('Navigating to page: $pageName with param: $paramValue');
    await widget.navigationAction!(paramValue, pageName);
  }

  String _getTimeAgo(DateTime timestamp) {
    return timeago.format(timestamp, allowFromNow: true);
  }

  String _getGroupLabel(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return 'TODAY';
    } else if (difference.inDays == 1) {
      return 'YESTERDAY';
    } else if (difference.inDays <= 7) {
      return 'LAST WEEK';
    } else if (difference.inDays <= 30) {
      return 'LAST MONTH';
    } else {
      return 'OLDER';
    }
  }

  Widget _buildAvatar(Map<String, dynamic> notification) {
    // For system notifications
    if (notification['notification_type'] == 'system') {
      return Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue,
        ),
        child: const Icon(
          Icons.notifications,
          color: Colors.white,
          size: 20,
        ),
      );
    }

    // Get user data from cache
    DocumentReference? senderRef = notification['sender_ref'];
    Map<String, dynamic>? userData;
    String displayName = 'User';

    if (senderRef != null) {
      userData = _userCache[senderRef.path];
      displayName = userData?['display_name'] ?? 'User';
    }

    String? photoUrl = userData?['photo_url'];

    // If we have a photo URL, display it
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: photoUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[300],
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) {
              print('Error loading image: $url - $error');
              return Container(
                color: Colors.grey[300],
                child: Center(
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // Fallback to initial letter
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
      ),
      child: Center(
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    DateTime timestamp = notification['timestamp'] ?? DateTime.now();
    String timeAgo = _getTimeAgo(timestamp);

    // Get sender name from cache
    String senderName = 'System';
    if (notification['sender_ref'] != null &&
        notification['sender_ref'] is DocumentReference) {
      DocumentReference senderRef = notification['sender_ref'];
      Map<String, dynamic>? userData = _userCache[senderRef.path];
      senderName = userData?['display_name'] ?? 'User';
    }

    // Check if this notification is clickable
    String? pageName = notification['initial_page_name'];
    String? parameterData = notification['parameter_data'];
    bool isClickable = pageName != null && pageName.isNotEmpty;

    // For certain page types, also check if parameter exists
    if (isClickable && ['EventDetail', 'ChatDetail'].contains(pageName)) {
      isClickable = parameterData != null && parameterData.isNotEmpty;
    }

    // Check if this is a group chat notification
    bool isGroupChatNotification = pageName?.toLowerCase() == 'chatdetail' &&
        notification['notification_title'] != null &&
        notification['notification_title'] != senderName;

    return InkWell(
      onTap: isClickable ? () => _handleNotificationTap(notification) : null,
      child: Opacity(
        opacity: isClickable ? 1.0 : 0.8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(notification),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                              children: [
                                // For group chat notifications, show group name on line 1
                                if (isGroupChatNotification)
                                  TextSpan(
                                    text: notification['notification_title'] ??
                                        '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  )
                                // For other notifications, show sender name
                                else
                                  TextSpan(
                                    text: senderName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                // Only show notification title if it's not a chat notification
                                if (pageName?.toLowerCase() != 'chatdetail' &&
                                    !isGroupChatNotification)
                                  TextSpan(
                                    text:
                                        ' ${notification['notification_title'] ?? ''}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.normal),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    // For group chat notifications, show "New Message" on line 2
                    if (isGroupChatNotification) ...[
                      const SizedBox(height: 4),
                      Text(
                        'New Message',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _getNotificationText(notification,
                          senderName: senderName,
                          isGroupChat: isGroupChatNotification),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getNotificationText(Map<String, dynamic> notification,
      {String? senderName, bool isGroupChat = false}) {
    String? pageName = notification['initial_page_name'];

    // For group chat notifications, show "SenderName: message"
    if (isGroupChat && senderName != null) {
      String messageText = notification['notification_text'] ?? '';
      return '$senderName: $messageText';
    }

    // For other chat notifications (DMs), just show the message
    if (pageName?.toLowerCase() == 'chatdetail') {
      return notification['notification_text'] ?? '';
    }

    // For other notifications, use the original text
    return notification['notification_text'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 400,
      color: Colors.transparent,
      child: _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_errorMessage!),
                  ElevatedButton(
                    onPressed: _loadInitialNotifications,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _allNotifications.isEmpty && _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _allNotifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _lastLoadedIndex + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _lastLoadedIndex) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (index >= _allNotifications.length) {
                          return const SizedBox();
                        }

                        Map<String, dynamic> notification =
                            _allNotifications[index];
                        DateTime timestamp =
                            notification['timestamp'] ?? DateTime.now();
                        String currentGroup = _getGroupLabel(timestamp);
                        String? previousGroup;

                        if (index > 0) {
                          DateTime prevTimestamp = _allNotifications[index - 1]
                                  ['timestamp'] ??
                              DateTime.now();
                          previousGroup = _getGroupLabel(prevTimestamp);
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (previousGroup != currentGroup ||
                                index == 0) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: Text(
                                  currentGroup,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                            _buildNotificationItem(notification),
                            if (index < _lastLoadedIndex - 1)
                              const Divider(height: 1, indent: 68),
                          ],
                        );
                      },
                    ),
    );
  }
}
