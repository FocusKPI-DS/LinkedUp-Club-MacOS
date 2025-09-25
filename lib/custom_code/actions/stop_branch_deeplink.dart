// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';

// Make sure this matches the original listener variable
StreamSubscription<Map>? _branchSubscription;

Future stopBranchDeeplink() async {
  // Cancel the existing Branch listener if it's active
  if (_branchSubscription != null) {
    print('[Branch] Cancelling Branch deep link listener...');
    await _branchSubscription!.cancel();
    _branchSubscription = null;
  } else {
    print('[Branch] No active deep link listener to cancel.');
  }
}
