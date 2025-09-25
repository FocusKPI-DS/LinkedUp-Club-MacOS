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

Future<List<UsersRecord>> getFirstLetterName(
  String? letter,
  List<UsersRecord>? friendList,
) async {
  // Validate input
  if (letter == null || letter.isEmpty || friendList == null) return [];

  final target = letter.toUpperCase();

  // Filter users whose display_name starts with the target letter
  return friendList.where((user) {
    final name = user.displayName ?? '';
    return name.isNotEmpty && name[0].toUpperCase() == target;
  }).toList();
}
