// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!

Future navigateBackAndRefresh(BuildContext context) async {
  // Navigate back
  context.pop();

  // Force a slight delay to ensure navigation completes
  await Future.delayed(const Duration(milliseconds: 100));

  // Force rebuild of the previous page
  if (context.mounted) {
    (context as Element).markNeedsBuild();
  }
}
