import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";
import { generatePersona } from "@/engines/persona";
import { buildSwipeSummary } from "@/lib/swipeSummary";
import type { SkillTranslation } from "@/types/skill";

export const POST = withAuth(async (req, { auth }) => {
  const body = await readJson<SkillTranslation>(req);
  if (!body?.id || !body.groups) return apiError("bad_request", "Translation payload required.");

  const list = store.translations.get(auth.userId) ?? [];
  const idx = list.findIndex((t) => t.id === body.id);
  if (idx >= 0) list[idx] = body;
  else list.push(body);
  store.translations.set(auth.userId, list);

  const summary = buildSwipeSummary(store.swipes.get(auth.userId) ?? []);
  const updatedPersona = generatePersona({
    profile: store.profiles.get(auth.userId) ?? null,
    explore: { likedRoleIds: summary.likedRoleIds, dislikedRoleIds: summary.dislikedRoleIds },
    skillTranslations: list.map((t) => ({ rawExperience: t.rawExperience, groups: t.groups })),
    previousPersona: store.personas.get(auth.userId) ?? null,
  });
  store.personas.set(auth.userId, updatedPersona);

  return NextResponse.json({ translationId: body.id, updatedPersona });
});
