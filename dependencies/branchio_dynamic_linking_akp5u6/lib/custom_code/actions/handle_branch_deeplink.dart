// Automatic FlutterFlow imports
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:flutter/services.dart';

StreamSubscription<Map>? _branchSubscription;

String? _lastLinkHandled;
DateTime? _lastHandledTime;

//Users have to wait 10 seconds between each link taps.
//Or kill app and try again.
const Duration _cooldown = Duration(seconds: 10);

/// Call this in your Home/Entry page `onPageLoad`.
/// It listens for incoming Branch links and triggers [onLinkOpened] with the link data.
Future handleBranchDeeplink(
  Future Function(dynamic linkData) onLinkOpened,
) async {
  // Check if platform supports Branch SDK
  if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) {
    print('[Branch] Branch SDK not supported on this platform');
    return;
  }

  // If already listening, do nothing
  if (_branchSubscription != null) return;

  try {
    _branchSubscription = FlutterBranchSdk.listSession().listen(
    (data) async {
      final clicked = data['+clicked_branch_link'] == true;
      if (!clicked) return;

      // Log the entire data payload
      print('[Branch] Received link data: $data');

      final linkId = data['~referring_link'] ?? data['deeplink_path'] ?? '';
      final now = DateTime.now();

      if (_lastLinkHandled == linkId &&
          _lastHandledTime != null &&
          now.difference(_lastHandledTime!) < _cooldown) {
        print('[Branch] Ignored duplicate link: "$linkId" (within cooldown)');
        return;
      }

      _lastLinkHandled = linkId;
      _lastHandledTime = now;

      // Pass link data to the user-defined handler
      await onLinkOpened(Map<String, dynamic>.from(data));
    },
    onError: (error) {
      if (error is PlatformException) {
        print('[Branch] PlatformException: ${error.code} - ${error.message}');
      } else {
        print('[Branch] Unknown error: $error');
      }
    },
  );
  } catch (e) {
    print('[Branch] Failed to initialize Branch deeplink listener: $e');
  }
}
