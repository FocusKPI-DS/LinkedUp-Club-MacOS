// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
// Begin custom action code

import 'package:cloud_firestore/cloud_firestore.dart';

/// Public/free email domains that should NOT trigger auto-connect.
/// Users with these domains are treated as personal accounts, not company accounts.
const Set<String> _publicEmailDomains = {
  // Google
  'gmail.com',
  'googlemail.com',
  // Microsoft
  'outlook.com',
  'hotmail.com',
  'live.com',
  'msn.com',
  // Yahoo
  'yahoo.com',
  'yahoo.co.uk',
  'yahoo.co.jp',
  'ymail.com',
  'rocketmail.com',
  // Apple
  'icloud.com',
  'me.com',
  'mac.com',
  // Chinese providers
  'qq.com',
  '163.com',
  '126.com',
  'sina.com',
  'foxmail.com',
  'aliyun.com',
  // Other popular providers
  'aol.com',
  'protonmail.com',
  'proton.me',
  'zoho.com',
  'mail.com',
  'yandex.com',
  'yandex.ru',
  'gmx.com',
  'gmx.net',
  'tutanota.com',
  'fastmail.com',
  // Education (generic)
  'edu.com',
};

/// Extracts the domain from an email address.
/// Returns null if the email is invalid.
String? getEmailDomain(String email) {
  final atIndex = email.lastIndexOf('@');
  if (atIndex < 0 || atIndex == email.length - 1) return null;
  return email.substring(atIndex + 1).toLowerCase().trim();
}

/// Returns true if the email domain is a company/organization domain
/// (i.e. NOT a public/free email provider).
bool isCompanyEmail(String email) {
  final domain = getEmailDomain(email);
  if (domain == null || domain.isEmpty) return false;
  return !_publicEmailDomains.contains(domain);
}

/// Auto-connects users who share the same company email domain.
///
/// Called once during user registration. For each user with the same
/// company email domain who is not already a friend, both users are
/// mutually added to each other's `friends` list.
///
/// Public email domains (gmail, outlook, etc.) are excluded.
///
/// Returns the number of new connections made.
Future<int> autoConnectSameCompanyUsers(String currentUserUid) async {
  try {
    final currentUserRef =
        FirebaseFirestore.instance.collection('users').doc(currentUserUid);
    final currentUserDoc = await currentUserRef.get();

    if (!currentUserDoc.exists) {
      print('[AutoConnect] ❌ Current user doc not found: $currentUserUid');
      return 0;
    }

    final currentEmail =
        (currentUserDoc.data()?['email'] as String?)?.toLowerCase().trim();
    if (currentEmail == null || currentEmail.isEmpty) {
      print('[AutoConnect] ❌ Current user has no email');
      return 0;
    }

    final domain = getEmailDomain(currentEmail);
    if (domain == null || domain.isEmpty) {
      print('[AutoConnect] ❌ Could not extract domain from: $currentEmail');
      return 0;
    }

    // Skip public email domains
    if (_publicEmailDomains.contains(domain)) {
      print('[AutoConnect] ⏭️ Public email domain "$domain", skipping');
      return 0;
    }

    print('[AutoConnect] 🔍 Looking for users with domain: $domain');

    // Query all users — we filter by domain client-side because
    // Firestore doesn't support endsWith queries.
    // For large user bases, consider adding an `email_domain` indexed field.
    final allUsersQuery = await FirebaseFirestore.instance
        .collection('users')
        .get();

    final currentFriends = List<dynamic>.from(
        currentUserDoc.data()?['friends'] ?? []);

    final batch = FirebaseFirestore.instance.batch();
    int connectionsAdded = 0;

    for (final userDoc in allUsersQuery.docs) {
      // Skip self
      if (userDoc.id == currentUserUid) continue;

      final userEmail =
          (userDoc.data()['email'] as String?)?.toLowerCase().trim();
      if (userEmail == null || userEmail.isEmpty) continue;

      final userDomain = getEmailDomain(userEmail);
      if (userDomain != domain) continue;

      final userRef = userDoc.reference;

      // Skip if already friends
      if (currentFriends.any((ref) =>
          ref is DocumentReference && ref.id == userRef.id)) {
        continue;
      }

      // Add mutual friendship
      batch.update(currentUserRef, {
        'friends': FieldValue.arrayUnion([userRef]),
        // Clean up any pending requests between them
        'sent_requests': FieldValue.arrayRemove([userRef]),
        'friend_requests': FieldValue.arrayRemove([userRef]),
      });

      batch.update(userRef, {
        'friends': FieldValue.arrayUnion([currentUserRef]),
        'sent_requests': FieldValue.arrayRemove([currentUserRef]),
        'friend_requests': FieldValue.arrayRemove([currentUserRef]),
      });

      connectionsAdded++;
      print(
          '[AutoConnect] ✅ Auto-connecting with ${userDoc.data()['display_name'] ?? userEmail}');
    }

    if (connectionsAdded > 0) {
      await batch.commit();
      print(
          '[AutoConnect] 🎉 Auto-connected $connectionsAdded users with domain "$domain"');
    } else {
      print('[AutoConnect] ℹ️ No new connections needed for domain "$domain"');
    }

    return connectionsAdded;
  } catch (e) {
    print('[AutoConnect] ❌ Error: $e');
    return 0;
  }
}
