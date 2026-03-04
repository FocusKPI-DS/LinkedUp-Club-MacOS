/**
 * Schedule message – standalone Cloud Function (not wired in index.js to avoid confusion).
 * Run every minute; sends any pending scheduled_messages whose scheduled_send_at is <= now.
 * Creates the message in the chat and updates chat last_message; marks the scheduled doc as sent.
 *
 * To deploy this function, add to index.js:
 *   exports.scheduledMessagesSend = require('./scheduledMessages').scheduledMessagesSend;
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const firestore = admin.firestore();

exports.scheduledMessagesSend = functions
  .runWith({
    timeoutSeconds: 120,
    memory: "256MB",
  })
  .pubsub.schedule("* * * * *") // Every minute
  .timeZone("UTC")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const snapshot = await firestore
      .collection("scheduled_messages")
      .where("status", "==", "pending")
      .where("scheduled_send_at", "<=", now)
      .limit(100)
      .get();

    if (snapshot.empty) {
      return null;
    }

    let sent = 0;
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const chatRef = data.chat_ref;
      let messageData = data.message_data || {};

      if (!chatRef || !chatRef.path) {
        await doc.ref.update({
          status: "failed",
          error: "missing chat_ref",
          sent_at: now,
        });
        continue;
      }

      try {
        // Use scheduled_send_at as message created_at so the message appears at the scheduled time
        messageData = { ...messageData };
        messageData.created_at = data.scheduled_send_at;

        const messageRef = chatRef.collection("messages").doc();
        await messageRef.set(messageData);

        // Determine last_message text for chat metadata
        let lastMessageText = messageData.content || "";
        if (lastMessageText.length === 0) {
          if (messageData.images && messageData.images.length > 0) lastMessageText = "📷 Photo";
          else if (messageData.video) lastMessageText = "🎬 Video";
          else if (messageData.audio) lastMessageText = "🎤 Voice message";
          else if (messageData.attachment_url) lastMessageText = "📎 File";
        }

        await chatRef.update({
          last_message: lastMessageText,
          last_message_at: data.scheduled_send_at,
          last_message_sent: messageData.sender_ref,
          last_message_type: messageData.message_type || "text",
          last_message_seen: messageData.sender_ref ? [messageData.sender_ref] : [],
        });

        await doc.ref.update({
          status: "sent",
          sent_at: now,
        });
        sent++;
      } catch (err) {
        console.error("scheduledMessagesSend error for doc", doc.id, err);
        await doc.ref.update({
          status: "failed",
          error: String(err && err.message),
          sent_at: now,
        });
      }
    }

    if (sent > 0) {
      console.log(`scheduledMessagesSend: sent ${sent} message(s)`);
    }
    return null;
  });
