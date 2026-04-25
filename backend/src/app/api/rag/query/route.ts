import { NextResponse } from "next/server";
import { answerRagQuery } from "@/engines/rag";
import { apiError } from "@/lib/errors";
import { readJson, withAuth } from "@/lib/route";
import { store } from "@/lib/store";
import type { KnowledgeCategory, KnowledgeSourceType } from "@/types/knowledge";
import type { Persona } from "@/types/persona";
import type { Profile } from "@/types/profile";

type Body = {
  question?: string;
  topK?: number;
  category?: KnowledgeCategory;
  sourceType?: KnowledgeSourceType;
  persona?: Persona;
  profile?: Profile;
};

const CATEGORIES: KnowledgeCategory[] = [
  "career_consulting",
  "course",
  "subsidy",
  "startup",
  "internship",
  "faq",
  "space",
  "international",
  "housing",
  "other",
];

const SOURCE_TYPES: KnowledgeSourceType[] = [
  "policy",
  "startup_resource",
  "course",
  "faq",
  "service",
  "counselor_case",
];

export const POST = withAuth(async (req, { auth }) => {
  const body = await readJson<Body>(req);
  const question = body.question?.trim();
  if (!question) return apiError("bad_request", "`question` is required.");
  if (body.category && !CATEGORIES.includes(body.category)) {
    return apiError("bad_request", "`category` is invalid.");
  }
  if (body.sourceType && !SOURCE_TYPES.includes(body.sourceType)) {
    return apiError("bad_request", "`sourceType` is invalid.");
  }

  const result = await answerRagQuery({
    userId: auth.userId,
    question,
    topK: body.topK,
    category: body.category,
    sourceType: body.sourceType,
    persona: body.persona ?? store.personas.get(auth.userId) ?? null,
    profile: body.profile ?? store.profiles.get(auth.userId) ?? null,
  });

  return NextResponse.json({
    answer: result.answer,
    retrievedChunks: result.retrievedChunks,
    confidenceScore: result.confidenceScore,
    shouldHandoff: result.shouldHandoff,
    provider: result.provider,
    logId: result.logId,
  });
});
