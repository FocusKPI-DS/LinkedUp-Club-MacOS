// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';

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
