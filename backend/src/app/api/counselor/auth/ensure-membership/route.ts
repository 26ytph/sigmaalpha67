import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { getSupabaseAdmin } from "@/lib/supabase";

/**
 * POST /api/counselor/auth/ensure-membership
 *
 * 把目前登入的 user upsert 進 public.counselors（active=true），
 * 讓他在 chat_messages / chat_conversations / user_insights 的 RLS 政策下
 * 被視為諮詢師（用於 Supabase Realtime 訂閱會被 RLS 過濾的場景）。
 *
 * 用 withAuth → 用 service role 寫入，bypass RLS，沒有額外資安問題：
 * 任何能登入的人都會被加進諮詢師名單（題目要求「先讓所有諮詢師看到所有人」）。
 *
 * Idempotent — 已經存在就 no-op。
 */
export const POST = withAuth(async (_req, { auth }) => {
  const supabase = getSupabaseAdmin();
  if (!supabase) {
    return NextResponse.json({ ok: true, skipped: "supabase_not_configured" });
  }
  const { error } = await supabase
    .from("counselors")
    .upsert(
      { user_id: auth.userId, active: true },
      { onConflict: "user_id" },
    );
  if (error) {
    // 表還沒建（005 migration 沒跑）— 不擋使用者流程
    return NextResponse.json({ ok: false, error: error.message });
  }
  return NextResponse.json({ ok: true });
});
