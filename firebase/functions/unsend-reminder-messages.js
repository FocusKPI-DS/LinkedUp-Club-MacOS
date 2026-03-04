/**
 * One-off script: Remove LonaAI "Task reminders" messages from group chats only.
 * Does NOT touch push notifications (ff_user_push_notifications).
 *
 * Run from firebase/functions with same credentials as send-lona-announcement.js:
 *   node unsend-reminder-messages.js
 *
 * Optional: DRY_RUN=1 node unsend-reminder-messages.js  (report only, no deletes)
 */

const admin = require("firebase-admin");
const path = require("path");
const fs = require("fs");

const DRY_RUN = process.env.DRY_RUN === "1";

// Reuse same credential logic as send-lona-announcement.js
let serviceAccountPath = path.join(__dirname, "serviceAccountKey.json");
if (!fs.existsSync(serviceAccountPath)) {
  serviceAccountPath = path.join(__dirname, "linkedup-c3e29-firebase-adminsdk-fbsvc-3e51f9a4e1.json");
}

if (!admin.apps.length) {
  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    console.log("✅ Initialized with service account key\n");
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "linkedup-c3e29" });
    console.log("✅ Initialized with GOOGLE_APPLICATION_CREDENTIALS\n");
  } else {
    try {
      admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "linkedup-c3e29" });
      console.log("✅ Initialized with Application Default Credentials\n");
    } catch (e) {
      console.error("❌ No credentials. Use serviceAccountKey.json or gcloud auth application-default login");
      process.exit(1);
    }
  }
}

const firestore = admin.firestore();
const LONA_AI_PATH = "users/ai_agent_lonaai";
const TASK_REMINDER_MARKER = "Task reminders";

async function main() {
  console.log(DRY_RUN ? "🔍 DRY RUN – no changes will be made\n" : "🗑️  Unsend reminder messages (group chats only)\n");

  const groupChatsSnap = await firestore.collection("chats").where("is_group", "==", true).get();
  let totalDeleted = 0;
  let chatsAffected = 0;

  for (const chatDoc of groupChatsSnap.docs) {
    const chatRef = chatDoc.ref;
    const messagesSnap = await chatRef.collection("messages").orderBy("created_at", "desc").get();

    const toDelete = [];
    for (const msgDoc of messagesSnap.docs) {
      const d = msgDoc.data();
      const senderPath = d.sender_ref && d.sender_ref.path;
      const isLona = senderPath === LONA_AI_PATH || (d.sender_name && d.sender_name === "LonaAI");
      const isReminder = (d.content || "").includes(TASK_REMINDER_MARKER);
      if (isLona && isReminder) toDelete.push(msgDoc.ref);
    }

    if (toDelete.length === 0) continue;

    chatsAffected += 1;
    totalDeleted += toDelete.length;

    if (!DRY_RUN) {
      const batch = firestore.batch();
      for (const ref of toDelete) batch.delete(ref);
      await batch.commit();
    }

    // Fix last_message for this chat: set to the most recent message that remains (or empty)
    if (!DRY_RUN) {
      const afterSnap = await chatRef.collection("messages").orderBy("created_at", "desc").limit(1).get();
      const lastMsg = afterSnap.docs[0] ? afterSnap.docs[0].data() : null;
      const firstLine = lastMsg && lastMsg.content ? lastMsg.content.split("\n")[0] : "";
      const preview = firstLine.length > 80 ? firstLine.substring(0, 77) + "..." : firstLine;

      await chatRef.update({
        last_message: lastMsg ? preview : "",
        last_message_at: lastMsg && lastMsg.created_at ? lastMsg.created_at : null,
        last_message_sent: lastMsg && lastMsg.sender_ref ? lastMsg.sender_ref : null,
        last_message_type: lastMsg && lastMsg.message_type ? lastMsg.message_type : null,
      });
    }
  }

  console.log("════════════════════════════════════════");
  console.log(DRY_RUN ? "Would delete:" : "Done.");
  console.log(`  Chats affected: ${chatsAffected}`);
  console.log(`  Messages removed: ${totalDeleted}`);
  console.log("════════════════════════════════════════\n");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
