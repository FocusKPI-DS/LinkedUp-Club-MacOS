import '/auth/base_auth_user_provider.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';

Future<bool> checkOnboarding(BuildContext context) async {
  // Fetch user document directly from Firestore to avoid race condition
  // where currentUserDocument may not be loaded yet from the auth stream.
  UsersRecord? userDoc = currentUserDocument;
  if (userDoc == null && currentUser != null) {
    try {
      userDoc = await UsersRecord.getDocumentOnce(
        UsersRecord.collection.doc(currentUser!.uid),
      );
      // Update the cached document so other parts of the app can use it
      currentUserDocument = userDoc;
    } catch (e) {
      debugPrint('checkOnboarding: Failed to fetch user document: $e');
    }
  }

  final hasCompletedOnboarding =
      valueOrDefault<bool>(userDoc?.isOnboarding, false);

  if (hasCompletedOnboarding == false) {
    context.pushNamed(OnboardingProfileWidget.routeName);
    return true; // onboarding was shown
  } else {
    context.go('/');
    return false; // no onboarding needed
  }
}

Future homeCheck(BuildContext context) async {
  if (loggedIn == true) {
    // Fetch user document directly to avoid race condition
    UsersRecord? userDoc = currentUserDocument;
    if (userDoc == null && currentUser != null) {
      try {
        userDoc = await UsersRecord.getDocumentOnce(
          UsersRecord.collection.doc(currentUser!.uid),
        );
        currentUserDocument = userDoc;
      } catch (e) {
        debugPrint('homeCheck: Failed to fetch user document: $e');
      }
    }

    final hasCompletedOnboarding =
        valueOrDefault<bool>(userDoc?.isOnboarding, false);

    if (hasCompletedOnboarding == false) {
      context.pushNamed(OnboardingProfileWidget.routeName);
    }
  } else {
    context.pushNamed(SignUpWidget.routeName);
  }
}


Future<bool?> checkBlock(
  BuildContext context, {
  DocumentReference? userRef,
  List<DocumentReference>? blockedUser,
}) async {
  if (blockedUser?.contains(userRef) == true) {
    return true;
  }

  return false;
}
