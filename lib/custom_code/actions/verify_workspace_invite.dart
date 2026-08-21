// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
import 'package:cloud_functions/cloud_functions.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

/// Verifies a workspace invitation token and processes the invitation
///
/// This function:
/// 1. Calls a Cloud Function to verify the invitation token
/// 2. Cloud Function checks if token is valid, not expired, and not used
/// 3. Cloud Function adds user to workspace if valid
/// 4. Returns workspace information or error message
///
/// Parameters:
/// - token: The invitation token from the dynamic link
///
/// Returns: Map with success status, workspace info, and message
Future<Map<String, dynamic>> verifyWorkspaceInvite(String token) async {
  try {
    if (token.isEmpty) {
      return {
        'success': false,
        'message': 'Invalid invitation token',
      };
    }

    // Call Cloud Function to verify invitation
    final callable =
        FirebaseFunctions.instance.httpsCallable('verifyWorkspaceInvite');

    final result = await callable.call({
      'token': token,
    });

    final data = result.data as Map<String, dynamic>?;

    if (data != null && data['success'] == true) {
      print('[Workspace Invite] ✅ Verified and processed invitation');
      return {
        'success': true,
        'workspaceId': data['workspaceId'] as String?,
        'workspaceName': data['workspaceName'] as String?,
        'alreadyMember': data['alreadyMember'] as bool? ?? false,
        'message':
            data['message'] as String? ?? 'Successfully joined workspace',
      };
    } else {
      final errorMessage =
          data?['message'] as String? ?? 'Failed to verify invitation';
      print('[Workspace Invite] ❌ Verification failed: $errorMessage');
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  } catch (e, stackTrace) {
    print('[Workspace Invite] ❌ Error verifying invitation: $e');
    print('[Workspace Invite] Stack trace: $stackTrace');

    // Try to extract error message from Firebase Functions error
    String errorMessage = 'Failed to verify invitation';
    if (e is FirebaseFunctionsException) {
      errorMessage = e.message ?? errorMessage;
    }

    return {
      'success': false,
      'message': errorMessage,
    };
  }
}
