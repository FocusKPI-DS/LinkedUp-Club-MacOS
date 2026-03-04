/**
 * Task reminder Cloud Function: finds pending action items whose due date + priority-based
 * delay has passed (reminder sent 24h / 48h / 72h after due date, not after creation).
 * Sends a single reminder message from LonaAI into each group chat and push notifications.
 * Protected by X-Reminder-Secret header. All logic in this file; index.js only exports it.
 *
 * Safe testing: add ?dry_run=1 (or header X-Reminder-Dry-Run: true). Use ?ignore_delay=1
 * in dry run to treat all pending tasks with a due_date as remindable.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const firestore = admin.firestore();

/** Max tasks to process in a single run (avoids blasting thousands at once). */
const MAX_TASKS_PER_RUN = 50;

const LONA_AI_USER_REF = firestore.doc("users/ai_agent_lonaai");
const LONA_AI_PHOTO_URL = "https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fsoftware-agent.png?alt=media&token=99761584-999d-4f8e-b3d1-f9d1baf86120";

/** Hours after due date before sending reminder: Urgent=0h, High=24h, Moderate=48h, Low=72h. */
const PRIORITY_DELAY_HOURS = {
  Urgent: 0,
  High: 24,
  Moderate: 48,
  Low: 72,
};

function getDelayHours(priority) {
  const p = (priority || "Moderate").trim();
  return PRIORITY_DELAY_HOURS[p] ?? PRIORITY_DELAY_HOURS.Moderate;
}

/**
 * Resolve involved_people (display names) to user DocumentReferences using chat members.
 * Used to send push notifications to the right users (they open the group chat).
 */
async function resolveInvolvedPeopleToUserRefs(chatDocRef, involvedPeople) {
  if (!involvedPeople || involvedPeople.length === 0) return [];
  const chatDoc = await chatDocRef.get();
  if (!chatDoc.exists) return [];
  const members = chatDoc.data().members || [];
  if (members.length === 0) return [];

  const memberNames = [];
  const memberRefs = [];
  for (const memberRef of members) {
    try {
      const memberDoc = await memberRef.get();
      if (memberDoc.exists) {
        const d = memberDoc.data();
        const displayName = d.display_name || d.displayName || d.name;
        if (displayName && !displayName.includes("ai_agent") && !displayName.toLowerCase().includes("summer") && !displayName.toLowerCase().includes("lona")) {
          memberNames.push(displayName);
          memberRefs.push(memberRef);
        }
      }
    } catch (e) {
      console.warn("Error fetching member", memberRef.path, e);
    }
  }

  const userRefs = [];
  for (const nameFromTask of involvedPeople) {
    const idx = memberNames.findIndex((memberName) => {
      const mn = memberName;
      const n = nameFromTask;
      return (
        mn.toLowerCase() === n.toLowerCase() ||
        mn.toLowerCase().includes(n.toLowerCase()) ||
        n.toLowerCase().includes((mn.split(" ")[0] || "").toLowerCase())
      );
    });
    if (idx >= 0 && !userRefs.some(r => r.path === memberRefs[idx].path)) {
      userRefs.push(memberRefs[idx]);
    }
  }
  return userRefs;
}

/**
 * Send one reminder message into the group chat (from LonaAI), listing all overdue tasks.
 * Optionally send push notifications to involved users so they open this group chat.
 */
async function sendReminderToGroupChat(chatRef, tasks, groupName, workspaceRef) {
  if (!tasks || tasks.length === 0) return 0;

  const chatDoc = await chatRef.get();
  if (!chatDoc.exists) return 0;
  const isGroup = chatDoc.data().is_group === true;
  if (!isGroup) return 0;

  // Build a single message: each task with priority, title, description, involved people, and a nudge to complete & check off
  const priorityLabel = (p) => (p ? `**Priority:** ${p}` : "");
  const taskBlocks = tasks.map((t) => {
    const title = t.title || "Task";
    const desc = (t.description || "").trim();
    const priority = (t.priority || "Moderate").trim();
    const involved = (t.involved_people || []);
    const involvedStr = involved.length > 0
      ? involved.join(", ")
      : "Everyone";
    let block = `**Task:** ${title}`;
    if (priorityLabel(priority)) block += `\n${priorityLabel(priority)}`;
    if (desc) block += `\n${desc}`;
    block += `\n👤 **Involved:** ${involvedStr}. Please complete this and check it off in your Tasks list!`;
    return block;
  });
  const reminderContent = `📋 **Task reminders**\n\nThe following action items are still pending:\n\n${taskBlocks.join("\n\n---\n\n")}\n\nMake sure to mark items done when you’re finished.`;

  const taskRemindersPayload = {
    overdue_count: tasks.length,
    intro_text: `Several critical actions require immediate attention to keep the ${groupName} project on track.`,
    tasks: tasks.map((t) => ({
      title: t.title || "Task",
      priority: (t.priority || "Moderate").trim(),
      description: (t.description || "").trim(),
      involved_people: t.involved_people || [],
      due_date: t.due_date || null,
      created_time: t.created_time || null,
      action_item_ref: t.ref.path,
    })),
  };

  const messageData = {
    sender_ref: LONA_AI_USER_REF,
    sender_type: "ai",
    content: reminderContent,
    task_reminders: taskRemindersPayload,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    message_type: "text",
    sender_name: "LonaAI",
    sender_photo: LONA_AI_PHOTO_URL,
    is_read_by: [],
  };

  const batch = firestore.batch();
  const messageRef = chatRef.collection("messages").doc();
  batch.set(messageRef, messageData);
  batch.update(chatRef, {
    last_message: `LonaAI: Task reminder – ${tasks.length} pending`,
    last_message_at: admin.firestore.FieldValue.serverTimestamp(),
    last_message_sent: LONA_AI_USER_REF,
    last_message_type: "text",
  });
  await batch.commit();

  // Store digest in reminder_digests collection (same shape as action items display) so frontend can render from collection instead of message
  await firestore.collection("reminder_digests").add({
    chat_ref: chatRef,
    group_name: groupName,
    intro_text: taskRemindersPayload.intro_text,
    overdue_count: taskRemindersPayload.overdue_count,
    tasks: taskRemindersPayload.tasks,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Collect all involved user refs across these tasks (for push); each user gets at most one push for this group
  const allInvolved = [...new Set(tasks.flatMap((t) => t.involved_people || []))];
  const userRefs = await resolveInvolvedPeopleToUserRefs(chatRef, allInvolved);
  const chatPath = chatRef.path;

  for (const userRef of userRefs) {
    try {
      await firestore.collection("ff_user_push_notifications").add({
        notification_title: "Task reminder",
        notification_text: `Lona: ${groupName} – ${tasks.length} pending action item(s)`,
        notification_image_url: LONA_AI_PHOTO_URL,
        notification_sound: "notification_sound.mp3",
        user_refs: userRef.path,
        initial_page_name: "Chat",
        parameter_data: JSON.stringify({ chatDoc: chatPath }),
        sender: LONA_AI_USER_REF,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      console.warn("Push notification failed for", userRef.path, e);
    }
  }

  return tasks.length;
}

/**
 * HTTP Cloud Function: run task reminders.
 * Expects header X-Reminder-Secret to match functions.config().reminder?.secret (or env).
 */
exports.runTaskReminders = functions
  .runWith({ timeoutSeconds: 120, memory: "256MB" })
  .https.onRequest(async (req, res) => {
    console.log("🔔 runTaskReminders: invoked");
    const secret = req.get("X-Reminder-Secret") || req.query.secret;
    const expectedSecret = functions.config().reminder?.secret || process.env.REMINDER_SECRET;
    if (expectedSecret && secret !== expectedSecret) {
      res.status(403).json({ error: "Forbidden" });
      return;
    }

    const dryRun = req.query.dry_run === "1" || req.get("X-Reminder-Dry-Run") === "true";
    /** For dry run only: if 1, treat all pending tasks as overdue so you can test without waiting 24h+. */
    const ignoreDelay = dryRun && (req.query.ignore_delay === "1" || req.get("X-Reminder-Ignore-Delay") === "true");

    try {
      const now = admin.firestore.Timestamp.now();
      const nowMs = now.toMillis();
      const snapshot = await firestore
        .collection("action_items")
        .where("status", "==", "pending")
        .get();

      const toRemind = [];
      const dryRunStats = dryRun ? { total_pending: snapshot.docs.length, no_due_date: 0, has_last_reminder: 0, not_yet_past_due_plus_delay: 0, overdue: 0 } : null;

      for (const doc of snapshot.docs) {
        const d = doc.data();
        const dueDate = d.due_date;
        if (!dueDate) {
          if (dryRunStats) dryRunStats.no_due_date++;
          continue;
        }
        if (d.last_reminder_at) {
          if (dryRunStats) dryRunStats.has_last_reminder++;
          continue;
        }
        const priority = d.priority || "Moderate";
        const delayHours = getDelayHours(priority);
        const dueDateMs = dueDate.toMillis ? dueDate.toMillis() : (dueDate._seconds || 0) * 1000;
        const remindAfterMs = dueDateMs + delayHours * 60 * 60 * 1000;
        const isPastDuePlusDelay = nowMs >= remindAfterMs;
        if (dryRunStats) {
          if (isPastDuePlusDelay || ignoreDelay) dryRunStats.overdue++;
          else dryRunStats.not_yet_past_due_plus_delay++;
        }
        if (isPastDuePlusDelay || ignoreDelay) {
          toRemind.push({
            ref: doc.ref,
            chat_ref: d.chat_ref,
            workspace_ref: d.workspace_ref || null,
            group_name: d.group_name || "Group",
            title: d.title || "Task",
            description: d.description || "",
            priority,
            involved_people: d.involved_people || [],
            due_date: dueDate,
            created_time: d.created_time || null,
          });
        }
      }

      // Group overdue tasks by group chat (chat_ref)
      const byChat = new Map();
      for (const task of toRemind) {
        if (!task.chat_ref) continue;
        const key = task.chat_ref.path || (typeof task.chat_ref === "string" ? task.chat_ref : task.chat_ref.id);
        if (!byChat.has(key)) byChat.set(key, []);
        byChat.get(key).push(task);
      }

      // Cap total tasks per run so one invocation never blasts thousands
      let totalCapped = 0;
      const byChatCapped = new Map();
      for (const [k, tasks] of byChat) {
        if (totalCapped >= MAX_TASKS_PER_RUN) break;
        const remaining = MAX_TASKS_PER_RUN - totalCapped;
        const take = Math.min(tasks.length, remaining);
        if (take > 0) {
          byChatCapped.set(k, tasks.slice(0, take));
          totalCapped += take;
        }
      }

      if (dryRun) {
        const wouldSend = [...byChatCapped.values()].reduce((s, t) => s + t.length, 0);
        const payload = {
          dry_run: true,
          would_send: wouldSend,
          chats_affected: byChatCapped.size,
          total_overdue_skipped: toRemind.length - totalCapped,
        };
        if (dryRunStats) {
          payload.diagnostics = dryRunStats;
          payload.message = dryRunStats.total_pending === 0
            ? "No pending action_items in Firestore (status=pending)."
            : wouldSend === 0
              ? `Found ${dryRunStats.total_pending} pending task(s). None past due date + delay yet (High=24h, Moderate=48h, Low=72h after due date). Use ?ignore_delay=1 to test.`
              : `Would send ${wouldSend} reminder(s) to ${byChatCapped.size} chat(s).`;
        }
        if (ignoreDelay) payload.ignore_delay = true;
        return res.status(200).json(payload);
      }

      let remindersSent = 0;
      for (const [, tasks] of byChatCapped) {
        if (tasks.length === 0) continue;
        const chatRef = tasks[0].chat_ref;
        const groupName = tasks[0].group_name || "Group";
        const workspaceRef = tasks[0].workspace_ref || null;
        const count = await sendReminderToGroupChat(chatRef, tasks, groupName, workspaceRef);
        remindersSent += count;
        for (const task of tasks) {
          await task.ref.update({
            last_reminder_at: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      console.log(`🔔 runTaskReminders: sent ${remindersSent} reminder(s) to ${byChatCapped.size} chat(s)`);
      res.status(200).json({ reminders_sent: remindersSent });
    } catch (err) {
      console.error("runTaskReminders error:", err);
      res.status(500).json({ error: String(err.message) });
    }
  });
