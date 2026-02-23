/**
 * Manual transcript processing: read pasted transcription, use OpenAI to extract
 * summary, involved people, action items (with priority and start date), and
 * store in Firestore (manualTranscripts). Production-grade: robust prompt,
 * default dates to run date, aggressive deduplication.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const OpenAI = require("openai");

const firestore = admin.firestore();
const MANUAL_TRANSCRIPTS_COLLECTION = "manualTranscripts";
const LONAAI_USER_REF = "users/ai_agent_lonaai";
/** Max input length to avoid token limits and control cost. */
const MAX_TRANSCRIPT_LENGTH = 120000;

function requireAuth(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Must be authenticated."
    );
  }
  return context.auth.uid;
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

/** Normalize action item title for deduplication (same as TaskManagerAI). */
function normalizeTitle(t) {
  if (!t) return "";
  const normalized = (t + "")
    .toLowerCase()
    .replace(/\b(the|a|an|on|of|in|into|for|to|with|and|or|but)\b/gi, " ")
    .replace(/[\p{P}\p{S}]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
  const words = normalized.split(" ").filter((w) => w.length > 2);
  return words.sort().join(" ");
}

/**
 * Callable: process manual transcription text with OpenAI and store in manualTranscripts.
 * Body: { chatId: string, transcriptionText: string }
 */
exports.manualTranscriptProcess = functions
  .runWith({ timeoutSeconds: 120, memory: "512MB" })
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const chatId = data?.chatId;
    const transcriptionText =
      typeof data?.transcriptionText === "string"
        ? data.transcriptionText.trim()
        : "";

    if (!chatId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "chatId is required."
      );
    }
    if (!transcriptionText) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "transcriptionText is required."
      );
    }

    const { chatRef, data: chatData } = await getChatAndVerifyMember(
      firestore,
      chatId,
      uid
    );

    const openaiApiKey = functions.config().openai?.key;
    if (!openaiApiKey) {
      throw new functions.https.HttpsError(
        "internal",
        "OpenAI API key not configured."
      );
    }

    // Reference date = today (user's "run" date). Use for defaults when transcript has no date.
    const now = new Date();
    const referenceDateISO = now.toISOString().slice(0, 10); // YYYY-MM-DD

    const transcriptForApi =
      transcriptionText.length > MAX_TRANSCRIPT_LENGTH
        ? transcriptionText.slice(0, MAX_TRANSCRIPT_LENGTH) +
          "\n\n[Transcript truncated for length.]"
        : transcriptionText;

    const openai = new OpenAI({ apiKey: openaiApiKey });
    const groupName =
      chatData.title || chatData.group_name || chatData.name || "Meeting";

    // Compute due-date offsets from reference for the prompt (Urgent=+0, High=+1, Moderate=+2, Low=+3 days)
    const ref = new Date(referenceDateISO + "T12:00:00Z");
    const addDays = (d, n) => {
      const out = new Date(d);
      out.setUTCDate(out.getUTCDate() + n);
      return out.toISOString().slice(0, 10);
    };
    const dueUrgent = addDays(ref, 0);
    const dueHigh = addDays(ref, 1);
    const dueModerate = addDays(ref, 2);
    const dueLow = addDays(ref, 3);

    const systemPrompt = `You are a production-grade meeting analyst. You read raw meeting transcripts or notes and output a single JSON object. No commentary, no markdown—only valid JSON.

## Reference date
Today's date is ${referenceDateISO}. Use it for meeting_start_date when the transcript does not state a meeting date. For action item due dates, see "Due date by priority" below.

## Due date by priority (when the transcript does NOT give a specific date)
You MUST assign a due date to every action item. When the transcript does not explicitly mention a due date for an item, set start_date from the item's priority:
- Urgent → due SAME DAY → use ${referenceDateISO} (${dueUrgent})
- High → due NEXT DAY (24 hours) → use ${dueHigh}
- Moderate → due in 2 days → use ${dueModerate}
- Low → due in 3 days → use ${dueLow}
When the transcript DOES give a specific date (e.g. "by Thursday", "due Feb 21"), use that date in YYYY-MM-DD instead.

## Output contract
Return exactly this structure. No extra keys. No code fences.
{
  "summary": "2–4 sentence overview: what was discussed, key outcomes, and context. Be specific and factual.",
  "involved_people": ["Full Name 1", "Full Name 2"],
  "action_items": [
    {
      "title": "Verb-first, specific task (max 80 chars)",
      "priority": "Urgent" | "High" | "Moderate" | "Low",
      "description": "1–2 sentences: context and why it matters.",
      "involved_people": ["Name"],
      "start_date": "YYYY-MM-DD"
    }
  ],
  "meeting_start_date": "YYYY-MM-DD"
}

## Few-shot examples

Example 1 (today is ${referenceDateISO}):
Input: "Sarah said she'll send the copy by EOD. James will review the designs by tomorrow. Priya and Alex will integrate the API by end of week."
Output:
{
  "summary": "The team aligned on copy delivery (Sarah, EOD), design review (James, tomorrow), and API integration (Priya and Alex, end of week).",
  "involved_people": ["Sarah", "James", "Priya", "Alex"],
  "action_items": [
    { "title": "Send final copy to design", "priority": "Urgent", "description": "Sarah to deliver copy by EOD for onboarding flow.", "involved_people": ["Sarah"], "start_date": "${dueUrgent}" },
    { "title": "Review high-fidelity designs", "priority": "High", "description": "James to review designs by next day.", "involved_people": ["James"], "start_date": "${dueHigh}" },
    { "title": "Integrate dashboard API with front end", "priority": "Moderate", "description": "Priya and Alex to complete integration by end of week.", "involved_people": ["Priya", "Alex"], "start_date": "${dueModerate}" }
  ],
  "meeting_start_date": "${referenceDateISO}"
}

Example 2 (transcript gives explicit date):
Input: "We need staging access by Wednesday Feb 19. Auth merge by Thursday Feb 20."
Output:
{
  "summary": "Staging access is needed by Feb 19 and auth merge by Feb 20.",
  "involved_people": [],
  "action_items": [
    { "title": "Set up staging access", "priority": "High", "description": "Staging access required by Feb 19.", "involved_people": [], "start_date": "2025-02-19" },
    { "title": "Complete auth migration merge", "priority": "Urgent", "description": "Auth merge due Feb 20.", "involved_people": [], "start_date": "2025-02-20" }
  ],
  "meeting_start_date": "${referenceDateISO}"
}

## Rules
- meeting_start_date: If the transcript states a meeting date, use it in YYYY-MM-DD. Otherwise use ${referenceDateISO}.
- action_items[].start_date: If the transcript gives a date for that item, use it in YYYY-MM-DD. Otherwise derive from priority: Urgent=${dueUrgent}, High=${dueHigh}, Moderate=${dueModerate}, Low=${dueLow}. Never null.
- involved_people: Real names only (participants/speakers). Deduplicate (e.g. "John" and "John Smith" → one entry).
- Deduplication: Merge action items with the same or very similar intent into one. Prefer the more specific, actionable title.
- Priority: Urgent = same day / blocking; High = next day; Moderate = 2 days; Low = 3 days or nice-to-have. When unclear, use Moderate.
- If the transcript is empty or has no actionable content, return summary: "No substantive content to summarize.", involved_people: [], action_items: [], meeting_start_date: "${referenceDateISO}".
- Titles: Start with a verb. Be concrete.`;

    let parsed;
    try {
      const completion = await openai.chat.completions.create({
        model: "gpt-4",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: transcriptForApi },
        ],
        temperature: 0.2,
      });
      let responseContent =
        completion.choices[0]?.message?.content?.trim() ?? "{}";
      // Strip markdown code fence if present (model may wrap JSON in ```json ... ```)
      const jsonMatch = responseContent.match(/```(?:json)?\s*([\s\S]*?)```/);
      if (jsonMatch) responseContent = jsonMatch[1].trim();
      parsed = JSON.parse(responseContent);
    } catch (err) {
      console.error("Manual transcript OpenAI error:", err);
      throw new functions.https.HttpsError(
        "internal",
        err.message || "Failed to process transcription with AI."
      );
    }

    const summary =
      typeof parsed.summary === "string" ? parsed.summary.trim() : "";
    const involvedPeople = Array.isArray(parsed.involved_people)
      ? parsed.involved_people.filter((n) => typeof n === "string" && n.trim())
      : [];
    let actionItems = Array.isArray(parsed.action_items) ? parsed.action_items : [];

    // Default meeting_start_date to reference date when missing or invalid
    let meetingStartDate =
      typeof parsed.meeting_start_date === "string" &&
      /^\d{4}-\d{2}-\d{2}$/.test(parsed.meeting_start_date)
        ? parsed.meeting_start_date
        : referenceDateISO;

    // Client-side dedupe by normalized title (same run)
    const seenKeys = new Set();
    actionItems = actionItems.filter((item) => {
      const key = normalizeTitle(item.title || "");
      if (!key || seenKeys.has(key)) return false;
      seenKeys.add(key);
      return true;
    });

    // Optional: dedupe against recent manualTranscripts for this chat (last 7 days)
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const recentSnapshot = await firestore
      .collection(MANUAL_TRANSCRIPTS_COLLECTION)
      .where("chat_ref", "==", chatRef)
      .where("created_at", ">=", admin.firestore.Timestamp.fromDate(sevenDaysAgo))
      .get();

    const existingKeys = new Set();
    recentSnapshot.forEach((doc) => {
      const items = doc.data().action_items || [];
      items.forEach((i) => {
        const k = normalizeTitle(i.title || "");
        if (k) existingKeys.add(k);
      });
    });

    const dedupedActionItems = actionItems.filter((item) => {
      const key = normalizeTitle(item.title || "");
      return key && !existingKeys.has(key);
    });

    const VALID_PRIORITIES = new Set(["Urgent", "High", "Moderate", "Low"]);
    const payload = {
      chat_id: chatId,
      chat_ref: chatRef,
      raw_transcription: transcriptionText,
      summary,
      involved_people: involvedPeople,
      action_items: dedupedActionItems.map((item) => {
        const startDate =
          typeof item.start_date === "string" &&
          /^\d{4}-\d{2}-\d{2}$/.test(item.start_date)
            ? item.start_date
            : referenceDateISO;
        const priority = VALID_PRIORITIES.has(item.priority)
          ? item.priority
          : "Moderate";
        return {
          title: String(item.title || "").trim().slice(0, 200),
          priority,
          description: String(item.description || "").trim().slice(0, 1000),
          involved_people: Array.isArray(item.involved_people)
            ? item.involved_people.filter(
                (n) => typeof n === "string" && n.trim()
              )
            : [],
          start_date: startDate,
        };
      }),
      meeting_start_date: meetingStartDate,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      created_by: uid,
    };

    const manualTranscriptRef = firestore
      .collection(MANUAL_TRANSCRIPTS_COLLECTION)
      .doc();

    await Promise.all([
      manualTranscriptRef.set(payload),
      chatRef.update({
        manual_meeting_transcription: transcriptionText,
      }),
    ]);

    const lonaAiRef = firestore.doc(LONAAI_USER_REF);
    await lonaAiRef.set(
      {
        display_name: "LonaAI",
        email: "",
        photo_url: "",
        uid: "ai_agent_lonaai",
        created_time: admin.firestore.FieldValue.serverTimestamp(),
        bio: "Your intelligent meeting assistant. I share transcript summaries and action items in the group.",
        is_onboarding: false,
        notifications_enabled: false,
        new_message_enabled: false,
        connection_requests_enabled: false,
      },
      { merge: true }
    );

    // Build action items grouped by person (for manual transcript card: name → tasks with due date & priority)
    const personToTasks = new Map();
    for (const item of dedupedActionItems) {
      const people = Array.isArray(item.involved_people) && item.involved_people.length > 0
        ? item.involved_people
        : ["Unassigned"];
      const dueDate =
        typeof item.start_date === "string" && /^\d{4}-\d{2}-\d{2}$/.test(item.start_date)
          ? item.start_date
          : referenceDateISO;
      const taskEntry = {
        title: (item.title || "").trim().slice(0, 200),
        due_date: dueDate,
        priority: VALID_PRIORITIES.has(item.priority) ? item.priority : "Moderate",
      };
      for (const person of people) {
        const name = String(person).trim() || "Unassigned";
        if (!personToTasks.has(name)) personToTasks.set(name, []);
        personToTasks.get(name).push(taskEntry);
      }
    }
    const action_items_by_person = Array.from(personToTasks.entries())
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([person, tasks]) => ({ person, tasks }));

    const actionItemStrings = dedupedActionItems.map(
      (i) => i.title + (i.priority ? ` (${i.priority})` : "")
    );
    const firefliesSummaryPayload = {
      title: "Manual transcript",
      dateString: meetingStartDate,
      duration: null,
      action_items: actionItemStrings,
      action_items_by_person,
      overview: summary,
      bullet_gist: null,
      short_summary:
        summary.substring(0, 300) + (summary.length > 300 ? "…" : ""),
      outline: null,
      topics_discussed: null,
    };

    await chatRef.collection("messages").add({
      content: `Manual meeting summary: ${groupName}`,
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
      last_message: `Manual meeting summary: ${groupName}`,
      last_message_at: admin.firestore.FieldValue.serverTimestamp(),
      last_message_sent: lonaAiRef,
      last_message_type: "text",
    });

    return {
      success: true,
      manualTranscriptId: manualTranscriptRef.id,
      summary,
      involved_people: involvedPeople,
      action_items_count: dedupedActionItems.length,
    };
  });
