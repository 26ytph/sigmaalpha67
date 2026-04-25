import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";
import * as db from "@/lib/db";
import type { Persona } from "@/types/persona";

// 2.3 — user manually edits persona text.
export const PUT = withAuth(async (req, { auth }) => {
  const body = await readJson<{ text?: string; userEdited?: boolean }>(req);
  if (body?.text === undefined) {
    return apiError("bad_request", "`text` is required.");
  }
  const existing = store.personas.get(auth.userId);
  if (!existing) {
    return apiError(
      "not_found",
      "Persona not yet generated. Call /api/persona/generate first.",
    );
  }
  const persona: Persona = {
    ...existing,
    text: body.text,
    userEdited: body.userEdited ?? true,
    lastUpdated: new Date().toISOString(),
  };
  store.personas.set(auth.userId, persona);
  await db.upsertPersona(auth.userId, persona);
  return NextResponse.json({ persona });
});

export const GET = withAuth(async (_req, { auth }) => {
  // Try Supabase first, then fall back to local cache.
  const remote = await db.fetchPersona(auth.userId);
  if (remote) {
    store.personas.set(auth.userId, remote);
    return NextResponse.json({ persona: remote });
  }
  const persona = store.personas.get(auth.userId);
  if (!persona) return apiError("not_found", "No persona yet.");
  return NextResponse.json({ persona });
});
