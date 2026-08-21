const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const firestore = admin.firestore();
const { Resend } = require("resend");

// Get API key from env or Firebase Runtime Config
let RESEND_API_KEY = process.env.RESEND_API_KEY || "";
try {
  if (!RESEND_API_KEY && functions.config().resend && functions.config().resend.key) {
    RESEND_API_KEY = functions.config().resend.key;
  }
} catch (e) {
  // functions.config() may not be available outside Cloud Functions runtime
}
const RESEND_FROM_EMAIL = "invites@lona.club"; 
const RESEND_FROM_NAME = "Lona Reminder";

/**
 * Triggered when a new message is created in any chat.
 * Checks if it's a DM or if there are mentions in a group chat,
 * and schedules an unread reminder 1 hour into the future.
 */
exports.scheduleUnreadReminder = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    try {
      const chatId = context.params.chatId;
      const messageId = context.params.messageId;

      // Skip lona-service-chat
      if (chatId === 'lona-service-chat') return;

      const messageData = snapshot.data();
      if (!messageData) return;

      // Skip system messages
      if (messageData.is_system_message === true) return;
      
      // Skip AI messages
      if (messageData.sender_type === 'ai' || (messageData.sender_ref && messageData.sender_ref.id === 'lona-service')) {
        return;
      }

      const senderRef = messageData.sender_ref;
      if (!senderRef) return;

      const chatDoc = await firestore.doc(`chats/${chatId}`).get();
      if (!chatDoc.exists) return;

      const chatData = chatDoc.data();
      const isGroup = chatData.is_group || false;
      const members = chatData.members || [];
      
      // Get sender name
      let senderName = "Someone";
      try {
        const senderDoc = await firestore.doc(`users/${senderRef.id}`).get();
        if (senderDoc.exists) {
          senderName = senderDoc.data().display_name || senderDoc.data().name || "Someone";
        }
      } catch (e) {
        console.log('Error getting sender name:', e);
      }

      let targetUserIds = new Set();

      if (!isGroup) {
        // For DMs, the target is the other member
        members.forEach(memberRef => {
          if (memberRef && memberRef.id !== senderRef.id) {
            targetUserIds.add(memberRef.id);
          }
        });
      } else {
        // For Groups, parse mentions: format is <@uid|Name>
        const content = messageData.content || '';
        if (content) {
          const mentionRegex = /<@([a-zA-Z0-9_-]+)\|/g;
          let match;
          while ((match = mentionRegex.exec(content)) !== null) {
            const mentionedUid = match[1];
            if (mentionedUid !== senderRef.id) {
              targetUserIds.add(mentionedUid);
            }
          }
        }
      }

      if (targetUserIds.size === 0) return;

      // Compute trigger time (1 hour from message creation)
      // created_at might be a Firestore Timestamp or a JS Date, handle both
      let createdAtMs;
      const rawCreatedAt = messageData.created_at;
      if (rawCreatedAt && typeof rawCreatedAt.toDate === 'function') {
        createdAtMs = rawCreatedAt.toDate().getTime();
      } else if (rawCreatedAt instanceof Date) {
        createdAtMs = rawCreatedAt.getTime();
      } else {
        createdAtMs = Date.now();
      }
      const triggerTimeMs = createdAtMs + (60 * 60 * 1000); // 1 hour
      const triggerTime = admin.firestore.Timestamp.fromMillis(triggerTimeMs);

      // Read all existing reminders first (avoid mixing reads inside batch writes)
      const reminderChecks = [];
      for (const targetUserId of targetUserIds) {
        const reminderId = `${chatId}_${targetUserId}`;
        const reminderRef = firestore.collection('unread_message_reminders').doc(reminderId);
        reminderChecks.push({ userId: targetUserId, ref: reminderRef, doc: await reminderRef.get() });
      }

      const batch = firestore.batch();
      let scheduledCount = 0;
      for (const { userId, ref, doc: reminderDoc } of reminderChecks) {
        // Only create if no pending reminder exists (keep earliest trigger time)
        if (!reminderDoc.exists || reminderDoc.data().status !== 'pending') {
          batch.set(ref, {
            chatId: chatId,
            userId: userId,
            senderId: senderRef.id,
            messageId: messageId,
            senderName: senderName,
            chatName: chatData.title || '',
            isGroup: isGroup,
            triggerTime: triggerTime,
            status: "pending",
            createdAt: admin.firestore.FieldValue.serverTimestamp()
          });
          scheduledCount++;
        }
      }
      
      if (scheduledCount > 0) {
        await batch.commit();
        console.log(`✅ Scheduled unread reminders for ${scheduledCount}/${targetUserIds.size} users in chat ${chatId}`);
      }

    } catch (e) {
      console.error(`❌ Error in scheduleUnreadReminder: ${e}`);
    }
  });

/**
 * Triggers when chat is updated. Removes pending reminders if the user is 
 * added to last_message_seen.
 */
exports.clearUnreadReminder = functions.firestore
  .document('chats/{chatId}')
  .onUpdate(async (change, context) => {
    try {
      const chatId = context.params.chatId;
      const beforeData = change.before.data();
      const afterData = change.after.data();

      const beforeSeen = beforeData.last_message_seen || [];
      const afterSeen = afterData.last_message_seen || [];

      // Extract new UIDs added to last_message_seen
      const beforeIds = new Set(beforeSeen.map(ref => ref.id));
      const afterIds = afterSeen.map(ref => ref.id);
      
      const newlySeenIds = afterIds.filter(id => !beforeIds.has(id));

      if (newlySeenIds.length === 0) return;

      const batch = firestore.batch();
      for (const userId of newlySeenIds) {
        const reminderId = `${chatId}_${userId}`;
        const reminderRef = firestore.collection('unread_message_reminders').doc(reminderId);
        
        // Delete pending reminders since the user has read the chat
        batch.delete(reminderRef);
      }
      await batch.commit();
      if (newlySeenIds.length > 0) {
        console.log(`✅ Cleared unread reminders for ${newlySeenIds.length} users in chat ${chatId}`);
      }

    } catch (e) {
      console.error(`❌ Error in clearUnreadReminder: ${e}`);
    }
  });

/**
 * Cron job that runs every 10 minutes to process pending unread message reminders.
 * 
 * REQUIRED Firestore composite index:
 *   Collection: unread_message_reminders
 *   Fields: status (Ascending), triggerTime (Ascending)
 */
exports.processUnreadReminders = functions.pubsub
  .schedule("every 10 minutes")
  .onRun(async (context) => {
    try {
      if (!RESEND_API_KEY) {
        console.error("❌ Resend API key not configured for reminders.");
        return null;
      }
      const resend = new Resend(RESEND_API_KEY);
      
      const now = admin.firestore.Timestamp.now();
      
      // Query pending reminders whose trigger time has passed
      const remindersSnapshot = await firestore
        .collection('unread_message_reminders')
        .where('status', '==', 'pending')
        .where('triggerTime', '<=', now)
        .limit(100) // process in batches
        .get();

      if (remindersSnapshot.empty) {
        return null;
      }

      console.log(`⏱ Processing ${remindersSnapshot.size} pending unread reminders...`);

      const batch = firestore.batch();
      let sentCount = 0;

      for (const doc of remindersSnapshot.docs) {
        const data = doc.data();
        
        try {
          // get user email
          const userDoc = await firestore.doc(`users/${data.userId}`).get();
          if (!userDoc.exists) {
            batch.delete(doc.ref);
            continue;
          }
          
          const userData = userDoc.data();
          const email = userData.email;
          const userName = userData.display_name || userData.name || "User";
          
          if (!email) {
            batch.delete(doc.ref);
            continue;
          }

          // Escape HTML special characters to prevent injection
          const escapeHtml = (str) => (str || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
          const contextName = data.isGroup ? (data.chatName || "a Group Chat") : (data.senderName || "Someone");
          const safeContextName = escapeHtml(contextName);
          const safeUserName = escapeHtml(userName);
          let subject = `You have an unread message from ${contextName}`;
          
          // Basic email format without exposing message content
          const htmlContent = `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #333;">
              <h2 style="color: #007AFF;">Lona Reminder</h2>
              <p>Hi ${safeUserName},</p>
              <p>You have new unread messages from <strong>${safeContextName}</strong> on Lona.</p>
              <p>Please open the Lona app to check your messages and reply.</p>
              <br/>
              <p style="font-size: 12px; color: #888;">This is an automated reminder.</p>
            </div>
          `;

          const { error } = await resend.emails.send({
            from: `${RESEND_FROM_NAME} <${RESEND_FROM_EMAIL}>`,
            to: [email],
            subject: subject,
            html: htmlContent,
          });

          if (error) {
            console.error(`❌ Resend error for ${email}:`, error);
            // Optionally leave as pending to retry, or mark failed. We'll mark failed.
            batch.update(doc.ref, { status: "failed", error: error.message, sentAt: now });
          } else {
            console.log(`📧 Unread reminder sent to ${email}`);
            batch.update(doc.ref, { status: "sent", sentAt: now });
            sentCount++;
          }
        } catch (innerErr) {
          console.error(`Error processing reminder ${doc.id}:`, innerErr);
        }
      }

      await batch.commit();
      console.log(`✅ Completed processing reminders. Sent: ${sentCount}`);

    } catch (e) {
      console.error(`❌ Error in processUnreadReminders: ${e}`);
    }
    return null;
  });
