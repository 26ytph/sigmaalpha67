import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { apiError } from "@/lib/errors";
import * as db from "@/lib/db";
import { getSupabaseAdmin } from "@/lib/supabase";

/**
 * GET /api/counselor/users/{userId}/normalized-questions
 *   列出該使用者所有「不在 RAG KB」的新問題正規化紀錄。
 *   權限：必須是 public.counselors 名單上的人。
 */
async function requireCounselor(userId: string): Promise<boolean> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return true; // demo 模式跳過守門
  const { data, error } = await supabase
    .from("counselors")
    .select("user_id, active")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) return false;
  return !!data?.active;
}

export const GET = withAuth<{ userId: string }>(
  async (req, { auth, params }) => {
    const ok = await requireCounselor(auth.userId);
    if (!ok) return apiError("forbidden", "Counselor access only.");

    const url = new URL(req.url);
    const limit = Math.min(
      Math.max(parseInt(url.searchParams.get("limit") ?? "50", 10) || 50, 1),
      200,
    );
    const items = await db.listNormalizedQuestions(params.userId, limit);
    return NextResponse.json({ questions: items });
  },
);
