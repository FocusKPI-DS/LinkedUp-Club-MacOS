/**
 * One-time backfill script to update last_message fields for all chats.
 * 
 * For each chat document, queries the most recent message in its 
 * messages subcollection and updates last_message, last_message_at,
 * last_message_sent, and last_message_type on the chat document.
 * 
 * Usage: Call this as an HTTP Cloud Function once, then delete it.
 * curl https://us-central1-linkedup-c3e29.cloudfunctions.net/backfillChatLastMessage
 */

const admin = require("firebase-admin");

// admin.initializeApp() is already called in index.js
const db = admin.firestore();

exports.backfillChatLastMessage = async (req, res) => {
  try {
    const chatsSnapshot = await db.collection("chats").get();
    console.log(`Found ${chatsSnapshot.size} chats to process`);

    let updated = 0;
    let skipped = 0;
    let errors = 0;
    const results = [];

    for (const chatDoc of chatsSnapshot.docs) {
      try {
        const chatId = chatDoc.id;
        const chatData = chatDoc.data();

        // Query the latest message in this chat's messages subcollection
        const messagesSnapshot = await db
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .orderBy("created_at", "desc")
          .limit(1)
          .get();

        if (messagesSnapshot.empty) {
          skipped++;
          results.push({ chatId, status: "skipped", reason: "no messages" });
          continue;
        }

        const latestMessage = messagesSnapshot.docs[0].data();
        const msgContent = latestMessage.content || "";
        const msgCreatedAt = latestMessage.created_at || null;
        const msgSenderRef = latestMessage.sender_ref || null;
        const msgType = latestMessage.message_type || "M";

        // Build preview text (truncate to 200 chars)
        let previewText = msgContent;
        if (previewText && previewText.length > 200) {
          previewText = previewText.substring(0, 200);
        }

        // Check if the existing last_message_at is already newer (race condition safety)
        const existingLastMsgAt = chatData.last_message_at;
        if (
          existingLastMsgAt &&
          msgCreatedAt &&
          existingLastMsgAt.toDate &&
          msgCreatedAt.toDate
        ) {
          const existingTime = existingLastMsgAt.toDate().getTime();
          const newTime = msgCreatedAt.toDate().getTime();
          if (existingTime >= newTime) {
            // Existing data is already up to date or newer
            skipped++;
            results.push({
              chatId,
              status: "skipped",
              reason: "already up to date",
              existingMsg: chatData.last_message
                ? chatData.last_message.substring(0, 50)
                : "(empty)",
            });
            continue;
          }
        }

        // Update the chat document
        const updateData = {
          last_message: previewText,
          last_message_at: msgCreatedAt,
          last_message_type: msgType,
        };
        if (msgSenderRef) {
          updateData.last_message_sent = msgSenderRef;
        }

        await chatDoc.ref.update(updateData);
        updated++;
        results.push({
          chatId,
          status: "updated",
          newPreview: previewText ? previewText.substring(0, 50) : "(empty)",
          oldPreview: chatData.last_message
            ? chatData.last_message.substring(0, 50)
            : "(empty)",
        });
      } catch (err) {
        errors++;
        results.push({
          chatId: chatDoc.id,
          status: "error",
          error: err.message,
        });
        console.error(`Error processing chat ${chatDoc.id}:`, err);
      }
    }

    const summary = {
      totalChats: chatsSnapshot.size,
      updated,
      skipped,
      errors,
      details: results,
    };

    console.log("Backfill complete:", JSON.stringify(summary, null, 2));
    res.status(200).json(summary);
  } catch (err) {
    console.error("Backfill failed:", err);
    res.status(500).json({ error: err.message });
  }
};
