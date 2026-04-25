import { NextResponse } from "next/server";
import { reindexKnowledgeChunks } from "@/engines/rag";
import { withAuth } from "@/lib/route";
import { store } from "@/lib/store";

export const POST = withAuth(async () => {
  const chunks = reindexKnowledgeChunks();
  return NextResponse.json({
    reindexedChunks: chunks.length,
    totalSources: store.knowledgeSources.size,
    totalChunks: store.knowledgeChunks.size,
  });
});
