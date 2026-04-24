# `breakdown` edge function — spec

AI-powered project breakdown for Ploot. User types a project title in the iOS app; this function decides whether to ask a clarifying question or stream 3–8 concrete tasks. Answers are passed back in subsequent calls until the model decides it has enough.

The function is **stateless** — every call includes the full prior Q&A history in the request body.

---

## 1. HTTP contract

### Request

```
POST /functions/v1/breakdown
Authorization: Bearer <supabase-user-jwt>
Content-Type: application/json
```

```jsonc
{
  "title": "launch my podcast",
  "answers": [
    { "q": "what's the format?", "a": "interview" }
  ],
  "locale": "en"           // optional, falls back to IETF tag from Accept-Language
}
```

- `title` — required, the project title as typed by the user. Max 500 chars; longer rejected with 400.
- `answers` — array of `{q, a}` pairs answered so far. Empty on the first call. Max length 3 (we cap the conversation).
- `locale` — optional. Hint to the model for output language; if absent, the model matches the input.

### Response

`Content-Type: text/event-stream`. Server-Sent Events, one `data:` line per event. Stream ends on `done` or `refused`.

**Event types**

- `heartbeat` — sent within 500ms of request receipt so Supabase's 150s idle timer and our iOS timeout don't fire. Body: `{}`.
- `question` — the model wants one clarifier. Stream ends after this event; client collects answer and re-calls.
  ```json
  {
    "type": "question",
    "text": "DIY or pro?",
    "choices": ["DIY", "hire someone", "not sure"],
    "allowCustom": true
  }
  ```
- `task` — emitted one at a time as the model streams the task list. Fields are the final shape; no partial task events.
  ```json
  {
    "type": "task",
    "order": 0,
    "emoji": "🎙️",
    "title": "pick a name and grab the handles"
  }
  ```
- `hint` — model recognized the title as a single task, not a project. Client shows an offer to add it as a standalone task. Stream ends after this.
  ```json
  { "type": "hint", "kind": "single_task" }
  ```
- `split` — model detected two projects smooshed together. Client offers to split. Stream ends.
  ```json
  { "type": "split", "projects": ["paint the living room", "plan mom's birthday"] }
  ```
- `refused` — request is harmful/abusive. Stream ends.
  ```json
  { "type": "refused", "reason": "can't help with that." }
  ```
- `done` — final terminator. Sent after all `task` events.
  ```json
  { "type": "done", "count": 6 }
  ```
- `error` — server-side failure. Client shows the retry chip.
  ```json
  { "type": "error", "code": "rate_limited" | "upstream" | "timeout" | "internal" }
  ```

### HTTP status codes

- `200` — stream started (errors inside the stream use the `error` event, not HTTP).
- `400` — malformed body or title > 500 chars.
- `401` — missing/invalid JWT.
- `429` — over daily rate limit (returned *before* the stream opens; body: `{ "error": "rate_limited", "resetAt": "2026-04-24T00:00:00Z" }`).

---

## 2. Strict JSON schema (OpenRouter `response_format`)

We ask the model to emit a single JSON object matching this schema per call. Streaming is compatible with strict mode — partial JSON arrives progressively and is valid on completion.

```json
{
  "type": "json_schema",
  "json_schema": {
    "name": "BreakdownResponse",
    "strict": true,
    "schema": {
      "type": "object",
      "additionalProperties": false,
      "required": ["kind"],
      "properties": {
        "kind": { "enum": ["question", "tasks", "hint", "split", "refused"] },
        "question": {
          "type": "object",
          "additionalProperties": false,
          "required": ["text", "choices", "allowCustom"],
          "properties": {
            "text": { "type": "string", "maxLength": 120 },
            "choices": {
              "type": "array",
              "minItems": 2,
              "maxItems": 4,
              "items": { "type": "string", "maxLength": 40 }
            },
            "allowCustom": { "type": "boolean" }
          }
        },
        "tasks": {
          "type": "array",
          "minItems": 1,
          "maxItems": 8,
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["emoji", "title"],
            "properties": {
              "emoji": { "type": "string" },
              "title": { "type": "string", "maxLength": 120 }
            }
          }
        },
        "split": {
          "type": "array",
          "minItems": 2,
          "maxItems": 3,
          "items": { "type": "string", "maxLength": 200 }
        },
        "refusedReason": { "type": "string", "maxLength": 200 }
      }
    }
  }
}
```

The edge function transforms this single JSON object into the SSE event stream: a `kind: "tasks"` object becomes N `task` events + 1 `done`, a `kind: "question"` becomes 1 `question` event, etc.

For Claude routes, which don't honor `strict: true` on `json_schema`, fall back to tool-calling with two tools (`ask_clarifier`, `emit_tasks`, `hint_single_task`, `split_projects`, `refuse`). Keep this in a single switch on `model.startsWith("anthropic/")`.

---

## 3. System prompt

Two parts: static rules + dynamic user context preamble. Assembled per request.

### Static rules

```
You break a project into a small, ordered list of concrete tasks for a native iOS task app called Ploot.

## Decision: ask or generate

Before generating tasks, decide whether you need ONE clarifying question.

Ask ONLY if the answer would change the task list significantly (>30%).
Skip if you are 70%+ confident you can generate a good list from the title alone plus any prior answers and the user context below.

Maximum 3 questions total across the conversation (check the count of prior answers). After 3 prior answers, you MUST generate tasks.

Question categories — pick at most ONE per turn:
- Approach (DIY vs pro, scratch vs template, manual vs automated)
- Scope (quick pass vs full redo, draft vs polished)
- Deadline (only if timeline changes the list)
- Constraint (budget, tools, starting assets)
- Audience (self vs work vs client)
- Format (category-defining — podcast format, trip type, party style)
- Starting point (fresh vs improving existing)

Never ask about:
- Info visible in the title.
- Preferences that don't shape the task list (colors, names, aesthetic picks).
- Feelings or motivation.
- Anything already in the user context below.

## When asking (kind: "question")

- `question.text`: one short, casual question. Lowercase, contractions, no corporate voice. Example: "DIY or pro?" not "What is your preferred approach?"
- `question.choices`: 2–4 mutually exclusive options covering the common cases. Lowercase.
- `question.allowCustom`: true unless the choices genuinely cover everything.
- Always include an escape like "not sure" or "skip" so the user is never stuck.

## When generating tasks (kind: "tasks")

- 3–8 tasks. Prefer fewer meaningful tasks over many small ones.
- Each task completable in under 2 hours of focused work. If a step needs sub-steps, return it as one concrete action, not an umbrella. Write "write first chapter" not "plan the book."
- Lowercase casual voice. Contractions. Period, not exclamation. Parentheticals for warmth.
  - good: "pick a name and grab the handles"
  - good: "buy a decent mic (shure mv7 or samson q2u)"
  - bad: "Research podcast equipment options"
  - bad: "Embark on your recording journey!"
- One emoji per task, chosen for the action. Allowed set:
  📝 🛒 📞 📐 💻 🎨 📚 🎧 🎙️ 🎛️ 📡 🚀 🔧 🔨 📦 📧 📄 ✍️ 🖼️ 🧪 🧹 🧊 🍳 🌱 🚗 ✈️ 🏠 🏋️ 💳 💰 🎁 🎂 🎉 💼 🏡 📅 ⏰ 🔍 ⚙️ ♻️
- Order by dependency or natural sequence.
- Match the language of the title. Spanish title → Spanish tasks.

## Edge cases

- Title is a single task ("email John back"): return kind "hint" instead of tasks.
- Title contains two distinct projects ("paint living room and plan mom's birthday"): return kind "split" with both titles.
- Title is gibberish, single emoji, or extremely vague ("asdf", "life"): ask one broad clarifier.
- Request is harmful, illegal, or abusive: return kind "refused" with a short polite reason.
- Title already has 3+ concrete constraints (deadline, budget, audience spelled out): skip questions; generate directly.
- Multi-week / multi-month project ("run a marathon"): return milestone-level tasks, not micro-steps.

## Later answer wins

If the user's custom answer contradicts an earlier choice, honor the latest.

## User context

Use this to shape phrasing and scope. Never mention it back to the user — they do not want to read their profile.
```

### Dynamic preamble (appended to the prompt)

Built from the caller's `profiles` row. Only include fields with values.

```
Today's date: 2026-04-23
Role: designer
Motivation: "trying to stop dropping balls at work"
Blockers: "i start too many things and finish nothing"
Tone preference: firm
Daily task goal: 3 tasks/day
Peak energy: morning
```

Field → source map:

| Preamble line | Source column |
|---|---|
| Role | `profiles.primary_role` |
| Motivation | `profiles.onboarding_answers->>'whatBringsYou'` |
| Blockers | `profiles.onboarding_answers->>'gettingInTheWay'` |
| Tone preference | `profiles.reminder_style` |
| Daily task goal | `profiles.daily_goal` |
| Peak energy | `profiles.chronotype` → "early morning" / "morning" / "afternoon" / "night" |
| Today's date | server clock, UTC → ISO date |

Do **not** pass: `checkin_time`, `current_system`, `uses_projects`, `track_streak`, `planning_time`, `tasks_per_day` — noise.

---

## 4. Rate limiting

Per-user, per-UTC-day counter in Postgres. Atomic increment on every successful call (AI call made, tokens billed). Requests over the limit return HTTP 429 *before* the stream opens.

- Free tier: 10 breakdowns / day.
- Subscribed tier (via `subscription_status.is_active`): 100 / day.

Numbers are tunable in a single constant in the edge function — no redeploy needed if we pass them via env. Start with these, watch logs for a week, adjust.

Pseudocode inside the edge function:

```ts
const { rows: [{ count }] } = await sql`
  insert into public.ai_breakdown_usage (user_id, day, count)
  values (${userId}, current_date, 1)
  on conflict (user_id, day)
  do update set count = ai_breakdown_usage.count + 1, updated_at = now()
  returning count
`
if (count > limit) return new Response(JSON.stringify({ error: "rate_limited", resetAt }), { status: 429 })
```

Race-safe via `ON CONFLICT`. Rollback on failure (refund the counter) is **not** implemented in v1 — a failed OpenRouter call still costs the user a quota point. Acceptable: failures are rare, and refunding opens its own race window. Revisit if users complain.

---

## 5. Model choice + fallback

Default: `openai/gpt-4o-mini`. Native strict `json_schema` support, cheapest JSON-reliable model (~$0.0003 per breakdown at 500 in / 200 out tokens, ~1.5 calls per breakdown average).

Fallback order on upstream failure:
1. `openai/gpt-4o-mini` (default).
2. `google/gemini-2.5-flash` on 5xx or timeout — good JSON, 3× the cost but still cheap.
3. `anthropic/claude-haiku-4.5` only if explicitly requested via query param (for our own voice-quality A/B testing).

Model ID lives in `OPENROUTER_MODEL` env var so we can swap without a redeploy.

---

## 6. Client integration notes (iOS)

- Use `Recouse/EventSource` Swift package. Single async-for loop, handles reconnect + partial lines.
- First event expected within 800ms; if not, show "thinking…" shimmer but don't cancel for 10s.
- Retain partial task list on disconnect. Offer "add the rest" chip, not a full regenerate.
- Cache the `answers` array locally while the sheet is open; on question answered, rebuild and POST the full array.
- Treat `type: "error"` as recoverable — retry chip. Treat HTTP 429 as a soft-cap message with the reset time.
- On `kind: "hint"`, show a single-task-instead prompt in the project detail UI.
- On `kind: "split"`, show a two-project split confirmation card.

---

## 7. Open items (not v1)

- Refund rate-limit count on failed OpenRouter calls (adds a race; probably not worth it).
- Learn per-user patterns over time — average task count, completion rate per category — feed back into preamble. V2.
- A/B test voice across models (haiku vs gpt-4o-mini) on real users once we have volume.
- Widget / Siri entry point for voice breakdown ("hey siri, break down a new project in ploot").

---

## 8. Deployment checklist

- [ ] `supabase secrets set OPENROUTER_API_KEY=sk-or-...`
- [ ] `supabase secrets set OPENROUTER_MODEL=openai/gpt-4o-mini`
- [ ] Apply `supabase/migrations/0007_ai_breakdown_usage.sql`
- [ ] Deploy: `supabase functions deploy breakdown`
- [ ] Smoke test via curl with a real user JWT.
- [ ] Wire the iOS client (separate task).
