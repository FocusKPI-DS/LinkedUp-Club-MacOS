// Automatic FlutterFlow imports
import '/backend/backend.dart';
// Imports other custom actions
// Imports custom functions
import 'package:cloud_functions/cloud_functions.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

/// Generates a Firebase Dynamic Link for workspace invitations
///
/// This function:
/// 1. Calls a Cloud Function to generate a unique invitation token
/// 2. Cloud Function stores the token in Firestore with expiry (7 days)
/// 3. Cloud Function generates a Firebase Dynamic Link
/// 4. Returns the dynamic link URL
///
/// Parameters:
/// - workspaceRef: The workspace reference to invite users to
/// - workspaceName: The name of the workspace
/// - inviterUserId: The user ID of the person sending the invitation
/// - inviterName: The name of the person sending the invitation (optional)
///
/// Returns: The generated Firebase Dynamic Link URL or null if generation fails
Future<String?> generateWorkspaceInviteLinkV2(
  DocumentReference workspaceRef,
  String workspaceName,
  String? inviterUserId,
  String? inviterName,
) async {
  try {
    if (inviterUserId == null || inviterUserId.isEmpty) {
      print('[Workspace Invite] ❌ Invalid inviter user ID');
      return null;
    }

    // Call Cloud Function to generate invitation
    final callable =
        FirebaseFunctions.instance.httpsCallable('generateWorkspaceInvite');

    final result = await callable.call({
      'workspaceId': workspaceRef.id,
      'workspaceName': workspaceName,
      'inviterUserId': inviterUserId,
      'inviterName': inviterName ?? '',
    });

    final data = result.data as Map<String, dynamic>?;

    if (data != null &&
        data['success'] == true &&
        data['dynamicLink'] != null) {
      final dynamicLink = data['dynamicLink'] as String;
      print('[Workspace Invite] ✅ Generated dynamic link: $dynamicLink');
      return dynamicLink;
    } else {
      print(
          '[Workspace Invite] ❌ Failed to generate link: ${data?['message'] ?? 'Unknown error'}');
      return null;
    }
  } catch (e, stackTrace) {
    print('[Workspace Invite] ❌ Error generating link: $e');
    print('[Workspace Invite] Stack trace: $stackTrace');
    return null;
  }
}


