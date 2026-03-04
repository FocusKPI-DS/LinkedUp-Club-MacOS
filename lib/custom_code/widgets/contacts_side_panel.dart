import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/desktop_chat/chat_controller.dart';
import '/utils/chat_helpers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ContactsSidePanel extends StatefulWidget {
  const ContactsSidePanel({Key? key}) : super(key: key);

  @override
  _ContactsSidePanelState createState() => _ContactsSidePanelState();
}

class _ContactsSidePanelState extends State<ContactsSidePanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Color(0xFF374151),
        border: Border(
          right: BorderSide(
            color: Color(0xFF4B5563),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),
          // Search Bar
          _buildSearchBar(),
          // Contacts List
          Expanded(child: _buildContactsList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF374151),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF4B5563),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.contacts,
            color: Colors.white,
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Contacts',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Color(0xFF4B5563),
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search contacts...',
            hintStyle: TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFF9CA3AF),
              fontSize: 14,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.white,
              size: 18,
            ),
          ),
          style: TextStyle(
            fontFamily: 'Inter',
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildContactsList() {
    return StreamBuilder<List<WorkspaceMembersRecord>>(
      stream: queryWorkspaceMembersRecord(
        queryBuilder: (workspaceMembersRecord) => workspaceMembersRecord.where(
            'workspace_ref',
            isEqualTo: currentUserDocument?.currentWorkspaceRef),
      ),
      builder: (context, membersSnapshot) {
        if (!membersSnapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          );
        }

        final members = membersSnapshot.data ?? [];

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];

            return StreamBuilder<UsersRecord>(
              stream: UsersRecord.getDocument(member.userRef ??
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc('placeholder')),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return SizedBox.shrink();
                }

                final user = userSnapshot.data!;
                final isCurrentUser = user.reference == currentUserReference;

                if (isCurrentUser) {
                  return SizedBox.shrink();
                }

                return InkWell(
                  onTap: () async {
                    await _startNewChatWithUser(user);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFF374151),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        // Avatar
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              imageUrl: user.photoUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: Color(0xFF6B7280),
                                  size: 18,
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: Color(0xFF6B7280),
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        // User Info
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user.displayName,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getRoleColor(member.role),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      member.role.toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 2),
                              Text(
                                user.email,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Tap to start messaging',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Color(0xFF3B82F6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Chat icon
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Color(0xFF3B82F6),
                          size: 18,
                        ),
                      ],
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

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Color(0xFFDC2626); // Red
      case 'moderator':
        return Color(0xFF059669); // Green
      case 'member':
        return Color(0xFF6B7280); // Gray
      default:
        return Color(0xFF6B7280); // Default gray
    }
  }

  Future<void> _startNewChatWithUser(UsersRecord user) async {
    try {
      final chatController = Get.find<ChatController>();
      final chat =
          await ChatHelpers.findOrCreateDirectChat(user.reference);
      chatController.selectChat(chat);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accessing chat: $e'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }
}
