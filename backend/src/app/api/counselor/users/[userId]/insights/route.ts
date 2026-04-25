import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import * as db from "@/lib/db";
import { getSupabaseAdmin } from "@/lib/supabase";

/**
 * 諮詢師讀／寫某位使用者的 AI insight。
 *
 * GET /api/counselor/users/{userId}/insights
 *   回傳該使用者最新的 user_insights row。
 *
 * PUT /api/counselor/users/{userId}/insights
 *   { counselor_note: "..." }
 *   讓諮詢師加備註（不會動 AI 產出的欄位）。
 *
 * 權限：必須是 public.counselors 名單上的人（不在的話回 403）。
 */
async function requireCounselor(userId: string): Promise<boolean> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return true; // 沒設定 Supabase 時跳過守門（demo 模式）
  const { data, error } = await supabase
    .from("counselors")
    .select("user_id, active")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) return false;
  return !!data?.active;
}

export const GET = withAuth<{ userId: string }>(
  async (_req, { auth, params }) => {
    const ok = await requireCounselor(auth.userId);
    if (!ok) return apiError("forbidden", "Counselor access only.");
    const insight = await db.fetchUserInsight(params.userId);
    if (!insight) return apiError("not_found", "No insight for that user.");
    return NextResponse.json({ insight });
  },
);

export const PUT = withAuth<{ userId: string }>(
  async (req, { auth, params }) => {
    const ok = await requireCounselor(auth.userId);
    if (!ok) return apiError("forbidden", "Counselor access only.");
    const body = await readJson<{ counselor_note?: string; counselorNote?: string }>(
      req,
    );
    const note = body?.counselor_note ?? body?.counselorNote ?? "";
    if (typeof note !== "string") {
      return apiError("bad_request", "`counselor_note` must be a string.");
    }
    await db.updateInsightCounselorNote(params.userId, note);
    const updated = await db.fetchUserInsight(params.userId);
    return NextResponse.json({ insight: updated });
  },
);
