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
  /**
   * 諮詢師回覆專用：這則訊息對應 user 的哪一則問題（chat_messages.id）。
   * UI 上會在 bubble 上方掛一個 ↩ 引用框，避免被後續訊息擠到上面去之後 user 看不懂回覆給誰。
   */
  replyToMessageId?: string;
  replyToText?: string;
  /** 諮詢師回覆專用：這則訊息屬於哪個 question_topics 主題（給後端做關聯，UI 不一定渲染）。 */
  topicId?: string;
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
