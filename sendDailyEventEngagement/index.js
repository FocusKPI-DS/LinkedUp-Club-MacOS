const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const crypto = require("crypto");

// Initialize Firebase Admin only once
admin.initializeApp();

// ==========================================
// EXISTING PUSH NOTIFICATION CONFIGURATION
// ==========================================
const kFcmTokensCollection = "fcm_tokens";
const kPushNotificationsCollection = "ff_push_notifications";
const kUserPushNotificationsCollection = "ff_user_push_notifications";
const firestore = admin.firestore();

const kPushNotificationRuntimeOpts = {
  timeoutSeconds: 540,
  memory: "2GB",
};

// ==========================================
// EVENTBRITE & BRANCH.IO CONFIGURATION
// ==========================================
// Branch.io configuration
const BRANCH_KEY = functions.config().branch?.key || process.env.BRANCH_KEY;
const BRANCH_API_URL = 'https://api2.branch.io/v1/url';

// ==========================================
// EXISTING PUSH NOTIFICATION FUNCTIONS
// ==========================================
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
            badge: 1, // This will add a badge to the app icon
            "mutable-content": 1, // Allow notification service extension to modify
            alert: {
              title: title,
              body: body,
            },
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
// EVENTBRITE AUTO SYNC FUNCTION
// ==========================================
exports.eventbriteAutoSync = functions.pubsub.schedule('every 30 minutes').onRun(async (context) => {
  console.log('Running EventBrite auto-sync...');
  
  try {
    // Get all users with auto-sync enabled
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .where('eventbrite_connected', '==', true)
      .where('eventbrite_auto_sync', '==', true)
      .get();
    
    console.log(`Found ${usersSnapshot.size} users with auto-sync enabled`);
    
    // Process each user
    const promises = usersSnapshot.docs.map(async (userDoc) => {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      try {
        await syncUserEvents(userId, userData);
      } catch (error) {
        console.error(`Error syncing events for user ${userId}:`, error);
      }
    });
    
    await Promise.all(promises);
    console.log('EventBrite auto-sync completed');
  } catch (error) {
    console.error('EventBrite auto-sync error:', error);
  }
  
  return null;
});

async function syncUserEvents(userId, userData) {
  const accessToken = userData.eventbrite_access_token;
  const eventbriteUserId = userData.eventbrite_user_id;
  
  if (!accessToken || !eventbriteUserId) {
    console.log(`Missing EventBrite credentials for user ${userId}`);
    return;
  }
  
  try {
    // Fetch user's events from EventBrite
    const response = await axios.get(
      `https://www.eventbriteapi.com/v3/users/${eventbriteUserId}/events/`,
      {
        headers: {
          'Authorization': `Bearer ${accessToken}`
        }
      }
    );
    
    const events = response.data.events || [];
    console.log(`Found ${events.length} events for user ${userId}`);
    
    // Check which events are not yet synced
    for (const event of events) {
      const eventbriteId = event.id;
      
      // Check if event already exists
      const existingEventQuery = await admin.firestore()
        .collection('events')
        .where('eventbrite_id', '==', eventbriteId)
        .limit(1)
        .get();
      
      if (existingEventQuery.empty) {
        // New event found, sync it
        console.log(`Syncing new event: ${event.name.text}`);
        await syncEventToFirestore(event, userId, accessToken);
      } else {
        // Event exists, check if it needs update
        const existingEvent = existingEventQuery.docs[0];
        const lastUpdated = existingEvent.data().last_updated?.toDate();
        const eventUpdated = new Date(event.changed);
        
        if (!lastUpdated || eventUpdated > lastUpdated) {
          console.log(`Updating existing event: ${event.name.text}`);
          await updateEventInFirestore(existingEvent.ref, event, accessToken);
        }
        
        // Check if event has QR code, generate if missing
        if (!existingEvent.data().qr_code_url) {
          const qrCodeUrl = await generateBranchLink(existingEvent.ref, event, userId);
          if (qrCodeUrl) {
            await existingEvent.ref.update({
              qr_code_url: qrCodeUrl
            });
            console.log(`Generated missing QR code for event: ${event.name.text}`);
          }
        }
      }
    }
    
    // Update user's last sync time
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({
        eventbrite_last_sync: admin.firestore.FieldValue.serverTimestamp()
      });
    
  } catch (error) {
    if (error.response?.status === 401) {
      // Token expired, disable auto-sync
      console.log(`Token expired for user ${userId}, disabling auto-sync`);
      await admin.firestore()
        .collection('users')
        .doc(userId)
        .update({
          eventbrite_auto_sync: false,
          eventbrite_token_expired: true
        });
    }
    throw error;
  }
}

async function syncEventToFirestore(eventData, userId, accessToken) {
  // Fetch venue data if available
  let venueData = null;
  if (eventData.venue_id) {
    try {
      const venueResponse = await axios.get(
        `https://www.eventbriteapi.com/v3/venues/${eventData.venue_id}/`,
        {
          headers: {
            'Authorization': `Bearer ${accessToken}`
          }
        }
      );
      venueData = venueResponse.data;
    } catch (error) {
      console.error('Error fetching venue:', error);
    }
  }
  
  const eventRef = await admin.firestore().collection('events').add({
    title: eventData.name.text || 'Untitled Event',
    description: eventData.description.text || '',
    location: venueData?.name || 'Online Event',
    latlng: venueData?.latitude && venueData?.longitude
      ? new admin.firestore.GeoPoint(
          parseFloat(venueData.latitude),
          parseFloat(venueData.longitude)
        )
      : null,
    start_date: new Date(eventData.start.utc),
    end_date: new Date(eventData.end.utc),
    creator_id: admin.firestore().collection('users').doc(userId),
    cover_image_url: eventData.logo?.url || '',
    is_private: false,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    is_trending: false,
    category: ['EventBrite Import'],
    event_id: `eventbrite_${eventData.id}`,
    price: eventData.is_free ? 0 : (eventData.minimum_ticket_price?.value || 0),
    ticket_deadline: eventData.sales_end 
      ? new Date(eventData.sales_end)
      : new Date(eventData.start.utc),
    ticket_amount: eventData.capacity || 0,
    eventbrite_id: eventData.id,
    eventbrite_url: eventData.url,
    use_eventbrite_ticketing: true,
    auto_synced: true,
    last_updated: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  // Update with self-reference
  await eventRef.update({
    event_ref: eventRef
  });
  
  // Generate QR code for the event
  const qrCodeUrl = await generateBranchLink(eventRef, eventData, userId);
  if (qrCodeUrl) {
    await eventRef.update({
      qr_code_url: qrCodeUrl
    });
    console.log(`Generated QR code for event: ${eventData.name.text}`);
  }
  
  // Create main chat group
  const chatGroupRef = await admin.firestore().collection('chats').add({
    group_name: eventData.name.text || 'Event Chat',
    description: `Main chat for ${eventData.name.text}`,
    is_public: true,
    event_ref: eventRef,
    admin_refs: [admin.firestore().collection('users').doc(userId)],
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    members: [admin.firestore().collection('users').doc(userId)],
    last_message_time: admin.firestore.FieldValue.serverTimestamp(),
    recent_messages: [],
  });
  
  // Update event with chat group
  await eventRef.update({
    main_group: chatGroupRef,
    chat_groups: [chatGroupRef],
    participants: [admin.firestore().collection('users').doc(userId)],
  });
  
  // Create participant record in subcollection (needed for QR code visibility)
  const participantQuery = await eventRef
    .collection('participant')
    .where('user_ref', '==', admin.firestore().collection('users').doc(userId))
    .limit(1)
    .get();
  
  if (participantQuery.empty) {
    // Get user data for participant record
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();
    
    const userData = userDoc.data() || {};
    
    // Create participant record
    await eventRef.collection('participant').add({
      user_id: userId,
      user_ref: admin.firestore().collection('users').doc(userId),
      name: userData.display_name || '',
      joined_at: admin.firestore.FieldValue.serverTimestamp(),
      status: 'joined',
      image: userData.photo_url || '',
      bio: userData.bio || '',
    });
    
    console.log('Created participant record for QR code visibility');
  }
}

async function updateEventInFirestore(eventRef, eventData, accessToken) {
  // Fetch venue data if needed
  let updateData = {
    title: eventData.name.text || 'Untitled Event',
    description: eventData.description.text || '',
    start_date: new Date(eventData.start.utc),
    end_date: new Date(eventData.end.utc),
    cover_image_url: eventData.logo?.url || '',
    price: eventData.is_free ? 0 : (eventData.minimum_ticket_price?.value || 0),
    ticket_deadline: eventData.sales_end 
      ? new Date(eventData.sales_end)
      : new Date(eventData.start.utc),
    ticket_amount: eventData.capacity || 0,
    eventbrite_url: eventData.url,
    last_updated: admin.firestore.FieldValue.serverTimestamp(),
  };
  
  if (eventData.venue_id) {
    try {
      const venueResponse = await axios.get(
        `https://www.eventbriteapi.com/v3/venues/${eventData.venue_id}/`,
        {
          headers: {
            'Authorization': `Bearer ${accessToken}`
          }
        }
      );
      const venueData = venueResponse.data;
      updateData.location = venueData.name || 'Online Event';
      if (venueData.latitude && venueData.longitude) {
        updateData.latlng = new admin.firestore.GeoPoint(
          parseFloat(venueData.latitude),
          parseFloat(venueData.longitude)
        );
      }
    } catch (error) {
      console.error('Error updating venue:', error);
    }
  }
  
  await eventRef.update(updateData);
}

async function generateBranchLink(eventRef, eventData, userId) {
  if (!BRANCH_KEY) {
    console.warn('Branch key not configured. Skipping QR code generation.');
    return null;
  }

  try {
    // Get user's invitation code
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();
    
    const userInvitationCode = userDoc.data()?.invitation_code || '';

    // Prepare Branch link data
    const branchData = {
      branch_key: BRANCH_KEY,
      alias: `event_${eventRef.id}_${Date.now()}`,
      type: 2, // Type 2 for marketing links
      data: {
        '$canonical_identifier': `eventDetail_${eventRef.path}`,
        '$og_title': 'LinkedUp Event Invite',
        '$og_description': `Join me at this ${eventData.name.text} event!`,
        '$marketing_title': 'LinkedUp Event Invite',
        'user_ref': userId,
        'event_id': eventRef.path,
        '$eventId': eventRef.path,
        '$inviteCode': userInvitationCode,
        '$deeplink_path': `eventDetail/${eventRef.id}`,
        '$invite_type': 'Event',
      },
      campaign: 'event_referral',
      channel: 'in_app',
      feature: 'invite',
      stage: 'event_page',
      tags: ['deeplink'],
    };

    // Generate the link
    const response = await axios.post(BRANCH_API_URL, branchData);
    
    if (response.data && response.data.url) {
      return response.data.url;
    }
    
    return null;
  } catch (error) {
    console.error('Error generating Branch link:', error);
    return null;
  }
}

// ==========================================
// EVENTBRITE OAUTH FUNCTION
// ==========================================
exports.eventbriteOAuth = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to connect EventBrite'
    );
  }

  const { userId, action, sessionId, code, state } = data;
  
  // Verify userId matches authenticated user
  if (userId !== context.auth.uid) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'User ID mismatch'
    );
  }
  
  // EventBrite OAuth credentials - store these in environment config
  const CLIENT_ID = functions.config().eventbrite?.client_id || 'YOUR_EVENTBRITE_CLIENT_ID';
  const CLIENT_SECRET = functions.config().eventbrite?.client_secret || 'YOUR_EVENTBRITE_CLIENT_SECRET';
  const REDIRECT_URI = functions.config().eventbrite?.redirect_uri || 'https://linkedup-c3e29.web.app/eventbrite-callback';
  
  try {
    if (action === 'initiate') {
      // Generate session ID and state for OAuth flow
      const newSessionId = admin.firestore().collection('sessions').doc().id;
      const newState = `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      
      // Store session with expiration
      await admin.firestore().collection('eventbrite_oauth_sessions').doc(newSessionId).set({
        userId: userId,
        state: newState,
        created: admin.firestore.FieldValue.serverTimestamp(),
        expires: new Date(Date.now() + 30 * 60 * 1000), // 30 minutes
        completed: false
      });
      
      // Build authorization URL
      const authUrl = `https://www.eventbrite.com/oauth/authorize?` +
        `response_type=code&` +
        `client_id=${CLIENT_ID}&` +
        `redirect_uri=${encodeURIComponent(REDIRECT_URI)}&` +
        `state=${newState}`;
      
      return { 
        success: true,
        authUrl, 
        sessionId: newSessionId 
      };
    }
    
    if (action === 'check') {
      // Check if OAuth flow is complete
      if (!sessionId) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Session ID is required'
        );
      }
      
      const sessionDoc = await admin.firestore()
        .collection('eventbrite_oauth_sessions')
        .doc(sessionId)
        .get();
      
      if (!sessionDoc.exists) {
        return { 
          completed: false,
          error: 'Session not found'
        };
      }
      
      const sessionData = sessionDoc.data();
      
      // Check if session expired
      if (sessionData.expires && sessionData.expires.toDate() < new Date()) {
        return {
          completed: true,
          success: false,
          error: 'Session expired'
        };
      }
      
      return {
        completed: sessionData.completed || false,
        success: sessionData.success || false,
        error: sessionData.error
      };
    }
    
    // Handle callback (this would be called by your web redirect handler)
    if (action === 'callback') {
      if (!code || !state) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Code and state are required for callback'
        );
      }
      
      // Find session by state
      const sessionsQuery = await admin.firestore()
        .collection('eventbrite_oauth_sessions')
        .where('state', '==', state)
        .where('completed', '==', false)
        .limit(1)
        .get();
      
      if (sessionsQuery.empty) {
        throw new functions.https.HttpsError(
          'not-found',
          'Invalid or expired session'
        );
      }
      
      const sessionDoc = sessionsQuery.docs[0];
      const sessionData = sessionDoc.data();
      
      // Verify session belongs to user
      if (sessionData.userId !== userId) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'Session does not belong to user'
        );
      }
      
      try {
        // Exchange code for token
        const tokenResponse = await axios.post(
          'https://www.eventbrite.com/oauth/token',
          new URLSearchParams({
            grant_type: 'authorization_code',
            client_id: CLIENT_ID,
            client_secret: CLIENT_SECRET,
            code: code,
            redirect_uri: REDIRECT_URI
          }),
          {
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded'
            }
          }
        );
        
        if (tokenResponse.data.access_token) {
          const accessToken = tokenResponse.data.access_token;
          const refreshToken = tokenResponse.data.refresh_token;
          
          // Get user information from EventBrite
          const userResponse = await axios.get(
            'https://www.eventbriteapi.com/v3/users/me/',
            {
              headers: {
                'Authorization': `Bearer ${accessToken}`
              }
            }
          );
          
          const eventbriteUserId = userResponse.data.id;
          const eventbriteUserName = userResponse.data.name;
          
          // Store tokens and user info
          await admin.firestore().collection('users').doc(userId).update({
            eventbrite_connected: true,
            eventbrite_access_token: accessToken,
            eventbrite_refresh_token: refreshToken,
            eventbrite_user_id: eventbriteUserId,
            eventbrite_user_name: eventbriteUserName,
            eventbrite_connected_at: admin.firestore.FieldValue.serverTimestamp()
          });
          
          // Update session as completed
          await sessionDoc.ref.update({
            completed: true,
            success: true,
            completed_at: admin.firestore.FieldValue.serverTimestamp()
          });
          
          // Set up webhook for auto-sync (optional)
          try {
            await setupEventbriteWebhook(eventbriteUserId, accessToken);
          } catch (webhookError) {
            console.error('Failed to set up webhook:', webhookError);
            // Continue anyway - webhook is optional
          }
          
          return { 
            success: true,
            message: 'EventBrite connected successfully'
          };
        } else {
          throw new Error('No access token received');
        }
      } catch (error) {
        console.error('Token exchange error:', error);
        
        // Update session with error
        await sessionDoc.ref.update({
          completed: true,
          success: false,
          error: error.message,
          completed_at: admin.firestore.FieldValue.serverTimestamp()
        });
        
        throw new functions.https.HttpsError(
          'internal',
          'Failed to complete OAuth flow: ' + error.message
        );
      }
    }
    
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid action specified'
    );
    
  } catch (error) {
    console.error('EventBrite OAuth error:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'An unexpected error occurred: ' + error.message
    );
  }
});

/**
 * Helper function to set up EventBrite webhook for auto-sync
 */
async function setupEventbriteWebhook(organizationId, accessToken) {
  try {
    const webhookUrl = `https://${process.env.GCLOUD_PROJECT}.cloudfunctions.net/eventbriteWebhook`;
    
    const response = await axios.post(
      `https://www.eventbriteapi.com/v3/organizations/${organizationId}/webhooks/`,
      {
        endpoint_url: webhookUrl,
        actions: [
          'event.created',
          'event.updated',
          'event.published',
          'event.unpublished'
        ]
      },
      {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        }
      }
    );
    
    console.log('Webhook created:', response.data.id);
    return response.data;
  } catch (error) {
    console.error('Webhook setup error:', error.response?.data || error.message);
    throw error;
  }
}

// ==========================================
// EVENTBRITE OAUTH CALLBACK FUNCTION
// ==========================================
exports.eventbriteOAuthCallback = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  
  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  
  // Only accept POST requests
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }
  
  try {
    const { code, state, userId } = req.body;
    
    if (!code || !state) {
      res.status(400).json({ error: 'Missing code or state parameter' });
      return;
    }
    
    // EventBrite OAuth credentials
    const CLIENT_ID = functions.config().eventbrite?.client_id || 'YOUR_EVENTBRITE_CLIENT_ID';
    const CLIENT_SECRET = functions.config().eventbrite?.client_secret || 'YOUR_EVENTBRITE_CLIENT_SECRET';
    const REDIRECT_URI = functions.config().eventbrite?.redirect_uri || 'https://linkedup-c3e29.web.app/eventbrite-callback.html';
    
    // Find the OAuth session by state
    const sessionsQuery = await admin.firestore()
      .collection('eventbrite_oauth_sessions')
      .where('state', '==', state)
      .where('completed', '==', false)
      .limit(1)
      .get();
    
    if (sessionsQuery.empty) {
      res.status(404).json({ error: 'Invalid or expired session' });
      return;
    }
    
    const sessionDoc = sessionsQuery.docs[0];
    const sessionData = sessionDoc.data();
    
    // If userId is provided, verify it matches the session
    if (userId && sessionData.userId !== userId) {
      res.status(403).json({ error: 'Session does not belong to user' });
      return;
    }
    
    // Use the userId from the session if not provided
    const actualUserId = userId || sessionData.userId;
    
    try {
      // Exchange authorization code for access token
      const tokenResponse = await axios.post(
        'https://www.eventbrite.com/oauth/token',
        new URLSearchParams({
          grant_type: 'authorization_code',
          client_id: CLIENT_ID,
          client_secret: CLIENT_SECRET,
          code: code,
          redirect_uri: REDIRECT_URI
        }),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
          }
        }
      );
      
      if (tokenResponse.data.access_token) {
        const accessToken = tokenResponse.data.access_token;
        const refreshToken = tokenResponse.data.refresh_token;
        
        // Get EventBrite user info
        const userResponse = await axios.get(
          'https://www.eventbriteapi.com/v3/users/me/',
          {
            headers: {
              'Authorization': `Bearer ${accessToken}`
            }
          }
        );
        
        const eventbriteUserId = userResponse.data.id;
        const eventbriteUserName = userResponse.data.name;
        
        // Update user document with EventBrite info
        const updateData = {
          eventbrite_connected: true,
          eventbrite_access_token: accessToken,
          eventbrite_user_id: eventbriteUserId,
          eventbrite_user_name: eventbriteUserName,
          eventbrite_connected_at: admin.firestore.FieldValue.serverTimestamp()
        };
        
        // Only add refresh_token if it exists
        if (refreshToken) {
          updateData.eventbrite_refresh_token = refreshToken;
        }
        
        await admin.firestore().collection('users').doc(actualUserId).update(updateData);
        
        // Mark session as completed
        await sessionDoc.ref.update({
          completed: true,
          success: true,
          completed_at: admin.firestore.FieldValue.serverTimestamp()
        });
        
        res.status(200).json({ 
          success: true, 
          message: 'EventBrite connected successfully',
          userId: actualUserId
        });
      } else {
        throw new Error('No access token received');
      }
    } catch (error) {
      console.error('Token exchange error:', error.response?.data || error);
      
      // Mark session as failed
      await sessionDoc.ref.update({
        completed: true,
        success: false,
        error: error.response?.data?.error_description || error.message,
        completed_at: admin.firestore.FieldValue.serverTimestamp()
      });
      
      res.status(400).json({ 
        error: 'Failed to exchange code for token',
        details: error.response?.data?.error_description || error.message
      });
    }
  } catch (error) {
    console.error('EventBrite OAuth callback error:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      message: error.message
    });
  }
});

// ==========================================
// EVENTBRITE WEBHOOK FUNCTION
// ==========================================
exports.eventbriteWebhook = functions.https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  
  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }
  
  try {
    // Verify webhook signature (if configured)
    const webhookSecret = functions.config().eventbrite?.webhook_secret;
    if (webhookSecret) {
      const signature = req.headers['x-eventbrite-signature'];
      const expectedSignature = crypto
        .createHmac('sha256', webhookSecret)
        .update(JSON.stringify(req.body))
        .digest('hex');
      
      if (signature !== expectedSignature) {
        console.error('Invalid webhook signature');
        res.status(401).send('Unauthorized');
        return;
      }
    }
    
    const { config, api_url } = req.body;
    const { action, webhook_id, user_id, endpoint_url } = config;
    
    console.log(`EventBrite webhook received: ${action}`);
    
    // Handle different webhook actions
    switch (action) {
      case 'attendee.updated':
      case 'attendee.checked_in':
      case 'attendee.checked_out':
        await handleAttendeeUpdate(api_url, action);
        break;
        
      case 'order.placed':
      case 'order.updated':
      case 'order.refunded':
        await handleOrderUpdate(api_url, action);
        break;
        
      case 'event.created':
      case 'event.updated':
      case 'event.published':
        await handleEventUpdate(api_url, action);
        break;
        
      default:
        console.log(`Unhandled webhook action: ${action}`);
    }
    
    res.status(200).send('OK');
  } catch (error) {
    console.error('EventBrite webhook error:', error);
    res.status(500).send('Internal server error');
  }
});

async function handleAttendeeUpdate(apiUrl, action) {
  try {
    // Extract attendee ID and event ID from the API URL
    // API URL format: https://www.eventbriteapi.com/v3/events/{event_id}/attendees/{attendee_id}/
    const urlParts = apiUrl.split('/');
    const attendeeId = urlParts[urlParts.length - 2];
    const eventId = urlParts[urlParts.length - 4];
    
    // Find the event in our database
    const eventQuery = await admin.firestore()
      .collection('events')
      .where('eventbrite_id', '==', eventId)
      .limit(1)
      .get();
    
    if (eventQuery.empty) {
      console.log(`Event not found for EventBrite ID: ${eventId}`);
      return;
    }
    
    const eventDoc = eventQuery.docs[0];
    
    // Find or create attendee record
    const attendeeQuery = await admin.firestore()
      .collection('event_attendees')
      .where('event_id', '==', eventDoc.id)
      .where('eventbrite_attendee_id', '==', attendeeId)
      .limit(1)
      .get();
    
    if (action === 'attendee.checked_in') {
      if (!attendeeQuery.empty) {
        await attendeeQuery.docs[0].ref.update({
          checked_in: true,
          checked_in_at: admin.firestore.FieldValue.serverTimestamp(),
          last_updated: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } else if (action === 'attendee.checked_out') {
      if (!attendeeQuery.empty) {
        await attendeeQuery.docs[0].ref.update({
          checked_in: false,
          checked_out_at: admin.firestore.FieldValue.serverTimestamp(),
          last_updated: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
    
    // Trigger a full sync for this event
    await eventDoc.ref.update({
      needs_attendee_sync: true,
      last_webhook_update: admin.firestore.FieldValue.serverTimestamp(),
    });
    
  } catch (error) {
    console.error('Error handling attendee update:', error);
  }
}

async function handleOrderUpdate(apiUrl, action) {
  try {
    // Extract order details from API URL
    const urlParts = apiUrl.split('/');
    const orderId = urlParts[urlParts.length - 2];
    
    // For new orders, we'll need to sync attendees
    if (action === 'order.placed') {
      // The order webhook doesn't give us the event ID directly
      // We'll need to mark all events for this user as needing sync
      console.log(`New order placed: ${orderId}`);
      // This would trigger a scheduled function to check for new attendees
    }
  } catch (error) {
    console.error('Error handling order update:', error);
  }
}

async function handleEventUpdate(apiUrl, action) {
  try {
    // Extract event ID from API URL
    const urlParts = apiUrl.split('/');
    const eventId = urlParts[urlParts.length - 2];
    
    // Find the event in our database
    const eventQuery = await admin.firestore()
      .collection('events')
      .where('eventbrite_id', '==', eventId)
      .limit(1)
      .get();
    
    if (!eventQuery.empty) {
      await eventQuery.docs[0].ref.update({
        needs_sync: true,
        last_webhook_update: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  } catch (error) {
    console.error('Error handling event update:', error);
  }
}

// ==========================================
// STRIPE CHECKOUT FUNCTION
// ==========================================
exports.createStripeCheckout = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to purchase tickets'
    );
  }

  const stripe = require('stripe')(functions.config().stripe?.secret_key || 'YOUR_STRIPE_SECRET_KEY');
  
  const {
    eventId,
    eventTitle,
    priceInCents,
    userId,
    userEmail,
    eventRef,
    eventType,
    eventCoverImage,
    eventDate
  } = data;

  try {
    // Create Stripe Checkout Session
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: 'usd',
            product_data: {
              name: `Ticket: ${eventTitle}`,
              description: `${eventType ? eventType.charAt(0).toUpperCase() + eventType.slice(1) : 'Event'} ticket for ${eventTitle}`,
              images: eventCoverImage ? [eventCoverImage] : [],
              metadata: {
                event_id: eventId,
                event_type: eventType || 'physical',
                event_date: eventDate || ''
              }
            },
            unit_amount: priceInCents, // Amount in cents
          },
          quantity: 1,
        },
      ],
      mode: 'payment',
      success_url: `${functions.config().app?.url || 'https://linkedup-c3e29.web.app'}/paymentSuccess/${eventId}?payment=success&sessionId={CHECKOUT_SESSION_ID}`,
      cancel_url: `${functions.config().app?.url || 'https://linkedup-c3e29.web.app'}/paymentSuccess/${eventId}?payment=cancelled`,
      customer_email: userEmail,
      client_reference_id: userId,
      metadata: {
        event_id: eventId,
        event_ref: eventRef,
        event_title: eventTitle,
        user_id: userId,
        event_type: eventType || 'physical'
      },
      // Enable invoice for receipts
      invoice_creation: {
        enabled: true,
      },
      // Customer data
      customer_creation: 'if_required',
      // Billing address collection
      billing_address_collection: 'required',
      // Phone number collection for physical events
      phone_number_collection: {
        enabled: eventType === 'physical' || eventType === 'hybrid'
      }
    });

    return {
      success: true,
      sessionId: session.id,
      checkoutUrl: session.url
    };
  } catch (error) {
    console.error('Stripe checkout error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to create checkout session',
      error.message
    );
  }
});

// ==========================================
// STRIPE WEBHOOK FUNCTION
// ==========================================
exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  const stripe = require('stripe')(functions.config().stripe?.secret_key || 'YOUR_STRIPE_SECRET_KEY');
  const endpointSecret = functions.config().stripe?.webhook_secret || 'YOUR_WEBHOOK_SECRET';

  let event;

  try {
    // Verify webhook signature
    const sig = req.headers['stripe-signature'];
    event = stripe.webhooks.constructEvent(req.rawBody, sig, endpointSecret);
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  // Handle the event
  try {
    switch (event.type) {
      case 'checkout.session.completed':
        await handleCheckoutSessionCompleted(event.data.object);
        break;
      
      case 'payment_intent.succeeded':
        await handlePaymentIntentSucceeded(event.data.object);
        break;
      
      case 'payment_intent.payment_failed':
        await handlePaymentFailed(event.data.object);
        break;
      
      case 'charge.refunded':
        await handleRefund(event.data.object);
        break;
      
      default:
        console.log(`Unhandled event type ${event.type}`);
    }

    res.json({received: true});
  } catch (error) {
    console.error('Webhook processing error:', error);
    res.status(500).send('Webhook processing failed');
  }
});

// Helper function to handle successful checkout
async function handleCheckoutSessionCompleted(session) {
  const { 
    client_reference_id: userId,
    customer_email: userEmail,
    amount_total: amount,
    payment_intent: paymentIntentId,
    metadata
  } = session;

  const {
    event_id: eventId,
    event_ref: eventRef,
    event_title: eventTitle,
    event_type: eventType
  } = metadata;

  try {
    // Get user reference
    const userRef = admin.firestore().doc(`users/${userId}`);
    const eventDocRef = admin.firestore().doc(eventRef);

    // Create payment history record
    const paymentHistoryRef = await admin.firestore().collection('payment_history').add({
      user_ref: userRef,
      event_ref: eventDocRef,
      event_id: eventId,
      event_title: eventTitle,
      amount: amount, // Amount in cents
      currency: 'USD',
      payment_method: 'stripe',
      payment_intent_id: paymentIntentId,
      status: 'completed',
      transaction_id: session.id,
      stripe_session_id: session.id,
      customer_email: userEmail,
      purchased_at: admin.firestore.FieldValue.serverTimestamp(),
      event_type: eventType || 'physical',
      receipt_url: session.url || ''
    });

    // Add user to event participants
    await eventDocRef.update({
      participants: admin.firestore.FieldValue.arrayUnion(userRef)
    });

    // Get user data for participant record
    const userDoc = await userRef.get();
    const userData = userDoc.data();

    // Create participant record
    await eventDocRef.collection('participant').add({
      user_ref: userRef,
      userId: userId,
      name: userData?.display_name || userData?.name || userEmail,
      image: userData?.photo_url || '',
      bio: userData?.bio || '',
      joined_at: admin.firestore.FieldValue.serverTimestamp(),
      status: 'joined',
      ticket_type: 'paid',
      payment_ref: paymentHistoryRef,
      ticket_price: amount
    });

    // Send confirmation email (optional)
    // You can add email sending logic here

    // Create notification for the user
    await userRef.collection('notifications').add({
      title: 'Ticket Purchase Confirmed',
      body: `Your ticket for ${eventTitle} has been confirmed!`,
      type: 'payment_success',
      event_ref: eventDocRef,
      event_id: eventId,
      payment_ref: paymentHistoryRef,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      read: false
    });

    console.log(`Payment completed for user ${userId} for event ${eventId}`);
  } catch (error) {
    console.error('Error processing successful payment:', error);
    throw error;
  }
}

// Helper function to handle payment intent success
async function handlePaymentIntentSucceeded(paymentIntent) {
  console.log('Payment intent succeeded:', paymentIntent.id);
  // Additional processing if needed
}

// Helper function to handle failed payments
async function handlePaymentFailed(paymentIntent) {
  console.log('Payment failed:', paymentIntent.id);
  
  // Update payment history status if exists
  const paymentHistorySnapshot = await admin.firestore()
    .collection('payment_history')
    .where('payment_intent_id', '==', paymentIntent.id)
    .limit(1)
    .get();
  
  if (!paymentHistorySnapshot.empty) {
    const doc = paymentHistorySnapshot.docs[0];
    await doc.ref.update({
      status: 'failed',
      failed_at: admin.firestore.FieldValue.serverTimestamp(),
      failure_reason: paymentIntent.last_payment_error?.message || 'Unknown error'
    });
  }
}

// Helper function to handle refunds
async function handleRefund(charge) {
  console.log('Refund processed:', charge.id);
  
  // Find and update payment history
  const paymentHistorySnapshot = await admin.firestore()
    .collection('payment_history')
    .where('payment_intent_id', '==', charge.payment_intent)
    .limit(1)
    .get();
  
  if (!paymentHistorySnapshot.empty) {
    const doc = paymentHistorySnapshot.docs[0];
    const paymentData = doc.data();
    
    await doc.ref.update({
      status: 'refunded',
      refunded_at: admin.firestore.FieldValue.serverTimestamp(),
      refund_amount: charge.amount_refunded
    });
    
    // Remove user from event participants if full refund
    if (charge.amount_refunded === charge.amount) {
      const eventRef = paymentData.event_ref;
      const userRef = paymentData.user_ref;
      
      if (eventRef && userRef) {
        await eventRef.update({
          participants: admin.firestore.FieldValue.arrayRemove(userRef)
        });
        
        // Remove participant record
        const participantSnapshot = await eventRef
          .collection('participant')
          .where('user_ref', '==', userRef)
          .limit(1)
          .get();
        
        if (!participantSnapshot.empty) {
          await participantSnapshot.docs[0].ref.delete();
        }
      }
    }
  }
}

// ==========================================
// EVENTBRITE SYNC NOW FUNCTION
// ==========================================
exports.eventbriteSyncNow = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to sync EventBrite'
    );
  }

  const { eventId, ticketingMode } = data;
  const userId = context.auth.uid;
  
  try {
    // Get user data to check EventBrite connection
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();
    
    if (!userDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'User not found'
      );
    }
    
    const userData = userDoc.data();
    
    if (!userData.eventbrite_connected) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'EventBrite not connected. Please connect your EventBrite account first.'
      );
    }
    
    const accessToken = userData.eventbrite_access_token;
    const eventbriteUserId = userData.eventbrite_user_id;
    
    if (!accessToken || !eventbriteUserId) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'EventBrite credentials missing. Please reconnect your EventBrite account.'
      );
    }
    
    // Find the event
    const eventDoc = await admin.firestore()
      .collection('events')
      .doc(eventId)
      .get();
    
    if (!eventDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Event not found'
      );
    }
    
    const eventData = eventDoc.data();
    
    // Update ticketing mode if provided
    if (typeof ticketingMode !== 'undefined') {
      await eventDoc.ref.update({
        use_eventbrite_ticketing: ticketingMode,
        last_updated: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    
    // If EventBrite event ID exists, sync attendees
    if (eventData.eventbrite_id) {
      try {
        // Fetch attendees from EventBrite
        const attendeesResponse = await axios.get(
          `https://www.eventbriteapi.com/v3/events/${eventData.eventbrite_id}/attendees/`,
          {
            headers: {
              'Authorization': `Bearer ${accessToken}`
            }
          }
        );
        
        const attendees = attendeesResponse.data.attendees || [];
        console.log(`Found ${attendees.length} attendees for event ${eventId}`);
        
        // Sync each attendee
        for (const attendee of attendees) {
          // Check if attendee exists as a LinkedUp user
          const email = attendee.profile?.email;
          if (email) {
            // Find user by email
            const userQuery = await admin.firestore()
              .collection('users')
              .where('email', '==', email)
              .limit(1)
              .get();
            
            if (!userQuery.empty) {
              const linkedUpUser = userQuery.docs[0];
              
              // Add to event participants if not already there
              const participantQuery = await eventDoc.ref
                .collection('participant')
                .where('user_ref', '==', linkedUpUser.ref)
                .limit(1)
                .get();
              
              if (participantQuery.empty) {
                const linkedUpUserData = linkedUpUser.data();
                await eventDoc.ref.collection('participant').add({
                  user_id: linkedUpUser.id,
                  user_ref: linkedUpUser.ref,
                  name: linkedUpUserData.display_name || attendee.profile.name || '',
                  joined_at: admin.firestore.FieldValue.serverTimestamp(),
                  status: 'joined',
                  image: linkedUpUserData.photo_url || '',
                  bio: linkedUpUserData.bio || '',
                  eventbrite_attendee_id: attendee.id,
                  checked_in: attendee.checked_in || false
                });
                
                // Also add to participants array in event document
                await eventDoc.ref.update({
                  participants: admin.firestore.FieldValue.arrayUnion(linkedUpUser.ref)
                });
              } else {
                // Update check-in status
                await participantQuery.docs[0].ref.update({
                  checked_in: attendee.checked_in || false,
                  eventbrite_attendee_id: attendee.id
                });
              }
            }
          }
        }
        
        // Update sync timestamp
        await eventDoc.ref.update({
          eventbrite_last_sync: admin.firestore.FieldValue.serverTimestamp(),
          needs_attendee_sync: false
        });
        
        return {
          success: true,
          message: `Successfully synced ${attendees.length} attendees`,
          attendeeCount: attendees.length,
          ticketingMode: ticketingMode !== undefined ? ticketingMode : eventData.use_eventbrite_ticketing
        };
        
      } catch (syncError) {
        console.error('Error syncing attendees:', syncError);
        
        if (syncError.response?.status === 401) {
          // Token expired
          await userDoc.ref.update({
            eventbrite_token_expired: true,
            eventbrite_auto_sync: false
          });
          
          throw new functions.https.HttpsError(
            'unauthenticated',
            'EventBrite token expired. Please reconnect your EventBrite account.'
          );
        }
        
        throw new functions.https.HttpsError(
          'internal',
          `Failed to sync attendees: ${syncError.message}`
        );
      }
    } else {
      // Just update ticketing mode if no EventBrite ID
      return {
        success: true,
        message: 'Ticketing mode updated successfully',
        attendeeCount: 0,
        ticketingMode: ticketingMode !== undefined ? ticketingMode : eventData.use_eventbrite_ticketing
      };
    }
    
  } catch (error) {
    console.error('EventBrite sync error:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      `An unexpected error occurred: ${error.message}`
    );
  }
});

// ==========================================
// CHAT FUNCTION
// ==========================================
const encodedAgentString = 'eyJzdGF0dXMiOiJMSVZFIiwiaWRlbnRpZmllciI6eyJuYW1lIjoiY2hhdCIsImtleSI6ImE3M3dwIn0sIm5hbWUiOiJDaGF0IiwiZGVzY3JpcHRpb24iOiJnZmRzYyIsImFpTW9kZWwiOnsicHJvdmlkZXIiOiJPUEVOQUkiLCJtb2RlbCI6ImdwdC00byIsInBhcmFtZXRlcnMiOnsidGVtcGVyYXR1cmUiOnsiaW5wdXRWYWx1ZSI6MX0sIm1heFRva2VucyI6eyJpbnB1dFZhbHVlIjoyMDQ4fSwidG9wUCI6eyJpbnB1dFZhbHVlIjoxfX0sIm1lc3NhZ2VzIjpbeyJyb2xlIjoiU1lTVEVNIiwidGV4dCI6ImFzZCJ9XX0sInJlcXVlc3RPcHRpb25zIjp7InJlcXVlc3RUeXBlcyI6WyJQTEFJTlRFWFQiXX0sInJlc3BvbnNlT3B0aW9ucyI6eyJyZXNwb25zZVR5cGUiOiJQTEFJTlRFWFQifX0=';

const agentString = Buffer.from(encodedAgentString, 'base64').toString('utf-8');

// Function to parse the agentString to a JSON object
function parseAgentString(agentString) {
  try {
    const agent = JSON.parse(agentString);
    return agent;
  } catch (error) {
    console.error("Error parsing agent JSON string:", error);
    return null;
  }
}

// Function to get the system message from ai model message array with response type instructions
function getSystemMessage(messages, responseType) {
  if (!messages || messages.length === 0) {
    return "";
  }

  const systemMessage = messages.find(msg => msg.role === "SYSTEM");
  let finalMessage = systemMessage ? systemMessage.text : "";

  // Add response format instructions
  switch (responseType) {
    case "PLAINTEXT":
      finalMessage += "\n Please provide your responses in plain text format only, without any special formatting or markdown.";
      break;
    case "MARKDOWN":
      finalMessage += "\n Please format your responses using markdown syntax for better readability.";
      break;
    case "JSON":
      finalMessage += "\nPlease provide your responses in valid JSON format.";
      break;
  }

  return finalMessage;
}

// Firebase Cloud Function to handle chat interactions
exports.chat = functions
  .runWith({ 
    minInstances: 0, 
    timeoutSeconds: 60,
    memory: '256MB'
  })
  .https.onCall(
  async (data, context) => {
    // Check authentication if required
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be authenticated to use this function"
      );
    }
    
    try {
      const { message, threadId, imageUrl, pdfUrl, messages, previousResponseId } = data;

      // Parse agentString to extract AI model params
      const agent = parseAgentString(agentString);

      // Check if parsing failed
      if (!agent) {
        throw new functions.https.HttpsError(
          "internal",
          "Error parsing agent configuration."
        );
      }

      const { OpenAI } = require("openai");

      // API key
      const OPENAI_API_KEY = '';

      function createOpenAIConfig(agent) {
        return {
          apiKey: OPENAI_API_KEY,
          maxRetries: 3,
          timeout: 30000,
        };
      }

      // Create OpenAI client
      const openaiClient = new OpenAI(createOpenAIConfig(agent));

      // Get system message for instructions
      const systemMessage = getSystemMessage(agent.aiModel.messages, agent.responseOptions.responseType);
      console.log('Using model:', agent.aiModel.model);
      console.log('Response type:', agent.responseOptions.responseType);

      // Prepare input content
      let inputContent = [];
      
      if (message && message.trim()) {
        inputContent.push({ type: "input_text", text: message });
      }
      
      if (imageUrl) {
        inputContent.push({ type: "input_image", image_url: imageUrl });
        console.log('Processing request with image');
      } else {
        console.log('Processing text-only request');
      }

      // Construct input array
      const input = [];
      
      // Add system message for JSON responses
      if (agent.responseOptions.responseType === 'JSON') {
        input.push({
          role: "system",
          content: systemMessage
        });
      }
      
      // Add user message
      input.push({
        role: "user",
        content: inputContent
      });

      // Create response using the Responses API
      console.log('Sending request to OpenAI...');
      const response = await openaiClient.responses.create({
        model: agent.aiModel.model,
        input: input,
        instructions: systemMessage,
        temperature: agent.aiModel.parameters.temperature.inputValue,
        top_p: agent.aiModel.parameters.topP.inputValue,
        max_output_tokens: agent.aiModel.parameters.maxTokens.inputValue,
        text: agent.responseOptions.responseType === 'JSON' 
          ? { format: {type: 'json_object' } } 
          : undefined,
        previous_response_id: previousResponseId
      });
      console.log('Received response from OpenAI');

      // Return formatted response with conversation tracking ID
      return {
        response: response.output_text,
        responseId: response.id,
      };

    } catch (error) {
      console.error("Error:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Error running assistant",
        {
          message: error.message || 'Unknown error',
          details: error.toString()
        }
      );
    }
  }
);

// ==========================================
// CLEANUP AND TOKEN REFRESH FUNCTIONS
// ==========================================
exports.cleanupExpiredSessions = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const now = new Date();
    const expiredSessions = await admin.firestore()
      .collection('eventbrite_oauth_sessions')
      .where('expires', '<', now)
      .get();
    
    const batch = admin.firestore().batch();
    expiredSessions.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log(`Cleaned up ${expiredSessions.size} expired sessions`);
});

exports.refreshEventbriteTokens = functions.pubsub
  .schedule('every 12 hours')
  .onRun(async (context) => {
    const CLIENT_ID = functions.config().eventbrite?.client_id;
    const CLIENT_SECRET = functions.config().eventbrite?.client_secret;
    
    if (!CLIENT_ID || !CLIENT_SECRET) {
      console.error('EventBrite credentials not configured');
      return;
    }
    
    // Get all users with EventBrite connections
    const usersWithEventbrite = await admin.firestore()
      .collection('users')
      .where('eventbrite_connected', '==', true)
      .get();
    
    const refreshPromises = usersWithEventbrite.docs.map(async (userDoc) => {
      const userData = userDoc.data();
      const refreshToken = userData.eventbrite_refresh_token;
      
      if (!refreshToken) {
        console.log(`No refresh token for user ${userDoc.id}`);
        return;
      }
      
      try {
        const response = await axios.post(
          'https://www.eventbrite.com/oauth/token',
          new URLSearchParams({
            grant_type: 'refresh_token',
            client_id: CLIENT_ID,
            client_secret: CLIENT_SECRET,
            refresh_token: refreshToken
          }),
          {
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded'
            }
          }
        );
        
        if (response.data.access_token) {
          await userDoc.ref.update({
            eventbrite_access_token: response.data.access_token,
            eventbrite_token_refreshed_at: admin.firestore.FieldValue.serverTimestamp()
          });
          console.log(`Refreshed token for user ${userDoc.id}`);
        }
      } catch (error) {
        console.error(`Failed to refresh token for user ${userDoc.id}:`, error.message);
        
        // If refresh fails, mark connection as invalid
        if (error.response?.status === 401) {
          await userDoc.ref.update({
            eventbrite_connected: false,
            eventbrite_connection_error: 'Token refresh failed - reconnection required'
          });
        }
      }
    });
    
    await Promise.all(refreshPromises);
    console.log(`Processed ${usersWithEventbrite.size} EventBrite connections`);
});

// ==========================================
// AI AGENT CLOUD FUNCTION
// ==========================================
exports.processAIMention = functions
  .runWith({
    timeoutSeconds: 300,
    memory: "1GB",
    minInstances: 1,    // Keep 1 instance warm to avoid cold starts
    maxInstances: 10,   // Limit scaling to control costs
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
          model: "gpt-4o-mini",  // Using mini model for faster responses
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
          max_tokens: 300,      // Reduced for faster responses
          temperature: 0.7,
          top_p: 0.9,          // Added for better quality
          frequency_penalty: 0.3, // Reduce repetitive responses
          presence_penalty: 0.3   // Encourage diverse responses
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
  });// ==========================================
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