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

import '/auth/firebase_auth/auth_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> setupEventbriteAutoSync(bool enableAutoSync) async {
  try {
    // Update user document with auto-sync preference
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserUid)
        .update({
      'eventbrite_auto_sync': enableAutoSync,
      'eventbrite_auto_sync_updated': FieldValue.serverTimestamp(),
    });

    // If enabling auto-sync, create a scheduled task record
    if (enableAutoSync) {
      await FirebaseFirestore.instance
          .collection('scheduled_tasks')
          .doc('eventbrite_sync_$currentUserUid')
          .set({
        'type': 'eventbrite_auto_sync',
        'user_id': currentUserUid,
        'enabled': true,
        'last_run': null,
        'next_run': DateTime.now().add(const Duration(minutes: 30)),
        'created_at': FieldValue.serverTimestamp(),
      });
    } else {
      // Disable the scheduled task
      await FirebaseFirestore.instance
          .collection('scheduled_tasks')
          .doc('eventbrite_sync_$currentUserUid')
          .update({
        'enabled': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  } catch (e) {
    print('Error setting up EventBrite auto-sync: $e');
    rethrow;
  }
}
