import { NextResponse } from "next/server";
import { randomUUID } from "node:crypto";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";
import * as db from "@/lib/db";
import type { ChatConversation, ChatMessage } from "@/types/chat";

type Body = {
  text?: string;
  /**
   * 諮詢師選擇要回覆哪一題。值是該題對應的 chat_messages.id（user 訊息）。
   *   - 帶這個 → 鎖定那一題當引用對象。
   *   - 沒帶 → 預設用主題裡最後一個 user 訊息（向後相容）。
   * 必須是該 topic 的成員，否則 400。
   */
  replyToMessageId?: string;
};

/**
 * POST /api/counselor/topics/{topicId}/reply
 *
 * 諮詢師對「整個主題」一次回覆，可選擇指定要回哪一題。
 * 寫進 user 最近活躍的 conversation（拿不到的話建一條新的），
 * sender='assistant' + by_counselor=true。user 端透過 realtime 立刻收到。
 *
 * 不在這裡直接 mark resolved — 讓諮詢師可以多輪對話。要結案請打 /resolve。
 */
export const POST = withAuth<{ topicId: string }>(
  async (req, { auth, params }) => {
    const body = await readJson<Body>(req);
    const text = (body?.text ?? "").trim();
    if (!text) return apiError("bad_request", "`text` is required.");

    const topic = await db.fetchTopicWithMembers(params.topicId);
    if (!topic) return apiError("not_found", "Topic not found.");
    const targetUserId = topic.userId;

    // 諮詢師指定回哪一題；沒指定就退回「最後一題」當預設 anchor。
    // 指定的 id 必須是這個 topic 的成員，否則 400 — 防止 client 帶錯資料。
    let anchor = topic.members[topic.members.length - 1] ?? null;
    if (body?.replyToMessageId) {
      const picked = topic.members.find(
        (m) => m.messageId === body.replyToMessageId,
      );
      if (!picked) {
        return apiError(
          "bad_request",
          "`replyToMessageId` is not a member of this topic.",
        );
      }
      anchor = picked;
    }

    // 用 topic 成員裡最後一筆訊息所在的 conversation；fallback 到 user 最近 conversation。
    let convId = anchor?.conversationId ?? null;
    if (!convId) {
      convId = await db.findMostActiveConversationId(targetUserId);
    }
    if (!convId) {
      const list = await db.listConversations(targetUserId, 1);
      convId = list[0]?.id ?? null;
    }
    const now = new Date().toISOString();
    if (!convId) {
      convId = randomUUID();
      await db.upsertConversation(targetUserId, convId, "career", now);
    }

    const replyToText = anchor
      ? (anchor.rawQuestion || anchor.normalizedText || "").slice(0, 240)
      : undefined;

    const msg: ChatMessage = {
      id: randomUUID(),
      role: "assistant",
      text,
      createdAt: now,
      fromCounselor: true,
      topicId: topic.id,
      replyToMessageId: anchor?.messageId ?? undefined,
      replyToText,
    };

    // in-memory + supabase
    let conv: ChatConversation | undefined = store.conversations.get(convId);
    if (!conv) {
      const remote = await db.fetchConversationMessages(targetUserId, convId);
      if (remote) conv = remote;
    }
    if (!conv) {
      conv = {
        id: convId,
        userId: targetUserId,
        mode: "career",
        messages: [],
        createdAt: now,
        updatedAt: now,
      };
    }
    conv.messages.push(msg);
    conv.updatedAt = now;
    store.conversations.set(convId, conv);

    await db.insertChatMessage(targetUserId, convId, msg, {
      byCounselor: true,
      normalized: {
        from_counselor: true,
        topic_id: topic.id,
        reply_to_message_id: anchor?.messageId ?? null,
        reply_to_text: replyToText ?? null,
        counselor_user_id: auth.userId,
        counselor_email: auth.email ?? "",
      },
    });

    return NextResponse.json({
      conversationId: convId,
      message: msg,
      topicId: topic.id,
    });
  },
);
