import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";
import * as db from "@/lib/db";
import { buildCounselorBrief } from "@/engines/counselorBrief";
import { buildSwipeSummary } from "@/lib/swipeSummary";
import { normalizeQuestion } from "@/engines/intentNormalizer";
import { generateUserInsight } from "@/engines/userInsight";
import type { NormalizedQuestion } from "@/types/chat";
import type { CounselorCaseStatus } from "@/types/counselor";

type Body = {
  fromMessageId?: string;
  conversationId?: string;
  userQuestion?: string;
  normalizedQuestion?: NormalizedQuestion;
};

export const POST = withAuth(async (req, { auth }) => {
  const body = await readJson<Body>(req);
  if (!body?.userQuestion) return apiError("bad_request", "`userQuestion` is required.");
  const normalized = body.normalizedQuestion ?? normalizeQuestion(body.userQuestion);
  const summary = buildSwipeSummary(store.swipes.get(auth.userId) ?? []);

  // 嘗試把 conversationId 釘到 case 上 — 諮詢師 reply 時就知道要塞回哪條對話。
  // 順序：1. body 帶來的最準  2. fromMessageId 反查  3. 該 user 最近的 conversation
  let conversationId = body.conversationId;
  if (!conversationId && body.fromMessageId) {
    const found = await db.findConversationIdByMessageId(
      auth.userId,
      body.fromMessageId,
    );
    if (found) conversationId = found;
  }
  if (!conversationId) {
    const list = await db.listConversations(auth.userId, 1);
    if (list[0]) conversationId = list[0].id;
  }

  const c = buildCounselorBrief({
    userId: auth.userId,
    profile: store.profiles.get(auth.userId) ?? null,
    persona: store.personas.get(auth.userId) ?? null,
    swipeSummary: summary,
    userQuestion: body.userQuestion,
    normalized,
    fromMessageId: body.fromMessageId,
    conversationId,
  });
  store.cases.set(c.id, c);

  // —— 一併把最新的 user insight 也吐回去給諮詢師 ——
  // 1) 先嘗試從 Supabase 撈現有的（前面 chat/messages 路徑會 fire-and-forget 重算）
  // 2) 沒有就現算一次（同步等，因為這個 endpoint 只在 user 點「需要諮詢師」時呼叫，頻率低）
  let insight = await db.fetchUserInsight(auth.userId);
  if (!insight) {
    const latestConv = Array.from(store.conversations.values())
      .filter((cc) => cc.userId === auth.userId)
      .sort((a, b) => (a.updatedAt < b.updatedAt ? 1 : -1))[0];
    let messages = latestConv?.messages ?? [];
    if (messages.length === 0) {
      const list = await db.listConversations(auth.userId, 1);
      if (list[0]) {
        const remote = await db.fetchConversationMessages(auth.userId, list[0].id);
        if (remote) messages = remote.messages;
      }
    }
    const draft = await generateUserInsight({
      profile: store.profiles.get(auth.userId) ?? null,
      persona: store.personas.get(auth.userId) ?? null,
      messages,
    });
    await db.upsertUserInsight(auth.userId, draft);
    insight = await db.fetchUserInsight(auth.userId);
  }

  return NextResponse.json({ case: c, insight });
});

export const GET = withAuth(async (req) => {
  const url = new URL(req.url);
  const status = url.searchParams.get("status") as CounselorCaseStatus | null;
  const all = [...store.cases.values()];
  const filtered = status ? all.filter((c) => c.status === status) : all;
  filtered.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  return NextResponse.json({ cases: filtered });
});
