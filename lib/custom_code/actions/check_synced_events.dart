// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
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
