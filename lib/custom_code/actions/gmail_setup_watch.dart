import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Set up Gmail Watch API for real-time push notifications
/// This enables Gmail to send push notifications when new emails arrive
/// Watch expires after 7 days and needs renewal
Future<Map<String, dynamic>?> gmailSetupWatch() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ User not authenticated');
      return {'success': false, 'error': 'User not authenticated'};
    }

    print('🔵 Setting up Gmail Watch API...');
    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'gmailSetupWatch',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final result = await callable.call();
    final data = result.data as Map<String, dynamic>?;
    if (data != null && data['success'] == true) {
      print('✅ Gmail Watch API set up successfully');
      print('   Expires at: ${data['expiresAt']}');
    } else {
      print(
          '❌ Error setting up Gmail Watch: ${data?['error'] ?? 'Unknown error'}');
    }
    return data;
  } catch (e) {
    print('❌ Error setting up Gmail Watch: $e');
    return {'success': false, 'error': e.toString()};
  }
}
