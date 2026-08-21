/**
 * Send a test message from TestVertin to Vertin via Firebase Admin SDK.
 * 
 * Usage: node sendTestMessage.js
 */

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.project_id,
  });
}

const db = admin.firestore();

async function sendTestMessage() {
  console.log("🔍 Looking up users...");

  // 1. Find TestVertin user
  const testVertinQuery = await db
    .collection("users")
    .where("display_name", "==", "TestVertin")
    .limit(1)
    .get();

  if (testVertinQuery.empty) {
    console.error("❌ User 'TestVertin' not found!");
    // Try alternative names
    const altQuery = await db
      .collection("users")
      .where("display_name", "==", "Test Vertin")
      .limit(1)
      .get();
    if (altQuery.empty) {
      // List some users to help debug
      console.log("\n📋 Available users (first 20):");
      const allUsers = await db.collection("users").limit(20).get();
      allUsers.forEach((doc) => {
        const data = doc.data();
        console.log(`  - ${data.display_name || "(no name)"} (uid: ${doc.id}, email: ${data.email || "N/A"})`);
      });
      process.exit(1);
    }
    var testVertinDoc = altQuery.docs[0];
  } else {
    var testVertinDoc = testVertinQuery.docs[0];
  }

  const testVertinRef = testVertinDoc.ref;
  const testVertinData = testVertinDoc.data();
  console.log(`✅ Found sender: ${testVertinData.display_name} (${testVertinDoc.id})`);

  // 2. Find Vertin user
  const vertinQuery = await db
    .collection("users")
    .where("display_name", "==", "Vertin")
    .limit(1)
    .get();

  if (vertinQuery.empty) {
    console.error("❌ User 'Vertin' not found!");
    // List some users to help debug
    console.log("\n📋 Available users (first 20):");
    const allUsers = await db.collection("users").limit(20).get();
    allUsers.forEach((doc) => {
      const data = doc.data();
      console.log(`  - ${data.display_name || "(no name)"} (uid: ${doc.id}, email: ${data.email || "N/A"})`);
    });
    process.exit(1);
  }

  const vertinDoc = vertinQuery.docs[0];
  const vertinRef = vertinDoc.ref;
  const vertinData = vertinDoc.data();
  console.log(`✅ Found receiver: ${vertinData.display_name} (${vertinDoc.id})`);

  // 3. Find existing 1-on-1 chat between them
  console.log("\n🔍 Looking for existing chat between them...");
  const chatsQuery = await db
    .collection("chats")
    .where("members", "array-contains", testVertinRef)
    .get();

  let chatRef = null;
  for (const chatDoc of chatsQuery.docs) {
    const chatData = chatDoc.data();
    const members = chatData.members || [];
    // Check if this is a 1-on-1 chat containing both users
    const hasVertin = members.some((m) => m.path === vertinRef.path);
    const isOneOnOne = !chatData.is_group && members.length === 2;
    if (hasVertin && isOneOnOne) {
      chatRef = chatDoc.ref;
      console.log(`✅ Found existing chat: ${chatDoc.id}`);
      break;
    }
  }

  // If no chat exists, create one
  if (!chatRef) {
    console.log("📝 No existing chat found, creating new one...");
    const newChat = await db.collection("chats").add({
      title: "",
      is_group: false,
      created_by: testVertinRef,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      members: [testVertinRef, vertinRef],
      last_message: "",
      last_message_at: admin.firestore.FieldValue.serverTimestamp(),
      last_message_sent: testVertinRef,
      last_message_type: "text",
      last_message_seen: [testVertinRef],
      is_pin: false,
      is_private: false,
    });
    chatRef = newChat;
    console.log(`✅ Created new chat: ${newChat.id}`);
  }

  // 4. Send the message
  const messageContent = "👋 Hello Vertin! This is a test message sent from TestVertin via script. 🚀";
  console.log(`\n📤 Sending message: "${messageContent}"`);

  const messageData = {
    sender_ref: testVertinRef,
    content: messageContent,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    message_type: "text",
    is_read_by: [testVertinRef],
    sender_name: testVertinData.display_name || "TestVertin",
    sender_photo: testVertinData.photo_url || "",
    is_edited: false,
    is_system_message: false,
    is_pinned: false,
  };

  const messageRef = await chatRef.collection("messages").add(messageData);
  console.log(`✅ Message sent! ID: ${messageRef.id}`);

  // 5. Update chat metadata
  await chatRef.update({
    last_message: messageContent,
    last_message_at: admin.firestore.FieldValue.serverTimestamp(),
    last_message_sent: testVertinRef,
    last_message_type: "text",
    last_message_seen: [testVertinRef],
  });
  console.log("✅ Chat metadata updated!");

  console.log("\n🎉 Done! Message sent successfully from TestVertin to Vertin.");
}

sendTestMessage()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ Error:", err);
    process.exit(1);
  });
