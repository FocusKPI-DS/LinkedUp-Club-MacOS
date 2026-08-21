/**
 * One-off test script: looks up user "Vertin" in Firestore,
 * then inserts a fake unread_message_reminders doc with triggerTime in the past
 * so the next processUnreadReminders cron run sends an email.
 *
 * Usage: node testUnreadReminder.js
 */
const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const firestore = admin.firestore();

async function main() {
  // 1. Find the user named "Vertin"
  console.log('🔍 Searching for user "Vertin"...');
  const usersSnapshot = await firestore
    .collection("users")
    .where("display_name", ">=", "Vertin")
    .where("display_name", "<=", "Vertin\uf8ff")
    .limit(5)
    .get();

  if (usersSnapshot.empty) {
    console.log("❌ No user found with display_name starting with 'Vertin'");
    // Try a broader search
    const allUsers = await firestore.collection("users").limit(20).get();
    console.log("Available users:");
    allUsers.docs.forEach((doc) => {
      const d = doc.data();
      console.log(`  - ${d.display_name || d.name || "(no name)"} (${doc.id}) email: ${d.email || "N/A"}`);
    });
    process.exit(1);
  }

  const vertinDoc = usersSnapshot.docs[0];
  const vertinData = vertinDoc.data();
  console.log(`✅ Found user: ${vertinData.display_name} (${vertinDoc.id})`);
  console.log(`   Email: ${vertinData.email}`);

  if (!vertinData.email) {
    console.log("❌ User has no email, cannot send reminder.");
    process.exit(1);
  }

  // 2. Create a test reminder with triggerTime in the past
  const reminderId = `test_chat_${vertinDoc.id}`;
  const reminderRef = firestore.collection("unread_message_reminders").doc(reminderId);

  // Set triggerTime to 1 hour ago so it's immediately eligible
  const triggerTime = admin.firestore.Timestamp.fromMillis(Date.now() - 60 * 60 * 1000);

  await reminderRef.set({
    chatId: "test_chat",
    userId: vertinDoc.id,
    senderId: "test_sender",
    messageId: "test_message",
    senderName: "Test Sender",
    chatName: "Test Group Chat",
    isGroup: false,
    triggerTime: triggerTime,
    status: "pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`✅ Created test reminder: ${reminderId}`);
  console.log(`   triggerTime: ${triggerTime.toDate().toISOString()} (in the past)`);
  console.log(`   status: pending`);
  console.log("");
  console.log("📧 The processUnreadReminders cron job runs every 10 minutes.");
  console.log("   It will pick up this document and send an email to:", vertinData.email);
  console.log("");
  console.log("   Or you can wait and check Firebase Console logs.");

  process.exit(0);
}

main().catch((err) => {
  console.error("Error:", err);
  process.exit(1);
});
