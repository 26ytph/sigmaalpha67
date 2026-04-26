import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { store } from "@/lib/store";
import * as db from "@/lib/db";

/**
 * GET /api/counselor/users
 *
 * 給諮詢師端用：列出所有「可被諮詢」的使用者。
 * 分配邏輯先不實作 — 任何登入諮詢師都可以看到全部 users。
 *
 * 來源：先看 Supabase（profiles 表），沒設定就 fallback 到 in-memory。
 */
export const GET = withAuth(async (_req, { auth }) => {
  // 1) 嘗試 Supabase
  const remote = await db.listAllUsersForCounselor();
  if (remote.length > 0) {
    // 把諮詢師自己過濾掉
    const filtered = remote.filter((u) => u.userId !== auth.userId);
    return NextResponse.json({ users: filtered });
  }

  // 2) Fallback 到 in-memory store
  const local = Array.from(store.profiles.entries())
    .filter(([userId]) => userId !== auth.userId)
    .map(([userId, profile]) => ({
      userId,
      name: profile.name ?? "",
      email: profile.email ?? "",
    }));

  // 也把純粹有對話、但還沒填 profile 的 user 列進來
  const seen = new Set(local.map((u) => u.userId));
  for (const conv of store.conversations.values()) {
    if (conv.userId === auth.userId) continue;
    if (seen.has(conv.userId)) continue;
    seen.add(conv.userId);
    local.push({ userId: conv.userId, name: "", email: "" });
  }

  return NextResponse.json({ users: local });
});
