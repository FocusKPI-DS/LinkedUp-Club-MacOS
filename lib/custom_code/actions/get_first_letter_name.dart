// Automatic FlutterFlow imports
import '/backend/backend.dart';
// Imports other custom actions
// Imports custom functions
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
