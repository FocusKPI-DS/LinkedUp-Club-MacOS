/**
 * Test script: Insert a test notification into ff_user_push_notifications
 * to trigger Lona's WebNotificationService.
 *
 * Usage: node testNotification.js [user_uid]
 *   Default user: Vertin (LJ6RK7RFp7RtWAu9bW5LAmYVId42)
 */

const admin = require("firebase-admin");
const path = require("path");

// Initialize with service account
const serviceAccount = require(path.join(__dirname, "serviceAccountKey.json"));

// Check if already initialized
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const firestore = admin.firestore();

async function sendTestNotification() {
  // Get user UID from command line or use default (Vertin)
  const userUid = process.argv[2] || "LJ6RK7RFp7RtWAu9bW5LAmYVId42";
  const userRef = `users/${userUid}`;

  console.log(`\n🔔 Sending test notification to user: ${userRef}`);

  const notificationData = {
    notification_title: "🧪 Test Notification",
    notification_text: "This is a test message from the notification system! If you see this popup, Lona notifications are working correctly.",
    notification_image_url: "",
    notification_sound: "default",
    user_refs: userRef,
    initial_page_name: "ChatDetail",
    parameter_data: JSON.stringify({}),
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  };

  try {
    const docRef = await firestore
      .collection("ff_user_push_notifications")
      .add(notificationData);

    console.log(`✅ Test notification created!`);
    console.log(`   Document ID: ${docRef.id}`);
    console.log(`   Title: ${notificationData.notification_title}`);
    console.log(`   Body: ${notificationData.notification_text}`);
    console.log(`   Target user: ${userRef}`);
    console.log(`\n📌 If Lona Web is open and logged in as this user,`);
    console.log(`   you should see a browser notification popup within seconds.`);
  } catch (error) {
    console.error("❌ Failed to send test notification:", error);
  }

  // Exit after a short delay to allow Firestore write to complete
  setTimeout(() => process.exit(0), 2000);
}

sendTestNotification();
