import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";
import * as db from "@/lib/db";

type Body = { done?: boolean };

export const PUT = withAuth<{ key: string }>(async (req, { auth, params }) => {
  const body = await readJson<Body>(req);
  if (typeof body?.done !== "boolean") {
    return apiError("bad_request", "`done` must be a boolean.");
  }
  const state = store.plans.get(auth.userId) ?? {
    plan: null,
    todos: {},
    weekNotes: {},
    generatedAt: null,
  };
  state.todos[params.key] = body.done;
  store.plans.set(auth.userId, state);
  await db.upsertPlanTodo(auth.userId, params.key, body.done);
  return NextResponse.json({ key: params.key, done: body.done });
});
