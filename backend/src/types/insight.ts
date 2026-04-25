export type UserInsightPriority = "低" | "中" | "中高" | "高";

export type UserInsight = {
  userId: string;
  problemPositioning: string;
  categories: string[];
  emotionProfile: string;
  specificConcerns: string[];
  triedApproaches: string[];
  blockers: string[];
  recommendedTopics: string[];
  priority: UserInsightPriority;
  tags: string[];
  rawSummary: string;
  messageCount: number;
  generatedBy: string;
  counselorNote: string;
  generatedAt: string;
  updatedAt: string;
};

/** Subset returned from the AI engine before we save / merge with timestamps. */
export type UserInsightDraft = Omit<
  UserInsight,
  "userId" | "counselorNote" | "generatedAt" | "updatedAt"
>;

export const emptyUserInsight = (userId: string): UserInsight => ({
  userId,
  problemPositioning: "",
  categories: [],
  emotionProfile: "",
  specificConcerns: [],
  triedApproaches: [],
  blockers: [],
  recommendedTopics: [],
  priority: "中",
  tags: [],
  rawSummary: "",
  messageCount: 0,
  generatedBy: "",
  counselorNote: "",
  generatedAt: new Date(0).toISOString(),
  updatedAt: new Date(0).toISOString(),
});
