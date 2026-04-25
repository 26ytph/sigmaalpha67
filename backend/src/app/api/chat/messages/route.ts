import { NextResponse } from "next/server";
import { randomUUID } from "node:crypto";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";
import * as db from "@/lib/db";
import { generateChatReply } from "@/engines/chatReply";
import {
  generateGeneralChatReply,
  lastGeminiChatError,
} from "@/engines/geminiChat";
import { answerRagQuery, shouldUseRag } from "@/engines/rag";
import {
  buildChatCacheKey,
  checkRate,
  getCachedReply,
  hashHistory,
  setCachedReply,
} from "@/lib/rateGuard";
import type { ChatConversation, ChatMessage } from "@/types/chat";

type Body = {
  conversationId?: string;
  message?: string;
  context?: { mode?: "career" | "startup"; useProfile?: boolean; useHistory?: boolean; useRag?: boolean };
};

export const POST = withAuth(async (req, { auth }) => {
  const body = await readJson<Body>(req);
  if (!body?.message?.trim()) return apiError("bad_request", "`message` is required.");
  const mode = body.context?.mode ?? "career";

  const rate = checkRate(auth.userId);
  if (!rate.ok) {
    const seconds = Math.ceil(rate.retryAfterMs / 1000);
    return NextResponse.json(
      {
        error: {
          code: "rate_limited",
          message: `太快了～請稍等 ${seconds} 秒再試（為了保護 LLM 配額）。`,
          retryAfterMs: rate.retryAfterMs,
        },
      },
      {
        status: 429,
        headers: { "retry-after": String(seconds) },
      },
    );
  }

  // 用 client 帶來的 id；沒有就用 UUID（Supabase chat_conversations.id 是 uuid）
  const convId = body.conversationId ?? randomUUID();
  const now = new Date().toISOString();

  // 1) 先看 in-memory store
  let conv: ChatConversation | undefined = store.conversations.get(convId);

  // 2) Cold start / 換 device：本機沒有但 client 帶了 id 過來 → 從 Supabase 把整段歷史撈回來
  if (!conv && body.conversationId) {
    const remote = await db.fetchConversationMessages(auth.userId, convId);
    if (remote) {
      conv = remote;
      store.conversations.set(convId, conv);
    }
  }

  // 3) 真的找不到就建一個新的
  if (!conv) {
    conv = {
      id: convId,
      userId: auth.userId,
      mode,
      messages: [],
      createdAt: now,
      updatedAt: now,
    };
  }
  if (conv.userId !== auth.userId) {
    return apiError("not_found", "Conversation not found.");
  }

  // 確保 Supabase 有這筆對話 row（首次訊息時建立）
  await db.upsertConversation(auth.userId, convId, mode, conv.createdAt);

  const userMsg: ChatMessage = {
    id: randomUUID(),
    role: "user",
    text: body.message,
    createdAt: now,
  };
  conv.messages.push(userMsg);
  // 把 user 的訊息寫進 Supabase
  await db.insertChatMessage(auth.userId, convId, userMsg);

  const profile = body.context?.useProfile === false ? null : store.profiles.get(auth.userId) ?? null;
  const persona = store.personas.get(auth.userId) ?? null;
  const ragEnabled = body.context?.useRag !== false && shouldUseRag(body.message, mode);

  const personaHash = persona
    ? `${persona.careerStage}:${(persona.mainInterests ?? []).slice(0, 3).join(",")}`
    : "no-persona";
  const historyHash = hashHistory(
    conv.messages.slice(0, -1).map((m) => ({ role: m.role, text: m.text })),
  );
  const cacheKey = buildChatCacheKey({
    userId: auth.userId,
    message: body.message,
    mode,
    useRag: ragEnabled,
    personaHash,
    historyHash,
  });
  type CachedPayload = {
    reply: string;
    shouldHandoff: boolean;
    tokensUsed: number;
    rag: unknown;
    chatProvider: "gemini" | "local" | null;
  };
  const cached = getCachedReply<CachedPayload>(cacheKey);
  if (cached) {
    const replyMsg: ChatMessage = {
      id: randomUUID(),
      role: "assistant",
      text: cached.reply,
      createdAt: new Date().toISOString(),
    };
    conv.messages.push(replyMsg);
    conv.updatedAt = replyMsg.createdAt;
    store.conversations.set(convId, conv);
    await db.insertChatMessage(auth.userId, convId, replyMsg, {
      askedHandoff: cached.shouldHandoff,
    });
    return NextResponse.json({
      conversationId: convId,
      messageId: replyMsg.id,
      reply: cached.reply,
      shouldHandoff: cached.shouldHandoff,
      tokensUsed: 0,
      rag: cached.rag,
      chatProvider: cached.chatProvider,
      cached: true,
      debugChatError: null,
    });
  }

  const history = conv.messages
    .slice(0, -1)
    .map((m) => ({ role: m.role as "user" | "assistant", text: m.text }));

  const ragResult = ragEnabled
    ? await answerRagQuery({
        userId: auth.userId,
        question: body.message,
        profile,
        persona,
        topK: 5,
        history,
      })
    : null;

  const geminiChat = ragResult
    ? null
    : await generateGeneralChatReply({
        message: body.message,
        profile,
        persona,
        mode,
        history,
      });

  const fallback = ragResult || geminiChat
    ? null
    : generateChatReply({
        message: body.message,
        profile,
        persona,
        mode,
      });
  const reply =
    ragResult?.answer ?? geminiChat?.reply ?? fallback?.reply ?? "";
  const shouldHandoff = ragResult?.shouldHandoff ?? fallback?.shouldHandoff ?? false;
  const tokensUsed = ragResult
    ? Math.min(1800, 180 + body.message.length * 2 + ragResult.answer.length * 2)
    : geminiChat
      ? Math.min(800, 60 + body.message.length * 2 + geminiChat.reply.length * 2)
      : fallback?.tokensUsed ?? 0;
  const chatProvider: "gemini" | "local" | null = ragResult
    ? null
    : geminiChat
      ? "gemini"
      : "local";
  const replyMsg: ChatMessage = {
    id: randomUUID(),
    role: "assistant",
    text: reply,
    createdAt: new Date().toISOString(),
  };
  conv.messages.push(replyMsg);
  conv.updatedAt = replyMsg.createdAt;
  store.conversations.set(convId, conv);
  await db.insertChatMessage(auth.userId, convId, replyMsg, {
    askedHandoff: shouldHandoff,
  });

  const ragPayload = ragResult
    ? {
        provider: ragResult.provider,
        confidenceScore: ragResult.confidenceScore,
        logId: ragResult.logId,
        sources: ragResult.retrievedChunks.map((chunk) => ({
          title: chunk.title,
          sourceUrl: chunk.sourceUrl,
          score: chunk.score,
        })),
      }
    : null;

  if (reply && (ragResult || geminiChat)) {
    setCachedReply<CachedPayload>(cacheKey, {
      reply,
      shouldHandoff,
      tokensUsed,
      rag: ragPayload,
      chatProvider,
    });
  }

  return NextResponse.json({
    conversationId: convId,
    messageId: replyMsg.id,
    reply,
    shouldHandoff,
    tokensUsed,
    rag: ragPayload,
    chatProvider,
    cached: false,
    debugChatError:
      chatProvider === "local" && !ragResult ? lastGeminiChatError.value : null,
  });
});
