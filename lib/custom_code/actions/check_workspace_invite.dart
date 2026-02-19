// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

Future<DeeplinkInfoStruct> checkWorkspaceInvite(dynamic linkData) async {
  try {
    if (linkData == null || linkData is! Map) {
      print('🔴 [Workspace Invite] linkData is null or not a Map');
      return DeeplinkInfoStruct();
    }

    final data = Map<String, dynamic>.from(linkData);

    // Extract workspace invitation data from Branch link
    final String? workspaceRef =
        data['workspace_ref'] is String ? data['workspace_ref'] : null;

    final String? workspaceId =
        data['workspace_id'] is String ? data['workspace_id'] : null;

    final String? workspaceName =
        data['workspace_name'] is String ? data['workspace_name'] : null;

    final String? userRef =
        data['user_ref'] is String ? data['user_ref'] : null;

    final String? inviteType =
        data.containsKey('\$invite_type') && data['\$invite_type'] is String
            ? data['\$invite_type']
            : (data['invite_type'] is String ? data['invite_type'] : null);

    // Debug
    print('✅ [Workspace Invite] workspaceRef: $workspaceRef');
    print('✅ [Workspace Invite] workspaceId: $workspaceId');
    print('✅ [Workspace Invite] workspaceName: $workspaceName');
    print('✅ [Workspace Invite] userRef: $userRef');
    print('✅ [Workspace Invite] inviteType: $inviteType');

    // Store workspace invitation data in DeeplinkInfoStruct
    // We'll use the invitationCode field to store workspaceId
    // and userInvite to store the inviter's user ID
    return DeeplinkInfoStruct(
      userInvite: userRef,
      invitationCode: workspaceId ?? workspaceRef ?? '',
      eventId: workspaceRef, // Reusing eventId field for workspace ref
      inviteType: inviteType ?? 'Workspace',
    );
  } catch (e) {
    print('🔥 [Workspace Invite] Exception in checkWorkspaceInvite: $e');
    return DeeplinkInfoStruct();
  }
}


