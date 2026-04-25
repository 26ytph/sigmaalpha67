/**
 * Stored row for `public.normalized_questions`.
 *
 * 兩種情境都會被寫入：
 *   1) 全新問題（KB 沒命中）→ resolved = false
 *   2) KB 命中 + 助理回答也跟 KB 既有答案夠像 → resolved = true
 *      （諮詢師可以一眼看出「這題其實 RAG 已經自動處理了」）
 * 而「KB 命中但答案有偏」這種 case 仍會被 store 成 resolved=false，
 * 讓諮詢師有機會 review 是不是 KB 過時了。
 */
export type StoredNormalizedQuestion = {
  id: string;
  userId: string;
  conversationId: string | null;
  messageId: string | null;
  rawQuestion: string;
  normalizedText: string;
  intents: string[];
  emotion: string;
  knownInfo: string[];
  missingInfo: string[];
  urgency: "低" | "中" | "中高" | "高";
  counselorSummary: string;
  tags: string[];
  noveltyScore: number;
  closestKbTitle: string;
  closestKbScore: number;
  thresholdUsed: number;
  // resolved tagging
  resolved: boolean;
  resolvedReason: string;
  answerScore: number;
  closestKbAnswer: string;
  generatedBy: string;
  createdAt: string;
};

/** 還沒寫進 DB 之前 AI engine 輸出的中介格式 */
export type NormalizedQuestionDraft = Omit<
  StoredNormalizedQuestion,
  "id" | "userId" | "conversationId" | "messageId" | "createdAt"
>;
