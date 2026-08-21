/**
 * Direct test: send an email to Vertin using Resend API.
 * This bypasses the Cloud Function entirely to verify Resend works.
 *
 * Usage: RESEND_API_KEY=re_xxx node testDirectEmail.js
 *   or it will try to read from Firebase config.
 */
const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");
const { Resend } = require("resend");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

async function main() {
  // Try to get API key from env or Firebase runtime config
  let apiKey = process.env.RESEND_API_KEY;
  
  if (!apiKey) {
    // Try reading from Firebase functions config
    console.log("No RESEND_API_KEY in env, checking Firebase config...");
    try {
      const configSnapshot = await admin.firestore()
        .collection("_config")
        .doc("resend")
        .get();
      if (configSnapshot.exists) {
        apiKey = configSnapshot.data().api_key;
      }
    } catch (e) {
      // ignore
    }
  }

  if (!apiKey) {
    // Last resort: try to read the functions config via REST
    console.log("Trying functions.config() equivalent...");
    console.log("");
    console.log("❌ Cannot find RESEND_API_KEY automatically.");
    console.log("   Please run with: RESEND_API_KEY=re_xxx node testDirectEmail.js");
    console.log("");
    console.log("   You can find the key in Firebase Console → Functions → Environment Variables");
    console.log("   Or run: firebase functions:config:get resend --project linkedup-c3e29");
    process.exit(1);
  }

  console.log(`✅ Got API key: ${apiKey.substring(0, 8)}...`);

  const resend = new Resend(apiKey);

  const email = "vertins@focuskpi.com";
  console.log(`📧 Sending test email to ${email}...`);

  try {
    const { data, error } = await resend.emails.send({
      from: "Lona Reminder <invites@lona.club>",
      to: [email],
      subject: "Test Email - Lona Unread Reminder",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #333;">
          <h2 style="color: #007AFF;">Lona Reminder</h2>
          <p>Hi Vertin,</p>
          <p>This is a <strong>test email</strong> to verify the Resend API is working correctly.</p>
          <p>If you see this, the unread message reminder feature is ready to go! 🎉</p>
          <br/>
          <p style="font-size: 12px; color: #888;">This is a test from the unread reminder system.</p>
        </div>
      `,
    });

    if (error) {
      console.error("❌ Resend API error:", error);
    } else {
      console.log("✅ Email sent successfully!");
      console.log("   Resend ID:", data.id);
    }
  } catch (err) {
    console.error("❌ Error:", err.message);
  }

  process.exit(0);
}

main();
