// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cloud_firestore/cloud_firestore.dart';
import 'handle_referral_deeplink.dart' as referral_deeplink;

/// Handle referral connection on user signup
/// This function:
/// 1. Checks for stored referral UID
/// 2. Gets the referrer user document
/// 3. Auto-connects the new user and referrer
/// 4. Saves referrer_ref to the new user's document
/// 5. Clears the stored referral UID
/// 
/// Returns the referrer's display name if connection was successful, null otherwise
Future<String?> handleReferralConnection(String newUserUid) async {
  try {
    // Get stored referral UID
    final referrerUid = await referral_deeplink.getStoredReferralUid();
    
    if (referrerUid == null || referrerUid.isEmpty) {
      print('[Referral Connection] No stored referral UID found');
      return null;
    }
    
    // Don't connect if user is referring themselves
    if (referrerUid == newUserUid) {
      print('[Referral Connection] User cannot refer themselves');
      await referral_deeplink.clearStoredReferralUid();
      return null;
    }
    
    // Get referrer user document
    final referrerRef = FirebaseFirestore.instance.collection('users').doc(referrerUid);
    final referrerDoc = await referrerRef.get();
    
    if (!referrerDoc.exists) {
      print('[Referral Connection] Referrer user not found: $referrerUid');
      await referral_deeplink.clearStoredReferralUid();
      return null;
    }
    
    final referrerData = referrerDoc.data();
    final referrerDisplayName = referrerData?['display_name'] as String? ?? 'Unknown';
    
    // Get new user reference
    final newUserRef = FirebaseFirestore.instance.collection('users').doc(newUserUid);
    final newUserDoc = await newUserRef.get();
    
    if (!newUserDoc.exists) {
      print('[Referral Connection] New user document not found: $newUserUid');
      await referral_deeplink.clearStoredReferralUid();
      return null;
    }
    
    final newUserData = newUserDoc.data();
    final currentFriends = List<DocumentReference>.from(newUserData?['friends'] ?? []);
    final currentSentRequests = List<DocumentReference>.from(newUserData?['sent_requests'] ?? []);
    final currentFriendRequests = List<DocumentReference>.from(newUserData?['friend_requests'] ?? []);
    
    // Check if already connected
    if (currentFriends.contains(referrerRef)) {
      print('[Referral Connection] Users already connected');
      await referral_deeplink.clearStoredReferralUid();
      return referrerDisplayName;
    }
    
    // Get referrer's current friends/sent_requests/friend_requests
    final referrerFriends = List<DocumentReference>.from(referrerData?['friends'] ?? []);
    final referrerSentRequests = List<DocumentReference>.from(referrerData?['sent_requests'] ?? []);
    final referrerFriendRequests = List<DocumentReference>.from(referrerData?['friend_requests'] ?? []);
    
    // Use batch write for atomic updates
    final batch = FirebaseFirestore.instance.batch();
    
    // Add each other to friends list (auto-connect)
    if (!referrerFriends.contains(newUserRef)) {
      referrerFriends.add(newUserRef);
    }
    if (!currentFriends.contains(referrerRef)) {
      currentFriends.add(referrerRef);
    }
    
    // Remove from sent_requests and friend_requests if present
    if (referrerSentRequests.contains(newUserRef)) {
      referrerSentRequests.remove(newUserRef);
    }
    if (referrerFriendRequests.contains(newUserRef)) {
      referrerFriendRequests.remove(newUserRef);
    }
    if (currentSentRequests.contains(referrerRef)) {
      currentSentRequests.remove(referrerRef);
    }
    if (currentFriendRequests.contains(referrerRef)) {
      currentFriendRequests.remove(referrerRef);
    }
    
    // Update both user documents atomically
    batch.update(referrerRef, {
      'friends': referrerFriends,
      'sent_requests': referrerSentRequests,
      'friend_requests': referrerFriendRequests,
    });
    
    batch.update(newUserRef, {
      'friends': currentFriends,
      'sent_requests': currentSentRequests,
      'friend_requests': currentFriendRequests,
      'referrer_ref': referrerRef, // Save referrer reference
    });
    
    await batch.commit();
    
    // Clear stored referral UID
    await referral_deeplink.clearStoredReferralUid();
    
    print('[Referral Connection] ✅ Successfully connected $newUserUid with referrer $referrerUid');
    return referrerDisplayName;
  } catch (e) {
    print('[Referral Connection] ❌ Error: $e');
    // Clear stored referral UID on error
    await referral_deeplink.clearStoredReferralUid();
    return null;
  }
}






