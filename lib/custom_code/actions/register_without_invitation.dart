// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!

import 'package:cloud_firestore/cloud_firestore.dart';
import '/auth/firebase_auth/auth_util.dart';

Future<bool> registerWithoutInvitation(BuildContext context) async {
  try {
    // Check if user exists and is authenticated
    if (currentUserReference == null) {
      return false;
    }

    // Update user document to indicate they registered without invitation
    await currentUserReference!.update({
      'has_invitation_code': false,
      'registration_type': 'skip_invitation',
      'registration_date': FieldValue.serverTimestamp(),
      'account_status': 'active', // Full access even without invitation
    });

    // Create a notification for admin about new user without invitation
    await FirebaseFirestore.instance.collection('admin_notifications').add({
      'type': 'user_registration_no_invite',
      'user_ref': currentUserReference,
      'user_name': currentUserDisplayName,
      'user_email': currentUserEmail,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending_review',
      'message':
          'New user registered without invitation code: ${currentUserDisplayName}',
    });

    // Note: App state flags should be set in FlutterFlow
    // The user document has been updated with limited access status

    return true;
  } catch (e) {
    print('Error registering without invitation: $e');
    return false;
  }
}

Future<bool> upgradeAccountWithInvitation(
  BuildContext context,
  String invitationCode,
) async {
  try {
    // Verify the invitation code
    final inviteQuery = await FirebaseFirestore.instance
        .collection('invitation_codes')
        .where('code', isEqualTo: invitationCode)
        .where('is_used', isEqualTo: false)
        .limit(1)
        .get();

    if (inviteQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid or already used invitation code'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return false;
    }

    final inviteDoc = inviteQuery.docs.first;

    // Update user account to full access
    await currentUserReference!.update({
      'has_invitation_code': true,
      'invitation_code': invitationCode,
      'invitation_code_ref': inviteDoc.reference,
      'account_status': 'active',
      'upgraded_date': FieldValue.serverTimestamp(),
      'features_access': FieldValue.delete(), // Remove limitations
    });

    // Mark invitation code as used
    await inviteDoc.reference.update({
      'is_used': true,
      'used_by': currentUserReference,
      'used_date': FieldValue.serverTimestamp(),
    });

    // Note: App state flags should be updated in FlutterFlow
    // The user document has been upgraded to full access

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Account upgraded successfully! You now have full access.'),
        backgroundColor: FlutterFlowTheme.of(context).success,
      ),
    );

    return true;
  } catch (e) {
    print('Error upgrading account: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to upgrade account. Please try again.'),
        backgroundColor: FlutterFlowTheme.of(context).error,
      ),
    );
    return false;
  }
}
