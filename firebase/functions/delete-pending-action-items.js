/**
 * One-off script: Delete all action_items where status === "pending".
 * Uses same credentials as send-lona-announcement.js (serviceAccountKey.json or gcloud ADC).
 *
 *   DRY_RUN=1 node delete-pending-action-items.js   # report only
 *   node delete-pending-action-items.js             # actually delete
 */

const admin = require("firebase-admin");
const path = require("path");
const fs = require("fs");

const DRY_RUN = process.env.DRY_RUN === "1";

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
    admin.initializeApp();
    console.log("✅ Initialized with GOOGLE_APPLICATION_CREDENTIALS\n");
  } else {
    try {
      admin.initializeApp();
      console.log("✅ Initialized with Application Default Credentials\n");
    } catch (e) {
      console.error("❌ No credentials. Use serviceAccountKey.json or gcloud auth application-default login");
      process.exit(1);
    }
  }
}

const firestore = admin.firestore();
const BATCH_SIZE = 500;

async function main() {
  console.log(DRY_RUN ? "🔍 DRY RUN – no deletes\n" : "🗑️  Deleting pending action_items\n");

  const snapshot = await firestore
    .collection("action_items")
    .where("status", "==", "pending")
    .get();

  const refs = snapshot.docs.map((d) => d.ref);
  const total = refs.length;

  if (total === 0) {
    console.log("No pending action_items found.");
    return;
  }

  if (!DRY_RUN) {
    for (let i = 0; i < refs.length; i += BATCH_SIZE) {
      const batch = firestore.batch();
      const chunk = refs.slice(i, i + BATCH_SIZE);
      chunk.forEach((ref) => batch.delete(ref));
      await batch.commit();
      console.log(`  Deleted ${Math.min(i + BATCH_SIZE, total)} / ${total}`);
    }
  }

  console.log("════════════════════════════════════════");
  console.log(DRY_RUN ? "Would delete:" : "Done.");
  console.log(`  Pending action_items: ${total}`);
  console.log("════════════════════════════════════════\n");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
