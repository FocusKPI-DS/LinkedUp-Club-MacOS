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

Future<DeeplinkInfoStruct> checkEventInvite(dynamic linkData) async {
  try {
    if (linkData == null || linkData is! Map) {
      print('🔴 linkData is null or not a Map');
      return DeeplinkInfoStruct();
    }

    final data = Map<String, dynamic>.from(linkData);

    // Extract with fallback keys (with or without $)
    final String? userRef =
        data['user_ref'] is String ? data['user_ref'] : null;

    final String? inviteCode =
        data.containsKey('\$inviteCode') && data['\$inviteCode'] is String
            ? data['\$inviteCode']
            : (data['inviteCode'] is String ? data['inviteCode'] : null);

    final String? eventId =
        data.containsKey('\$eventId') && data['\$eventId'] is String
            ? data['\$eventId']
            : (data['eventId'] is String ? data['eventId'] : null);

    final String? inviteType =
        data.containsKey('\$invite_type') && data['\$invite_type'] is String
            ? data['\$invite_type']
            : (data['~invite_type'] is String ? data['~invite_type'] : null);

    // Debug
    print('✅ userRef: $userRef');
    print('✅ inviteCode: $inviteCode');
    print('✅ eventId: $eventId');
    print('✅ inviteType: $inviteType');

    return DeeplinkInfoStruct(
      userInvite: userRef,
      invitationCode: inviteCode,
      eventId: eventId,
      inviteType: inviteType,
    );
  } catch (e) {
    print('🔥 Exception in checkEventInvite: $e');
    return DeeplinkInfoStruct();
  }
}
