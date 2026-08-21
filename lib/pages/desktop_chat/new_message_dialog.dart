import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/pages/desktop_chat/desktop_safe_user_builder.dart';
import '/utils/desktop_pointer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

typedef NewMessageDialogSubmit = Future<void> Function(
  List<DocumentReference> selectedMembers,
);

Future<void> showNewMessageDialog({
  required BuildContext context,
  required TextEditingController searchController,
  required List<DocumentReference> initialSelectedMembers,
  required Future<UsersRecord> Function(DocumentReference ref) fetchUser,
  required NewMessageDialogSubmit onSubmit,
}) async {
  var selectedMembers =
      List<DocumentReference>.from(initialSelectedMembers);
  var isSubmitting = false;
  searchController.clear();

  await showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          void update(VoidCallback fn) => setDialogState(fn);

          final count = selectedMembers.length;
          final hasSelection = count > 0;
          final isGroup = count > 1;
          final actionLabel = !hasSelection
              ? 'Add people to start'
              : isGroup
                  ? 'Create Group ($count)'
                  : 'Start Direct Message';

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              width: 520,
              constraints:
                  const BoxConstraints(maxWidth: 520, maxHeight: 640),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Color(0xFFF0F4FF),
                    Color(0xFFE8F0FE),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _NewMessageDialogHeader(
                    selectedCount: count,
                    onClose: () => Navigator.of(dialogContext).pop(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                    child: _NewMessageSearchField(
                      controller: searchController,
                      onChanged: () => update(() {}),
                    ),
                  ),
                  if (selectedMembers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedMembers.map((memberRef) {
                          return _SelectedMemberChip(
                            memberRef: memberRef,
                            fetchUser: fetchUser,
                            onRemove: () => update(
                              () => selectedMembers.removeWhere(
                                (ref) => ref.id == memberRef.id,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SuggestedHeader(),
                          Expanded(
                            child: _SuggestedConnectionsList(
                              searchQuery:
                                  searchController.text.toLowerCase(),
                              selectedMembers: selectedMembers,
                              fetchUser: fetchUser,
                              onToggle: (userRef, selected) {
                                update(() {
                                  if (selected) {
                                    selectedMembers.removeWhere(
                                      (ref) => ref.id == userRef.id,
                                    );
                                  } else {
                                    selectedMembers.add(userRef);
                                    searchController.clear();
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      border: Border(
                        top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (!hasSelection || isSubmitting)
                            ? null
                            : () async {
                                update(() => isSubmitting = true);
                                try {
                                  await onSubmit(
                                    List<DocumentReference>.from(
                                      selectedMembers,
                                    ),
                                  );
                                  if (dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop();
                                  }
                                } finally {
                                  if (context.mounted) {
                                    update(() => isSubmitting = false);
                                  }
                                }
                              },
                        style: desktopClickableButtonStyle(
                          ElevatedButton.styleFrom(
                            backgroundColor: hasSelection
                                ? Color(0xFF3B82F6)
                                : Color(0xFF9CA3AF),
                            disabledBackgroundColor: Color(0xFFCBD5E1),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isGroup
                                        ? Icons.group_rounded
                                        : Icons.chat_bubble_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    actionLabel,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      color: Colors.white,
                                      fontSize: 15,
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
}

class _NewMessageDialogHeader extends StatelessWidget {
  const _NewMessageDialogHeader({
    required this.selectedCount,
    required this.onClose,
  });

  final int selectedCount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.topRight,
          colors: [
            Colors.white,
            Color(0xFFF8FAFF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFE5E7EB), width: 1),
              ),
              child: const Icon(
                Icons.close,
                color: Color(0xFF6B7280),
                size: 20,
              ),
            ),
          ).withClickCursor(),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Color(0xFF3B82F6),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Message',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF1A1F36),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  selectedCount > 1
                      ? 'Adding $selectedCount people — this will start a group chat'
                      : 'Add one person for a direct message, or more to start a group',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewMessageSearchField extends StatelessWidget {
  const _NewMessageSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF3B82F6).withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        onChanged: (_) => onChanged(),
        decoration: const InputDecoration(
          hintText: 'Type a name or email to add people',
          hintStyle: TextStyle(
            fontFamily: 'Inter',
            color: Color(0xFF94A3B8),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
          prefixIcon: Padding(
            padding: EdgeInsetsDirectional.only(start: 14, end: 10),
            child: Icon(
              Icons.person_add_alt_1_rounded,
              color: Color(0xFF3B82F6),
              size: 20,
            ),
          ),
        ),
        style: const TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFF1A1F36),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SelectedMemberChip extends StatelessWidget {
  const _SelectedMemberChip({
    required this.memberRef,
    required this.fetchUser,
    required this.onRemove,
  });

  final DocumentReference memberRef;
  final Future<UsersRecord> Function(DocumentReference ref) fetchUser;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return DesktopSafeUserBuilder(
      userRef: memberRef,
      fetchOnce: fetchUser,
      builder: (context, user) {
        final name = (user?.displayName.isNotEmpty ?? false)
            ? user!.displayName
            : (user?.email.split('@').first ?? 'User');
        return Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
          decoration: BoxDecoration(
            color: Color(0xFFEBF2FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Color(0xFFBFD4FF), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFDCE7FF),
                ),
                child: (user != null && user.photoUrl.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: user.photoUrl,
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Icon(
                          Icons.person,
                          size: 14,
                          color: Color(0xFF3B82F6),
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        size: 14,
                        color: Color(0xFF3B82F6),
                      ),
              ),
              const SizedBox(width: 6),
              Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1D4ED8),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Color(0xFF3B82F6),
                ),
              ).withClickCursor(),
            ],
          ),
        );
      },
    );
  }
}

class _SuggestedHeader extends StatelessWidget {
  const _SuggestedHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'SUGGESTED',
            style: TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFF475569),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedConnectionsList extends StatelessWidget {
  const _SuggestedConnectionsList({
    required this.searchQuery,
    required this.selectedMembers,
    required this.fetchUser,
    required this.onToggle,
  });

  final String searchQuery;
  final List<DocumentReference> selectedMembers;
  final Future<UsersRecord> Function(DocumentReference ref) fetchUser;
  final void Function(DocumentReference userRef, bool isSelected) onToggle;

  @override
  Widget build(BuildContext context) {
    return DesktopSafeUserBuilder(
      userRef: currentUserReference!,
      fetchOnce: fetchUser,
      builder: (context, currentUser) {
        if (currentUser == null) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color.fromARGB(255, 16, 184, 239),
            ),
          );
        }

        final connections = currentUser.friends;
        if (connections.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Color(0xFF3B82F6).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.people_outline_rounded,
                    color: Color(0xFF3B82F6),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No connections',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF1A1F36),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add connections to start chatting',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF64748B),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: connections.length,
          itemBuilder: (context, index) {
            final connectionRef = connections[index];
            return DesktopSafeUserBuilder(
              userRef: connectionRef,
              fetchOnce: fetchUser,
              builder: (context, user) {
                if (user == null ||
                    user.reference == currentUserReference) {
                  return const SizedBox.shrink();
                }

                final isSelected = selectedMembers
                    .any((ref) => ref.id == user.reference.id);

                if (searchQuery.isNotEmpty) {
                  final displayName = user.displayName.toLowerCase();
                  final email = user.email.toLowerCase();
                  if (!displayName.contains(searchQuery) &&
                      !email.contains(searchQuery)) {
                    return const SizedBox.shrink();
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFFEBF2FF) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Color(0xFF3B82F6)
                          : Color(0xFFE2E8F0),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      mouseCursor: MaterialStateMouseCursor.clickable,
                      onTap: () => onToggle(user.reference, isSelected),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Row(
                          children: [
                            _ConnectionAvatar(photoUrl: user.photoUrl),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.displayName,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      color: Color(0xFF111827),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user.email,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      color: Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Color(0xFF3B82F6)
                                    : Color(0xFF3B82F6).withOpacity(0.08),
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: Color(0xFFCBD5E1),
                                        width: 1.5,
                                      ),
                              ),
                              child: Icon(
                                isSelected
                                    ? Icons.check_rounded
                                    : Icons.add_rounded,
                                color: isSelected
                                    ? Colors.white
                                    : Color(0xFF3B82F6),
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ConnectionAvatar extends StatelessWidget {
  const _ConnectionAvatar({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: CachedNetworkImage(
            imageUrl: photoUrl,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            placeholder: (context, url) => _avatarPlaceholder(),
            errorWidget: (context, url, error) => _avatarPlaceholder(),
          ),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person_rounded,
        color: Color(0xFF64748B),
        size: 20,
      ),
    );
  }
}
