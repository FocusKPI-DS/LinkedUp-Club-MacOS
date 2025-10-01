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

Future checkOnboarding(BuildContext context) async {
  if (valueOrDefault<bool>(currentUserDocument?.isOnboarding, false) ==
      false) {
    context.pushNamed(OnboardingProfileWidget.routeName);
  } else {
    context.pushNamed(DiscoverWidget.routeName);
  }
}

Future homeCheck(BuildContext context) async {
  if (loggedIn == true) {
    if ((valueOrDefault<bool>(currentUserDocument?.isOnboarding, false) ==
            false) ||
        (valueOrDefault<bool>(currentUserDocument?.isOnboarding, false) ==
            null)) {
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
