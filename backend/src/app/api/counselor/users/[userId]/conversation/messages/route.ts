import { NextResponse } from "next/server";
import { randomUUID } from "node:crypto";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";
import * as db from "@/lib/db";
import type { ChatConversation, ChatMessage } from "@/types/chat";

type Body = {
  conversationId?: string;
  text?: string;
};

/**
 * POST /api/counselor/users/{userId}/conversation/messages
 *
 * 諮詢師對「某位被諮詢使用者」送訊息。
 *
 * 寫法：
 *   - 直接 insert 到 public.chat_messages，sender='assistant'（schema 限制只允許 user/assistant）
 *   - 把「這是真人諮詢師寫的」標在 normalized.from_counselor = true，
 *     之後讀回來時前端可以區分「AI vs 諮詢師」
 *   - 找不到 conversationId 就建一段新的（uuid + mode='career'）
 *
 * 沒有走 user 端的 chat pipeline（不會觸發 Gemini 回覆 / RAG / rate guard），
 * 純粹把諮詢師寫的字塞進該 user 的對話歷史。
 */
export const POST = withAuth<{ userId: string }>(
  async (req, { auth, params }) => {
    const targetUserId = params.userId;
    const body = await readJson<Body>(req);
    const text = (body?.text ?? "").trim();
    if (!text) return apiError("bad_request", "`text` is required.");

    const now = new Date().toISOString();

    // 1) 找出對話 id：優先 client 帶來；否則拿該 user 最新一段；都沒有就建新的
    let convId = body?.conversationId ?? "";

    if (!convId) {
      // 1) 優先：該 user 最近真正有訊息流動的那段對話
      const active = await db.findMostActiveConversationId(targetUserId);
      if (active) {
        convId = active;
      } else {
        // 2) 沒訊息 → 退到 chat_conversations 最新一筆（user 剛開、空的）
        const list = await db.listConversations(targetUserId, 1);
        if (list[0]) {
          convId = list[0].id;
        } else {
          // 3) Supabase 沒任何資料 → in-memory fallback
          const localLatest = Array.from(store.conversations.values())
            .filter((c) => c.userId === targetUserId)
            .sort((a, b) => (a.updatedAt < b.updatedAt ? 1 : -1))[0];
          if (localLatest) convId = localLatest.id;
        }
      }
    }

    if (!convId) {
      convId = randomUUID();
      await db.upsertConversation(targetUserId, convId, "career", now);
    } else {
      // 確保 in-memory 跟 Supabase 都有這筆 conversation row（可能是新對話）
      let conv: ChatConversation | undefined = store.conversations.get(convId);
      if (!conv) {
        const remote = await db.fetchConversationMessages(
          targetUserId,
          convId,
        );
        if (remote) {
          conv = remote;
          store.conversations.set(convId, conv);
        }
      }
      if (!conv) {
        await db.upsertConversation(targetUserId, convId, "career", now);
      }
    }

    // 2) 寫入訊息
    const msg: ChatMessage = {
      id: randomUUID(),
      role: "assistant",
      text,
      createdAt: now,
      fromCounselor: true,
    };

    // in-memory: 寫進該 user 的對話
    let conv = store.conversations.get(convId);
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

    // Supabase: 寫進 chat_messages，把 from_counselor 塞進 normalized
    await db.insertChatMessage(targetUserId, convId, msg, {
      normalized: {
        from_counselor: true,
        counselor_user_id: auth.userId,
        counselor_email: auth.email ?? "",
      },
    });

    return NextResponse.json({
      conversationId: convId,
      message: msg,
    });
  },
);
