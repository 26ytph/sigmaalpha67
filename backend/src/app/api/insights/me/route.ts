import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { store } from "@/lib/store";
import * as db from "@/lib/db";
import { generateUserInsight } from "@/engines/userInsight";
import { emptyUserInsight } from "@/types/insight";

/**
 * GET /api/insights/me
 *   讀取目前已存的 insight。沒有就回空殼（200 + empty fields）。
 *
 * POST /api/insights/me
 *   立刻強制重算一次（讀使用者最近對話 → Gemini → 寫回 Supabase）。
 *   給 user 自己也能用，counselor 也可以打。
 */
export const GET = withAuth(async (_req, { auth }) => {
  const remote = await db.fetchUserInsight(auth.userId);
  if (remote) return NextResponse.json({ insight: remote });
  return NextResponse.json({ insight: emptyUserInsight(auth.userId) });
});

export const POST = withAuth(async (_req, { auth }) => {
  const profile = store.profiles.get(auth.userId) ?? null;
  const persona = store.personas.get(auth.userId) ?? null;

  // 找該使用者最新一段對話的訊息
  const latest = Array.from(store.conversations.values())
    .filter((c) => c.userId === auth.userId)
    .sort((a, b) => (a.updatedAt < b.updatedAt ? 1 : -1))[0];

  let messages = latest?.messages ?? [];

  // 本機沒有就到 Supabase 撈最新一段
  if (messages.length === 0) {
    const list = await db.listConversations(auth.userId, 1);
    if (list[0]) {
      const remote = await db.fetchConversationMessages(auth.userId, list[0].id);
      if (remote) messages = remote.messages;
    }
  }

  const draft = await generateUserInsight({ profile, persona, messages });
  await db.upsertUserInsight(auth.userId, draft);

  const saved = await db.fetchUserInsight(auth.userId);
  return NextResponse.json({
    insight: saved ?? { ...emptyUserInsight(auth.userId), ...draft },
    messageCount: messages.length,
  });
});
