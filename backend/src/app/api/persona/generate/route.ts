import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { store } from "@/lib/store";
import { generatePersona } from "@/engines/persona";
import type { PersonaGenerateInput } from "@/types/persona";

export const POST = withAuth(async (req, { auth }) => {
  const body = await readJson<PersonaGenerateInput>(req);
  const persona = generatePersona({
    ...body,
    profile: body.profile ?? store.profiles.get(auth.userId) ?? null,
    previousPersona: body.previousPersona ?? store.personas.get(auth.userId) ?? null,
  });
  store.personas.set(auth.userId, persona);
  return NextResponse.json({ persona });
});
