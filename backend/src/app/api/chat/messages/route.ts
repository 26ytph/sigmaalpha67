import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store, newId } from "@/lib/store";
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

  const convId = body.conversationId ?? newId("c");
  const now = new Date().toISOString();
  const conv: ChatConversation =
    store.conversations.get(convId) ?? {
      id: convId,
      userId: auth.userId,
      mode,
      messages: [],
      createdAt: now,
      updatedAt: now,
    };
  if (conv.userId !== auth.userId) return apiError("not_found", "Conversation not found.");

  const userMsg: ChatMessage = {
    id: newId("m"),
    role: "user",
    text: body.message,
    createdAt: now,
  };
  conv.messages.push(userMsg);

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
      id: newId("m"),
      role: "assistant",
      text: cached.reply,
      createdAt: new Date().toISOString(),
    };
    conv.messages.push(replyMsg);
    conv.updatedAt = replyMsg.createdAt;
    store.conversations.set(convId, conv);
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
    id: newId("m"),
    role: "assistant",
    text: reply,
    createdAt: new Date().toISOString(),
  };
  conv.messages.push(replyMsg);
  conv.updatedAt = replyMsg.createdAt;
  store.conversations.set(convId, conv);

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
