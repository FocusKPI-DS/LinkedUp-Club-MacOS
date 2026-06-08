import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/desktop_chat/desktop_safe_user_builder.dart';
import 'dart:io';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class AddGroupMembersWidget extends StatefulWidget {
  const AddGroupMembersWidget({
    super.key,
    required this.chatDoc,
  });

  final ChatsRecord? chatDoc;

  static String routeName = 'AddGroupMembers';
  static String routePath = '/addGroupMembers';

  @override
  State<AddGroupMembersWidget> createState() => _AddGroupMembersWidgetState();
}

class _AddGroupMembersWidgetState extends State<AddGroupMembersWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  List<DocumentReference> _selectedMembers = [];
  String _searchQuery = '';
  int _originalMemberCount = 0;

  @override
  void initState() {
    super.initState();
    // Initialize with current members
    _selectedMembers = widget.chatDoc?.members.toList() ?? [];
    _originalMemberCount = _selectedMembers.length;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleMember(DocumentReference memberRef) {
    if (Platform.isIOS) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      if (_selectedMembers.any((m) => m.id == memberRef.id)) {
        _selectedMembers.removeWhere((m) => m.id == memberRef.id);
      } else {
        _selectedMembers.add(memberRef);
      }
    });
  }

  bool _isMemberSelected(DocumentReference memberRef) {
    return _selectedMembers.any((m) => m.id == memberRef.id);
  }

  int get _addedCount => _selectedMembers.length - _originalMemberCount;

  Future<void> _addMembers() async {
    if (widget.chatDoc == null) return;
    if (_addedCount <= 0) {
      Navigator.of(context).pop();
      return;
    }

    try {
      // Update the members list
      await fsPatchDocument(widget.chatDoc!.reference, {
        ...mapToFirestore({
          'members': _selectedMembers,
        }),
      });

      // Send system message
      final userName = currentUserDisplayName.isNotEmpty
          ? currentUserDisplayName
          : (currentUserDocument?.displayName ?? 'Someone');

      final systemMessage = '$userName added $_addedCount ${_addedCount == 1 ? 'member' : 'members'}';

      await fsCreateMessage(
        widget.chatDoc!.reference,
        {
          'content': systemMessage,
          'chat_ref': widget.chatDoc!.reference,
          'sender_ref': currentUserReference,
          'timestamp': getCurrentTimestamp,
          'message_type': 'system',
        },
      );

      // Update chat's last_message fields for preview
      await fsPatchDocument(widget.chatDoc!.reference, {
        'last_message': systemMessage,
        'last_message_at': getCurrentTimestamp,
        'last_message_sent': currentUserReference,
        'last_message_type': MessageType.text.serialize(),
      });

      if (mounted) {
        // Show success and pop back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Members added successfully'),
            backgroundColor: Color(0xFF34C759),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add members'),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            // Search bar
            _buildSearchBar(),
            // Members list
            Expanded(
              child: _buildMembersList(),
            ),
            // Add button at bottom
            _buildAddButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button - iOS 26+ style with liquid glass effects (same as mobile_chat_widget)
          LiquidStretch(
            stretch: 0.5,
            interactionScale: 1.05,
            child: GlassGlow(
              glowColor: Colors.white24,
              glowRadius: 1.0,
              child: AdaptiveFloatingActionButton(
                onPressed: () {
                  if (Platform.isIOS) {
                    HapticFeedback.lightImpact();
                  }
                  Navigator.of(context).pop();
                },
                mini: true,
                backgroundColor: Colors.white,
                foregroundColor: CupertinoColors.systemBlue,
                child: Icon(
                  CupertinoIcons.chevron_left,
                  size: 22,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          // Title
          Expanded(
            child: Text(
              'Add Members',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
          style: TextStyle(
            fontFamily: 'SF Pro Text',
            fontSize: 16,
            color: Color(0xFF1C1C1E),
          ),
          decoration: InputDecoration(
            hintText: 'Search connections',
            hintStyle: TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 16,
              color: Color(0xFF8E8E93),
            ),
            prefixIcon: Icon(
              CupertinoIcons.search,
              size: 20,
              color: Color(0xFF8E8E93),
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildMembersList() {
    return Container(
      color: Colors.white,
      child: AuthUserStreamWidget(
        builder: (context) => DesktopSafeUserPollBuilder(
          userRef: currentUserReference!,
          fetchOnce: fsGetUserOnce,
          builder: (context, currentUser) {
            if (currentUser == null) {
              return Center(
                child: CupertinoActivityIndicator(),
              );
            }

            final connections = currentUser.friends;
            final existingMembers = widget.chatDoc?.members.toList() ?? [];
            final workspaceRef = currentUser.currentWorkspaceRef;

            // Start with friends-based candidates
            final friendRefs = connections.where((ref) {
              if (ref.id == currentUserReference?.id) return false;
              return !existingMembers.any((member) => member.id == ref.id);
            }).toList();

            // If no workspace, just show friends
            if (workspaceRef == null) {
              return _buildCandidateList(friendRefs, []);
            }

            if (useWindowsFirestoreRest) {
              return FutureBuilder<List<DocumentReference>>(
                future: fsQueryWorkspaceMemberUserRefs(workspaceRef),
                builder: (context, wsSnapshot) {
                  List<DocumentReference> workspaceUserRefs = [];
                  if (wsSnapshot.hasData) {
                    final friendIds = friendRefs.map((r) => r.id).toSet();
                    for (final userRef in wsSnapshot.data!) {
                      if (userRef.id == currentUserReference?.id) continue;
                      if (existingMembers.any((m) => m.id == userRef.id)) {
                        continue;
                      }
                      if (friendIds.contains(userRef.id)) continue;
                      workspaceUserRefs.add(userRef);
                    }
                  }
                  return _buildCandidateList(friendRefs, workspaceUserRefs);
                },
              );
            }

            // Also query workspace members
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('workspace_members')
                  .where('workspace_ref', isEqualTo: workspaceRef)
                  .where('status', isEqualTo: 'active')
                  .snapshots(),
              builder: (context, wsSnapshot) {
                List<DocumentReference> workspaceUserRefs = [];
                if (wsSnapshot.hasData) {
                  final friendIds = friendRefs.map((r) => r.id).toSet();
                  for (final doc in wsSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final userRef = data['user_ref'] as DocumentReference?;
                    if (userRef == null) continue;
                    if (userRef.id == currentUserReference?.id) continue;
                    if (existingMembers.any((m) => m.id == userRef.id)) continue;
                    // Don't duplicate friends
                    if (friendIds.contains(userRef.id)) continue;
                    workspaceUserRefs.add(userRef);
                  }
                }

                return _buildCandidateList(friendRefs, workspaceUserRefs);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCandidateList(
    List<DocumentReference> friendRefs,
    List<DocumentReference> workspaceRefs,
  ) {
    final allRefs = [...friendRefs, ...workspaceRefs];
    if (allRefs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.person_2_fill,
              size: 64,
              color: Color(0xFFD1D1D6),
            ),
            SizedBox(height: 16),
            Text(
              'No users available to add',
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                fontSize: 16,
                color: Color(0xFF8E8E93),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'All workspace members are already in this group',
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                fontSize: 14,
                color: Color(0xFFAEAEB2),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (friendRefs.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Your Connections',
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E8E93),
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...friendRefs.map((userRef) => _buildUserStreamTile(userRef)),
        ],
        if (workspaceRefs.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Workspace Members',
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E8E93),
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...workspaceRefs.map((userRef) => _buildUserStreamTile(userRef)),
        ],
      ],
    );
  }

  Widget _buildUserStreamTile(DocumentReference userRef) {
    return StreamBuilder<UsersRecord>(
      stream: UsersRecord.getDocument(userRef),
      builder: (context, snapshot) {
        // If error or document doesn't exist, hide this tile completely
        if (snapshot.hasError) {
          return SizedBox.shrink();
        }

        if (!snapshot.hasData) {
          // Show a compact loading shimmer instead of empty space
          return Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(12),
            height: 68,
            decoration: BoxDecoration(
              color: Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(width: 24, height: 24, decoration: BoxDecoration(
                  color: Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(6),
                )),
                SizedBox(width: 12),
                Container(width: 44, height: 44, decoration: BoxDecoration(
                  color: Color(0xFFE5E5EA), shape: BoxShape.circle,
                )),
                SizedBox(width: 12),
                Expanded(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 14, width: 120, decoration: BoxDecoration(
                      color: Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(4),
                    )),
                    SizedBox(height: 6),
                    Container(height: 12, width: 180, decoration: BoxDecoration(
                      color: Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(4),
                    )),
                  ],
                )),
              ],
            ),
          );
        }

        final user = snapshot.data!;

        // Skip users with empty display name (likely deleted/invalid)
        if (user.displayName.isEmpty && user.email.isEmpty) {
          return SizedBox.shrink();
        }

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          final name = user.displayName.toLowerCase();
          final email = user.email.toLowerCase();
          if (!name.contains(_searchQuery) && !email.contains(_searchQuery)) {
            return SizedBox.shrink();
          }
        }

        final isSelected = _isMemberSelected(userRef);

        return _buildUserTile(user, userRef, isSelected);
      },
    );
  }

  Widget _buildUserTile(UsersRecord user, DocumentReference userRef, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleMember(userRef),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Color(0xFF007AFF) : Color(0xFFE5E5EA),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFF007AFF) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? Color(0xFF007AFF) : Color(0xFFD1D1D6),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      CupertinoIcons.checkmark,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            SizedBox(width: 12),
            // Avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: CachedNetworkImage(
                imageUrl: user.photoUrl.isNotEmpty
                    ? user.photoUrl
                    : 'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdiv.png?alt=media&token=85d5445a-3d2d-4dd5-879e-c4000b1fefd5',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    CupertinoIcons.person_fill,
                    size: 22,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    CupertinoIcons.person_fill,
                    size: 22,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName.isNotEmpty ? user.displayName : 'Unknown',
                    style: TextStyle(
                      fontFamily: 'SF Pro Text',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    user.email,
                    style: TextStyle(
                      fontFamily: 'SF Pro Text',
                      fontSize: 14,
                      color: Color(0xFF8E8E93),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    final canAdd = _addedCount > 0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: canAdd
              ? () {
                  if (Platform.isIOS) {
                    HapticFeedback.mediumImpact();
                  }
                  _addMembers();
                }
              : null,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: canAdd ? Color(0xFF007AFF) : Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (canAdd)
                  Icon(
                    CupertinoIcons.checkmark,
                    size: 18,
                    color: Colors.white,
                  ),
                if (canAdd) SizedBox(width: 8),
                Text(
                  canAdd
                      ? 'Add $_addedCount ${_addedCount == 1 ? 'member' : 'members'}'
                      : 'Select members to add',
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: canAdd ? Colors.white : Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
