export type ChatRole = "user" | "assistant";

export type ChatMessage = {
  id: string;
  role: ChatRole;
  text: string;
  createdAt: string;
  /** true 代表這則 'assistant' 訊息其實是真人諮詢師發的（透過 case reply）。 */
  byCounselor?: boolean;
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
