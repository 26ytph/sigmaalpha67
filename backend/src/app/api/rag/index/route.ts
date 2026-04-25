import { NextResponse } from "next/server";
import { indexKnowledgeSources, ensureKnowledgeBaseSeeded } from "@/engines/rag";
import { apiError } from "@/lib/errors";
import { withAuth } from "@/lib/route";
import { store } from "@/lib/store";
import type { KnowledgeSourceInput } from "@/types/knowledge";

type Body = {
  sources?: KnowledgeSourceInput[];
  replace?: boolean;
};

export const POST = withAuth(async (req) => {
  const body = ((await req.json().catch(() => ({}))) ?? {}) as Body;

  if (body.sources !== undefined && !Array.isArray(body.sources)) {
    return apiError("bad_request", "`sources` must be an array when provided.");
  }

  let result: ReturnType<typeof indexKnowledgeSources>;
  if (body.sources?.length) {
    if (!body.replace) ensureKnowledgeBaseSeeded();
    result = indexKnowledgeSources(body.sources, { replace: body.replace });
  } else {
    ensureKnowledgeBaseSeeded();
    result = {
      sources: [...store.knowledgeSources.values()],
      chunks: [...store.knowledgeChunks.values()],
    };
  }

  return NextResponse.json({
    indexedSources: result.sources.length,
    indexedChunks: result.chunks.length,
    totalSources: store.knowledgeSources.size,
    totalChunks: store.knowledgeChunks.size,
  });
});
