import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";
import type { Persona } from "@/types/persona";

// 2.3 — user manually edits persona text.
export const PUT = withAuth(async (req, { auth }) => {
  const body = await readJson<{ text?: string; userEdited?: boolean }>(req);
  if (!body?.text) return apiError("bad_request", "`text` is required.");
  const existing = store.personas.get(auth.userId);
  if (!existing) return apiError("not_found", "Persona not yet generated. Call /api/persona/generate first.");
  const persona: Persona = {
    ...existing,
    text: body.text,
    userEdited: body.userEdited ?? true,
    lastUpdated: new Date().toISOString(),
  };
  store.personas.set(auth.userId, persona);
  return NextResponse.json({ persona });
});

export const GET = withAuth(async (_req, { auth }) => {
  const persona = store.personas.get(auth.userId);
  if (!persona) return apiError("not_found", "No persona yet.");
  return NextResponse.json({ persona });
});
