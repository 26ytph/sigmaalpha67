import type { NormalizedQuestion } from "./chat";

export type CounselorCaseStatus = "waiting_for_counselor" | "in_progress" | "resolved";

export type CounselorCase = {
  id: string;
  userId: string;
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
