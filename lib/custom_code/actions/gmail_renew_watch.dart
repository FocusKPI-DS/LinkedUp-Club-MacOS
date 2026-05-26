import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Renew Gmail Watch API (watch expires after 7 days)
/// This should be called before the watch expires to maintain real-time notifications
Future<Map<String, dynamic>?> gmailRenewWatch() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ User not authenticated');
      return {'success': false, 'error': 'User not authenticated'};
    }

    print('🔵 Renewing Gmail Watch API...');
    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'gmailRenewWatch',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final result = await callable.call();
    final data = result.data as Map<String, dynamic>?;
    if (data != null && data['success'] == true) {
      print('✅ Gmail Watch API renewed successfully');
      if (data['expiresAt'] != null) {
        print('   New expiration: ${data['expiresAt']}');
      }
    } else {
      print(
          '❌ Error renewing Gmail Watch: ${data?['error'] ?? 'Unknown error'}');
    }
    return data;
  } catch (e) {
    print('❌ Error renewing Gmail Watch: $e');
    return {'success': false, 'error': e.toString()};
  }
}
