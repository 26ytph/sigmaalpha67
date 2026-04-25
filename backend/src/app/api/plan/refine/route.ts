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
  lastRefineGeminiError,
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
    const detail = lastRefineGeminiError.value ?? "";
    const lower = detail.toLowerCase();
    let userMessage = "AI 暫時無法產生更新，請稍後再試或手動編輯。";

    if (detail.includes("missing GEMINI_API_KEY")) {
      userMessage = "後端尚未設定 GEMINI_API_KEY，目前 AI 更新無法運作。";
    } else if (lower.includes("safety") || lower.includes("blockreason")) {
      userMessage = "Gemini 將內容判為敏感而拒絕生成。請換個說法再試。";
    } else if (detail.includes("HTTP 429")) {
      userMessage = "Gemini quota 已用完，請等一下再試。";
    } else if (detail.includes("HTTP 401") || detail.includes("HTTP 403")) {
      userMessage = "Gemini API key 無效或權限不足，請檢查後端設定。";
    } else if (
      lower.includes("token") ||
      lower.includes("max_tokens") ||
      lower.includes("too long") ||
      lower.includes("exceeds")
    ) {
      // 已自動在 engine 內 retry 三次（含 ultraCompact + no-schema fallback）
      // 還不行就是 input 真的太大或被 quota 卡 → 提示使用者精簡內容。
      userMessage =
        "輸入內容過長，已嘗試壓縮但仍失敗。請精簡 Persona / 任務後再試。";
    } else if (detail.includes("HTTP 4")) {
      userMessage = "Gemini 拒絕了這個請求（可能是內容或設定問題）。";
    } else if (lower.includes("parse")) {
      userMessage = "Gemini 回傳的內容無法解析，請再試一次。";
    }

    return NextResponse.json(
      {
        plan: currentPlan,
        fromAi: false,
        message: userMessage,
        // 開發階段保留原始錯誤，前端要看可以打 console；正式環境若擔心
        // 洩漏內部訊息可以再拿掉這欄。
        debug: detail || null,
      },
      { status: 200 },
    );
  }

  const withIds = ensureTaskIds(refined);
  return NextResponse.json({ plan: withIds, fromAi: true });
});
