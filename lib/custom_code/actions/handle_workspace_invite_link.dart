// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/auth/firebase_auth/auth_util.dart';
// Imports other custom actions
import '/custom_code/actions/index.dart' as actions;
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';

/// Handles workspace invitation dynamic links
///
/// This function:
/// 1. Parses the dynamic link URL to extract the invitation token
/// 2. Calls the Cloud Function to verify and process the invitation
/// 3. Returns workspace information if successful
///
/// Parameters:
/// - linkUrl: The Firebase Dynamic Link URL
///
/// Returns: Map with success status and workspace info
Future<Map<String, dynamic>> handleWorkspaceInviteLink(String? linkUrl) async {
  if (linkUrl == null || linkUrl.isEmpty) {
    print('[Workspace Invite] ❌ No link URL provided.');
    return {
      'success': false,
      'message': 'No invitation link provided',
    };
  }

  try {
    print('[Workspace Invite] 🔗 Processing link: $linkUrl');

    // Parse the URL to extract the token
    final uri = Uri.parse(linkUrl);

    // Extract token from query parameters
    // Format: https://lona.page.link/invite?token=abc123
    // or: https://lona.club/workspace-invite?token=abc123
    String? token;

    // Check query parameters first
    token = uri.queryParameters['token'];

    // If no token in query params, check path segments
    if (token == null || token.isEmpty) {
      // Try to extract from path: /workspace-invite?token=abc123
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        // Check if last segment might be the token
        final lastSegment = pathSegments.last;
        if (lastSegment.length > 20) {
          // UUID-like tokens are typically long
          token = lastSegment;
        }
      }
    }

    // If still no token, try to extract from fragment
    if ((token == null || token.isEmpty) && uri.hasFragment) {
      final fragment = uri.fragment;
      final fragmentUri = Uri.parse('?$fragment');
      token = fragmentUri.queryParameters['token'];
    }

    if (token == null || token.isEmpty) {
      print('[Workspace Invite] ❌ No token found in link: $linkUrl');
      return {
        'success': false,
        'message': 'Invalid invitation link format',
      };
    }

    print('[Workspace Invite] ✅ Extracted token: $token');

    // Verify and process the invitation
    final result = await actions.verifyWorkspaceInvite(token);

    if (result['success'] == true) {
      print('[Workspace Invite] ✅ Successfully processed invitation');

      // Update user's current workspace if they joined
      if (!(result['alreadyMember'] as bool? ?? false)) {
        final workspaceId = result['workspaceId'] as String?;
        if (workspaceId != null) {
          final workspaceRef = FirebaseFirestore.instance
              .collection('workspaces')
              .doc(workspaceId);

          // Update user's current workspace
          final userRef = currentUserReference;
          if (userRef != null) {
            await userRef.update({
              'current_workspace_ref': workspaceRef,
            });
            print('[Workspace Invite] ✅ Updated user\'s current workspace');
          }
        }
      }
    }

    return result;
  } catch (e, stack) {
    print('[Workspace Invite] ❌ Error processing link: $e\n$stack');
    return {
      'success': false,
      'message': 'Error processing invitation: $e',
    };
  }
}
