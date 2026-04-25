export type KnowledgeCategory =
  | "career_consulting"
  | "course"
  | "subsidy"
  | "startup"
  | "internship"
  | "faq"
  | "space"
  | "international"
  | "housing"
  | "other";

export type KnowledgeSourceType =
  | "policy"
  | "startup_resource"
  | "course"
  | "faq"
  | "service"
  | "counselor_case";

export type KnowledgeSource = {
  id: string;
  title: string;
  category: KnowledgeCategory;
  sourceType: KnowledgeSourceType;
  sourceUrl?: string;
  content: string;
  eligibility?: string;
  applicationMethod?: string;
  targetUser?: string[];
  stage?: string[];
  relatedSkills?: string[];
  suitableFor?: string[];
  requiredDocuments?: string[];
  tags?: string[];
  approvedByCounselor: boolean;
  metadata?: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
};

export type KnowledgeSourceInput = Omit<
  KnowledgeSource,
  "id" | "approvedByCounselor" | "createdAt" | "updatedAt"
> & {
  id?: string;
  approvedByCounselor?: boolean;
  createdAt?: string;
  updatedAt?: string;
};

export type KnowledgeChunk = {
  id: string;
  sourceId: string;
  title: string;
  chunkText: string;
  metadata: Record<string, unknown>;
  embedding: number[];
  createdAt: string;
};

export type RetrievedKnowledgeChunk = {
  chunkId: string;
  sourceId: string;
  title: string;
  category: KnowledgeCategory;
  sourceType: KnowledgeSourceType;
  sourceUrl?: string;
  chunkText: string;
  score: number;
  metadata: Record<string, unknown>;
};

export type RagLog = {
  id: string;
  userId: string;
  question: string;
  retrievedChunks: RetrievedKnowledgeChunk[];
  answer: string;
  confidenceScore: number;
  shouldHandoff: boolean;
  provider: "gemini" | "local";
  createdAt: string;
};
