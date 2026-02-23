// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cloud_functions/cloud_functions.dart';
import '/auth/firebase_auth/auth_util.dart';

Future callAIAgent(
  String chatRefPath,
  String messageContent,
) async {
  // Add your function code here!
  try {
    // Get current user's display name
    final senderName = currentUserDisplayName ?? 'User';

    // Get the cloud function reference
    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'processAIMention',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 300),
      ),
    );

    // Call the cloud function
    final result = await callable.call({
      'chatRef': 'chats/$chatRefPath',
      'messageContent': messageContent,
      'senderName': senderName,
    });

    // Check if the function executed successfully
    if (result.data != null && result.data['success'] == true) {
      print('AI response sent successfully');
      return true;
    } else {
      print('AI function returned false or null');
      return false;
    }
  } catch (e) {
    print('Error calling AI function: $e');

    // Handle specific Firebase Functions errors
    if (e is FirebaseFunctionsException) {
      print('Firebase Functions Error:');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('Details: ${e.details}');
    }

    return false;
  }
}
