/**
 * User-insight engine.
 *
 * 把使用者的 profile + persona + 最近對話歷史餵給 Gemini，
 * 要它輸出結構化 JSON：問題定位、類別、情緒、具體擔憂、已試方案、卡關點、
 * 建議切入點、優先度、tags。
 *
 * Gemini key 沒設定 / 呼叫失敗時：fall back 到輕量規則式 heuristic，
 * 確保 user_insights 表至少有一份基本內容讓諮詢師看到，不會卡 demo。
 */

import type { Profile } from "@/types/profile";
import type { Persona } from "@/types/persona";
import type { ChatMessage } from "@/types/chat";
import type { UserInsightDraft, UserInsightPriority } from "@/types/insight";

// ---------------------------------------------------------------------------
// PROMPT
// ---------------------------------------------------------------------------
const SYSTEM_INSTRUCTION =
  "你是 EmploYA! 的青年職涯／創業諮詢輔助系統。" +
  "請根據使用者的個資、Persona 與最近對話，整理出諮詢師可以用來『一眼看懂這個人』的結構化分析。" +
  "重點是準確、不過度推論、用繁體中文、保持中性同理。" +
  "輸出必須是合法 JSON，不要加註解、Markdown、code fence。";

// 我們希望 Gemini 回傳的 JSON 結構
type JsonShape = {
  problemPositioning: string;
  categories: string[];
  emotionProfile: string;
  specificConcerns: string[];
  triedApproaches: string[];
  blockers: string[];
  recommendedTopics: string[];
  priority: UserInsightPriority;
  tags: string[];
  rawSummary: string;
};

// ---------------------------------------------------------------------------
// PUBLIC API
// ---------------------------------------------------------------------------
export async function generateUserInsight(opts: {
  profile?: Profile | null;
  persona?: Persona | null;
  messages: ChatMessage[];
}): Promise<UserInsightDraft> {
  const trimmed = (opts.messages ?? []).slice(-30);

  const fromGemini = await tryGemini({
    profile: opts.profile ?? null,
    persona: opts.persona ?? null,
    messages: trimmed,
  });
  if (fromGemini) {
    return {
      ...fromGemini,
      messageCount: trimmed.length,
      generatedBy:
        process.env.GEMINI_MODEL?.trim() || "gemini-2.5-flash",
    };
  }

  const heur = buildHeuristic({
    profile: opts.profile ?? null,
    persona: opts.persona ?? null,
    messages: trimmed,
  });
  return {
    ...heur,
    messageCount: trimmed.length,
    generatedBy: "heuristic",
  };
}

// ---------------------------------------------------------------------------
// GEMINI
// ---------------------------------------------------------------------------
async function tryGemini(opts: {
  profile: Profile | null;
  persona: Persona | null;
  messages: ChatMessage[];
}): Promise<JsonShape | null> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) return null;

  const primaryModel = process.env.GEMINI_MODEL?.trim() || "gemini-2.5-flash";
  const fallbackModel =
    process.env.GEMINI_FALLBACK_MODEL?.trim() || "gemini-2.5-flash-lite";
  const modelsToTry =
    primaryModel === fallbackModel ? [primaryModel] : [primaryModel, fallbackModel];

  const profileLine = opts.profile
    ? [
        `姓名：${opts.profile.name || "—"}`,
        `學校：${opts.profile.school || "—"}`,
        `科系：${opts.profile.department || "—"}`,
        `年級：${opts.profile.grade || "—"}`,
        `階段：${opts.profile.currentStage || "—"}`,
        `想創業：${opts.profile.startupInterest ? "是" : "否"}`,
        `目標：${(opts.profile.goals ?? []).join("、") || "—"}`,
        `興趣：${(opts.profile.interests ?? []).join("、") || "—"}`,
        `經驗：${(opts.profile.experiences ?? []).join("、") || "—"}`,
        `困擾：${opts.profile.concerns || "—"}`,
      ].join("｜")
    : "—";

  const personaLine = opts.persona
    ? `自介：${opts.persona.text || "—"}｜階段：${opts.persona.careerStage || "—"}` +
      `｜興趣：${(opts.persona.mainInterests ?? []).join("、")}` +
      `｜既有能力：${(opts.persona.strengths ?? []).join("、")}` +
      `｜可補強：${(opts.persona.skillGaps ?? []).join("、")}`
    : "—";

  const dialogue = opts.messages
    .map(
      (m) => `${m.role === "user" ? "使用者" : "助理"}：${m.text.slice(0, 600)}`,
    )
    .join("\n");

  const userInstruction =
    `=== 使用者基本資料 ===\n${profileLine}\n\n` +
    `=== Persona ===\n${personaLine}\n\n` +
    `=== 最近對話（由舊到新） ===\n${dialogue || "（尚無對話）"}\n\n` +
    `=== 任務 ===\n` +
    `請輸出一份 JSON，結構必須完全符合下面的 key（缺漏的欄位用空字串或空陣列）：\n\n` +
    `{\n` +
    `  "problemPositioning": "1–2 句話總結這個人主要卡在哪。客觀，不要包含安撫或建議。",\n` +
    `  "categories": ["從這幾個類別中挑：職涯探索, 履歷協助, 面試準備, 實習尋找, 求職規劃, 技能盤點, 創業諮詢, 資源／政策, 心理支持, 一般諮詢"],\n` +
    `  "emotionProfile": "整體情緒輪廓，例如：偏焦慮但願意行動 / 想釐清不急 / 信心受挫",\n` +
    `  "specificConcerns": ["對話裡『實際提到』的事，公司/產業/技能/deadline，最多 6 條"],\n` +
    `  "triedApproaches": ["使用者已嘗試過的事，最多 5 條"],\n` +
    `  "blockers": ["真正在卡他的事，最多 5 條"],\n` +
    `  "recommendedTopics": ["諮詢師一上來談這 2–3 件事最有效"],\n` +
    `  "priority": "從 低 / 中 / 中高 / 高 中挑一個（依情緒急迫程度與時間壓力）",\n` +
    `  "tags": ["短標籤，最多 6 個，例如：應屆生 / 跨領域 / 家裡反對 / 創業早期 / 技能轉換"],\n` +
    `  "rawSummary": "3–5 句話自然語言摘要，給諮詢師快速看一眼用，不要套用模板"\n` +
    `}\n` +
    `只輸出 JSON 本身，前後不要加任何說明文字、code fence、或 Markdown。`;

  const requestBody = JSON.stringify({
    system_instruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
    contents: [{ role: "user", parts: [{ text: userInstruction }] }],
    generationConfig: {
      temperature: 0.3,
      maxOutputTokens: 800,
      responseMimeType: "application/json",
    },
  });

  for (const model of modelsToTry) {
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
          `[userInsight] ${model} HTTP ${res.status}: ${body.slice(0, 200)}`,
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
      console.error("[userInsight] gemini call failed:", err);
    }
  }
  return null;
}

function safeParse(text: string): JsonShape | null {
  // Gemini 偶爾還是會包 ```json ... ``` 或前後有解釋；嘗試擷取大括號。
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
    return JSON.parse(body) as JsonShape;
  } catch {
    return null;
  }
}

function normalize(input: Partial<JsonShape>): JsonShape {
  const allowedPriorities: UserInsightPriority[] = ["低", "中", "中高", "高"];
  const priority = allowedPriorities.includes(
    input.priority as UserInsightPriority,
  )
    ? (input.priority as UserInsightPriority)
    : "中";
  const arr = (v: unknown): string[] =>
    Array.isArray(v)
      ? v
          .map((x) => (typeof x === "string" ? x.trim() : ""))
          .filter((x) => x.length > 0)
      : [];
  return {
    problemPositioning:
      typeof input.problemPositioning === "string"
        ? input.problemPositioning.trim()
        : "",
    categories: arr(input.categories).slice(0, 8),
    emotionProfile:
      typeof input.emotionProfile === "string"
        ? input.emotionProfile.trim()
        : "",
    specificConcerns: arr(input.specificConcerns).slice(0, 8),
    triedApproaches: arr(input.triedApproaches).slice(0, 8),
    blockers: arr(input.blockers).slice(0, 8),
    recommendedTopics: arr(input.recommendedTopics).slice(0, 6),
    priority,
    tags: arr(input.tags).slice(0, 8),
    rawSummary:
      typeof input.rawSummary === "string" ? input.rawSummary.trim() : "",
  };
}

// ---------------------------------------------------------------------------
// HEURISTIC FALLBACK
// ---------------------------------------------------------------------------
function buildHeuristic(opts: {
  profile: Profile | null;
  persona: Persona | null;
  messages: ChatMessage[];
}): JsonShape {
  const userText = opts.messages
    .filter((m) => m.role === "user")
    .map((m) => m.text)
    .join("\n");

  const cats: string[] = [];
  if (/履歷|CV|resume/i.test(userText)) cats.push("履歷協助");
  if (/面試|interview/i.test(userText)) cats.push("面試準備");
  if (/實習/.test(userText)) cats.push("實習尋找");
  if (/方向|迷惘|不知道做什麼/.test(userText)) cats.push("職涯探索");
  if (/正職|找工作|就業/.test(userText)) cats.push("求職規劃");
  if (/創業|開店/.test(userText)) cats.push("創業諮詢");
  if (/補助|貸款|資金/.test(userText)) cats.push("資源／政策");
  if (/壓力|焦慮|累/.test(userText)) cats.push("心理支持");
  if (cats.length === 0) cats.push("一般諮詢");

  let priority: UserInsightPriority = "中";
  if (/明天|這週|快來不及/.test(userText)) priority = "高";
  else if (/壓力|焦慮|沮喪/.test(userText)) priority = "中高";

  const blockers: string[] = [];
  if (/沒回音|沒回應|被拒/.test(userText)) blockers.push("投履歷沒回音");
  if (/不知道.{0,4}方向/.test(userText)) blockers.push("方向不明確");
  if (/沒(經驗|作品)/.test(userText)) blockers.push("缺乏經驗或作品集");

  const tags: string[] = [];
  if (opts.profile?.startupInterest) tags.push("創業傾向");
  if (opts.profile?.grade) tags.push(opts.profile.grade);
  if (opts.profile?.currentStage) tags.push(opts.profile.currentStage);

  const positioning = [
    opts.profile?.department && `${opts.profile.department}學生`,
    opts.profile?.currentStage && `處於「${opts.profile.currentStage}」階段`,
    cats.length ? `主要關心${cats.slice(0, 2).join("、")}` : null,
  ]
    .filter(Boolean)
    .join("，") || "尚無足夠資料下定論";

  return {
    problemPositioning: positioning + "。",
    categories: cats,
    emotionProfile: priority === "高" ? "急迫、有壓力" : priority === "中高" ? "焦慮、有壓力" : "中性、想釐清",
    specificConcerns: opts.profile?.concerns ? [opts.profile.concerns] : [],
    triedApproaches: opts.profile?.experiences ?? [],
    blockers,
    recommendedTopics: [
      cats[0] ? `先聚焦在${cats[0]}` : "先釐清目前最在意的事",
      "確認時間壓力與資源限制",
    ],
    priority,
    tags,
    rawSummary:
      `（規則式摘要 — Gemini 不可用）${positioning}。情緒偏${priority}優先處理。` +
      (blockers.length ? `主要卡關：${blockers.join("、")}。` : ""),
  };
}
