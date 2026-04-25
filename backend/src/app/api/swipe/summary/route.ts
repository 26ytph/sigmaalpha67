import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { store } from "@/lib/store";
import { buildSwipeSummary } from "@/lib/swipeSummary";

export const GET = withAuth(async (_req, { auth }) => {
  const list = store.swipes.get(auth.userId) ?? [];
  return NextResponse.json({ summary: buildSwipeSummary(list) });
});
