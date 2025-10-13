const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const kFcmTokensCollection = "fcm_tokens";
const kPushNotificationsCollection = "ff_push_notifications";
const kUserPushNotificationsCollection = "ff_user_push_notifications";
const firestore = admin.firestore();

const kPushNotificationRuntimeOpts = {
  timeoutSeconds: 540,
  memory: "2GB",
};

exports.addFcmToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    return "Failed: Unauthenticated calls are not allowed.";
  }
  const userDocPath = data.userDocPath;
  const fcmToken = data.fcmToken;
  const deviceType = data.deviceType;
  if (
    typeof userDocPath === "undefined" ||
    typeof fcmToken === "undefined" ||
    typeof deviceType === "undefined" ||
    userDocPath.split("/").length <= 1 ||
    fcmToken.length === 0 ||
    deviceType.length === 0
  ) {
    return "Invalid arguments encoutered when adding FCM token.";
  }
  if (context.auth.uid != userDocPath.split("/")[1]) {
    return "Failed: Authenticated user doesn't match user provided.";
  }
  const existingTokens = await firestore
    .collectionGroup(kFcmTokensCollection)
    .where("fcm_token", "==", fcmToken)
    .get();
  var userAlreadyHasToken = false;
  for (var doc of existingTokens.docs) {
    const user = doc.ref.parent.parent;
    if (user.path != userDocPath) {
      // Should never have the same FCM token associated with multiple users.
      await doc.ref.delete();
    } else {
      userAlreadyHasToken = true;
    }
  }
  if (userAlreadyHasToken) {
    return "FCM token already exists for this user. Ignoring...";
  }
  await getUserFcmTokensCollection(userDocPath).doc().set({
    fcm_token: fcmToken,
    device_type: deviceType,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  return "Successfully added FCM token!";
});

exports.sendPushNotificationsTrigger = functions
  .runWith(kPushNotificationRuntimeOpts)
  .firestore.document(`${kPushNotificationsCollection}/{id}`)
  .onCreate(async (snapshot, _) => {
    try {
      // Ignore scheduled push notifications on create
      const scheduledTime = snapshot.data().scheduled_time || "";
      if (scheduledTime) {
        return;
      }

      await sendPushNotifications(snapshot);
    } catch (e) {
      console.log(`Error: ${e}`);
      await snapshot.ref.update({ status: "failed", error: `${e}` });
    }
  });

exports.sendUserPushNotificationsTrigger = functions
  .runWith(kPushNotificationRuntimeOpts)
  .firestore.document(`${kUserPushNotificationsCollection}/{id}`)
  .onCreate(async (snapshot, _) => {
    try {
      // Ignore scheduled push notifications on create
      const scheduledTime = snapshot.data().scheduled_time || "";
      if (scheduledTime) {
        return;
      }

      // Don't let user-triggered notifications to be sent to all users.
      const userRefsStr = snapshot.data().user_refs || "";
      if (userRefsStr) {
        await sendPushNotifications(snapshot);
      }
    } catch (e) {
      console.log(`Error: ${e}`);
      await snapshot.ref.update({ status: "failed", error: `${e}` });
    }
  });

async function sendPushNotifications(snapshot) {
  const notificationData = snapshot.data();
  const title = notificationData.notification_title || "";
  const body = notificationData.notification_text || "";
  const imageUrl = notificationData.notification_image_url || "";
  const sound = notificationData.notification_sound || "";
  const parameterData = notificationData.parameter_data || "";
  const targetAudience = notificationData.target_audience || "";
  const initialPageName = notificationData.initial_page_name || "";
  const userRefsStr = notificationData.user_refs || "";
  const batchIndex = notificationData.batch_index || 0;
  const numBatches = notificationData.num_batches || 0;
  const status = notificationData.status || "";

  if (status !== "" && status !== "started") {
    console.log(`Already processed ${snapshot.ref.path}. Skipping...`);
    return;
  }

  if (title === "" || body === "") {
    await snapshot.ref.update({ status: "failed" });
    return;
  }

  const userRefs = userRefsStr === "" ? [] : userRefsStr.trim().split(",");
  var tokens = new Set();
  if (userRefsStr) {
    for (var userRef of userRefs) {
      const userTokens = await firestore
        .doc(userRef)
        .collection(kFcmTokensCollection)
        .get();
      userTokens.docs.forEach((token) => {
        if (typeof token.data().fcm_token !== undefined) {
          tokens.add(token.data().fcm_token);
        }
      });
    }
  } else {
    var userTokensQuery = firestore.collectionGroup(kFcmTokensCollection);
    // Handle batched push notifications by splitting tokens up by document
    // id.
    if (numBatches > 0) {
      userTokensQuery = userTokensQuery
        .orderBy(admin.firestore.FieldPath.documentId())
        .startAt(getDocIdBound(batchIndex, numBatches))
        .endBefore(getDocIdBound(batchIndex + 1, numBatches));
    }
    const userTokens = await userTokensQuery.get();
    userTokens.docs.forEach((token) => {
      const data = token.data();
      const audienceMatches =
        targetAudience === "All" || data.device_type === targetAudience;
      if (audienceMatches && typeof data.fcm_token !== undefined) {
        tokens.add(data.fcm_token);
      }
    });
  }

  const tokensArr = Array.from(tokens);
  var messageBatches = [];
  for (let i = 0; i < tokensArr.length; i += 500) {
    const tokensBatch = tokensArr.slice(i, Math.min(i + 500, tokensArr.length));
    const messages = {
      notification: {
        title,
        body,
        ...(imageUrl && { imageUrl: imageUrl }),
      },
      data: {
        initialPageName,
        parameterData,
      },
      android: {
        notification: {
          ...(sound && { sound: sound }),
        },
      },
      apns: {
        payload: {
          aps: {
            ...(sound && { sound: sound }),
          },
        },
      },
      tokens: tokensBatch,
    };
    messageBatches.push(messages);
  }

  var numSent = 0;
  await Promise.all(
    messageBatches.map(async (messages) => {
      const response = await admin.messaging().sendEachForMulticast(messages);
      numSent += response.successCount;
    }),
  );

  await snapshot.ref.update({ status: "succeeded", num_sent: numSent });
}

function getUserFcmTokensCollection(userDocPath) {
  return firestore.doc(userDocPath).collection(kFcmTokensCollection);
}

function getDocIdBound(index, numBatches) {
  if (index <= 0) {
    return "users/(";
  }
  if (index >= numBatches) {
    return "users/}";
  }
  const numUidChars = 62;
  const twoCharOptions = Math.pow(numUidChars, 2);

  var twoCharIdx = (index * twoCharOptions) / numBatches;
  var firstCharIdx = Math.floor(twoCharIdx / numUidChars);
  var secondCharIdx = Math.floor(twoCharIdx % numUidChars);
  const firstChar = getCharForIndex(firstCharIdx);
  const secondChar = getCharForIndex(secondCharIdx);
  return "users/" + firstChar + secondChar;
}

function getCharForIndex(charIdx) {
  if (charIdx < 10) {
    return String.fromCharCode(charIdx + "0".charCodeAt(0));
  } else if (charIdx < 36) {
    return String.fromCharCode("A".charCodeAt(0) + charIdx - 10);
  } else {
    return String.fromCharCode("a".charCodeAt(0) + charIdx - 36);
  }
}
exports.onUserDeleted = functions.auth.user().onDelete(async (user) => {
  let firestore = admin.firestore();
  let userRef = firestore.doc("users/" + user.uid);
  await firestore.collection("users").doc(user.uid).delete();
});
// ========== WORKSPACE MIGRATION FUNCTION ==========
// One-time function to migrate all existing users to FocusKPI workspace
exports.migrateUsersToFocusKPI = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be authenticated to run migration.'
    );
  }
  
  try {
    console.log('Starting user migration to FocusKPI workspace...');
    const db = admin.firestore();
    const focusKPIRef = db.collection('workspaces').doc('focuskpi');
    
    // Verify FocusKPI workspace exists
    const focusKPIDoc = await focusKPIRef.get();
    if (!focusKPIDoc.exists) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'FocusKPI workspace does not exist. Please create it first.'
      );
    }
    
    // Get all users
    const usersSnapshot = await db.collection('users').get();
    console.log(`Found ${usersSnapshot.size} users to migrate`);
    
    if (usersSnapshot.empty) {
      return {
        success: true,
        message: 'No users to migrate',
        migratedUsers: 0
      };
    }
    
    let migratedCount = 0;
    let errorCount = 0;
    const errors = [];
    
    const batchSize = 400; // Firestore batch limit
    let batch = db.batch();
    let operationCount = 0;
    
    for (const userDoc of usersSnapshot.docs) {
      try {
        const userId = userDoc.id;
        const userData = userDoc.data();
        
        // Skip if already has workspace
        if (userData.current_workspace_ref) {
          console.log(`User ${userId} already has workspace, skipping...`);
          continue;
        }
        
        // Create workspace membership
        const memberRef = db.collection('workspace_members').doc();
        batch.set(memberRef, {
          workspace_ref: focusKPIRef,
          user_ref: db.collection('users').doc(userId),
          role: 'member',
          joined_at: admin.firestore.FieldValue.serverTimestamp(),
          status: 'active',
          is_default: true
        });
        operationCount++;
        
        // Update user with workspace info
        batch.update(userDoc.ref, {
          current_workspace_ref: focusKPIRef,
          workspaces: [focusKPIRef],
          default_workspace_ref: focusKPIRef
        });
        operationCount++;
        
        migratedCount++;
        
        // Commit batch if we hit the limit
        if (operationCount >= batchSize) {
          await batch.commit();
          console.log(`Committed batch of ${operationCount} operations. Total migrated: ${migratedCount}`);
          batch = db.batch();
          operationCount = 0;
        }
        
      } catch (error) {
        console.error(`Error migrating user ${userDoc.id}:`, error);
        errorCount++;
        errors.push({ userId: userDoc.id, error: error.message });
      }
    }
    
    // Commit remaining operations
    if (operationCount > 0) {
      await batch.commit();
      console.log(`Committed final batch of ${operationCount} operations`);
    }
    
    const result = {
      success: true,
      message: `Migration completed. Migrated ${migratedCount} users to FocusKPI workspace.`,
      migratedUsers: migratedCount,
      totalUsers: usersSnapshot.size,
      errors: errorCount > 0 ? errors : undefined
    };
    
    console.log('Migration completed:', result);
    return result;
    
  } catch (error) {
    console.error('Migration failed:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ========== CHAT WORKSPACE MIGRATION FUNCTION ==========
// One-time function to migrate all existing chats to FocusKPI workspace
exports.migrateChatsToFocusKPI = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be authenticated to run migration.'
    );
  }
  
  try {
    console.log('Starting chat migration to FocusKPI workspace...');
    const db = admin.firestore();
    const focusKPIRef = db.collection('workspaces').doc('focuskpi');
    
    // Verify FocusKPI workspace exists
    const focusKPIDoc = await focusKPIRef.get();
    if (!focusKPIDoc.exists) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'FocusKPI workspace does not exist. Please create it first.'
      );
    }
    
    // Get all chats
    const chatsSnapshot = await db.collection('chats').get();
    console.log(`Found ${chatsSnapshot.size} chats to migrate`);
    
    if (chatsSnapshot.empty) {
      return {
        success: true,
        message: 'No chats to migrate',
        migratedChats: 0
      };
    }
    
    let migratedCount = 0;
    let skippedCount = 0;
    let errorCount = 0;
    const errors = [];
    
    const batchSize = 500; // Firestore batch limit
    let batch = db.batch();
    let operationCount = 0;
    
    for (const chatDoc of chatsSnapshot.docs) {
      try {
        const chatId = chatDoc.id;
        const chatData = chatDoc.data();
        
        // Skip if already has workspace_ref
        if (chatData.workspace_ref) {
          console.log(`Chat ${chatId} already has workspace, skipping...`);
          skippedCount++;
          continue;
        }
        
        // Add workspace_ref to chat
        batch.update(chatDoc.ref, {
          workspace_ref: focusKPIRef
        });
        operationCount++;
        migratedCount++;
        
        // Commit batch if we hit the limit
        if (operationCount >= batchSize) {
          await batch.commit();
          console.log(`Committed batch of ${operationCount} operations. Total migrated: ${migratedCount}`);
          batch = db.batch();
          operationCount = 0;
        }
        
      } catch (error) {
        console.error(`Error migrating chat ${chatDoc.id}:`, error);
        errorCount++;
        errors.push({ chatId: chatDoc.id, error: error.message });
      }
    }
    
    // Commit remaining operations
    if (operationCount > 0) {
      await batch.commit();
      console.log(`Committed final batch of ${operationCount} operations`);
    }
    
    const result = {
      success: true,
      message: `Migration completed. Migrated ${migratedCount} chats to FocusKPI workspace.`,
      migratedChats: migratedCount,
      skippedChats: skippedCount,
      totalChats: chatsSnapshot.size,
      errors: errorCount > 0 ? errors : undefined
    };
    
    console.log('Chat migration completed:', result);
    return result;
    
  } catch (error) {
    console.error('Chat migration failed:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ==========================================
// DAILY EVENT ENGAGEMENT CLOUD FUNCTION
// ==========================================
exports.sendDailyEventEngagement = functions
  .runWith({
    timeoutSeconds: 540,
    memory: "2GB",
    maxInstances: 5,
  })
  .pubsub
  .schedule("0 * * * *") // Runs every hour
  .timeZone("America/Los_Angeles") // Set your preferred timezone
  .onRun(async (context) => {
    const currentHour = new Date().getHours();
    console.log(`Starting hourly group engagement check at hour ${currentHour}`);
    
    try {
      const openaiApiKey = functions.config().openai?.key;
      
      if (!openaiApiKey) {
        console.error("OpenAI API key not configured");
        return;
      }

      // Query all group chats (both event and non-event groups)
      const groupChatsSnapshot = await firestore
        .collection("chats")
        .where("is_group", "==", true)
        .get();

      if (groupChatsSnapshot.empty) {
        console.log("No group chats found");
        return;
      }

      console.log(`Found ${groupChatsSnapshot.size} group chats`);

      // Create AI bot user reference
      const aiBotUserRef = firestore.doc("users/ai_agent_linkai");

      // Process each chat
      const promises = groupChatsSnapshot.docs.map(async (chatDoc) => {
        try {
          const chatData = chatDoc.data();
          const chatRef = chatDoc.ref.path;
          
          // Get or set reminder_frequency
          let reminderFrequency = chatData.reminder_frequency;
          if (typeof reminderFrequency === 'undefined' || reminderFrequency === null) {
            // Set default reminder_frequency to 1
            reminderFrequency = 1;
            await chatDoc.ref.update({ reminder_frequency: 1 });
            console.log(`Set default reminder_frequency=1 for chat: ${chatRef}`);
          }

          // Calculate if we should send a message this hour
          // Distribute messages evenly throughout the day (8 AM to 8 PM)
          const startHour = 8;
          const endHour = 20;
          const availableHours = endHour - startHour;
          
          if (currentHour < startHour || currentHour >= endHour) {
            // Outside of active hours
            return;
          }

          // Calculate which hours this chat should receive messages
          const hoursForThisChat = [];
          if (reminderFrequency === 1) {
            // Send at 9 AM for once-daily messages
            hoursForThisChat.push(9);
          } else {
            // Distribute evenly across the day
            const interval = Math.floor(availableHours / reminderFrequency);
            for (let i = 0; i < reminderFrequency; i++) {
              const hour = startHour + (i * interval);
              if (hour < endHour) {
                hoursForThisChat.push(hour);
              }
            }
          }

          // Check if current hour is in the list
          if (!hoursForThisChat.includes(currentHour)) {
            return; // Skip this chat for this hour
          }

          const chatType = chatData.event_ref ? 'event' : 'general';
          console.log(`Sending message to ${chatType} chat ${chatRef} (frequency: ${reminderFrequency}, hour: ${currentHour})`);
          
          // Skip if the chat has been inactive for more than 30 days
          const lastMessageAt = chatData.last_message_at;
          if (lastMessageAt) {
            const daysSinceLastMessage = (Date.now() - lastMessageAt.toDate().getTime()) / (1000 * 60 * 60 * 24);
            if (daysSinceLastMessage > 30) {
              console.log(`Skipping inactive chat: ${chatRef}`);
              return;
            }
          }

          // Fetch event info (if available) and recent messages in parallel
          const [eventInfo, messagesSnapshot] = await Promise.all([
            chatData.event_ref 
              ? chatData.event_ref.get().then(eventDoc => {
                  if (eventDoc.exists) {
                    const eventData = eventDoc.data();
                    return {
                      title: eventData.title || "",
                      description: eventData.description || "",
                      location: eventData.location || "",
                      startDate: eventData.start_date ? eventData.start_date.toDate().toISOString() : "",
                      endDate: eventData.end_date ? eventData.end_date.toDate().toISOString() : "",
                      speakers: eventData.speakers || [],
                      category: eventData.category || [],
                      dateSchedule: eventData.dateSchedule || []
                    };
                  }
                  return null;
                })
              : Promise.resolve(null),
            firestore
              .doc(chatRef)
              .collection("messages")
              .orderBy("created_at", "desc")
              .limit(20) // Get last 20 messages for better context
              .get()
          ]);

          // Prepare recent messages context
          const recentMessages = [];
          messagesSnapshot.docs.forEach(doc => {
            const msgData = doc.data();
            // Skip AI messages to avoid self-referencing
            if (msgData.sender_ref?.path !== "users/ai_agent_linkai") {
              recentMessages.push({
                sender: msgData.sender_name || "Unknown",
                content: msgData.content || "",
                timestamp: msgData.created_at ? msgData.created_at.toDate().toISOString() : ""
              });
            }
          });
          recentMessages.reverse(); // Chronological order

          // Calculate event timing context or set general context
          const now = new Date();
          let timingContext = "";
          let eventPhase = "general"; // upcoming, ongoing, concluded, general
          
          if (eventInfo) {
            const eventStart = eventInfo.startDate ? new Date(eventInfo.startDate) : null;
            const eventEnd = eventInfo.endDate ? new Date(eventInfo.endDate) : null;
            
            if (eventStart && eventEnd) {
              if (now < eventStart) {
                const daysUntil = Math.ceil((eventStart - now) / (1000 * 60 * 60 * 24));
                timingContext = `The event starts in ${daysUntil} days.`;
                eventPhase = "upcoming";
              } else if (now >= eventStart && now <= eventEnd) {
                timingContext = "The event is currently ongoing!";
                eventPhase = "ongoing";
              } else {
                timingContext = "The event has concluded.";
                eventPhase = "concluded";
              }
            }
          } else {
            // Non-event group context
            timingContext = "This is a general discussion group.";
            eventPhase = "general";
          }

          // Add time of day context for varied messages
          let timeOfDayContext = "";
          if (currentHour < 12) {
            timeOfDayContext = "morning";
          } else if (currentHour < 17) {
            timeOfDayContext = "afternoon";
          } else {
            timeOfDayContext = "evening";
          }

          // Analyze recent conversation topics
          let conversationThemes = [];
          let mostActiveUser = null;
          let userMessageCount = {};
          
          recentMessages.forEach(msg => {
            // Count messages per user
            userMessageCount[msg.sender] = (userMessageCount[msg.sender] || 0) + 1;
            
            // Extract themes from messages (simple keyword analysis)
            const keywords = msg.content.toLowerCase().match(/\b\w{4,}\b/g) || [];
            conversationThemes.push(...keywords);
          });
          
          // Find most active user
          if (Object.keys(userMessageCount).length > 0) {
            mostActiveUser = Object.entries(userMessageCount).reduce((a, b) => a[1] > b[1] ? a : b)[0];
          }
          
          // Get most common themes
          const themeFrequency = {};
          conversationThemes.forEach(theme => {
            if (!['that', 'this', 'with', 'from', 'have', 'been', 'what', 'your', 'about'].includes(theme)) {
              themeFrequency[theme] = (themeFrequency[theme] || 0) + 1;
            }
          });
          const topThemes = Object.entries(themeFrequency)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 3)
            .map(([theme]) => theme);

          // Check previous AI messages today to ensure variety
          const todayStart = new Date();
          todayStart.setHours(0, 0, 0, 0);
          
          const previousAIMessagesToday = messagesSnapshot.docs.filter(doc => {
            const msgData = doc.data();
            return msgData.sender_ref?.path === "users/ai_agent_linkai" && 
                   msgData.created_at && 
                   msgData.created_at.toDate() >= todayStart;
          });

          const usedMessageStyles = previousAIMessagesToday.map(doc => {
            const content = doc.data().content.toLowerCase();
            // Simple pattern matching to identify message types
            if (content.includes('poll') || content.includes('would you rather')) return 'poll';
            if (content.includes('did you know') || content.includes('fact')) return 'fact';
            if (content.includes('challenge')) return 'challenge';
            if (content.includes('tip')) return 'tip';
            if (content.includes('quote')) return 'quote';
            if (content.includes('who') && content.includes('?')) return 'question';
            return 'general';
          });

          // Prepare system prompt for engaging message
          let systemPrompt = `You are Linkai, an AI assistant for the LinkedUp networking app. Your primary goal is to foster active and meaningful engagement within this group chat by sending ONE proactive, thoughtful message. 

Your Message Generation Process:
-Analyze & Summarize: First, analyze the recentMessages. If there's an active discussion (more than ~5 recent messages), your message must begin with a concise, 1-2 sentence summary of the main topic. This demonstrates you are listening to the conversation. (e.g., "It sounds like there's a great discussion about Dr. Anya Sharma's keynote on AI ethics..." or "Loving the debate on the pros and cons of remote vs. hybrid work..."). If the chat is quiet, you can skip the summary and proceed to step 2.
-Engage & Extend: Based on the conversation you just summarized (or the group's general purpose if the chat is quiet), craft a meaningful follow-up. Your goal is to extend the current topic, not pivot away from it. Ask a specific follow-up question, introduce a new angle, or connect two ideas from the discussion.
-Add a "Hook": Conclude your message with an engaging hook that is directly related to the topic. This gives members an easy and interesting way to respond. Good hooks include a surprising piece of trivia, a relevant fun fact, or a quick poll.

CRITICAL REQUIREMENTS:
- Follow the 3-Step Process: Your message structure must follow the Analyze -> Engage -> Hook model described above.
- If people have been discussing specific topics, acknowledge or build on them
- Be aware that it's ${timeOfDayContext}
- Vary Your Style: You MUST vary your message style and avoid generic greetings. Today you've already sent ${previousAIMessagesToday.length} messages with styles: ${usedMessageStyles.join(', ')}. AVOID repeating these.

${eventInfo ? `Event Context:
- The event is ${eventPhase}
- Use the Message Style Options below as inspiration for the "Engage & Extend" and "Hook" parts of your message.

Message Style Options for Event Groups (prioritize unused styles):
1. Ask about a specific speaker or session by name
2. Share a fun fact or trivia related to the event's topic/category
3. Create a mini-poll or "would you rather" question about event topics
4. Highlight an upcoming session or speaker with enthusiasm
5. Share a networking tip specific to the event's industry/category
6. Ask about specific challenges in the event's field
7. Suggest a creative networking activity for attendees
8. Share an inspiring quote related to the event theme
9. Ask about implementation plans for learnings from specific sessions
10. Create a playful challenge or game related to the event topic
11. Share a ${timeOfDayContext} greeting with event-specific content
12. Suggest interesting resources or tools related to ${eventInfo.category[0] || 'the event'}`
: `General Group Context:
- This is a general discussion group without a specific event
- Focus on facilitating engaging conversations
- Be helpful and friendly

Message Style Options for General Groups (prioritize unused styles):
1. Ask a follow-up question: Deepen the current discussion with a thoughtful question.
2. Share a related fun fact: Find a surprising fact related to the group's interests.
3. Create a mini-poll: Create a poll based on the current conversation.
4. Share a motivational quote: Find a quote that resonates with the group's goals.
5. Pose a challenge: Create a fun group challenge related to the discussion.
6. Share a ${timeOfDayContext} greeting with a conversation starter
7. Ask about people's interests or hobbies
8. Share tips or life hacks
9. Create a word game or riddle
10. Ask about current projects or goals
11. Start a discussion about trending topics`}

${recentMessages.length > 5 ? `\nCONVERSATION CONTEXT:
- Most active participant: ${mostActiveUser || 'No clear leader'}
- Topics being discussed: ${topThemes.join(', ') || 'General discussion'}
- Consider acknowledging these themes or the active participants\n` : ''}

Guidelines:
- Keep messages concise (2-3 sentences max)
- Phase: ${eventPhase} - ${timingContext}
- Time of day: ${timeOfDayContext}
- Be creative and unexpected - surprise and delight members
- With ${reminderFrequency} messages per day, this is message ${previousAIMessagesToday.length + 1}
${eventInfo ? `- Reference specific names, topics, or details from below
- Make it impossible to use this message for any other event

Current Event Information:
Title: ${eventInfo.title}
Description: ${eventInfo.description}
Location: ${eventInfo.location}
${timingContext}
Categories: ${eventInfo.category.join(", ")}` 
: `
Group Information:
Name: ${chatData.group_name || chatData.title || 'Discussion Group'}
${chatData.description ? `Description: ${chatData.description}` : ''}
Members: ${chatData.members ? chatData.members.length : 'Unknown'} participants`}`;

          if (eventInfo) {
            if (eventInfo.speakers && eventInfo.speakers.length > 0) {
              systemPrompt += "\n\nSpeakers (USE THESE NAMES):";
              eventInfo.speakers.forEach(speaker => {
                systemPrompt += `\n- ${speaker.name || "Unknown"}: ${speaker.bio || "No bio available"}`;
              });
            }

            if (eventInfo.dateSchedule && eventInfo.dateSchedule.length > 0) {
              systemPrompt += "\n\nSchedule Sessions (REFERENCE THESE):";
              eventInfo.dateSchedule.slice(0, 3).forEach(schedule => {
                systemPrompt += `\n- ${schedule.title || "Unknown"}: ${schedule.description || "No description"}`;
              });
            }
          }

          // Add conversation context if messages exist
          if (recentMessages.length > 0) {
            systemPrompt += "\n\nRecent messages (DO NOT repeat these topics directly):";
            recentMessages.slice(-5).forEach(msg => {
              systemPrompt += `\n${msg.sender}: ${msg.content.substring(0, 100)}...`;
            });
          }

          // Create varied user prompts based on event phase, time, and conversation
          const getPhaseAndTimeSpecificPrompts = () => {
            const basePrompts = [];
            
            if (eventInfo) {
              // Event-specific prompts
              if (eventPhase === "upcoming") {
                basePrompts.push(
                  `Create an exciting ${timeOfDayContext} countdown message for "${eventInfo.title}" that builds anticipation by mentioning a specific speaker or session.`,
                  `Generate a fun icebreaker question for attendees who will be at "${eventInfo.title}" in ${eventInfo.location}.`,
                  `Write a ${timeOfDayContext} message sharing a fascinating fact about ${eventInfo.category[0] || 'the event topic'} to get people excited for "${eventInfo.title}".`,
                  `Create a networking challenge for "${eventInfo.title}" attendees to complete before the event starts.`,
                  `Ask what people are most looking forward to learning from specific speakers at "${eventInfo.title}".`
                );
              } else if (eventPhase === "ongoing") {
                basePrompts.push(
                  `Create a ${timeOfDayContext} poll about which session at "${eventInfo.title}" people are most excited to attend next.`,
                  `Generate an energetic message encouraging people to share their real-time insights from "${eventInfo.title}".`,
                  `Write a fun ${timeOfDayContext} networking prompt for people currently at "${eventInfo.title}" in ${eventInfo.location}.`,
                  `Ask about surprising discoveries or unexpected connections being made at "${eventInfo.title}".`,
                  `Create a mini-challenge related to ${eventInfo.category[0] || 'the event'} for attendees to complete during their ${timeOfDayContext} break.`
                );
              } else if (eventPhase === "concluded") {
                basePrompts.push(
                  `Ask about specific implementation plans for learnings from "${eventInfo.title}" - mention a speaker or session.`,
                  `Create a ${timeOfDayContext} reflection prompt about the most surprising insight from "${eventInfo.title}".`,
                  `Generate a fun "event aftermath" question about applying ${eventInfo.category[0] || 'event'} concepts.`,
                  `Ask who people connected with at "${eventInfo.title}" and what collaborations might emerge.`,
                  `Share a thought-provoking ${timeOfDayContext} question about the future of ${eventInfo.category[0] || 'the industry'} based on event discussions.`
                );
              }
            } else {
              // General group prompts
              basePrompts.push(
                `Create an engaging ${timeOfDayContext} conversation starter for the group "${chatData.group_name || 'discussion group'}".`,
                `Generate a fun "would you rather" question to spark discussion in this ${timeOfDayContext}.`,
                `Write a ${timeOfDayContext} message with an interesting fact or trivia to share with the group.`,
                `Ask the group about their current projects or what they're working on.`,
                `Create a mini-poll or fun question about ${timeOfDayContext === 'morning' ? 'how everyone is starting their day' : timeOfDayContext === 'afternoon' ? 'afternoon plans' : 'evening activities'}.`,
                `Share a motivational quote or thought perfect for this ${timeOfDayContext}.`,
                `Ask an engaging question about hobbies, interests, or weekend plans.`,
                `Create a word game, riddle, or brain teaser for the group to solve together.`
              );
            }
            
            // Filter out prompts that match already used styles
            return basePrompts.filter(prompt => {
              const promptLower = prompt.toLowerCase();
              if (usedMessageStyles.includes('poll') && promptLower.includes('poll')) return false;
              if (usedMessageStyles.includes('fact') && promptLower.includes('fact')) return false;
              if (usedMessageStyles.includes('challenge') && promptLower.includes('challenge')) return false;
              return true;
            });
          };

          // Add conversation-aware prompts if themes detected
          const conversationAwarePrompts = topThemes.length > 0 ? [
            eventInfo 
              ? `Build on the current ${timeOfDayContext} discussion about "${topThemes[0]}" with a related insight specific to "${eventInfo.title}".`
              : `Build on the current ${timeOfDayContext} discussion about "${topThemes[0]}" with a related insight or question.`,
            eventInfo
              ? `Acknowledge that people are discussing "${topThemes.join('", "')}" and add a fresh ${timeOfDayContext} perspective related to the event.`
              : `Acknowledge that people are discussing "${topThemes.join('", "')}" and add a fresh ${timeOfDayContext} perspective.`,
            mostActiveUser ? (eventInfo 
              ? `Thank ${mostActiveUser} for their active participation and ask a follow-up question about "${eventInfo.title}".`
              : `Thank ${mostActiveUser} for their active participation and ask a follow-up question to keep the conversation going.`) : null
          ].filter(Boolean) : [];

          const allPrompts = [...getPhaseAndTimeSpecificPrompts(), ...conversationAwarePrompts];
          const selectedUserPrompt = allPrompts[Math.floor(Math.random() * allPrompts.length)] || 
            (eventInfo 
              ? `Create a unique ${timeOfDayContext} message for "${eventInfo.title}" that references specific event details.`
              : `Create an engaging ${timeOfDayContext} message for the group to spark conversation.`);

          console.log(`Generating AI message for ${chatType} chat ${chatRef} (message ${previousAIMessagesToday.length + 1}/${reminderFrequency} today)`);

          // Generate engaging message using OpenAI
          const fetch = await import("node-fetch");
          const response = await fetch.default("https://api.openai.com/v1/chat/completions", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${openaiApiKey}`
            },
            body: JSON.stringify({
              model: "gpt-4o-mini",
              messages: [
                {
                  role: "system",
                  content: systemPrompt
                },
                {
                  role: "user",
                  content: selectedUserPrompt
                }
              ],
              max_tokens: 150,
              temperature: 0.9, // Higher for more creative/varied messages
              top_p: 0.95,
              frequency_penalty: 0.5, // Reduce repetitive patterns
              presence_penalty: 0.5
            })
          });

          if (!response.ok) {
            const error = await response.text();
            console.error(`OpenAI API error for chat ${chatRef}:`, error);
            return;
          }

          const aiResponse = await response.json();
          const aiMessage = aiResponse.choices[0].message.content;

          // Prepare message data
          const messageData = {
            sender_ref: aiBotUserRef,
            content: aiMessage,
            created_at: admin.firestore.FieldValue.serverTimestamp(),
            message_type: "text",
            sender_name: "Linkai AI",
            sender_photo: "https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2F67b27b2cda06e9c69e5d000615c1153f80b09576.png?alt=media&token=5caa8d82-6b67-4503-9258-d4732fb9c0bd",
            is_read_by: []
          };

          const chatUpdateData = {
            last_message: `Linkai AI: ${aiMessage.substring(0, 50)}...`,
            last_message_at: admin.firestore.FieldValue.serverTimestamp(),
            last_message_sent: aiBotUserRef,
            last_message_type: "text"
          };

          // Create message and update chat using batch
          const batch = firestore.batch();
          
          const messageRef = firestore.doc(chatRef).collection("messages").doc();
          batch.set(messageRef, messageData);
          batch.update(firestore.doc(chatRef), chatUpdateData);
          
          await batch.commit();
          
          console.log(`Successfully sent engagement message to chat: ${chatRef}`);
          
        } catch (error) {
          console.error(`Error processing chat ${chatDoc.ref.path}:`, error);
        }
      });

      // Process all chats with controlled concurrency
      const batchSize = 5;
      for (let i = 0; i < promises.length; i += batchSize) {
        await Promise.all(promises.slice(i, i + batchSize));
        // Add small delay between batches to avoid rate limiting
        if (i + batchSize < promises.length) {
          await new Promise(resolve => setTimeout(resolve, 1000));
        }
      }

      console.log(`Completed hourly group engagement check at hour ${currentHour}`);
      
    } catch (error) {
      console.error("Error in sendDailyEventEngagement:", error);
    }
  });

// ==========================================
// AI AGENT CLOUD FUNCTION (processAIMention)
// ==========================================
exports.processAIMention = functions
  .runWith({
    timeoutSeconds: 300,
    memory: "1GB",
    minInstances: 1,    // Keep 1 instance warm to avoid cold starts
    maxInstances: 10,   // Limit scaling to control costs
    vpcConnector: null, // No VPC needed for external API calls
    ingressSettings: "ALLOW_ALL",
  })
  .https.onCall(async (data, context) => {
    // Check authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }

    try {
      const { chatRef, messageContent, senderName } = data;
      
      if (!chatRef || !messageContent) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing required parameters"
        );
      }

      // Get chat document and event info in parallel for better performance
      const [chatDoc, openaiApiKey] = await Promise.all([
        firestore.doc(chatRef).get(),
        Promise.resolve(functions.config().openai?.key)
      ]);

      if (!chatDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Chat not found"
        );
      }

      if (!openaiApiKey) {
        throw new functions.https.HttpsError(
          "internal",
          "OpenAI API key not configured"
        );
      }

      const chatData = chatDoc.data();
      
      // Fetch event info and messages in parallel
      const [eventInfo, messagesSnapshot] = await Promise.all([
        // Get event information if available
        chatData.event_ref ? 
          chatData.event_ref.get().then(eventDoc => {
            if (eventDoc.exists) {
              const eventData = eventDoc.data();
              return {
                title: eventData.title || "",
                description: eventData.description || "",
                location: eventData.location || "",
                startDate: eventData.start_date ? eventData.start_date.toDate().toISOString() : "",
                endDate: eventData.end_date ? eventData.end_date.toDate().toISOString() : "",
                speakers: eventData.speakers || [],
                category: eventData.category || [],
                dateSchedule: eventData.dateSchedule || []
              };
            }
            return null;
          }) : Promise.resolve(null),
        
        // Get last 20 messages for context (increased from 10 for better context in non-event chats)
        firestore
          .doc(chatRef)
          .collection("messages")
          .orderBy("created_at", "desc")
          .limit(20)
          .get()
      ]);

      const recentMessages = [];
      messagesSnapshot.docs.forEach(doc => {
        const msgData = doc.data();
        recentMessages.push({
          sender: msgData.sender_name || "Unknown",
          content: msgData.content || "",
          timestamp: msgData.created_at ? msgData.created_at.toDate().toISOString() : ""
        });
      });

      // Reverse to get chronological order
      recentMessages.reverse();

      // Prepare context for OpenAI
      let systemPrompt = "You are Linkai, an AI assistant for the LinkedUp event networking app. ";
      
      if (eventInfo) {
        systemPrompt += "You help users with questions about events, schedules, speakers, and general event information. Be friendly, helpful, and concise in your responses.";
        systemPrompt += `\n\nCurrent Event Information:
Title: ${eventInfo.title}
Description: ${eventInfo.description}
Location: ${eventInfo.location}
Start Date: ${eventInfo.startDate}
End Date: ${eventInfo.endDate}
Categories: ${eventInfo.category.join(", ")}`;

        if (eventInfo.speakers && eventInfo.speakers.length > 0) {
          systemPrompt += "\n\nSpeakers:";
          eventInfo.speakers.forEach(speaker => {
            systemPrompt += `\n- ${speaker.name || "Unknown"}: ${speaker.bio || "No bio available"}`;
          });
        }

        if (eventInfo.dateSchedule && eventInfo.dateSchedule.length > 0) {
          systemPrompt += "\n\nSchedule:";
          eventInfo.dateSchedule.forEach(schedule => {
            systemPrompt += `\n- ${schedule.title || "Unknown"}: ${schedule.description || "No description"}`;
          });
        }
      } else {
        // Non-event group chat context
        systemPrompt += "You are participating in a general group chat. Be friendly, helpful, and engaging. You can discuss various topics, answer questions, and help facilitate conversations among group members. Be concise and natural in your responses.";
        
        // Add group chat info if available
        if (chatData.group_name) {
          systemPrompt += `\n\nGroup Chat: ${chatData.group_name}`;
        }
        if (chatData.description) {
          systemPrompt += `\nDescription: ${chatData.description}`;
        }
      }

      // Add recent messages context
      let conversationContext = "\n\nRecent conversation:";
      recentMessages.forEach(msg => {
        conversationContext += `\n${msg.sender}: ${msg.content}`;
      });

      // Clean the user's message (remove @linkai mention)
      const cleanedMessage = messageContent.replace(/@linkai/gi, "").trim();

      // Make OpenAI API call with optimized settings
      const fetch = await import("node-fetch");
      const response = await fetch.default("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${openaiApiKey}`
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",  // Using mini model for faster responses
          messages: [
            {
              role: "system",
              content: systemPrompt + conversationContext
            },
            {
              role: "user",
              content: `${senderName} asked: ${cleanedMessage}`
            }
          ],
          max_tokens: 300,      // Reduced for faster responses
          temperature: 0.7,
          top_p: 0.9,          // Added for better quality
          frequency_penalty: 0.3, // Reduce repetitive responses
          presence_penalty: 0.3   // Encourage diverse responses
        })
      });

      if (!response.ok) {
        const error = await response.text();
        console.error("OpenAI API error:", error);
        throw new functions.https.HttpsError(
          "internal",
          "Failed to get AI response"
        );
      }

      const aiResponse = await response.json();
      const aiMessage = aiResponse.choices[0].message.content;

      // Create AI bot user reference
      const aiBotUserRef = firestore.doc("users/ai_agent_linkai");

      // Prepare message data
      const messageData = {
        sender_ref: aiBotUserRef,
        sender_type: "ai", // This is the missing field!
        content: aiMessage,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        message_type: "text",
        sender_name: "Linkai AI",
        sender_photo: "https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2F67b27b2cda06e9c69e5d000615c1153f80b09576.png?alt=media&token=5caa8d82-6b67-4503-9258-d4732fb9c0bd",
        is_read_by: []
      };

      const chatUpdateData = {
        last_message: `Linkai AI: ${aiMessage.substring(0, 50)}...`,
        last_message_at: admin.firestore.FieldValue.serverTimestamp(),
        last_message_sent: aiBotUserRef,
        last_message_type: "text"
      };

      // Create message and update chat in parallel using batch for atomicity
      const batch = firestore.batch();
      
      const messageRef = firestore.doc(chatRef).collection("messages").doc();
      batch.set(messageRef, messageData);
      batch.update(firestore.doc(chatRef), chatUpdateData);
      
      await batch.commit();

      return {
        success: true,
        message: "AI response sent successfully",
        aiResponse: aiMessage
      };

    } catch (error) {
      console.error("Error in processAIMention:", error);
      
      // Return a more specific error based on the type
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError(
        "internal",
        error.message || "An error occurred processing the AI mention"
      );
    }
  });
