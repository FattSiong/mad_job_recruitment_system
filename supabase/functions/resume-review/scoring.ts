// =====================================================================
// Pure helpers for the AI Resume Assistant (no I/O, unit-testable)
// =====================================================================

export type Priority = "high" | "medium" | "low";

export type CategoryKey = "content" | "impact" | "keywords" | "structure" | "writing";

/** The five areas every resume is scored on, and how much each counts. */
export const CATEGORIES: { key: CategoryKey; label: string; weight: number }[] = [
  { key: "content", label: "Content & Completeness", weight: 0.25 },
  { key: "impact", label: "Impact & Achievements", weight: 0.25 },
  { key: "keywords", label: "Keywords & ATS", weight: 0.2 },
  { key: "structure", label: "Structure & Formatting", weight: 0.15 },
  { key: "writing", label: "Writing & Clarity", weight: 0.15 },
];

export type CategoryScore = { key: CategoryKey; label: string; score: number; comment: string };

export type Improvement = {
  priority: Priority;
  section: string;
  issue: string;
  suggestion: string;
  before: string;
  after: string;
};

export function clampScore(v: unknown): number {
  const n = typeof v === "number" ? v : Number(v);
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(100, Math.round(n)));
}

export function normalisePriority(v: unknown): Priority {
  return v === "high" || v === "low" ? v : "medium";
}

/**
 * Always returns the five categories in a fixed order. A category the AI left
 * out gets score 0 and an empty comment, so the overall score stays honest.
 */
export function normaliseCategories(
  raw: { key?: unknown; score?: unknown; comment?: unknown }[] | undefined,
): CategoryScore[] {
  const byKey = new Map<string, { score?: unknown; comment?: unknown }>();
  for (const c of raw ?? []) {
    if (typeof c?.key === "string") byKey.set(c.key, c);
  }
  return CATEGORIES.map(({ key, label }) => {
    const c = byKey.get(key);
    return {
      key,
      label,
      score: clampScore(c?.score),
      comment: typeof c?.comment === "string" ? c.comment.trim() : "",
    };
  });
}

/**
 * Overall score 0-100: weighted average of the category scores. Calculated
 * here (not by the AI) so it is consistent and explainable.
 */
export function overallScore(categories: CategoryScore[]): number {
  let total = 0;
  let weights = 0;
  for (const c of categories) {
    const w = CATEGORIES.find((x) => x.key === c.key)?.weight ?? 0;
    total += c.score * w;
    weights += w;
  }
  return weights === 0 ? 0 : Math.round(total / weights);
}

/** High priority first, keeping the AI's order inside each priority. */
export function sortImprovements(items: Improvement[]): Improvement[] {
  const order: Record<Priority, number> = { high: 0, medium: 1, low: 2 };
  return items
    .map((item, i) => ({ item, i }))
    .sort((a, b) => order[a.item.priority] - order[b.item.priority] || a.i - b.i)
    .map((x) => x.item);
}

export function scoreLabel(score: number): string {
  if (score >= 85) return "Excellent";
  if (score >= 70) return "Good";
  if (score >= 50) return "Fair";
  return "Needs work";
}

/** Keywords from a role title for searching Job postings, e.g. "Junior Flutter Developer" -> ["flutter","developer"]. */
const STOP_WORDS = new Set([
  "junior", "senior", "intern", "internship", "trainee", "lead", "head", "the", "and", "for", "of",
  "assistant", "associate", "entry", "level", "graduate", "fresh", "part", "time", "full", "remote",
]);

export function roleKeywords(role: string): string[] {
  return [...new Set(
    role.toLowerCase()
      .replace(/[^a-z0-9+#/ ]/g, " ")
      .split(/[\s/]+/)
      .filter((w) => w.length >= 2 && !STOP_WORDS.has(w)),
  )].slice(0, 4);
}

/** "1730000000_My Resume.pdf" -> "My Resume.pdf" */
export function displayFileName(fileName: string): string {
  const i = fileName.indexOf("_");
  return i > 0 && /^\d+$/.test(fileName.slice(0, i)) ? fileName.slice(i + 1) : fileName;
}
