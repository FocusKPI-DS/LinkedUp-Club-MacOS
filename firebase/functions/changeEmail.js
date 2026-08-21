const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { Resend } = require("resend");

const RESEND_API_KEY = (functions.config().resend && functions.config().resend.key) || process.env.RESEND_API_KEY || "";
const RESEND_FROM_EMAIL = "noreply@lona.club";
const RESEND_FROM_NAME = "Lona";

/**
 * Cloud Function: sendChangeEmailVerification
 * 
 * Called from the Lona app when a user wants to change their email.
 * Uses Firebase Admin SDK to generate a verify-and-change-email link,
 * then sends it via Resend (same email service used by other Lona emails).
 */
exports.sendChangeEmailVerification = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Must be logged in to change email."
    );
  }

  const { newEmail } = data;
  const uid = context.auth.uid;

  if (!newEmail || typeof newEmail !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "newEmail is required."
    );
  }

  // Basic email validation
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(newEmail)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Invalid email address."
    );
  }

  try {
    // Get current user
    const currentUser = await admin.auth().getUser(uid);
    const currentEmail = currentUser.email;

    if (!currentEmail) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Current user has no email address."
      );
    }

    if (currentEmail.toLowerCase() === newEmail.toLowerCase()) {
      throw new functions.https.HttpsError(
        "already-exists",
        "New email is the same as current email."
      );
    }

    // Check if the new email is already in use
    try {
      await admin.auth().getUserByEmail(newEmail);
      throw new functions.https.HttpsError(
        "already-exists",
        "This email is already used by another account."
      );
    } catch (err) {
      if (err instanceof functions.https.HttpsError) throw err;
      if (err.code !== "auth/user-not-found") throw err;
      // auth/user-not-found = email is available, good!
    }

    // Generate the verify-and-change-email link via Admin SDK
    const link = await admin.auth().generateVerifyAndChangeEmailLink(
      currentEmail,
      newEmail,
      {
        url: "https://lona.club/app",
        handleCodeInApp: false,
      }
    );

    // Send via Resend
    if (!RESEND_API_KEY) {
      console.error("❌ RESEND_API_KEY not configured");
      throw new functions.https.HttpsError(
        "internal",
        "Email service not configured."
      );
    }

    const resend = new Resend(RESEND_API_KEY);
    const { data: emailData, error } = await resend.emails.send({
      from: `${RESEND_FROM_NAME} <${RESEND_FROM_EMAIL}>`,
      to: newEmail,
      subject: "Verify your new email address - Lona",
      html: `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto; padding: 40px 20px; background-color: #f9fafb;">
          <div style="text-align: center; margin-bottom: 32px;">
            <h1 style="font-size: 28px; font-weight: 700; color: #1a1a1a; margin: 0;">Lona</h1>
          </div>
          <div style="background: #ffffff; border: 1px solid #e5e7eb; border-radius: 16px; padding: 36px; box-shadow: 0 1px 3px rgba(0,0,0,0.05);">
            <h2 style="font-size: 20px; font-weight: 600; color: #1a1a1a; margin: 0 0 20px 0;">Verify your new email</h2>
            <p style="font-size: 15px; color: #4b5563; line-height: 1.6; margin: 0 0 12px 0;">
              You requested to change your Lona account email:
            </p>
            <div style="background: #f3f4f6; border-radius: 10px; padding: 16px; margin: 0 0 24px 0;">
              <p style="font-size: 14px; color: #6b7280; margin: 0 0 6px 0;">
                <strong>Current:</strong> ${currentEmail}
              </p>
              <p style="font-size: 14px; color: #1a1a1a; margin: 0;">
                <strong>New:</strong> ${newEmail}
              </p>
            </div>
            <p style="font-size: 15px; color: #4b5563; line-height: 1.6; margin: 0 0 28px 0;">
              Click the button below to verify and complete the change:
            </p>
            <div style="text-align: center; margin: 0 0 28px 0;">
              <a href="${link}" style="display: inline-block; background: linear-gradient(135deg, #2563eb, #1d4ed8); color: #ffffff; font-size: 16px; font-weight: 600; text-decoration: none; padding: 14px 36px; border-radius: 10px; box-shadow: 0 2px 8px rgba(37,99,235,0.3);">
                Verify New Email
              </a>
            </div>
            <p style="font-size: 13px; color: #9ca3af; line-height: 1.5; margin: 0; border-top: 1px solid #f3f4f6; padding-top: 20px;">
              If you didn't request this change, you can safely ignore this email. Your account email will remain unchanged.
            </p>
          </div>
          <p style="font-size: 12px; color: #9ca3af; text-align: center; margin-top: 24px;">
            © ${new Date().getFullYear()} Lona. All rights reserved.
          </p>
        </div>
      `,
    });

    if (error) {
      console.error("❌ Resend error:", error);
      throw new functions.https.HttpsError("internal", "Failed to send email.");
    }

    console.log(`✅ Change email verification sent to ${newEmail} for user ${uid} (Resend ID: ${emailData?.id})`);

    // Store the pending email change in Firestore so we can sync after verification
    const firestore = admin.firestore();
    await firestore.collection("users").doc(uid).update({
      pending_email_change: newEmail,
    });

    return { success: true, email: newEmail };

  } catch (error) {
    console.error("❌ Change email error:", error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError(
      "internal",
      error.message || "Failed to send verification email."
    );
  }
});

/**
 * Cloud Function: syncEmailAfterVerification
 * 
 * Called by the client after the user navigates back to the app.
 * Checks if the Auth email has changed and syncs it to Firestore.
 */
exports.syncEmailAfterVerification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in.");
  }

  const uid = context.auth.uid;
  const firestore = admin.firestore();

  try {
    const authUser = await admin.auth().getUser(uid);
    const authEmail = authUser.email;

    if (!authEmail) return { synced: false };

    const userDoc = await firestore.collection("users").doc(uid).get();
    if (!userDoc.exists) return { synced: false };

    const firestoreEmail = userDoc.data().email;

    if (firestoreEmail !== authEmail) {
      await firestore.collection("users").doc(uid).update({
        email: authEmail,
        pending_email_change: admin.firestore.FieldValue.delete(),
      });
      console.log(`✅ Synced email for ${uid}: ${firestoreEmail} → ${authEmail}`);
      return { synced: true, newEmail: authEmail };
    }

    return { synced: false };
  } catch (error) {
    console.error("❌ Sync email error:", error);
    throw new functions.https.HttpsError("internal", error.message || "Failed to sync email.");
  }
});
