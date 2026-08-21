const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const path = require('path');

const serviceAccount = require(path.join(__dirname, 'firebase', 'functions', 'serviceAccountKey.json'));

initializeApp({
  credential: cert(serviceAccount),
  projectId: 'linkedup-c3e29',
});

const db = getFirestore();

const content = `**Lona v1.9.36 -- Connections & Auto-Approve Update (macOS & iOS)**

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
**Build:** 1.9.36 (70)`;

async function main() {
  const chatRef = db.collection('chats').doc('lona-service-chat');
  const senderRef = db.collection('users').doc('LJ6RK7RFp7RtWAu9bW5LAmYVId42');

  await chatRef.collection('messages').add({
    content: content,
    sender_ref: senderRef,
    created_at: FieldValue.serverTimestamp(),
    message_type: 'text',
    is_read_by: [],
  });

  await chatRef.update({
    last_message: content.substring(0, 100),
    last_message_sent_by: senderRef,
    last_message_time: FieldValue.serverTimestamp(),
    last_message_type: 'text',
  });

  console.log('Announcement sent successfully!');
  process.exit(0);
}

main().catch(e => { console.error(e.message); process.exit(1); });
