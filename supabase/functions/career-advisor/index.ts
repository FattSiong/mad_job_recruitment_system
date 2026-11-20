// =====================================================================
// career-advisor  —  Career Buddy, the AI career chat (Use Case 4.58)
//
// Request  (POST, Authorization: Bearer <user access token>)
//   { "message": "How do I move into data analytics?", "conversationId": "<uuid>" | null,
//     "requestId": "<uuid>" }   // optional, one per question (see below)
//
// requestId: the app makes one per question and sends it again if it asks
// the same question after a timeout. When that question was already
// answered, the saved answer is returned (no second AI call, nothing saved
// twice). Needs migration 20261120000000_advisor_request_id; without it the
// ID is ignored.
//
// Response 200
//   {
//     "conversationId": "<uuid>",
//     "userMessage":  { messageID, conversationID, role: "user",  content, createdAt },
//     "reply":        { messageID, conversationID, role: "model", content, createdAt }
//   }
//
// Errors   { "error": "<code>", "message": "<safe text for the UI>" }
//   400 empty_message | message_too_long | bad_request
//   401 unauthorized      403 not_job_seeker      404 conversation_not_found
//   429 rate_limited      502/504 ai_unavailable  500 server_error
//
// Secrets (supabase secrets set ...):
//   GEMINI_API_KEY   required
//   GEMINI_MODEL     optional, default below
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are provided automatically.
// =====================================================================

import { createClient, SupabaseClient } from "@supabase/supabase-js";

const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.5-flash-lite";
const GEMINI_TIMEOUT_MS = 25_000;
const MAX_MESSAGE_CHARS = 2000;
const HISTORY_LIMIT = 10;          // previous messages sent to Gemini as context
const RATE_LIMIT_PER_MINUTE = 15;  // user messages per minute
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function fail(status: number, error: string, message: string): Response {
  return json({ error, message }, status);
}

type SavedMessage = { messageID: string; conversationID: string; role: string; content: string; createdAt: string };
type SavedTurn = { conversationId: string; userMessage: SavedMessage; reply: SavedMessage };

const MESSAGE_COLUMNS = "messageID, conversationID, role, content, createdAt";

/** Postgres / PostgREST codes for "the requestID column doesn't exist yet". */
function isMissingRequestColumn(error: { code?: string } | null): boolean {
  return error?.code === "42703" || error?.code === "PGRST204";
}

/**
 * The question saved earlier with [requestID] and the answer saved with it,
 * null when there is none yet, or "unsupported" before the migration.
 */
async function findSavedTurn(
  supabase: SupabaseClient,
  seekerID: string,
  requestID: string,
): Promise<SavedTurn | null | "unsupported"> {
  const { data: user, error } = await supabase
    .from("AdvisorMessage")
    .select(MESSAGE_COLUMNS)
    .eq("seekerID", seekerID)
    .eq("requestID", requestID)
    .eq("role", "user")
    .maybeSingle();
  if (isMissingRequestColumn(error)) return "unsupported";
  if (error) throw error;
  if (!user) return null;

  const { data: reply, error: replyErr } = await supabase
    .from("AdvisorMessage")
    .select(MESSAGE_COLUMNS)
    .eq("conversationID", user.conversationID)
    .eq("role", "model")
    .gt("createdAt", user.createdAt)
    .order("createdAt", { ascending: true })
    .limit(1)
    .maybeSingle();
  if (replyErr) throw replyErr;
  if (!reply) return null;
  return { conversationId: user.conversationID, userMessage: user as SavedMessage, reply: reply as SavedMessage };
}

/** The conversation doesn't exist (any more); the app then starts a new one. */
function conversationGone(): Response {
  return fail(404, "conversation_not_found", "This conversation no longer exists.");
}

// ---------------------------------------------------------------------
// System prompt
// ---------------------------------------------------------------------
const SYSTEM_PROMPT = `
You are "Career Buddy", the AI career assistant inside a Malaysian job recruitment app.
You help job seekers with career planning, job search strategy, resumes, interviews,
skill development, certifications and industry insights, with a focus on the Malaysian job market.

Rules:
- Use the applicant profile below to personalise advice. Do not repeat the profile back to them.
- If the profile is missing something you need, ask one short follow-up question.
- Be practical: give concrete next steps. Keep replies under about 250 words unless the user asks for more.
- Format as plain text. You may use short "- " bullet lists. Do not use markdown headings, tables or bold.
- Reply in the same language the user writes in.
- Only discuss career-related topics. If asked something unrelated, politely steer back to careers.
- Do not invent specific facts such as exact salaries for named companies or job openings that may not exist.
  When giving salary ranges, say they are estimates.
- Never ask for or reveal sensitive personal data (IC number, passwords, bank details).
`.trim();

// ---------------------------------------------------------------------
// Profile context (data minimisation: no name, email, phone, links)
// ---------------------------------------------------------------------
type ProfileRow = {
  bio: string | null;
  location: string | null;
  careerGoal: string | null;
  Skill: { skillName: string; proficiency: string | null }[];
  Education: {
    degree: string;
    fieldOfStudy: string | null;
    startDate: string;
    endDate: string | null;
    isCurrent: boolean;
  }[];
  WorkExperience: {
    jobTitle: string;
    startDate: string;
    endDate: string | null;
    isCurrent: boolean;
    description: string | null;
  }[];
};

function yearOf(date: string | null): string {
  return date ? date.slice(0, 4) : "";
}

function truncate(text: string | null, max: number): string {
  if (!text) return "";
  const t = text.trim();
  return t.length > max ? t.slice(0, max) + "…" : t;
}

function buildProfileContext(p: ProfileRow | null): string {
  if (!p) return "No profile information available.";

  const lines: string[] = [];
  if (p.careerGoal) lines.push(`Career goal: ${truncate(p.careerGoal, 300)}`);
  if (p.location) lines.push(`Location: ${p.location}`);
  if (p.bio) lines.push(`About: ${truncate(p.bio, 400)}`);

  lines.push(
    "Skills: " +
      (p.Skill?.length
        ? p.Skill.map((s) => (s.proficiency ? `${s.skillName} (${s.proficiency})` : s.skillName)).join(", ")
        : "none listed"),
  );

  lines.push("Education:");
  if (p.Education?.length) {
    for (const e of p.Education) {
      const field = e.fieldOfStudy ? ` in ${e.fieldOfStudy}` : "";
      const end = e.isCurrent ? "present" : yearOf(e.endDate);
      lines.push(`- ${e.degree}${field} (${yearOf(e.startDate)}–${end})`);
    }
  } else {
    lines.push("- none listed");
  }

  lines.push("Work experience:");
  if (p.WorkExperience?.length) {
    for (const w of p.WorkExperience) {
      const end = w.isCurrent ? "present" : yearOf(w.endDate);
      const desc = w.description ? `: ${truncate(w.description, 200)}` : "";
      lines.push(`- ${w.jobTitle} (${yearOf(w.startDate)}–${end})${desc}`);
    }
  } else {
    lines.push("- none listed");
  }

  return lines.join("\n");
}

// ---------------------------------------------------------------------
// Gemini call
// ---------------------------------------------------------------------
type GeminiContent = { role: "user" | "model"; parts: { text: string }[] };

class AiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

async function callGemini(systemText: string, contents: GeminiContent[]): Promise<string> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) throw new AiError(500, "GEMINI_API_KEY is not set");

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), GEMINI_TIMEOUT_MS);

  let res: Response;
  try {
    res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
      {
        method: "POST",
        signal: controller.signal,
        headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
        body: JSON.stringify({
          system_instruction: { parts: [{ text: systemText }] },
          contents,
          generationConfig: { temperature: 0.7 },
        }),
      },
    );
  } catch (e) {
    if (e instanceof DOMException && e.name === "AbortError") {
      throw new AiError(504, "Gemini request timed out");
    }
    throw new AiError(502, `Gemini network error: ${e}`);
  } finally {
    clearTimeout(timer);
  }

  if (!res.ok) {
    // Logged server-side only, never returned to the app
    throw new AiError(502, `Gemini HTTP ${res.status}: ${await res.text()}`);
  }

  const data = await res.json();
  const parts: { text?: string; thought?: boolean }[] = data?.candidates?.[0]?.content?.parts ?? [];
  const text = parts
    .filter((p) => !p.thought && typeof p.text === "string")
    .map((p) => p.text)
    .join("")
    .trim();

  if (!text) {
    const reason = data?.promptFeedback?.blockReason ?? data?.candidates?.[0]?.finishReason ?? "unknown";
    throw new AiError(502, `Gemini returned no text (reason: ${reason})`);
  }
  return text;
}

// ---------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "method_not_allowed", "Use POST.");

  const supabase: SupabaseClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  try {
    // 1. Authenticate --------------------------------------------------
    const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
    if (!token) return fail(401, "unauthorized", "Please log in again.");

    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !userData?.user) return fail(401, "unauthorized", "Please log in again.");
    const seekerID = userData.user.id;

    // 2. Validate input (Use case A2: empty message) ---------------------
    let body: { message?: unknown; conversationId?: unknown; requestId?: unknown };
    try {
      body = await req.json();
    } catch {
      return fail(400, "bad_request", "Invalid request.");
    }
    const message = typeof body.message === "string" ? body.message.trim() : "";
    const conversationIdIn =
      typeof body.conversationId === "string" && body.conversationId.length > 0 ? body.conversationId : null;
    const requestIdIn =
      typeof body.requestId === "string" && UUID_RE.test(body.requestId) ? body.requestId : null;

    if (!message) return fail(400, "empty_message", "Please enter a question for Career Buddy.");
    if (message.length > MAX_MESSAGE_CHARS) {
      return fail(400, "message_too_long", `Please keep your message under ${MAX_MESSAGE_CHARS} characters.`);
    }

    // 3. Load profile (also confirms the user is a job seeker) ----------
    const { data: profile, error: profileErr } = await supabase
      .from("JobSeeker")
      .select(
        `bio, location, careerGoal,
         Skill ( skillName, proficiency ),
         Education ( degree, fieldOfStudy, startDate, endDate, isCurrent ),
         WorkExperience ( jobTitle, startDate, endDate, isCurrent, description )`,
      )
      .eq("seekerID", seekerID)
      .maybeSingle();
    if (profileErr) throw profileErr;
    if (!profile) return fail(403, "not_job_seeker", "Career Buddy is only available for job seekers.");

    // 4. Same question sent again (the app timed out): return the saved answer.
    //    Checked before the rate limit, so this never counts as a new message.
    let useRequestId = requestIdIn !== null;
    if (requestIdIn) {
      const saved = await findSavedTurn(supabase, seekerID, requestIdIn);
      if (saved === "unsupported") useRequestId = false;
      else if (saved) return json(saved);
    }

    // 5. Simple rate limit -----------------------------------------------
    const oneMinuteAgo = new Date(Date.now() - 60_000).toISOString();
    const { count: recentCount, error: rateErr } = await supabase
      .from("AdvisorMessage")
      .select("messageID", { count: "exact", head: true })
      .eq("seekerID", seekerID)
      .eq("role", "user")
      .gte("createdAt", oneMinuteAgo);
    if (rateErr) throw rateErr;
    if ((recentCount ?? 0) >= RATE_LIMIT_PER_MINUTE) {
      return fail(429, "rate_limited", "You're sending messages too quickly. Please wait a moment.");
    }

    // 6. Existing conversation: check ownership + load history ----------
    let history: GeminiContent[] = [];
    if (conversationIdIn) {
      // Not an ID we could have made (a bad ID would fail in the database)
      if (!UUID_RE.test(conversationIdIn)) return conversationGone();
      const { data: conv, error: convErr } = await supabase
        .from("AdvisorConversation")
        .select("conversationID")
        .eq("conversationID", conversationIdIn)
        .eq("seekerID", seekerID)
        .maybeSingle();
      if (convErr) throw convErr;
      if (!conv) return conversationGone();

      const { data: rows, error: histErr } = await supabase
        .from("AdvisorMessage")
        .select("role, content")
        .eq("conversationID", conversationIdIn)
        .order("createdAt", { ascending: false })
        .limit(HISTORY_LIMIT);
      if (histErr) throw histErr;

      history = (rows ?? [])
        .reverse()
        .map((r: { role: string; content: string }) => ({
          role: r.role as "user" | "model",
          parts: [{ text: r.content }],
        }));
      // Gemini expects the history to start with a user turn
      while (history.length && history[0].role !== "user") history.shift();
    }

    // 7. Ask Gemini (nothing is saved if this fails -> use case A1) ------
    const systemText = `${SYSTEM_PROMPT}\n\nApplicant profile:\n${buildProfileContext(profile as ProfileRow)}`;
    const reply = await callGemini(systemText, [
      ...history,
      { role: "user", parts: [{ text: message }] },
    ]);

    // 8. Create the conversation on first message -----------------------
    let conversationID = conversationIdIn;
    if (!conversationID) {
      const title = message.length > 50 ? message.slice(0, 50).trimEnd() + "…" : message;
      const { data: newConv, error: newConvErr } = await supabase
        .from("AdvisorConversation")
        .insert({ seekerID, title })
        .select("conversationID")
        .single();
      if (newConvErr) throw newConvErr;
      conversationID = newConv.conversationID as string;
    }

    // 9. Save both turns (explicit timestamps keep the order stable) ----
    const now = Date.now();
    const turns = (withRequestId: boolean) => [
      {
        conversationID, seekerID, role: "user", content: message, createdAt: new Date(now).toISOString(),
        ...(withRequestId ? { requestID: requestIdIn } : {}),
      },
      { conversationID, seekerID, role: "model", content: reply, createdAt: new Date(now + 1).toISOString() },
    ];
    let { data: saved, error: saveErr } = await supabase
      .from("AdvisorMessage")
      .insert(turns(useRequestId))
      .select(MESSAGE_COLUMNS);
    if (useRequestId && isMissingRequestColumn(saveErr)) {
      // The column went away (or the cache is behind): save without the ID
      ({ data: saved, error: saveErr } = await supabase
        .from("AdvisorMessage")
        .insert(turns(false))
        .select(MESSAGE_COLUMNS));
    }
    // 23505: another attempt of this same question was saved first. Use that
    // one, and drop the conversation this attempt created for it (if any).
    if (saveErr?.code === "23505" && requestIdIn) {
      if (!conversationIdIn) {
        await supabase.from("AdvisorConversation").delete().eq("conversationID", conversationID);
      }
      const first = await findSavedTurn(supabase, seekerID, requestIdIn);
      if (first && first !== "unsupported") return json(first);
    }
    // 23503: the conversation was deleted while Gemini was answering
    if (saveErr?.code === "23503") return conversationGone();
    if (saveErr) throw saveErr;

    const { error: touchErr } = await supabase
      .from("AdvisorConversation")
      .update({ updatedAt: new Date(now + 1).toISOString() })
      .eq("conversationID", conversationID);
    if (touchErr) console.error("updatedAt touch failed:", touchErr);

    const savedRows = (saved ?? []) as SavedMessage[];
    const userMessage = savedRows.find((m) => m.role === "user");
    const modelMessage = savedRows.find((m) => m.role === "model");

    return json({ conversationId: conversationID, userMessage, reply: modelMessage });
  } catch (e) {
    if (e instanceof AiError) {
      console.error("[career-advisor] AI error:", e.message);
      return fail(
        e.status === 504 ? 504 : 502,
        "ai_unavailable",
        "Career Buddy is currently unavailable. Please try again later.",
      );
    }
    console.error("[career-advisor] server error:", e);
    return fail(500, "server_error", "Something went wrong. Please try again.");
  }
});
