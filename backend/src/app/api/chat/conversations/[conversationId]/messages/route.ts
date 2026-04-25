import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";

export const GET = withAuth<{ conversationId: string }>(async (_req, { auth, params }) => {
  const conv = store.conversations.get(params.conversationId);
  if (!conv || conv.userId !== auth.userId) {
    return apiError("not_found", "Conversation not found.");
  }
  return NextResponse.json({ conversationId: conv.id, messages: conv.messages });
});
