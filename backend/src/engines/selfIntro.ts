/**
 * AI 從履歷生成自介。
 *
 * 把 user profile（科系、年級、目前階段、興趣、目標、經驗、自填的 concerns）
 * 跟 persona（如果有）丟給 Gemini，請它寫出一段 80–120 字、第一人稱、
 * 自然口語的自介。失敗時退回 heuristic 拼接版本，避免 demo 空轉。
 */

import type { Profile } from "@/types/profile";
import type { Persona } from "@/types/persona";

const SYSTEM_INSTRUCTION =
  "你是 EmploYA! 的自介生成助理。" +
  "請依照使用者填寫的履歷資料，產出一段第一人稱、口語、誠懇、不誇飾的自我介紹。" +
  "字數約 80–120 字（中文計），不要分段、不要使用條列、不要 emoji，不要重複欄位名稱。" +
  "若資料不足，可以保留模糊但不能編造（例如不要憑空捏造學校、職稱、實習）。" +
  "輸出只給自介本文，不要前後綴、不要『以下是…』之類的話。";

export async function generateSelfIntroFromProfile(
  profile: Profile | null,
  persona?: Persona | null,
): Promise<string | null> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) return null;

  const modelsToTry = Array.from(
    new Set(
      (
        process.env.GEMINI_MODEL_CHAIN ||
        [
          process.env.GEMINI_MODEL || "gemini-2.5-flash",
          process.env.GEMINI_FALLBACK_MODEL || "gemini-2.5-flash-lite",
          process.env.GEMINI_FALLBACK_MODEL_2 || "gemini-2.0-flash",
          "gemini-1.5-flash",
        ].join(",")
      )
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean),
    ),
  );

  const profileBlock = profile
    ? [
        `姓名：${profile.name || "（未填）"}`,
        `學校 / 科系：${[profile.school, profile.department].filter(Boolean).join(" / ") || "（未填）"}`,
        `年級：${profile.grade || "（未填）"}`,
        `目前階段：${profile.currentStage || "（未填）"}`,
        `興趣：${(profile.interests ?? []).join("、") || "（未填）"}`,
        `目標：${(profile.goals ?? []).join("、") || "（未填）"}`,
        `經驗：${(profile.experiences ?? []).join("；") || "（未填）"}`,
        `學歷紀錄：${(profile.educationItems ?? [])
          .map((e) => `${e.school || ""} ${e.department || ""} ${e.grade || ""}`)
          .filter((s) => s.trim())
          .join("；") || "（未填）"}`,
        `自填煩惱：${profile.concerns || "（未填）"}`,
        `想創業：${profile.startupInterest ? "是" : "否"}`,
      ].join("\n")
    : "（沒有履歷資料）";

  const personaLine = persona?.text
    ? `先前 persona：${persona.text}`
    : "（沒有先前 persona）";

  const userPrompt =
    `=== 履歷資料 ===\n${profileBlock}\n\n${personaLine}\n\n` +
    `任務：根據上面資料寫一段自介。如果欄位幾乎都空白，可以說「正在探索方向」之類的誠實版本，` +
    `不要編造未填寫的東西。`;

  const requestBody = JSON.stringify({
    system_instruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
    contents: [{ role: "user", parts: [{ text: userPrompt }] }],
    generationConfig: { temperature: 0.55, maxOutputTokens: 400 },
  });

  for (const model of modelsToTry) {
    try {
      const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
        model,
      )}:generateContent`;
      const res = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: requestBody,
      });
      if (!res.ok) {
        const body = await res.text().catch(() => "");
        console.error(
          `[selfIntro] ${model} HTTP ${res.status}: ${body.slice(0, 160)}`,
        );
        if (res.status === 429 || res.status >= 500) continue;
        return null;
      }
      const json = (await res.json()) as {
        candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
      };
      const text = (json.candidates?.[0]?.content?.parts ?? [])
        .map((p) => p.text ?? "")
        .join("")
        .trim();
      if (text) return stripWrappers(text);
    } catch (err) {
      console.error("[selfIntro] gemini call failed:", err);
    }
  }
  return null;
}

function stripWrappers(s: string): string {
  // Gemini 偶爾會包成 `「...」` 或加 「以下是」前綴 — 簡單清掉。
  let out = s.trim();
  out = out.replace(/^[「『"']\s*/, "").replace(/\s*[」』"']$/, "");
  out = out.replace(/^以下[是為]?[一一]?段?自介[：:]?\s*/, "");
  return out.trim();
}

/** Gemini 不可用時的 deterministic fallback。 */
export function buildHeuristicSelfIntro(
  profile: Profile | null,
  persona?: Persona | null,
): string {
  if (!profile) return persona?.text ?? "我正在探索職涯方向，邊做邊找答案。";
  const dept = profile.department?.trim();
  const grade = profile.grade?.trim();
  const stage = profile.currentStage?.trim();
  const interests = (profile.interests ?? []).slice(0, 3).join("、");
  const goals = (profile.goals ?? []).slice(0, 2).join("、");
  const exp = (profile.experiences ?? []).slice(0, 2).join("、");

  const intro = [
    profile.name ? `我是 ${profile.name}，` : "我",
    dept || grade ? `${dept ?? ""}${grade ? `${grade}學生` : ""}，` : "",
    stage ? `目前正在${stage}。` : "正在思考下一步。",
    interests ? `對 ${interests} 比較有興趣。` : "",
    exp ? `做過 ${exp}，` : "",
    goals ? `希望接下來能 ${goals}。` : "希望找到適合自己的方向。",
  ]
    .filter(Boolean)
    .join("");
  return intro;
}
