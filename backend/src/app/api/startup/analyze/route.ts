import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { analyzeStartup } from "@/engines/startupAnalyzer";
import type { Profile } from "@/types/profile";
import { store } from "@/lib/store";

type Body = { idea?: string; profile?: Partial<Profile> };

export const POST = withAuth(async (req, { auth }) => {
  const body = await readJson<Body>(req);
  if (!body?.idea?.trim()) return apiError("bad_request", "`idea` is required.");
  const result = analyzeStartup({
    idea: body.idea,
    profile: body.profile ?? store.profiles.get(auth.userId) ?? null,
  });
  return NextResponse.json(result);
});
