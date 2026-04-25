import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";

type Body = { note?: string };

export const PUT = withAuth<{ week: string }>(async (req, { auth, params }) => {
  const body = await readJson<Body>(req);
  if (typeof body?.note !== "string") {
    return apiError("bad_request", "`note` must be a string.");
  }
  const state = store.plans.get(auth.userId) ?? {
    plan: null,
    todos: {},
    weekNotes: {},
    generatedAt: null,
  };
  state.weekNotes[params.week] = body.note;
  store.plans.set(auth.userId, state);
  return NextResponse.json({ week: params.week, note: body.note });
});
