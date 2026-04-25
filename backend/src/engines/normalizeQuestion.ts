/**
 * Per-message question-normalisation pipeline.
 *
 *   1. 用 RAG searchKnowledge 看 KB 是否已經有相似的「問題」。
 *   2. 若 KB 命中：
 *      a. 如果同時拿到 LLM 的回覆，並且回覆和 KB 既有答案也夠像
 *         → 寫入 `normalized_questions` 並標記 `resolved = true`
 *           （給諮詢師看『這題 RAG 已經自動處理掉了』）
 *      b. 答案不夠像 → 仍寫入但 `resolved = false`，諮詢師會看到
 *           『KB 有相似題目但 AI 回答有偏，可能要 review』。
 *      c. 沒拿到回覆（背景批次先跑） → 沿用舊行為跳過儲存。
 *   3. KB 沒命中 → Gemini 整理成正規化摘要 + tags 後存入。
 *   4. 不論是哪一條路徑，tags 都會被 append 進 user_insights.tags。
 *
 * Gemini 失敗時退回 local heuristic，確保 demo 不會空轉。
 */

import { searchKnowledge, scoreTextSimilarity } from "@/engines/rag";
import { normalizeQuestion as localNormalize } from "@/engines/intentNormalizer";
import type { Profile } from "@/types/profile";
import type { Persona } from "@/types/persona";
import type { ChatMessage } from "@/types/chat";
import type { NormalizedQuestionDraft } from "@/types/normalizedQuestion";

/** 命中分數 ≥ 這個值就視為「KB 已經有相似問題」。 */
export const KB_SIMILARITY_THRESHOLD = 0.55;

/** 答案 vs KB 答案 ≥ 這個值 → 視為「AI 已給出和 KB 一致的回答」→ 標 resolved。 */
export const ANSWER_SIMILARITY_THRESHOLD = 0.45;

export type NormalizationOutcome =
  | {
      stored: false;
      reason: "kb_hit_no_answer" | "empty";
      closestKbTitle: string;
      closestKbScore: number;
    }
  | { stored: true; draft: NormalizedQuestionDraft };

const SYSTEM_INSTRUCTION =
  "你是 EmploYA! 的諮詢輔助系統。" +
  "輸入是一位青年的職涯／創業提問。請整理成『諮詢師可以一眼看懂的正規化摘要』+ 屬性 tag。" +
  "保持中性、不過度推論；不要安撫式語句、不要建議。" +
  "輸出必須是合法 JSON，不要加 Markdown / code fence / 註解。";

type JsonShape = {
  normalizedText: string;
  intents: string[];
  emotion: string;
  knownInfo: string[];
  missingInfo: string[];
  urgency: "低" | "中" | "中高" | "高";
  counselorSummary: string;
  tags: string[];
};

// ---------------------------------------------------------------------------
// PUBLIC API
// ---------------------------------------------------------------------------
export async function processUserQuestion(opts: {
  question: string;
  profile?: Profile | null;
  persona?: Persona | null;
  history?: ChatMessage[];
  threshold?: number;
  /** AI / RAG 對這題的最終回覆。提供時才會做「resolved」判定。 */
  assistantReply?: string;
  /** 自訂答案相似度門檻；預設 ANSWER_SIMILARITY_THRESHOLD。 */
  answerThreshold?: number;
  /**
   * AI 在這次 chat turn 已給出明確回覆且不需要 handoff（無低信心 / 無模糊不清）。
   * true 時直接把這題標為 resolved，諮詢師端 UI 會把這組 Q+A 淡化成「已完成」。
   * 這個訊號從 chat route 傳進來，比 KB+answer-match 寬鬆 — 只要 AI 自己不慫，
   * 就算 KB 沒有完全相同的 FAQ，也算諮詢師可以略過。
   */
  aiHighConfidence?: boolean;
}): Promise<NormalizationOutcome> {
  const text = (opts.question ?? "").trim();
  if (!text) {
    return { stored: false, reason: "empty", closestKbTitle: "", closestKbScore: 0 };
  }

  const threshold = opts.threshold ?? KB_SIMILARITY_THRESHOLD;
  const answerThreshold = opts.answerThreshold ?? ANSWER_SIMILARITY_THRESHOLD;
  const aiConfident = opts.aiHighConfidence === true;

  // 1) 先看 RAG KB 有沒有近似的既有問答
  let closestTitle = "";
  let closestScore = 0;
  let closestAnswerText = "";
  try {
    const hits = searchKnowledge({ query: text, topK: 1 });
    if (hits.length > 0) {
      closestTitle = hits[0].title ?? "";
      closestScore = Number(hits[0].score ?? 0);
      closestAnswerText = (hits[0].chunkText ?? "").trim();
    }
  } catch {
    // KB 還沒 seed / 撈不到就當作沒命中
  }

  const reply = (opts.assistantReply ?? "").trim();

  // 2) KB 命中（相似題目已存在）
  if (closestScore >= threshold) {
    // 沒拿到回覆就走舊行為：背景 pipeline 先跑、之後沒辦法判斷 resolved，先跳過。
    if (!reply) {
      return {
        stored: false,
        reason: "kb_hit_no_answer",
        closestKbTitle: closestTitle,
        closestKbScore: closestScore,
      };
    }

    const answerScore = closestAnswerText
      ? scoreTextSimilarity(reply, closestAnswerText)
      : 0;
    const answerMatches = answerScore >= answerThreshold;
    const resolved = aiConfident || answerMatches;

    // 命中時跳過 Gemini 整理（多花 token 沒意義），用 heuristic 補欄位即可。
    const body = buildHeuristic(text, opts.profile ?? null);
    if (resolved && !body.tags.includes("已解決")) body.tags.push("已解決");

    const draft: NormalizedQuestionDraft = {
      rawQuestion: text,
      normalizedText: body.normalizedText,
      intents: body.intents,
      emotion: body.emotion,
      knownInfo: body.knownInfo,
      missingInfo: body.missingInfo,
      urgency: body.urgency,
      counselorSummary: body.counselorSummary,
      tags: body.tags,
      noveltyScore: clamp01(1 - closestScore),
      closestKbTitle: closestTitle,
      closestKbScore: closestScore,
      thresholdUsed: threshold,
      resolved,
      resolvedReason: resolved
        ? aiConfident && !answerMatches
          ? `AI 在這次回覆已給出明確答案（KB 命中 ${closestScore.toFixed(2)}）`
          : `KB 命中（${closestScore.toFixed(2)}）+ 回答近似（${answerScore.toFixed(2)}）`
        : `KB 命中（${closestScore.toFixed(2)}）但回答近似度只有 ${answerScore.toFixed(2)}`,
      answerScore,
      closestKbAnswer: closestAnswerText.slice(0, 600),
      generatedBy: "kb_hit_heuristic",
    };
    return { stored: true, draft };
  }

  // 3) KB 沒命中 → Gemini 整理成正規化摘要
  const fromGemini = await tryGemini({
    question: text,
    profile: opts.profile ?? null,
    persona: opts.persona ?? null,
    history: opts.history ?? [],
  });

  let body: JsonShape;
  let generatedBy: string;
  if (fromGemini) {
    body = fromGemini;
    generatedBy = process.env.GEMINI_MODEL?.trim() || "gemini-2.5-flash";
  } else {
    body = buildHeuristic(text, opts.profile ?? null);
    generatedBy = "heuristic";
  }
  if (aiConfident && !body.tags.includes("已解決")) body.tags.push("已解決");

  const draft: NormalizedQuestionDraft = {
    rawQuestion: text,
    normalizedText: body.normalizedText,
    intents: body.intents,
    emotion: body.emotion,
    knownInfo: body.knownInfo,
    missingInfo: body.missingInfo,
    urgency: body.urgency,
    counselorSummary: body.counselorSummary,
    tags: body.tags,
    noveltyScore: clamp01(1 - closestScore),
    closestKbTitle: closestTitle,
    closestKbScore: closestScore,
    thresholdUsed: threshold,
    resolved: aiConfident,
    resolvedReason: aiConfident
      ? "AI 在這次回覆已給出明確答案（不需要 handoff）"
      : "",
    answerScore: 0,
    closestKbAnswer: "",
    generatedBy,
  };
  return { stored: true, draft };
}

// ---------------------------------------------------------------------------
// GEMINI
// ---------------------------------------------------------------------------
async function tryGemini(opts: {
  question: string;
  profile: Profile | null;
  persona: Persona | null;
  history: ChatMessage[];
}): Promise<JsonShape | null> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) return null;

  const primary = process.env.GEMINI_MODEL?.trim() || "gemini-2.5-flash";
  const fallback =
    process.env.GEMINI_FALLBACK_MODEL?.trim() || "gemini-2.5-flash-lite";
  const models = primary === fallback ? [primary] : [primary, fallback];

  const profileLine = opts.profile
    ? [
        `姓名：${opts.profile.name || "—"}`,
        `科系：${opts.profile.department || "—"}`,
        `年級：${opts.profile.grade || "—"}`,
        `階段：${opts.profile.currentStage || "—"}`,
        `想創業：${opts.profile.startupInterest ? "是" : "否"}`,
        `目標：${(opts.profile.goals ?? []).join("、") || "—"}`,
        `興趣：${(opts.profile.interests ?? []).join("、") || "—"}`,
      ].join("｜")
    : "—";
  const personaLine = opts.persona
    ? `自介：${opts.persona.text || "—"}`
    : "—";
  const recent = (opts.history ?? [])
    .slice(-6)
    .map(
      (m) => `${m.role === "user" ? "使用者" : "助理"}：${m.text.slice(0, 400)}`,
    )
    .join("\n");

  const userPrompt =
    `=== 使用者基本資料 ===\n${profileLine}\n\n` +
    `=== Persona ===\n${personaLine}\n\n` +
    `=== 最近對話（由舊到新） ===\n${recent || "（這是第一句）"}\n\n` +
    `=== 這次的問題 ===\n${opts.question}\n\n` +
    `=== 任務 ===\n` +
    `請輸出一份 JSON，欄位完全照下面（缺漏的用空字串／空陣列）：\n` +
    `{\n` +
    `  "normalizedText": "把這個問題改寫成一句中性、可被諮詢師快速理解的標準問句（不要含情緒）",\n` +
    `  "intents": ["從這幾個選 1–3 個：職涯探索, 履歷協助, 面試準備, 實習尋找, 求職規劃, 技能盤點, 創業諮詢, 資源／政策, 心理支持, 一般諮詢"],\n` +
    `  "emotion": "情緒（焦慮、想釐清、有動能、信心受挫... 一個短語）",\n` +
    `  "knownInfo": ["這個訊息／使用者資料裡『已經知道』的事，最多 5 條"],\n` +
    `  "missingInfo": ["諮詢前還需要先確認的關鍵資訊，最多 5 條"],\n` +
    `  "urgency": "從 低 / 中 / 中高 / 高 中挑一個",\n` +
    `  "counselorSummary": "3–5 句給諮詢師的摘要：背景、現在卡在哪、希望被怎麼回",\n` +
    `  "tags": ["短屬性標籤，最多 5 個。例如：應屆生、跨領域、創業早期、家裡反對、缺作品集、轉職、面試焦慮"]\n` +
    `}\n` +
    `只輸出 JSON 本身。`;

  const requestBody = JSON.stringify({
    system_instruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
    contents: [{ role: "user", parts: [{ text: userPrompt }] }],
    generationConfig: {
      temperature: 0.25,
      maxOutputTokens: 700,
      responseMimeType: "application/json",
    },
  });

  for (const model of models) {
    try {
      const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
        model,
      )}:generateContent`;
      const res = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: requestBody,
      });
      if (!res.ok) {
        const body = await res.text().catch(() => "");
        console.error(
          `[normalizeQuestion] ${model} HTTP ${res.status}: ${body.slice(0, 200)}`,
        );
        if (res.status === 429 || res.status >= 500) continue;
        return null;
      }
      const json = (await res.json()) as {
        candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
      };
      const text = (json.candidates?.[0]?.content?.parts ?? [])
        .map((p) => p.text ?? "")
        .join("")
        .trim();
      if (!text) continue;
      const parsed = safeParse(text);
      if (parsed) return normalize(parsed);
    } catch (err) {
      console.error("[normalizeQuestion] gemini call failed:", err);
    }
  }
  return null;
}

function safeParse(text: string): Partial<JsonShape> | null {
  let body = text.trim();
  const fence = body.match(/```(?:json)?\s*([\s\S]+?)\s*```/i);
  if (fence) body = fence[1];
  if (!body.startsWith("{")) {
    const first = body.indexOf("{");
    const last = body.lastIndexOf("}");
    if (first === -1 || last === -1 || last < first) return null;
    body = body.slice(first, last + 1);
  }
  try {
    return JSON.parse(body) as Partial<JsonShape>;
  } catch {
    return null;
  }
}

function normalize(input: Partial<JsonShape>): JsonShape {
  const allowedUrg: JsonShape["urgency"][] = ["低", "中", "中高", "高"];
  const urgency = allowedUrg.includes(input.urgency as JsonShape["urgency"])
    ? (input.urgency as JsonShape["urgency"])
    : "中";
  const arr = (v: unknown): string[] =>
    Array.isArray(v)
      ? v
          .map((x) => (typeof x === "string" ? x.trim() : ""))
          .filter((x) => x.length > 0)
      : [];
  return {
    normalizedText:
      typeof input.normalizedText === "string"
        ? input.normalizedText.trim()
        : "",
    intents: arr(input.intents).slice(0, 4),
    emotion: typeof input.emotion === "string" ? input.emotion.trim() : "",
    knownInfo: arr(input.knownInfo).slice(0, 6),
    missingInfo: arr(input.missingInfo).slice(0, 6),
    urgency,
    counselorSummary:
      typeof input.counselorSummary === "string"
        ? input.counselorSummary.trim()
        : "",
    tags: arr(input.tags).slice(0, 6),
  };
}

// ---------------------------------------------------------------------------
// HEURISTIC FALLBACK — 沿用既有規則式 normalizer，再補上 tag
// ---------------------------------------------------------------------------
function buildHeuristic(question: string, profile: Profile | null): JsonShape {
  const local = localNormalize(question);
  const tags: string[] = [];
  if (profile?.startupInterest) tags.push("創業傾向");
  if (profile?.grade) tags.push(profile.grade);
  if (/應屆|快畢業/.test(question)) tags.push("應屆生");
  if (/沒回音|沒回應|被拒/.test(question)) tags.push("投履歷沒回音");
  if (/家人|爸|媽|父母/.test(question)) tags.push("家庭壓力");
  if (/作品集|portfolio/i.test(question)) tags.push("缺作品集");
  return {
    normalizedText: question.replace(/\s+/g, " ").trim(),
    intents: local.intents,
    emotion: local.emotion,
    knownInfo: local.knownInfo,
    missingInfo: local.missingInfo,
    urgency: local.urgency,
    counselorSummary: local.counselorSummary,
    tags,
  };
}

function clamp01(v: number) {
  if (Number.isNaN(v)) return 0;
  if (v < 0) return 0;
  if (v > 1) return 1;
  return Math.round(v * 1000) / 1000;
}
