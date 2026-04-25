import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";
import * as db from "@/lib/db";

export const GET = withAuth<{ conversationId: string }>(
  async (_req, { auth, params }) => {
    // 1) 先看 in-memory
    let conv = store.conversations.get(params.conversationId);

    // 2) 沒有就去 Supabase 撈
    if (!conv) {
      const remote = await db.fetchConversationMessages(
        auth.userId,
        params.conversationId,
      );
      if (remote) {
        store.conversations.set(remote.id, remote);
        conv = remote;
      }
    }

    if (!conv || conv.userId !== auth.userId) {
      return apiError("not_found", "Conversation not found.");
    }
    return NextResponse.json({
      conversationId: conv.id,
      mode: conv.mode,
      messages: conv.messages,
    });
  },
);
