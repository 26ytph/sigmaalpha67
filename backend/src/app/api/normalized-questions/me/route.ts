import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import * as db from "@/lib/db";

/** GET /api/normalized-questions/me — 使用者看自己被整理過的「新問題」紀錄 */
export const GET = withAuth(async (req, { auth }) => {
  const url = new URL(req.url);
  const limit = Math.min(
    Math.max(parseInt(url.searchParams.get("limit") ?? "30", 10) || 30, 1),
    100,
  );
  const items = await db.listNormalizedQuestions(auth.userId, limit);
  return NextResponse.json({ questions: items });
});
