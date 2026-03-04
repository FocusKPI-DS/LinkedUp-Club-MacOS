/**
 * Firebase Cloud Function to send workspace invitation emails via MailerSend
 * 
 * This function:
 * 1. Gets the workspace's invite_code from Firestore
 * 2. Sends an email via MailerSend with the invite code
 * 3. Returns success/error status
 * 
 * Usage:
 * Call this function from your Flutter app:
 * 
 * final result = await FirebaseFunctions.instance
 *   .httpsCallable('sendWorkspaceInviteEmail')
 *   .call({
 *     'email': 'user@example.com',
 *     'workspaceId': 'workspace_id',
 *     'workspaceName': 'Workspace Name',
 *     'inviterUserId': 'user_id',
 *     'inviterName': 'User Name',
 *   });
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

// MailerSend API configuration
const MAILERSEND_API_KEY = functions.config().mailersend?.api_key || "";
const MAILERSEND_FROM_EMAIL = functions.config().mailersend?.from_email || "noreply@lona.club";
const MAILERSEND_FROM_NAME = functions.config().mailersend?.from_name || "Lona";

exports.sendWorkspaceInviteEmail = functions
  .runWith({
    timeoutSeconds: 60,
    memory: "256MB",
  })
  .https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be authenticated to send invitations"
      );
    }

    const {
      email,
      workspaceId,
      workspaceName,
      inviterUserId,
      inviterName,
    } = data;

    // Validate required fields
    if (!email || !workspaceId || !workspaceName || !inviterUserId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields: email, workspaceId, workspaceName, inviterUserId"
      );
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid email address format"
      );
    }

    try {
      // Get workspace document to retrieve invite_code
      const workspaceRef = admin.firestore()
        .collection("workspaces")
        .doc(workspaceId);

      const workspaceDoc = await workspaceRef.get();

      if (!workspaceDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Workspace not found"
        );
      }

      const workspaceData = workspaceDoc.data();
      const inviteCode = workspaceData.invite_code;

      if (!inviteCode || inviteCode.trim().length === 0) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Workspace does not have an invite code. Please generate one first."
        );
      }

      // If no MailerSend API key is configured, return error
      if (!MAILERSEND_API_KEY) {
        console.error("❌ MailerSend API key not configured");
        throw new functions.https.HttpsError(
          "failed-precondition",
          "MailerSend API key not configured. Please set functions.config().mailersend.api_key"
        );
      }

      // Prepare email content
      const subject = `${inviterName || "Someone"} has invited you to ${workspaceName} workspace`;
      const emailBody = `
Hi there,

${inviterName || "Someone"} has invited you to join the "${workspaceName}" workspace on Lona!

Your invitation code is:

${inviteCode}

To join the workspace:
1. Open the Lona app
2. Go to Settings → Workspace Management
3. Enter the invitation code above
4. Click "Join Workspace"

Looking forward to having you on board!

Best regards,
The Lona Team
      `.trim();

      // Send email via MailerSend API
      const mailerSendResponse = await sendMailerSendEmail({
        to: email,
        subject: subject,
        text: emailBody,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #333;">You've been invited!</h2>
            <p>Hi there,</p>
            <p><strong>${inviterName || "Someone"}</strong> has invited you to join the "<strong>${workspaceName}</strong>" workspace on Lona!</p>
            <div style="background-color: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center;">
              <p style="margin: 0; font-size: 14px; color: #666;">Your invitation code is:</p>
              <h1 style="margin: 10px 0; font-size: 32px; color: #007AFF; letter-spacing: 4px;">${inviteCode}</h1>
            </div>
            <p><strong>To join the workspace:</strong></p>
            <ol>
              <li>Open the Lona app</li>
              <li>Go to Settings → Workspace Management</li>
              <li>Enter the invitation code above</li>
              <li>Click "Join Workspace"</li>
            </ol>
            <p>Looking forward to having you on board!</p>
            <p>Best regards,<br>The Lona Team</p>
          </div>
        `,
      });

      if (mailerSendResponse.success) {
        console.log(`✅ Workspace invitation email sent to ${email} for workspace ${workspaceName} (${inviteCode})`);
        return {
          success: true,
          message: "Invitation email sent successfully",
          inviteCode: inviteCode,
        };
      } else {
        throw new functions.https.HttpsError(
          "internal",
          `Failed to send email: ${mailerSendResponse.message}`
        );
      }
    } catch (error) {
      console.error("❌ Error sending workspace invitation email:", error);
      
      // If it's already an HttpsError, re-throw it
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      // Otherwise, wrap it in an HttpsError
      throw new functions.https.HttpsError(
        "internal",
        `Failed to send invitation email: ${error.message}`
      );
    }
  });

/**
 * Sends an email via MailerSend API
 * 
 * @param {Object} emailData - Email data (to, subject, text, html)
 * @returns {Promise<Object>} Response with success status and message
 */
async function sendMailerSendEmail(emailData) {
  try {
    const url = "https://api.mailersend.com/v1/email";

    const payload = {
      from: {
        email: MAILERSEND_FROM_EMAIL,
        name: MAILERSEND_FROM_NAME,
      },
      to: [
        {
          email: emailData.to,
        },
      ],
      subject: emailData.subject,
      text: emailData.text,
      html: emailData.html,
    };

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${MAILERSEND_API_KEY}`,
        "Content-Type": "application/json",
        "X-Requested-With": "XMLHttpRequest",
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error("❌ MailerSend API error:", errorText);
      return {
        success: false,
        message: `MailerSend API error: ${response.status} ${response.statusText}`,
      };
    }

    // MailerSend may return empty body on success (202 Accepted)
    // Check content length before parsing JSON
    const contentType = response.headers.get("content-type");
    let responseData = null;
    
    if (contentType && contentType.includes("application/json")) {
      const responseText = await response.text();
      if (responseText && responseText.trim().length > 0) {
        try {
          responseData = JSON.parse(responseText);
        } catch (e) {
          console.warn("⚠️ Could not parse JSON response:", responseText);
        }
      }
    }

    return {
      success: true,
      message: "Email sent successfully",
      data: responseData,
    };
  } catch (error) {
    console.error("❌ Error calling MailerSend API:", error);
    return {
      success: false,
      message: error.message || "Failed to send email",
    };
  }
}

