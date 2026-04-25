import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";
import { buildCounselorBrief } from "@/engines/counselorBrief";
import { buildSwipeSummary } from "@/lib/swipeSummary";
import { normalizeQuestion } from "@/engines/intentNormalizer";
import type { NormalizedQuestion } from "@/types/chat";
import type { CounselorCaseStatus } from "@/types/counselor";

type Body = {
  fromMessageId?: string;
  userQuestion?: string;
  normalizedQuestion?: NormalizedQuestion;
};

export const POST = withAuth(async (req, { auth }) => {
  const body = await readJson<Body>(req);
  if (!body?.userQuestion) return apiError("bad_request", "`userQuestion` is required.");
  const normalized = body.normalizedQuestion ?? normalizeQuestion(body.userQuestion);
  const summary = buildSwipeSummary(store.swipes.get(auth.userId) ?? []);
  const c = buildCounselorBrief({
    userId: auth.userId,
    profile: store.profiles.get(auth.userId) ?? null,
    persona: store.personas.get(auth.userId) ?? null,
    swipeSummary: summary,
    userQuestion: body.userQuestion,
    normalized,
    fromMessageId: body.fromMessageId,
  });
  store.cases.set(c.id, c);
  return NextResponse.json({ case: c });
});

export const GET = withAuth(async (req) => {
  const url = new URL(req.url);
  const status = url.searchParams.get("status") as CounselorCaseStatus | null;
  const all = [...store.cases.values()];
  const filtered = status ? all.filter((c) => c.status === status) : all;
  filtered.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  return NextResponse.json({ cases: filtered });
});
