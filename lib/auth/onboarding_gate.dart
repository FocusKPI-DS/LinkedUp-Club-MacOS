import 'dart:async';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';
import '/backend/firestore/windows_firestore_rest.dart';

/// Returns true when onboarding was completed or the user already saved profile info.
bool isOnboardingComplete(UsersRecord? user) {
  if (user == null) return false;
  if (user.isOnboarding) return true;
  return _hasFilledProfileDetails(user);
}

bool isOnboardingCompleteRaw(Map<String, dynamic>? raw) {
  if (raw == null) return false;
  final cover = (raw['cover_photo_url'] as String?)?.trim() ?? '';
  if (cover.isNotEmpty) return true;
  return false;
}

bool _hasFilledProfileDetails(UsersRecord user) {
  if (user.bio.trim().isNotEmpty) return true;
  if (user.location.trim().isNotEmpty) return true;
  if (user.interests.isNotEmpty) return true;
  if (user.phoneNumber.trim().isNotEmpty) return true;
  if (user.workspaces.isNotEmpty) return true;
  if (user.defaultWorkspaceRef != null) return true;
  if (user.friends.isNotEmpty) return true;
  if (_hasUploadedProfilePhoto(user)) return true;
  return false;
}

bool _hasUploadedProfilePhoto(UsersRecord user) {
  final url = user.photoUrl.trim();
  if (url.isEmpty) return false;
  return url.contains('firebasestorage.googleapis.com') ||
      url.contains('/uploads/');
}

/// Loads the signed-in user's Firestore doc (REST on Windows/Linux).
Future<UsersRecord?> ensureCurrentUserDocument() async {
  if (currentUserDocument != null) return currentUserDocument;
  if (currentUserUid.isEmpty) return null;

  final ref = UsersRecord.collection.doc(currentUserUid);
  try {
    final user = await fsGetUserOnce(ref);
    currentUserDocument = user;
    return user;
  } catch (_) {
    return null;
  }
}

Future<Map<String, dynamic>?> _fetchCurrentUserRawData() async {
  if (currentUserUid.isEmpty) return null;
  final ref = UsersRecord.collection.doc(currentUserUid);
  if (useWindowsFirestoreRest) {
    return WindowsFirestoreRest.fetchDocumentData(ref);
  }
  final snap = await ref.get();
  return snap.data() as Map<String, dynamic>?;
}

/// Waits for the user doc to load before deciding whether onboarding is needed.
Future<bool> resolveOnboardingComplete() async {
  final user = await ensureCurrentUserDocument();
  if (isOnboardingComplete(user)) return true;

  final raw = await _fetchCurrentUserRawData();
  return isOnboardingCompleteRaw(raw);
}

/// Persists [is_onboarding] when profile data exists but the flag was never set.
Future<void> markOnboardingCompleteIfFilledProfile() async {
  final user = await ensureCurrentUserDocument();
  if (user == null || user.isOnboarding) return;

  final raw = await _fetchCurrentUserRawData();
  if (!_hasFilledProfileDetails(user) && !isOnboardingCompleteRaw(raw)) {
    return;
  }

  final ref = currentUserReference;
  if (ref == null) return;

  await fsPatchDocument(ref, createUsersRecordData(isOnboarding: true));
  currentUserDocument = await fsGetUserOnce(ref);
}
