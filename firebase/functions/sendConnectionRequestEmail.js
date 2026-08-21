const functions = require("firebase-functions/v1");
const { Resend } = require("resend");

const RESEND_API_KEY = process.env.RESEND_API_KEY || "";
const RESEND_FROM_EMAIL = "invites@lona.club";
const RESEND_FROM_NAME = "Lona";

exports.sendConnectionRequestEmail = functions.https.onCall(async (data, context) => {
    const {
        recipientEmail,
        recipientName,
        senderName,
    } = data;

    if (!recipientEmail) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Missing required field: recipientEmail"
        );
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(recipientEmail)) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Invalid email address format"
        );
    }

    if (!RESEND_API_KEY) {
        console.error("❌ Resend API key not configured");
        throw new functions.https.HttpsError(
            "failed-precondition",
            "Resend API key not configured"
        );
    }

    const resend = new Resend(RESEND_API_KEY);

    try {
        const displaySender = senderName || "Someone";
        const subject = `${displaySender} wants to connect with you on Lona`;

        const { data: resendData, error } = await resend.emails.send({
            from: `${RESEND_FROM_NAME} <${RESEND_FROM_EMAIL}>`,
            to: [recipientEmail],
            subject: subject,
            html: `
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>New Connection Request</title>
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
            background: linear-gradient(135deg, #3B82F6 0%, #60A5FA 100%);
            padding: 40px 20px;
            text-align: center;
        }
        h1 {
            font-size: 22px;
            font-weight: 700;
            margin: 0;
            color: #ffffff;
        }
        .content {
            padding: 40px 30px;
            text-align: center;
        }
        p {
            font-size: 16px;
            line-height: 1.6;
            margin: 0 0 20px;
            color: #4a4a4a;
        }
        .sender-name {
            font-weight: 600;
            color: #3B82F6;
        }
        .note {
            font-size: 14px;
            color: #8e8e93;
            margin-top: 24px;
        }
        .footer {
            padding: 24px 30px;
            text-align: center;
            font-size: 12px;
            color: #8e8e93;
            background: #f9f9f9;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>New Connection Request</h1>
        </div>
        <div class="content">
            <p>Hi ${recipientName || "there"},</p>
            <p><span class="sender-name">${displaySender}</span> has sent you a connection request on Lona.</p>
            <p>Open the Lona app to review and respond to this request.</p>
            <p class="note">You received this email because someone sent you a connection request on Lona.</p>
        </div>
        <div class="footer">
            <p>&copy; 2026 Lona Club. All rights reserved.</p>
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

        console.log(`✅ Connection request email sent to ${recipientEmail} via Resend. ID: ${resendData.id}`);
        return {
            success: true,
            message: "Connection request email sent successfully",
            id: resendData.id,
        };
    } catch (error) {
        console.error("❌ Error sending connection request email:", error);

        if (error instanceof functions.https.HttpsError) {
            throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            `Failed to send connection request email: ${error.message}`
        );
    }
});
