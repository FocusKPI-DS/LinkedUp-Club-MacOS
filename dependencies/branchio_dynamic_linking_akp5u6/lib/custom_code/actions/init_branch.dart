// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';

/// Initialises Branch SDK.
///
/// Add this action as a final action in main.dart
Future initBranch() async {
  // Add your function code here!
  await FlutterBranchSdk.init();
}
