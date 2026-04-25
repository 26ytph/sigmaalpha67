import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";

export const DELETE = withAuth<{ conversationId: string }>(async (_req, { auth, params }) => {
  const conv = store.conversations.get(params.conversationId);
  if (!conv) return NextResponse.json({ ok: true });
  if (conv.userId !== auth.userId) return apiError("not_found", "Conversation not found.");
  store.conversations.delete(params.conversationId);
  return NextResponse.json({ ok: true });
});
