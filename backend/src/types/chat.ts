export type ChatRole = "user" | "assistant";

export type ChatMessage = {
  id: string;
  role: ChatRole;
  text: string;
  createdAt: string;
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
