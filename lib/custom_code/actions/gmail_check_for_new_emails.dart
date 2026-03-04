import 'package:cloud_functions/cloud_functions.dart';

Future<Map<String, dynamic>?> gmailCheckForNewEmails() async {
  try {
    final callable =
        FirebaseFunctions.instance.httpsCallable('gmailCheckForNewEmails');
    final result = await callable.call();
    return result.data as Map<String, dynamic>?;
  } catch (e) {
    print('Error checking for new emails: $e');
    return null;
  }
}


