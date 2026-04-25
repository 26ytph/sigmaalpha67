import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";
import { getQuestionById } from "@/data/dailyQuestions";

type Body = { questionId?: string; answer?: string };

function todayISO() {
  const d = new Date();
  const tz = d.getTimezoneOffset();
  const local = new Date(d.getTime() - tz * 60_000);
  return local.toISOString().slice(0, 10);
}

function dayDelta(a: string, b: string): number {
  const ad = Date.parse(a + "T00:00:00Z");
  const bd = Date.parse(b + "T00:00:00Z");
  return Math.round((bd - ad) / 86_400_000);
}

export const POST = withAuth(async (req, { auth }) => {
  const body = await readJson<Body>(req);
  if (!body?.questionId || !body.answer) {
    return apiError("bad_request", "`questionId` and `answer` are required.");
  }
  const q = getQuestionById(body.questionId);
  if (!q) return apiError("not_found", "Question not found.");

  const date = todayISO();
  const list = store.dailyAnswers.get(auth.userId) ?? [];
  if (!list.some((a) => a.date === date)) {
    list.push({ questionId: body.questionId, answer: body.answer, date, answeredAt: new Date().toISOString() });
    store.dailyAnswers.set(auth.userId, list);

    const prev = store.streaks.get(auth.userId);
    let current = 1;
    if (prev?.lastAnsweredDate) {
      const delta = dayDelta(prev.lastAnsweredDate, date);
      if (delta === 1) current = prev.current + 1;
      else if (delta === 0) current = prev.current;
      else current = 1;
    }
    store.streaks.set(auth.userId, { current, lastAnsweredDate: date });
  }

  const strike = store.streaks.get(auth.userId)!;
  return NextResponse.json({ strike, explanation: q.answer });
});
