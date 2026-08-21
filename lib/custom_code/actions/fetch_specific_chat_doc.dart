// Automatic FlutterFlow imports
import '/backend/backend.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!


Future<ChatsRecord?> fetchSpecificChatDoc(
  DocumentReference userRefOne,
  DocumentReference userRefTwo,
) async {
  // Add your function code here!
  // Step 1: Query by one member using array-contains
  final querySnapshot = await FirebaseFirestore.instance
      .collection('chats')
      .where('members', arrayContains: userRefOne)
      .get();

  // Step 2: Filter manually to match exactly 2 members
  for (var doc in querySnapshot.docs) {
    final data = doc.data();
    final members = List<DocumentReference>.from(data['members'] ?? []);

    // Ensure both users exist and list has only two members
    final isMatch = members.length == 2 &&
        members.contains(userRefOne) &&
        members.contains(userRefTwo);

    if (isMatch) {
      return ChatsRecord.fromSnapshot(doc);
    }
  }

  // No exact match found
  return null;
}
