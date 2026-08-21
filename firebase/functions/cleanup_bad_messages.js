const admin = require('firebase-admin');

// Initialize with default credentials (uses gcloud auth)
admin.initializeApp({
  projectId: 'linkedup-c3e29',
});

const db = admin.firestore();

async function cleanupBadMessages() {
  // Find the chat "Vertin, TestVertin, tester222"
  const chatsSnap = await db.collection('chats').get();
  
  let targetChatRef = null;
  for (const chatDoc of chatsSnap.docs) {
    const data = chatDoc.data();
    // Look for the group chat with these members
    if (data.chat_name && data.chat_name.includes('tester222')) {
      targetChatRef = chatDoc.ref;
      console.log(`Found chat: ${chatDoc.id} - ${data.chat_name || 'unnamed'}`);
      break;
    }
    // Also check users array
    if (data.users && data.users.length === 3) {
      const memberNames = data.member_names || [];
      if (memberNames.some(n => n && n.includes('tester222'))) {
        targetChatRef = chatDoc.ref;
        console.log(`Found chat: ${chatDoc.id}`);
        break;
      }
    }
  }
  
  if (!targetChatRef) {
    // Try listing all chats with messages subcollection
    console.log('Searching all chats...');
    for (const chatDoc of chatsSnap.docs) {
      const data = chatDoc.data();
      const lastMsg = data.last_message || '';
      if (lastMsg.includes('.png') || lastMsg.includes('.docx')) {
        console.log(`Candidate chat: ${chatDoc.id}, last_message: "${lastMsg}"`);
        targetChatRef = chatDoc.ref;
      }
    }
  }
  
  if (!targetChatRef) {
    console.log('Chat not found. Listing all chats:');
    for (const chatDoc of chatsSnap.docs) {
      const data = chatDoc.data();
      console.log(`  ${chatDoc.id}: last_message="${data.last_message || ''}", users=${data.users?.length || 0}`);
    }
    return;
  }
  
  // Get all messages in this chat
  const messagesSnap = await targetChatRef.collection('messages')
    .orderBy('created_at', 'desc')
    .get();
  
  console.log(`\nTotal messages: ${messagesSnap.size}`);
  
  let deletedCount = 0;
  for (const msgDoc of messagesSnap.docs) {
    const data = msgDoc.data();
    const msgType = data.message_type;
    const content = data.content || '';
    const image = data.image || '';
    const createdAt = data.created_at ? data.created_at.toDate() : null;
    
    // Show all messages
    console.log(`  [${msgDoc.id}] type=${msgType}, content="${content.substring(0, 50)}", image=${image ? 'YES' : 'no'}, created=${createdAt}`);
    
    // Delete broken image messages (content is empty or a filename, message_type is image)
    if (msgType === 'image' && (!content || content.trim() === '' || content.match(/^\d+\.\w+$/))) {
      console.log(`    -> DELETING broken image message: ${msgDoc.id}`);
      await msgDoc.ref.delete();
      deletedCount++;
    }
  }
  
  console.log(`\nDeleted ${deletedCount} broken messages.`);
}

cleanupBadMessages().then(() => process.exit(0)).catch(e => {
  console.error('Error:', e);
  process.exit(1);
});
