/**
 * Send a message with @mentions from TestVertin in a group chat.
 * 
 * Usage: node sendGroupMention.js
 */

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.project_id,
  });
}

const db = admin.firestore();

async function main() {
  console.log("🔍 Looking up TestVertin...");

  // 1. Find TestVertin
  const testVertinQuery = await db
    .collection("users")
    .where("display_name", "==", "TestVertin")
    .limit(1)
    .get();

  if (testVertinQuery.empty) {
    console.error("❌ User 'TestVertin' not found!");
    process.exit(1);
  }

  const testVertinDoc = testVertinQuery.docs[0];
  const testVertinRef = testVertinDoc.ref;
  const testVertinData = testVertinDoc.data();
  console.log(`✅ Found TestVertin: ${testVertinDoc.id}`);

  // 2. Find all group chats where TestVertin is a member
  console.log("\n🔍 Looking for group chats...");
  const chatsQuery = await db
    .collection("chats")
    .where("members", "array-contains", testVertinRef)
    .get();

  const groupChats = [];
  for (const chatDoc of chatsQuery.docs) {
    const chatData = chatDoc.data();
    if (chatData.is_group === true) {
      groupChats.push({ ref: chatDoc.ref, id: chatDoc.id, data: chatData });
    }
  }

  if (groupChats.length === 0) {
    console.error("❌ TestVertin is not in any group chats!");
    console.log("\n📋 All chats TestVertin is in:");
    for (const chatDoc of chatsQuery.docs) {
      const d = chatDoc.data();
      console.log(`  - ${chatDoc.id} | title: "${d.title || "(untitled)"}" | is_group: ${d.is_group} | members: ${(d.members || []).length}`);
    }
    process.exit(1);
  }

  console.log(`\n📋 Found ${groupChats.length} group chat(s):`);
  for (let i = 0; i < groupChats.length; i++) {
    const g = groupChats[i];
    console.log(`  [${i}] "${g.data.title || "(untitled)"}" (${g.id}) - ${(g.data.members || []).length} members`);
  }

  // Use the first group chat
  const targetChat = groupChats[0];
  const chatRef = targetChat.ref;
  console.log(`\n🎯 Using group: "${targetChat.data.title || "(untitled)"}" (${targetChat.id})`);

  // 3. Get all members of the group
  const memberRefs = targetChat.data.members || [];
  console.log(`\n🔍 Loading ${memberRefs.length} members...`);

  const members = [];
  for (const memberRef of memberRefs) {
    try {
      const userDoc = await memberRef.get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        members.push({
          ref: memberRef,
          id: userDoc.id,
          displayName: userData.display_name || "(unknown)",
          photoUrl: userData.photo_url || "",
        });
        console.log(`  ✅ ${userData.display_name} (${userDoc.id})`);
      }
    } catch (e) {
      console.log(`  ⚠️ Could not load member: ${memberRef.path}`);
    }
  }

  // 4. Pick members to @mention (all members except TestVertin)
  const mentionTargets = members.filter((m) => m.id !== testVertinDoc.id);

  if (mentionTargets.length === 0) {
    console.error("❌ No other members to mention!");
    process.exit(1);
  }

  // Build the @mention markup: <@uid|DisplayName>
  const mentionParts = mentionTargets.map((m) => `<@${m.id}|${m.displayName}>`);
  const mentionText = mentionParts.join(" ");

  const messageContent = `👋 Hey ${mentionText} — this is a test message with @mentions sent from TestVertin via script! 🚀`;

  console.log(`\n📤 Sending message with ${mentionTargets.length} mention(s):`);
  console.log(`   Raw: ${messageContent}`);
  console.log(`   Display: ${messageContent.replace(/<@[^|]+\|([^>]+)>/g, "@$1")}`);

  // 5. Send the message
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
  console.log(`\n✅ Message sent! ID: ${messageRef.id}`);

  // 6. Update chat metadata
  const previewContent = messageContent.replace(/<@[^|]+\|([^>]+)>/g, "@$1");
  await chatRef.update({
    last_message: previewContent.length > 100 ? previewContent.substring(0, 100) : previewContent,
    last_message_at: admin.firestore.FieldValue.serverTimestamp(),
    last_message_sent: testVertinRef,
    last_message_type: "text",
    last_message_seen: [testVertinRef],
  });
  console.log("✅ Chat metadata updated!");

  console.log(`\n🎉 Done! Message with @mentions sent in group "${targetChat.data.title || "(untitled)"}"!`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ Error:", err);
    process.exit(1);
  });
