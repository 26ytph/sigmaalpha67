/**
 * Topic = 同一個使用者下「相同／類似主題」的問題群組。
 * 諮詢師端的卡片視圖以 Topic 為單位，每張卡裡聚合多個 normalized_questions。
 */
export type StoredTopic = {
  id: string;
  userId: string;
  title: string;
  summary: string;
  centroidText: string;
  status: "pending" | "resolved";
  resolvedBy: string | null;
  resolvedAt: string | null;
  kbSourceId: string | null;
  questionCount: number;
  /**
   * 這個主題裡還沒被諮詢師回覆的成員問題數。
   *   - 由 backend 即時算出來：normalized_questions 屬於這 topic 但
   *     沒有任一筆 chat_messages.by_counselor=true 的 normalized.reply_to_message_id
   *     等於該 question 的 message_id。
   *   - 主題卡上會顯示成「N 未回」徽章，諮詢師可以一眼掃哪些主題還有沒處理的題。
   *   - 可能 undefined（後端 supabase 沒設定時）。
   */
  unansweredCount?: number;
  createdAt: string;
  updatedAt: string;
};

/**
 * Topic + 聚合的成員問題。Counselor UI 點開 Topic 卡時用。
 * 每個 member 內的 `aiReply` 是 chat_messages 裡 user 訊息後緊接的 assistant 回覆，
 * 給諮詢師當 context — 解決時 AI 整理 KB **不會** 採用 aiReply。
 */
export type TopicMemberQuestion = {
  normalizedQuestionId: string;
  messageId: string | null;
  conversationId: string | null;
  rawQuestion: string;
  normalizedText: string;
  intents: string[];
  emotion: string;
  urgency: string;
  createdAt: string;
  /** AI 在當下對這題的暫時回覆。可能為 null（沒對應 chat_messages 抓不到）。 */
  aiReply: string | null;
  aiReplyAt: string | null;
};

/** 諮詢師對這個主題的歷次回覆（諮詢師端要看自己跟個案聊到哪、user 端要看引用了哪一題）。 */
export type TopicCounselorReply = {
  messageId: string;
  conversationId: string;
  text: string;
  createdAt: string;
  replyToMessageId?: string;
  replyToText?: string;
};

export type TopicWithMembers = StoredTopic & {
  members: TopicMemberQuestion[];
  counselorReplies: TopicCounselorReply[];
};
