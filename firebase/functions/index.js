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
  .runWith({
    timeoutSeconds: 300,  // Reduced from 540
    memory: "512MB",      // Reduced from 2GB for faster cold start
  })
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

// Trigger for emoji reaction notifications
exports.sendReactionNotificationTrigger = functions
  .runWith({
    timeoutSeconds: 60,
    memory: "256MB",
  })
  .firestore.document('chats/{chatId}/messages/{messageId}')
  .onUpdate(async (change, context) => {
    try {
      const beforeData = change.before.data();
      const afterData = change.after.data();
      
      // Check if reactions_by_user field changed
      const beforeReactions = beforeData.reactions_by_user || {};
      const afterReactions = afterData.reactions_by_user || {};
      
      // Find new reactions added
      const newReactions = {};
      for (const [userId, emojis] of Object.entries(afterReactions)) {
        const beforeEmojis = beforeReactions[userId] || [];
        const newEmojis = emojis.filter(emoji => !beforeEmojis.includes(emoji));
        if (newEmojis.length > 0) {
          newReactions[userId] = newEmojis;
        }
      }
      
      // If no new reactions, skip
      if (Object.keys(newReactions).length === 0) {
        return;
      }
      
      // Get message author info
      const messageAuthorRef = afterData.sender_ref;
      if (!messageAuthorRef) {
        console.log('No sender_ref found for message');
        return;
      }
      
      // Get chat info for workspace context
      const chatDoc = await firestore.doc(`chats/${context.params.chatId}`).get();
      if (!chatDoc.exists) {
        console.log('Chat document not found');
        return;
      }
      
      const chatData = chatDoc.data();
      const workspaceRef = chatData.workspace_ref;
      
      // Get workspace name
      let workspaceName = "Unknown Workspace";
      if (workspaceRef) {
        try {
          const workspaceDoc = await workspaceRef.get();
          if (workspaceDoc.exists) {
            workspaceName = workspaceDoc.data().name || workspaceDoc.data().title || "Unknown Workspace";
          }
        } catch (e) {
          console.log('Error getting workspace name:', e);
        }
      }
      
      // Send notification for each new reaction
      for (const [reactingUserId, emojis] of Object.entries(newReactions)) {
        // Don't notify the person who reacted
        if (reactingUserId === messageAuthorRef.id) {
          continue;
        }
        
        // Get reacting user's name
        let reactingUserName = "Someone";
        try {
          const reactingUserDoc = await firestore.doc(`users/${reactingUserId}`).get();
          if (reactingUserDoc.exists) {
            reactingUserName = reactingUserDoc.data().display_name || reactingUserDoc.data().name || "Someone";
          }
        } catch (e) {
          console.log('Error getting reacting user name:', e);
        }
        
        // Create notification for each emoji
        for (const emoji of emojis) {
          const notificationData = {
            notification_title: "New Reaction",
            notification_text: `${reactingUserName} reacted ${emoji} to your message`,
            notification_image_url: "",
            notification_sound: "default",
            user_refs: messageAuthorRef.path,
            initial_page_name: "ChatDetail",
            parameter_data: JSON.stringify({
              chatDoc: `chats/${context.params.chatId}`,
              workspaceName: workspaceName
            }),
            sender: firestore.doc(`users/${reactingUserId}`),
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          };
          
          // Add to notifications collection to trigger the existing notification system
          await firestore.collection(kUserPushNotificationsCollection).add(notificationData);
        }
      }
      
    } catch (e) {
      console.log(`Error in reaction notification trigger: ${e}`);
    }
  });

// Trigger for text message notifications
// COMMENTED OUT - Disabled to prevent duplicate notifications
// exports.sendMessageNotificationTrigger = functions
//   .runWith({
//     timeoutSeconds: 60,
//     memory: "256MB",
//   })
//   .firestore.document('chats/{chatId}/messages/{messageId}')
//   .onCreate(async (snapshot, context) => {
//     try {
//       const messageData = snapshot.data();
//       
//       // Only process text messages (not reactions)
//       if (messageData.message_type !== 'text' && messageData.content) {
//         return;
//       }
//       
//       const senderRef = messageData.sender_ref;
//       if (!senderRef) {
//         console.log('No sender_ref found for message');
//         return;
//       }
//       
//       // Get chat info for workspace context
//       const chatDoc = await firestore.doc(`chats/${context.params.chatId}`).get();
//       if (!chatDoc.exists) {
//         console.log('Chat document not found');
//         return;
//       }
//       
//       const chatData = chatDoc.data();
//       const workspaceRef = chatData.workspace_ref;
//       
//       // Get workspace name
//       let workspaceName = "Unknown Workspace";
//       if (workspaceRef) {
//         try {
//           const workspaceDoc = await workspaceRef.get();
//           if (workspaceDoc.exists) {
//             workspaceName = workspaceDoc.data().name || workspaceDoc.data().title || "Unknown Workspace";
//           }
//         } catch (e) {
//           console.log('Error getting workspace name:', e);
//         }
//       }
//       
//       // Get sender name
//       let senderName = "Someone";
//       try {
//         const senderDoc = await firestore.doc(`users/${senderRef.id}`).get();
//         if (senderDoc.exists) {
//           senderName = senderDoc.data().display_name || senderDoc.data().name || "Someone";
//         }
//       } catch (e) {
//         console.log('Error getting sender name:', e);
//       }
//       
//       // Get other chat members (exclude sender)
//       const members = chatData.members || [];
//       const otherMembers = members.filter(member => member.id !== senderRef.id);
//       
//       if (otherMembers.length === 0) {
//         console.log('No other members to notify');
//         return;
//       }
//       
//       // Create notification for each member
//       const notificationData = {
//         notification_title: workspaceName,
//         notification_text: `${senderName}: ${messageData.content || 'sent a message'}`,
//         notification_image_url: "",
//         notification_sound: "default",
//         user_refs: otherMembers.map(member => member.path).join(','),
//         initial_page_name: "ChatDetail",
//         parameter_data: JSON.stringify({
//           chatDoc: `chats/${context.params.chatId}`,
//           workspaceName: workspaceName
//         }),
//         sender: senderRef,
//         timestamp: admin.firestore.FieldValue.serverTimestamp(),
//       };
//       
//       await firestore.collection(kUserPushNotificationsCollection).add(notificationData);
//       console.log(`Message notification sent for workspace: ${workspaceName}`);
//       
//     } catch (e) {
//       console.log(`Error in message notification trigger: ${e}`);
//     }
//   });

async function sendPushNotifications(snapshot) {
  const notificationData = snapshot.data();
  const title = notificationData.notification_title || "";
  const body = notificationData.notification_text || "";
  const imageUrl = notificationData.notification_image_url || "";
  const sound = notificationData.notification_sound || "";
  const parameterData = notificationData.parameter_data || "";
  const targetAudience = notificationData.target_audience || "";
  const initialPageName = notificationData.initial_page_name || "";
  
  console.log("🔍 DEBUG: Original notification data:", {
    title,
    body,
    notification_title: notificationData.notification_title,
    notification_text: notificationData.notification_text,
    parameterData: parameterData,
    initialPageName: initialPageName
  });
  const userRefsStr = notificationData.user_refs || "";
  const batchIndex = notificationData.batch_index || 0;
  const numBatches = notificationData.num_batches || 0;
  const status = notificationData.status || "";

  // Add workspace context to notification text for chat messages and reactions
  let formattedBody = body;
  let formattedTitle = title;
  if (initialPageName === "ChatDetail" || initialPageName === "chatdetail") {
    // Extract workspace name from parameter data if available
    let workspaceName = "Unknown Workspace";
    try {
      const parsedData = JSON.parse(parameterData || "{}");
      console.log("🔍 DEBUG: Parsed parameter data:", JSON.stringify(parsedData));
      
      if (parsedData.workspaceName) {
        workspaceName = parsedData.workspaceName;
        console.log("🔍 DEBUG: Using workspaceName from parameter:", workspaceName);
      } else if (parsedData.workspace_ref) {
        console.log("🔍 DEBUG: Fetching workspace document for:", parsedData.workspace_ref);
        // Fetch workspace document to get the actual name
        try {
          const workspaceDoc = await firestore.doc(parsedData.workspace_ref).get();
          if (workspaceDoc.exists) {
            const workspaceData = workspaceDoc.data();
            workspaceName = workspaceData.name || workspaceData.title || "Unknown Workspace";
            console.log("🔍 DEBUG: Found workspace name:", workspaceName);
          } else {
            console.log("🔍 DEBUG: Workspace document does not exist");
          }
        } catch (e) {
          console.log('🔍 DEBUG: Error getting workspace name from document:', e);
          // Fallback to using the workspace ID
          workspaceName = parsedData.workspace_ref.split('/').pop() || "Unknown Workspace";
        }
      } else {
        console.log("🔍 DEBUG: No workspaceName or workspace_ref found in parameter data");
      }
    } catch (e) {
      console.log("🔍 DEBUG: Could not parse parameter data for workspace name:", e);
    }
    
    // Set title to workspace name and format body
    formattedTitle = workspaceName;
    formattedBody = body; // Keep original body without "Workspace:" prefix
  }

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
        const fcmToken = token.data().fcm_token;
        if (fcmToken && fcmToken.length > 0) {
          tokens.add(fcmToken);
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
      const fcmToken = data.fcm_token;
      if (audienceMatches && fcmToken && fcmToken.length > 0) {
        tokens.add(fcmToken);
      }
    });
  }

  const tokensArr = Array.from(tokens);
  var messageBatches = [];
  for (let i = 0; i < tokensArr.length; i += 500) {
    const tokensBatch = tokensArr.slice(i, Math.min(i + 500, tokensArr.length));
    const messages = {
      notification: {
        title: formattedTitle,
        body: formattedBody,
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
            alert: {
              title: formattedTitle,
              body: formattedBody,
            },
            sound: {
              name: 'Glass',
              critical: false,
              volume: 1.0
            },
            badge: 1,
            'mutable-content': 1,
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

// ==========================================
// DAILY EVENT ENGAGEMENT CLOUD FUNCTION
// ==========================================
// COMMENTED OUT - Function disabled to prevent automatic triggering
// exports.sendDailyEventEngagement = functions
//   .runWith({
//     timeoutSeconds: 540,
//     memory: "2GB",
//     maxInstances: 5,
//   })
//   .pubsub
//   .schedule("0 * * * *") // Runs every hour
//   .timeZone("America/Los_Angeles") // Set your preferred timezone
//   .onRun(async (context) => {
//     const currentHour = new Date().getHours();
//     console.log(`Starting hourly group engagement check at hour ${currentHour}`);
//     
//     try {
//       const openaiApiKey = functions.config().openai?.key;
//       
//       if (!openaiApiKey) {
//         console.error("OpenAI API key not configured");
//         return;
//       }

//       // Query all group chats (both event and non-event groups)
//       const groupChatsSnapshot = await firestore
//         .collection("chats")
//         .where("is_group", "==", true)
//         .get();

//       if (groupChatsSnapshot.empty) {
//         console.log("No group chats found");
//         return;
//       }

//       console.log(`Found ${groupChatsSnapshot.size} group chats`);

//       // Create AI bot user reference
//       const aiBotUserRef = firestore.doc("users/ai_agent_linkai");

//       // Process each chat
//       const promises = groupChatsSnapshot.docs.map(async (chatDoc) => {
//         try {
//           const chatData = chatDoc.data();
//           const chatRef = chatDoc.ref.path;
//           
//           // Get or set reminder_frequency
//           let reminderFrequency = chatData.reminder_frequency;
//           if (typeof reminderFrequency === 'undefined' || reminderFrequency === null) {
//             // Set default reminder_frequency to 1
//             reminderFrequency = 1;
//             await chatDoc.ref.update({ reminder_frequency: 1 });
//             console.log(`Set default reminder_frequency=1 for chat: ${chatRef}`);
//           }

//           // Calculate if we should send a message this hour
//           // Distribute messages evenly throughout the day (8 AM to 8 PM)
//           const startHour = 8;
//           const endHour = 20;
//           const availableHours = endHour - startHour;
//           
//           if (currentHour < startHour || currentHour >= endHour) {
//             // Outside of active hours
//             return;
//           }

//           // Calculate which hours this chat should receive messages
//           const hoursForThisChat = [];
//           if (reminderFrequency === 1) {
//             // Send at 9 AM for once-daily messages
//             hoursForThisChat.push(9);
//           } else {
//             // Distribute evenly across the day
//             const interval = Math.floor(availableHours / reminderFrequency);
//             for (let i = 0; i < reminderFrequency; i++) {
//               const hour = startHour + (i * interval);
//               if (hour < endHour) {
//                 hoursForThisChat.push(hour);
//               }
//             }
//           }

//           // Check if current hour is in the list
//           if (!hoursForThisChat.includes(currentHour)) {
//             return; // Skip this chat for this hour
//           }

//           const chatType = chatData.event_ref ? 'event' : 'general';
//           console.log(`Sending message to ${chatType} chat ${chatRef} (frequency: ${reminderFrequency}, hour: ${currentHour})`);
//           
//           // Skip if the chat has been inactive for more than 30 days
//           const lastMessageAt = chatData.last_message_at;
//           if (lastMessageAt) {
//             const daysSinceLastMessage = (Date.now() - lastMessageAt.toDate().getTime()) / (1000 * 60 * 60 * 24);
//             if (daysSinceLastMessage > 30) {
//               console.log(`Skipping inactive chat: ${chatRef}`);
//               return;
//             }
//           }

//           // Fetch event info (if available) and recent messages in parallel
//           const [eventInfo, messagesSnapshot] = await Promise.all([
//             chatData.event_ref 
//               ? chatData.event_ref.get().then(eventDoc => {
//                   if (eventDoc.exists) {
//                     const eventData = eventDoc.data();
//                     return {
//                       title: eventData.title || "",
//                       description: eventData.description || "",
//                       location: eventData.location || "",
//                       startDate: eventData.start_date ? eventData.start_date.toDate().toISOString() : "",
//                       endDate: eventData.end_date ? eventData.end_date.toDate().toISOString() : "",
//                       speakers: eventData.speakers || [],
//                       category: eventData.category || [],
//                       dateSchedule: eventData.dateSchedule || []
//                     };
//                   }
//                   return null;
//                 })
//               : Promise.resolve(null),
//             firestore
//               .doc(chatRef)
//               .collection("messages")
//               .orderBy("created_at", "desc")
//               .limit(20) // Get last 20 messages for better context
//               .get()
//           ]);

//           // Prepare recent messages context
//           const recentMessages = [];
//           messagesSnapshot.docs.forEach(doc => {
//             const msgData = doc.data();
//             // Skip AI messages to avoid self-referencing
//             if (msgData.sender_ref?.path !== "users/ai_agent_linkai") {
//               recentMessages.push({
//                 sender: msgData.sender_name || "Unknown",
//                 content: msgData.content || "",
//                 timestamp: msgData.created_at ? msgData.created_at.toDate().toISOString() : ""
//               });
//             }
//           });
//           recentMessages.reverse(); // Chronological order

//           // Calculate event timing context or set general context
//           const now = new Date();
//           let timingContext = "";
//           let eventPhase = "general"; // upcoming, ongoing, concluded, general
//           
//           if (eventInfo) {
//             const eventStart = eventInfo.startDate ? new Date(eventInfo.startDate) : null;
//             const eventEnd = eventInfo.endDate ? new Date(eventInfo.endDate) : null;
//             
//             if (eventStart && eventEnd) {
//               if (now < eventStart) {
//                 const daysUntil = Math.ceil((eventStart - now) / (1000 * 60 * 60 * 24));
//                 timingContext = `The event starts in ${daysUntil} days.`;
//                 eventPhase = "upcoming";
//               } else if (now >= eventStart && now <= eventEnd) {
//                 timingContext = "The event is currently ongoing!";
//                 eventPhase = "ongoing";
//               } else {
//                 timingContext = "The event has concluded.";
//                 eventPhase = "concluded";
//               }
//             }
//           } else {
//             // Non-event group context
//             timingContext = "This is a general discussion group.";
//             eventPhase = "general";
//           }

//           // Add time of day context for varied messages
//           let timeOfDayContext = "";
//           if (currentHour < 12) {
//             timeOfDayContext = "morning";
//           } else if (currentHour < 17) {
//             timeOfDayContext = "afternoon";
//           } else {
//             timeOfDayContext = "evening";
//           }

//           // Analyze recent conversation topics
//           let conversationThemes = [];
//           let mostActiveUser = null;
//           let userMessageCount = {};
//           
//           recentMessages.forEach(msg => {
//             // Count messages per user
//             userMessageCount[msg.sender] = (userMessageCount[msg.sender] || 0) + 1;
//             
//             // Extract themes from messages (simple keyword analysis)
//             const keywords = msg.content.toLowerCase().match(/\b\w{4,}\b/g) || [];
//             conversationThemes.push(...keywords);
//           });
//           
//           // Find most active user
//           if (Object.keys(userMessageCount).length > 0) {
//             mostActiveUser = Object.entries(userMessageCount).reduce((a, b) => a[1] > b[1] ? a : b)[0];
//           }
//           
//           // Get most common themes
//           const themeFrequency = {};
//           conversationThemes.forEach(theme => {
//             if (!['that', 'this', 'with', 'from', 'have', 'been', 'what', 'your', 'about'].includes(theme)) {
//               themeFrequency[theme] = (themeFrequency[theme] || 0) + 1;
//             }
//           });
//           const topThemes = Object.entries(themeFrequency)
//             .sort((a, b) => b[1] - a[1])
//             .slice(0, 3)
//             .map(([theme]) => theme);

//           // Check previous AI messages today to ensure variety
//           const todayStart = new Date();
//           todayStart.setHours(0, 0, 0, 0);
//           
//           const previousAIMessagesToday = messagesSnapshot.docs.filter(doc => {
//             const msgData = doc.data();
//             return msgData.sender_ref?.path === "users/ai_agent_linkai" && 
//                    msgData.created_at && 
//                    msgData.created_at.toDate() >= todayStart;
//           });

//           const usedMessageStyles = previousAIMessagesToday.map(doc => {
//             const content = doc.data().content.toLowerCase();
//             // Simple pattern matching to identify message types
//             if (content.includes('poll') || content.includes('would you rather')) return 'poll';
//             if (content.includes('did you know') || content.includes('fact')) return 'fact';
//             if (content.includes('challenge')) return 'challenge';
//             if (content.includes('tip')) return 'tip';
//             if (content.includes('quote')) return 'quote';
//             if (content.includes('who') && content.includes('?')) return 'question';
//             return 'general';
//           });

//           // Prepare system prompt for engaging message
//           let systemPrompt = `You are Linkai, an AI assistant for the LinkedUp networking app. Your primary goal is to foster active and meaningful engagement within this group chat by sending ONE proactive, thoughtful message. 

// Your Message Generation Process:
// -Analyze & Summarize: First, analyze the recentMessages. If there's an active discussion (more than ~5 recent messages), your message must begin with a concise, 1-2 sentence summary of the main topic. This demonstrates you are listening to the conversation. (e.g., "It sounds like there's a great discussion about Dr. Anya Sharma's keynote on AI ethics..." or "Loving the debate on the pros and cons of remote vs. hybrid work..."). If the chat is quiet, you can skip the summary and proceed to step 2.
// -Engage & Extend: Based on the conversation you just summarized (or the group's general purpose if the chat is quiet), craft a meaningful follow-up. Your goal is to extend the current topic, not pivot away from it. Ask a specific follow-up question, introduce a new angle, or connect two ideas from the discussion.
// -Add a "Hook": Conclude your message with an engaging hook that is directly related to the topic. This gives members an easy and interesting way to respond. Good hooks include a surprising piece of trivia, a relevant fun fact, or a quick poll.

// CRITICAL REQUIREMENTS:
// - Follow the 3-Step Process: Your message structure must follow the Analyze -> Engage -> Hook model described above.
// - If people have been discussing specific topics, acknowledge or build on them
// - Be aware that it's ${timeOfDayContext}
// - Vary Your Style: You MUST vary your message style and avoid generic greetings. Today you've already sent ${previousAIMessagesToday.length} messages with styles: ${usedMessageStyles.join(', ')}. AVOID repeating these.

// ${eventInfo ? `Event Context:
// - The event is ${eventPhase}
// - Use the Message Style Options below as inspiration for the "Engage & Extend" and "Hook" parts of your message.

// Message Style Options for Event Groups (prioritize unused styles):
// 1. Ask about a specific speaker or session by name
// 2. Share a fun fact or trivia related to the event's topic/category
// 3. Create a mini-poll or "would you rather" question about event topics
// 4. Highlight an upcoming session or speaker with enthusiasm
// 5. Share a networking tip specific to the event's industry/category
// 6. Ask about specific challenges in the event's field
// 7. Suggest a creative networking activity for attendees
// 8. Share an inspiring quote related to the event theme
// 9. Ask about implementation plans for learnings from specific sessions
// 10. Create a playful challenge or game related to the event topic
// 11. Share a ${timeOfDayContext} greeting with event-specific content
// 12. Suggest interesting resources or tools related to ${eventInfo.category[0] || 'the event'}`
// : `General Group Context:
// - This is a general discussion group without a specific event
// - Focus on facilitating engaging conversations
// - Be helpful and friendly

// Message Style Options for General Groups (prioritize unused styles):
// 1. Ask a follow-up question: Deepen the current discussion with a thoughtful question.
// 2. Share a related fun fact: Find a surprising fact related to the group's interests.
// 3. Create a mini-poll: Create a poll based on the current conversation.
// 4. Share a motivational quote: Find a quote that resonates with the group's goals.
// 5. Pose a challenge: Create a fun group challenge related to the discussion.
// 6. Share a ${timeOfDayContext} greeting with a conversation starter
// 7. Ask about people's interests or hobbies
// 8. Share tips or life hacks
// 9. Create a word game or riddle
// 10. Ask about current projects or goals
// 11. Start a discussion about trending topics`}

// ${recentMessages.length > 5 ? `\nCONVERSATION CONTEXT:
// - Most active participant: ${mostActiveUser || 'No clear leader'}
// - Topics being discussed: ${topThemes.join(', ') || 'General discussion'}
// - Consider acknowledging these themes or the active participants\n` : ''}

// Guidelines:
// - Keep messages concise (2-3 sentences max)
// - Phase: ${eventPhase} - ${timingContext}
// - Time of day: ${timeOfDayContext}
// - Be creative and unexpected - surprise and delight members
// - With ${reminderFrequency} messages per day, this is message ${previousAIMessagesToday.length + 1}
// ${eventInfo ? `- Reference specific names, topics, or details from below
// - Make it impossible to use this message for any other event

// Current Event Information:
// Title: ${eventInfo.title}
// Description: ${eventInfo.description}
// Location: ${eventInfo.location}
// ${timingContext}
// Categories: ${eventInfo.category.join(", ")}` 
// : `
// Group Information:
// Name: ${chatData.group_name || chatData.title || 'Discussion Group'}
// ${chatData.description ? `Description: ${chatData.description}` : ''}
// Members: ${chatData.members ? chatData.members.length : 'Unknown'} participants`}`;

//           if (eventInfo) {
//             if (eventInfo.speakers && eventInfo.speakers.length > 0) {
//               systemPrompt += "\n\nSpeakers (USE THESE NAMES):";
//               eventInfo.speakers.forEach(speaker => {
//                 systemPrompt += `\n- ${speaker.name || "Unknown"}: ${speaker.bio || "No bio available"}`;
//               });
//             }

//             if (eventInfo.dateSchedule && eventInfo.dateSchedule.length > 0) {
//               systemPrompt += "\n\nSchedule Sessions (REFERENCE THESE):";
//               eventInfo.dateSchedule.slice(0, 3).forEach(schedule => {
//                 systemPrompt += `\n- ${schedule.title || "Unknown"}: ${schedule.description || "No description"}`;
//               });
//             }
//           }

//           // Add conversation context if messages exist
//           if (recentMessages.length > 0) {
//             systemPrompt += "\n\nRecent messages (DO NOT repeat these topics directly):";
//             recentMessages.slice(-5).forEach(msg => {
//               systemPrompt += `\n${msg.sender}: ${msg.content.substring(0, 100)}...`;
//             });
//           }

//           // Create varied user prompts based on event phase, time, and conversation
//           const getPhaseAndTimeSpecificPrompts = () => {
//             const basePrompts = [];
//             
//             if (eventInfo) {
//               // Event-specific prompts
//               if (eventPhase === "upcoming") {
//                 basePrompts.push(
//                   `Create an exciting ${timeOfDayContext} countdown message for "${eventInfo.title}" that builds anticipation by mentioning a specific speaker or session.`,
//                   `Generate a fun icebreaker question for attendees who will be at "${eventInfo.title}" in ${eventInfo.location}.`,
//                   `Write a ${timeOfDayContext} message sharing a fascinating fact about ${eventInfo.category[0] || 'the event topic'} to get people excited for "${eventInfo.title}".`,
//                   `Create a networking challenge for "${eventInfo.title}" attendees to complete before the event starts.`,
//                   `Ask what people are most looking forward to learning from specific speakers at "${eventInfo.title}".`
//                 );
//               } else if (eventPhase === "ongoing") {
//                 basePrompts.push(
//                   `Create a ${timeOfDayContext} poll about which session at "${eventInfo.title}" people are most excited to attend next.`,
//                   `Generate an energetic message encouraging people to share their real-time insights from "${eventInfo.title}".`,
//                   `Write a fun ${timeOfDayContext} networking prompt for people currently at "${eventInfo.title}" in ${eventInfo.location}.`,
//                   `Ask about surprising discoveries or unexpected connections being made at "${eventInfo.title}".`,
//                   `Create a mini-challenge related to ${eventInfo.category[0] || 'the event'} for attendees to complete during their ${timeOfDayContext} break.`
//                 );
//               } else if (eventPhase === "concluded") {
//                 basePrompts.push(
//                   `Ask about specific implementation plans for learnings from "${eventInfo.title}" - mention a speaker or session.`,
//                   `Create a ${timeOfDayContext} reflection prompt about the most surprising insight from "${eventInfo.title}".`,
//                   `Generate a fun "event aftermath" question about applying ${eventInfo.category[0] || 'event'} concepts.`,
//                   `Ask who people connected with at "${eventInfo.title}" and what collaborations might emerge.`,
//                   `Share a thought-provoking ${timeOfDayContext} question about the future of ${eventInfo.category[0] || 'the industry'} based on event discussions.`
//                 );
//               }
//             } else {
//               // General group prompts
//               basePrompts.push(
//                 `Create an engaging ${timeOfDayContext} conversation starter for the group "${chatData.group_name || 'discussion group'}".`,
//                 `Generate a fun "would you rather" question to spark discussion in this ${timeOfDayContext}.`,
//                 `Write a ${timeOfDayContext} message with an interesting fact or trivia to share with the group.`,
//                 `Ask the group about their current projects or what they're working on.`,
//                 `Create a mini-poll or fun question about ${timeOfDayContext === 'morning' ? 'how everyone is starting their day' : timeOfDayContext === 'afternoon' ? 'afternoon plans' : 'evening activities'}.`,
//                 `Share a motivational quote or thought perfect for this ${timeOfDayContext}.`,
//                 `Ask an engaging question about hobbies, interests, or weekend plans.`,
//                 `Create a word game, riddle, or brain teaser for the group to solve together.`
//               );
//             }
//             
//             // Filter out prompts that match already used styles
//             return basePrompts.filter(prompt => {
//               const promptLower = prompt.toLowerCase();
//               if (usedMessageStyles.includes('poll') && promptLower.includes('poll')) return false;
//               if (usedMessageStyles.includes('fact') && promptLower.includes('fact')) return false;
//               if (usedMessageStyles.includes('challenge') && promptLower.includes('challenge')) return false;
//               return true;
//             });
//           };

//           // Add conversation-aware prompts if themes detected
//           const conversationAwarePrompts = topThemes.length > 0 ? [
//             eventInfo 
//               ? `Build on the current ${timeOfDayContext} discussion about "${topThemes[0]}" with a related insight specific to "${eventInfo.title}".`
//               : `Build on the current ${timeOfDayContext} discussion about "${topThemes[0]}" with a related insight or question.`,
//             eventInfo
//               ? `Acknowledge that people are discussing "${topThemes.join('", "')}" and add a fresh ${timeOfDayContext} perspective related to the event.`
//               : `Acknowledge that people are discussing "${topThemes.join('", "')}" and add a fresh ${timeOfDayContext} perspective.`,
//             mostActiveUser ? (eventInfo 
//               ? `Thank ${mostActiveUser} for their active participation and ask a follow-up question about "${eventInfo.title}".`
//               : `Thank ${mostActiveUser} for their active participation and ask a follow-up question to keep the conversation going.`) : null
//           ].filter(Boolean) : [];

//           const allPrompts = [...getPhaseAndTimeSpecificPrompts(), ...conversationAwarePrompts];
//           const selectedUserPrompt = allPrompts[Math.floor(Math.random() * allPrompts.length)] || 
//             (eventInfo 
//               ? `Create a unique ${timeOfDayContext} message for "${eventInfo.title}" that references specific event details.`
//               : `Create an engaging ${timeOfDayContext} message for the group to spark conversation.`);

//           console.log(`Generating AI message for ${chatType} chat ${chatRef} (message ${previousAIMessagesToday.length + 1}/${reminderFrequency} today)`);

//           // Generate engaging message using OpenAI
//           const fetch = await import("node-fetch");
//           const response = await fetch.default("https://api.openai.com/v1/chat/completions", {
//             method: "POST",
//             headers: {
//               "Content-Type": "application/json",
//               "Authorization": `Bearer ${openaiApiKey}`
//             },
//             body: JSON.stringify({
//               model: "gpt-4o-mini",
//               messages: [
//                 {
//                   role: "system",
//                   content: systemPrompt
//                 },
//                 {
//                   role: "user",
//                   content: selectedUserPrompt
//                 }
//               ],
//               max_tokens: 150,
//               temperature: 0.9, // Higher for more creative/varied messages
//               top_p: 0.95,
//               frequency_penalty: 0.5, // Reduce repetitive patterns
//               presence_penalty: 0.5
//             })
//           });

//           if (!response.ok) {
//             const error = await response.text();
//             console.error(`OpenAI API error for chat ${chatRef}:`, error);
//             return;
//           }

//           const aiResponse = await response.json();
//           const aiMessage = aiResponse.choices[0].message.content;

//           // Prepare message data
//           const messageData = {
//             sender_ref: aiBotUserRef,
//             content: aiMessage,
//             created_at: admin.firestore.FieldValue.serverTimestamp(),
//             message_type: "text",
//             sender_name: "Linkai AI",
//             sender_photo: "https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2F67b27b2cda06e9c69e5d000615c1153f80b09576.png?alt=media&token=5caa8d82-6b67-4503-9258-d4732fb9c0bd",
//             is_read_by: []
//           };

//           const chatUpdateData = {
//             last_message: `Linkai AI: ${aiMessage.substring(0, 50)}...`,
//             last_message_at: admin.firestore.FieldValue.serverTimestamp(),
//             last_message_sent: aiBotUserRef,
//             last_message_type: "text"
//           };

//           // Create message and update chat using batch
//           const batch = firestore.batch();
//           
//           const messageRef = firestore.doc(chatRef).collection("messages").doc();
//           batch.set(messageRef, messageData);
//           batch.update(firestore.doc(chatRef), chatUpdateData);
//           
//           await batch.commit();
//           
//           console.log(`Successfully sent engagement message to chat: ${chatRef}`);
//           
//         } catch (error) {
//           console.error(`Error processing chat ${chatDoc.ref.path}:`, error);
//         }
//       });

//       // Process all chats with controlled concurrency
//       const batchSize = 5;
//       for (let i = 0; i < promises.length; i += batchSize) {
//         await Promise.all(promises.slice(i, i + batchSize));
//         // Add small delay between batches to avoid rate limiting
//         if (i + batchSize < promises.length) {
//           await new Promise(resolve => setTimeout(resolve, 1000));
//         }
//       }

//       console.log(`Completed hourly group engagement check at hour ${currentHour}`);
//       
//     } catch (error) {
//       console.error("Error in sendDailyEventEngagement:", error);
//     }
//   });

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

// ==========================================
// DAILY SUMMARY CLOUD FUNCTION (SUMMERAI)
// ==========================================
exports.dailySummary = functions
  .runWith({
    timeoutSeconds: 300,
    memory: "1GB",
    minInstances: 0,
    maxInstances: 10,
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
      const { chatId } = data;
      
      if (!chatId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing required parameter: chatId"
        );
      }

      // Get chat document and verify permissions
      const chatDoc = await firestore.collection("chats").doc(chatId).get();
      
      if (!chatDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Chat not found"
        );
      }

      const chatData = chatDoc.data();
      const userId = context.auth.uid;

      // Verify user is a member of the chat
      if (!chatData.members || !chatData.members.some(memberRef => {
        // Handle both DocumentReference objects and string paths
        const memberPath = typeof memberRef === 'string' ? memberRef : memberRef.path;
        return memberPath.includes(userId);
      })) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "You do not have permission to trigger this summary."
        );
      }

      // Get OpenAI API key
      const openaiApiKey = functions.config().openai?.key;
      if (!openaiApiKey) {
        throw new functions.https.HttpsError(
          "internal",
          "OpenAI API key not configured"
        );
      }

      // Create SummerAI user reference
      const summerAiUserRef = firestore.doc("users/ai_agent_summerai");

      // Fetch messages from the last 24 hours
      const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

      const messagesSnapshot = await firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .where("created_at", ">=", twentyFourHoursAgo)
        .orderBy("created_at", "asc")
        .get();

      if (messagesSnapshot.empty) {
        // Create or get DM chat between SummerAI and the requesting user
        const requestingUserRef = firestore.doc(`users/${userId}`);
        
        // Check if DM already exists between SummerAI and the user
        const existingDMs = await firestore
          .collection("chats")
          .where("members", "array-contains", summerAiUserRef)
          .where("is_group", "==", false)
          .get();

        let dmChatRef = null;
        for (const dmDoc of existingDMs.docs) {
          const dmData = dmDoc.data();
          if (dmData.members && 
              dmData.members.length === 2 && 
              dmData.members.some(memberRef => {
                const memberPath = typeof memberRef === 'string' ? memberRef : memberRef.path;
                return memberPath.includes(userId);
              })) {
            dmChatRef = dmDoc.ref;
            break;
          }
        }

        // Create new DM if it doesn't exist
        if (!dmChatRef) {
          dmChatRef = firestore.collection("chats").doc();
          await dmChatRef.set({
            title: '', // Empty for direct chats
            is_group: false,
            created_by: summerAiUserRef,
            created_at: admin.firestore.FieldValue.serverTimestamp(),
            members: [summerAiUserRef, requestingUserRef],
            last_message: '',
            last_message_at: admin.firestore.FieldValue.serverTimestamp(),
            last_message_sent: summerAiUserRef,
            last_message_type: "text",
            last_message_seen: [summerAiUserRef],
            workspace_ref: chatData.workspace_ref || null,
          });
        }

        // Send DM saying no messages found
        const noMessagesData = {
          sender_ref: summerAiUserRef,
          sender_type: "ai",
          content: "📊 **Daily Summary**\n\nNo messages were found in the last 24 hours to summarize. The chat has been quiet today!",
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          message_type: "text",
          sender_name: "SummerAI",
          sender_photo: "https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120",
          is_read_by: []
        };

        await dmChatRef.collection("messages").add(noMessagesData);

        // Send push notification to the user
        try {
          await firestore.collection("ff_user_push_notifications").add({
            notification_title: "New Message",
            notification_text: "Summer has sent you a daily summary",
            notification_image_url: "https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120",
            notification_sound: "notification_sound.mp3",
            user_refs: requestingUserRef.path,
            initial_page_name: "Chat",
            parameter_data: JSON.stringify({
              chatDoc: dmChatRef.path
            }),
            sender: summerAiUserRef,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log("Push notification triggered for Summer DM (no messages)");
        } catch (notificationError) {
          console.error("Error sending push notification:", notificationError);
        }

        return { 
          success: true,
          message: "No messages found in the last 24 hours" 
        };
      }

      // Prepare messages for AI analysis - EXCLUDE AI messages to prevent feedback loop
      const recentMessages = messagesSnapshot.docs
        .map((doc) => {
          const msgData = doc.data();
          return {
            sender: msgData.sender_name || "Unknown",
            content: msgData.content || "",
            senderType: msgData.sender_type || "user",
          };
        })
        .filter((msg) => {
          // Filter out AI messages (SummerAI, Linkai AI, etc.)
          const isAIMessage = msg.senderType === "ai" || 
                            msg.sender === "SummerAI" || 
                            msg.sender === "Linkai AI" ||
                            msg.sender === "LonaAI";
          return !isAIMessage; // Only keep non-AI messages
        });

      // Check if we have any real user messages after filtering
      if (recentMessages.length === 0) {
        // Create or get DM chat between SummerAI and the requesting user
        const requestingUserRef = firestore.doc(`users/${userId}`);
        
        // Check if DM already exists between SummerAI and the user
        const existingDMs = await firestore
          .collection("chats")
          .where("members", "array-contains", summerAiUserRef)
          .where("is_group", "==", false)
          .get();

        let dmChatRef = null;
        for (const dmDoc of existingDMs.docs) {
          const dmData = dmDoc.data();
          if (dmData.members && 
              dmData.members.length === 2 && 
              dmData.members.some(memberRef => {
                const memberPath = typeof memberRef === 'string' ? memberRef : memberRef.path;
                return memberPath.includes(userId);
              })) {
            dmChatRef = dmDoc.ref;
            break;
          }
        }

        // Create new DM if it doesn't exist
        if (!dmChatRef) {
          dmChatRef = firestore.collection("chats").doc();
          await dmChatRef.set({
            title: '', // Empty for direct chats
            is_group: false,
            created_by: summerAiUserRef,
            created_at: admin.firestore.FieldValue.serverTimestamp(),
            members: [summerAiUserRef, requestingUserRef],
            last_message: '',
            last_message_at: admin.firestore.FieldValue.serverTimestamp(),
            last_message_sent: summerAiUserRef,
            last_message_type: "text",
            last_message_seen: [summerAiUserRef],
            workspace_ref: chatData.workspace_ref || null,
          });
        }

        // Send DM saying no user messages found
        const noUserMessagesData = {
          sender_ref: summerAiUserRef,
          sender_type: "ai",
          content: "📊 **Daily Summary**\n\nNo user messages were found in the last 24 hours. Only AI messages were posted during this time.",
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          message_type: "text",
          sender_name: "SummerAI",
          sender_photo: "https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120",
          is_read_by: []
        };

        await dmChatRef.collection("messages").add(noUserMessagesData);

        // Send push notification to the user
        try {
          await firestore.collection("ff_user_push_notifications").add({
            notification_title: "New Message",
            notification_text: "Summer has sent you a daily summary",
            notification_image_url: "https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120",
            notification_sound: "notification_sound.mp3",
            user_refs: requestingUserRef.path,
            initial_page_name: "Chat",
            parameter_data: JSON.stringify({
              chatDoc: dmChatRef.path
            }),
            sender: summerAiUserRef,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log("Push notification triggered for Summer DM (no user messages)");
        } catch (notificationError) {
          console.error("Error sending push notification:", notificationError);
        }

        return { 
          success: true,
          message: "No user messages found in the last 24 hours" 
        };
      }

      // Get event information if available
      let eventInfo = null;
      if (chatData.event_ref) {
        const eventDoc = await chatData.event_ref.get();
        if (eventDoc.exists) {
          const eventData = eventDoc.data();
          eventInfo = {
            title: eventData.title || "",
            description: eventData.description || "",
            location: eventData.location || "",
            startDate: eventData.start_date ? eventData.start_date.toDate().toISOString() : "",
            endDate: eventData.end_date ? eventData.end_date.toDate().toISOString() : "",
          };
        }
      }

      // Prepare previous summary context
      const lastSummary = chatData.last_summary || "None";
      const lastSummaryDate = chatData.last_summary_at
        ? chatData.last_summary_at.toDate().toLocaleDateString()
        : "N/A";

      // Format the current date (same day)
      const currentDate = new Date();
      const currentDateFormatted = currentDate.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      });

      // Build system prompt
      let systemPrompt = `You are SummerAI, an AI assistant for a networking app. Your role is to analyze a day's worth of group chat messages and generate a structured summary in bullet format.

**CRITICAL INSTRUCTIONS:**
1. **Analyze ONLY Real User Messages:** You will receive ONLY real user messages (AI messages have been filtered out). Do NOT make up topics, people, or content that isn't explicitly mentioned in the provided messages. Only summarize what was actually discussed by real users.

2. **Identify Multiple Topics:** This format should be used for ALL topics discussed. Identify multiple topics from the conversation, even if they seem unimportant. Give priorities accordingly:
   - **Technical topics:** High/Medium priority
   - **Non-technical topics:** Low/Medium priority
   - **Business/Professional topics:** Medium/High priority
   - **Casual/Social topics:** Low priority

3. **Summarize in Bullet Format:** Your output MUST follow this exact format for each topic:

> **Topic Name** (Priority: High/Medium/Low)
- **Details:** Brief description of what was discussed
- **Action Items:** Any tasks, decisions, or follow-ups identified (if none, write "None")
- **Involved People:** Names of members who participated most actively (ONLY use names that appear in the actual messages below)
- **SummerAI's Thoughts:** A 1-2 sentence personal insight or observation about the topic

4. **Be Comprehensive:** Cover all topics discussed, from technical discussions to casual conversations. Don't skip topics just because they seem minor.

5. **Previous Summary Note:** You last summarized on ${lastSummaryDate}. Try to connect today's summary to previous discussions if relevant.

6. **Start with Header:** Begin with "Summary for ` + (chatData.title || chatData.group_name || 'Group') + ` for ` + currentDateFormatted + `"

7. **No Additional Greeting:** After the header, go straight into the bullet format summary without any additional greetings.

**CONVERSATION CONTEXT:**`;

      if (eventInfo) {
        systemPrompt += `\n- The conversation happened in a group for the event titled "${eventInfo.title}".`;
        if (eventInfo.description) {
          systemPrompt += `\n- Event Description: ${eventInfo.description}`;
        }
      } else {
        systemPrompt += `\n- Group Name: ${chatData.title || chatData.group_name || 'Discussion Group'}`;
      }

      systemPrompt += `\n- Timeframe: Messages from the last 24 hours.
- Here are the messages from the last 24 hours for you to analyze:`;

      // Format messages for AI
      const messagesForAI = recentMessages.map(msg => `\n- ${msg.sender}: ${msg.content}`).join('');

      // Call OpenAI API using node-fetch (consistent with existing code)
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
              content: messagesForAI
            }
          ],
          max_tokens: 800,
          temperature: 0.7,
          top_p: 0.9,
          frequency_penalty: 0.3,
          presence_penalty: 0.3
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

      // Create or get DM chat between SummerAI and the requesting user
      const requestingUserRef = firestore.doc(`users/${userId}`);
      
      // Check if DM already exists between SummerAI and the user in the same workspace
      const existingDMs = await firestore
        .collection("chats")
        .where("members", "array-contains", summerAiUserRef)
        .where("is_group", "==", false)
        .where("workspace_ref", "==", chatData.workspace_ref)
        .get();

      let dmChatRef = null;
      for (const dmDoc of existingDMs.docs) {
        const dmData = dmDoc.data();
        if (dmData.members && 
            dmData.members.length === 2 && 
            dmData.members.some(memberRef => {
              const memberPath = typeof memberRef === 'string' ? memberRef : memberRef.path;
              return memberPath.includes(userId);
            })) {
          dmChatRef = dmDoc.ref;
          break;
        }
      }

      // Create new DM if it doesn't exist
      if (!dmChatRef) {
        dmChatRef = firestore.collection("chats").doc();
        await dmChatRef.set({
          title: '', // Empty for direct chats
          is_group: false,
          created_by: summerAiUserRef,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          members: [summerAiUserRef, requestingUserRef],
          last_message: '',
          last_message_at: admin.firestore.FieldValue.serverTimestamp(),
          last_message_sent: summerAiUserRef,
          last_message_type: "text",
          last_message_seen: [summerAiUserRef],
          workspace_ref: chatData.workspace_ref, // Use same workspace as group chat
        });
      }

      // Prepare message data for SummerAI DM
      const messageData = {
        sender_ref: summerAiUserRef,
        sender_type: "ai",
        content: aiMessage,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        message_type: "text",
        sender_name: "SummerAI",
        sender_photo: "https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120",
        is_read_by: []
      };

      const dmChatUpdateData = {
        last_message: `SummerAI: Daily Summary`,
        last_message_at: admin.firestore.FieldValue.serverTimestamp(),
        last_message_sent: summerAiUserRef,
        last_message_type: "text",
        last_summary: aiMessage,
        last_summary_at: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Create message in DM and update DM chat using batch for atomicity
      const batch = firestore.batch();
      
      const messageRef = dmChatRef.collection("messages").doc();
      batch.set(messageRef, messageData);
      batch.update(dmChatRef, dmChatUpdateData);
      
      await batch.commit();

      // Send push notification to the user
      try {
        await firestore.collection("ff_user_push_notifications").add({
          notification_title: "New Message",
          notification_text: "Summer has sent you a daily summary",
          notification_image_url: "https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120",
          notification_sound: "notification_sound.mp3",
          user_refs: requestingUserRef.path,
          initial_page_name: "Chat",
          parameter_data: JSON.stringify({
            chatDoc: dmChatRef.path
          }),
          sender: summerAiUserRef,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log("Push notification triggered for Summer DM");
      } catch (notificationError) {
        console.error("Error sending push notification:", notificationError);
        // Don't fail the whole operation if notification fails
      }

      return {
        success: true,
        message: "Daily summary generated and sent successfully",
        summaryPreview: aiMessage.substring(0, 100) + "..."
      };

    } catch (error) {
      console.error("Error in dailySummary:", error);
      
      // Return a more specific error based on the type
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError(
        "internal",
        error.message || "An error occurred generating the daily summary"
      );
    }
  });

// ==========================================
// IN-GROUP SUMMER CLOUD FUNCTION (SCHEDULED DAILY SUMMARY)
// ==========================================
exports.InGroupSummer = functions
  .runWith({
    timeoutSeconds: 300,
    memory: "1GB",
    minInstances: 0,
    maxInstances: 10,
  })
  .pubsub
  .schedule("0 9 * * *") // Runs daily at 9:00 AM EST
  .timeZone("America/New_York") // EST timezone
  .onRun(async (context) => {
    console.log('Starting scheduled daily group summary generation...');
    
    try {
      // Get OpenAI API key
      const openaiApiKey = functions.config().openai?.key;
      if (!openaiApiKey) {
        console.error("OpenAI API key not configured");
        return;
      }

      // Create SummerAI user reference
      const summerAiUserRef = firestore.doc("users/ai_agent_summerai");

      // Get all group chats
      const groupChatsSnapshot = await firestore
        .collection("chats")
        .where("is_group", "==", true)
        .get();

      if (groupChatsSnapshot.empty) {
        console.log("No group chats found for scheduled summary");
        return;
      }

      console.log(`Found ${groupChatsSnapshot.size} group chats for scheduled summary`);

      // Process each group chat
      const promises = groupChatsSnapshot.docs.map(async (chatDoc) => {
        try {
          const chatData = chatDoc.data();
          const chatId = chatDoc.id;
          const chatRef = chatDoc.ref.path;

          // Skip if chat has been inactive for more than 7 days
          const lastMessageAt = chatData.last_message_at;
          if (lastMessageAt) {
            const daysSinceLastMessage = (Date.now() - lastMessageAt.toDate().getTime()) / (1000 * 60 * 60 * 24);
            if (daysSinceLastMessage > 7) {
              console.log(`Skipping inactive chat: ${chatRef}`);
              return;
            }
          }

          // Fetch messages from the previous day (yesterday)
          const yesterday = new Date();
          yesterday.setDate(yesterday.getDate() - 1);
          yesterday.setHours(0, 0, 0, 0);
          
          const today = new Date();
          today.setHours(0, 0, 0, 0);

          const messagesSnapshot = await firestore
            .collection("chats")
            .doc(chatId)
            .collection("messages")
            .where("created_at", ">=", yesterday)
            .where("created_at", "<", today)
            .orderBy("created_at", "asc")
            .get();

          if (messagesSnapshot.empty) {
            console.log(`No messages found for yesterday in chat: ${chatRef}`);
            return;
          }

          // Prepare messages for AI analysis - EXCLUDE AI messages to prevent feedback loop
          const recentMessages = messagesSnapshot.docs
            .map((doc) => {
              const msgData = doc.data();
              return {
                sender: msgData.sender_name || "Unknown",
                content: msgData.content || "",
                senderType: msgData.sender_type || "user",
              };
            })
            .filter((msg) => {
              // Filter out AI messages (SummerAI, Linkai AI, etc.)
              const isAIMessage = msg.senderType === "ai" || 
                                msg.sender === "SummerAI" || 
                                msg.sender === "Linkai AI" ||
                                msg.sender === "LonaAI";
              return !isAIMessage; // Only keep non-AI messages
            });

          // Check if we have any real user messages after filtering
          if (recentMessages.length === 0) {
            console.log(`No user messages found for yesterday in chat: ${chatRef}`);
            return;
          }

          // Get event information if available
          let eventInfo = null;
          if (chatData.event_ref) {
            const eventDoc = await chatData.event_ref.get();
            if (eventDoc.exists) {
              const eventData = eventDoc.data();
              eventInfo = {
                title: eventData.title || "",
                description: eventData.description || "",
                location: eventData.location || "",
                startDate: eventData.start_date ? eventData.start_date.toDate().toISOString() : "",
                endDate: eventData.end_date ? eventData.end_date.toDate().toISOString() : "",
              };
            }
          }

          // Prepare previous summary context
          const lastSummary = chatData.last_summary || "None";
          const lastSummaryDate = chatData.last_summary_at
            ? chatData.last_summary_at.toDate().toLocaleDateString()
            : "N/A";

          // Format yesterday's date (previous day)
          const yesterdayFormatted = yesterday.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
          });

          // Build system prompt with bullet format
          let systemPrompt = `You are SummerAI, an AI assistant for a networking app. Your role is to analyze yesterday's group chat messages and generate a structured summary in bullet format.

**CRITICAL INSTRUCTIONS:**
1. **Analyze ONLY Real User Messages:** You will receive ONLY real user messages (AI messages have been filtered out). Do NOT make up topics, people, or content that isn't explicitly mentioned in the provided messages. Only summarize what was actually discussed by real users.

2. **Identify Multiple Topics:** This format should be used for ALL topics discussed. Identify multiple topics from the conversation, even if they seem unimportant. Give priorities accordingly:
   - **Technical topics:** High/Medium priority
   - **Non-technical topics:** Low/Medium priority
   - **Business/Professional topics:** Medium/High priority
   - **Casual/Social topics:** Low priority

3. **Summarize in Bullet Format:** Your output MUST follow this exact format for each topic:

> **Topic Name** (Priority: High/Medium/Low)
- **Details:** Brief description of what was discussed
- **Action Items:** Any tasks, decisions, or follow-ups identified (if none, write "None")
- **Involved People:** Names of members who participated most actively (ONLY use names that appear in the actual messages below)
- **SummerAI's Thoughts:** A 1-2 sentence personal insight or observation about the topic

4. **Be Comprehensive:** Cover all topics discussed, from technical discussions to casual conversations. Don't skip topics just because they seem minor.

5. **Previous Summary Note:** You last summarized on ${lastSummaryDate}. Try to connect today's summary to previous discussions if relevant.

6. **Start with Header:** Begin with "Summary for ` + (chatData.name || 'Group') + ` for ` + yesterdayFormatted + `"

7. **No Additional Greeting:** After the header, go straight into the bullet format summary without any additional greetings.

**CONVERSATION CONTEXT:**`;

          if (eventInfo) {
            systemPrompt += `\n- The conversation happened in a group for the event titled "${eventInfo.title}".`;
            if (eventInfo.description) {
              systemPrompt += `\n- Event Description: ${eventInfo.description}`;
            }
          } else {
            systemPrompt += `\n- Group Name: ${chatData.title || chatData.group_name || 'Discussion Group'}`;
          }

          systemPrompt += `\n- Timeframe: Messages from yesterday (${yesterday.toLocaleDateString()}).
- Here are the messages from yesterday for you to analyze:`;

          // Format messages for AI
          const messagesForAI = recentMessages.map(msg => `\n- ${msg.sender}: ${msg.content}`).join('');

          // Call OpenAI API using node-fetch (consistent with existing code)
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
                  content: messagesForAI
                }
              ],
              max_tokens: 800,
              temperature: 0.7,
              top_p: 0.9,
              frequency_penalty: 0.3,
              presence_penalty: 0.3
            })
          });

          if (!response.ok) {
            const error = await response.text();
            console.error(`OpenAI API error for chat ${chatRef}:`, error);
            return;
          }

          const aiResponse = await response.json();
          const aiMessage = aiResponse.choices[0].message.content;

          // Prepare message data for SummerAI
          const messageData = {
            sender_ref: summerAiUserRef,
            sender_type: "ai",
            content: aiMessage,
            created_at: admin.firestore.FieldValue.serverTimestamp(),
            message_type: "text",
            sender_name: "SummerAI",
            sender_photo: "https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120",
            is_read_by: []
          };

          const chatUpdateData = {
            last_message: `SummerAI: Daily Summary`,
            last_message_at: admin.firestore.FieldValue.serverTimestamp(),
            last_message_sent: summerAiUserRef,
            last_message_type: "text",
            last_summary: aiMessage,
            last_summary_at: admin.firestore.FieldValue.serverTimestamp(),
          };

          // Create message and update chat using batch for atomicity
          const batch = firestore.batch();
          
          const messageRef = firestore.doc(chatRef).collection("messages").doc();
          batch.set(messageRef, messageData);
          batch.update(firestore.doc(chatRef), chatUpdateData);
          
          await batch.commit();

          console.log(`Successfully sent scheduled daily summary to chat: ${chatRef}`);
          
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

      console.log('Completed scheduled daily group summary generation');
      
    } catch (error) {
      console.error("Error in InGroupSummer:", error);
    }
  });
