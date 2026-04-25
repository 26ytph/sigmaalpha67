export type ChatRole = "user" | "assistant";

export type ChatMessage = {
  id: string;
  role: ChatRole;
  text: string;
  createdAt: string;
  /** True if this assistant message was actually sent by a human counselor. */
  fromCounselor?: boolean;
  /**
   * 對 user 訊息：true 代表這個問題已被 RAG/AI 處理掉
   * （normalized_questions.resolved=true），諮詢師端會淡化此 Q + 後續 AI 回覆。
   */
  resolved?: boolean;
};

export type ChatConversation = {
  id: string;
  userId: string;
  mode: "career" | "startup";
  messages: ChatMessage[];
  createdAt: string;
  updatedAt: string;
};

export type NormalizedQuestion = {
  userStage: string;
  intents: string[];
  emotion: string;
  knownInfo: string[];
  missingInfo: string[];
  suggestedQuestions: string[];
  urgency: "低" | "中" | "中高" | "高";
  counselorSummary: string;
};
