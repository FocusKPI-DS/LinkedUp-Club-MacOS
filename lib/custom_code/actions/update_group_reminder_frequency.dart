// Automatic FlutterFlow imports
import '/backend/backend.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!

import 'package:cloud_firestore/cloud_firestore.dart';

Future<bool> updateGroupReminderFrequency(
  DocumentReference chatRef,
  int reminderFrequency,
) async {
  try {
    // Validate reminder frequency (should be between 1 and 5)
    if (reminderFrequency < 1 || reminderFrequency > 5) {
      print(
          'Invalid reminder frequency: $reminderFrequency. Must be between 1 and 5.');
      return false;
    }

    // Update the chat document with the new reminder frequency
    await chatRef.update({
      'reminder_frequency': reminderFrequency,
      'reminder_updated_at': FieldValue.serverTimestamp(),
    });

    print(
        'Successfully updated reminder frequency to $reminderFrequency times per day');
    return true;
  } catch (e) {
    print('Error updating reminder frequency: $e');
    return false;
  }
}
