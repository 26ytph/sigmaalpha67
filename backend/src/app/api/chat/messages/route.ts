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
import {
  answerRagQuery,
  ensureCounselorFaqsLoaded,
  searchKnowledge,
  shouldUseRag,
} from "@/engines/rag";
import { generateUserInsight } from "@/engines/userInsight";
import { processUserQuestion } from "@/engines/normalizeQuestion";
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

  // 先把諮詢師寫過的 FAQ 從 supabase 載進 in-memory KB（60s TTL）。
  // 這一步要在 shouldUseRag / searchKnowledge 之前 — 否則 cold start 後寫過的 FAQ 撈不到。
  await ensureCounselorFaqsLoaded();

  // RAG 觸發判斷：除了 keyword 名單之外，也用一次便宜的 KB 預檢；
  // 若這個問題真的有諮詢師寫過的 FAQ 高度命中，就強制走 RAG path 把答案拉出來。
  let ragEnabled = body.context?.useRag !== false && shouldUseRag(body.message, mode);
  if (!ragEnabled && body.context?.useRag !== false) {
    try {
      const peek = searchKnowledge({ query: body.message, topK: 1 });
      if (peek.length > 0 && peek[0].score >= 0.4) {
        ragEnabled = true;
      }
    } catch {
      /* KB 還沒 seed 之類；忽略 */
    }
  }

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
    refreshNormalizedQuestionInBackground({
      userId: auth.userId,
      conversationId: convId,
      messageId: userMsg.id,
      question: body.message,
      assistantReply: cached.reply,
      // 命中 cache 表示之前已成功回過這題、且當時不需 handoff（cache 不會存 handoff）→
      // 視為 AI 信心足夠，直接 resolved。
      aiHighConfidence: !cached.shouldHandoff,
      profile,
      persona,
      history: conv.messages.slice(0, -2),
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
  const baseReply =
    ragResult?.answer ?? geminiChat?.reply ?? fallback?.reply ?? "";
  const shouldHandoff = ragResult?.shouldHandoff ?? fallback?.shouldHandoff ?? false;

  // —— RAG 沒命中（或信心很低 / 直接被判 handoff）→ 補上「已通知諮詢師」提示
  //    並背景開一張 case，讓諮詢師收件匣看得到。 ——
  const ragConfidence = ragResult?.confidenceScore ?? 0;
  const ragMissed =
    !ragResult ||
    ragResult.retrievedChunks.length === 0 ||
    ragConfidence < 0.24;
  const needsHandoff = shouldHandoff || ragMissed;
  let reply = baseReply;
  if (needsHandoff) {
    const followUp = pickFollowUp(body.message);
    reply =
      `${baseReply}\n\n` +
      `📌 這題我目前沒辦法精確回答 — 已通知諮詢師，你可以等他們接手回覆。\n` +
      (followUp ? `如果方便，可以先補一些細節讓我先幫你整理：${followUp}` : "");
    autoCreateCounselorCaseInBackground({
      userId: auth.userId,
      conversationId: convId,
      fromMessageId: userMsg.id,
      userQuestion: body.message,
    });
  }

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

  // —— 正規化 + tag 抽取（不 await，背景跑）——
  //    把 reply 一起帶進去 → 可以判斷「已解決」並寫到 normalized_questions。
  //    needsHandoff=false 表示 AI 信心足、有命中 KB 或回得清楚 → 直接標 resolved=true，
  //    諮詢師端 UI 看到的這組 Q+A 會立刻被淡化成「已完成」，不會再花時間處理重複問題。
  refreshNormalizedQuestionInBackground({
    userId: auth.userId,
    conversationId: convId,
    messageId: userMsg.id,
    question: body.message,
    assistantReply: reply,
    aiHighConfidence: !needsHandoff,
    profile,
    persona,
    history: conv.messages.slice(0, -2), // 不含這次的 user + assistant msg
  });

  // —— 每 4 則使用者訊息（即每 8 則 total）就 fire-and-forget 重算一次 insight ——
  //    或者：這次被標 shouldHandoff 也立刻重算（諮詢師可能要看了）。
  const userTurns = conv.messages.filter((m) => m.role === "user").length;
  if (userTurns > 0 && (userTurns % 2 === 0 || shouldHandoff)) {
    refreshInsightInBackground(auth.userId, conv.messages);
  }

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

/**
 * RAG 沒命中時：回給使用者的追問句，盡量讓 AI 順便繼續收集細節，
 * 諮詢師接手時就能看到比較完整的脈絡。順序由問題的字面線索決定。
 */
function pickFollowUp(question: string): string {
  const q = question.toLowerCase();
  if (/補助|津貼|貸款|申請/.test(q)) {
    return "你的年齡 / 身分 / 設籍縣市，以及希望申請哪一類資源（職涯／創業／實習）？";
  }
  if (/履歷|cv|面試/.test(q)) {
    return "你最想調整哪一段（學歷、實習、專案）？想投的職位類型大概是什麼？";
  }
  if (/創業|青創|商業/.test(q)) {
    return "目前是想法階段、有原型還是已經在營運？資金需求大概多少？";
  }
  if (/實習|工讀/.test(q)) {
    return "你想實習的領域、希望的時段（暑期 / 學期間），以及目前學校 / 年級？";
  }
  if (/迷惘|方向|不知道/.test(q)) {
    return "現在最讓你卡住的是哪一段（科系、興趣、家裡期待、能力盤點）？最近有什麼讓你猶豫的決定？";
  }
  return "可以多給一點背景嗎？例如目前階段、目標時程、已經試過什麼？";
}

/**
 * 不 await — RAG 沒命中或被判要 handoff 時，背景幫使用者開一張 case，
 * 諮詢師端的個案列表就能看到「待處理」。失敗只 log。
 */
function autoCreateCounselorCaseInBackground(opts: {
  userId: string;
  conversationId: string;
  fromMessageId: string;
  userQuestion: string;
}) {
  void (async () => {
    try {
      const profile = store.profiles.get(opts.userId) ?? null;
      const persona = store.personas.get(opts.userId) ?? null;
      // 同一個 user msg 不重複開 case（reload 重送也只會留一張）。
      for (const existing of store.cases.values()) {
        if (
          existing.userId === opts.userId &&
          existing.fromMessageId === opts.fromMessageId
        ) {
          return;
        }
      }
      const { buildCounselorBrief } = await import("@/engines/counselorBrief");
      const { normalizeQuestion } = await import("@/engines/intentNormalizer");
      const { buildSwipeSummary } = await import("@/lib/swipeSummary");
      const c = buildCounselorBrief({
        userId: opts.userId,
        profile,
        persona,
        swipeSummary: buildSwipeSummary(store.swipes.get(opts.userId) ?? []),
        userQuestion: opts.userQuestion,
        normalized: normalizeQuestion(opts.userQuestion),
        fromMessageId: opts.fromMessageId,
        conversationId: opts.conversationId,
      });
      store.cases.set(c.id, c);
    } catch (e) {
      console.warn("[autoCase] background create failed:", e);
    }
  })();
}

/**
 * 不 await — 讓 chat 回覆先送回 client，背景再算 insight。
 * 失敗只 log，不影響使用者體感。
 */
function refreshInsightInBackground(
  userId: string,
  messages: import("@/types/chat").ChatMessage[],
) {
  void (async () => {
    try {
      const profile = store.profiles.get(userId) ?? null;
      const persona = store.personas.get(userId) ?? null;
      const draft = await generateUserInsight({
        profile,
        persona,
        messages,
      });
      await db.upsertUserInsight(userId, draft);
    } catch (err) {
      console.warn("[insight] background refresh failed:", err);
    }
  })();
}

/**
 * Per-message normalisation pipeline。
 *   - 先用 RAG searchKnowledge 看這題是否已經有相似既存問答
 *   - 沒命中才用 Gemini 整理成正規化摘要 + tags
 *   - 寫入 normalized_questions（去重後的「新問題清單」），同時把 tags 累加到 user_insights.tags
 *
 * 採 fire-and-forget，不阻塞 chat 回覆。
 */
function refreshNormalizedQuestionInBackground(opts: {
  userId: string;
  conversationId: string;
  messageId: string;
  question: string;
  assistantReply?: string;
  aiHighConfidence?: boolean;
  profile: import("@/types/profile").Profile | null;
  persona: import("@/types/persona").Persona | null;
  history: import("@/types/chat").ChatMessage[];
}) {
  void (async () => {
    try {
      const outcome = await processUserQuestion({
        question: opts.question,
        assistantReply: opts.assistantReply,
        aiHighConfidence: opts.aiHighConfidence,
        profile: opts.profile,
        persona: opts.persona,
        history: opts.history,
      });
      if (!outcome.stored) return;
      await db.insertNormalizedQuestion(
        opts.userId,
        opts.conversationId,
        opts.messageId,
        outcome.draft,
      );
      if (outcome.draft.tags?.length) {
        await db.appendUserTags(opts.userId, outcome.draft.tags);
      }
    } catch (err) {
      console.warn("[normalizeQuestion] background pipeline failed:", err);
    }
  })();
}
