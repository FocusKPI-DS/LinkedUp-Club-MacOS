const functions = require("firebase-functions");
const { Resend } = require("resend");

// Resend API configuration
const RESEND_API_KEY = functions.config().resend?.key || "";
const RESEND_FROM_EMAIL = "invites@lona.club"; // This must be a verified domain in Resend
const RESEND_FROM_NAME = "Lona";

exports.sendInviteEmail = functions
    .runWith({
        timeoutSeconds: 60,
        memory: "256MB",
    })
    .https.onCall(async (data, context) => {
        // Verify authentication (optional, but recommended if you want to track who sends invites)
        // if (!context.auth) {
        //   throw new functions.https.HttpsError(
        //     "unauthenticated",
        //     "Must be authenticated to send invitations"
        //   );
        // }

        const {
            email,
            recipientName,
            senderName,
            referralLink,
            personalMessage,
        } = data;

        // Validate required fields
        if (!email || !referralLink) {
            throw new functions.https.HttpsError(
                "invalid-argument",
                "Missing required fields: email or referralLink"
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

        if (!RESEND_API_KEY) {
            console.error("❌ Resend API key not configured");
            throw new functions.https.HttpsError(
                "failed-precondition",
                "Resend API key not configured. Please set functions.config().resend.key"
            );
        }

        const resend = new Resend(RESEND_API_KEY);

        try {
            const subject = senderName
                ? `${senderName} invited you to join Lona`
                : "You've been invited to join Lona!";

            const { data: resendData, error } = await resend.emails.send({
                from: `${RESEND_FROM_NAME} <${RESEND_FROM_EMAIL}>`,
                to: [email],
                subject: subject,
                html: `
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Invitation to Lona</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: #f9f9f9;
            margin: 0;
            padding: 0;
            color: #1a1a1a;
        }
        .container {
            max-width: 600px;
            margin: 40px auto;
            background: #ffffff;
            border-radius: 16px;
            overflow: hidden;
            box-shadow: 0 4px 24px rgba(0, 0, 0, 0.06);
        }
        .header {
            background: linear-gradient(135deg, #007AFF 0%, #00C6FF 100%);
            padding: 40px 20px;
            text-align: center;
        }
        .logo {
            width: 80px;
            height: 80px;
            margin-bottom: 20px;
            border-radius: 20px;
            background: rgba(255, 255, 255, 0.2);
            display: inline-flex;
            align-items: center;
            justify-content: center;
            backdrop-filter: blur(10px);
        }
        .content {
            padding: 40px 30px;
            text-align: center;
        }
        h1 {
            font-size: 24px;
            font-weight: 700;
            margin: 0 0 16px;
            color: #ffffff;
        }
        p {
            font-size: 16px;
            line-height: 1.6;
            margin: 0 0 24px;
            color: #4a4a4a;
        }
        .personal-message {
            background: #f5f5f7;
            padding: 20px;
            border-radius: 12px;
            font-style: italic;
            margin-bottom: 30px;
            text-align: left;
            position: relative;
        }
        .personal-message::before {
            content: '"';
            font-size: 40px;
            color: #007AFF;
            position: absolute;
            top: 5px;
            left: 10px;
            opacity: 0.1;
        }
        .button {
            display: inline-block;
            background-color: #007AFF;
            color: #ffffff !important;
            padding: 16px 32px;
            border-radius: 12px;
            text-decoration: none;
            font-weight: 600;
            font-size: 16px;
            transition: transform 0.2s ease;
        }
        .footer {
            padding: 30px;
            text-align: center;
            font-size: 12px;
            color: #8e8e93;
            background: #f9f9f9;
        }
        .divider {
            height: 1px;
            background: #eee;
            margin: 30px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>You're Invited!</h1>
        </div>
        <div class="content">
            <p>Hi ${recipientName || "there"},</p>
            <p>Hey! I've been using this app named Lona for communication, and it's amazing! It really boosts productivity and makes team collaboration so much easier. You should check it out!</p>
            
            ${personalMessage ? `
            <div class="personal-message">
                ${personalMessage}
            </div>
            ` : ""}

            <a href="${referralLink}" class="button">Accept Invitation</a>
            
            <p style="margin-top: 30px; font-size: 14px; color: #8e8e93;">
                Or copy and paste this link into your browser:<br>
                <span style="color: #007AFF;">${referralLink}</span>
            </p>
        </div>
        <div class="footer">
            <p>&copy; 2026 Lona Club. All rights reserved.</p>
            <p>You received this because someone invited you to join Lona.</p>
        </div>
    </div>
</body>
</html>
        `,
            });

            if (error) {
                console.error("❌ Resend API error:", error);
                throw new functions.https.HttpsError(
                    "internal",
                    `Failed to send email: ${error.message}`
                );
            }

            console.log(`✅ Invite email sent to ${email} via Resend. ID: ${resendData.id}`);
            return {
                success: true,
                message: "Invitation email sent successfully",
                id: resendData.id,
            };
        } catch (error) {
            console.error("❌ Error sending invite email:", error);

            if (error instanceof functions.https.HttpsError) {
                throw error;
            }

            throw new functions.https.HttpsError(
                "internal",
                `Failed to send invitation email: ${error.message}`
            );
        }
    });
