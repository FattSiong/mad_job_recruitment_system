// =====================================================================
// Body language cues from the camera (optional, feedback only)
//
// The app estimates these on the phone with Google ML Kit while the user
// answers with the camera on, and sends only the numbers:
//   face: { sampleCount, facePresentPercent, eyeContactPercent|null,
//           smilePercent|null, lookAwayCount }
// They are NOT given to the scoring prompt and NOT part of any score.
// The feedback sentences are rule based, so they only ever describe what
// was measured (no guessing of emotions or personality).
// =====================================================================

export type FaceMetrics = {
  sampleCount: number;
  facePresentPercent: number;
  eyeContactPercent: number | null;
  smilePercent: number | null;
  lookAwayCount: number;
};

export type BodyLanguageSummary = {
  answersWithCamera: number;
  eyeContactPercent: number | null;
  smilePercent: number | null;
  totalLookAways: number;
  feedback: string;
};

/** The columns saved per answer (any of them may be null). */
export type FaceRow = {
  eyeContactPercent: number | null;
  smilePercent: number | null;
  facePresentPercent: number | null;
  lookAwayCount: number | null;
};

const isInt = (v: unknown, min: number, max: number): v is number =>
  typeof v === "number" && Number.isInteger(v) && v >= min && v <= max;

/**
 * Validates the optional `face` object sent by the app.
 * Anything malformed is ignored (returns null) so a bad camera reading never
 * stops the answer from being evaluated.
 */
export function parseFaceMetrics(raw: unknown): FaceMetrics | null {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
  const f = raw as Record<string, unknown>;
  if (!isInt(f.sampleCount, 1, 5000)) return null; // 3 per second for 3 minutes is ~540
  if (!isInt(f.facePresentPercent, 0, 100)) return null;
  if (!isInt(f.lookAwayCount, 0, 1000)) return null;
  const optionalPercent = (v: unknown) => (v === null || v === undefined ? null : isInt(v, 0, 100) ? v : undefined);
  const eye = optionalPercent(f.eyeContactPercent);
  const smile = optionalPercent(f.smilePercent);
  if (eye === undefined || smile === undefined) return null;
  return {
    sampleCount: f.sampleCount,
    facePresentPercent: f.facePresentPercent,
    eyeContactPercent: eye,
    smilePercent: smile,
    lookAwayCount: f.lookAwayCount,
  };
}

const lookAwayText = (n: number) => (n === 1 ? "once" : `${n} times`);

/** Eye contact + smile sentence(s), shared by the per-answer and overall feedback. */
function describe(
  eye: number | null, smile: number | null, facePresent: number, lookAways: number, scope: string,
): string {
  if (facePresent < 50 || eye === null) {
    return `Your face was out of the camera view for much of ${scope}. ` +
      "Keep the phone at eye level, about an arm's length away, so the interviewer can see you.";
  }

  let eyeText: string;
  if (eye >= 75) {
    eyeText = `Good eye contact: you faced the camera ${eye}% of the time.`;
  } else if (eye >= 50) {
    eyeText = `You faced the camera ${eye}% of the time and looked away ${lookAwayText(lookAways)}. ` +
      "It's fine to glance away while thinking, but bring your eyes back to the camera as you answer.";
  } else {
    eyeText = `You looked away from the camera most of the time (${eye}% eye contact). ` +
      "Try speaking to the camera lens as if it were the interviewer.";
  }

  if (smile === null) return eyeText;
  if (smile >= 30) return `${eyeText} A friendly, smiling expression came through.`;
  if (smile < 10) return `${eyeText} A natural smile when you greet and finish can make you look more approachable.`;
  return eyeText;
}

/** One or two sentences for one answer (null when the camera was off). */
export function bodyLanguageFeedback(f: FaceMetrics | null): string | null {
  if (!f) return null;
  return describe(f.eyeContactPercent, f.smilePercent, f.facePresentPercent, f.lookAwayCount, "this answer");
}

const avgRounded = (xs: number[]) =>
  xs.length ? Math.round(xs.reduce((a, b) => a + b, 0) / xs.length) : null;

/**
 * Overall cues for the scorecard: averages over the answers recorded with the
 * camera on. Null when the camera was never on.
 */
export function summarizeBodyLanguage(rows: FaceRow[]): BodyLanguageSummary | null {
  const withCamera = rows.filter((r) => r.facePresentPercent !== null && r.facePresentPercent !== undefined);
  if (withCamera.length === 0) return null;

  const nums = (xs: (number | null)[]) => xs.filter((x): x is number => typeof x === "number");
  const eye = avgRounded(nums(withCamera.map((r) => r.eyeContactPercent)));
  const smile = avgRounded(nums(withCamera.map((r) => r.smilePercent)));
  const facePresent = avgRounded(nums(withCamera.map((r) => r.facePresentPercent))) ?? 0;
  const totalLookAways = withCamera.reduce((s, r) => s + (r.lookAwayCount ?? 0), 0);

  return {
    answersWithCamera: withCamera.length,
    eyeContactPercent: eye,
    smilePercent: smile,
    totalLookAways,
    feedback: describe(eye, smile, facePresent, totalLookAways, "the interview"),
  };
}

/** Line for the final summary prompt (tips only, the scores are already fixed). */
export function bodyLanguageForPrompt(b: BodyLanguageSummary | null, totalAnswers: number): string {
  if (!b) return "Camera cues: camera was off (do not mention eye contact or facial expression).";
  return `Camera cues (measured on the phone, feedback only, NOT part of the scores; ` +
    `${b.answersWithCamera} of ${totalAnswers} answers): ` +
    `faced the camera ${b.eyeContactPercent ?? "unknown"}% of the time, ` +
    `smiling ${b.smilePercent ?? "unknown"}% of the time, looked away ${b.totalLookAways} times in total.`;
}
