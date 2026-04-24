// Voice intent extraction. Takes a short spoken-task transcript and
// returns a structured shape: single task, multi task, new project, or
// ambiguous. Shares the ai_breakdown_usage daily counter with the
// breakdown function so voice + AI-breakdown pool into one daily quota.
//
// Security + reliability parity with breakdown v6:
//   * JWT verified via supabase.auth.getUser — real signature check.
//   * Rate limit via atomic check_and_increment_usage RPC.
//   * Strict json_schema response_format for near-100% schema adherence.

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "npm:@supabase/supabase-js@2.45.4"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const OPENROUTER_API_KEY = Deno.env.get("OPENROUTER_API_KEY")!
const OPENROUTER_MODEL = Deno.env.get("OPENROUTER_MODEL") ?? "openai/gpt-4o-mini"
const OPENROUTER_FALLBACK_MODEL = Deno.env.get("OPENROUTER_FALLBACK_MODEL") ?? "google/gemini-2.5-flash"

const FREE_DAILY_LIMIT = 10
const SUB_DAILY_LIMIT = 100
const UPSTREAM_TIMEOUT_MS = 15_000

const ACTIVE_SUB_STATUSES = new Set(["trialing", "active", "grace"])

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

// Strict JSON schema for voice intent. Same discriminated-union pattern
// as breakdown: kind enum + sibling nullable fields, every property
// required, additionalProperties: false.
const INTENT_SCHEMA = {
  name: "IntentResponse",
  strict: true,
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["kind", "task", "tasks", "projectTitle"],
    properties: {
      kind: { type: "string", enum: ["task", "tasks", "project", "ambiguous"] },
      task: {
        anyOf: [
          { type: "null" },
          {
            type: "object",
            additionalProperties: false,
            required: ["title", "dueDate", "projectSlug", "priority"],
            properties: {
              title: { type: "string" },
              dueDate: { anyOf: [{ type: "null" }, { type: "string" }] },
              projectSlug: { anyOf: [{ type: "null" }, { type: "string" }] },
              priority: { anyOf: [{ type: "null" }, { type: "string", enum: ["urgent", "high", "normal"] }] },
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
              required: ["title", "dueDate", "projectSlug", "priority"],
              properties: {
                title: { type: "string" },
                dueDate: { anyOf: [{ type: "null" }, { type: "string" }] },
                projectSlug: { anyOf: [{ type: "null" }, { type: "string" }] },
                priority: { anyOf: [{ type: "null" }, { type: "string", enum: ["urgent", "high", "normal"] }] },
              },
            },
          },
        ],
      },
      projectTitle: { anyOf: [{ type: "null" }, { type: "string" }] },
    },
  },
}

const SYSTEM_PROMPT = `You extract structured intent from a short voice transcript for a native iOS task app called Ploot. The user just held a button and spoke; we transcribed it with Apple Speech. Your job is to figure out what they meant.

Always return every top-level field (kind, task, tasks, projectTitle). Set unused fields to null. The "kind" field determines which sibling is populated:

- kind = "task": populate task, others null.
- kind = "tasks": populate tasks array (2+ items), others null. Use for two or more distinct actions.
- kind = "project": populate projectTitle, others null. Use sparingly — only for clearly multi-step exploratory goals.
- kind = "ambiguous": ALL siblings null. Use for silence, gibberish, or cancellation phrases.

## Clean the transcript

- Strip filler ("um", "uh", "like", "yeah", "so", "well", "you know").
- Fix obvious stutter ("buy buy milk" → "buy milk").
- Lowercase, contractions, period not exclamation. Task titles 1–80 chars.

## Spoken corrections supersede earlier content

- If the transcript contains "scratch that", "no wait", "I mean", "actually", "correction": ignore content BEFORE the marker; use only what comes AFTER.
- "never mind", "forget it", "cancel that": return {"kind":"ambiguous", ...all null}.

## Classify

- **task** — one action. Action verb + specific object.
- **tasks** — multiple distinct actions joined by "and", "and also", "and then", or pauses.
- **project** — topical, exploratory, multi-step. Usually "plan", "launch", "build", "organize", "start". Be stingy — when in doubt, task.
- **ambiguous** — nothing meaningful in the transcript.

## Date resolution

Today is {TODAY} (UTC).
- "tomorrow" = today+1. "next week" = next Monday. "this weekend" = this Saturday. "in august" = August 1 of next coming August.
- "at 5" = 17:00. "at 6:30" = 18:30. "morning" = 09:00. "afternoon" = 14:00. "evening" = 18:00. "night" = 20:00. Default PM unless "am".
- "by Friday" = that Friday. "before Monday" = Sunday.
- Output a REAL ISO 8601 string like "2026-04-25T17:00:00Z". Never a placeholder like "tomorrow ISO".
- If no time/date mentioned, null.

## Project assignment

User's projects (slug — name):
{PROJECTS}

If the transcript mentions an existing project by name or strong hint ("for work", "in the home project", "for ploot app"), set projectSlug to the matching slug. Fuzzy match OK. Otherwise null.

## Priority

- "urgent", "asap", "right now", "immediately" → "urgent"
- "important", "high priority" → "high"
- Default → null

## Examples (assuming today is 2026-04-24)

Input: "buy milk tomorrow"
Output: {"kind":"task","task":{"title":"buy milk","dueDate":"2026-04-25T09:00:00Z","projectSlug":null,"priority":null},"tasks":null,"projectTitle":null}

Input: "um yeah post on tiktok for ploot app urgent"
Output: {"kind":"task","task":{"title":"post on tiktok","dueDate":null,"projectSlug":"ploot-app","priority":"urgent"},"tasks":null,"projectTitle":null}

Input: "before 3 finish the budget and also order lunch"
Output: {"kind":"tasks","task":null,"tasks":[{"title":"finish the budget","dueDate":"2026-04-24T15:00:00Z","projectSlug":null,"priority":null},{"title":"order lunch","dueDate":"2026-04-24T12:00:00Z","projectSlug":null,"priority":null}],"projectTitle":null}

Input: "plan my birthday trip to greece in august"
Output: {"kind":"project","task":null,"tasks":null,"projectTitle":"plan birthday trip to greece"}

Input: "uhhhh nevermind"
Output: {"kind":"ambiguous","task":null,"tasks":null,"projectTitle":null}

Input: "call mom — no wait, call dad"
Output: {"kind":"task","task":{"title":"call dad","dueDate":null,"projectSlug":null,"priority":null},"tasks":null,"projectTitle":null}
`

type ProjectLite = { id: string; name: string; emoji: string | null }

type ModelResponse =
  | { kind: "task"; task: { title: string; dueDate: string | null; projectSlug: string | null; priority: "urgent" | "high" | "normal" | null } }
  | { kind: "tasks"; tasks: Array<{ title: string; dueDate: string | null; projectSlug: string | null; priority: "urgent" | "high" | "normal" | null }> }
  | { kind: "project"; projectTitle: string }
  | { kind: "ambiguous" }

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS })
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405)

  const authHeader = req.headers.get("Authorization")
  if (!authHeader?.startsWith("Bearer ")) return jsonResponse({ error: "unauthorized", reason: "missing_header" }, 401)
  const jwt = authHeader.substring(7)

  const userId = await verifyJwtAndGetUserId(jwt)
  if (!userId) return jsonResponse({ error: "unauthorized", reason: "invalid_jwt" }, 401)

  let body: { transcript?: unknown }
  try { body = await req.json() } catch { return jsonResponse({ error: "invalid_json" }, 400) }

  const transcript = typeof body.transcript === "string" ? body.transcript.trim() : ""
  if (!transcript || transcript.length > 1000) return jsonResponse({ error: "invalid_transcript" }, 400)

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } })
  const today = new Date().toISOString().slice(0, 10)

  const [projectsResult, subResult] = await Promise.all([
    admin.from("projects").select("id, name, emoji").eq("owner_id", userId).is("deleted_at", null).order("sort_order"),
    admin.from("subscription_status").select("status").eq("user_id", userId).maybeSingle(),
  ])

  const isSubbed = subResult.data?.status && ACTIVE_SUB_STATUSES.has(subResult.data.status as string)
  const limit = isSubbed ? SUB_DAILY_LIMIT : FREE_DAILY_LIMIT

  const rateLimitResult = await admin.rpc("check_and_increment_usage", { p_user_id: userId, p_limit: limit })
  if (rateLimitResult.error) {
    console.error("rate-limit rpc failed", rateLimitResult.error)
    return jsonResponse({ error: "internal" }, 500)
  }
  const row = Array.isArray(rateLimitResult.data) ? rateLimitResult.data[0] : null
  const currentCount = (row?.new_count as number | undefined) ?? 0
  const allowed = (row?.allowed as boolean | undefined) ?? false

  if (!allowed) {
    const resetAt = new Date(); resetAt.setUTCHours(24, 0, 0, 0)
    return jsonResponse({ error: "rate_limited", resetAt: resetAt.toISOString(), limit, used: currentCount }, 429)
  }

  const projects = (projectsResult.data as ProjectLite[] | null) ?? []
  const projectList = projects.length
    ? projects.map((p) => `- ${p.id} — ${p.emoji ?? ""} ${p.name}`.trim()).join("\n")
    : "(none)"

  const systemPrompt = SYSTEM_PROMPT.replace("{TODAY}", today).replace("{PROJECTS}", projectList)
  const userMessage = `Transcript: ${transcript}`

  let response: ModelResponse | null = null
  let lastErrorCode = "internal"

  for (const model of [OPENROUTER_MODEL, OPENROUTER_FALLBACK_MODEL]) {
    try { response = await callOpenRouter(model, systemPrompt, userMessage); break }
    catch (err) {
      console.error(`openrouter call failed on ${model}:`, err)
      lastErrorCode = err instanceof Error && err.message.startsWith("timeout") ? "timeout" : "upstream"
    }
  }

  if (!response) return jsonResponse({ error: lastErrorCode }, 502)
  return jsonResponse(response, 200)
})

async function verifyJwtAndGetUserId(jwt: string): Promise<string | null> {
  const supa = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { auth: { persistSession: false, autoRefreshToken: false } })
  const { data, error } = await supa.auth.getUser(jwt)
  if (error || !data?.user?.id) { console.error("getUser failed", error?.message ?? "no user"); return null }
  return data.user.id
}

async function callOpenRouter(model: string, systemPrompt: string, userMessage: string): Promise<ModelResponse> {
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
        messages: [{ role: "system", content: systemPrompt }, { role: "user", content: userMessage }],
        response_format: { type: "json_schema", json_schema: INTENT_SCHEMA },
        temperature: 0.2,
        max_tokens: 400,
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
  } finally { clearTimeout(timeout) }
}

function validateModelResponse(v: unknown): ModelResponse {
  if (!v || typeof v !== "object") throw new Error("not an object")
  const obj = v as Record<string, unknown>
  const kind = obj.kind

  if (kind === "task") {
    const t = obj.task as Record<string, unknown> | null
    if (!t || typeof t.title !== "string" || t.title.trim().length === 0) throw new Error("bad task")
    return {
      kind: "task",
      task: {
        title: (t.title as string).slice(0, 120).trim(),
        dueDate: typeof t.dueDate === "string" ? t.dueDate : null,
        projectSlug: typeof t.projectSlug === "string" ? t.projectSlug : null,
        priority: normalizePriority(t.priority),
      },
    }
  }

  if (kind === "tasks") {
    const raw = Array.isArray(obj.tasks) ? obj.tasks : []
    const tasks: Array<{ title: string; dueDate: string | null; projectSlug: string | null; priority: "urgent" | "high" | "normal" | null }> = []
    for (const t of raw) {
      if (!t || typeof t !== "object") continue
      const o = t as Record<string, unknown>
      const title = typeof o.title === "string" ? o.title.trim() : ""
      if (!title) continue
      tasks.push({
        title: title.slice(0, 120),
        dueDate: typeof o.dueDate === "string" ? o.dueDate : null,
        projectSlug: typeof o.projectSlug === "string" ? o.projectSlug : null,
        priority: normalizePriority(o.priority),
      })
    }
    if (tasks.length === 0) throw new Error("no tasks")
    if (tasks.length === 1) return { kind: "task", task: tasks[0] }
    return { kind: "tasks", tasks }
  }

  if (kind === "project") {
    const title = typeof obj.projectTitle === "string" ? obj.projectTitle.trim() : ""
    if (!title) throw new Error("bad project title")
    return { kind: "project", projectTitle: title.slice(0, 120) }
  }

  if (kind === "ambiguous") return { kind: "ambiguous" }
  throw new Error(`unknown kind: ${String(kind)}`)
}

function normalizePriority(v: unknown): "urgent" | "high" | "normal" | null {
  if (v === "urgent" || v === "high" || v === "normal") return v
  return null
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } })
}
