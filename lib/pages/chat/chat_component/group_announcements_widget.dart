import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/backend/backend.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';
import '/pages/desktop_chat/rest_poll_builder.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Right-side panel for viewing and managing group announcements.
/// Admins (chat.admin or chat.created_by) can create, pin, and delete.
/// All members can confirm/acknowledge announcements.
class GroupAnnouncementsWidget extends StatefulWidget {
  const GroupAnnouncementsWidget({
    super.key,
    required this.chatDoc,
    this.onClose,
  });

  final ChatsRecord? chatDoc;
  final VoidCallback? onClose;

  @override
  State<GroupAnnouncementsWidget> createState() =>
      _GroupAnnouncementsWidgetState();
}

class _GroupAnnouncementsWidgetState extends State<GroupAnnouncementsWidget> {
  final TextEditingController _contentController = TextEditingController();
  bool _isCreating = false;
  bool _isSending = false;

  bool get _isAdmin {
    final chat = widget.chatDoc;
    if (chat == null) return false;
    return chat.admin == currentUserReference ||
        chat.createdBy == currentUserReference;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _createAnnouncement() async {
    final content = _contentController.text.trim();
    if (content.isEmpty || widget.chatDoc == null) return;

    setState(() => _isSending = true);

    try {
      final pinned = await fsQueryPinnedAnnouncements(
        widget.chatDoc!.reference,
        limit: 50,
      );
      for (final ann in pinned) {
        await fsPatchDocument(ann.reference, {'is_pinned': false});
      }

      await fsCreateSubcollectionDocument(
        parentRef: widget.chatDoc!.reference,
        collectionId: 'announcements',
        data: createAnnouncementsRecordData(
          content: content,
          createdAt: getCurrentTimestamp,
          createdBy: currentUserReference,
          creatorName: currentUserDocument?.displayName ?? '',
          isPinned: true,
        ),
      );

      _contentController.clear();
      setState(() {
        _isCreating = false;
        _isSending = false;
      });
    } catch (e) {
      print('Error creating announcement: $e');
      setState(() => _isSending = false);
    }
  }

  Future<void> _deleteAnnouncement(AnnouncementsRecord ann) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement'),
        content:
            const Text('Are you sure you want to delete this announcement?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await fsDeleteDocument(ann.reference);
    }
  }

  Future<void> _togglePin(AnnouncementsRecord ann) async {
    if (ann.isPinned) {
      await fsPatchDocument(ann.reference, {'is_pinned': false});
    } else {
      final pinned = await fsQueryPinnedAnnouncements(
        widget.chatDoc!.reference,
        limit: 50,
      );
      for (final existing in pinned) {
        await fsPatchDocument(existing.reference, {'is_pinned': false});
      }
      await fsPatchDocument(ann.reference, {'is_pinned': true});
    }
  }

  Future<void> _toggleConfirm(AnnouncementsRecord ann) async {
    final uid = currentUserReference;
    if (uid == null) return;

    if (ann.confirmedBy.contains(uid)) {
      await fsArrayRemove(ann.reference, 'confirmed_by', [uid]);
    } else {
      await fsArrayUnion(ann.reference, 'confirmed_by', [uid]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chatDoc == null) {
      return const Center(child: Text('No chat selected'));
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildAnnouncementList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_rounded,
              color: Color(0xFF3B82F6), size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Announcements',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF111827),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_isAdmin && !_isCreating)
            InkWell(
              onTap: () => setState(() => _isCreating = true),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'New',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 8),
          InkWell(
            onTap: widget.onClose,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, color: Color(0xFF9CA3AF), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementList() {
    return Column(
      children: [
        // Create new announcement form
        if (_isCreating) _buildCreateForm(),
        // Announcement list
        Expanded(
          child: useWindowsFirestoreRest
              ? RestPollBuilder<List<AnnouncementsRecord>>(
                  interval: const Duration(seconds: 30),
                  fetch: () => fsQueryChatAnnouncements(
                    widget.chatDoc!.reference,
                  ),
                  builder: (context, snapshot) =>
                      _buildAnnouncementListBody(snapshot),
                )
              : StreamBuilder<List<AnnouncementsRecord>>(
                  stream: queryAnnouncementsRecord(
                    parent: widget.chatDoc!.reference,
                    queryBuilder: (q) =>
                        q.orderBy('created_at', descending: true),
                  ),
                  builder: (context, snapshot) =>
                      _buildAnnouncementListBody(snapshot),
                ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementListBody(
    AsyncSnapshot<List<AnnouncementsRecord>> snapshot,
  ) {
    if (snapshot.hasError) {
      print('❌ [Announcements] Stream error: ${snapshot.error}');
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined,
                color: Color(0xFFD1D5DB), size: 48),
            const SizedBox(height: 12),
            Text(
              'No announcements yet',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF9CA3AF),
                fontSize: 14,
              ),
            ),
            if (_isAdmin) ...[
              const SizedBox(height: 8),
              Text(
                'Tap "+ New" to create one',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFFD1D5DB),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      );
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    final announcements = snapshot.data!;
    if (announcements.isEmpty && !_isCreating) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined,
                color: Color(0xFFD1D5DB), size: 48),
            const SizedBox(height: 12),
            Text(
              'No announcements yet',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF9CA3AF),
                fontSize: 14,
              ),
            ),
            if (_isAdmin) ...[
              const SizedBox(height: 8),
              Text(
                'Tap "+ New" to create one',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFFD1D5DB),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: announcements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _buildAnnouncementCard(announcements[index]),
    );
  }

  Widget _buildCreateForm() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New Announcement',
            style: TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFF1E40AF),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _contentController,
            maxLines: 4,
            autofocus: true,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF111827),
            ),
            decoration: InputDecoration(
              hintText: 'Type your announcement...',
              hintStyle: TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF9CA3AF),
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF3B82F6)),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _isCreating = false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSending ? null : _createAnnouncement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Publish',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(AnnouncementsRecord ann) {
    final isConfirmed =
        currentUserReference != null && ann.confirmedBy.contains(currentUserReference);
    final memberCount = widget.chatDoc?.members.length ?? 0;
    final confirmedCount = ann.confirmedBy.length;
    final timeAgo = ann.createdAt != null
        ? _formatTimeAgo(ann.createdAt!)
        : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ann.isPinned ? const Color(0xFFFFF7ED) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              ann.isPinned ? const Color(0xFFFBBF24) : const Color(0xFFE5E7EB),
          width: ann.isPinned ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: pin badge + admin actions
          Row(
            children: [
              if (ann.isPinned)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.push_pin, color: Color(0xFFD97706), size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Pinned',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFFD97706),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              if (_isAdmin)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'pin') _togglePin(ann);
                    if (value == 'delete') _deleteAnnouncement(ann);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'pin',
                      child: Row(children: [
                        Icon(Icons.push_pin,
                            size: 16, color: Color(0xFF374151)),
                        SizedBox(width: 8),
                        Text(ann.isPinned ? 'Unpin' : 'Pin to top'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                  icon: const Icon(Icons.more_horiz,
                      color: Color(0xFF9CA3AF), size: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  color: Colors.white,
                  elevation: 4,
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Content
          Text(
            ann.content,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFF111827),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // Footer: author + time + confirmation
          Row(
            children: [
              Icon(Icons.person_outline,
                  color: Color(0xFF9CA3AF), size: 14),
              const SizedBox(width: 4),
              Text(
                ann.creatorName.isNotEmpty ? ann.creatorName : 'Admin',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.access_time, color: Color(0xFF9CA3AF), size: 14),
              const SizedBox(width: 4),
              Text(
                timeAgo,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Confirmation bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: confirmedCount > 0
                      ? const Color(0xFF10B981)
                      : const Color(0xFFD1D5DB),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$confirmedCount / $memberCount confirmed',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _toggleConfirm(ann),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isConfirmed
                          ? const Color(0xFF10B981).withOpacity(0.1)
                          : const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isConfirmed
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          color: isConfirmed
                              ? const Color(0xFF10B981)
                              : const Color(0xFF3B82F6),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isConfirmed ? 'Confirmed' : 'Confirm',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: isConfirmed
                                ? const Color(0xFF10B981)
                                : const Color(0xFF3B82F6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Expandable: who confirmed
          if (_isAdmin && confirmedCount > 0)
            _buildConfirmedByList(ann),
        ],
      ),
    );
  }

  Widget _buildConfirmedByList(AnnouncementsRecord ann) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        title: Text(
          'View who confirmed',
          style: TextStyle(
            fontFamily: 'Inter',
            color: Color(0xFF6B7280),
            fontSize: 12,
          ),
        ),
        children: ann.confirmedBy.map((ref) {
          return FutureBuilder<UsersRecord>(
            future: UsersRecord.getDocumentOnce(ref),
            builder: (context, snap) {
              final name = snap.data?.displayName ?? '...';
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check,
                        color: Color(0xFF10B981), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}
