// Automatic FlutterFlow imports
import '/backend/backend.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

Future<ChatsRecord?> getChatDocFromId(String? chatId) async {
  // Add your function code here!
  if (chatId == null || chatId.isEmpty) {
    return null;
  }

  try {
    String docId;
    if (chatId.contains('/')) {
      docId = chatId.split('/').last;
    } else {
      docId = chatId;
    }

    final docRef = ChatsRecord.collection.doc(docId);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      return null;
    }

    return ChatsRecord.fromSnapshot(docSnapshot);
  } catch (e) {
    print('Error getting chat document: $e');
    return null;
  }
}
