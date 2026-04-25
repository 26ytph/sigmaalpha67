import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { store } from "@/lib/store";
import * as db from "@/lib/db";

/**
 * GET /api/counselor/users/{userId}/conversation
 *
 * 諮詢師讀「某位被諮詢使用者」目前還在進行的對話紀錄。
 *
 * 重要：
 *   - 不能用 chat_conversations.created_at 取「最新一段」，
 *     因為使用者可能切過模式而建了新的空對話 → 拿到空的那段。
 *   - 改成先看 chat_messages 最近一次寫入是哪一段對話，再把整段拉回來。
 *   - 找不到任何訊息時才退回 chat_conversations 最新一筆。
 *
 * 不同步打 RT；每 5 秒前端 polling 自己會 refresh。
 */
export const GET = withAuth<{ userId: string }>(async (_req, { params }) => {
  const targetUserId = params.userId;

  // 1) 找該 user 「最近一次有訊息的那段對話」
  const activeConvId = await db.findMostActiveConversationId(targetUserId);
  if (activeConvId) {
    const remote = await db.fetchConversationMessages(
      targetUserId,
      activeConvId,
    );
    if (remote) {
      store.conversations.set(remote.id, remote);
      return NextResponse.json({
        conversationId: remote.id,
        mode: remote.mode,
        messages: remote.messages,
      });
    }
  }

  // 2) 沒訊息的話，退到 chat_conversations 最新一筆（可能是剛開、還沒人講話）
  const list = await db.listConversations(targetUserId, 1);
  if (list[0]) {
    return NextResponse.json({
      conversationId: list[0].id,
      mode: list[0].mode,
      messages: [],
    });
  }

  // 3) Supabase 完全沒資料 → in-memory fallback（demo 模式）
  const localLatest = Array.from(store.conversations.values())
    .filter((c) => c.userId === targetUserId)
    .sort((a, b) => (a.updatedAt < b.updatedAt ? 1 : -1))[0];
  if (localLatest) {
    return NextResponse.json({
      conversationId: localLatest.id,
      mode: localLatest.mode,
      messages: localLatest.messages,
    });
  }

  return NextResponse.json({
    conversationId: null,
    mode: "career",
    messages: [],
  });
});
