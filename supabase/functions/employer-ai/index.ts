// =====================================================================
// employer-ai  —  Server-side Gemini proxy for Employer AI features
//
// Keeps GEMINI_API_KEY strictly on the server (Supabase Edge Function
// secrets) so no API key is ever bundled inside the Flutter client APK.
//
// Powers all 6 Employer AI features:
//   1. AI Salary Suggestion (getAiSalarySuggestion)
//   2. AI Pre-Screening Question Generator (generateAiQuestion)
//   3. AI Candidate Resume & Profile Ranking (rankApplicantWithAI)
//   4. AI Auto-Grade Pre-Screening Answers 0–5 (autoGradeApplicantAnswersWithAI)
//   5. AI Offer Letter Draft (generateOfferLetterWithAI)
//   6. Post-Interview Audio & Multimodal AI Report (generatePostInterviewAiReport)
//
// Request (POST, Authorization: Bearer <user access token>):
//   {
//     "prompt": "<string>",
//     "inlineParts"?: [{ "mimeType": "application/pdf" | "audio/aac", "data": "<base64>" }],
//     "responseMimeType"?: "application/json",
//     "temperature"?: 0.3
//   }
//
// Response 200:
//   { "text": "<Gemini output string>" }
//
// Secrets:
//   GEMINI_API_KEY (required)
//   GEMINI_MODEL   (optional, defaults to "gemini-3-flash-preview")
// =====================================================================

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3-flash-preview";
const GEMINI_TIMEOUT_MS = 90_000;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
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

interface InlinePart {
  mimeType: string;
  data: string;
}

interface EmployerAiRequest {
  prompt?: unknown;
  inlineParts?: unknown;
  responseMimeType?: unknown;
  temperature?: unknown;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return fail(405, "method_not_allowed", "Use POST.");
  }

  const supabase: SupabaseClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  try {
    // 1. Authenticate caller
    const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
    if (!token) {
      return fail(401, "unauthorized", "Please log in again.");
    }

    const { data: userData, error: userErr } = await supabase.auth.getUser(
      token,
    );
    if (userErr || !userData?.user) {
      return fail(401, "unauthorized", "Please log in again.");
    }
    const userId = userData.user.id;

    // 2. Verify caller is an Employer or Admin
    const [{ data: employerRow }, { data: userRow }] = await Promise.all([
      supabase
        .from("Employer")
        .select("employerID")
        .eq("employerID", userId)
        .maybeSingle(),
      supabase
        .from("User")
        .select("role")
        .eq("userID", userId)
        .maybeSingle(),
    ]);

    const role = (userRow?.role ?? "").toString().toLowerCase();
    if (!employerRow && role !== "employer" && role !== "admin") {
      return fail(
        403,
        "forbidden",
        "Employer AI features are only available to employers.",
      );
    }

    // 3. Parse request body
    let body: EmployerAiRequest;
    try {
      body = await req.json();
    } catch {
      return fail(400, "bad_request", "Invalid JSON payload.");
    }

    const prompt = typeof body.prompt === "string" ? body.prompt.trim() : "";
    if (!prompt) {
      return fail(400, "empty_prompt", "Prompt is required.");
    }

    const rawParts = Array.isArray(body.inlineParts) ? body.inlineParts : [];
    const inlineParts: InlinePart[] = [];
    for (const item of rawParts) {
      if (
        item &&
        typeof item === "object" &&
        typeof (item as InlinePart).mimeType === "string" &&
        typeof (item as InlinePart).data === "string"
      ) {
        const mimeType = (item as InlinePart).mimeType.trim();
        const data = (item as InlinePart).data.trim();
        if (mimeType && data) {
          inlineParts.push({ mimeType, data });
        }
      }
    }

    const responseMimeType =
      typeof body.responseMimeType === "string" &&
      body.responseMimeType.trim().length > 0
        ? body.responseMimeType.trim()
        : undefined;

    const temperature =
      typeof body.temperature === "number" &&
      Number.isFinite(body.temperature)
        ? body.temperature
        : undefined;

    // 4. Call Gemini API using server-side GEMINI_API_KEY
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      console.error("[employer-ai] GEMINI_API_KEY secret is not configured");
      return fail(
        500,
        "not_configured",
        "AI service key is not configured on the server.",
      );
    }

    const geminiParts: Record<string, unknown>[] = [{ text: prompt }];
    for (const part of inlineParts) {
      geminiParts.push({
        inline_data: {
          mime_type: part.mimeType,
          data: part.data,
        },
      });
    }

    const generationConfig: Record<string, unknown> = {};
    if (responseMimeType) {
      generationConfig.responseMimeType = responseMimeType;
    }
    if (temperature !== undefined) {
      generationConfig.temperature = temperature;
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), GEMINI_TIMEOUT_MS);

    let res: Response;
    try {
      res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
        {
          method: "POST",
          signal: controller.signal,
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": apiKey,
          },
          body: JSON.stringify({
            contents: [{ role: "user", parts: geminiParts }],
            ...(Object.keys(generationConfig).length > 0
              ? { generationConfig }
              : {}),
          }),
        },
      );
    } catch (e) {
      if (e instanceof DOMException && e.name === "AbortError") {
        return fail(504, "ai_timeout", "AI request timed out.");
      }
      console.error("[employer-ai] network error:", e);
      return fail(502, "ai_unavailable", "AI service is currently unavailable.");
    } finally {
      clearTimeout(timer);
    }

    if (!res.ok) {
      console.error(
        `[employer-ai] Gemini HTTP ${res.status}: ${await res.text()}`,
      );
      return fail(502, "ai_unavailable", "AI service returned an error.");
    }

    const data = await res.json();
    const candidateParts: { text?: string; thought?: boolean }[] =
      data?.candidates?.[0]?.content?.parts ?? [];
    const text = candidateParts
      .filter((p) => !p.thought && typeof p.text === "string")
      .map((p) => p.text)
      .join("")
      .trim();

    if (!text) {
      return fail(502, "ai_empty", "AI returned an empty response.");
    }

    return json({ text });
  } catch (e) {
    console.error("[employer-ai] unexpected error:", e);
    return fail(500, "server_error", "Something went wrong. Please try again.");
  }
});
