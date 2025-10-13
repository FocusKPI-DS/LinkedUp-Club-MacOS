import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'workspace_management_model.dart';

class WorkspaceManagementWidget extends StatefulWidget {
  const WorkspaceManagementWidget({super.key});

  @override
  State<WorkspaceManagementWidget> createState() =>
      _WorkspaceManagementWidgetState();
}

class _WorkspaceManagementWidgetState extends State<WorkspaceManagementWidget> {
  late WorkspaceManagementModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => WorkspaceManagementModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _model.unfocusNode.canRequestFocus
          ? FocusScope.of(context).requestFocus(_model.unfocusNode)
          : FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primary,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () async {
              context.pop();
            },
          ),
          title: Text(
            'Workspace Management',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontSize: 22,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w600,
                ),
          ),
          actions: [],
          centerTitle: false,
          elevation: 2,
        ),
        body: SafeArea(
          top: true,
          child: StreamBuilder<UsersRecord>(
            stream: UsersRecord.getDocument(currentUserReference!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              final currentUser = snapshot.data!;
              if (!currentUser.hasCurrentWorkspaceRef()) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.workspace_premium,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No workspace selected',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('Please select a workspace to manage'),
                    ],
                  ),
                );
              }

              return StreamBuilder<WorkspacesRecord>(
                stream: WorkspacesRecord.getDocument(
                    currentUser.currentWorkspaceRef!),
                builder: (context, workspaceSnapshot) {
                  if (!workspaceSnapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final workspace = workspaceSnapshot.data!;

                  return StreamBuilder<List<WorkspaceMembersRecord>>(
                    stream: queryWorkspaceMembersRecord(
                      queryBuilder: (workspaceMembersRecord) =>
                          workspaceMembersRecord.where('workspace_ref',
                              isEqualTo: currentUser.currentWorkspaceRef),
                    ),
                    builder: (context, membersSnapshot) {
                      if (!membersSnapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }

                      final members = membersSnapshot.data!;

                      // Find current user's role in this workspace
                      final currentUserMember = members.firstWhere(
                        (member) => member.userRef == currentUserReference,
                        orElse: () =>
                            WorkspaceMembersRecord.getDocumentFromData(
                                {'role': 'member'},
                                FirebaseFirestore.instance
                                    .collection('workspace_members')
                                    .doc()),
                      );
                      final currentUserRole = currentUserMember.role;

                      // Sort members by joined_at (most recent first)
                      members.sort((a, b) {
                        if (a.joinedAt == null && b.joinedAt == null) return 0;
                        if (a.joinedAt == null) return 1;
                        if (b.joinedAt == null) return -1;
                        return b.joinedAt!.compareTo(a.joinedAt!);
                      });

                      return SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Workspace Info Card
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: FlutterFlowTheme.of(context).alternate,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: workspace.hasLogoUrl() &&
                                                workspace.logoUrl.isNotEmpty
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Image.network(
                                                  workspace.logoUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Center(
                                                      child: Text(
                                                        workspace
                                                                .name.isNotEmpty
                                                            ? workspace.name[0]
                                                                .toUpperCase()
                                                            : 'W',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              )
                                            : Center(
                                                child: Text(
                                                  workspace.name.isNotEmpty
                                                      ? workspace.name[0]
                                                          .toUpperCase()
                                                      : 'W',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              workspace.name,
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              workspace.description.isNotEmpty
                                                  ? workspace.description
                                                  : 'No description',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(Icons.people,
                                                    size: 16,
                                                    color: Colors.grey[600]),
                                                SizedBox(width: 4),
                                                Text(
                                                  '${members.length} members',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 24),

                            // Management Actions
                            Text(
                              'Management Actions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: FFButtonWidget(
                                    onPressed: () {
                                      _showInviteUserDialog(context, workspace);
                                    },
                                    text: 'Invite User',
                                    icon: Icon(Icons.person_add, size: 20),
                                    options: FFButtonOptions(
                                      height: 50,
                                      color: Colors.green,
                                      textStyle: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: FFButtonWidget(
                                    onPressed: () {
                                      _showInviteCodeDialog(context, workspace);
                                    },
                                    text: 'Generate Invite Code',
                                    icon: Icon(Icons.qr_code, size: 20),
                                    options: FFButtonOptions(
                                      height: 50,
                                      color: Colors.blue,
                                      textStyle: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 24),

                            // Members List
                            Text(
                              'Workspace Members',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),

                            ...members
                                .map((member) => _buildMemberCard(
                                    member, currentUser, currentUserRole))
                                .toList(),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(WorkspaceMembersRecord member,
      UsersRecord currentUser, String currentUserRole) {
    return StreamBuilder<UsersRecord>(
      stream: UsersRecord.getDocument(member.userRef!),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return SizedBox.shrink();
        }

        final user = userSnapshot.data!;
        final isCurrentUser = user.reference == currentUserReference;
        final isOwner = member.role == 'owner';
        final isModerator = member.role == 'moderator';

        // Use the passed current user role
        final canManageUsers =
            currentUserRole == 'owner' || currentUserRole == 'moderator';

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: FlutterFlowTheme.of(context).alternate,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // User Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: user.hasPhotoUrl() && user.photoUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: Image.network(
                          user.photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                user.displayName.isNotEmpty
                                    ? user.displayName[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),

              SizedBox(width: 16),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user.displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isCurrentUser) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'You',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOwner
                                ? Colors.red
                                : isModerator
                                    ? Colors.orange
                                    : Colors.grey,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            member.role.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Joined ${_formatDate(member.joinedAt)}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions - 3 buttons for owners and moderators
              // Don't show actions for current user to prevent self-removal/downgrade
              if (!isCurrentUser && canManageUsers) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Change Role Button
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: IconButton(
                        onPressed: () =>
                            _showChangeRoleDialog(context, member, user),
                        icon: Icon(Icons.admin_panel_settings,
                            size: 20, color: Colors.blue),
                        tooltip: 'Change Role',
                      ),
                    ),
                    SizedBox(width: 8),

                    // Upgrade User Button (only show if not already owner)
                    if (member.role != 'owner') ...[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: IconButton(
                          onPressed: () => _showUpgradeUserDialog(
                              context, member, user, currentUserRole),
                          icon: Icon(Icons.arrow_upward,
                              size: 20, color: Colors.green),
                          tooltip: 'Upgrade User',
                        ),
                      ),
                      SizedBox(width: 8),
                    ],

                    // Remove User Button
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: IconButton(
                        onPressed: () =>
                            _showRemoveUserDialog(context, member, user),
                        icon: Icon(Icons.person_remove,
                            size: 20, color: Colors.red),
                        tooltip: 'Remove User',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showInviteUserDialog(BuildContext context, WorkspacesRecord workspace) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invite User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter the email address of the user you want to invite:'),
            SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isNotEmpty) {
                await _inviteUserByEmail(emailController.text, workspace);
                Navigator.pop(context);
              }
            },
            child: Text('Send Invite'),
          ),
        ],
      ),
    );
  }

  void _showInviteCodeDialog(BuildContext context, WorkspacesRecord workspace) {
    final inviteCode = _generateInviteCode();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invite Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share this code with users to join your workspace:'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                inviteCode,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This code expires in 7 days',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showChangeRoleDialog(
      BuildContext context, WorkspaceMembersRecord member, UsersRecord user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select new role for ${user.displayName}:'),
            SizedBox(height: 16),
            ...['owner', 'moderator', 'member']
                .map(
                  (role) => RadioListTile<String>(
                    title: Text(role.toUpperCase()),
                    subtitle: Text(_getRoleDescription(role)),
                    value: role,
                    groupValue: member.role,
                    onChanged: (value) async {
                      if (value != null) {
                        await member.reference.update({'role': value});
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Role updated successfully')),
                        );
                      }
                    },
                  ),
                )
                .toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showRemoveUserDialog(
      BuildContext context, WorkspaceMembersRecord member, UsersRecord user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove User'),
        content: Text(
            'Are you sure you want to remove ${user.displayName} from this workspace?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await member.reference.delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('User removed successfully')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _inviteUserByEmail(
      String email, WorkspacesRecord workspace) async {
    // TODO: Implement email invitation logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invitation sent to $email')),
    );
  }

  String _generateInviteCode() {
    // Generate a random invite code
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'owner':
        return 'Full control over workspace';
      case 'moderator':
        return 'Can manage users and content';
      case 'member':
        return 'Basic workspace access';
      default:
        return '';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else {
      return 'Just now';
    }
  }

  void _showUpgradeUserDialog(BuildContext context,
      WorkspaceMembersRecord member, UsersRecord user, String currentUserRole) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upgrade User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select new role for ${user.displayName}:'),
            SizedBox(height: 16),
            ...['moderator', 'owner']
                .where((role) => role != member.role)
                .where((role) => role == 'owner'
                    ? currentUserRole == 'owner'
                    : true) // Only owners can promote to owner
                .map(
                  (role) => RadioListTile<String>(
                    title: Text(role.toUpperCase()),
                    subtitle: Text(_getRoleDescription(role)),
                    value: role,
                    groupValue: member.role,
                    onChanged: (value) async {
                      if (value != null) {
                        await member.reference.update({'role': value});
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('User upgraded successfully')),
                        );
                      }
                    },
                  ),
                )
                .toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
