import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { apiError } from "@/lib/errors";
import * as db from "@/lib/db";

/**
 * GET /api/counselor/topics/{topicId}
 *
 * 拿一張主題卡的完整內容：topic meta + 所有成員問題（含當下 AI 暫時回覆）。
 * 諮詢師端點開卡片時用。
 */
export const GET = withAuth<{ topicId: string }>(
  async (_req, { params }) => {
    const topic = await db.fetchTopicWithMembers(params.topicId);
    if (!topic) return apiError("not_found", "Topic not found.");
    return NextResponse.json({ topic });
  },
);
