import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/chat/chat_component/memo/memo_widget.dart';
import '/utils/chat_helpers.dart';
import '/utils/connection_request_helpers.dart';
import '/utils/open_direct_chat.dart';
import '/utils/desktop_pointer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Opens a profile popup for [user] (or [userRef]).
///
/// Pass [groupChat] (or [chatRef] to a group chat) when opened from a group
/// context so the member's role (Owner / Admin / Member) can be shown.
Future<void> showUserProfilePopup(
  BuildContext context, {
  UsersRecord? user,
  DocumentReference? userRef,
  ChatsRecord? groupChat,
  DocumentReference? chatRef,
}) async {
  UsersRecord? resolved = user;
  final ref = userRef ?? user?.reference;
  if (resolved == null && ref != null) {
    try {
      resolved = await fsGetUserOnce(ref);
    } catch (_) {}
  }
  if (resolved == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load this profile.')),
      );
    }
    return;
  }

  ChatsRecord? chat = groupChat;
  if (chat == null && chatRef != null) {
    try {
      final fetched = await fsGetChatOnce(chatRef);
      if (fetched.isGroup) chat = fetched;
    } catch (_) {}
  }

  if (!context.mounted) return;
  await showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (dialogContext) => UserProfilePopup(
      user: resolved!,
      groupChat: chat,
    ),
  );
}

enum _FriendState { self, bot, friends, incoming, pending, none }

class UserProfilePopup extends StatefulWidget {
  const UserProfilePopup({
    super.key,
    required this.user,
    this.groupChat,
  });

  final UsersRecord user;
  final ChatsRecord? groupChat;

  @override
  State<UserProfilePopup> createState() => _UserProfilePopupState();
}

class _UserProfilePopupState extends State<UserProfilePopup> {
  UserMemoRecord? _memo;
  String _noteText = '';
  bool _busy = false;

  int _tabIndex = 0; // 0 = Mutual Friends, 1 = Mutual Groups
  bool _mutualLoading = true;
  List<UsersRecord> _mutualFriends = [];
  List<ChatsRecord> _mutualGroups = [];
  final ScrollController _scrollController = ScrollController();
  bool _showEmailCopiedTip = false;

  DocumentReference get _ref => widget.user.reference;
  bool get _isBot => _ref.path.contains('ai_agent');
  String get _email => widget.user.email.trim();

  static const Color _labelGray = Color(0xFF8E8E93);
  static const Color _borderGray = Color(0xFFE5E5EA);
  static const Color _chipGray = Color(0xFFF2F2F7);
  static const Color _black = Color(0xFF1C1C1E);
  static const Color _appBlue = Color(0xFF2563EB);
  static const Color _avatarBlue = Color(0xFF3B82F6);
  static const Color _avatarBorder = Color(0xFFE5E7EB);
  static const Color _avatarIconGray = Color(0xFF6B7280);
  static const String _kSummerAiAvatar =
      'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120';

  @override
  void initState() {
    super.initState();
    _loadNote();
    _loadMutuals();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNote() async {
    if (_isBot || _ref.path == currentUserReference?.path) return;
    // Direct cloud_firestore reads crash the Windows/Linux build (see
    // useWindowsFirestoreRest) and there is no REST query for `user_memo`,
    // so skip preloading the note there.
    if (useWindowsFirestoreRest) return;
    try {
      final memo = await queryUserMemoRecordOnce(
        queryBuilder: (m) => m
            .where('owner_ref', isEqualTo: currentUserReference)
            .where('target_ref', isEqualTo: _ref),
        singleRecord: true,
      ).then((s) => s.firstOrNull);
      if (!mounted) return;
      setState(() {
        _memo = memo;
        _noteText = memo?.memoText ?? '';
      });
    } catch (_) {}
  }

  Future<void> _loadMutuals() async {
    try {
      final myFriends =
          (currentUserDocument?.friends ?? []).map((e) => e.path).toSet();
      final theirFriends = widget.user.friends;
      final mutualRefs = theirFriends
          .where((f) =>
              myFriends.contains(f.path) &&
              f.path != currentUserReference?.path)
          .take(30)
          .toList();

      final friends = <UsersRecord>[];
      for (final r in mutualRefs) {
        try {
          final u = await fsGetUserOnce(r);
          friends.add(u);
        } catch (_) {}
      }

      final groups = <ChatsRecord>[];
      try {
        final myChats = await fsQueryMemberChats(currentUserReference!);
        for (final c in myChats) {
          if (c.isGroup && c.members.any((m) => m.path == _ref.path)) {
            groups.add(c);
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _mutualFriends = friends;
        _mutualGroups = groups;
        _mutualLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _mutualLoading = false);
    }
  }

  _FriendState _friendState() {
    if (_ref.path == currentUserReference?.path) return _FriendState.self;
    if (_isBot) return _FriendState.bot;
    bool contains(List<DocumentReference>? list) =>
        (list ?? []).any((e) => e.path == _ref.path);
    if (contains(currentUserDocument?.friends)) return _FriendState.friends;
    if (contains(currentUserDocument?.friendRequests)) {
      return _FriendState.incoming;
    }
    if (contains(currentUserDocument?.sentRequests)) {
      return _FriendState.pending;
    }
    return _FriendState.none;
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      final message = e is ConnectionRequestException
          ? e.message
          : 'Something went wrong. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptRequest() => _runBusy(() async {
        await ConnectionRequestHelpers.accept(widget.user);
      });

  Future<void> _addFriend() => _runBusy(() async {
        await ConnectionRequestHelpers.promptAndSend(
          context: context,
          targetUser: widget.user,
        );
      });

  Future<void> _declineRequest() => _runBusy(() async {
        await ConnectionRequestHelpers.decline(widget.user);
      });

  Future<void> _cancelRequest() => _runBusy(() async {
        await ConnectionRequestHelpers.cancel(widget.user);
      });

  Future<void> _openMessage() async {
    await _runBusy(() async {
      final chat = await ChatHelpers.findOrCreateDirectChat(_ref);
      if (!mounted) return;
      Navigator.of(context).pop();
      await openDirectChat(chat);
    });
  }

  Future<void> _editNote() async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: MemoWidget(
          isEdit: _memo != null,
          memo: _memo?.memoText,
          iamge: _memo?.memoImage,
          action: (memo, image) async {
            if (_memo != null) {
              await fsPatchDocument(
                _memo!.reference,
                createUserMemoRecordData(
                  memoText: memo,
                  memoImage: image,
                  updatedAt: getCurrentTimestamp,
                ),
              );
            } else {
              final reference = UserMemoRecord.collection.doc();
              final data = createUserMemoRecordData(
                ownerRef: currentUserReference,
                targetRef: _ref,
                memoText: memo,
                memoImage: image,
                updatedAt: getCurrentTimestamp,
              );
              await fsSetDocument(reference, data);
              _memo = UserMemoRecord.getDocumentFromData(data, reference);
            }
            if (mounted) setState(() => _noteText = memo ?? '');
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
        ),
      ),
    );
  }

  void _confirmBlockUser() {
    final name = valueOrDefault<String>(widget.user.displayName, 'this user');
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Block User'),
        content: Text(
          'Are you sure you want to block $name? You won\'t be able to see their profile or receive messages from them.',
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _blockUser();
            },
            child: const Text('Block'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser() async {
    if (currentUserReference == null) return;
    await _runBusy(() async {
      try {
        final currentUserData = await fsGetUserOnce(currentUserReference!);

        if (currentUserData.friends.any((e) => e.path == _ref.path)) {
          await fsArrayRemove(currentUserReference!, 'friends', [_ref]);
          try {
            await fsArrayRemove(_ref, 'friends', [currentUserReference!]);
          } catch (_) {}
        }

        if (currentUserData.sentRequests.any((e) => e.path == _ref.path)) {
          await fsArrayRemove(currentUserReference!, 'sent_requests', [_ref]);
          try {
            await fsArrayRemove(
                _ref, 'friend_requests', [currentUserReference!]);
          } catch (_) {}
        }

        if (currentUserData.friendRequests.any((e) => e.path == _ref.path)) {
          await fsArrayRemove(currentUserReference!, 'friend_requests', [_ref]);
        }

        final alreadyBlocked = await fsIsUserBlocked(
          blockerRef: currentUserReference!,
          blockedRef: _ref,
        );
        if (!alreadyBlocked) {
          await fsBlockUser(
            blockerUser: currentUserReference!,
            blockedUser: _ref,
          );
        }

        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${valueOrDefault<String>(widget.user.displayName, 'User')} has been blocked',
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to block user: $e')),
        );
      }
    });
  }

  String _roleLabel() {
    final chat = widget.groupChat;
    if (chat == null) return 'Member';
    if (ChatHelpers.isGroupOwner(chat, _ref)) return 'Owner';
    if (ChatHelpers.isGroupAdmin(chat, _ref)) return 'Admin';
    return 'Member';
  }

  Future<void> _copyEmail() async {
    if (_email.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _email));
    if (!mounted) return;
    setState(() => _showEmailCopiedTip = true);
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() => _showEmailCopiedTip = false);
  }

  Widget _buildEmailCopyButton() {
    if (_email.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Tooltip(
            message: 'Click to copy email',
            waitDuration: const Duration(milliseconds: 350),
            child: InkWell(
              onTap: _copyEmail,
              borderRadius: BorderRadius.circular(6),
              mouseCursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 16,
                      color: _labelGray,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: _labelGray,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ).withClickCursor(),
          ),
          if (_showEmailCopiedTip)
            Positioned(
              left: 0,
              top: -28,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _black,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Email copied',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = valueOrDefault<String>(widget.user.displayName, 'N/A');
    final bio = widget.user.bio;
    final location = widget.user.location.trim();
    final showNote = _friendState() != _FriendState.self && !_isBot;
    // Fixed size so the popup never resizes with content.
    const popupWidth = 500.0;
    final popupHeight = MediaQuery.of(context).size.height * 0.60;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: popupWidth,
        height: popupHeight,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stationary header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 28),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildAvatar(
                                  imageUrl: _isBot &&
                                          _ref.path
                                              .contains('ai_agent_summerai')
                                      ? _kSummerAiAvatar
                                      : widget.user.photoUrl,
                                  size: 64,
                                  isGroup: false,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: _black,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      _buildEmailCopyButton(),
                                      const SizedBox(height: 12),
                                      AuthUserStreamWidget(
                                        builder: (context) {
                                          final friendState = _friendState();
                                          final currentUser =
                                              currentUserDocument;
                                          final requestNote = currentUser ==
                                                  null
                                              ? null
                                              : friendState ==
                                                      _FriendState.incoming
                                                  ? ConnectionRequestHelpers
                                                      .noteFrom(
                                                      currentUser,
                                                      _ref,
                                                    )
                                                  : friendState ==
                                                          _FriendState.pending
                                                      ? ConnectionRequestHelpers
                                                          .noteFrom(
                                                          widget.user,
                                                          currentUser
                                                              .reference,
                                                        )
                                                      : null;
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _buildActionRow(),
                                              if (requestNote != null) ...[
                                                const SizedBox(height: 10),
                                                ConnectionRequestHelpers
                                                    .noteBanner(requestNote),
                                              ],
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          _divider(),
                          const SizedBox(height: 16),
                          Text(
                            'About',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _labelGray,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            bio.isNotEmpty ? bio : 'No bio yet',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: bio.isNotEmpty ? _black : _labelGray,
                              fontStyle: bio.isNotEmpty
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (location.isNotEmpty) ...[
                            Text(
                              'Location',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _labelGray,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              location,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _black,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Member since',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: _labelGray,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.user.createdTime != null
                                          ? dateTimeFormat('MMM d, yyyy',
                                              widget.user.createdTime!)
                                          : '—',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: _black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.groupChat != null)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Role',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: _labelGray,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _chipGray,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          _roleLabel(),
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: _black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _divider(),
                          const SizedBox(height: 12),
                          _buildMutualTabs(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),

                    // Scrollable mutuals list only
                    Expanded(
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: _mutualLoading
                            ? const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : ListView(
                                controller: _scrollController,
                                padding:
                                    const EdgeInsets.fromLTRB(20, 4, 20, 8),
                                children: [
                                  if (_tabIndex == 0)
                                    _buildMutualFriendsList()
                                  else
                                    _buildMutualGroupsList(),
                                ],
                              ),
                      ),
                    ),

                    // Stationary note at bottom
                    if (showNote)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _divider(),
                            const SizedBox(height: 14),
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: _editNote,
                              mouseCursor: SystemMouseCursors.click,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: _chipGray,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _noteText.isNotEmpty
                                      ? _noteText
                                      : 'Add a private note',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: _noteText.isNotEmpty
                                        ? _black
                                        : _labelGray,
                                  ),
                                ),
                              ),
                            ).withClickCursor(),
                          ],
                        ),
                      )
                    else
                      const SizedBox(height: 20),
                  ],
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).maybePop(),
                  mouseCursor: SystemMouseCursors.click,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: _chipGray,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 16, color: _labelGray),
                  ),
                ).withClickCursor(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => Container(height: 1, color: _borderGray);

  Widget _buildAvatar({
    required String imageUrl,
    required double size,
    bool isGroup = false,
  }) {
    final icon = isGroup ? Icons.group : Icons.person;
    final iconSize = isGroup ? size * 0.55 : size * 0.52;

    Widget fallback() => ColoredBox(
          color: Colors.white,
          child: Center(
            child: Icon(icon, color: _avatarIconGray, size: iconSize),
          ),
        );

    // Match connections/chat avatars: circular clip + BoxFit.cover, and do
    // not set both memCacheWidth/Height (that forces a square resize and
    // squashes non-square uploads).
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isGroup ? Colors.white : _avatarBlue,
        shape: BoxShape.circle,
        border: Border.all(color: _avatarBorder, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              placeholder: (_, __) => fallback(),
              errorWidget: (_, __, ___) => fallback(),
            )
          : fallback(),
    );
  }

  Widget _buildActionRow() {
    final state = _friendState();
    if (state == _FriendState.self) return const SizedBox.shrink();

    final children = <Widget>[];
    switch (state) {
      case _FriendState.friends:
        children.add(_filledButton(
          label: 'Message',
          icon: Icons.chat_bubble_outline,
          onTap: _openMessage,
        ));
        break;
      case _FriendState.incoming:
        children.add(_filledButton(
          label: 'Accept',
          icon: Icons.person_add_alt_1,
          onTap: _acceptRequest,
        ));
        children.add(const SizedBox(width: 8));
        children.add(_outlineIconButton(Icons.close, _declineRequest));
        break;
      case _FriendState.pending:
        children.add(_outlineButton(
          label: 'Pending',
          icon: Icons.hourglass_empty,
          onTap: _cancelRequest,
        ));
        break;
      case _FriendState.bot:
        children.add(_filledButton(
          label: 'Message',
          icon: Icons.chat_bubble_outline,
          onTap: _openMessage,
        ));
        break;
      case _FriendState.none:
        children.add(_filledButton(
          label: 'Connect',
          icon: Icons.person_add_alt_1,
          onTap: _addFriend,
        ));
        break;
      case _FriendState.self:
        break;
    }

    children.add(const SizedBox(width: 8));
    children.add(_moreButton());
    return Row(children: children);
  }

  Widget _filledButton({
    required String label,
    required IconData icon,
    required Future<void> Function() onTap,
  }) {
    return Opacity(
      opacity: _busy ? 0.6 : 1.0,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _busy ? null : () => onTap(),
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 60),
          decoration: BoxDecoration(
            color: _appBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ).withClickCursor(enabled: !_busy),
    );
  }

  Widget _outlineButton({
    required String label,
    required IconData icon,
    required Future<void> Function() onTap,
  }) {
    return Opacity(
      opacity: _busy ? 0.6 : 1.0,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _busy ? null : () => onTap(),
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 60),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderGray),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: _black),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _black,
                ),
              ),
            ],
          ),
        ),
      ).withClickCursor(enabled: !_busy),
    );
  }

  Widget _outlineIconButton(IconData icon, Future<void> Function() onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _busy ? null : () => onTap(),
      mouseCursor: SystemMouseCursors.click,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderGray),
        ),
        child: Icon(icon, size: 16, color: _black),
      ),
    ).withClickCursor(enabled: !_busy);
  }

  Widget _moreButton() {
    return PopupMenuButton<String>(
      tooltip: 'More',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'block',
          child: desktopClickableMenuChild(
            Text(
              'Block user',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFFF3B30),
              ),
            ),
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'block') _confirmBlockUser();
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderGray),
        ),
        child: const Icon(Icons.more_horiz, size: 18, color: _black),
      ),
    ).withClickCursor();
  }

  Widget _buildMutualTabs() {
    final friendLabel = _mutualFriends.length == 1
        ? '1 mutual friend'
        : '${_mutualFriends.length} mutual friends';
    final groupLabel = _mutualGroups.length == 1
        ? '1 mutual group'
        : '${_mutualGroups.length} mutual groups';

    return SizedBox(
      height: 36,
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(child: _tabButton(label: friendLabel, index: 0)),
              Expanded(child: _tabButton(label: groupLabel, index: 1)),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth = constraints.maxWidth / 2;
                return SizedBox(
                  height: 2.5,
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        left: _tabIndex * tabWidth,
                        width: tabWidth,
                        top: 0,
                        bottom: 0,
                        child: Container(color: _appBlue),
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

  Widget _tabButton({required String label, required int index}) {
    final selected = _tabIndex == index;
    return InkWell(
      onTap: () => setState(() => _tabIndex = index),
      mouseCursor: SystemMouseCursors.click,
      child: Align(
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? _black : _labelGray,
          ),
        ),
      ),
    ).withClickCursor();
  }

  Widget _buildMutualFriendsList() {
    if (_mutualFriends.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No mutual friends',
          style: GoogleFonts.inter(fontSize: 13, color: _labelGray),
        ),
      );
    }
    return Column(
      children: _mutualFriends.map((u) {
        final name = valueOrDefault<String>(u.displayName, 'N/A');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              _buildAvatar(imageUrl: u.photoUrl, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _black,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMutualGroupsList() {
    if (_mutualGroups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No mutual groups',
          style: GoogleFonts.inter(fontSize: 13, color: _labelGray),
        ),
      );
    }
    return Column(
      children: _mutualGroups.map((c) {
        final title = valueOrDefault<String>(c.title, 'Group');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              _buildAvatar(
                imageUrl: c.chatImageUrl,
                size: 32,
                isGroup: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _black,
                      ),
                    ),
                    Text(
                      '${c.members.length} members',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _labelGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
