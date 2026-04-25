import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { store } from "@/lib/store";
import * as db from "@/lib/db";

/**
 * GET /api/chat/conversations
 *
 * 列出該使用者的對話清單，新→舊。優先讀 Supabase（給跨裝置 / cold start
 * 用），找不到就 fall back 到 in-memory store。
 */
export const GET = withAuth(async (_req, { auth }) => {
  const fromDb = await db.listConversations(auth.userId);
  if (fromDb.length > 0) {
    return NextResponse.json({ conversations: fromDb });
  }

  const local = Array.from(store.conversations.values())
    .filter((c) => c.userId === auth.userId)
    .sort((a, b) => (a.updatedAt < b.updatedAt ? 1 : -1))
    .map((c) => ({ id: c.id, mode: c.mode, createdAt: c.createdAt }));
  return NextResponse.json({ conversations: local });
});
