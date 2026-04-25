/**
 * Stored row for `public.normalized_questions`.
 * 只有「不在 RAG 既有知識庫」中的新問題才會被記錄。
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
  generatedBy: string;
  createdAt: string;
};

/** 還沒寫進 DB 之前 AI engine 輸出的中介格式 */
export type NormalizedQuestionDraft = Omit<
  StoredNormalizedQuestion,
  "id" | "userId" | "conversationId" | "messageId" | "createdAt"
>;
