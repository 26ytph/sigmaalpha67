// =====================================================================
// POST /api/plan/refine
// Body: { prompt, currentPlan, mode?, persona? }
// Output: { plan, fromAi: boolean }
//
// 把使用者的「我想做 X / 我已經會 Y」自然語言指令丟給 Gemini，請它依舊
// 計畫產出更新版。前端用回傳的 task.id 對應原本的勾選狀態（merge 在前端）。
// 如果 Gemini 不可用（無 key / quota / 解析失敗），回傳 fromAi=false 讓
// 前端 fallback 到本機處理（保留原計畫，提示使用者）。
// =====================================================================

import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { store } from "@/lib/store";
import {
  refinePlanWithGemini,
  ensureTaskIds,
  type RefinePlan,
} from "@/engines/planRefine";
import type { Persona } from "@/types/persona";

type Body = {
  prompt?: string;
  currentPlan?: RefinePlan;
  mode?: "career" | "startup";
  persona?: Persona;
};

export const POST = withAuth(async (req, { auth }) => {
  const body = (await readJson<Body>(req)) ?? {};
  const prompt = (body.prompt ?? "").trim();
  if (!prompt) {
    return NextResponse.json(
      { error: { message: "prompt is required" } },
      { status: 400 },
    );
  }
  const currentPlan = body.currentPlan ?? { headline: "", weeks: [] };
  const mode = body.mode ?? "career";
  const persona = body.persona ?? store.personas.get(auth.userId) ?? null;

  const refined = await refinePlanWithGemini({
    prompt,
    currentPlan,
    mode,
    persona,
  });

  if (!refined) {
    return NextResponse.json(
      {
        plan: currentPlan,
        fromAi: false,
        message: "AI 暫時無法產生更新，請稍後再試或手動編輯。",
      },
      { status: 200 },
    );
  }

  const withIds = ensureTaskIds(refined);
  return NextResponse.json({ plan: withIds, fromAi: true });
});
