import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { store } from "@/lib/store";
import * as db from "@/lib/db";
import { generateUserInsight } from "@/engines/userInsight";

/**
 * GET /api/counselor/users/{userId}/summary
 *
 * 給諮詢師端 chat 頁右側面板用：拉某位 user 最新的 AI 摘要。
 *
 * 比既有的 /insights 寬鬆：
 *   - 不擋 public.counselors 名單
 *   - 沒有現成 insight 但 user 已經有訊息 → 即時生成一份（fire-and-wait，
 *     而不是 fire-and-forget），upsert 進 user_insights，然後回傳。
 *     這樣諮詢師打開頁面就能看到摘要，不用等使用者再多聊幾句湊滿 4 則。
 *   - 完全沒訊息 → 回 insight=null（前端會顯示「尚無摘要」）。
 */
export const GET = withAuth<{ userId: string }>(async (_req, { params }) => {
  const targetUserId = params.userId;

  // 1) 先看現成的
  const existing = await db.fetchUserInsight(targetUserId);
  if (existing) return NextResponse.json({ insight: existing });

  // 2) 沒有就嘗試即時生成 — 從 user 最近活躍的那段對話拿訊息
  const activeConvId = await db.findMostActiveConversationId(targetUserId);
  if (!activeConvId) {
    return NextResponse.json({ insight: null });
  }

  const remote = await db.fetchConversationMessages(targetUserId, activeConvId);
  const messages = remote?.messages ?? [];
  if (messages.length === 0) {
    return NextResponse.json({ insight: null });
  }

  try {
    const profile = store.profiles.get(targetUserId) ?? null;
    const persona = store.personas.get(targetUserId) ?? null;
    const draft = await generateUserInsight({
      profile,
      persona,
      messages,
    });
    await db.upsertUserInsight(targetUserId, draft);
    const fresh = await db.fetchUserInsight(targetUserId);
    return NextResponse.json({ insight: fresh ?? null });
  } catch (e) {
    console.warn("[counselor.summary] insight generate failed:", e);
    return NextResponse.json({ insight: null });
  }
});
