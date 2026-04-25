import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { store } from "@/lib/store";

// Section 11: GDPR-style account delete.
export const DELETE = withAuth(async (_req, { auth }) => {
  const u = auth.userId;
  store.profiles.delete(u);
  store.personas.delete(u);
  store.swipes.delete(u);
  store.translations.delete(u);
  store.dailyAnswers.delete(u);
  store.streaks.delete(u);
  store.plans.delete(u);
  for (const [k, conv] of store.conversations) {
    if (conv.userId === u) store.conversations.delete(k);
  }
  for (const [k, c] of store.cases) {
    if (c.userId === u) store.cases.delete(k);
  }
  return NextResponse.json({ ok: true });
});
