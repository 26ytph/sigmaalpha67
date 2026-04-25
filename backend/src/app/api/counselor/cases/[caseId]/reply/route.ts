import { NextResponse } from "next/server";
import { randomUUID } from "node:crypto";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";
import * as db from "@/lib/db";
import { buildCounselorFaqSource, ensureKnowledgeBaseSeeded, upsertKnowledgeSource } from "@/engines/rag";
import type { ChatMessage } from "@/types/chat";

type Body = { reply?: string; savedToKnowledgeBase?: boolean };

export const PUT = withAuth<{ caseId: string }>(async (req, { params }) => {
  const body = await readJson<Body>(req);
  if (!body?.reply) return apiError("bad_request", "`reply` is required.");
  const c = store.cases.get(params.caseId);
  if (!c) return apiError("not_found", "Case not found.");
  c.counselorReply = body.reply;
  // 預設一律推進 KB —— 諮詢師回過的問題就成為下次 RAG 可命中的 FAQ。
  // 諮詢師若不希望這題被收進 KB（例如太個案、含敏感資料）可手動傳 false 蓋掉。
  c.savedToKnowledgeBase = body.savedToKnowledgeBase ?? true;
  if (c.savedToKnowledgeBase) {
    try {
      ensureKnowledgeBaseSeeded();
      const { source } = upsertKnowledgeSource(
        buildCounselorFaqSource({
          question: c.mainQuestion,
          answer: body.reply,
          caseId: c.id,
          tags: ["諮詢師審核", ...c.suggestedTopics.slice(0, 3), ...c.recommendedResources.slice(0, 3)],
        }),
      );
      c.knowledgeSourceId = source.id;
    } catch (e) {
      console.warn("[counselor.reply] push to KB failed:", e);
    }
  }
  // 同步把當初觸發 case 的 user 訊息對應的 normalized_questions 標成 resolved，
  // 諮詢師端 UI 會把這組 Q+A 淡化成「已完成」。
  if (c.fromMessageId) {
    await db
      .markNormalizedQuestionResolvedByMessageId(
        c.fromMessageId,
        `諮詢師回覆 case ${c.id}`,
      )
      .catch(() => {});
  }

  // —— 把諮詢師的回覆寫進對應的 chat_messages，讓 user 端透過 realtime 收到 ——
  //    若 case 沒記到 conversationId（舊資料），fall back 到該 user 最近一條 conversation。
  let conversationId = c.conversationId;
  if (!conversationId) {
    const list = await db.listConversations(c.userId, 1);
    if (list[0]) {
      conversationId = list[0].id;
      c.conversationId = conversationId;
    }
  }
  if (conversationId) {
    const replyMsg: ChatMessage = {
      id: randomUUID(),
      role: "assistant",
      text: body.reply,
      createdAt: new Date().toISOString(),
    };
    await db.upsertConversation(c.userId, conversationId, "career", c.createdAt);
    await db.insertChatMessage(c.userId, conversationId, replyMsg, {
      byCounselor: true,
    });
    // 同步 in-memory store，下次 chat 才看得到完整 context
    const conv = store.conversations.get(conversationId);
    if (conv) {
      conv.messages.push(replyMsg);
      conv.updatedAt = replyMsg.createdAt;
      store.conversations.set(conversationId, conv);
    }
  } else {
    console.warn(
      `[counselor.reply] case ${c.id} has no conversation — reply not delivered to user chat.`,
    );
  }

  c.status = "resolved";
  c.updatedAt = new Date().toISOString();
  store.cases.set(c.id, c);
  return NextResponse.json({ case: c });
});
