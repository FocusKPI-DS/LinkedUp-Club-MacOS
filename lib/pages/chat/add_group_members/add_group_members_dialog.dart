import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/desktop_chat/rest_poll_builder.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

final Map<String, Future<UsersRecord>> _addMemberUserFutureCache = {};
final Map<String, UsersRecord> _addMemberUserRecordCache = {};

Future<UsersRecord> _getCachedUserOnce(DocumentReference ref) {
  if (!fsIsRealUserRef(ref)) {
    final cached = _addMemberUserRecordCache[ref.id];
    if (cached != null) return Future.value(cached);
    final synthetic = fsSyntheticAgentUser(ref);
    _addMemberUserRecordCache[ref.id] = synthetic;
    return Future.value(synthetic);
  }

  final cached = _addMemberUserRecordCache[ref.id];
  if (cached != null) return Future.value(cached);

  return _addMemberUserFutureCache.putIfAbsent(ref.id, () async {
    try {
      final user = await fsGetUserOnce(ref);
      _addMemberUserRecordCache[ref.id] = user;
      return user;
    } catch (e) {
      _addMemberUserFutureCache.remove(ref.id);
      rethrow;
    }
  });
}

class _CandidateListEntry {
  const _CandidateListEntry.header(this.label) : userRef = null;
  const _CandidateListEntry.user(this.userRef) : label = null;

  final String? label;
  final DocumentReference? userRef;
  bool get isHeader => label != null;
}

Future<void> showAddGroupMembersDialog({
  required BuildContext context,
  required ChatsRecord chat,
  VoidCallback? onMembersAdded,
}) async {
  if (!chat.isGroup) return;

  final searchController = TextEditingController();
  var selectedMembers = List<DocumentReference>.from(chat.members);
  final originalMemberCount = chat.members.length;

  await showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final addedCount = selectedMembers.length - originalMemberCount;

          void toggleMember(DocumentReference memberRef) {
            setDialogState(() {
              if (selectedMembers.any((m) => m.id == memberRef.id)) {
                selectedMembers.removeWhere((m) => m.id == memberRef.id);
              } else {
                selectedMembers.add(memberRef);
              }
            });
          }

          bool isMemberSelected(DocumentReference memberRef) {
            return selectedMembers.any((m) => m.id == memberRef.id);
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Container(
              width: 500,
              constraints: const BoxConstraints(
                maxWidth: 500.0,
                maxHeight: 600.0,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AddMembersDialogHeader(
                    onClose: () => Navigator.of(dialogContext).pop(),
                  ),
                  _AddMembersSearchBar(controller: searchController, onChanged: () {
                    setDialogState(() {});
                  }),
                  Expanded(
                    child: _AddMembersCandidatePanel(
                      chat: chat,
                      searchQuery: searchController.text.toLowerCase(),
                      isMemberSelected: isMemberSelected,
                      onToggleMember: toggleMember,
                    ),
                  ),
                  if (addedCount > 0)
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(16.0),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await fsPatchDocument(chat.reference, {
                                ...mapToFirestore({
                                  'members': selectedMembers,
                                }),
                              });

                              final userName =
                                  currentUserDisplayName.isNotEmpty
                                      ? currentUserDisplayName
                                      : (currentUserDocument?.displayName ??
                                          'Someone');
                              final systemMessage =
                                  '$userName added $addedCount ${addedCount == 1 ? 'member' : 'members'}';

                              await fsCreateMessage(
                                chat.reference,
                                {
                                  'content': systemMessage,
                                  'chat_ref': chat.reference,
                                  'sender_ref': currentUserReference,
                                  'timestamp': getCurrentTimestamp,
                                  'message_type': 'system',
                                },
                              );

                              await fsPatchDocument(chat.reference, {
                                'last_message': systemMessage,
                                'last_message_at': getCurrentTimestamp,
                                'last_message_sent': currentUserReference,
                                'last_message_type':
                                    MessageType.text.serialize(),
                              });

                              if (context.mounted) {
                                Navigator.of(dialogContext).pop();
                                onMembersAdded?.call();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to add members'),
                                    backgroundColor: Color(0xFFEF4444),
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check, size: 20.0),
                              const SizedBox(width: 8.0),
                              Text(
                                'Add $addedCount ${addedCount == 1 ? 'member' : 'members'}',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w600,
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
          );
        },
      );
    },
  );

  searchController.dispose();
}

List<DocumentReference> _filterWorkspaceCandidates(
  List<DocumentReference> workspaceRefs,
  List<DocumentReference> friendRefs,
  List<DocumentReference> existingMembers,
) {
  final friendIds = friendRefs.map((r) => r.id).toSet();
  return workspaceRefs.where((userRef) {
    if (userRef.id == currentUserReference?.id) return false;
    if (existingMembers.any((m) => m.id == userRef.id)) return false;
    if (friendIds.contains(userRef.id)) return false;
    return true;
  }).toList();
}

class _AddMembersCandidatePanel extends StatefulWidget {
  const _AddMembersCandidatePanel({
    required this.chat,
    required this.searchQuery,
    required this.isMemberSelected,
    required this.onToggleMember,
  });

  final ChatsRecord chat;
  final String searchQuery;
  final bool Function(DocumentReference ref) isMemberSelected;
  final void Function(DocumentReference ref) onToggleMember;

  @override
  State<_AddMembersCandidatePanel> createState() =>
      _AddMembersCandidatePanelState();
}

class _AddMembersCandidatePanelState extends State<_AddMembersCandidatePanel> {
  bool _loading = true;
  List<DocumentReference> _friendRefs = [];
  List<DocumentReference> _workspaceRefs = [];
  final Map<String, UsersRecord> _usersById = {};

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    try {
      final currentUserRef = currentUserReference;
      if (currentUserRef == null) return;

      final currentUser =
          currentUserDocument ?? await fsGetUserOnce(currentUserRef);
      final existingMembers = widget.chat.members.toList();
      final workspaceRef = currentUser.currentWorkspaceRef;

      final friendRefs = currentUser.friends.where((ref) {
        if (ref.id == currentUserRef.id) return false;
        return !existingMembers.any((member) => member.id == ref.id);
      }).toList();

      var workspaceRefs = <DocumentReference>[];
      if (workspaceRef != null) {
        if (useWindowsFirestoreRest) {
          final wsRefs = await fsQueryWorkspaceMemberUserRefs(workspaceRef);
          workspaceRefs = _filterWorkspaceCandidates(
            wsRefs,
            friendRefs,
            existingMembers,
          );
        } else {
          final wsSnapshot = await FirebaseFirestore.instance
              .collection('workspace_members')
              .where('workspace_ref', isEqualTo: workspaceRef)
              .where('status', isEqualTo: 'active')
              .get();
          final friendIds = friendRefs.map((r) => r.id).toSet();
          for (final doc in wsSnapshot.docs) {
            final data = doc.data();
            final userRef = data['user_ref'] as DocumentReference?;
            if (userRef == null) continue;
            if (userRef.id == currentUserRef.id) continue;
            if (existingMembers.any((m) => m.id == userRef.id)) continue;
            if (friendIds.contains(userRef.id)) continue;
            workspaceRefs.add(userRef);
          }
        }
      }

      final allRefs = [...friendRefs, ...workspaceRefs];
      for (final ref in allRefs) {
        if (_usersById.containsKey(ref.id)) continue;
        try {
          _usersById[ref.id] = await _getCachedUserOnce(ref);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _friendRefs = friendRefs;
        _workspaceRefs = workspaceRefs;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _matchesSearch(UsersRecord user) {
    if (widget.searchQuery.isEmpty) return true;
    final name = user.displayName.toLowerCase();
    final email = user.email.toLowerCase();
    return name.contains(widget.searchQuery) ||
        email.contains(widget.searchQuery);
  }

  List<_CandidateListEntry> _visibleEntries() {
    final entries = <_CandidateListEntry>[];
    final visibleFriends = _friendRefs
        .map((ref) => _usersById[ref.id])
        .whereType<UsersRecord>()
        .where(_matchesSearch)
        .toList();
    final visibleWorkspace = _workspaceRefs
        .map((ref) => _usersById[ref.id])
        .whereType<UsersRecord>()
        .where(_matchesSearch)
        .toList();

    if (visibleFriends.isNotEmpty) {
      entries.add(const _CandidateListEntry.header('Suggested'));
      entries.addAll(
        visibleFriends.map((user) => _CandidateListEntry.user(user.reference)),
      );
    }
    if (visibleWorkspace.isNotEmpty) {
      entries.add(const _CandidateListEntry.header('Workspace Members'));
      entries.addAll(
        visibleWorkspace
            .map((user) => _CandidateListEntry.user(user.reference)),
      );
    }
    return entries;
  }

  Widget _buildUserList(List<_CandidateListEntry> entries) {
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'No matches found',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.0,
            color: Color(0xFF9CA3AF),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        if (entry.isHeader) {
          return _SectionLabel(entry.label!);
        }
        final userRef = entry.userRef!;
        final user = _usersById[userRef.id];
        if (user == null) return const SizedBox.shrink();
        return _AddMemberCandidateTile(
          user: user,
          isSelected: widget.isMemberSelected(userRef),
          onToggle: () => widget.onToggleMember(userRef),
        );
      },
    );
  }

  List<_CandidateListEntry> _globalSearchEntries(List<UsersRecord> allUsers) {
    final existingIds = widget.chat.members.map((m) => m.id).toSet();
    final filtered = allUsers.where((user) {
      if (user.reference.id == currentUserReference?.id) return false;
      if (existingIds.contains(user.reference.id)) return false;
      if (user.displayName.isEmpty && user.email.isEmpty) return false;
      return _matchesSearch(user);
    }).toList()
      ..sort((a, b) => a.displayName
          .toLowerCase()
          .compareTo(b.displayName.toLowerCase()));

    for (final user in filtered) {
      _usersById[user.reference.id] = user;
    }

    return filtered
        .map((user) => _CandidateListEntry.user(user.reference))
        .toList();
  }

  Widget _buildGlobalSearchResults() {
    Widget buildFromSnapshot(AsyncSnapshot<List<UsersRecord>> snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: Text(
            'Error loading users',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.0,
              color: Color(0xFF9CA3AF),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
          ),
        );
      }
      return _buildUserList(_globalSearchEntries(snapshot.data!));
    }

    if (useWindowsFirestoreRest) {
      return RestPollBuilder<List<UsersRecord>>(
        interval: const Duration(seconds: 30),
        fetch: () => fsQueryUsers(limit: 200),
        builder: (context, snapshot) => buildFromSnapshot(snapshot),
      );
    }

    return StreamBuilder<List<UsersRecord>>(
      stream: queryUsersRecord(),
      builder: (context, snapshot) => buildFromSnapshot(snapshot),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.searchQuery.isNotEmpty) {
      return _buildGlobalSearchResults();
    }

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
        ),
      );
    }

    if (_friendRefs.isEmpty && _workspaceRefs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search,
                size: 48.0,
                color: Color(0xFFE5E7EB),
              ),
              SizedBox(height: 16.0),
              Text(
                'Search for people',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              SizedBox(height: 8.0),
              Text(
                'Search by name or email to find people to add',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.0,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildUserList(_visibleEntries());
  }
}

class _AddMembersDialogHeader extends StatelessWidget {
  const _AddMembersDialogHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onClose,
            child: const Icon(
              Icons.close,
              color: Color(0xFF6B7280),
              size: 24.0,
            ),
          ),
          const SizedBox(width: 16.0),
          const Expanded(
            child: Text(
              'Add member',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18.0,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1F36),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMembersSearchBar extends StatelessWidget {
  const _AddMembersSearchBar({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16.0, right: 8.0),
              child: Icon(
                Icons.search,
                color: Color(0xFF6B7280),
                size: 20.0,
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.0,
                  color: Color(0xFF1A1F36),
                ),
                decoration: const InputDecoration(
                  hintText: 'Search by name or email',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.0,
                    color: Color(0xFF9CA3AF),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 12.0,
                  ),
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13.0,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }
}

class _AddMemberCandidateTile extends StatelessWidget {
  const _AddMemberCandidateTile({
    required this.user,
    required this.isSelected,
    required this.onToggle,
  });

  final UsersRecord user;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (user.displayName.isEmpty && user.email.isEmpty) {
      return const SizedBox.shrink();
    }

    return InkWell(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFF3F4F6),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20.0,
                  height: 20.0,
                  margin: const EdgeInsets.only(right: 12.0),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF3B82F6)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFFD1D5DB),
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14.0,
                        )
                      : null,
                ),
                Container(
                  width: 48.0,
                  height: 48.0,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEBF4FF),
                    shape: BoxShape.circle,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24.0),
                    child: user.photoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: user.photoUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => const Icon(
                              Icons.person,
                              color: Color(0xFF3B82F6),
                              size: 24.0,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            color: Color(0xFF3B82F6),
                            size: 24.0,
                          ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16.0,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1F36),
                        ),
                      ),
                      if (user.email.isNotEmpty)
                        Text(
                          user.email,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.0,
                            color: Color(0xFF6B7280),
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
