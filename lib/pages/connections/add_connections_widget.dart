import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/mobile_chat/mobile_chat_widget.dart';
import '/pages/user_summary/user_summary_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:share_plus/share_plus.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import '/custom_code/actions/index.dart' as actions;
import '/utils/chat_helpers.dart';

class AddConnectionsWidget extends StatefulWidget {
  const AddConnectionsWidget({super.key});

  static String routeName = 'AddConnections';
  static String routePath = '/add-connections';

  @override
  State<AddConnectionsWidget> createState() => _AddConnectionsWidgetState();
}

class _AddConnectionsWidgetState extends State<AddConnectionsWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Track loading states for each user to prevent multiple operations
  final Set<String> _loadingOperations = <String>{};

  // Pagination state variables
  final ScrollController _scrollController = ScrollController();
  List<UsersRecord> _loadedUsers = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMoreUsers = true;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _scrollController.addListener(_onScroll);
    _loadInitialUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
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

  // Scroll listener for pagination
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        _hasMoreUsers &&
        !_isLoadingMore &&
        _searchQuery.isEmpty) {
      _loadMoreUsers();
    }
  }

  // Load initial batch of users
  Future<void> _loadInitialUsers() async {
    if (currentUserReference == null) return;

    setState(() {
      _isInitialLoading = true;
    });

    try {
      // Get current user data to calculate mutual connections
      final currentUserDoc = await currentUserReference!.get();
      final currentUser = UsersRecord.fromSnapshot(currentUserDoc);

      // Fetch a larger batch of users to sort by mutual connections
      // Fetch 50 users to have enough to sort and prioritize
      final users = await queryUsersRecordOnce(
        queryBuilder: (q) => q.limit(100),
        limit: 100,
      );

      // Filter out current user
      final filteredUsers = users
          .where((user) => user.reference != currentUserReference)
          .toList();

      // Calculate mutual connections for each user and create a list with counts
      final usersWithMutuals = filteredUsers.map((user) {
        final mutualCount = _calculateMutualConnections(currentUser, user);
        return MapEntry(user, mutualCount);
      }).toList();

      // Sort by mutual connections count (descending), then by name
      usersWithMutuals.sort((a, b) {
        if (a.value != b.value) {
          return b.value.compareTo(a.value); // More mutuals first
        }
        // If same mutual count, sort alphabetically by name
        return a.key.displayName
            .toLowerCase()
            .compareTo(b.key.displayName.toLowerCase());
      });

      // Take top 30 users
      final topUsers = usersWithMutuals.take(30).map((e) => e.key).toList();

      // Store the last user's document for pagination
      if (topUsers.isNotEmpty) {
        _lastDocument = await topUsers.last.reference.get();
      }

      setState(() {
        _loadedUsers = topUsers;
        _hasMoreUsers = filteredUsers.length >= 30;
        _isInitialLoading = false;
      });
    } catch (e) {
      print('Error loading initial users: $e');
      setState(() {
        _isInitialLoading = false;
        _hasMoreUsers = false;
      });
    }
  }

  // Load more users for pagination
  Future<void> _loadMoreUsers() async {
    if (currentUserReference == null ||
        _lastDocument == null ||
        !_hasMoreUsers ||
        _isLoadingMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Get current user data to calculate mutual connections
      final currentUserDoc = await currentUserReference!.get();
      final currentUser = UsersRecord.fromSnapshot(currentUserDoc);

      // Fetch next batch of users
      Query query = UsersRecord.collection
          .startAfterDocument(_lastDocument!)
          .limit(100); // Fetch 100 to have enough to sort

      final querySnapshot = await query.get();
      final fetchedUsers = querySnapshot.docs
          .map((doc) => UsersRecord.fromSnapshot(doc))
          .where((user) => user.reference != currentUserReference)
          .where((user) => !_loadedUsers
              .any((loaded) => loaded.reference.id == user.reference.id))
          .toList();

      if (fetchedUsers.isEmpty) {
        setState(() {
          _hasMoreUsers = false;
          _isLoadingMore = false;
        });
        return;
      }

      // Calculate mutual connections for each user
      final usersWithMutuals = fetchedUsers.map((user) {
        final mutualCount = _calculateMutualConnections(currentUser, user);
        return MapEntry(user, mutualCount);
      }).toList();

      // Sort by mutual connections count (descending), then by name
      usersWithMutuals.sort((a, b) {
        if (a.value != b.value) {
          return b.value.compareTo(a.value); // More mutuals first
        }
        // If same mutual count, sort alphabetically by name
        return a.key.displayName
            .toLowerCase()
            .compareTo(b.key.displayName.toLowerCase());
      });

      // Take top 30 users from this batch
      final newUsers = usersWithMutuals.take(30).map((e) => e.key).toList();

      if (newUsers.isNotEmpty) {
        // Store the last user's document for pagination
        _lastDocument = await newUsers.last.reference.get();

        setState(() {
          _loadedUsers.addAll(newUsers);
          _hasMoreUsers = fetchedUsers.length >= 30;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _hasMoreUsers = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error loading more users: $e');
      setState(() {
        _isLoadingMore = false;
        _hasMoreUsers = false;
      });
    }
  }

  // Calculate mutual connections between current user and displayed user
  int _calculateMutualConnections(
      UsersRecord currentUser, UsersRecord displayedUser) {
    final currentUserFriends = currentUser.friends.toSet();
    final displayedUserFriends = displayedUser.friends.toSet();
    return currentUserFriends.intersection(displayedUserFriends).length;
  }

  @override
  Widget build(BuildContext context) {
    return SelectionContainer.disabled(
      child: CupertinoPageScaffold(
        backgroundColor: Colors.white,
        child: Container(
          color: Colors.white,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Custom header with iOS 26 native back button
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: Colors.white,
                  child: Row(
                    children: [
                      // Floating back button - iOS 26+ style with liquid glass effects
                      LiquidStretch(
                        stretch: 0.5,
                        interactionScale: 1.05,
                        child: GlassGlow(
                          glowColor: Colors.white24,
                          glowRadius: 1.0,
                          child: AdaptiveFloatingActionButton(
                            mini: true,
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF007AFF),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Icon(
                              CupertinoIcons.chevron_left,
                              size: 17,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Centered title
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Add Connections',
                            style: TextStyle(
                              fontFamily: 'SF Pro Text',
                              color: CupertinoColors.label,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.41,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Invite friends button - iOS 26+ style with liquid glass effects
                      LiquidStretch(
                        stretch: 0.5,
                        interactionScale: 1.05,
                        child: GlassGlow(
                          glowColor: Colors.white24,
                          glowRadius: 1.0,
                          child: AdaptiveFloatingActionButton(
                            mini: true,
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF007AFF),
                            onPressed: () => _showInviteDialog(context),
                            child: const Icon(
                              CupertinoIcons.person_add_solid,
                              size: 17,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Search bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
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
                      autofocus: true,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                      placeholder: 'Search by name or email',
                      placeholderStyle: const TextStyle(
                        fontFamily: 'SF Pro Text',
                        color: CupertinoColors.systemGrey,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        decoration: TextDecoration.none,
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      prefix: const Padding(
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
                              child: const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Icon(
                                  CupertinoIcons.xmark_circle_fill,
                                  color: CupertinoColors.systemGrey,
                                  size: 16,
                                ),
                              ),
                            )
                          : null,
                      style: const TextStyle(
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
                // Recommended text (only show when no search query)
                if (_searchQuery.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Recommended:',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),

                // Content area
                Expanded(
                  child: _buildSearchResults(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (currentUserReference == null) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    return StreamBuilder<UsersRecord>(
      stream: UsersRecord.getDocument(currentUserReference!),
      builder: (context, currentUserSnapshot) {
        if (!currentUserSnapshot.hasData) {
          return Container(
            color: Colors.white,
            child: const Center(
              child: CupertinoActivityIndicator(),
            ),
          );
        }

        final currentUser = currentUserSnapshot.data!;

        // Show dummy profile cards if no search query
        if (_searchQuery.isEmpty) {
          return _buildDummyProfileCards();
        }

        // Fetch all users and filter client-side for real-time suggestions
        return StreamBuilder<List<UsersRecord>>(
          stream: queryUsersRecord(),
          builder: (context, searchSnapshot) {
            // Check for errors first
            if (searchSnapshot.hasError) {
              print('Error searching users: ${searchSnapshot.error}');
              return _buildEmptyState(
                icon: CupertinoIcons.exclamationmark_triangle,
                title: 'Error Loading Users',
                subtitle: 'Please check your connection and try again',
              );
            }

            if (!searchSnapshot.hasData) {
              return Container(
                color: Colors.white,
                child: const Center(
                  child: CupertinoActivityIndicator(),
                ),
              );
            }

            final allUsers = searchSnapshot.data!;
            final searchLower = _searchQuery.toLowerCase();

            // Filter users by search query (case-insensitive) and exclude connected users
            final filteredUsers = allUsers.where((user) {
              if (user.reference == currentUserReference) return false;
              // Exclude already connected users
              if (_isUserConnected(user.reference, currentUser)) return false;
              final displayName = user.displayName.toLowerCase();
              final email = user.email.toLowerCase();
              return displayName.contains(searchLower) ||
                  email.contains(searchLower);
            }).toList();

            if (filteredUsers.isEmpty) {
              return _buildEmptyState(
                icon: CupertinoIcons.search,
                title: 'No Results Found',
                subtitle: 'Try searching with a different term',
              );
            }

            // Calculate mutual connections and sort by mutual count (descending)
            final usersWithMutuals = filteredUsers.map((user) {
              final mutualCount =
                  _calculateMutualConnections(currentUser, user);
              return MapEntry(user, mutualCount);
            }).toList();

            // Sort by mutual connections count (descending), then by name
            usersWithMutuals.sort((a, b) {
              if (a.value != b.value) {
                return b.value.compareTo(a.value); // More mutuals first
              }
              // If same mutual count, sort alphabetically by name
              return a.key.displayName
                  .toLowerCase()
                  .compareTo(b.key.displayName.toLowerCase());
            });

            final sortedUsers = usersWithMutuals.map((e) => e.key).toList();

            return Container(
              color: Colors.white,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.70,
                ),
                itemCount: sortedUsers.length,
                itemBuilder: (context, index) {
                  final user = sortedUsers[index];
                  final mutualCount = usersWithMutuals[index].value;
                  final isConnected =
                      _isUserConnected(user.reference, currentUser);
                  final isSentRequest =
                      _isValidSentRequest(user.reference, currentUser);

                  return _buildProfileCard(
                    user: user,
                    currentUser: currentUser,
                    mutualConnections: mutualCount,
                    isConnected: isConnected,
                    isSentRequest: isSentRequest,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildConnectionCard(UsersRecord user, UsersRecord currentUser,
      {bool isConnected = false,
      bool isSentRequest = false,
      bool hasIncomingRequest = false}) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User avatar
            SizedBox(
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
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
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
            const SizedBox(width: 10),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName.isNotEmpty
                        ? user.displayName
                        : 'Unknown User',
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      color: Color(0xFF000000),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      height: 1.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Bio or job title (can span multiple lines)
                  if (user.bio.isNotEmpty)
                    Text(
                      user.bio,
                      style: const TextStyle(
                        fontFamily: 'SF Pro Display',
                        color: Color(0xFF666666),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontFamily: 'SF Pro Display',
                        color: Color(0xFF666666),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                        decoration: TextDecoration.none,
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
                    color: const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                  shape: BoxShape.circle,
                ),
                child: isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CupertinoActivityIndicator(),
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.paperplane_fill,
                        size: 16,
                        color: Color(0xFF000000),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 6),
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
                    color: const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CupertinoActivityIndicator(color: Colors.white),
                      )
                    : const Text(
                        'Accept',
                        style: TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : () => _declineConnectionRequest(user),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CupertinoActivityIndicator(),
                      )
                    : const Text(
                        'Decline',
                        style: TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF666666),
                          decoration: TextDecoration.none,
                        ),
                      ),
              ),
            ),
          ),
        ],
      );
    } else if (actuallyHasSentRequest) {
      // Show pending state
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Pending',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            decoration: TextDecoration.none,
          ),
        ),
      );
    } else {
      // Connect button
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : () => _sendConnectionRequest(user),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(4),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CupertinoActivityIndicator(color: Colors.white),
                  )
                : const Text(
                    'Connect',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      decoration: TextDecoration.none,
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
            child: const Text(
              'Remove connection',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showRemoveConnectionConfirmation(
      UsersRecord user, UsersRecord currentUser) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Remove Connection'),
        content: Text(
            'Are you sure you want to remove ${user.displayName} from your connections?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _removeConnection(user, currentUser);
            },
            child: const Text('Remove'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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

  Widget _buildInitialsAvatar(UsersRecord user) {
    final initials = user.displayName.isNotEmpty
        ? user.displayName.split(' ').map((name) => name[0]).take(2).join()
        : 'U';

    return Container(
      width: 48,
      height: 48,
      color: CupertinoColors.systemBlue,
      child: Center(
        child: SelectionContainer.disabled(
          child: Text(
            initials.toUpperCase(),
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDummyProfileCards() {
    if (_isInitialLoading) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    if (_loadedUsers.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.person_2,
        title: 'No Users Found',
        subtitle: 'There are no other users to connect with at the moment',
      );
    }

    return StreamBuilder<UsersRecord>(
      stream: UsersRecord.getDocument(currentUserReference!),
      builder: (context, currentUserSnapshot) {
        if (!currentUserSnapshot.hasData) {
          return Container(
            color: Colors.white,
            child: const Center(
              child: CupertinoActivityIndicator(),
            ),
          );
        }

        final currentUser = currentUserSnapshot.data!;

        // Filter out already connected users
        final filteredUsers = _loadedUsers.where((user) {
          return !_isUserConnected(user.reference, currentUser);
        }).toList();

        if (filteredUsers.isEmpty && !_isLoadingMore) {
          return _buildEmptyState(
            icon: CupertinoIcons.person_2,
            title: 'No Recommendations',
            subtitle: 'All available users are already connected',
          );
        }

        return Container(
          color: Colors.white,
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 280,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.70,
            ),
            itemCount: filteredUsers.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == filteredUsers.length) {
                // Loading indicator at the end
                return const Center(
                  child: CupertinoActivityIndicator(),
                );
              }

              final user = filteredUsers[index];
              final mutualCount =
                  _calculateMutualConnections(currentUser, user);
              final isConnected = _isUserConnected(user.reference, currentUser);
              final isSentRequest =
                  _isValidSentRequest(user.reference, currentUser);

              return _buildProfileCard(
                user: user,
                currentUser: currentUser,
                mutualConnections: mutualCount,
                isConnected: isConnected,
                isSentRequest: isSentRequest,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProfileCard({
    required UsersRecord user,
    required UsersRecord currentUser,
    required int mutualConnections,
    required bool isConnected,
    required bool isSentRequest,
  }) {
    final isLoading = _isOperationInProgress(user.reference.id);
    
    // Set fixed character limit for bio/about text (45 characters)
    final rawTitle = user.bio.isNotEmpty ? user.bio : user.email;
    final title = rawTitle.length > 45 
        ? '${rawTitle.substring(0, 42)}...' 
        : rawTitle;
    
    final mutualText = mutualConnections > 0
        ? mutualConnections == 1
            ? '1 mutual connection'
            : '$mutualConnections mutual connections'
        : '';

    return SelectionContainer.disabled(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => UserSummaryWidget(
                userRef: user.reference,
                isEditable: false,
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 8,
                offset: Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Profile picture - centered
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: user.photoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: user.photoUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            memCacheWidth: 240,
                            fadeInDuration: const Duration(milliseconds: 200),
                            fadeOutDuration: const Duration(milliseconds: 100),
                            placeholder: (context, url) => Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF9FAFB),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.person_fill,
                                color: Color(0xFF9CA3AF),
                                size: 40,
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                _buildInitialsAvatarSmall(user),
                          )
                        : _buildInitialsAvatarSmall(user),
                  ),
                ),
                const SizedBox(height: 10),
                // Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    user.displayName.isNotEmpty
                        ? user.displayName
                        : 'Unknown User',
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      height: 1.2,
                      color: Color(0xFF111827),
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                // Title/Bio - Fixed height container to ensure consistent card height
                SizedBox(
                  height: 34,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.1,
                        height: 1.3,
                        color: Color(0xFF6B7280),
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                // Mutual connections
                if (mutualText.isNotEmpty)
                  SizedBox(
                    height: 16,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.person_2_fill,
                            size: 13,
                            color: Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              mutualText,
                              style: const TextStyle(
                                fontFamily: 'SF Pro Text',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.1,
                                height: 1.2,
                                color: Color(0xFF9CA3AF),
                                decoration: TextDecoration.none,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (mutualText.isNotEmpty) const SizedBox(height: 6),
                // Connect button or status
                Container(
                  width: double.infinity,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isConnected
                        ? const Color(0xFFF3F4F6)
                        : isSentRequest
                            ? const Color(0xFFF3F4F6)
                            : const Color(0xFF007AFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isLoading
                          ? null
                          : isConnected
                              ? () => _removeConnection(user, currentUser)
                              : isSentRequest
                                  ? () => _cancelConnectionRequest(user)
                                  : () => _sendConnectionRequest(user),
                      borderRadius: BorderRadius.circular(8),
                      child: Center(
                        child: isLoading
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CupertinoActivityIndicator(
                                  color: isConnected || isSentRequest
                                      ? const Color(0xFF6B7280)
                                      : Colors.white,
                                ),
                              )
                            : Text(
                                isConnected
                                    ? 'Connected'
                                    : isSentRequest
                                        ? 'Pending'
                                        : 'Connect',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Text',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                  color: isConnected || isSentRequest
                                      ? const Color(0xFF6B7280)
                                      : Colors.white,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildInitialsAvatarSmall(UsersRecord user) {
    final initials = user.displayName.isNotEmpty
        ? user.displayName.split(' ').map((name) => name[0]).take(2).join()
        : 'U';

    // Generate a consistent color based on user's name
    final colors = [
      const Color(0xFF007AFF),
      const Color(0xFF5856D6),
      const Color(0xFFAF52DE),
      const Color(0xFFFF2D55),
      const Color(0xFFFF3B30),
      const Color(0xFFFF9500),
      const Color(0xFFFFCC00),
      const Color(0xFF34C759),
      const Color(0xFF5AC8FA),
      const Color(0xFF00C7BE),
    ];
    final colorIndex = user.displayName.hashCode.abs() % colors.length;

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: colors[colorIndex],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SelectionContainer.disabled(
          child: Text(
            initials.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              decoration: TextDecoration.none,
            ),
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
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 80,
                color: CupertinoColors.systemGrey,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.label,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontSize: 16,
                  color: CupertinoColors.secondaryLabel,
                  height: 1.4,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Bulletproof connection logic methods
  bool _isUserConnected(DocumentReference userRef, UsersRecord currentUser) {
    return currentUser.friends.contains(userRef);
  }

  bool _isValidSentRequest(DocumentReference userRef, UsersRecord currentUser) {
    // Check if the sent request is still pending and user is not already connected
    return currentUser.sentRequests.contains(userRef) &&
        !currentUser.friends.contains(userRef);
  }

  // Action methods
  Future<void> _startChat(UsersRecord user) async {
    try {
      final chatToOpen =
          await ChatHelpers.findOrCreateDirectChat(user.reference);

      if (context.mounted) {
        context.pushNamed(
          'Chat',
          queryParameters: {
            'chatDoc': serializeParam(chatToOpen, ParamType.Document),
          }.withoutNulls,
          extra: <String, dynamic>{'chatDoc': chatToOpen},
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting chat: $e'),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    }
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

  Future<void> _cancelConnectionRequest(UsersRecord user) async {
    final userId = user.reference.id;

    // Prevent multiple operations
    if (_isOperationInProgress(userId)) return;

    _startOperation(userId);

    try {
      // Bulletproof check - ensure request exists
      final currentUserDoc = await currentUserReference!.get();
      final currentUserData = UsersRecord.fromSnapshot(currentUserDoc);

      if (!currentUserData.sentRequests.contains(user.reference)) {
        _showErrorMessage('No pending request to ${user.displayName}');
        return;
      }

      // Use a batch write for better performance and atomicity
      final batch = FirebaseFirestore.instance.batch();

      // Update current user: remove from sent_requests
      batch.update(currentUserReference!, {
        'sent_requests': FieldValue.arrayRemove([user.reference]),
      });

      // Update target user: remove from friend_requests
      batch.update(user.reference, {
        'friend_requests': FieldValue.arrayRemove([currentUserReference]),
      });

      await batch.commit();

      if (mounted) {
        _showSuccessMessage('Connection request cancelled');
      }
    } catch (e) {
      print('Error cancelling connection request: $e');
      if (mounted) {
        if (e.toString().contains('permission-denied')) {
          _showErrorMessage(
              'Unable to cancel connection request. This feature requires updated permissions.');
        } else {
          _showErrorMessage(
              'Failed to cancel connection request. Please check your internet connection and try again.');
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

  void _showSuccessMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
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
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  String _getInviteMessage() {
    // Get current user's UID for personalized referral link
    final userUid = currentUserUid.isNotEmpty
        ? currentUserUid
        : (currentUserReference?.id ?? '');

    // Create personalized referral link
    final referralLink = 'https://lona.club/invite/$userUid';

    return 'Hey! I\'ve been using this app named Lona for communication, and it\'s amazing! It really boosts productivity and makes team collaboration so much easier. You should check it out!\n\nJoin me on Lona: $referralLink';
  }

  Future<void> _shareInviteMessage() async {
    // Open native iOS share sheet (like WhatsApp)
    // Get screen size for share position origin
    final size = MediaQuery.of(context).size;
    final sharePositionOrigin = Rect.fromLTWH(
      size.width / 2 - 100,
      size.height / 2,
      200,
      100,
    );

    await Share.share(
      _getInviteMessage(),
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  void _showInviteDialog(BuildContext context) async {
    // Show iOS 26+ adaptive dialog with invite options (iOS 26+ liquid glass effect)
    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Invite Friends',
      message:
          'Share Lona with your friends and boost your team\'s productivity together!',
      icon: 'person.2.fill',
      actions: [
        AlertAction(
          title: 'Cancel',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Share',
          style: AlertActionStyle.primary,
          onPressed: () {
            _shareInviteMessage();
          },
        ),
      ],
    );
  }
}
