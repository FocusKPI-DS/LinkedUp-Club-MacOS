// Run with: dart run send_announcement.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final firestore = FirebaseFirestore.instance;

  final content = '''**Lona v1.9.36 -- Connections & Auto-Approve Update (macOS & iOS)**

This update introduces colleague discovery, connection management improvements, and auto-approve functionality across both macOS and iOS.

**What's New:**

1. **Same-Company Colleague Suggestions** -- When signed in with a company email, Lona now identifies other users from the same email domain and presents them as suggested connections in a dedicated banner on the Connections page. The banner supports pagination for browsing through multiple suggestions, with a "Connect All" option to send requests in bulk.

2. **Auto-Approve Connection Requests** -- A new set of preferences in Settings > Connections allows you to streamline the connection approval process:
   - Accept all incoming requests automatically
   - Accept requests from users with the same company email domain
   - Define custom email domains whose requests should be auto-approved
   These settings are available on both macOS and iOS (Settings > Connections).

3. **Connect All with Settings Prompt** -- After using "Connect All" to send bulk requests, users who have not yet enabled auto-approve will see a prompt offering to navigate directly to the relevant settings page.

4. **Connections UI Improvements** -- Card layouts have been refined with compact sizing optimized for each platform. The search functionality now correctly filters results without layout gaps. On iOS, cards are sized at 100px height for a denser, mobile-friendly view.

5. **Public Email Domain Handling** -- Users signed in with public email providers (Gmail, Outlook, Yahoo, etc.) will see an informational banner explaining that colleague suggestions require a company email, rather than the section being silently hidden.

**Platforms:** macOS, iOS
**Build:** 1.9.36 (70)''';

  // Send to lona-service-chat
  final chatRef = firestore.collection('chats').doc('lona-service-chat');
  final messagesRef = chatRef.collection('messages');

  // Use a service account/bot user reference
  final senderRef = firestore.collection('users').doc('lona-service-bot');

  await messagesRef.add({
    'content': content,
    'sender_ref': senderRef,
    'created_at': FieldValue.serverTimestamp(),
    'message_type': 'text',
    'is_read_by': [],
  });

  // Update chat's last_message fields
  await chatRef.update({
    'last_message': content.substring(0, 100),
    'last_message_sent_by': senderRef,
    'last_message_time': FieldValue.serverTimestamp(),
    'last_message_type': 'text',
  });

  print('Announcement sent successfully!');
}
