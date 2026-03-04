// Automatic FlutterFlow imports
import '/backend/backend.dart';
// Imports other custom actions
// Imports custom functions
import 'package:branchio_dynamic_linking_akp5u6/flutter_flow/custom_functions.dart'
    as branchio_functions;
import 'package:branchio_dynamic_linking_akp5u6/custom_code/actions/index.dart'
    as branchio_actions;
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

/// Generates a Branch.io deeplink for workspace invitations
///
/// Parameters:
/// - workspaceRef: The workspace reference to invite users to
/// - workspaceName: The name of the workspace
/// - inviterUserId: The user ID of the person sending the invitation
///
/// Returns: The generated Branch.io deeplink URL or null if generation fails
Future<String?> generateWorkspaceInviteLink(
  DocumentReference workspaceRef,
  String workspaceName,
  String? inviterUserId,
) async {
  try {
    // Generate a unique canonical identifier for this workspace invitation
    final canonicalIdentifier = 'workspaceInvite_${workspaceRef.path}';

    // Create metadata for the invitation
    final metadata = <String, String?>{
      'workspace_ref': workspaceRef.path,
      'workspace_id': workspaceRef.id,
      'workspace_name': workspaceName,
      'user_ref': inviterUserId,
      'invite_type': 'Workspace',
    };

    // Create link properties with custom parameters
    final linkProperties = branchio_functions.createLinkProperties(
      'in_app', // channel
      'invite', // feature
      'workspace_invitation', // campaign
      'workspace_join', // stage
      ['deeplink', 'workspace'].toList(), // tags
      null, // alias
      172800000, // matchDuration: 2 days in milliseconds
      <String, String?>{
        'workspaceId': workspaceRef.id,
        'workspaceRef': workspaceRef.path,
        'deeplink_path': 'workspaceInvite/${workspaceRef.id}',
        'invite_type': 'Workspace',
      },
    );

    // Generate the Branch.io link
    final link = await branchio_actions.generateLink(
      canonicalIdentifier,
      'Join $workspaceName on LinkedUp',
      'You\'ve been invited to join $workspaceName workspace on LinkedUp!',
      metadata,
      linkProperties,
    );

    if (link != null) {
      print('[Workspace Invite] ✅ Generated link: $link');
    } else {
      print('[Workspace Invite] ❌ Failed to generate link');
    }

    return link;
  } catch (e) {
    print('[Workspace Invite] ❌ Error generating link: $e');
    return null;
  }
}
