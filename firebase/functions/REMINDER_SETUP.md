# Task reminder setup (fully in action)

The LangGraph agent calls your **runTaskReminders** HTTP function at the end of each run (cron + on-demand daily summary). That function finds pending action items whose **due date + priority-based delay** has passed and sends a reminder message in each group chat + push from LonaAI.

**Reminders are based on due date only (not creation date):** a reminder is sent X hours **after** the task’s due date. Urgent: 0h after due · High: 24h after due · Moderate: 48h after due · Low: 72h after due. Tasks without a `due_date` are skipped.

---

## 1. Deploy functions (including runTaskReminders)

From your project root:

```bash
cd firebase
firebase deploy --only functions
```

Or deploy a single function:

```bash
firebase deploy --only functions:runTaskReminders
```

After deploy, note the **region** (e.g. `us-central1`). The URL will be:

```
https://<region>-<projectId>.cloudfunctions.net/runTaskReminders
```

Example for project `linkedup-c3e29` in `us-central1`:

```
https://us-central1-linkedup-c3e29.cloudfunctions.net/runTaskReminders
```

You can also see it in Firebase Console → Functions → `runTaskReminders` → copy trigger URL.

---

## 2. Set Firebase config (so the agent can call the reminder URL)

The agent reads **reminder.url** and **reminder.secret** from Firebase config (or env). Set them:

```bash
firebase functions:config:set reminder.url="https://us-central1-linkedup-c3e29.cloudfunctions.net/runTaskReminders" reminder.secret="6339072d5b2590910875b820d6c8fd3a7dde2d1ffa1596c2" --project linkedup-c3e29
```

- Run from project root or from `firebase/`. Replace the URL if your region/project differs.

**Redeploy after setting config** (config is baked in at deploy time):

```bash
firebase deploy --only functions
```

---

## 3. Verify

1. **Config is set**
   ```bash
   firebase functions:config:get reminder
   ```
   You should see `url` and `secret`.

2. **Agent has the URL**
   - When the agent runs (cron or daily summary), it will call `reminderUrl` with `X-Reminder-Secret: <reminderSecret>`.
   - If config was missing, agent logs would show: `No REMINDER_URL configured; skipped.`

3. **Reminder endpoint works**
   - **Safe test (no reminders sent):** use `?dry_run=1` to see what would be sent:
     ```bash
     curl -X POST "https://us-central1-linkedup-c3e29.cloudfunctions.net/runTaskReminders?dry_run=1" \
       -H "Content-Type: application/json" \
       -H "X-Reminder-Secret: 6339072d5b2590910875b820d6c8fd3a7dde2d1ffa1596c2" \
       -d '{}'
     ```
     Response includes `dry_run`, `would_send`, `chats_affected`, and **diagnostics**: `total_pending`, `no_due_date`, `has_last_reminder`, `not_yet_past_due_plus_delay`, `overdue`. A `message` explains why nothing is sent (e.g. "None past due date + delay yet").
   - **Test without waiting:** add `&ignore_delay=1` so all pending tasks with a due_date count as remindable in dry run only: `?dry_run=1&ignore_delay=1`.
   - **Real run:** omit `?dry_run=1`. You get `200` and `{"reminders_sent":N}`. At most **50 tasks** are processed per invocation (cap); the rest are handled on the next run.

---

## 4. Optional: use environment variables instead of config

If you prefer env vars (e.g. in Firebase config or CI):

- `REMINDER_URL` = full runTaskReminders URL
- `REMINDER_SECRET` = same secret string

Your code already falls back to these in index.js and in runTaskReminders.js:

- index.js: `functions.config().reminder?.url || process.env.REMINDER_URL`
- runTaskReminders.js: `functions.config().reminder?.secret || process.env.REMINDER_SECRET`

So you can set env in Firebase (e.g. via Firebase Console or `firebase functions:config:set` is the usual way; for env vars you’d use a `.env` file or Cloud Build / deployment config if you use one).

---

## 5. When reminders actually run

- Reminders run **when the agent runs**: at the end of each **InGroupSummer** cron (e.g. 9 AM) and at the end of each **dailySummary** (on-demand) run.
- So with a daily cron at 9 AM, reminders are sent once per day for any pending task whose due date + priority delay has passed (e.g. High → 24h after due date).
- If you want reminders at more precise times (e.g. exactly 24h after due date), add a **scheduled function** that calls the same runTaskReminders URL every hour (with the same secret). The delay is still enforced by runTaskReminders (now >= due_date + delayHours); you just run the check more often.
