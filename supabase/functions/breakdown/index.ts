// AI project breakdown. Decides whether to ask one clarifying question
// or emit 3–8 concrete tasks. Stateless; callers pass the full answer
// history on each call.
//
// Security + reliability hardenings in v5+:
//   * JWT verified via supabase.auth.getUser(jwt) — real signature check,
//     not just a base64 decode relying on verify_jwt=true at the gateway.
//   * Rate limit is a single atomic RPC (check_and_increment_usage) so
//     concurrent calls can't slip past the limit.
//   * OpenRouter response_format is strict json_schema with a
//     discriminated union — near-100% schema adherence vs the ~70% we
//     were getting with plain json_object.

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "npm:@supabase/supabase-js@2.45.4"

// ---------- Config ----------

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const OPENROUTER_API_KEY = Deno.env.get("OPENROUTER_API_KEY")!
const OPENROUTER_MODEL = Deno.env.get("OPENROUTER_MODEL") ?? "openai/gpt-4o-mini"
const OPENROUTER_FALLBACK_MODEL =
  Deno.env.get("OPENROUTER_FALLBACK_MODEL") ?? "google/gemini-2.5-flash"

const FREE_DAILY_LIMIT = 10
const SUB_DAILY_LIMIT = 100
const UPSTREAM_TIMEOUT_MS = 30_000
const TASK_EMIT_GAP_MS = 60

const ACTIVE_SUB_STATUSES = new Set(["trialing", "active", "grace"])

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

// ---------- Strict JSON schema ----------

// OpenAI strict mode: every property must appear in `required`; "optional"
// fields are modeled as `anyOf: [null, …]`. additionalProperties: false
// everywhere. Discriminated unions use a `kind` enum + sibling nullable
// fields — OpenAI doesn't support `oneOf` at the root reliably yet.
const BREAKDOWN_SCHEMA = {
  name: "BreakdownResponse",
  strict: true,
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["kind", "question", "tasks", "split", "refusedReason"],
    properties: {
      kind: { type: "string", enum: ["question", "tasks", "hint", "split", "refused"] },
      question: {
        anyOf: [
          { type: "null" },
          {
            type: "object",
            additionalProperties: false,
            required: ["text", "choices", "allowCustom"],
            properties: {
              text: { type: "string" },
              choices: { type: "array", items: { type: "string" } },
              allowCustom: { type: "boolean" },
            },
          },
        ],
      },
      tasks: {
        anyOf: [
          { type: "null" },
          {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              required: ["title"],
              properties: {
                title: { type: "string" },
              },
            },
          },
        ],
      },
      split: {
        anyOf: [
          { type: "null" },
          { type: "array", items: { type: "string" } },
        ],
      },
      refusedReason: {
        anyOf: [{ type: "null" }, { type: "string" }],
      },
    },
  },
}

// ---------- Prompt ----------

const SYSTEM_PROMPT_STATIC = `You break a project into a small, ordered list of concrete tasks for a native iOS task app called Ploot.

## Decision: ask or generate

Before generating tasks, decide whether you need ONE clarifying question.

Ask ONLY if the answer would change the task list significantly (>30%).
Skip if you are 70%+ confident you can generate a good list from the title alone plus any prior answers and the user context below.

(The question budget appears in a separate "Question budget" section below — count the prior answers against the cap stated there.)

Question categories — pick at most ONE per turn:
- Approach (DIY vs pro, scratch vs template, manual vs automated)
- Scope (quick pass vs full redo, draft vs polished)
- Deadline — ASK when the title implies a real-world end date (party, trip, launch, presentation, exam, interview, demo, deadline, recital, wedding, move). Also ask if user's daily_goal is 1–3 and the project will likely produce 5+ tasks (the drip alone would take >5 days). Choices should be concrete windows: "this weekend", "this week", "next 2 weeks", "longer / no rush". Skip when the project is open-ended.
- Constraint (budget, tools, starting assets)
- Audience (self vs work vs client)
- Format (category-defining — podcast format, trip type, party style)
- Starting point (fresh vs improving existing)

Never ask about:
- Info visible in the title.
- Preferences that don't shape the task list (colors, names, aesthetic picks).
- Feelings or motivation.
- Anything already in the user context.

## Output shape

ALWAYS include every top-level field (kind, question, tasks, split, refusedReason). Set unused fields to null. The "kind" field determines which sibling field is populated:

- kind = "question": populate question, set others to null.
- kind = "tasks": populate tasks array (3–8 items), set others to null.
- kind = "hint": set ALL siblings to null. Used when the title is a single task, not a project.
- kind = "split": populate split (2–3 titles), set others to null. Used when title contains two distinct projects.
- kind = "refused": populate refusedReason (short polite reason), set others to null. Used for harmful/illegal/abusive.

## When asking (kind = "question")

- question.text: one short, casual question. Lowercase, contractions, no corporate voice.
- question.choices: 2–4 mutually exclusive options covering the common cases. Lowercase.
- question.allowCustom: true unless the choices genuinely cover everything.
- Always include an escape like "not sure" or "skip" so the user is never stuck.

## When generating tasks (kind = "tasks")

### How many tasks

The 3–8 range is a guide, not a default. Actively decide based on these signals from the user context below:

- **Low daily_goal (1–3)** → prefer 3–5 tasks. This user handles fewer at a time; 8 micro-tasks would overwhelm them.
- **High daily_goal (6+)** → 6–8 tasks OK if the project genuinely has that many distinct steps.
- **User's blocker mentions "perfectionism", "overwhelm", "anxiety", "too much"** → return 3–5 FEWER, BIGGER tasks. Each completion gives real momentum.
- **User's blocker mentions "procrastination", "distractions", "focus", "starting"** → return 5–7 SMALLER tasks (30–45 min each). Each feels doable.
- **Short-horizon project (this weekend, this week, a few days)** → 5–7 concrete 1–2hr tasks.
- **Multi-week / multi-month project** → 5–7 milestone-level tasks, NOT granular steps. Each milestone can be broken down again later.

When in doubt, err on FEWER tasks. An 8-task list fills the user's whole week; a 4-task list fits their day.

### Each task

- Completable in under 2 hours of focused work.
- Lowercase casual voice. Contractions. Period, not exclamation. Parentheticals for warmth.
- Acronyms: lowercase ("diy", "ceo", "api", "ui", "mvp"). Never "DIY", "CEO", etc.
- Order by dependency or natural sequence.
- Match the language of the title. Spanish title → Spanish tasks.

## Edge cases

- Title is a single task ("email John back"): return kind "hint".
- Title contains two distinct projects: return kind "split" with both titles.
- Title is gibberish, single emoji, or extremely vague: ask one broad clarifier.
- Harmful / illegal / abusive: return kind "refused".
- Multi-week project: milestone-level tasks, not micro-steps.

## User context

Use this to shape phrasing and scope. Never mention it back to the user — they don't want to read their profile.
`

// ---------- Types ----------

type Answer = { q: string; a: string }

type Profile = {
  primary_role: string | null
  chronotype: string | null
  daily_goal: number | null
  reminder_style: string | null
  bio: string | null
  onboarding_answers: Record<string, unknown> | null
}

type ProjectContext = {
  completed_projects: string[]
  active_projects: string[]
  avg_tasks_per_project: number
}

type ModelResponse =
  | { kind: "question"; question: { text: string; choices: string[]; allowCustom: boolean } }
  | { kind: "tasks"; tasks: Array<{ title: string }> }
  | { kind: "hint" }
  | { kind: "split"; split: string[] }
  | { kind: "refused"; refusedReason: string }

// ---------- Main handler ----------

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS })
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405)

  const authHeader = req.headers.get("Authorization")
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "unauthorized", reason: "missing_header" }, 401)
  }
  const jwt = authHeader.substring(7)

  // Real signature verification via the Supabase auth server. Slightly
  // slower than a base64 decode (~80ms) but means we're not relying on
  // verify_jwt=true at the platform layer, which Supabase is deprecating.
  const userId = await verifyJwtAndGetUserId(jwt)
  if (!userId) {
    return jsonResponse({ error: "unauthorized", reason: "invalid_jwt" }, 401)
  }

  let body: { title?: unknown; answers?: unknown; locale?: unknown; max_questions?: unknown; bio?: unknown; project_context?: unknown }
  try {
    body = await req.json()
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400)
  }

  const title = typeof body.title === "string" ? body.title.trim() : ""
  if (!title || title.length > 500) return jsonResponse({ error: "invalid_title" }, 400)

  // Caps the conversation length. Driven by the iOS client's
  // Settings → AI breakdown → Clarifying questions pref. 0 means "skip
  // questions entirely, jump straight to tasks". Defaults to 3 if the
  // client doesn't pass it, matching the previous hardcoded cap.
  const maxQuestionsRaw = typeof body.max_questions === "number" ? body.max_questions : 3
  const maxQuestions = Math.max(0, Math.min(5, Math.floor(maxQuestionsRaw)))

  const answersRaw = Array.isArray(body.answers) ? body.answers : []
  if (answersRaw.length > 5) return jsonResponse({ error: "too_many_answers" }, 400)
  const answers: Answer[] = []
  for (const a of answersRaw) {
    if (!a || typeof a !== "object") continue
    const q = typeof (a as Answer).q === "string" ? (a as Answer).q : ""
    const ans = typeof (a as Answer).a === "string" ? (a as Answer).a : ""
    if (q && ans) answers.push({ q: q.slice(0, 200), a: ans.slice(0, 200) })
  }

  // Client-supplied bio and project context. These enrich the system
  // prompt so the AI can tailor task count and phrasing.
  const clientBio = typeof body.bio === "string" ? body.bio.trim().slice(0, 500) : null
  const clientProjectCtx: ProjectContext | null = (() => {
    const pc = body.project_context
    if (!pc || typeof pc !== "object") return null
    const obj = pc as Record<string, unknown>
    return {
      completed_projects: Array.isArray(obj.completed_projects)
        ? (obj.completed_projects as unknown[]).filter((s) => typeof s === "string").slice(0, 10) as string[]
        : [],
      active_projects: Array.isArray(obj.active_projects)
        ? (obj.active_projects as unknown[]).filter((s) => typeof s === "string").slice(0, 10) as string[]
        : [],
      avg_tasks_per_project: typeof obj.avg_tasks_per_project === "number" ? obj.avg_tasks_per_project : 0,
    }
  })()

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  })

  // Subscription check runs in parallel with the rate-limit RPC. We can't
  // run the rate-limit RPC before knowing the limit tier, so subscription
  // fetch happens first and the check afterward. Profile fetch also runs
  // in parallel with the subscription lookup.
  const [subResult, profileResult] = await Promise.all([
    admin.from("subscription_status").select("status").eq("user_id", userId).maybeSingle(),
    admin
      .from("profiles")
      .select("primary_role, chronotype, daily_goal, reminder_style, bio, onboarding_answers")
      .eq("id", userId)
      .maybeSingle(),
  ])

  const isSubbed =
    subResult.data?.status && ACTIVE_SUB_STATUSES.has(subResult.data.status as string)
  const limit = isSubbed ? SUB_DAILY_LIMIT : FREE_DAILY_LIMIT

  const rateLimitResult = await admin.rpc("check_and_increment_usage", {
    p_user_id: userId,
    p_limit: limit,
  })
  if (rateLimitResult.error) {
    console.error("rate-limit rpc failed", rateLimitResult.error)
    return jsonResponse({ error: "internal" }, 500)
  }
  const row = Array.isArray(rateLimitResult.data) ? rateLimitResult.data[0] : null
  const currentCount = (row?.new_count as number | undefined) ?? 0
  const allowed = (row?.allowed as boolean | undefined) ?? false

  if (!allowed) {
    const resetAt = new Date()
    resetAt.setUTCHours(24, 0, 0, 0)
    return jsonResponse(
      { error: "rate_limited", resetAt: resetAt.toISOString(), limit, used: currentCount },
      429,
    )
  }

  const profile = (profileResult.data as Profile | null) ?? null
  const preamble = buildPreamble(profile, clientBio, clientProjectCtx)
  // The user-pref question cap rewrites the question budget in the
  // system prompt. `maxQuestions === 0` flips the prompt to "never
  // ask, always emit tasks" so the prefill is unambiguous.
  const questionRule = maxQuestions === 0
    ? `\n\n## Question budget\nThe user has disabled clarifying questions. NEVER ask a question — emit tasks (or hint/split/refused) on the first turn.`
    : `\n\n## Question budget\nMaximum ${maxQuestions} question${maxQuestions === 1 ? "" : "s"} total across the conversation (count the prior answers). After ${maxQuestions} prior answer${maxQuestions === 1 ? "" : "s"}, you MUST generate tasks.`
  const systemPrompt = SYSTEM_PROMPT_STATIC + questionRule + "\n" + preamble
  const userMessage = buildUserMessage(title, answers)

  const stream = new ReadableStream<Uint8Array>({
    async start(controller) {
      const enc = new TextEncoder()
      const send = (type: string, payload: Record<string, unknown> = {}) => {
        controller.enqueue(enc.encode(`data: ${JSON.stringify({ type, ...payload })}\n\n`))
      }

      send("heartbeat")

      let response: ModelResponse | null = null
      let lastError = "internal"
      for (const model of [OPENROUTER_MODEL, OPENROUTER_FALLBACK_MODEL]) {
        try {
          response = await callOpenRouter(model, systemPrompt, userMessage)
          break
        } catch (err) {
          console.error(`openrouter call failed on ${model}:`, err)
          lastError =
            err instanceof Error && err.message.startsWith("timeout") ? "timeout" : "upstream"
        }
      }

      if (!response) {
        send("error", { code: lastError })
        controller.close()
        return
      }

      switch (response.kind) {
        case "question":
          send("question", {
            text: response.question.text,
            choices: response.question.choices,
            allowCustom: response.question.allowCustom,
          })
          send("done", { count: 0 })
          break
        case "tasks": {
          const tasks = response.tasks.slice(0, 8)
          for (let i = 0; i < tasks.length; i++) {
            send("task", { order: i, title: tasks[i].title })
            if (i < tasks.length - 1) await sleep(TASK_EMIT_GAP_MS)
          }
          send("done", { count: tasks.length })
          break
        }
        case "hint":
          send("hint", { kind: "single_task" })
          break
        case "split":
          send("split", { projects: response.split })
          break
        case "refused":
          send("refused", { reason: response.refusedReason })
          break
      }

      controller.close()
    },
  })

  return new Response(stream, {
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive",
    },
  })
})

// ---------- Auth ----------

/// Verifies the bearer JWT against the Supabase auth server and extracts
/// the user id. Returns null on any failure (bad token, expired, network).
async function verifyJwtAndGetUserId(jwt: string): Promise<string | null> {
  const supa = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data, error } = await supa.auth.getUser(jwt)
  if (error || !data?.user?.id) {
    console.error("getUser failed", error?.message ?? "no user")
    return null
  }
  return data.user.id
}

// ---------- OpenRouter ----------

async function callOpenRouter(
  model: string,
  systemPrompt: string,
  userMessage: string,
): Promise<ModelResponse> {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS)
  try {
    const res = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENROUTER_API_KEY}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://ploot.app",
        "X-Title": "Ploot",
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userMessage },
        ],
        response_format: { type: "json_schema", json_schema: BREAKDOWN_SCHEMA },
        temperature: 0.6,
        max_tokens: 600,
      }),
      signal: controller.signal,
    })
    if (!res.ok) {
      const txt = await res.text().catch(() => "")
      throw new Error(`openrouter ${res.status}: ${txt.slice(0, 200)}`)
    }
    const payload = await res.json()
    const content: string | undefined = payload?.choices?.[0]?.message?.content
    if (!content) throw new Error("empty model response")
    return validateModelResponse(JSON.parse(content))
  } catch (err) {
    if (err instanceof Error && err.name === "AbortError") throw new Error("timeout")
    throw err
  } finally {
    clearTimeout(timeout)
  }
}

function validateModelResponse(v: unknown): ModelResponse {
  if (!v || typeof v !== "object") throw new Error("not an object")
  const obj = v as Record<string, unknown>
  const kind = obj.kind

  if (kind === "question") {
    const q = obj.question as Record<string, unknown> | null
    if (!q || typeof q.text !== "string") throw new Error("bad question")
    const choices = Array.isArray(q.choices) ? q.choices.filter((c) => typeof c === "string") : []
    if (choices.length < 2 || choices.length > 4) throw new Error("bad choices")
    return {
      kind: "question",
      question: {
        text: (q.text as string).slice(0, 120),
        choices: (choices as string[]).map((c) => c.slice(0, 40)),
        allowCustom: q.allowCustom !== false,
      },
    }
  }

  if (kind === "tasks") {
    const raw = Array.isArray(obj.tasks) ? obj.tasks : []
    const tasks: Array<{ title: string }> = []
    for (const t of raw) {
      if (!t || typeof t !== "object") continue
      const o = t as Record<string, unknown>
      const title = typeof o.title === "string" ? o.title : ""
      if (title) tasks.push({ title: title.slice(0, 120) })
    }
    if (tasks.length === 0) throw new Error("no tasks")
    return { kind: "tasks", tasks }
  }

  if (kind === "hint") return { kind: "hint" }

  if (kind === "split") {
    const split = Array.isArray(obj.split)
      ? obj.split.filter((s) => typeof s === "string").map((s) => (s as string).slice(0, 200))
      : []
    if (split.length < 2) throw new Error("bad split")
    return { kind: "split", split: split as string[] }
  }

  if (kind === "refused") {
    const reason = typeof obj.refusedReason === "string" ? obj.refusedReason : "can't help with that."
    return { kind: "refused", refusedReason: reason.slice(0, 200) }
  }

  throw new Error(`unknown kind: ${String(kind)}`)
}

// ---------- Helpers ----------

function buildPreamble(
  profile: Profile | null,
  clientBio: string | null,
  projectCtx: ProjectContext | null,
): string {
  const today = new Date().toISOString().slice(0, 10)
  const lines: string[] = [`Today's date: ${today}`]
  if (!profile && !clientBio && !projectCtx) return lines.join("\n")

  // Bio: prefer client-sent (most recent), fall back to DB-stored.
  const bio = clientBio || profile?.bio || null
  if (bio) lines.push(`About the user: "${bio.slice(0, 500)}"`)

  if (profile) {
    if (profile.primary_role) lines.push(`Role: ${profile.primary_role}`)
    const answers = profile.onboarding_answers as Record<string, unknown> | null
    if (answers) {
      if (typeof answers.whatBringsYou === "string" && answers.whatBringsYou.trim()) {
        lines.push(`Motivation: "${String(answers.whatBringsYou).slice(0, 200)}"`)
      }
      if (typeof answers.gettingInTheWay === "string" && answers.gettingInTheWay.trim()) {
        lines.push(`Blockers: "${String(answers.gettingInTheWay).slice(0, 200)}"`)
      }
    }
    if (profile.reminder_style) lines.push(`Tone preference: ${profile.reminder_style}`)
    if (profile.daily_goal) lines.push(`Daily task goal: ${profile.daily_goal} tasks/day`)
    const peak = chronotypeLabel(profile.chronotype)
    if (peak) lines.push(`Peak energy: ${peak}`)
  }

  // Project history: helps the AI calibrate task count and avoid
  // repeating themes from recent projects.
  if (projectCtx) {
    if (projectCtx.completed_projects.length > 0) {
      lines.push(`Recently completed projects: ${projectCtx.completed_projects.join(", ")}`)
    }
    if (projectCtx.active_projects.length > 0) {
      lines.push(`Currently active projects: ${projectCtx.active_projects.join(", ")}`)
    }
    if (projectCtx.avg_tasks_per_project > 0) {
      lines.push(`Avg tasks per project: ${projectCtx.avg_tasks_per_project}`)
    }
  }

  return lines.join("\n")
}

function chronotypeLabel(c: string | null): string | null {
  switch (c) {
    case "early": return "early morning"
    case "morning": return "morning"
    case "afternoon": return "afternoon"
    case "night": return "night"
    default: return null
  }
}

function buildUserMessage(title: string, answers: Answer[]): string {
  const lines = [`Project title: ${title}`]
  if (answers.length > 0) {
    lines.push("", "Prior answers:")
    for (const a of answers) lines.push(`- Q: ${a.q}`, `  A: ${a.a}`)
  }
  return lines.join("\n")
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms))
}
