import '/components/skeleton/skeleton_templates.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';
import '/pages/desktop_chat/desktop_safe_user_builder.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/mobile_chat/mobile_chat_widget.dart';
import '/pages/connections/add_connections_widget.dart';
import '/pages/chat/user_profile_popup/user_profile_popup.dart';
import '/pages/profile_settings/profile_settings_widget.dart';
import '/pages/profile_settings/profile_settings_model.dart';
import '/utils/desktop_pointer.dart';
import '/utils/connection_request_helpers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const double _kConnectionsContentMaxWidth = 1440;
const double _kConnectionsSearchMaxWidth = 420;
const double _kCardGridSpacing = 14;

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

  // ScrollControllers for each ListView
  final ScrollController _connectionsScrollController = ScrollController();
  final ScrollController _pendingScrollController = ScrollController();
  final ScrollController _suggestionsScrollController = ScrollController();

  // Same-company suggestion state
  bool _suggestionsCollapsed = false;
  List<UsersRecord>? _suggestedUsers;
  bool _isLoadingSuggestions = false;
  bool _isAddingAll = false;
  int _suggestionsPage = 0;
  static const int _suggestionsPerPage = 8;

  // Public email domains to exclude from "same company" matching
  static const Set<String> _publicEmailDomains = {
    'gmail.com', 'googlemail.com',
    'outlook.com', 'outlook.co.uk', 'live.com', 'live.co.uk',
    'hotmail.com', 'hotmail.co.uk', 'hotmail.fr', 'hotmail.de',
    'msn.com',
    'yahoo.com', 'yahoo.co.uk', 'yahoo.co.jp', 'yahoo.fr', 'yahoo.de',
    'ymail.com', 'rocketmail.com',
    'icloud.com', 'me.com', 'mac.com',
    'aol.com', 'aim.com',
    'qq.com', 'foxmail.com',
    '163.com', '126.com', 'yeah.net',
    'sina.com', 'sina.cn', 'sohu.com',
    'mail.com', 'email.com',
    'protonmail.com', 'proton.me', 'pm.me',
    'zoho.com', 'zohomail.com',
    'yandex.com', 'yandex.ru',
    'mail.ru', 'inbox.ru', 'list.ru', 'bk.ru',
    'gmx.com', 'gmx.de', 'gmx.net',
    'web.de', 't-online.de', 'freenet.de',
    'naver.com', 'daum.net', 'hanmail.net',
    'rediffmail.com',
    'tutanota.com', 'tuta.io',
    'fastmail.com', 'fastmail.fm',
    'hey.com',
    'test.com', 'tester.com', 'example.com',
  };

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
    _connectionsScrollController.dispose();
    _pendingScrollController.dispose();
    _suggestionsScrollController.dispose();
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

  int _gridColumnCount(double width) {
    if (width >= 1180) return 4;
    if (width >= 880) return 3;
    if (width >= 560) return 2;
    return 1;
  }

  Widget _constrainContent(Widget child) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: _kConnectionsContentMaxWidth),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      child: SafeArea(
        child: ColoredBox(
          color: const Color(0xFFF8FAFC),
          child: Column(
            children: [
              Expanded(
                child: _constrainContent(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: _buildPageHeader(),
                        ),
                        const SizedBox(height: 20),
                        _buildTabsRow(),
                        const SizedBox(height: 16),
                        _buildSearchBar(),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SizedBox(
                            width: double.infinity,
                            child: _buildTabContent(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Text(
            'Connections',
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
            onTap: () {
              showAddConnectionsDialog(context);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Add New',
                    style: TextStyle(
                      fontFamily: 'SF Pro Text',
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).withClickCursor(),
      ],
    );
  }

  Widget _buildTabsRow() {
    if (currentUserReference == null) {
      return _buildSegmentedControl(connectionsCount: 0, pendingCount: 0);
    }

    return DesktopSafeUserBuilder(
      userRef: currentUserReference!,
      fetchOnce: fsGetUserOnce,
      builder: (context, user) {
        final connectionsCount = user?.friends.length ?? 0;
        final incomingRequestsCount = user?.friendRequests.length ?? 0;
        final sentRequestsCount = user == null
            ? 0
            : user.sentRequests
                .where((ref) => !user.friends.contains(ref))
                .length;
        return _buildSegmentedControl(
          connectionsCount: connectionsCount,
          pendingCount: incomingRequestsCount + sentRequestsCount,
        );
      },
    );
  }

  Widget _buildSegmentedControl({
    required int connectionsCount,
    required int pendingCount,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: CupertinoSlidingSegmentedControl<int>(
        backgroundColor: const Color(0xFFEef2F7),
        thumbColor: Colors.white,
        groupValue: _selectedTabIndex,
        children: {
          0: _buildSegment('My Connections', connectionsCount, 0),
          1: _buildSegment('Pending', pendingCount, 1),
        },
        onValueChanged: (value) {
          if (value != null) {
            setState(() => _selectedTabIndex = value);
          }
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kConnectionsSearchMaxWidth),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: CupertinoTextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _searchQuery = value.toLowerCase());
            },
            placeholder: 'Search connections...',
            placeholderStyle: const TextStyle(
              fontFamily: 'SF Pro Text',
              color: Color(0xFF94A3B8),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              decoration: TextDecoration.none,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            prefix: const Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Icon(
                CupertinoIcons.search,
                color: Color(0xFF94A3B8),
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
                        color: Color(0xFFCBD5E1),
                        size: 16,
                      ),
                    ),
                  ).withClickCursor()
                : null,
            style: const TextStyle(
              fontFamily: 'SF Pro Text',
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              decoration: TextDecoration.none,
            ),
            decoration: const BoxDecoration(color: Colors.transparent),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (currentUserReference == null) {
      return const ConnectionsGridSkeleton();
    }

    return DesktopSafeUserBuilder(
      userRef: currentUserReference!,
      fetchOnce: fsGetUserOnce,
      builder: (context, currentUser) {
        if (currentUser == null) {
          return const ConnectionsGridSkeleton();
        }

        // Show tab content based on selected tab
        switch (_selectedTabIndex) {
          case 0:
            return _buildConnectionsList(currentUser);
          case 1:
            return _buildPendingList(currentUser);
          default:
            return _buildConnectionsList(currentUser);
        }
      },
    );
  }

  /// Extract email domain from an email address. Returns null for public domains.
  String? _getCompanyDomain(String email) {
    if (email.isEmpty || !email.contains('@')) return null;
    final domain = email.split('@').last.toLowerCase();
    if (_publicEmailDomains.contains(domain)) return null;
    return domain;
  }

  /// Load same-company user suggestions from Firestore.
  Future<void> _loadSuggestions(UsersRecord currentUser) async {
    final domain = _getCompanyDomain(currentUser.email);
    print('🔍 [Suggestions] User email: ${currentUser.email}, domain: $domain');
    if (domain == null) {
      // Public email domain — no suggestions possible
      setState(() {
        _suggestedUsers = [];
        _isLoadingSuggestions = false;
      });
      return;
    }

    if (_isLoadingSuggestions) return;
    setState(() => _isLoadingSuggestions = true);

    try {
      // Query all users — we'll filter by email domain client-side
      // (Firestore doesn't support "endsWith" queries natively)
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final suggestions = <UsersRecord>[];
      for (final doc in querySnapshot.docs) {
        final user = UsersRecord.fromSnapshot(doc);

        // Skip self
        if (user.reference.id == currentUserReference?.id) continue;
        // Skip already connected
        if (currentUser.friends.contains(user.reference)) continue;
        // Skip already sent request
        if (currentUser.sentRequests.contains(user.reference)) continue;
        // Skip already received request
        if (currentUser.friendRequests.contains(user.reference)) continue;
        // Check same domain
        final userDomain = _getCompanyDomain(user.email);
        if (userDomain != domain) continue;

        suggestions.add(user);
      }

      if (mounted) {
        setState(() {
          _suggestedUsers = suggestions;
          _isLoadingSuggestions = false;
          _suggestionsPage = 0;
        });
      }
    } catch (e) {
      print('❌ Error loading suggestions: $e');
      if (mounted) {
        setState(() {
          _suggestedUsers = [];
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  /// Send connection requests to all suggested users at once.
  Future<void> _connectAll(List<UsersRecord> users, UsersRecord currentUser) async {
    if (_isAddingAll) return;
    setState(() => _isAddingAll = true);

    int successCount = 0;
    for (final user in users) {
      try {
        // Check if target user has auto-accept enabled
        final targetUser = await fsGetUserOnce(user.reference);
        final senderDomain = _getCompanyDomain(currentUser.email);
        final targetDomain = _getCompanyDomain(targetUser.email);

        bool shouldAutoAccept = targetUser.autoAcceptAllRequests;
        if (!shouldAutoAccept && targetUser.autoAcceptSameCompany &&
            senderDomain != null && senderDomain == targetDomain) {
          shouldAutoAccept = true;
        }
        if (!shouldAutoAccept && senderDomain != null &&
            targetUser.autoAcceptEmailDomains.contains(senderDomain)) {
          shouldAutoAccept = true;
        }

        if (shouldAutoAccept) {
          // Directly add as friends (skip the request flow)
          await fsArrayUnion(currentUserReference!, 'friends', [user.reference]);
          await fsArrayUnion(user.reference, 'friends', [currentUserReference!]);
        } else {
          // Send a regular connection request
          await fsArrayUnion(currentUserReference!, 'sent_requests', [user.reference]);
          await fsArrayUnion(user.reference, 'friend_requests', [currentUserReference!]);
        }
        successCount++;
      } catch (e) {
        print('❌ Error connecting with ${user.displayName}: $e');
      }
    }

    if (mounted) {
      setState(() => _isAddingAll = false);
      _showSuccessMessage('$successCount connection request(s) sent!');
      // Reload suggestions to remove the ones we just sent
      _loadSuggestions(currentUser);
      // Show dialog suggesting auto-approve settings (only if not already enabled)
      if (!currentUser.autoAcceptAllRequests && !currentUser.autoAcceptSameCompany) {
        _showAutoApproveHintDialog();
      }
    }
  }

  void _showAutoApproveHintDialog() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Tip: Auto-Approve Requests'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'You can enable auto-approve in Settings so that colleagues from the same company don\'t need to wait for your approval.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Dismiss'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Go to Settings'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => ProfileSettingsWidget(
                    initialTab: SettingsTab.connections,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsBanner(UsersRecord currentUser) {
    final domain = _getCompanyDomain(currentUser.email);
    final rawDomain = currentUser.email.contains('@')
        ? currentUser.email.split('@').last.toLowerCase()
        : '';
    if (rawDomain.isEmpty) return const SizedBox.shrink();

    final isPublicDomain = domain == null;

    // Load suggestions on first build
    if (_suggestedUsers == null && !_isLoadingSuggestions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSuggestions(currentUser);
      });
    }

    if (_suggestedUsers == null || _isLoadingSuggestions) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 100,
          child: ChatListSkeleton(itemCount: 2),
        ),
      );
    }

    if (_suggestedUsers!.isEmpty) {
      // Show the banner frame with an empty-state message
      final displayDomain = domain ?? rawDomain;
      final emptyMessage = isPublicDomain
          ? 'No colleague suggestions — you\'re using a public email (@$rawDomain). Use a company email to discover colleagues.'
          : 'All users from @$displayDomain are already in your connections!';
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEFF6FF), Color(0xFFF0F9FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.building_2_fill, size: 18, color: Color(0xFF93C5FD)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                emptyMessage,
                style: const TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final totalUsers = _suggestedUsers!.length;
    final totalPages = (totalUsers / _suggestionsPerPage).ceil();
    final startIdx = _suggestionsPage * _suggestionsPerPage;
    final endIdx = (startIdx + _suggestionsPerPage).clamp(0, totalUsers);
    final pageUsers = _suggestedUsers!.sublist(startIdx, endIdx);

    return AnimatedCrossFade(
      firstChild: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEFF6FF), Color(0xFFF0F9FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                const Icon(CupertinoIcons.building_2_fill, size: 18, color: Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'People from @$domain',
                    style: const TextStyle(
                      fontFamily: 'SF Pro Text',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E40AF),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                Text(
                  '$totalUsers found',
                  style: const TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 8),
                // Connect All button
                GestureDetector(
                  onTap: _isAddingAll ? null : () => _connectAll(_suggestedUsers!, currentUser),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isAddingAll
                        ? const CupertinoActivityIndicator(color: Colors.white, radius: 8)
                        : const Text(
                            'Connect All',
                            style: TextStyle(
                              fontFamily: 'SF Pro Text',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              decoration: TextDecoration.none,
                            ),
                          ),
                  ),
                ).withClickCursor(),
                const SizedBox(width: 8),
                // Collapse button
                GestureDetector(
                  onTap: () => setState(() => _suggestionsCollapsed = true),
                  child: const Icon(CupertinoIcons.chevron_up, size: 16, color: Color(0xFF94A3B8)),
                ).withClickCursor(),
              ],
            ),
            const SizedBox(height: 12),
            // User cards row
            SizedBox(
              height: 90,
              child: Row(
                children: [
                  // Previous page button
                  if (_suggestionsPage > 0)
                    GestureDetector(
                      onTap: () => setState(() => _suggestionsPage--),
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(CupertinoIcons.chevron_left, size: 14, color: Color(0xFF64748B)),
                      ),
                    ).withClickCursor(),
                  // User cards
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pageUsers.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final user = pageUsers[index];
                        final isLoading = _isOperationInProgress(user.reference.id);
                        return Container(
                          width: 180,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Avatar
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    backgroundImage: user.photoUrl.isNotEmpty
                                        ? NetworkImage(user.photoUrl)
                                        : null,
                                    child: user.photoUrl.isEmpty
                                        ? Text(
                                            user.displayName.isNotEmpty
                                                ? user.displayName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF64748B),
                                              decoration: TextDecoration.none,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.displayName,
                                          style: const TextStyle(
                                            fontFamily: 'SF Pro Text',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A1A),
                                            decoration: TextDecoration.none,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          user.email,
                                          style: const TextStyle(
                                            fontFamily: 'SF Pro Text',
                                            fontSize: 10,
                                            color: Color(0xFF94A3B8),
                                            decoration: TextDecoration.none,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // Connect button
                              GestureDetector(
                                onTap: isLoading
                                    ? null
                                    : () => _sendConnectionRequest(user),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF3B82F6), width: 0.5),
                                  ),
                                  child: Center(
                                    child: isLoading
                                        ? const CupertinoActivityIndicator(radius: 8)
                                        : const Text(
                                            'Connect',
                                            style: TextStyle(
                                              fontFamily: 'SF Pro Text',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF3B82F6),
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                  ),
                                ),
                              ).withClickCursor(),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // Next page button
                  if (_suggestionsPage < totalPages - 1)
                    GestureDetector(
                      onTap: () => setState(() => _suggestionsPage++),
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFF64748B)),
                      ),
                    ).withClickCursor(),
                ],
              ),
            ),
            // Page indicator
            if (totalPages > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(totalPages, (i) => Container(
                    width: i == _suggestionsPage ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i == _suggestionsPage
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )),
                ),
              ),
          ],
        ),
      ),
      secondChild: // Collapsed state — small bar to re-expand
          GestureDetector(
        onTap: () => setState(() => _suggestionsCollapsed = false),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE), width: 0.5),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.building_2_fill, size: 14, color: Color(0xFF3B82F6)),
              const SizedBox(width: 6),
              Text(
                '$totalUsers people from @$domain',
                style: const TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontSize: 13,
                  color: Color(0xFF3B82F6),
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
              const Spacer(),
              const Icon(CupertinoIcons.chevron_down, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ).withClickCursor(),
      crossFadeState: _suggestionsCollapsed
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 250),
    );
  }

  Widget _buildConnectionsList(UsersRecord currentUser) {
    final connections = currentUser.friends;

    if (connections.isEmpty) {
      return Column(
        children: [
          _buildSuggestionsBanner(currentUser),
          Expanded(
            child: _buildEmptyState(
              icon: CupertinoIcons.person_2,
              title: 'No Connections Yet',
              subtitle: 'Start connecting with people. Tap "Add New" to get started.',
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSuggestionsBanner(currentUser),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
          child: Text(
            '${connections.length} CONNECTION${connections.length == 1 ? '' : 'S'}',
            style: const TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Color(0xFF94A3B8),
              decoration: TextDecoration.none,
            ),
          ),
        ),
        Expanded(
          child: CupertinoScrollbar(
            controller: _connectionsScrollController,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = _gridColumnCount(constraints.maxWidth);
                final cardHeight = crossAxisCount == 1 ? 100.0 : 130.0;
                // When search is active, we need to filter by loading each user
                // Use a FutureBuilder approach to pre-filter
                if (_searchQuery.isNotEmpty) {
                  return FutureBuilder<List<MapEntry<DocumentReference, UsersRecord>>>(
                    future: _loadAndFilterConnections(connections),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return ConnectionsGridSkeleton(crossAxisCount: crossAxisCount, cardHeight: cardHeight);
                      }
                      final filtered = snapshot.data!;
                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            'No matches found',
                            style: TextStyle(
                              fontFamily: 'SF Pro Text',
                              fontSize: 14,
                              color: Color(0xFF94A3B8),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        );
                      }
                      return GridView.builder(
                        controller: _connectionsScrollController,
                        padding: const EdgeInsets.only(bottom: 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: _kCardGridSpacing,
                          mainAxisSpacing: _kCardGridSpacing,
                          mainAxisExtent: cardHeight,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final user = filtered[index].value;
                          final isActuallyConnected =
                              _isUserConnected(user.reference, currentUser);
                          return _buildPersonCard(
                            user,
                            currentUser,
                            isConnected: isActuallyConnected,
                          );
                        },
                      );
                    },
                  );
                }
                // No search — render all connections normally
                return GridView.builder(
                  controller: _connectionsScrollController,
                  padding: const EdgeInsets.only(bottom: 24),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: _kCardGridSpacing,
                    mainAxisSpacing: _kCardGridSpacing,
                    mainAxisExtent: cardHeight,
                  ),
                  itemCount: connections.length,
                  itemBuilder: (context, index) {
                    final connectionRef = connections[index];
                    return DesktopSafeUserBuilder(
                      userRef: connectionRef,
                      fetchOnce: fsGetUserOnce,
                      builder: (context, user) {
                        if (user == null) {
                          return const SizedBox.shrink();
                        }
                        final isActuallyConnected =
                            _isUserConnected(user.reference, currentUser);
                        return _buildPersonCard(
                          user,
                          currentUser,
                          isConnected: isActuallyConnected,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Pre-load all connection user data and filter by search query.
  /// This avoids the GridView gap issue where SizedBox.shrink() creates
  /// empty cells in a fixed grid layout.
  Future<List<MapEntry<DocumentReference, UsersRecord>>> _loadAndFilterConnections(
      List<DocumentReference> connections) async {
    final results = <MapEntry<DocumentReference, UsersRecord>>[];
    for (final ref in connections) {
      try {
        final user = await fsGetUserOnce(ref);
        if (_matchesSearch(user)) {
          results.add(MapEntry(ref, user));
        }
      } catch (_) {}
    }
    return results;
  }

  bool _matchesSearch(UsersRecord user) {
    if (_searchQuery.isEmpty) return true;
    final displayName = user.displayName.toLowerCase();
    final email = user.email.toLowerCase();
    final bio = user.bio.toLowerCase();
    return displayName.contains(_searchQuery) ||
        email.contains(_searchQuery) ||
        bio.contains(_searchQuery);
  }

  int _mutualConnectionCount(UsersRecord currentUser, UsersRecord otherUser) {
    return currentUser.friends
        .toSet()
        .intersection(otherUser.friends.toSet())
        .length;
  }

  String _relativeTimeLabel(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inDays >= 365) {
      final years = (diff.inDays / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    }
    if (diff.inDays >= 30) {
      final months = (diff.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    }
    if (diff.inDays >= 7) {
      final weeks = (diff.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    }
    if (diff.inDays >= 1) {
      return diff.inDays == 1 ? '1 day ago' : '${diff.inDays} days ago';
    }
    if (diff.inHours >= 1) {
      return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
    }
    return 'Just now';
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
    final key = user.reference.id.isNotEmpty
        ? user.reference.id
        : user.displayName;
    return colors[key.hashCode.abs() % colors.length];
  }

  Widget _buildPendingList(UsersRecord currentUser) {
    final requests = currentUser.friendRequests;
    final sentRequests = currentUser.sentRequests
        .where((ref) => !currentUser.friends.contains(ref))
        .toList();

    if (requests.isEmpty && sentRequests.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.person_add,
        title: 'No Pending Requests',
        subtitle: 'You have no incoming or sent connection requests',
      );
    }

    return CupertinoScrollbar(
      controller: _pendingScrollController,
      child: ListView(
        controller: _pendingScrollController,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildPendingSectionHeader('Requests', requests.length),
          if (requests.isEmpty)
            _buildPendingSectionEmpty('No incoming requests')
          else
            _buildPendingCardGrid(
              refs: requests,
              currentUser: currentUser,
              isIncoming: true,
            ),
          const SizedBox(height: 8),
          _buildPendingSectionHeader('Sent', sentRequests.length),
          if (sentRequests.isEmpty)
            _buildPendingSectionEmpty('No sent requests')
          else
            _buildPendingCardGrid(
              refs: sentRequests,
              currentUser: currentUser,
              isIncoming: false,
            ),
        ],
      ),
    );
  }

  Widget _buildPendingCardGrid({
    required List<DocumentReference> refs,
    required UsersRecord currentUser,
    required bool isIncoming,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _gridColumnCount(constraints.maxWidth);
        final totalSpacing = _kCardGridSpacing * (crossAxisCount - 1);
        final cardWidth =
            (constraints.maxWidth - totalSpacing) / crossAxisCount;

        return Wrap(
          spacing: _kCardGridSpacing,
          runSpacing: _kCardGridSpacing,
          children: [
            for (final ref in refs)
              SizedBox(
                width: cardWidth,
                child: DesktopSafeUserBuilder(
                  userRef: ref,
                  fetchOnce: fsGetUserOnce,
                  builder: (context, user) {
                    if (user == null || !_matchesSearch(user)) {
                      return const SizedBox.shrink();
                    }
                    if (!isIncoming &&
                        !_isValidSentRequest(user.reference, currentUser)) {
                      return const SizedBox.shrink();
                    }
                    return SizedBox(
                      height: 180,
                      child: _buildPersonCard(
                        user,
                        currentUser,
                        hasIncomingRequest: isIncoming,
                        isSentRequest: !isIncoming,
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPendingSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 12),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Color(0xFF94A3B8),
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: const TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSectionEmpty(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      child: Text(
        message,
        style: const TextStyle(
          fontFamily: 'SF Pro Text',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Color(0xFF94A3B8),
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildPersonCard(
    UsersRecord user,
    UsersRecord currentUser, {
    bool isConnected = false,
    bool isSentRequest = false,
    bool hasIncomingRequest = false,
  }) {
    final mutualCount = _mutualConnectionCount(currentUser, user);
    final timeLabel = _relativeTimeLabel(user.createdTime);
    final name =
        user.displayName.isNotEmpty ? user.displayName : 'Unknown User';
    final requestNote = hasIncomingRequest
        ? ConnectionRequestHelpers.noteFrom(currentUser, user.reference)
        : isSentRequest
            ? ConnectionRequestHelpers.noteFrom(user, currentUser.reference)
            : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: () => _viewUserProfile(user),
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
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCardAvatar(user),
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
                                        fontWeight: FontWeight.w400,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (requestNote != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                requestNote,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'SF Pro Text',
                                  color: Color(0xFF334155),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ] else if (user.bio.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                user.bio,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'SF Pro Text',
                                  color: Color(0xFF475569),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildActionButtons(
                        user,
                        currentUser,
                        isConnected: isConnected,
                        isSentRequest: isSentRequest,
                        hasIncomingRequest: hasIncomingRequest,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                height: 1,
                color: const Color(0xFFF1F5F9),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people_outline_rounded,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$mutualCount mutual',
                      style: const TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF64748B),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const Spacer(),
                    if (timeLabel.isNotEmpty) ...[
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          fontFamily: 'SF Pro Text',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF64748B),
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
    ).withClickCursor();
  }

  Widget _buildCardAvatar(UsersRecord user) {
    return Container(
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
              placeholder: (context, url) => _buildInitialsAvatar(user, size: 44),
              errorWidget: (context, url, error) =>
                  _buildInitialsAvatar(user, size: 44),
            )
          : _buildInitialsAvatar(user, size: 44),
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
      // Show More options icon button only
      return Material(
        color: Colors.transparent,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: () => _showMoreOptions(user, currentUser),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(
                color: Color(0xFFE5E7EB),
                width: 1,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.ellipsis,
              size: 14,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ).withClickCursor();
    } else if (actuallyHasIncomingRequest && !actuallyHasSentRequest) {
      // Compact Accept / Decline for card layout
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              mouseCursor: SystemMouseCursors.click,
              onTap: isLoading ? null : () => _acceptConnectionRequest(user),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CupertinoActivityIndicator(color: Colors.white),
                      )
                    : Text(
                        'Accept',
                        style: TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                        ),
                      ),
              ),
            ),
          ).withClickCursor(),
          SizedBox(height: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              mouseCursor: SystemMouseCursors.click,
              onTap: isLoading ? null : () => _declineConnectionRequest(user),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Color(0xFFE5E7EB),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.white,
                ),
                child: Text(
                  'Decline',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ).withClickCursor(),
        ],
      );
    } else if (actuallyHasSentRequest) {
      // Show cancel button for sent requests in the Pending tab
      if (_selectedTabIndex == 1) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            mouseCursor: SystemMouseCursors.click,
            onTap: isLoading ? null : () => _cancelConnectionRequest(user),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(6),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CupertinoActivityIndicator(color: Colors.white),
                    )
                  : Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                      ),
                    ),
            ),
          ),
        ).withClickCursor();
      } else {
        // Show pending state in other tabs
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Pending',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              decoration: TextDecoration.none,
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

      // Try to update other user's document (may fail due to permissions, but that's okay)
      // The connection will be removed from their side when they next sync
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

  Widget _buildInitialsAvatar(UsersRecord user, {double size = 48}) {
    final parts = user.displayName.trim().split(RegExp(r'\s+'));
    final initials = parts.isEmpty || parts.first.isEmpty
        ? 'U'
        : parts.map((name) => name[0]).take(2).join();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _avatarColorFor(user),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
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

      final existingChats = await fsQueryMemberDmChats(
        memberRef: currentUserReference!,
        workspaceRef: currentWorkspaceRef,
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
        final newChatRef = await fsCreateChat({
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
        chatToOpen = await fsGetChatOnce(newChatRef);
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
    showUserProfilePopup(context, user: user);
  }

  Future<void> _sendConnectionRequest(UsersRecord user) async {
    final userId = user.reference.id;

    // Prevent multiple operations
    if (_isOperationInProgress(userId)) return;

    _startOperation(userId);

    try {
      final outcome = await ConnectionRequestHelpers.promptAndSend(
        context: context,
        targetUser: user,
      );
      if (!mounted) return;
      final message = ConnectionRequestHelpers.successMessage(
        outcome,
        user.displayName,
      );
      if (message != null) {
        _showSuccessMessage(message);
      }
    } catch (e) {
      print('Error sending connection request: $e');
      if (mounted) {
        if (e is ConnectionRequestException) {
          _showErrorMessage(e.message);
        } else if (e.toString().contains('permission-denied')) {
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
      await ConnectionRequestHelpers.accept(user);
      if (mounted) {
        _showSuccessMessage('Connection request accepted!');
      }
    } catch (e) {
      print('Error accepting connection request: $e');
      if (mounted) {
        if (e is ConnectionRequestException) {
          _showErrorMessage(e.message);
        } else if (e.toString().contains('permission-denied')) {
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
      await ConnectionRequestHelpers.decline(user);
      if (mounted) {
        _showSuccessMessage('Connection request declined');
      }
    } catch (e) {
      print('Error declining connection request: $e');
      if (mounted) {
        if (e is ConnectionRequestException) {
          _showErrorMessage(e.message);
        } else {
          _showErrorMessage(
              'Failed to decline connection request. Please check your internet connection and try again.');
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
      await ConnectionRequestHelpers.cancel(user);
      if (mounted) {
        _showSuccessMessage('Connection request cancelled');
      }
    } catch (e) {
      print('Error cancelling connection request: $e');
      if (mounted) {
        if (e is ConnectionRequestException) {
          _showErrorMessage(e.message);
        } else {
          _showErrorMessage(
              'Failed to cancel connection request. Please check your internet connection and try again.');
        }
      }
    } finally {
      _stopOperation(userId);
    }
  }

  Widget _buildSegment(String label, int count, int index) {
    final isSelected = _selectedTabIndex == index;
    final isPendingTab = index == 1;
    final badgeColor = count <= 0
        ? Colors.transparent
        : isPendingTab && !isSelected
            ? const Color(0xFFF97316)
            : isSelected
                ? const Color(0xFF2563EB)
                : const Color(0xFFE2E8F0);
    final badgeTextColor = count <= 0
        ? Colors.transparent
        : isPendingTab && !isSelected
            ? Colors.white
            : isSelected
                ? Colors.white
                : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF64748B),
                decoration: TextDecoration.none,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 16,
              ),
              child: Center(
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
