import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";
import { buildSwipeSummary } from "@/lib/swipeSummary";
import type { SwipeRecord } from "@/types/swipe";

export const POST = withAuth(async (req, { auth }) => {
  const body = await readJson<Partial<SwipeRecord>>(req);
  if (!body?.cardId || (body.action !== "left" && body.action !== "right")) {
    return apiError("bad_request", "`cardId` and `action` (left|right) are required.");
  }
  const record: SwipeRecord = {
    cardId: body.cardId,
    action: body.action,
    swipedAt: body.swipedAt ?? new Date().toISOString(),
  };
  const list = store.swipes.get(auth.userId) ?? [];
  list.push(record);
  store.swipes.set(auth.userId, list);
  return NextResponse.json({ summary: buildSwipeSummary(list) });
});
