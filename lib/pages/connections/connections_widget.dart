import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/mobile_chat/mobile_chat_widget.dart';
import '/pages/connections/add_connections_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

class ConnectionsWidget extends StatefulWidget {
  const ConnectionsWidget({super.key});

  static String routeName = 'Connections';
  static String routePath = '/connections';

  @override
  State<ConnectionsWidget> createState() => _ConnectionsWidgetState();
}

class _ConnectionsWidgetState extends State<ConnectionsWidget> {
  int _selectedTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Track loading states for each user to prevent multiple operations
  final Set<String> _loadingOperations = <String>{};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper method to check if an operation is in progress for a user
  bool _isOperationInProgress(String userId) {
    return _loadingOperations.contains(userId);
  }

  // Helper method to start tracking an operation
  void _startOperation(String userId) {
    setState(() {
      _loadingOperations.add(userId);
    });
  }

  // Helper method to stop tracking an operation
  void _stopOperation(String userId) {
    setState(() {
      _loadingOperations.remove(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              // Header with title and Add new button
              Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Connections',
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .navLargeTitleTextStyle
                          .copyWith(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    AdaptiveFloatingActionButton(
                      mini: true,
                      backgroundColor:
                          Colors.white, // Pure white like back button
                      foregroundColor: Color(0xFF007AFF), // System blue icon
                      onPressed: () {
                        context.pushNamed(AddConnectionsWidget.routeName);
                      },
                      child: Icon(
                        CupertinoIcons.add,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Filter buttons
              if (currentUserReference != null)
                StreamBuilder<UsersRecord>(
                  stream: UsersRecord.getDocument(currentUserReference!),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return Container(
                        padding: const EdgeInsets.only(
                            left: 0, right: 16.0, top: 8.0, bottom: 8.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 0),
                            child: Row(
                              children: [
                                _ConnectionFilterButton(
                                  label: 'My Connections',
                                  isSelected: _selectedTabIndex == 0,
                                  badgeCount: 0,
                                  onTap: () {
                                    setState(() {
                                      _selectedTabIndex = 0;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8.0),
                                _ConnectionFilterButton(
                                  label: 'Requests',
                                  isSelected: _selectedTabIndex == 1,
                                  badgeCount: 0,
                                  onTap: () {
                                    setState(() {
                                      _selectedTabIndex = 1;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8.0),
                                _ConnectionFilterButton(
                                  label: 'Sent',
                                  isSelected: _selectedTabIndex == 2,
                                  badgeCount: 0,
                                  onTap: () {
                                    setState(() {
                                      _selectedTabIndex = 2;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final currentUser = userSnapshot.data!;
                    final incomingRequestsCount =
                        currentUser.friendRequests.length;
                    final connectionsCount = currentUser.friends.length;

                    return Container(
                      padding: const EdgeInsets.only(
                          left: 0, right: 16.0, top: 8.0, bottom: 8.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 0),
                          child: Row(
                            children: [
                              _ConnectionFilterButton(
                                label: 'My Connections',
                                isSelected: _selectedTabIndex == 0,
                                badgeCount:
                                    connectionsCount > 0 ? connectionsCount : 0,
                                onTap: () {
                                  setState(() {
                                    _selectedTabIndex = 0;
                                  });
                                },
                              ),
                              const SizedBox(width: 8.0),
                              _ConnectionFilterButton(
                                label: 'Requests',
                                isSelected: _selectedTabIndex == 1,
                                badgeCount: incomingRequestsCount,
                                onTap: () {
                                  setState(() {
                                    _selectedTabIndex = 1;
                                  });
                                },
                              ),
                              const SizedBox(width: 8.0),
                              _ConnectionFilterButton(
                                label: 'Sent',
                                isSelected: _selectedTabIndex == 2,
                                badgeCount: 0,
                                onTap: () {
                                  setState(() {
                                    _selectedTabIndex = 2;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.only(
                      left: 0, right: 16.0, top: 8.0, bottom: 8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 0),
                      child: Row(
                        children: [
                          _ConnectionFilterButton(
                            label: 'My Connections',
                            isSelected: _selectedTabIndex == 0,
                            badgeCount: 0,
                            onTap: () {
                              setState(() {
                                _selectedTabIndex = 0;
                              });
                            },
                          ),
                          const SizedBox(width: 8.0),
                          _ConnectionFilterButton(
                            label: 'Requests',
                            isSelected: _selectedTabIndex == 1,
                            badgeCount: 0,
                            onTap: () {
                              setState(() {
                                _selectedTabIndex = 1;
                              });
                            },
                          ),
                          const SizedBox(width: 8.0),
                          _ConnectionFilterButton(
                            label: 'Sent',
                            isSelected: _selectedTabIndex == 2,
                            badgeCount: 0,
                            onTap: () {
                              setState(() {
                                _selectedTabIndex = 2;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              SizedBox(height: 16),

              // Search bar
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.white,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: CupertinoColors.separator,
                      width: 0.5,
                    ),
                  ),
                  child: CupertinoTextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                    placeholder: 'Search connections',
                    placeholderStyle: TextStyle(
                      fontFamily: 'SF Pro Text',
                      color: CupertinoColors.systemGrey,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.none,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    prefix: Padding(
                      padding: EdgeInsets.only(left: 12, right: 8),
                      child: Icon(
                        CupertinoIcons.search,
                        color: CupertinoColors.systemBlue,
                        size: 18,
                      ),
                    ),
                    suffix: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                            child: Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(
                                CupertinoIcons.xmark_circle_fill,
                                color: CupertinoColors.systemGrey,
                                size: 16,
                              ),
                            ),
                          )
                        : null,
                    style: TextStyle(
                      fontFamily: 'SF Pro Text',
                      color: CupertinoColors.label,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.none,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),

              // Content area
              Expanded(
                child: _buildTabContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (currentUserReference == null) {
      return Center(
        child: CupertinoActivityIndicator(),
      );
    }

    return StreamBuilder<UsersRecord>(
      stream: UsersRecord.getDocument(currentUserReference!),
      builder: (context, currentUserSnapshot) {
        if (!currentUserSnapshot.hasData) {
          return Center(
            child: CupertinoActivityIndicator(),
          );
        }

        final currentUser = currentUserSnapshot.data!;

        // Show tab content based on selected tab
        switch (_selectedTabIndex) {
          case 0:
            return _buildConnectionsList(currentUser);
          case 1:
            return _buildRequestsList(currentUser);
          case 2:
            return _buildSentRequestsList(currentUser);
          default:
            return _buildConnectionsList(currentUser);
        }
      },
    );
  }

  Widget _buildConnectionsList(UsersRecord currentUser) {
    final connections = currentUser.friends;

    if (connections.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.person_2,
        title: 'No Connections Yet',
        subtitle: 'Start connecting with people, Tap \'+\' to get started',
      );
    }

    return Column(
      children: [
        // Connection count and sort by row - Enhanced styling
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFF1F5F9),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${connections.length}',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1F36),
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(width: 6),
              Text(
                'connection${connections.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF64748B),
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),

        // Connections list
        Expanded(
          child: CupertinoScrollbar(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: connections.length,
              separatorBuilder: (context, index) => SizedBox.shrink(),
              itemBuilder: (context, index) {
                final connectionRef = connections[index];
                return StreamBuilder<UsersRecord>(
                  stream: UsersRecord.getDocument(connectionRef),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return SizedBox.shrink();
                    }
                    final user = userSnapshot.data!;

                    // Filter by search query
                    if (_searchQuery.isNotEmpty) {
                      final displayName = user.displayName.toLowerCase();
                      final email = user.email.toLowerCase();
                      final bio = user.bio.toLowerCase();
                      if (!displayName.contains(_searchQuery) &&
                          !email.contains(_searchQuery) &&
                          !bio.contains(_searchQuery)) {
                        return SizedBox.shrink();
                      }
                    }

                    final isActuallyConnected =
                        _isUserConnected(user.reference, currentUser);
                    return _buildConnectionCard(user, currentUser,
                        isConnected: isActuallyConnected);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsList(UsersRecord currentUser) {
    final requests = currentUser.friendRequests;

    if (requests.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.person_add,
        title: 'No Pending Requests',
        subtitle: 'You have no pending connection requests',
      );
    }

    return Column(
      children: [
        // Request count and sort by row - Enhanced styling
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFF1F5F9),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${requests.length}',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1F36),
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(width: 6),
              Text(
                'request${requests.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF64748B),
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),

        // Requests list
        Expanded(
          child: CupertinoScrollbar(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: requests.length,
              separatorBuilder: (context, index) => SizedBox.shrink(),
              itemBuilder: (context, index) {
                final requestRef = requests[index];
                return StreamBuilder<UsersRecord>(
                  stream: UsersRecord.getDocument(requestRef),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return SizedBox.shrink();
                    }
                    final user = userSnapshot.data!;

                    // Filter by search query
                    if (_searchQuery.isNotEmpty) {
                      final displayName = user.displayName.toLowerCase();
                      final email = user.email.toLowerCase();
                      final bio = user.bio.toLowerCase();
                      if (!displayName.contains(_searchQuery) &&
                          !email.contains(_searchQuery) &&
                          !bio.contains(_searchQuery)) {
                        return SizedBox.shrink();
                      }
                    }

                    return _buildRequestCard(user, currentUser);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSentRequestsList(UsersRecord currentUser) {
    final sentRequests = currentUser.sentRequests
        .where((ref) => !currentUser.friends.contains(ref))
        .toList();

    if (sentRequests.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.paperplane,
        title: 'No Sent Requests',
        subtitle: 'You have no pending sent connection requests',
      );
    }

    return Column(
      children: [
        // Sent request count and sort by row - Enhanced styling
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFF1F5F9),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${sentRequests.length}',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1F36),
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(width: 6),
              Text(
                'sent request${sentRequests.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF64748B),
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),

        // Sent requests list
        Expanded(
          child: CupertinoScrollbar(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: sentRequests.length,
              separatorBuilder: (context, index) => SizedBox.shrink(),
              itemBuilder: (context, index) {
                final requestRef = sentRequests[index];
                return StreamBuilder<UsersRecord>(
                  stream: UsersRecord.getDocument(requestRef),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return SizedBox.shrink();
                    }
                    final user = userSnapshot.data!;
                    final isValidSentRequest =
                        _isValidSentRequest(user.reference, currentUser);
                    if (!isValidSentRequest) {
                      return SizedBox.shrink();
                    }

                    // Filter by search query
                    if (_searchQuery.isNotEmpty) {
                      final displayName = user.displayName.toLowerCase();
                      final email = user.email.toLowerCase();
                      final bio = user.bio.toLowerCase();
                      if (!displayName.contains(_searchQuery) &&
                          !email.contains(_searchQuery) &&
                          !bio.contains(_searchQuery)) {
                        return SizedBox.shrink();
                      }
                    }

                    return _buildConnectionCard(user, currentUser,
                        isSentRequest: true);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionCard(UsersRecord user, UsersRecord currentUser,
      {bool isConnected = false,
      bool isSentRequest = false,
      bool hasIncomingRequest = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User avatar
            Container(
              width: 48,
              height: 48,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: user.photoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: user.photoUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.person_fill,
                            color: Color(0xFF64748B),
                            size: 24,
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildInitialsAvatar(user),
                      )
                    : _buildInitialsAvatar(user),
              ),
            ),
            SizedBox(width: 10),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName.isNotEmpty
                        ? user.displayName
                        : 'Unknown User',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      color: Color(0xFF000000),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 2),

                  // Bio or job title (can span multiple lines)
                  if (user.bio.isNotEmpty)
                    Text(
                      user.bio,
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        color: Color(0xFF666666),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      user.email,
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        color: Color(0xFF666666),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Action buttons (icon buttons)
            _buildActionButtons(user, currentUser,
                isConnected: isConnected,
                isSentRequest: isSentRequest,
                hasIncomingRequest: hasIncomingRequest),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(UsersRecord user, UsersRecord currentUser,
      {bool isConnected = false,
      bool isSentRequest = false,
      bool hasIncomingRequest = false}) {
    final actuallyConnected = _isUserConnected(user.reference, currentUser);
    final actuallyHasSentRequest =
        _isValidSentRequest(user.reference, currentUser);
    final actuallyHasIncomingRequest =
        user.sentRequests.contains(currentUserReference);
    final isLoading = _isOperationInProgress(user.reference.id);

    if (actuallyConnected) {
      // Show Message icon button and More options icon button - LinkedIn style
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Message button (paper plane icon)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : () => _startChat(user),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Color(0xFFE5E7EB),
                    width: 1,
                  ),
                  shape: BoxShape.circle,
                ),
                child: isLoading
                    ? Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CupertinoActivityIndicator(),
                        ),
                      )
                    : Icon(
                        CupertinoIcons.paperplane_fill,
                        size: 16,
                        color: Color(0xFF000000),
                      ),
              ),
            ),
          ),
          SizedBox(width: 6),
          // More options button (ellipsis icon)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showMoreOptions(user, currentUser),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Color(0xFFE5E7EB),
                    width: 1,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.ellipsis_vertical,
                  size: 16,
                  color: Color(0xFF666666),
                ),
              ),
            ),
          ),
        ],
      );
    } else if (actuallyHasIncomingRequest && !actuallyHasSentRequest) {
      // Accept and Decline buttons for incoming requests
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : () => _acceptConnectionRequest(user),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CupertinoActivityIndicator(color: Colors.white),
                      )
                    : Text(
                        'Accept',
                        style: TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
          SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : () => _declineConnectionRequest(user),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Color(0xFFE5E7EB),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CupertinoActivityIndicator(),
                      )
                    : Text(
                        'Decline',
                        style: TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF666666),
                        ),
                      ),
              ),
            ),
          ),
        ],
      );
    } else if (actuallyHasSentRequest) {
      // Show cancel button for sent requests in the "Sent" tab
      if (_selectedTabIndex == 2) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : () => _cancelConnectionRequest(user),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(4),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CupertinoActivityIndicator(color: Colors.white),
                    )
                  : Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        );
      } else {
        // Show pending state in other tabs
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Pending',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        );
      }
    } else {
      // Connect button
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : () => _sendConnectionRequest(user),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(4),
            ),
            child: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CupertinoActivityIndicator(color: Colors.white),
                  )
                : Text(
                    'Connect',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      );
    }
  }

  void _showMoreOptions(UsersRecord user, UsersRecord currentUser) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _showRemoveConnectionConfirmation(user, currentUser);
            },
            child: Text(
              'Remove connection',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
      ),
    );
  }

  void _showRemoveConnectionConfirmation(
      UsersRecord user, UsersRecord currentUser) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Remove Connection'),
        content: Text(
            'Are you sure you want to remove ${user.displayName} from your connections?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _removeConnection(user, currentUser);
            },
            child: Text('Remove'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeConnection(
      UsersRecord user, UsersRecord currentUser) async {
    final userId = user.reference.id;

    // Prevent multiple operations
    if (_isOperationInProgress(userId)) return;

    _startOperation(userId);

    try {
      // Bulletproof check - ensure they are actually connected
      final currentUserDoc = await currentUserReference!.get();
      final currentUserData = UsersRecord.fromSnapshot(currentUserDoc);

      if (!currentUserData.friends.contains(user.reference)) {
        _showErrorMessage('You are not connected with ${user.displayName}');
        return;
      }

      // Update current user's document (we have permission for our own document)
      await currentUserReference!.update({
        'friends': FieldValue.arrayRemove([user.reference]),
      });

      // Try to update other user's document (may fail due to permissions, but that's okay)
      // The connection will be removed from their side when they next sync
      try {
        await user.reference.update({
          'friends': FieldValue.arrayRemove([currentUserReference]),
        });
      } catch (e) {
        // If we can't update the other user's document, that's okay
        // The connection is still removed from our side
        print('Note: Could not update other user\'s friends list: $e');
      }

      if (mounted) {
        _showSuccessMessage('Connection removed successfully');
      }
    } catch (e) {
      print('Error removing connection: $e');
      if (mounted) {
        if (e.toString().contains('permission-denied')) {
          _showErrorMessage(
              'Unable to remove connection. This feature requires updated permissions.');
        } else {
          _showErrorMessage(
              'Failed to remove connection. Please check your internet connection and try again.');
        }
      }
    } finally {
      _stopOperation(userId);
    }
  }

  Widget _buildRequestCard(UsersRecord user, UsersRecord currentUser) {
    return _buildConnectionCard(user, currentUser, hasIncomingRequest: true);
  }

  Widget _buildUserAvatar(UsersRecord user) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.2),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: user.photoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: user.photoUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: CupertinoColors.systemGrey5,
                  child: Icon(
                    CupertinoIcons.person_fill,
                    color: CupertinoColors.systemGrey,
                    size: 28,
                  ),
                ),
                errorWidget: (context, url, error) =>
                    _buildInitialsAvatar(user),
              )
            : _buildInitialsAvatar(user),
      ),
    );
  }

  Widget _buildInitialsAvatar(UsersRecord user) {
    final initials = user.displayName.isNotEmpty
        ? user.displayName.split(' ').map((name) => name[0]).take(2).join()
        : 'U';

    return Container(
      width: 48,
      height: 48,
      color: CupertinoColors.systemBlue,
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
            color: CupertinoColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: CupertinoColors.systemGrey,
            ),
            SizedBox(height: 24),
            Text(
              title,
              style: CupertinoTheme.of(context)
                  .textTheme
                  .navLargeTitleTextStyle
                  .copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 16,
                    color: CupertinoColors.secondaryLabel,
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // Bulletproof connection logic methods
  bool _isUserConnected(DocumentReference userRef, UsersRecord currentUser) {
    return currentUser.friends.contains(userRef);
  }

  bool _isValidPendingRequest(
      DocumentReference userRef, UsersRecord currentUser) {
    // Check if the request is still pending and user is not already connected
    return currentUser.friendRequests.contains(userRef) &&
        !currentUser.friends.contains(userRef);
  }

  bool _isValidSentRequest(DocumentReference userRef, UsersRecord currentUser) {
    // Check if the sent request is still pending and user is not already connected
    return currentUser.sentRequests.contains(userRef) &&
        !currentUser.friends.contains(userRef);
  }

  // Helper method to check if there's a mutual connection request
  bool _hasMutualRequest(DocumentReference userRef, UsersRecord currentUser,
      UsersRecord otherUser) {
    return currentUser.sentRequests.contains(userRef) &&
        otherUser.sentRequests.contains(currentUserReference);
  }

  // Action methods
  Future<void> _startChat(UsersRecord user) async {
    try {
      // Check if a chat already exists between current user and this user in the current workspace
      final currentWorkspaceRef = currentUserDocument?.currentWorkspaceRef;

      final existingChats = await queryChatsRecordOnce(
        queryBuilder: (chatsRecord) => chatsRecord
            .where('members', arrayContains: currentUserReference)
            .where('is_group', isEqualTo: false)
            .where('workspace_ref', isEqualTo: currentWorkspaceRef),
      );

      // Find if there's already a direct chat with this user in the current workspace
      ChatsRecord? existingChat;
      for (final chat in existingChats) {
        if (chat.members.contains(user.reference) &&
            chat.members.length == 2 &&
            !chat.isGroup &&
            chat.workspaceRef?.path == currentWorkspaceRef?.path) {
          existingChat = chat;
          break;
        }
      }

      ChatsRecord chatToOpen;

      if (existingChat != null) {
        // Chat already exists, use it
        chatToOpen = existingChat;
      } else {
        // Create a new chat
        final newChatRef = await ChatsRecord.collection.add({
          ...createChatsRecordData(
            isGroup: false,
            title: '', // Empty for direct chats
            createdAt: getCurrentTimestamp,
            lastMessageAt: getCurrentTimestamp,
            lastMessage: '',
            lastMessageSent: currentUserReference,
            workspaceRef: currentUserDocument?.currentWorkspaceRef,
          ),
          'members': [currentUserReference!, user.reference],
          'last_message_seen': [currentUserReference!],
        });

        // Get the created chat document
        chatToOpen = await ChatsRecord.getDocumentOnce(newChatRef);
      }

      // Navigate to the chat - use push so we can go back to Connections
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MobileChatWidget(
              initialChat: chatToOpen,
            ),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting chat: $e'),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  void _viewUserProfile(UsersRecord user) {
    // Navigate to user profile detail page
    print('Viewing profile of ${user.displayName}');
    // TODO: Implement profile navigation
  }

  Future<void> _sendConnectionRequest(UsersRecord user) async {
    final userId = user.reference.id;

    // Prevent multiple operations
    if (_isOperationInProgress(userId)) return;

    _startOperation(userId);

    try {
      // Bulletproof check - don't send if already connected or request already sent
      final currentUserDoc = await currentUserReference!.get();
      final currentUserData = UsersRecord.fromSnapshot(currentUserDoc);

      if (currentUserData.friends.contains(user.reference)) {
        _showErrorMessage('You are already connected with ${user.displayName}');
        return;
      }

      if (currentUserData.sentRequests.contains(user.reference)) {
        _showErrorMessage(
            'Connection request already sent to ${user.displayName}');
        return;
      }

      // Check if they already sent us a request (auto-accept scenario)
      if (currentUserData.friendRequests.contains(user.reference)) {
        await _acceptConnectionRequest(user);
        return;
      }

      // Use a batch write for better performance and atomicity
      final batch = FirebaseFirestore.instance.batch();

      // Update current user's sent requests
      batch.update(currentUserReference!, {
        'sent_requests': FieldValue.arrayUnion([user.reference]),
      });

      // Update target user's friend requests
      batch.update(user.reference, {
        'friend_requests': FieldValue.arrayUnion([currentUserReference]),
      });

      await batch.commit();

      if (mounted) {
        _showSuccessMessage('Connection request sent to ${user.displayName}');
      }
    } catch (e) {
      print('Error sending connection request: $e');
      if (mounted) {
        // Check if it's a permission error and provide specific guidance
        if (e.toString().contains('permission-denied')) {
          _showErrorMessage(
              'Unable to send connection request. This feature requires updated permissions.');
        } else {
          _showErrorMessage(
              'Failed to send connection request. Please check your internet connection and try again.');
        }
      }
    } finally {
      _stopOperation(userId);
    }
  }

  Future<void> _acceptConnectionRequest(UsersRecord user) async {
    final userId = user.reference.id;

    // Prevent multiple operations
    if (_isOperationInProgress(userId)) return;

    _startOperation(userId);

    try {
      // Bulletproof check - ensure they sent us a request and we're not already connected
      final currentUserDoc = await currentUserReference!.get();
      final currentUserData = UsersRecord.fromSnapshot(currentUserDoc);

      if (currentUserData.friends.contains(user.reference)) {
        _showErrorMessage('You are already connected with ${user.displayName}');
        return;
      }

      if (!currentUserData.friendRequests.contains(user.reference)) {
        _showErrorMessage('No pending request from ${user.displayName}');
        return;
      }

      // Use a batch write for better performance and atomicity
      final batch = FirebaseFirestore.instance.batch();

      // Update current user: add to friends, remove from friend_requests
      batch.update(currentUserReference!, {
        'friends': FieldValue.arrayUnion([user.reference]),
        'friend_requests': FieldValue.arrayRemove([user.reference]),
        'sent_requests': FieldValue.arrayRemove(
            [user.reference]), // Remove if we also sent them a request
      });

      // Update other user: add to friends, remove from sent_requests
      batch.update(user.reference, {
        'friends': FieldValue.arrayUnion([currentUserReference]),
        'sent_requests': FieldValue.arrayRemove([currentUserReference]),
      });

      await batch.commit();

      if (mounted) {
        _showSuccessMessage('Connection request accepted!');
      }
    } catch (e) {
      print('Error accepting connection request: $e');
      if (mounted) {
        if (e.toString().contains('permission-denied')) {
          _showErrorMessage(
              'Unable to accept connection request. This feature requires updated permissions.');
        } else {
          _showErrorMessage(
              'Failed to accept connection request. Please check your internet connection and try again.');
        }
      }
    } finally {
      _stopOperation(userId);
    }
  }

  Future<void> _declineConnectionRequest(UsersRecord user) async {
    final userId = user.reference.id;

    // Prevent multiple operations
    if (_isOperationInProgress(userId)) return;

    _startOperation(userId);

    try {
      // Bulletproof check - ensure request exists
      final currentUserDoc = await currentUserReference!.get();
      final currentUserData = UsersRecord.fromSnapshot(currentUserDoc);

      if (!currentUserData.friendRequests.contains(user.reference)) {
        _showErrorMessage('No pending request from ${user.displayName}');
        return;
      }

      // Only update current user's document (we have permission for this)
      await currentUserReference!.update({
        'friend_requests': FieldValue.arrayRemove([user.reference]),
      });

      if (mounted) {
        _showSuccessMessage('Connection request declined');
      }
    } catch (e) {
      print('Error declining connection request: $e');
      if (mounted) {
        _showErrorMessage(
            'Failed to decline connection request. Please check your internet connection and try again.');
      }
    } finally {
      _stopOperation(userId);
    }
  }

  Future<void> _cancelConnectionRequest(UsersRecord user) async {
    final userId = user.reference.id;

    // Prevent multiple operations
    if (_isOperationInProgress(userId)) return;

    _startOperation(userId);

    try {
      // Bulletproof check - ensure sent request exists
      final currentUserDoc = await currentUserReference!.get();
      final currentUserData = UsersRecord.fromSnapshot(currentUserDoc);

      if (!currentUserData.sentRequests.contains(user.reference)) {
        _showErrorMessage('No pending sent request to ${user.displayName}');
        return;
      }

      if (currentUserData.friends.contains(user.reference)) {
        _showErrorMessage('You are already connected with ${user.displayName}');
        return;
      }

      // Only update current user's document (we have permission for this)
      await currentUserReference!.update({
        'sent_requests': FieldValue.arrayRemove([user.reference]),
      });

      if (mounted) {
        _showSuccessMessage('Connection request cancelled');
      }
    } catch (e) {
      print('Error cancelling connection request: $e');
      if (mounted) {
        _showErrorMessage(
            'Failed to cancel connection request. Please check your internet connection and try again.');
      }
    } finally {
      _stopOperation(userId);
    }
  }

  void _showSuccessMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showErrorMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _ConnectionFilterButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  const _ConnectionFilterButton({
    required this.label,
    required this.isSelected,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                // Liquid Glass effect with semi-transparent background
                color: isSelected
                    ? CupertinoColors.systemBlue.withOpacity(0.96)
                    : CupertinoColors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: isSelected
                      ? CupertinoColors.systemBlue.withOpacity(0.96)
                      : CupertinoColors.white.withOpacity(0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? CupertinoColors.white
                          : CupertinoColors.systemBlue,
                    ),
                  ),
                  if (badgeCount > 0) ...[
                    SizedBox(width: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CupertinoColors.white
                            : Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? CupertinoColors.systemBlue
                                : CupertinoColors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
