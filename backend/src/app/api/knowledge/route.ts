import { NextResponse } from "next/server";
import { ensureKnowledgeBaseSeeded, upsertKnowledgeSource } from "@/engines/rag";
import { apiError } from "@/lib/errors";
import { readJson, withAuth } from "@/lib/route";
import { store } from "@/lib/store";
import type { KnowledgeCategory, KnowledgeSourceInput, KnowledgeSourceType } from "@/types/knowledge";

type Body = Partial<KnowledgeSourceInput> & {
  question?: string;
  answer?: string;
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

export const POST = withAuth(async (req) => {
  ensureKnowledgeBaseSeeded();
  const body = await readJson<Body>(req);
  const contentFromFaq =
    body.question?.trim() && body.answer?.trim()
      ? `Q: ${body.question.trim()}\nA: ${body.answer.trim()}`
      : undefined;

  const title = body.title?.trim() || (body.question ? `FAQ：${body.question.trim()}` : "");
  const content = body.content?.trim() || contentFromFaq || "";
  if (!title) return apiError("bad_request", "`title` or `question` is required.");
  if (!content) return apiError("bad_request", "`content` or `question` + `answer` is required.");

  const category = body.category ?? "faq";
  const sourceType = body.sourceType ?? (body.question ? "counselor_case" : "faq");
  if (!CATEGORIES.includes(category)) return apiError("bad_request", "`category` is invalid.");
  if (!SOURCE_TYPES.includes(sourceType)) return apiError("bad_request", "`sourceType` is invalid.");

  const { source, chunks } = upsertKnowledgeSource({
    id: body.id,
    title,
    category,
    sourceType,
    sourceUrl: body.sourceUrl,
    content,
    eligibility: body.eligibility,
    applicationMethod: body.applicationMethod,
    targetUser: body.targetUser,
    stage: body.stage,
    relatedSkills: body.relatedSkills,
    suitableFor: body.suitableFor,
    requiredDocuments: body.requiredDocuments,
    tags: body.tags,
    metadata: body.metadata,
    approvedByCounselor: body.approvedByCounselor ?? true,
  });

  return NextResponse.json({ source, chunks });
});

export const GET = withAuth(async () => {
  ensureKnowledgeBaseSeeded();
  const sources = [...store.knowledgeSources.values()].sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
  return NextResponse.json({
    sources,
    totalSources: sources.length,
    totalChunks: store.knowledgeChunks.size,
  });
});
