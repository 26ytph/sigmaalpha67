import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { store } from "@/lib/store";
import { pickQuestionForDate } from "@/data/dailyQuestions";

function todayISO() {
  const d = new Date();
  const tz = d.getTimezoneOffset();
  const local = new Date(d.getTime() - tz * 60_000);
  return local.toISOString().slice(0, 10);
}

export const GET = withAuth(async (req, { auth }) => {
  const url = new URL(req.url);
  const date = url.searchParams.get("date") ?? todayISO();
  const question = pickQuestionForDate(date);
  const answers = store.dailyAnswers.get(auth.userId) ?? [];
  const my = answers.find((a) => a.date === date);
  return NextResponse.json({
    question,
    alreadyAnswered: Boolean(my),
    myAnswer: my?.answer ?? null,
  });
});
