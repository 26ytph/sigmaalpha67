import { KNOWLEDGE_BASE_SEED } from "@/data/knowledgeBase";
import { newId, store } from "@/lib/store";
import type { Persona } from "@/types/persona";
import type { Profile } from "@/types/profile";
import type {
  KnowledgeCategory,
  KnowledgeChunk,
  KnowledgeSource,
  KnowledgeSourceInput,
  KnowledgeSourceType,
  RagLog,
  RetrievedKnowledgeChunk,
} from "@/types/knowledge";

const VECTOR_SIZE = 192;
const DEFAULT_TOP_K = 5;
const MIN_QUERY_SCORE = 0.055;

const CATEGORY_LABELS: Record<KnowledgeCategory, string> = {
  career_consulting: "職涯諮詢",
  course: "課程活動",
  subsidy: "補助津貼",
  startup: "創業資源",
  internship: "實習資源",
  faq: "歷史 FAQ",
  space: "場地空間",
  international: "國際資源",
  housing: "居住資源",
  other: "其他",
};

const RAG_TRIGGER_TERMS = [
  "政策",
  "補助",
  "津貼",
  "貸款",
  "課程",
  "講座",
  "工作坊",
  "職涯諮詢",
  "履歷健檢",
  "創業",
  "青創",
  "實習",
  "工讀",
  "資源",
  "申請",
  "預約",
  "資格",
  "文組",
  "資料分析",
  "sql",
  "共享空間",
  "咖啡廳",
];

const KNOWN_TERMS = [
  ...RAG_TRIGGER_TERMS,
  "大學生",
  "應屆畢業",
  "待業",
  "轉職",
  "求職",
  "面試",
  "履歷",
  "作品集",
  "技能翻譯",
  "職涯探索",
  "職涯方向",
  "進修",
  "資料整理",
  "excel",
  "python",
  "ux research",
  "行銷分析",
  "資料分析助理",
  "商業模式",
  "市場驗證",
  "創業諮詢",
  "創業課程",
  "創業貸款",
  "創業補助",
  "寵物友善咖啡廳",
  "青年局",
  "臺北青年職涯發展中心",
  "tys",
  "star",
];

const EXPANSIONS: Array<{ match: string[]; add: string[] }> = [
  {
    match: ["文組"],
    add: ["技能翻譯", "履歷", "職涯焦慮", "企劃", "溝通", "資料整理", "職涯諮詢"],
  },
  {
    match: ["資料分析", "數據分析", "data"],
    add: ["SQL", "Excel", "Python", "資料整理", "資料分析助理", "作品集"],
  },
  {
    match: ["履歷", "cv", "resume"],
    add: ["履歷健檢", "面試", "STAR", "求職", "職涯諮詢", "技能翻譯"],
  },
  {
    match: ["補助", "津貼", "補貼"],
    add: ["申請", "資格", "文件", "期限", "課程補助", "實習津貼"],
  },
  {
    match: ["創業", "青創", "startup"],
    add: ["創業諮詢", "創業貸款", "商業模式", "市場驗證", "共享空間", "創業課程"],
  },
  {
    match: ["咖啡廳", "寵物友善咖啡廳"],
    add: ["創業", "創業諮詢", "商業模式", "市場驗證", "創業貸款", "創業課程"],
  },
  {
    match: ["實習"],
    add: ["實習津貼", "職場實習", "暑期工讀", "履歷素材", "在學青年"],
  },
  {
    match: ["諮詢"],
    add: ["職涯諮詢", "創業諮詢", "預約", "接手包", "一對一"],
  },
];

type QueryIntent = "startup" | "course" | "subsidy" | "career" | "internship" | "faq" | "general";

export type RagQueryResult = {
  answer: string;
  retrievedChunks: RetrievedKnowledgeChunk[];
  confidenceScore: number;
  shouldHandoff: boolean;
  logId: string;
  provider: "gemini" | "local";
};

export function shouldUseRag(question: string, mode?: "career" | "startup"): boolean {
  const q = question.toLowerCase();
  if (mode === "startup") return true;
  return RAG_TRIGGER_TERMS.some((term) => q.includes(term.toLowerCase()));
}

export function ensureKnowledgeBaseSeeded(): void {
  if (store.knowledgeSeeded) return;
  indexKnowledgeSources(KNOWLEDGE_BASE_SEED);
  store.knowledgeSeeded = true;
}

export function indexKnowledgeSources(
  sources: KnowledgeSourceInput[],
  opts: { replace?: boolean } = {},
): { sources: KnowledgeSource[]; chunks: KnowledgeChunk[] } {
  if (opts.replace) {
    store.knowledgeSources.clear();
    store.knowledgeChunks.clear();
    store.knowledgeSeeded = true;
  }

  const upsertedSources: KnowledgeSource[] = [];
  const upsertedChunks: KnowledgeChunk[] = [];
  for (const input of sources) {
    const { source, chunks } = upsertKnowledgeSource(input);
    upsertedSources.push(source);
    upsertedChunks.push(...chunks);
  }

  return { sources: upsertedSources, chunks: upsertedChunks };
}

export function reindexKnowledgeChunks(): KnowledgeChunk[] {
  ensureKnowledgeBaseSeeded();
  store.knowledgeChunks.clear();
  const chunks: KnowledgeChunk[] = [];
  for (const source of store.knowledgeSources.values()) {
    const nextChunks = chunkKnowledgeSource(source);
    for (const chunk of nextChunks) store.knowledgeChunks.set(chunk.id, chunk);
    chunks.push(...nextChunks);
  }
  return chunks;
}

export function upsertKnowledgeSource(input: KnowledgeSourceInput): {
  source: KnowledgeSource;
  chunks: KnowledgeChunk[];
} {
  const now = new Date().toISOString();
  const existing = input.id ? store.knowledgeSources.get(input.id) : undefined;
  const source: KnowledgeSource = {
    ...input,
    id: input.id ?? newId("ks"),
    approvedByCounselor: input.approvedByCounselor ?? existing?.approvedByCounselor ?? false,
    createdAt: input.createdAt ?? existing?.createdAt ?? now,
    updatedAt: input.updatedAt ?? now,
  };

  store.knowledgeSources.set(source.id, source);
  for (const chunk of store.knowledgeChunks.values()) {
    if (chunk.sourceId === source.id) store.knowledgeChunks.delete(chunk.id);
  }

  const chunks = chunkKnowledgeSource(source);
  for (const chunk of chunks) store.knowledgeChunks.set(chunk.id, chunk);
  return { source, chunks };
}

export function searchKnowledge(opts: {
  query: string;
  topK?: number;
  category?: KnowledgeCategory;
  sourceType?: KnowledgeSourceType;
}): RetrievedKnowledgeChunk[] {
  ensureKnowledgeBaseSeeded();

  const topK = clampTopK(opts.topK);
  const queryTokens = expandTokens(extractTokens(opts.query));
  const queryEmbedding = embedTokens(queryTokens);
  const intent = detectIntent(opts.query);

  const scored = [...store.knowledgeChunks.values()]
    .map((chunk) => {
      const source = store.knowledgeSources.get(chunk.sourceId);
      if (!source) return null;
      if (opts.category && source.category !== opts.category) return null;
      if (opts.sourceType && source.sourceType !== opts.sourceType) return null;

      const sourceText = sourceToText(source);
      const sourceTokens = expandTokens(extractTokens(sourceText));
      const vectorScore = cosineSimilarity(queryEmbedding, chunk.embedding);
      const overlapScore = tokenOverlap(queryTokens, sourceTokens);
      const boost = metadataBoost(intent, source, opts.query);
      const score = Math.min(1, vectorScore * 0.68 + overlapScore * 0.24 + boost);

      return toRetrievedChunk(chunk, source, roundScore(score));
    })
    .filter((item): item is RetrievedKnowledgeChunk => Boolean(item))
    .filter((item) => item.score >= MIN_QUERY_SCORE)
    .sort((a, b) => b.score - a.score);

  return scored.slice(0, topK);
}

export async function answerRagQuery(opts: {
  userId: string;
  question: string;
  persona?: Persona | null;
  profile?: Profile | null;
  topK?: number;
  category?: KnowledgeCategory;
  sourceType?: KnowledgeSourceType;
  history?: Array<{ role: "user" | "assistant"; text: string }>;
}): Promise<RagQueryResult> {
  const retrievedChunks = searchKnowledge({
    query: buildSearchQuery(opts),
    topK: opts.topK ?? DEFAULT_TOP_K,
    category: opts.category,
    sourceType: opts.sourceType,
  });

  const confidenceScore = calculateConfidence(retrievedChunks);
  const shouldHandoff = shouldHandoffToCounselor(opts.question, retrievedChunks, confidenceScore);
  const geminiAnswer = await generateWithGemini({
    question: opts.question,
    persona: opts.persona,
    profile: opts.profile,
    retrievedChunks,
    confidenceScore,
    shouldHandoff,
    history: opts.history,
  });

  const provider = geminiAnswer ? "gemini" : "local";
  const answer =
    geminiAnswer ??
    buildLocalAnswer({
      question: opts.question,
      persona: opts.persona,
      profile: opts.profile,
      retrievedChunks,
      confidenceScore,
      shouldHandoff,
    });

  const log: RagLog = {
    id: newId("raglog"),
    userId: opts.userId,
    question: opts.question,
    retrievedChunks,
    answer,
    confidenceScore,
    shouldHandoff,
    provider,
    createdAt: new Date().toISOString(),
  };
  store.ragLogs.push(log);

  return {
    answer,
    retrievedChunks,
    confidenceScore,
    shouldHandoff,
    logId: log.id,
    provider,
  };
}

/**
 * 語意相似度（0..1）— 用 chunk 同款的 token + cosine + overlap，
 * 主要拿來判斷「LLM 生成的回答」跟「KB 既有答案」夠不夠像。
 * 不引入新的 embedding stack；和 searchKnowledge 的打分維持一致 spirit。
 */
export function scoreTextSimilarity(a: string, b: string): number {
  const ta = expandTokens(extractTokens(a ?? ""));
  const tb = expandTokens(extractTokens(b ?? ""));
  if (ta.length === 0 || tb.length === 0) return 0;
  const vectorScore = cosineSimilarity(embedTokens(ta), embedTokens(tb));
  const overlapScore = tokenOverlap(ta, tb);
  return roundScore(Math.min(1, vectorScore * 0.7 + overlapScore * 0.3));
}

export function buildCounselorFaqSource(opts: {
  question: string;
  answer: string;
  caseId?: string;
  tags?: string[];
}): KnowledgeSourceInput {
  return {
    id: opts.caseId ? `case_faq_${opts.caseId}` : undefined,
    title: `諮詢師審核 FAQ：${trimText(opts.question, 42)}`,
    category: "faq",
    sourceType: "counselor_case",
    content: `Q: ${opts.question}\nA: ${opts.answer}`,
    targetUser: ["青年使用者", "諮詢師"],
    tags: opts.tags ?? ["諮詢師審核", "歷史案例"],
    approvedByCounselor: true,
  };
}

function chunkKnowledgeSource(source: KnowledgeSource): KnowledgeChunk[] {
  const baseText = sourceToText(source);
  const maxLength = 1200;
  const rawChunks =
    baseText.length <= maxLength
      ? [baseText]
      : baseText.match(new RegExp(`[\\s\\S]{1,${maxLength}}`, "g")) ?? [baseText];

  return rawChunks.map((chunkText, index) => ({
    id: `${source.id}_chunk_${String(index + 1).padStart(2, "0")}`,
    sourceId: source.id,
    title: source.title,
    chunkText,
    metadata: {
      category: source.category,
      sourceType: source.sourceType,
      sourceUrl: source.sourceUrl,
      eligibility: source.eligibility,
      applicationMethod: source.applicationMethod,
      targetUser: source.targetUser,
      stage: source.stage,
      relatedSkills: source.relatedSkills,
      suitableFor: source.suitableFor,
      requiredDocuments: source.requiredDocuments,
      tags: source.tags,
      approvedByCounselor: source.approvedByCounselor,
      chunkIndex: index,
    },
    embedding: embedText(`${chunkText}\n${JSON.stringify(source.metadata ?? {})}`),
    createdAt: new Date().toISOString(),
  }));
}

function sourceToText(source: KnowledgeSource): string {
  return [
    `標題：${source.title}`,
    `類別：${CATEGORY_LABELS[source.category]}`,
    `內容：${source.content}`,
    source.eligibility ? `申請資格：${source.eligibility}` : "",
    source.applicationMethod ? `申請方式：${source.applicationMethod}` : "",
    source.targetUser?.length ? `適合對象：${source.targetUser.join("、")}` : "",
    source.stage?.length ? `創業階段：${source.stage.join("、")}` : "",
    source.relatedSkills?.length ? `相關技能：${source.relatedSkills.join("、")}` : "",
    source.suitableFor?.length ? `適合職務：${source.suitableFor.join("、")}` : "",
    source.requiredDocuments?.length ? `準備文件：${source.requiredDocuments.join("、")}` : "",
    source.tags?.length ? `標籤：${source.tags.join("、")}` : "",
    source.sourceUrl ? `來源：${source.sourceUrl}` : "",
  ]
    .filter(Boolean)
    .join("\n");
}

function toRetrievedChunk(
  chunk: KnowledgeChunk,
  source: KnowledgeSource,
  score: number,
): RetrievedKnowledgeChunk {
  return {
    chunkId: chunk.id,
    sourceId: source.id,
    title: source.title,
    category: source.category,
    sourceType: source.sourceType,
    sourceUrl: source.sourceUrl,
    chunkText: chunk.chunkText,
    score,
    metadata: chunk.metadata,
  };
}

function buildSearchQuery(opts: {
  question: string;
  persona?: Persona | null;
  profile?: Profile | null;
}): string {
  const personaText = opts.persona
    ? [
        opts.persona.text,
        opts.persona.careerStage,
        opts.persona.mainInterests.join(" "),
        opts.persona.skillGaps.join(" "),
        opts.persona.mainConcerns.join(" "),
      ].join(" ")
    : "";
  const profileText = opts.profile
    ? [
        opts.profile.department,
        opts.profile.grade,
        opts.profile.currentStage,
        opts.profile.goals.join(" "),
        opts.profile.interests.join(" "),
        opts.profile.concerns,
        opts.profile.startupInterest ? "創業" : "",
      ].join(" ")
    : "";
  return `${opts.question}\n${personaText}\n${profileText}`.trim();
}

function extractTokens(text: string): string[] {
  const normalized = text.toLowerCase();
  const tokens: string[] = [];
  tokens.push(...(normalized.match(/[a-z0-9+#.]+/g) ?? []));

  for (const term of KNOWN_TERMS) {
    const t = term.toLowerCase();
    if (normalized.includes(t)) tokens.push(t);
  }

  for (const segment of normalized.match(/[\u4e00-\u9fff]{2,}/g) ?? []) {
    if (segment.length <= 4) {
      tokens.push(segment);
      continue;
    }
    for (let i = 0; i < segment.length - 1; i += 1) tokens.push(segment.slice(i, i + 2));
    for (let i = 0; i < segment.length - 2; i += 1) tokens.push(segment.slice(i, i + 3));
  }

  return tokens.filter((token) => token.length > 1);
}

function expandTokens(tokens: string[]): string[] {
  const expanded = [...tokens];
  const tokenText = tokens.join(" ");
  for (const rule of EXPANSIONS) {
    if (rule.match.some((term) => tokenText.includes(term.toLowerCase()))) {
      expanded.push(...rule.add.map((term) => term.toLowerCase()));
    }
  }
  return expanded;
}

function embedText(text: string): number[] {
  return embedTokens(expandTokens(extractTokens(text)));
}

function embedTokens(tokens: string[]): number[] {
  const vector = Array.from({ length: VECTOR_SIZE }, () => 0);
  for (const token of tokens) {
    const hash = hashToken(token);
    const weight = token.length >= 4 ? 1.35 : 1;
    vector[hash % VECTOR_SIZE] += weight;
  }
  return normalizeVector(vector);
}

function hashToken(token: string): number {
  let hash = 2166136261;
  for (let i = 0; i < token.length; i += 1) {
    hash ^= token.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function normalizeVector(vector: number[]): number[] {
  const length = Math.sqrt(vector.reduce((sum, value) => sum + value * value, 0));
  if (!length) return vector;
  return vector.map((value) => value / length);
}

function cosineSimilarity(a: number[], b: number[]): number {
  let sum = 0;
  for (let i = 0; i < Math.min(a.length, b.length); i += 1) sum += a[i] * b[i];
  return Math.max(0, sum);
}

function tokenOverlap(queryTokens: string[], docTokens: string[]): number {
  const query = new Set(queryTokens);
  const doc = new Set(docTokens);
  let hits = 0;
  for (const token of query) {
    if (doc.has(token)) hits += 1;
  }
  return query.size ? Math.min(1, hits / Math.sqrt(query.size * Math.max(1, doc.size))) : 0;
}

function detectIntent(question: string): QueryIntent {
  const q = question.toLowerCase();
  if (/創業|青創|貸款|咖啡廳|商業模式|startup/.test(q)) return "startup";
  if (/課程|講座|工作坊|學|sql|資料分析|excel|python/.test(q)) return "course";
  if (/補助|津貼|補貼|申請|資格/.test(q)) return "subsidy";
  if (/實習|工讀/.test(q)) return "internship";
  if (/文組|焦慮|不好找|沒有經驗/.test(q)) return "faq";
  if (/職涯|履歷|面試|諮詢|求職|轉職/.test(q)) return "career";
  return "general";
}

function metadataBoost(intent: QueryIntent, source: KnowledgeSource, question: string): number {
  let boost = 0;
  const q = question.toLowerCase();

  if (intent === "startup" && ["startup", "space"].includes(source.category)) boost += 0.12;
  if (intent === "course" && source.category === "course") boost += 0.12;
  if (intent === "subsidy" && ["subsidy", "internship", "startup"].includes(source.category)) boost += 0.1;
  if (intent === "career" && source.category === "career_consulting") boost += 0.1;
  if (intent === "internship" && source.category === "internship") boost += 0.12;
  if (intent === "faq" && source.sourceType === "faq") boost += 0.12;
  if (source.approvedByCounselor) boost += 0.025;

  for (const tag of source.tags ?? []) {
    if (q.includes(tag.toLowerCase())) boost += 0.035;
  }

  return Math.min(0.22, boost);
}

function calculateConfidence(chunks: RetrievedKnowledgeChunk[]): number {
  if (chunks.length === 0) return 0;
  const top = chunks[0].score;
  const second = chunks[1]?.score ?? 0;
  const support = Math.min(0.12, chunks.length * 0.025);
  return roundScore(Math.min(0.98, top + second * 0.18 + support));
}

function shouldHandoffToCounselor(
  question: string,
  chunks: RetrievedKnowledgeChunk[],
  confidenceScore: number,
): boolean {
  if (chunks.length === 0 || confidenceScore < 0.24) return true;
  if (/很焦慮|崩潰|不知道怎麼辦|資格不確定|最新|逐字|合約|法律|醫療/.test(question)) return true;
  if (/申請資格|能不能申請|可不可以申請/.test(question) && chunks.length < 3) return true;
  return false;
}

async function generateWithGemini(opts: {
  question: string;
  persona?: Persona | null;
  profile?: Profile | null;
  retrievedChunks: RetrievedKnowledgeChunk[];
  confidenceScore: number;
  shouldHandoff: boolean;
  history?: Array<{ role: "user" | "assistant"; text: string }>;
}): Promise<string | null> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey || opts.retrievedChunks.length === 0) return null;

  const primaryModel = process.env.GEMINI_MODEL || "gemini-2.5-flash";
  const fallbackModel =
    process.env.GEMINI_FALLBACK_MODEL || "gemini-2.5-flash-lite";
  const modelsToTry = primaryModel === fallbackModel
    ? [primaryModel]
    : [primaryModel, fallbackModel];

  const systemInstruction =
    "你是 EmploYA! 的青年職涯與創業助理「小幫手」，正在跟一位青年朋友聊天。" +
    "用繁體中文、口語、溫暖、像朋友的口氣回覆，3 到 6 句話即可，避免條列、標題與「**問題理解：**」之類的格式化區塊。" +
    "把檢索到最相關的 1 到 2 個資源自然地融入句子裡（例如「你可以看看《xxx》這個資源」），" +
    "不需要重複條列其他資源、不需要重複貼網址（系統會在訊息下方自動把卡片貼上來）。" +
    "若資料不足或不確定使用者個人資格，誠實說，並引導使用者補充哪一段資訊或預約諮詢師。" +
    "禁止編造政策名稱、補助金額、申請資格或網址。";

  const context = {
    persona: opts.persona ?? null,
    profile: opts.profile
      ? {
          department: opts.profile.department,
          grade: opts.profile.grade,
          currentStage: opts.profile.currentStage,
          goals: opts.profile.goals,
          interests: opts.profile.interests,
          concerns: opts.profile.concerns,
          startupInterest: opts.profile.startupInterest,
        }
      : null,
    confidenceScore: opts.confidenceScore,
    shouldHandoff: opts.shouldHandoff,
    retrievedChunks: opts.retrievedChunks.map((chunk) => ({
      title: chunk.title,
      category: CATEGORY_LABELS[chunk.category],
      sourceUrl: chunk.sourceUrl,
      score: chunk.score,
      content: chunk.chunkText,
    })),
  };

  const recentHistory = (opts.history ?? []).slice(-6);
  const historyContents = recentHistory.map((h) => ({
    role: h.role === "assistant" ? "model" : "user",
    parts: [{ text: h.text }],
  }));

  const requestBody = JSON.stringify({
    system_instruction: { parts: [{ text: systemInstruction }] },
    contents: [
      ...historyContents,
      {
        role: "user",
        parts: [
          {
            text: `使用者最新問題：${opts.question}\n\n根據以下檢索資料以及上面的對話脈絡回答（記得參考使用者前面說過什麼，不要要求重複資訊）：\n${JSON.stringify(context)}`,
          },
        ],
      },
    ],
    generationConfig: {
      temperature: 0.2,
      maxOutputTokens: 900,
    },
  });

  for (const model of modelsToTry) {
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
      model,
    )}:generateContent`;
    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: requestBody,
      });

      if (!response.ok) {
        const body = await response.text().catch(() => "");
        console.error(
          `[rag.gemini] [${model}] HTTP ${response.status}: ${body.slice(0, 200)}`,
        );
        if (response.status === 429 || response.status >= 500) continue;
        return null;
      }
      const json = (await response.json()) as {
        candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
      };
      const text = json.candidates?.[0]?.content?.parts
        ?.map((part) => part.text ?? "")
        .join("")
        .trim();
      if (text) return text;
    } catch (err) {
      console.error(`[rag.gemini] [${model}] threw:`, err);
      continue;
    }
  }
  return null;
}

function buildLocalAnswer(opts: {
  question: string;
  persona?: Persona | null;
  profile?: Profile | null;
  retrievedChunks: RetrievedKnowledgeChunk[];
  confidenceScore: number;
  shouldHandoff: boolean;
}): string {
  if (opts.retrievedChunks.length === 0) {
    return [
      `我理解你的問題是：「${opts.question}」。`,
      "目前知識庫沒有找到足夠接近的政策、課程、創業資源或歷史案例，因此不適合直接給出政策名稱或申請條件。",
      "下一步建議：補充你的年齡、身分、目前階段、所在地、想申請的資源類型，再轉交諮詢師確認。",
      "是否建議轉交諮詢師：是。",
    ].join("\n\n");
  }

  const intent = detectIntent(opts.question);
  const sourceLines = opts.retrievedChunks
    .slice(0, DEFAULT_TOP_K)
    .map((chunk, index) => {
      const source = store.knowledgeSources.get(chunk.sourceId);
      const detail = source ? pickSourceDetail(source) : trimText(chunk.chunkText, 110);
      const url = chunk.sourceUrl ? `\n   來源：${chunk.sourceUrl}` : "";
      return `${index + 1}. ${chunk.title}（${CATEGORY_LABELS[chunk.category]}，相似度 ${chunk.score.toFixed(
        2,
      )}）\n   ${detail}${url}`;
    })
    .join("\n");

  const personaHint = buildPersonaHint(opts.persona, opts.profile);
  const nextStep = buildNextStep(intent, opts.retrievedChunks);
  const handoffLine = opts.shouldHandoff
    ? "是否建議轉交諮詢師：是。原因是這題可能需要確認個人資格、最新受理狀態或更細的背景資料。"
    : "是否建議轉交諮詢師：暫時不一定。若你要確認資格、文件或申請期限，再轉給諮詢師會更穩。";

  return [
    `我理解你的問題是：「${opts.question}」。${personaHint}`,
    `根據目前知識庫，較相關的資源有：\n${sourceLines}`,
    `適合原因：這些資料和你的問題中的「${intentLabel(intent)}」需求最接近，可先用來判斷方向，但實際資格、金額與受理狀態仍要以來源頁面或諮詢師確認為準。`,
    `下一步行動：${nextStep}`,
    handoffLine,
  ].join("\n\n");
}

function pickSourceDetail(source: KnowledgeSource): string {
  const parts = [
    trimText(source.content, 115),
    source.eligibility ? `資格：${trimText(source.eligibility, 70)}` : "",
    source.applicationMethod ? `方式：${trimText(source.applicationMethod, 70)}` : "",
  ].filter(Boolean);
  return parts.join(" ");
}

function buildPersonaHint(persona?: Persona | null, profile?: Profile | null): string {
  const hints = [
    persona?.mainInterests?.length ? `你的 Persona 興趣包含 ${persona.mainInterests.slice(0, 2).join("、")}` : "",
    persona?.skillGaps?.length ? `技能缺口包含 ${persona.skillGaps.slice(0, 2).join("、")}` : "",
    profile?.currentStage ? `目前階段是 ${profile.currentStage}` : "",
  ].filter(Boolean);
  return hints.length ? ` 我也會把「${hints.join("；")}」納入排序參考。` : "";
}

function buildNextStep(intent: QueryIntent, chunks: RetrievedKnowledgeChunk[]): string {
  const titles = chunks.map((chunk) => chunk.title).join("、");
  if (intent === "startup") {
    return "先把創業想法整理成目標客群、服務內容、成本與目前階段，再預約創業諮詢；若已進入籌備或營運初期，再評估青創貸款、共享空間或創業課程。";
  }
  if (intent === "course") {
    return "先選一門入門課建立作品或履歷素材；若你的目標是資料分析，建議從 SQL、Excel 資料整理與小型作品集開始。";
  }
  if (intent === "subsidy") {
    return "先確認年齡、身分、設籍或就學條件、申請期限、是否能與其他補助併用，再準備證明文件與計畫資料。";
  }
  if (intent === "internship") {
    return "先確認你要找的是實習機會、實習津貼或暑期工讀，再準備履歷、實習證明與申請所需文件。";
  }
  if (intent === "career" || intent === "faq") {
    return "先盤點 2 到 3 個具體經驗，改寫成履歷語言；若仍卡住，可預約職涯諮詢或履歷健檢。";
  }
  return `先閱讀 ${titles}，再補充你的年齡、身分、目前階段與想申請的資源類型。`;
}

function intentLabel(intent: QueryIntent): string {
  const labels: Record<QueryIntent, string> = {
    startup: "創業資源",
    course: "課程學習",
    subsidy: "補助津貼",
    career: "職涯諮詢",
    internship: "實習資源",
    faq: "歷史案例",
    general: "青年資源",
  };
  return labels[intent];
}

function clampTopK(topK?: number): number {
  if (!topK || Number.isNaN(topK)) return DEFAULT_TOP_K;
  return Math.min(10, Math.max(1, Math.floor(topK)));
}

function trimText(text: string, maxLength: number): string {
  return text.length > maxLength ? `${text.slice(0, maxLength)}...` : text;
}

function roundScore(score: number): number {
  return Math.round(score * 1000) / 1000;
}
