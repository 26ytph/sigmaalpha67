import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { store } from "@/lib/store";
import { generatePlan } from "@/engines/planGenerator";
import { buildSwipeSummary } from "@/lib/swipeSummary";
import type { Persona } from "@/types/persona";

type Body = {
  mode?: "career" | "startup";
  likedRoleIds?: string[];
  persona?: Persona;
};

export const POST = withAuth(async (req, { auth }) => {
  const body = (await readJson<Body>(req)) ?? {};
  const mode = body.mode ?? "career";

  const liked =
    body.likedRoleIds ??
    buildSwipeSummary(store.swipes.get(auth.userId) ?? []).likedRoleIds;

  const plan = generatePlan({
    mode,
    likedRoleIds: liked,
    persona: body.persona ?? store.personas.get(auth.userId) ?? null,
  });

  const existing = store.plans.get(auth.userId);
  store.plans.set(auth.userId, {
    plan,
    todos: existing?.todos ?? {},
    weekNotes: existing?.weekNotes ?? {},
    generatedAt: new Date().toISOString(),
  });

  return NextResponse.json({ plan });
});
