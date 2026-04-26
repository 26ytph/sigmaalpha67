/**
 * 把使用者每則訊息丟給 Gemini 分類成兩種：
 *
 *   - "smalltalk"
 *       打招呼／問你是誰／隨便聊／無意義／鬧／off-topic（你住哪、你吃大便等）
 *       → AI 直接回一句口語回覆，不打 KB、不丟主題卡給諮詢師。
 *       AI 會順便產出該則回覆文字。
 *
 *   - "actionable"
 *       真正想問職涯／求職／創業／心情／補助／資源／教育的問題。
 *       → 走後續的嚴格 RAG 守門 + handoff 流程。
 *
 * Gemini 失敗時 → 默認回 "actionable"（保守安全：寧可走諮詢師也不漏接真問題）。
 */

import type { Persona } from "@/types/persona";
import type { Profile } from "@/types/profile";

export type IntentClassification =
  | { kind: "smalltalk"; reply: string; reason?: string }
  | { kind: "actionable"; reason?: string };

const SYSTEM_INSTRUCTION = [
  "你是 EmploYA! 的青年職涯助理「YAYA」前面的守門員。",
  "你的任務只有一個：把使用者剛剛送出的訊息分類成『smalltalk』或『actionable』。",
  "判斷標準：",
  "  - smalltalk：打招呼（你好 / 哈囉 / hi）、問 AI 是誰、隨便閒聊（吃飯了嗎）、",
  "    無意義 / 開玩笑 / 鬧（你吃大便）、跟個人偏好無關的 off-topic（你住哪、你幾歲）。",
  "  - actionable：真的想問職涯方向、求職、面試、履歷、創業、補助、課程、實習、",
  "    心理 / 情緒、教育選擇、資源等任一類型的問題。即使語氣很口語、很短，",
  "    只要有實質問題或情緒求助都算 actionable。",
  "smalltalk 時，你**必須**順便輸出一段 1–3 句、繁體中文、口語溫暖的回覆：",
  "  - 招呼類 → 友善回招呼 + 簡短自介。",
  "  - 自我詢問類 → 介紹自己（YAYA，職涯小幫手），歡迎他們聊聊。",
  "  - 無意義 / 鬧 / off-topic → 用幽默不說教的方式溫柔導回職涯話題（不要兇、不要冷漠、不要正經教育對方）。",
  "  - 有 emoji 也 OK。不要硬塞模板。",
  "actionable 時，reply 留空字串。",
  "輸出格式（JSON only，no markdown / no code fence）：",
  '  {"kind":"smalltalk"|"actionable","reply":"...","reason":"<為什麼這樣分（給我們 debug 用，1 句即可）>"}',
].join("\n");

export async function classifyUserIntent(opts: {
  message: string;
  profile?: Profile | null;
  persona?: Persona | null;
}): Promise<IntentClassification> {
  const text = (opts.message ?? "").trim();
  if (!text) return { kind: "smalltalk", reply: "嗨～有想聊的事跟我說一聲就好！" };

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    // 沒 key → 安全 fallback：當作 actionable（後面會走 RAG／handoff）。
    return { kind: "actionable", reason: "no GEMINI_API_KEY, default actionable" };
  }

  // 用便宜的 lite 模型當主力 — 分類任務不需要旗艦 model。
  const modelsToTry = Array.from(
    new Set(
      (
        process.env.GEMINI_CLASSIFIER_CHAIN ||
        [
          process.env.GEMINI_CLASSIFIER_MODEL || "gemini-2.5-flash-lite",
          process.env.GEMINI_FALLBACK_MODEL || "gemini-2.5-flash",
          "gemini-flash-lite-latest",
          "gemini-flash-latest",
        ].join(",")
      )
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean),
    ),
  );

  // 給 LLM 一點 user 背景，讓「我想找工作」這種曖昧的訊息能被正確判成 actionable。
  const profileLine = opts.profile
    ? `使用者：姓名=${opts.profile.name || "未填"}、` +
      `年級=${opts.profile.grade || "未填"}、` +
      `階段=${opts.profile.currentStage || "未填"}、` +
      `想創業=${opts.profile.startupInterest ? "是" : "否"}`
    : "使用者：尚未填資料。";
  const personaLine = opts.persona?.text
    ? `Persona：${opts.persona.text.slice(0, 120)}`
    : "Persona：尚未生成。";

  const userPrompt = `${profileLine}\n${personaLine}\n\n使用者剛送出：「${text}」\n\n請依規則分類並輸出 JSON。`;

  const requestBody = JSON.stringify({
    system_instruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
    contents: [{ role: "user", parts: [{ text: userPrompt }] }],
    generationConfig: {
      temperature: 0.3,
      maxOutputTokens: 350,
      responseMimeType: "application/json",
      thinkingConfig: { thinkingBudget: 0 },
    },
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
          `[intentClassifier] ${model} HTTP ${res.status}: ${body.slice(0, 160)}`,
        );
        if (res.status === 429 || res.status >= 500) continue;
        return { kind: "actionable", reason: `classifier http ${res.status}` };
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
      console.warn(
        `[intentClassifier] ${model} returned unparseable JSON: ${out.slice(0, 160)}`,
      );
    } catch (err) {
      console.error("[intentClassifier] threw:", err);
    }
  }

  return { kind: "actionable", reason: "all classifier models failed" };
}

function safeParse(text: string): IntentClassification | null {
  let body = text.trim();
  const fence = body.match(/```(?:json)?\s*([\s\S]+?)\s*```/i);
  if (fence) body = fence[1];
  if (!body.startsWith("{")) {
    const f = body.indexOf("{");
    const l = body.lastIndexOf("}");
    if (f === -1 || l === -1 || l < f) return null;
    body = body.slice(f, l + 1);
  }
  let raw: { kind?: unknown; reply?: unknown; reason?: unknown };
  try {
    raw = JSON.parse(body);
  } catch {
    return null;
  }
  const kind = raw.kind;
  const reply = typeof raw.reply === "string" ? raw.reply.trim() : "";
  const reason = typeof raw.reason === "string" ? raw.reason.trim() : undefined;
  if (kind === "smalltalk") {
    if (!reply) return null; // smalltalk 一定要附 reply，否則丟給 actionable path
    return { kind: "smalltalk", reply, reason };
  }
  if (kind === "actionable") {
    return { kind: "actionable", reason };
  }
  return null;
}
