/**
 * Fireflies.ai integration – API key stored and used only on the server.
 * Clients never receive the key; transcripts are fetched via these callable functions.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

const firestore = admin.firestore();
const FIREFLIES_GRAPHQL = "https://api.fireflies.ai/graphql";
const FIRESTORE_COLLECTION = "fireflies_api_keys";
const FIREFLIES_TRANSCRIPTS_COLLECTION = "fireflies_transcripts";

function requireAuth(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Must be authenticated."
    );
  }
  return context.auth.uid;
}

async function getChatAndVerifyAdmin(firestore, chatId, uid) {
  const chatRef = firestore.collection("chats").doc(chatId);
  const chatSnap = await chatRef.get();
  if (!chatSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Chat not found.");
  }
  const data = chatSnap.data();
  const adminRef = data.admin;
  if (!adminRef || adminRef.id !== uid) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only the group admin can perform this action."
    );
  }
  return { chatRef, data };
}

async function getChatAndVerifyMember(firestore, chatId, uid) {
  const chatRef = firestore.collection("chats").doc(chatId);
  const chatSnap = await chatRef.get();
  if (!chatSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Chat not found.");
  }
  const data = chatSnap.data();
  const members = data.members || [];
  const isMember = members.some((ref) => ref && ref.id === uid);
  if (!isMember) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "You must be a member of this group."
    );
  }
  return { chatRef, data };
}

async function validateFirefliesKey(apiKey) {
  const response = await axios.post(
    FIREFLIES_GRAPHQL,
    {
      query: `query Transcripts($limit: Int) { transcripts(limit: $limit) { id title } }`,
      variables: { limit: 1 },
    },
    {
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      timeout: 10000,
      validateStatus: () => true,
    }
  );
  if (response.status !== 200) return false;
  const data = response.data;
  if (data.errors && data.errors.length) return false;
  return !!data.data;
}

async function fetchTranscriptsFromFireflies(apiKey, limit = 5, skip = 0) {
  const response = await axios.post(
    FIREFLIES_GRAPHQL,
    {
      query: `query Transcripts($limit: Int, $skip: Int) {
        transcripts(limit: $limit, skip: $skip) { id title date duration }
      }`,
      variables: { limit, skip },
    },
    {
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      timeout: 15000,
    }
  );
  const data = response.data;
  if (data.errors && data.errors.length) {
    throw new Error(data.errors[0].message || "Fireflies API error");
  }
  return data.data?.transcripts || [];
}

async function fetchTranscriptWithSummaryFromFireflies(apiKey, transcriptId) {
  const response = await axios.post(
    FIREFLIES_GRAPHQL,
    {
      query: `query Transcript($transcriptId: String!) {
        transcript(id: $transcriptId) {
          id
          title
          date
          duration
          dateString
          summary {
            action_items
            outline
            overview
            short_summary
            shorthand_bullet
            bullet_gist
            gist
            short_overview
            meeting_type
            topics_discussed
            transcript_chapters
          }
        }
      }`,
      variables: { transcriptId },
    },
    {
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      timeout: 15000,
    }
  );
  const data = response.data;
  if (data.errors && data.errors.length) {
    throw new Error(data.errors[0].message || "Fireflies API error");
  }
  const transcript = data.data?.transcript;
  if (!transcript) {
    throw new Error("Transcript not found");
  }
  return transcript;
}

function safeDocId(chatId, transcriptId) {
  const safe = (transcriptId || "").replace(/\//g, "_");
  return `${chatId}_${safe}`;
}

/**
 * Connect Fireflies for a group. Callable by group admin only.
 * Body: { chatId: string, apiKey: string }
 */
exports.firefliesConnect = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const { chatId, apiKey } = data || {};
  if (!chatId || typeof apiKey !== "string" || !apiKey.trim()) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "chatId and apiKey are required."
    );
  }
  const key = apiKey.trim();
  await getChatAndVerifyAdmin(firestore, chatId, uid);
  const valid = await validateFirefliesKey(key);
  if (!valid) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Invalid Fireflies API key."
    );
  }
  await firestore.collection(FIRESTORE_COLLECTION).doc(chatId).set({
    apiKey: key,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: uid,
  });
  return { success: true };
});

/**
 * Get transcripts for a group. Callable by any group member.
 * Body: { chatId: string, limit?: number, skip?: number }
 */
exports.firefliesGetTranscripts = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const chatId = data?.chatId;
  const limit = Math.min(Number(data?.limit) || 5, 50);
  const skip = Math.max(0, Number(data?.skip) || 0);
  if (!chatId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "chatId is required."
    );
  }
  await getChatAndVerifyMember(firestore, chatId, uid);
  const keySnap = await firestore.collection(FIRESTORE_COLLECTION).doc(chatId).get();
  if (!keySnap.exists) {
    return { transcripts: [], connected: false };
  }
  const apiKey = keySnap.data().apiKey;
  if (!apiKey) {
    return { transcripts: [], connected: false };
  }
  try {
    const transcripts = await fetchTranscriptsFromFireflies(apiKey, limit, skip);
    return { transcripts, connected: true };
  } catch (err) {
    console.error("Fireflies getTranscripts error:", err.message);
    throw new functions.https.HttpsError(
      "internal",
      err.message || "Failed to fetch transcripts."
    );
  }
});

/**
 * Disconnect Fireflies for a group. Callable by group admin only.
 * Body: { chatId: string }
 */
exports.firefliesDisconnect = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const chatId = data?.chatId;
  if (!chatId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "chatId is required."
    );
  }
  await getChatAndVerifyAdmin(firestore, chatId, uid);
  await firestore.collection(FIRESTORE_COLLECTION).doc(chatId).delete();
  return { success: true };
});

/**
 * Check if Fireflies is connected for a group. Callable by any group member.
 * Body: { chatId: string }
 */
exports.firefliesGetConnectionStatus = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const chatId = data?.chatId;
  if (!chatId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "chatId is required."
    );
  }
  await getChatAndVerifyMember(firestore, chatId, uid);
  const keySnap = await firestore.collection(FIRESTORE_COLLECTION).doc(chatId).get();
  return { connected: keySnap.exists && !!keySnap.data().apiKey };
});

/**
 * Fetch a single transcript (with summary, action items, etc.) from Fireflies and store in Firestore.
 * Callable by any group member.
 * Body: { chatId: string, transcriptId: string }
 */
exports.firefliesFetchAndStoreTranscript = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const chatId = data?.chatId;
  const transcriptId = data?.transcriptId;
  if (!chatId || !transcriptId || typeof transcriptId !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "chatId and transcriptId are required."
    );
  }
  await getChatAndVerifyMember(firestore, chatId, uid);
  const keySnap = await firestore.collection(FIRESTORE_COLLECTION).doc(chatId).get();
  if (!keySnap.exists || !keySnap.data().apiKey) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Fireflies is not connected for this group."
    );
  }
  const apiKey = keySnap.data().apiKey;
  const LONAAI_USER_REF = "users/ai_agent_lonaai";

  // Ensure LonaAI user document exists (for profile resolution, avatar, etc.)
  const lonaAiRef = firestore.doc(LONAAI_USER_REF);
  await lonaAiRef.set(
    {
      display_name: "LonaAI",
      email: "",
      photo_url: "",
      uid: "ai_agent_lonaai",
      created_time: admin.firestore.FieldValue.serverTimestamp(),
      bio: "Your intelligent meeting assistant. I share Fireflies transcript summaries and action items in the group.",
      is_onboarding: false,
      notifications_enabled: false,
      new_message_enabled: false,
      connection_requests_enabled: false,
    },
    { merge: true }
  );

  try {
    const transcript = await fetchTranscriptWithSummaryFromFireflies(apiKey, transcriptId);
    const docId = safeDocId(chatId, transcriptId);
    const summary = transcript.summary || {};
    const payload = {
      chatId,
      transcriptId: transcript.id,
      title: transcript.title || "Untitled",
      date: transcript.date ?? null,
      duration: transcript.duration ?? null,
      dateString: transcript.dateString ?? null,
      summary,
      fetchedAt: admin.firestore.FieldValue.serverTimestamp(),
      fetchedBy: uid,
    };
    await firestore.collection(FIREFLIES_TRANSCRIPTS_COLLECTION).doc(docId).set(payload);

    // Post a LonaAI message in the group chat with a summary card payload
    const chatRef = firestore.collection("chats").doc(chatId);
    // Fireflies returns action_items as a single string (namewise: " **Name** task1 (06:35) **Name2** ..."). Pass it through so the app can parse and show by-person.
    const actionItemsRaw = summary.action_items;
    const firefliesSummaryPayload = {
      title: payload.title,
      dateString: payload.dateString || null,
      duration: payload.duration ?? null,
      action_items: actionItemsRaw != null ? actionItemsRaw : [],
      overview: summary.overview || null,
      bullet_gist: summary.bullet_gist || null,
      short_summary: summary.short_summary || null,
      outline: summary.outline || null,
      topics_discussed: summary.topics_discussed || null,
    };
    const messageRef = await chatRef.collection("messages").add({
      content: `Meeting summary: ${payload.title}`,
      sender_ref: lonaAiRef,
      sender_name: "LonaAI",
      sender_photo: "",
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      message_type: "text",
      is_read_by: [],
      is_system_message: false,
      fireflies_summary: firefliesSummaryPayload,
    });
    await chatRef.update({
      last_message: `Meeting summary: ${payload.title}`,
      last_message_at: admin.firestore.FieldValue.serverTimestamp(),
      last_message_sent: lonaAiRef,
      last_message_type: "text",
    });

    return { success: true, transcript: payload };
  } catch (err) {
    console.error("Fireflies fetchAndStoreTranscript error:", err.message);
    throw new functions.https.HttpsError(
      "internal",
      err.message || "Failed to fetch and store transcript."
    );
  }
});
