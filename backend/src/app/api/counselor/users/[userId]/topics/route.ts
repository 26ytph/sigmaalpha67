import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import * as db from "@/lib/db";

/**
 * GET /api/counselor/users/{userId}/topics?status=pending|resolved|all
 *
 * 諮詢師端：列出某 user 目前所有「主題卡」(question_topics)。
 * 預設 status=pending — 那些是 AI 沒解決、需要諮詢師接手的群組。
 */
export const GET = withAuth<{ userId: string }>(
  async (req, { params }) => {
    const url = new URL(req.url);
    const statusParam = url.searchParams.get("status") ?? "pending";
    const status: "pending" | "resolved" | "all" =
      statusParam === "resolved"
        ? "resolved"
        : statusParam === "all"
          ? "all"
          : "pending";
    const topics = await db.listUserTopics(params.userId, {
      status,
      limit: 80,
    });
    return NextResponse.json({ topics });
  },
);
