// =====================================================================
// Skill translator — Gemini-driven，失敗時退回 keyword-based fallback。
// =====================================================================

import type { SkillTranslation } from "@/types/skill";
import { newId } from "@/lib/store";

const KEYWORD_SKILLS: Array<{ kw: RegExp; skills: string[] }> = [
  { kw: /(迎新|活動|社團|策展)/, skills: ["活動企劃", "流程把控", "跨組溝通"] },
  { kw: /(訪談|採訪|報導)/, skills: ["訪談技巧", "資料整理", "結論歸納"] },
  { kw: /(報告|簡報|presentation)/i, skills: ["敘事結構", "資料視覺化", "公開表達"] },
  { kw: /(教|家教|助教|tutor)/i, skills: ["教學設計", "拆解複雜概念", "耐心溝通"] },
  { kw: /(打工|餐廳|店員|service)/i, skills: ["服務流程", "壓力管理", "顧客同理心"] },
  { kw: /(程式|coding|專案|hackathon|coding|build|寫程式)/i, skills: ["問題拆解", "工具實作", "團隊協作"] },
  { kw: /(設計|繪|畫|插畫|圖)/, skills: ["視覺敏感度", "工具熟悉度", "美感判斷"] },
  { kw: /(分析|統計|數據|excel|sql)/i, skills: ["資料處理", "假設驗證", "結論歸納"] },
];

const SYSTEM_INSTRUCTION =
  "你是 EmploYA! 的『技能翻譯』助理。" +
  "把使用者的口語經驗描述拆成數段，每段萃取 3–4 個職場能力；" +
  "再生成一句可直接放履歷的中文敘述（量化、動詞開頭、自然不誇飾）。" +
  "輸出必須是合法 JSON，不要加 Markdown / code fence / 解釋。";

type GeminiOut = {
  groups: Array<{ experience: string; skills: string[] }>;
  resumeSentence: string;
};

/** Public API — chat / route 呼叫這支。Async 因為要打 Gemini。 */
export async function translateExperience(raw: string): Promise<SkillTranslation> {
  const text = raw.trim();
  const fromGemini = await tryGemini(text);
  if (fromGemini) {
    return {
      id: newId("st"),
      rawExperience: text,
      groups: fromGemini.groups,
      resumeSentence: fromGemini.resumeSentence,
      createdAt: new Date().toISOString(),
    };
  }
  return heuristicTranslate(text);
}

function heuristicTranslate(text: string): SkillTranslation {
  const segments = text
    .split(/[，,。.；;\n]/)
    .map((s) => s.trim())
    .filter(Boolean);
  const groups = segments.length ? segments : [text];

  const groupResults = groups.map((seg) => {
    const skillSet = new Set<string>();
    for (const { kw, skills } of KEYWORD_SKILLS) {
      if (kw.test(seg)) for (const s of skills) skillSet.add(s);
    }
    if (skillSet.size === 0) {
      ["問題拆解", "團隊協作", "成果交付"].forEach((s) => skillSet.add(s));
    }
    return { experience: seg, skills: [...skillSet].slice(0, 4) };
  });

  const sentenceParts = groupResults.map(
    (g) => `曾於${g.experience}中展現${g.skills.slice(0, 3).join("、")}的能力`,
  );
  const resumeSentence = `${sentenceParts.join("，並")} ，能將實作經驗轉化為可量化交付。`;

  return {
    id: newId("st"),
    rawExperience: text,
    groups: groupResults,
    resumeSentence,
    createdAt: new Date().toISOString(),
  };
}

async function tryGemini(text: string): Promise<GeminiOut | null> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey || !text) return null;

  const modelsToTry = Array.from(
    new Set(
      (
        process.env.GEMINI_MODEL_CHAIN ||
        [
          process.env.GEMINI_MODEL || "gemini-2.5-flash",
          process.env.GEMINI_FALLBACK_MODEL || "gemini-2.5-flash-lite",
          process.env.GEMINI_FALLBACK_MODEL_2 || "gemini-flash-latest",
          "gemini-flash-lite-latest",
        ].join(",")
      )
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean),
    ),
  );

  const userPrompt =
    `=== 使用者口語經驗 ===\n${text}\n\n` +
    `=== 任務 ===\n` +
    `1) 把上面內容拆成 1–4 段「事件」（按語意，不一定要照標點）。\n` +
    `2) 每段萃取 3–4 個職場能力（中文短語，不要 "..."）。\n` +
    `3) 寫一句 50–90 字、可放履歷的中文句子（動詞開頭、可量化、避免誇飾）。\n` +
    `=== 輸出格式（JSON only） ===\n` +
    `{\n` +
    `  "groups": [{ "experience": "原始片段", "skills": ["能力1","能力2","能力3"] }],\n` +
    `  "resumeSentence": "可放履歷的句子"\n` +
    `}`;

  const requestBody = JSON.stringify({
    system_instruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
    contents: [{ role: "user", parts: [{ text: userPrompt }] }],
    generationConfig: {
      temperature: 0.3,
      maxOutputTokens: 600,
      responseMimeType: "application/json",
    },
  });

  for (const model of modelsToTry) {
    try {
      const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
        model,
      )}:generateContent`;
      const res = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
        body: requestBody,
      });
      if (!res.ok) {
        const body = await res.text().catch(() => "");
        console.error(
          `[skillTranslator] ${model} HTTP ${res.status}: ${body.slice(0, 160)}`,
        );
        if (res.status === 429 || res.status >= 500) continue;
        return null;
      }
      const json = (await res.json()) as {
        candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
      };
      const out = (json.candidates?.[0]?.content?.parts ?? [])
        .map((p) => p.text ?? "")
        .join("")
        .trim();
      const parsed = safeParse(out);
      if (parsed) return parsed;
    } catch (err) {
      console.error("[skillTranslator] gemini call failed:", err);
    }
  }
  return null;
}

function safeParse(text: string): GeminiOut | null {
  let body = text.trim();
  const fence = body.match(/```(?:json)?\s*([\s\S]+?)\s*```/i);
  if (fence) body = fence[1];
  if (!body.startsWith("{")) {
    const f = body.indexOf("{");
    const l = body.lastIndexOf("}");
    if (f === -1 || l === -1 || l < f) return null;
    body = body.slice(f, l + 1);
  }
  let raw: { groups?: unknown; resumeSentence?: unknown };
  try {
    raw = JSON.parse(body);
  } catch {
    return null;
  }
  const groups = Array.isArray(raw.groups)
    ? raw.groups
        .map((g) => {
          if (!g || typeof g !== "object") return null;
          const exp = (g as { experience?: unknown }).experience;
          const sk = (g as { skills?: unknown }).skills;
          const experience = typeof exp === "string" ? exp.trim() : "";
          const skills = Array.isArray(sk)
            ? sk
                .map((s) => (typeof s === "string" ? s.trim() : ""))
                .filter((s) => s.length > 0)
                .slice(0, 5)
            : [];
          if (!experience || skills.length === 0) return null;
          return { experience, skills };
        })
        .filter((x): x is { experience: string; skills: string[] } => x !== null)
    : [];
  const resumeSentence =
    typeof raw.resumeSentence === "string" ? raw.resumeSentence.trim() : "";
  if (groups.length === 0 || !resumeSentence) return null;
  return { groups, resumeSentence };
}
