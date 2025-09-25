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

Future<ChatsRecord?> getChatDocFromId(String? chatId) async {
  // Add your function code here!
  if (chatId == null || chatId.isEmpty) {
    return null;
  }

  try {
    String docId;
    if (chatId.contains('/')) {
      docId = chatId.split('/').last;
    } else {
      docId = chatId;
    }

    final docRef = ChatsRecord.collection.doc(docId);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      return null;
    }

    return ChatsRecord.fromSnapshot(docSnapshot);
  } catch (e) {
    print('Error getting chat document: $e');
    return null;
  }
}
