import type { NormalizedQuestion } from "./chat";

export type CounselorCaseStatus = "waiting_for_counselor" | "in_progress" | "resolved";

export type CounselorCase = {
  id: string;
  userId: string;
  /** 這個 case 對應的 chat_conversations.id；reply 時會把回覆寫進這條對話。 */
  conversationId?: string;
  /** 觸發此 case 的 chat_messages.id（user 端的那則訊息）。 */
  fromMessageId?: string;
  status: CounselorCaseStatus;
  urgency: NormalizedQuestion["urgency"];
  userBackground: string;
  personaSummary: string;
  recentActivities: string;
  mainQuestion: string;
  aiAnalysis: string;
  suggestedTopics: string[];
  recommendedResources: string[];
  aiDraftReply: string;
  counselorReply?: string;
  savedToKnowledgeBase?: boolean;
  knowledgeSourceId?: string;
  createdAt: string;
  updatedAt: string;
};
