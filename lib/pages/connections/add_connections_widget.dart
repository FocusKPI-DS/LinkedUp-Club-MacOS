import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';
import '/pages/desktop_chat/desktop_safe_user_builder.dart';
import '/pages/desktop_chat/rest_poll_builder.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/chat/user_profile_popup/user_profile_popup.dart';
import '/utils/desktop_pointer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
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
import '/utils/open_direct_chat.dart';

const double _kAddConnectionsDialogMaxWidth = 980;
const double _kAddConnectionsDialogMaxHeightFactor = 0.72;
const double _kAddConnectionsDialogInset = 48;
const double _kAddConnectionsDialogPadding = 36;
const double _kAddConnectionsCardSpacing = 14;

Future<void> showAddConnectionsDialog(BuildContext context) async {
  final chat = await showDialog<ChatsRecord>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (dialogContext) => const AddConnectionsWidget(asDialog: true),
  );
  if (chat != null && context.mounted) {
    await openDirectChat(chat, context: context);
  }
}

class AddConnectionsWidget extends StatefulWidget {
  const AddConnectionsWidget({
    super.key,
    this.asDialog = false,
  });

  /// When true, renders as a centered dialog. Defaults to false for the
  /// routed full-page experience. Nullable-safe for hot-reload compatibility.
  final bool? asDialog;

  static String routeName = 'AddConnections';
  static String routePath = '/add-connections';

  @override
  State<AddConnectionsWidget> createState() => _AddConnectionsWidgetState();
}

class _AddConnectionsWidgetState extends State<AddConnectionsWidget> {
  late final bool _asDialog;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Track loading states for each user to prevent multiple operations
  final Set<String> _loadingOperations = <String>{};

  // Pagination state variables
  final ScrollController _scrollController = ScrollController();
  List<UsersRecord> _loadedUsers = [];
  DocumentSnapshot? _lastDocument;
  String? _lastWindowsUserId;
  bool _isLoadingMore = false;
  bool _hasMoreUsers = true;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _asDialog = widget.asDialog ?? false;
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
      final currentUser = await fsGetUserOnce(currentUserReference!);

      // Fetch a larger batch of users to sort by mutual connections
      final users = useWindowsFirestoreRest
          ? await fsQueryUsers(limit: 100)
          : await queryUsersRecordOnce(
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
        if (useWindowsFirestoreRest) {
          _lastWindowsUserId = topUsers.last.reference.id;
        } else {
          _lastDocument = await topUsers.last.reference.get();
        }
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
        (!useWindowsFirestoreRest && _lastDocument == null) ||
        (useWindowsFirestoreRest && _lastWindowsUserId == null) ||
        !_hasMoreUsers ||
        _isLoadingMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Get current user data to calculate mutual connections
      final currentUser = await fsGetUserOnce(currentUserReference!);

      final Iterable<UsersRecord> fetchedUsersIterable;
      if (useWindowsFirestoreRest) {
        fetchedUsersIterable = await fsQueryUsers(
          limit: 100,
          startAfterUserId: _lastWindowsUserId,
        );
      } else {
        Query query = UsersRecord.collection
            .startAfterDocument(_lastDocument!)
            .limit(100);
        final querySnapshot = await query.get();
        fetchedUsersIterable = querySnapshot.docs
            .map((doc) => UsersRecord.fromSnapshot(doc));
      }

      final fetchedUsers = fetchedUsersIterable
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
        if (useWindowsFirestoreRest) {
          _lastWindowsUserId = newUsers.last.reference.id;
        } else {
          _lastDocument = await newUsers.last.reference.get();
        }

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

  int _gridColumnCount(double width) {
    if (width >= 1180) return 4;
    if (width >= 880) return 3;
    if (width >= 560) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    if (_asDialog) {
      return _buildDialogShell();
    }
    return SelectionContainer.disabled(
      child: CupertinoPageScaffold(
        backgroundColor: Colors.white,
        child: Container(
          color: Colors.white,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildPageRouteHeader(),
                SizedBox(height: 8),
                _buildSearchField(padding: EdgeInsets.all(16)),
                if (_searchQuery.isEmpty) _buildRecommendedLabel(),
                Expanded(child: _buildSearchResults()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogShell() {
    final screen = MediaQuery.sizeOf(context);
    final horizontalInset = _kAddConnectionsDialogInset * 2;
    final verticalInset = _kAddConnectionsDialogInset * 2;
    final dialogWidth = math.min(
      _kAddConnectionsDialogMaxWidth,
      screen.width - horizontalInset,
    );
    final dialogHeight = math.min(
      screen.height * _kAddConnectionsDialogMaxHeightFactor,
      screen.height - verticalInset,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(_kAddConnectionsDialogInset),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Breathing space above the header
            const SizedBox(height: 36),
            _buildDialogHeader(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _kAddConnectionsDialogPadding,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: _buildSearchField(padding: EdgeInsets.zero),
                ),
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _kAddConnectionsDialogPadding,
                ),
                child: _buildRecommendedLabel(compact: true),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kAddConnectionsDialogPadding,
                  0,
                  _kAddConnectionsDialogPadding,
                  _kAddConnectionsDialogPadding,
                ),
                child: _buildSearchResults(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _kAddConnectionsDialogPadding,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Color(0xFF64748B),
              ),
            ),
          ).withClickCursor(),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Add Connections',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              mouseCursor: SystemMouseCursors.click,
              onTap: () => _showInviteDialog(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.person_add_solid,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Invite',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).withClickCursor(),
        ],
      ),
    );
  }

  Widget _buildPageRouteHeader() {
    return Container(
      height: 44,
      padding: EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white,
      child: Row(
        children: [
          LiquidStretch(
            stretch: 0.5,
            interactionScale: 1.05,
            child: GlassGlow(
              glowColor: Colors.white24,
              glowRadius: 1.0,
              child: AdaptiveFloatingActionButton(
                mini: true,
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF007AFF),
                onPressed: () => Navigator.of(context).pop(),
                child: Icon(
                  CupertinoIcons.chevron_left,
                  size: 17,
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
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
          SizedBox(width: 8),
          LiquidStretch(
            stretch: 0.5,
            interactionScale: 1.05,
            child: GlassGlow(
              glowColor: Colors.white24,
              glowRadius: 1.0,
              child: AdaptiveFloatingActionButton(
                mini: true,
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF007AFF),
                onPressed: () => _showInviteDialog(context),
                child: Icon(
                  CupertinoIcons.person_add_solid,
                  size: 17,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedLabel({bool compact = false}) {
    return Padding(
      padding: compact
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          compact ? 'RECOMMENDED' : 'Recommended',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: compact ? 12 : 18,
            fontWeight: FontWeight.w600,
            letterSpacing: compact ? 0.8 : -0.2,
            color: compact ? Color(0xFF94A3B8) : Color(0xFF111827),
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField({required EdgeInsets padding}) {
    return Container(
      width: double.infinity,
      padding: padding,
      color: _asDialog ? Colors.transparent : Colors.white,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: _asDialog ? Colors.white : CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(_asDialog ? 22 : 12),
          border: Border.all(
            color: _asDialog
                ? const Color(0xFFE2E8F0)
                : CupertinoColors.separator,
            width: _asDialog ? 1 : 0.5,
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
              color: _asDialog
                  ? Color(0xFF94A3B8)
                  : CupertinoColors.systemBlue,
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
                ).withClickCursor()
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
    );
  }

  Widget _buildSearchResults() {
    if (currentUserReference == null) {
      return Container(
        color: Colors.white,
        child: Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    return DesktopSafeUserPollBuilder(
      userRef: currentUserReference!,
      fetchOnce: fsGetUserOnce,
      builder: (context, currentUser) {
        if (currentUser == null) {
          return Container(
            color: Colors.white,
            child: Center(
              child: CupertinoActivityIndicator(),
            ),
          );
        }

        // Show dummy profile cards if no search query
        if (_searchQuery.isEmpty) {
          return _buildDummyProfileCards(currentUser);
        }

        // Fetch all users and filter client-side for real-time suggestions
        return _buildUserSearchGrid(currentUser);
      },
    );
  }

  Widget _buildUserSearchGrid(UsersRecord currentUser) {
    Widget buildGrid(AsyncSnapshot<List<UsersRecord>> searchSnapshot) {
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
                child: Center(
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
              color: _asDialog ? Colors.transparent : Colors.white,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = _gridColumnCount(constraints.maxWidth);
                  return GridView.builder(
                    padding: EdgeInsets.only(
                      top: _asDialog ? 4 : 16,
                      bottom: 16,
                      left: _asDialog ? 0 : 16,
                      right: _asDialog ? 0 : 16,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: _kAddConnectionsCardSpacing,
                      mainAxisSpacing: _kAddConnectionsCardSpacing,
                      mainAxisExtent: 176,
                    ),
                    itemCount: sortedUsers.length,
                    itemBuilder: (context, index) {
                      final user = sortedUsers[index];
                      final mutualCount = usersWithMutuals[index].value;
                      final isConnected =
                          _isUserConnected(user.reference, currentUser);
                      final isSentRequest =
                          _isValidSentRequest(user.reference, currentUser);

                      return _buildContactCard(
                        user: user,
                        currentUser: currentUser,
                        mutualConnections: mutualCount,
                        isConnected: isConnected,
                        isSentRequest: isSentRequest,
                      );
                    },
                  );
                },
              ),
            );
    }

    if (useWindowsFirestoreRest) {
      return RestPollBuilder<List<UsersRecord>>(
        interval: const Duration(seconds: 30),
        fetch: () => fsQueryUsers(limit: 200),
        builder: (context, snapshot) => buildGrid(snapshot),
      );
    }

    return StreamBuilder<List<UsersRecord>>(
      stream: queryUsersRecord(),
      builder: (context, snapshot) => buildGrid(snapshot),
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
                      decoration: TextDecoration.none,
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
                        decoration: TextDecoration.none,
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
                          decoration: TextDecoration.none,
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
      final currentUserData = await fsGetUserOnce(currentUserReference!);

      if (!currentUserData.friends.contains(user.reference)) {
        _showErrorMessage('You are not connected with ${user.displayName}');
        return;
      }

      // Update current user's document (we have permission for our own document)
      await fsArrayRemove(
        currentUserReference!,
        'friends',
        [user.reference],
      );

      try {
        await fsArrayRemove(
          user.reference,
          'friends',
          [currentUserReference!],
        );
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
            style: TextStyle(
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

  Widget _buildDummyProfileCards(UsersRecord currentUser) {
    if (_isInitialLoading) {
      return Container(
        color: Colors.white,
        child: Center(
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
      color: _asDialog ? Colors.transparent : Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = _gridColumnCount(constraints.maxWidth);
          return GridView.builder(
            controller: _scrollController,
            padding: EdgeInsets.only(
              top: _asDialog ? 4 : 16,
              bottom: 16,
              left: _asDialog ? 0 : 16,
              right: _asDialog ? 0 : 16,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: _kAddConnectionsCardSpacing,
              mainAxisSpacing: _kAddConnectionsCardSpacing,
              mainAxisExtent: 176,
            ),
            itemCount: filteredUsers.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == filteredUsers.length) {
                return Center(
                  child: CupertinoActivityIndicator(),
                );
              }

              final user = filteredUsers[index];
              final mutualCount =
                  _calculateMutualConnections(currentUser, user);
              final isConnected = _isUserConnected(user.reference, currentUser);
              final isSentRequest =
                  _isValidSentRequest(user.reference, currentUser);

              return _buildContactCard(
                user: user,
                currentUser: currentUser,
                mutualConnections: mutualCount,
                isConnected: isConnected,
                isSentRequest: isSentRequest,
              );
            },
          );
        },
      ),
    );
  }

  Color _avatarColorFor(UsersRecord user) {
    const colors = <Color>[
      Color(0xFFF59E0B),
      Color(0xFF3B82F6),
      Color(0xFF1E3A5F),
      Color(0xFF8B5CF6),
      Color(0xFF10B981),
      Color(0xFFEF4444),
      Color(0xFF0EA5E9),
      Color(0xFFEC4899),
    ];
    final key =
        user.reference.id.isNotEmpty ? user.reference.id : user.displayName;
    return colors[key.hashCode.abs() % colors.length];
  }

  Widget _buildContactCard({
    required UsersRecord user,
    required UsersRecord currentUser,
    required int mutualConnections,
    required bool isConnected,
    required bool isSentRequest,
  }) {
    final isLoading = _isOperationInProgress(user.reference.id);
    final name =
        user.displayName.isNotEmpty ? user.displayName : 'Unknown User';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: () {
          showUserProfilePopup(context, user: user);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _avatarColorFor(user),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: user.photoUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: user.photoUrl,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    _buildInitialsAvatarCompact(user),
                              )
                            : _buildInitialsAvatarCompact(user),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'SF Pro Display',
                                color: Color(0xFF0F172A),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            if (user.email.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.mail_outline_rounded,
                                    size: 13,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      user.email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'SF Pro Text',
                                        color: Color(0xFF64748B),
                                        fontSize: 12,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (user.bio.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                user.bio,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'SF Pro Text',
                                  color: Color(0xFF475569),
                                  fontSize: 13,
                                  height: 1.3,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(height: 1, color: const Color(0xFFF1F5F9)),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people_outline_rounded,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '$mutualConnections mutual',
                        style: const TextStyle(
                          fontFamily: 'SF Pro Text',
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        mouseCursor: SystemMouseCursors.click,
                        onTap: isLoading
                            ? null
                            : isConnected
                                ? () => _removeConnection(user, currentUser)
                                : isSentRequest
                                    ? () => _cancelConnectionRequest(user)
                                    : () => _sendConnectionRequest(user),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isConnected || isSentRequest
                                ? const Color(0xFFF1F5F9)
                                : const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: isLoading
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CupertinoActivityIndicator(
                                    color: isConnected || isSentRequest
                                        ? const Color(0xFF64748B)
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
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isConnected || isSentRequest
                                        ? const Color(0xFF64748B)
                                        : Colors.white,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                        ),
                      ),
                    ).withClickCursor(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).withClickCursor();
  }

  Widget _buildInitialsAvatarCompact(UsersRecord user) {
    final parts = user.displayName.trim().split(RegExp(r'\s+'));
    final initials = parts.isEmpty || parts.first.isEmpty
        ? 'U'
        : parts.map((n) => n[0]).take(2).join();
    return Container(
      width: 44,
      height: 44,
      color: _avatarColorFor(user),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
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
      Color(0xFF007AFF),
      Color(0xFF5856D6),
      Color(0xFFAF52DE),
      Color(0xFFFF2D55),
      Color(0xFFFF3B30),
      Color(0xFFFF9500),
      Color(0xFFFFCC00),
      Color(0xFF34C759),
      Color(0xFF5AC8FA),
      Color(0xFF00C7BE),
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
            style: TextStyle(
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
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.label,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
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

      if (!context.mounted) return;
      if (_asDialog) {
        Navigator.of(context).pop(chatToOpen);
        return;
      }
      await openDirectChat(chatToOpen, context: context);
    } catch (e) {
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

  Future<void> _sendConnectionRequest(UsersRecord user) async {
    final userId = user.reference.id;

    // Prevent multiple operations
    if (_isOperationInProgress(userId)) return;

    _startOperation(userId);

    try {
      // Bulletproof check - don't send if already connected or request already sent
      final currentUserData = await fsGetUserOnce(currentUserReference!);

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

      await fsArrayUnion(
        currentUserReference!,
        'sent_requests',
        [user.reference],
      );
      await fsArrayUnion(
        user.reference,
        'friend_requests',
        [currentUserReference!],
      );

      if (mounted) {
        _showSuccessMessage('Connection request sent to ${user.displayName}');
      }

      // Fire-and-forget: send email notification to recipient
      final currentUserData2 = await fsGetUserOnce(currentUserReference!);
      actions.sendConnectionRequestEmail(
        recipientEmail: user.email,
        recipientName: user.displayName,
        senderName: currentUserData2.displayName,
      );
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
      final currentUserData = await fsGetUserOnce(currentUserReference!);

      if (!currentUserData.sentRequests.contains(user.reference)) {
        _showErrorMessage('No pending request to ${user.displayName}');
        return;
      }

      await fsArrayRemove(
        currentUserReference!,
        'sent_requests',
        [user.reference],
      );
      await fsArrayRemove(
        user.reference,
        'friend_requests',
        [currentUserReference!],
      );

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
      final currentUserData = await fsGetUserOnce(currentUserReference!);

      if (currentUserData.friends.contains(user.reference)) {
        _showErrorMessage('You are already connected with ${user.displayName}');
        return;
      }

      if (!currentUserData.friendRequests.contains(user.reference)) {
        _showErrorMessage('No pending request from ${user.displayName}');
        return;
      }

      await fsArrayUnion(currentUserReference!, 'friends', [user.reference]);
      await fsArrayRemove(
        currentUserReference!,
        'friend_requests',
        [user.reference],
      );
      await fsArrayRemove(
        currentUserReference!,
        'sent_requests',
        [user.reference],
      );
      await fsArrayUnion(user.reference, 'friends', [currentUserReference!]);
      await fsArrayRemove(
        user.reference,
        'sent_requests',
        [currentUserReference!],
      );

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
      final currentUserData = await fsGetUserOnce(currentUserReference!);

      if (!currentUserData.friendRequests.contains(user.reference)) {
        _showErrorMessage('No pending request from ${user.displayName}');
        return;
      }

      await fsArrayRemove(
        currentUserReference!,
        'friend_requests',
        [user.reference],
      );

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
