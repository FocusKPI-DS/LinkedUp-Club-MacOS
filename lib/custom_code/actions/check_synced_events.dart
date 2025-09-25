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

Future<List<String>> checkSyncedEvents(List<String> eventbriteEventIds) async {
  try {
    if (eventbriteEventIds.isEmpty) {
      return [];
    }

    // Query Firestore to find which events are already synced
    final querySnapshot = await FirebaseFirestore.instance
        .collection('events')
        .where('eventbrite_id', whereIn: eventbriteEventIds)
        .get();

    // Extract the EventBrite IDs of synced events
    final syncedEventIds = querySnapshot.docs
        .map((doc) => doc.data()['eventbrite_id'] as String?)
        .where((id) => id != null)
        .cast<String>()
        .toList();

    return syncedEventIds;
  } catch (e) {
    print('Error checking synced events: $e');
    return [];
  }
}
