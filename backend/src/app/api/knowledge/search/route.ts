import { NextResponse } from "next/server";
import { searchKnowledge } from "@/engines/rag";
import { apiError } from "@/lib/errors";
import { withAuth } from "@/lib/route";
import type { KnowledgeCategory, KnowledgeSourceType } from "@/types/knowledge";

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

export const GET = withAuth(async (req) => {
  const url = new URL(req.url);
  const q = url.searchParams.get("q")?.trim();
  if (!q) return apiError("bad_request", "`q` query parameter is required.");

  const category = url.searchParams.get("category") as KnowledgeCategory | null;
  const sourceType = url.searchParams.get("sourceType") as KnowledgeSourceType | null;
  const limit = Number(url.searchParams.get("limit") ?? "5");

  if (category && !CATEGORIES.includes(category)) return apiError("bad_request", "`category` is invalid.");
  if (sourceType && !SOURCE_TYPES.includes(sourceType)) {
    return apiError("bad_request", "`sourceType` is invalid.");
  }

  const results = searchKnowledge({
    query: q,
    topK: limit,
    category: category ?? undefined,
    sourceType: sourceType ?? undefined,
  });

  return NextResponse.json({ results });
});
