import '/auth/base_auth_user_provider.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/auth/onboarding_gate.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

Future checkOnboarding(BuildContext context) async {
  if (await resolveOnboardingComplete()) {
    unawaited(markOnboardingCompleteIfFilledProfile());
    if (context.mounted) {
      context.go('/');
    }
  } else if (context.mounted) {
    context.pushNamed(OnboardingProfileWidget.routeName);
  }
}

Future homeCheck(BuildContext context) async {
  if (loggedIn != true) {
    if (context.mounted) {
      context.pushNamed(SignUpWidget.routeName);
    }
    return;
  }

  if (!await resolveOnboardingComplete()) {
    if (context.mounted) {
      context.pushNamed(OnboardingProfileWidget.routeName);
    }
    return;
  }

  unawaited(markOnboardingCompleteIfFilledProfile());
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
