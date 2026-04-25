import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";

type Body = { reply?: string; savedToKnowledgeBase?: boolean };

export const PUT = withAuth<{ caseId: string }>(async (req, { params }) => {
  const body = await readJson<Body>(req);
  if (!body?.reply) return apiError("bad_request", "`reply` is required.");
  const c = store.cases.get(params.caseId);
  if (!c) return apiError("not_found", "Case not found.");
  c.counselorReply = body.reply;
  c.savedToKnowledgeBase = body.savedToKnowledgeBase ?? false;
  c.status = "resolved";
  c.updatedAt = new Date().toISOString();
  store.cases.set(c.id, c);
  return NextResponse.json({ case: c });
});
