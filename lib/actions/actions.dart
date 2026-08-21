import '/auth/base_auth_user_provider.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/auth/onboarding_gate.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'dart:async';
import 'package:flutter/material.dart';

/// Returns true when onboarding was shown, false when user can go home.
Future<bool> checkOnboarding(BuildContext context) async {
  if (await resolveOnboardingComplete()) {
    unawaited(markOnboardingCompleteIfFilledProfile());
    if (context.mounted) {
      context.go('/');
    }
    return false;
  }
  if (context.mounted) {
    context.pushNamed(OnboardingProfileWidget.routeName);
  }
  return true;
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
