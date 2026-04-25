// =====================================================================
// FAKE engine — plan generator using static templates per top-tag.
// Mirrors `lib/logic/generate_plan.dart`. Replace with an LLM call for
// truly personalised plans.
// =====================================================================

import type { Plan } from "@/types/plan";
import type { Persona } from "@/types/persona";
import { getRoleCardById } from "@/data/roles";
import { PLAN_HEADLINES, PLAN_TEMPLATES, pickPlanKey } from "@/data/planTemplates";

export function generatePlan(opts: {
  mode: "career" | "startup";
  likedRoleIds: string[];
  persona?: Persona | null;
}): Plan {
  if (opts.mode === "startup") {
    return {
      headline: PLAN_HEADLINES.startup,
      basedOnTopTags: [{ tag: "startup", score: opts.likedRoleIds.length || 1 }],
      recommendedRoles: [getRoleCardById("founder")!].filter(Boolean),
      weeks: PLAN_TEMPLATES.startup,
    };
  }

  const tagCount = new Map<string, number>();
  for (const id of opts.likedRoleIds) {
    const card = getRoleCardById(id);
    if (!card) continue;
    for (const tag of card.tags) tagCount.set(tag, (tagCount.get(tag) ?? 0) + 1);
  }
  const sorted = [...tagCount.entries()].sort((a, b) => b[1] - a[1]);
  const top = sorted[0]?.[0] ?? null;
  const key = pickPlanKey(top);

  const recommendedRoles = opts.likedRoleIds
    .map((id) => getRoleCardById(id))
    .filter((c): c is NonNullable<typeof c> => Boolean(c))
    .slice(0, 3);

  return {
    headline: PLAN_HEADLINES[key],
    basedOnTopTags: sorted.slice(0, 3).map(([tag, score]) => ({ tag, score })),
    recommendedRoles,
    weeks: PLAN_TEMPLATES[key],
  };
}
