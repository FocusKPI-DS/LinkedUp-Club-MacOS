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

import 'package:cloud_firestore/cloud_firestore.dart';

Future<List<dynamic>> fetchAllNotifications(
    DocumentReference thisUserRef) async {
  // Add your function code here!
  try {
    // Query the ff_user_push_notifications collection
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('ff_user_push_notifications')
        .where('user_refs', isEqualTo: thisUserRef)
        .orderBy('timestamp', descending: true) // Most recent first
        .get();

    // Convert the documents to a list of JSON objects
    List<dynamic> notifications = querySnapshot.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      // Add the document ID to the data
      data['document_id'] = doc.id;

      // Convert timestamp to a string if it exists
      if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
        data['timestamp'] =
            (data['timestamp'] as Timestamp).toDate().toIso8601String();
      }

      // Convert user_refs to string if it's a DocumentReference
      if (data['user_refs'] != null && data['user_refs'] is DocumentReference) {
        data['user_refs'] = (data['user_refs'] as DocumentReference).path;
      }

      // Convert sender to string if it's a DocumentReference
      if (data['sender'] != null && data['sender'] is DocumentReference) {
        data['sender'] = (data['sender'] as DocumentReference).path;
      }

      return data;
    }).toList();

    return notifications;
  } catch (e) {
    print('Error fetching notifications: $e');
    return [];
  }
}
