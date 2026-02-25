/**
 * SummerAI LangGraph agent (JavaScript).
 * Stateful daily summary + action item extraction + save_memory + send_reminders.
 * Uses LangGraph (StateGraph, MemorySaver). Deploy as part of Firebase Functions.
 * Call runAgent(messages, chatId, context, options) from index.js or any HTTP handler.
 */

const { StateGraph, Annotation, MemorySaver, END } = require("@langchain/langgraph/web");
const OpenAI = require("openai");
const fetch = require("node-fetch");

// Fallback when options not passed via run config (e.g. single-threaded or tests)
let _runOptions = {};

// -----------------------------------------------------------------------------
// Config: from LangGraph run config.configurable (per-invocation) or _runOptions/env.
// Using configurable avoids race when cron runs multiple chats in parallel.
// -----------------------------------------------------------------------------
function getConfig(overrides) {
  const o =
    overrides && typeof overrides === "object" && "configurable" in overrides
      ? overrides.configurable
      : overrides || _runOptions;
  return {
    openaiApiKey: o.openaiApiKey || process.env.OPENAI_API_KEY || "",
    tavilyApiKey: o.tavilyApiKey || process.env.TAVILY_API_KEY || "",
    reminderUrl: o.reminderUrl || process.env.REMINDER_URL || "",
    reminderSecret: o.reminderSecret || process.env.REMINDER_SECRET || "",
  };
}

// -----------------------------------------------------------------------------
// State schema (matches Python AgentState for checkpointer)
// -----------------------------------------------------------------------------
const AgentStateAnnotation = Annotation.Root({
  messages: Annotation(),
  chat_id: Annotation(),
  last_summary: Annotation(),
  last_summary_date: Annotation(),
  retrieved_memory: Annotation(),
  summary: Annotation(),
  action_items: Annotation(),
  group_name: Annotation(),
  member_names: Annotation(),
  event_info: Annotation(),
  timeframe: Annotation(),
  llm_messages: Annotation(),
  tool_results: Annotation(),
});

// -----------------------------------------------------------------------------
// Tools
// -----------------------------------------------------------------------------
async function webSearch(query, tavilyApiKey) {
  if (tavilyApiKey) {
    try {
      const resp = await fetch("https://api.tavily.com/search", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          api_key: tavilyApiKey,
          query,
          search_depth: "basic",
          max_results: 3,
        }),
      });
      if (!resp.ok) return [];
      const data = await resp.json();
      return (data.results || []).slice(0, 5).map((r) => ({
        title: r.title || query,
        url: r.url || "",
        snippet: r.content || "",
      }));
    } catch (e) {
      console.warn("Tavily search error:", e);
    }
  }
  try {
    const resp = await fetch(
      `https://api.duckduckgo.com/?q=${encodeURIComponent(query)}&format=json&no_redirect=1`
    );
    if (!resp.ok) return [];
    const data = await resp.json();
    const results = [];
    if (data.AbstractText) {
      results.push({
        title: data.Heading || query,
        url: data.AbstractURL || "",
        snippet: data.AbstractText || "",
      });
    }
    (data.RelatedTopics || []).slice(0, 2).forEach((topic) => {
      if (topic.FirstURL) {
        results.push({
          title: topic.Text || topic.FirstURL,
          url: topic.FirstURL,
          snippet: topic.Text || "",
        });
      }
    });
    return results;
  } catch (e) {
    console.warn("DuckDuckGo search error:", e);
    return [];
  }
}

// -----------------------------------------------------------------------------
// Nodes
// -----------------------------------------------------------------------------
function loadMemory(state) {
  const last = (state.last_summary || "").trim();
  return { retrieved_memory: last || "" };
}

async function summarize(state, config) {
  const apiKey = config.openaiApiKey;
  if (!apiKey) throw new Error("OPENAI_API_KEY not set");

  const groupName = state.group_name || "Group";
  const timeframe = state.timeframe || "the last 24 hours";
  const lastSummaryDate = state.last_summary_date || "N/A";
  const retrieved = state.retrieved_memory || "";
  const eventInfo = state.event_info;

  const systemParts = [
    "You are SummerAI, an AI assistant for a networking app. Your role is to analyze a day's worth of group chat messages and generate a structured summary in bullet format.",
    "",
    "**WEB SEARCH REQUIREMENT:** You MUST use web search for EVERY summary. Search for at least 2-3 topics discussed in the conversation to find relevant, up-to-date information that enhances your summary. This is mandatory for all summaries.",
    "",
    "**CRITICAL INSTRUCTIONS:**",
    "1. **Analyze ONLY Real User Messages:** You will receive ONLY real user messages (AI messages have been filtered out). Do NOT make up topics, people, or content that isn't explicitly mentioned in the provided messages. Only summarize what was actually discussed by real users.",
    "",
    "2. **Identify Multiple Topics:** This format should be used for ALL topics discussed. Identify multiple topics from the conversation, even if they seem unimportant. Give priorities accordingly:",
    "   - **Technical topics:** High/Medium priority",
    "   - **Non-technical topics:** Low/Medium priority",
    "   - **Business/Professional topics:** Medium/High priority",
    "   - **Casual/Social topics:** Low priority",
    "",
    "3. **Summarize in Bullet Format:** Your output MUST follow this exact format for each topic:",
    "",
    "> **Topic Name** (Priority: High/Medium/Low)",
    "- **Details:** Brief description of what was discussed",
    "- **Action Items:** Any tasks, decisions, or follow-ups identified (if none, write \"None\")",
    "- **Involved People:** Names of members who participated most actively (ONLY use names that appear in the actual messages below)",
    "- **SummerAI's Thoughts:** A 1-2 sentence personal insight or observation about the topic",
    "- **Useful Links:** ONLY include this section if you performed a web search for this topic. Format: \"1. [Article Title](URL) - Brief description\". If no search was performed, omit this section entirely.",
    "",
    "4. **Be Comprehensive:** Cover all topics discussed, from technical discussions to casual conversations. Don't skip topics just because they seem minor.",
    "",
    `5. **Previous Summary Note:** You last summarized on ${lastSummaryDate}. Try to connect today's summary to previous discussions if relevant.`,
    "",
    "6. **Do NOT repeat action items from the previous summary:** If the previous summary (provided below) already listed a task or action item, do NOT list the same task again in today's Action Items, even with different wording. Only list NEW tasks that emerged from today's messages. If the same topic appears but the action was already identified yesterday, write under Action Items: \"None new (already identified in last summary)\" or omit that topic's action items. This prevents duplicate tasks day after day.",
    "",
    `7. **Start with Header:** Begin with \"Summary for ${groupName} for ${timeframe}\"`,
    "",
    "8. **No Additional Greeting:** After the header, go straight into the bullet format summary without any additional greetings.",
    "",
    "**CONVERSATION CONTEXT:**",
  ];
  if (eventInfo && eventInfo.title) {
    systemParts.push(`- The conversation happened in a group for the event titled "${eventInfo.title}".`);
    if (eventInfo.description) systemParts.push(`- Event Description: ${eventInfo.description}`);
  } else {
    systemParts.push(`- Group Name: ${groupName}`);
  }
  systemParts.push(`- Timeframe: Messages from ${timeframe}.`);
  if (retrieved) {
    systemParts.push("- **Previous summary (use this to avoid repeating the same action items today):**");
    systemParts.push(retrieved.substring(0, 3000));
  }
  systemParts.push("- Here are the messages for you to analyze:");

  const messagesRaw = state.messages || [];
  const userContent = messagesRaw.map((m) => `\n- ${m.sender || "Unknown"}: ${m.content || ""}`).join("");

  const openai = new OpenAI({ apiKey });
  const webSearchTool = {
    type: "function",
    function: {
      name: "web_search",
      description: "Search the web for current information, latest news, or up-to-date details about topics mentioned in the conversation.",
      parameters: {
        type: "object",
        properties: { query: { type: "string", description: "The search query to look up on the web" } },
        required: ["query"],
      },
    },
  };

  const chatMessages = [
    { role: "system", content: systemParts.join("\n") },
    { role: "user", content: userContent },
  ];
  let searchCompleted = false;

  while (true) {
    const toolChoice = searchCompleted ? "none" : { type: "function", function: { name: "web_search" } };
    const resp = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: chatMessages,
      tools: [webSearchTool],
      tool_choice: toolChoice,
      max_tokens: 800,
      temperature: 0.7,
      top_p: 0.9,
      frequency_penalty: 0.3,
      presence_penalty: 0.3,
    });
    const msg = resp.choices[0].message;
    const assistantMsg = { role: "assistant", content: msg.content || "" };
    const toolCalls = msg.tool_calls || [];
    if (toolCalls.length) {
      assistantMsg.tool_calls = toolCalls.map((tc) => ({
        id: tc.id,
        type: "function",
        function: { name: tc.function?.name || "", arguments: tc.function?.arguments || "{}" },
      }));
    }
    chatMessages.push(assistantMsg);
    if (toolCalls.length === 0) break;
    for (const tc of toolCalls) {
      const fn = tc.function;
      if (fn && fn.name === "web_search") {
        let args = {};
        try {
          args = JSON.parse(fn.arguments || "{}");
        } catch (_) {}
        const query = args.query || "";
        const results = await webSearch(query, config.tavilyApiKey);
        const formatted = results.map((r, i) => `${i + 1}. [${r.title}](${r.url}) - ${r.snippet}`).join("\n");
        chatMessages.push({ role: "tool", tool_call_id: tc.id, content: formatted });
        searchCompleted = true;
      }
    }
  }

  const summaryText = (chatMessages[chatMessages.length - 1].content || "").trim();
  return { summary: summaryText, llm_messages: chatMessages };
}

async function extractTasks(state, config) {
  const apiKey = config.openaiApiKey;
  if (!apiKey) throw new Error("OPENAI_API_KEY not set");

  const summary = state.summary || "";
  const groupName = state.group_name || "Group Chat";
  const memberNames = state.member_names || [];
  const memberNamesText = memberNames.length
    ? `\n\nEXACT MEMBER NAMES (USE THESE EXACT NAMES ONLY - DO NOT GUESS OR USE PARTIAL NAMES):\n${memberNames.map((n, i) => `${i + 1}. ${n}`).join("\n")}\n\nCRITICAL: When assigning tasks, use ONLY the exact names from this list. If a name appears in the summary as "Mitansh" but the exact name is "Mitansh Patel", you MUST use "Mitansh Patel". Do NOT use partial names or guess names.`
    : "";

  const system = `You are TaskManagerAI, an intelligent task extraction assistant.
Your job is to carefully analyze SummerAI's summary and extract ONLY real, actionable tasks with accurate priority, owners, and a clear "Details" text. Do NOT include or infer due dates; due dates are set by humans later.

CRITICAL RULES:
1) Extract ONLY explicit action items; ignore general comments or observations.
2) Do NOT invent tasks, people, due dates, or context not present in the input.
3) Prefer items listed under any "Action Items" sections; if action-like directives appear elsewhere, include them only if they are clearly tasks.
4) Each item MUST include: title, priority, involvedPeople, and description (Details). Do NOT include a due date field.
5) Do NOT extract an action item when the summary says it was already identified previously (e.g. "None new", "already identified in last summary", or similar). Return zero action items for that topic.

OUTPUT FORMAT (JSON ONLY):
{
  "actionItems": [
    {
      "title": "Verb-first, specific task (<= 80 chars)",
      "priority": "Urgent" | "High" | "Moderate" | "Low",
      "involvedPeople": ["Exact Participant Name"],
      "description": "Details text per template below"
    }
  ]
}

NOTE: Do NOT include "groupName" in your output. The actual group name will be provided separately and will be used automatically.

DETAILS (description) TEMPLATE:
Write a clear, engaging description that tells the story of this task. Format it naturally:

"During the ${groupName} discussion on {CurrentDate}, {PeopleInvolved} identified the need to {action summary}. This task involves {specific steps and context}. {Why this matters - business impact or reason}. {Any dependencies, blockers, or important context if relevant - otherwise omit this part}."

IMPORTANT: The actual group name is "${groupName}". Use this exact name in your descriptions, not generic terms like "Group" or "the group".

Guidelines:
- Write in a natural, conversational tone (2-3 sentences)
- Make it clear why this task exists and what it accomplishes
- Focus on the "what" and "why", not just dry facts
- Always use the actual group name "${groupName}" in descriptions
- If People/Date are unclear, write naturally without forcing those details
- No markdown, no bullet points - just flowing prose
- Make it interesting and easy to understand at a glance

PRIORITY RUBRIC:
- Urgent: deadline ≤ 48h, blocks others, explicit urgency ("ASAP", "today/tomorrow").
- High: business-critical within ~3–7 days or external commitments.
- Moderate: important but flexible timeline.
- Low: nice-to-have or exploratory.
If mixed signals, choose the highest justified and briefly reflect that in description.

INVOLVED PEOPLE:
- Use ONLY the exact member names provided in the list below. DO NOT guess names, use partial names, or create variations.
- If a name appears in the summary as "Mitansh" but the exact name is "Mitansh Patel", you MUST use "Mitansh Patel".
- Match names from the summary to the exact names in the provided list. If unsure, leave involvedPeople empty rather than guessing.
- Exclude bots/assistants (SummerAI, etc.).
${memberNamesText}

QUALITY + SAFETY CHECKS BEFORE RETURNING:
- Deduplicate tasks (same intent/owner). If multiple tasks have the same core objective, merge them into ONE task.
- Remove non-actionable items.
- If you see similar tasks (e.g., "integrate Gmail" and "focus on Gmail integration"), return ONLY ONE consolidated task.
- Ensure valid JSON ONLY (no prose outside JSON). Start with { and end with }.`;

  const openai = new OpenAI({ apiKey });
  const completion = await openai.chat.completions.create({
    model: "gpt-4",
    messages: [{ role: "system", content: system }, { role: "user", content: summary }],
    temperature: 0.3,
  });
  let content = (completion.choices[0].message.content || "").trim();
  if (content.startsWith("```")) {
    content = content.replace(/^```\w*\n?/, "").replace(/```\s*$/, "");
  }
  let parsed;
  try {
    parsed = JSON.parse(content);
  } catch (_) {
    return { action_items: [] };
  }
  const rawItems = parsed.actionItems || [];
  const actionItems = rawItems.map((item) => ({
    title: item.title || "",
    priority: item.priority || "Moderate",
    involved_people: item.involvedPeople || item.involved_people || [],
    description: item.description || "",
  }));
  return { action_items: actionItems };
}

function saveMemory(state) {
  const now = new Date();
  const dateStr = now.toISOString().slice(0, 10);
  return {
    last_summary: state.summary || "",
    last_summary_date: dateStr,
  };
}

async function sendTaskReminders(config) {
  const url = (config.reminderUrl || "").trim();
  const secret = config.reminderSecret || "";
  if (!url) {
    console.log("🔔 Reminders: skipped (no REMINDER_URL configured)");
    return "No REMINDER_URL configured; skipped.";
  }
  try {
    const headers = { "Content-Type": "application/json" };
    if (secret) headers["X-Reminder-Secret"] = secret;
    const resp = await fetch(url, { method: "POST", headers, body: JSON.stringify({}) });
    if (resp.status !== 200) {
      console.warn("🔔 Reminders: API returned", resp.status);
      return `Reminders API returned ${resp.status}`;
    }
    const data = await resp.json();
    const sent = data.reminders_sent || 0;
    console.log(`🔔 Reminders: called runTaskReminders → reminders_sent=${sent}`);
    return `Reminders sent: ${sent}`;
  } catch (e) {
    console.error("🔔 Reminders: error", e.message || e);
    return `Reminders error: ${e.message || e}`;
  }
}

async function sendReminders(state, config) {
  const result = await sendTaskReminders(config);
  return { tool_results: result };
}

// -----------------------------------------------------------------------------
// Graph build and run
// -----------------------------------------------------------------------------
let compiledGraph = null;

function buildGraph() {
  const checkpointer = new MemorySaver();
  const builder = new StateGraph(AgentStateAnnotation);

  builder.addNode("load_memory", (state) => loadMemory(state));
  builder.addNode("summarize", async (state, config) => summarize(state, getConfig(config)));
  builder.addNode("extract_tasks", async (state, config) => extractTasks(state, getConfig(config)));
  builder.addNode("save_memory", (state) => saveMemory(state));
  builder.addNode("send_reminders", async (state, config) => sendReminders(state, getConfig(config)));

  builder.addEdge("load_memory", "summarize");
  builder.addEdge("summarize", "extract_tasks");
  builder.addEdge("extract_tasks", "save_memory");
  builder.addEdge("save_memory", "send_reminders");
  builder.addEdge("send_reminders", END);
  builder.setEntryPoint("load_memory");

  return builder.compile({ checkpointer });
}

function getGraph() {
  if (!compiledGraph) compiledGraph = buildGraph();
  return compiledGraph;
}

/**
 * Run the SummerAI agent for one chat.
 *
 * @param {Array<{ sender: string, content: string }>} messages - User messages only.
 * @param {string} chatId - Used as thread_id for checkpointer.
 * @param {object} context - group_name, member_names, last_summary, last_summary_date, event_info (optional), timeframe.
 * @param {object} [options] - openaiApiKey, tavilyApiKey, reminderUrl, reminderSecret (else from env).
 * @returns {Promise<{ summary: string, content: string, action_items: Array<{ title, priority, involvedPeople, description }> }>}
 */
async function runAgent(messages, chatId, context, options = {}) {
  const config = getConfig(options);
  if (!messages || messages.length === 0) {
    return { summary: "", content: "", action_items: [] };
  }

  const groupName = context.group_name || "Group";
  const memberNames = context.member_names || [];
  const lastSummary = context.last_summary || "";
  const lastSummaryDate = context.last_summary_date || "N/A";
  const eventInfo = context.event_info || null;
  const timeframe = context.timeframe || "the last 24 hours";

  _runOptions = options || {};
  const initial = {
    messages,
    chat_id: chatId,
    last_summary: lastSummary,
    last_summary_date: lastSummaryDate,
    retrieved_memory: "",
    summary: "",
    action_items: [],
    group_name: groupName,
    member_names: memberNames,
    event_info: eventInfo,
    timeframe,
  };

  const graph = getGraph();
  // Pass options in configurable so each parallel invocation has its own config (no global race).
  const runConfig = {
    configurable: {
      thread_id: chatId,
      openaiApiKey: options.openaiApiKey,
      tavilyApiKey: options.tavilyApiKey,
      reminderUrl: options.reminderUrl,
      reminderSecret: options.reminderSecret,
    },
    recursion_limit: 50,
  };
  let final;
  try {
    final = await graph.invoke(initial, runConfig);
  } finally {
    _runOptions = {};
  }

  const rawItems = final.action_items || [];
  const actionItemsOut = rawItems.map((item) => ({
    title: item.title || "",
    priority: item.priority || "Moderate",
    involvedPeople: item.involved_people || item.involvedPeople || [],
    description: item.description || "",
  }));

  const summaryText = final.summary || "";
  return {
    summary: summaryText,
    content: summaryText,
    action_items: actionItemsOut,
  };
}

module.exports = { runAgent, getConfig };


//3. Reminder tool
//The agent already has a send_reminders node that calls the reminders HTTP endpoint. The cron passes reminderUrl and reminderSecret in agentOptions, so after each run the agent will call your runTaskReminders function when those config values are set.
//Reverting if needed
//Uncomment the old block: remove the opening /* -------- OLD CRON ... and the closing -------- END OLD CRON -------- */, and comment out (or remove) the new “LangGraph agent” section so the previous in-JS SummerAI + TaskManagerAI flow runs again.
//Config for reminders
//Set either:
//functions.config().reminder.url and functions.config().reminder.secret, or
//REMINDER_URL and REMINDER_SECRET (e.g. in Firebase config or env),
//with the URL of your deployed runTaskReminders (e.g. https://<region>-<project>.cloudfunctions.net/runTaskReminders).