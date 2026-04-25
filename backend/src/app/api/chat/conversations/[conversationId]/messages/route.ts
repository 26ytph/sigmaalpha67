import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";
import * as db from "@/lib/db";

export const GET = withAuth<{ conversationId: string }>(
  async (_req, { auth, params }) => {
    // 1) 永遠先讀 Supabase（避免使用者端跟諮詢師端各自更新 in-memory 後不同步）。
    //    Supabase 沒設定時 fetchConversationMessages 會回 null，再退回 in-memory。
    const remote = await db.fetchConversationMessages(
      auth.userId,
      params.conversationId,
    );
    if (remote) {
      store.conversations.set(remote.id, remote);
      return NextResponse.json({
        conversationId: remote.id,
        mode: remote.mode,
        messages: remote.messages,
      });
    }

    // 2) Fallback：只有 in-memory（demo 模式）
    const conv = store.conversations.get(params.conversationId);
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
