// =====================================================================
// Pure helpers for Skill Gap Analysis (no I/O, unit-testable)
// =====================================================================

export type Importance = "high" | "medium" | "low";
export type SkillStatus = "matched" | "partial" | "missing";

export type RequiredSkill = {
  skill: string;
  category: string;     // technical | tool | soft | domain | certification
  importance: Importance;
  status: SkillStatus;
  evidence: string;     // where the applicant shows it (matched / partial)
  gap: string;          // what is missing (partial / missing)
};

const WEIGHT: Record<Importance, number> = { high: 3, medium: 2, low: 1 };
const CREDIT: Record<SkillStatus, number> = { matched: 1, partial: 0.5, missing: 0 };

export function normaliseImportance(v: unknown): Importance {
  return v === "high" || v === "low" ? v : "medium";
}

export function normaliseStatus(v: unknown): SkillStatus {
  return v === "matched" || v === "partial" ? v : "missing";
}

/**
 * Match score 0-100: importance-weighted share of required skills the applicant has.
 * matched = full credit, partial = half credit. Calculated here (not by the AI) so it is
 * consistent and explainable.
 */
export function calculateMatchScore(skills: RequiredSkill[]): number {
  let total = 0;
  let earned = 0;
  for (const s of skills) {
    const w = WEIGHT[s.importance] ?? 2;
    total += w;
    earned += w * (CREDIT[s.status] ?? 0);
  }
  return total === 0 ? 0 : Math.round((earned / total) * 100);
}

export function splitByStatus(skills: RequiredSkill[]) {
  const order: Record<Importance, number> = { high: 0, medium: 1, low: 2 };
  const byPriority = (a: RequiredSkill, b: RequiredSkill) => order[a.importance] - order[b.importance];
  return {
    matching: skills.filter((s) => s.status === "matched").sort(byPriority),
    partial: skills.filter((s) => s.status === "partial").sort(byPriority),
    missing: skills.filter((s) => s.status === "missing").sort(byPriority),
  };
}

/** Keywords from a role title for searching Job postings, e.g. "Junior Flutter Developer" -> ["flutter","developer"]. */
const STOP_WORDS = new Set([
  "junior", "senior", "intern", "internship", "trainee", "lead", "head", "the", "and", "for", "of",
  "assistant", "associate", "entry", "level", "graduate", "fresh", "part", "time", "full", "remote",
]);

export function roleKeywords(role: string): string[] {
  const words = role
    .toLowerCase()
    .replace(/[^a-z0-9+#\s]/g, " ")
    .split(/\s+/)
    .map((w) => w.replace(/[^a-z0-9]/g, "")) // PostgREST filter-safe
    .filter((w) => w.length >= 3 && !STOP_WORDS.has(w));
  return [...new Set(words)].slice(0, 4);
}
