import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { normalizeQuestion } from "@/engines/intentNormalizer";

export const POST = withAuth(async (req) => {
  const body = await readJson<{ question?: string }>(req);
  if (!body?.question?.trim()) return apiError("bad_request", "`question` is required.");
  const normalized = normalizeQuestion(body.question);
  return NextResponse.json({ normalized });
});
