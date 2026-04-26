// =====================================================================
// Plan refine — Gemini-driven incremental update.
//
// Inputs:
//   - prompt: user's natural-language goal/update
//             ("我想投 DevOps 實習" / "我已經會 Docker 了，幫我跳過")
//   - currentPlan: the user's current customised plan (with stable IDs)
//   - persona / mode: same context the generator uses
//
// Output: a new plan with stable IDs preserved when the same task survives,
// fresh IDs for newly added tasks. The frontend uses these IDs to keep
// completed checkboxes ticked across regenerations.
// =====================================================================

import type { Persona } from "@/types/persona";

export type RefineTask = {
  id: string;
  title: string;
  description?: string;
  section: "goals" | "resources" | "outputs";
  done?: boolean;
  userAdded?: boolean;
  userEdited?: boolean;
};

export type RefineWeek = {
  week: number;
  title: string;
  tasks: RefineTask[];
};

export type RefinePlan = {
  headline: string;
  weeks: RefineWeek[];
};

export const lastRefineGeminiError: { value: string | null } = { value: null };

const SYSTEM_INSTRUCTION = [
  "你是 EmploYA! 的職涯計畫精修助理。",
  "使用者會提供：① 一段目前的計畫（含每個任務的 stable id），② 一段他們的新需求／已完成事項。",
  "請根據新需求修改計畫，並輸出整份新版計畫 JSON。",
  "規則：",
  "1. 只輸出符合 schema 的 JSON，不要任何前後說明文字。",
  "2. 一律繁體中文。語氣親切口語、可執行；避免空泛口號。",
  "3. 若舊計畫中的任務在新版仍然合理且沒被使用者標 done，**保留原 id**（讓前端能 keep 勾選狀態）。",
  "4. 新增的任務 id 留空字串 ''，後端會幫忙補。",
  "5. 使用者明確說「已經會」「已完成」「跳過」的能力 → 對應任務從 plan 移除（不要保留為 done）。",
  "6. 使用者明確指定的目標（例：「我想投 DevOps 實習」）必須反映在 headline 與週主題裡。",
  "7. 4 週節奏：盤點 → 打底 → 做出來 → 收斂展示／面試準備。",
  "8. 每週 2–4 個 goals、1–3 個 resources、2–3 個 outputs。",
  "9. headline ≤ 22 字，能一句話講清楚這份計畫的方向。",
].join("\n");

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    headline: { type: "STRING" },
    weeks: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          week: { type: "INTEGER" },
          title: { type: "STRING" },
          tasks: {
            type: "ARRAY",
            items: {
              type: "OBJECT",
              properties: {
                id: { type: "STRING" },
                title: { type: "STRING" },
                description: { type: "STRING" },
                section: { type: "STRING" },
              },
              required: ["title", "section"],
            },
          },
        },
        required: ["week", "title", "tasks"],
      },
    },
  },
  required: ["headline", "weeks"],
};

// ---------------------------------------------------------------------
// Prompt size budgeting
//
// 為什麼存在：Gemini 2.5-flash + responseSchema 在輸入過長 / 輸出超過
// maxOutputTokens 時會回 HTTP 400 或截斷 (finishReason=MAX_TOKENS)，
// 對使用者來看就是「Gemini 拒絕了這個請求」的對話框。
//
// 對策：
//   1. summarisePlan 從 verbose 改成 compact 一行 N 字節的格式。
//   2. 每週最多保留 6 個 task 餵給 LLM（以保留 user-added / 未完成 為優先）。
//   3. Persona 文字壓到 ~120 字、user prompt 壓到 ~500 字。
// ---------------------------------------------------------------------
const TASKS_PER_WEEK_INPUT_CAP = 6;
const PERSONA_TEXT_MAX = 120;
const USER_PROMPT_MAX = 500;

function truncate(s: string | undefined | null, max: number): string {
  if (!s) return "";
  const t = s.trim();
  if (t.length <= max) return t;
  return `${t.slice(0, max)}…`;
}

/// 每週只保留最多 N 個 task，優先順序：使用者新增 > 未完成 > 已完成。
/// 這樣壓縮後送給 Gemini，輸入小、它的輸出也容易在 budget 內。
function compactPlan(plan: RefinePlan): RefinePlan {
  return {
    headline: plan.headline,
    weeks: plan.weeks.map((w) => {
      const sorted = [...w.tasks].sort((a, b) => {
        const score = (t: RefineTask) =>
          (t.userAdded ? 0 : 0) * 4 + (t.done ? 1 : 0) * 2;
        return score(a) - score(b);
      });
      return { ...w, tasks: sorted.slice(0, TASKS_PER_WEEK_INPUT_CAP) };
    }),
  };
}

/// 緊湊格式：`g/<id>/<title>` 取代 verbose 的「id=... · section=... · ...」。
/// section 用首字母 g/r/o；done / userAdded 用 ✓ / + 後綴。
function summarisePlanCompact(plan: RefinePlan): string {
  const lines: string[] = [`H:${truncate(plan.headline, 60)}`];
  for (const w of plan.weeks) {
    lines.push(`W${w.week}:${truncate(w.title, 40)}`);
    for (const t of w.tasks) {
      const sec = t.section[0]; // g / r / o
      const tag = t.done ? "✓" : t.userAdded ? "+" : "";
      lines.push(
        `  ${sec}/${truncate(t.id, 24)}/${truncate(t.title, 40)}${tag}`,
      );
    }
  }
  return lines.join("\n");
}

function buildUserPrompt(opts: {
  prompt: string;
  currentPlan: RefinePlan;
  mode: "career" | "startup";
  persona: Persona | null | undefined;
  ultraCompact?: boolean;
}): string {
  const compact = opts.ultraCompact ?? false;
  const lines: string[] = [];
  lines.push(`模式：${opts.mode === "startup" ? "創業者" : "求職者"}`);

  if (opts.persona && opts.persona.text) {
    if (!compact) {
      lines.push(`Persona：${truncate(opts.persona.text, PERSONA_TEXT_MAX)}`);
    }
    if (opts.persona.mainInterests?.length) {
      lines.push(`興趣：${opts.persona.mainInterests.slice(0, 5).join("、")}`);
    }
    if (opts.persona.strengths?.length) {
      lines.push(`已有：${opts.persona.strengths.slice(0, 5).join("、")}`);
    }
    if (opts.persona.skillGaps?.length) {
      lines.push(`待補：${opts.persona.skillGaps.slice(0, 5).join("、")}`);
    }
  }

  lines.push("");
  lines.push("舊計畫（compact 格式：sec/id/title，✓=done，+=userAdded）：");
  lines.push(summarisePlanCompact(compactPlan(opts.currentPlan)));
  lines.push("");
  lines.push(`新需求：「${truncate(opts.prompt, USER_PROMPT_MAX)}」`);
  lines.push("");
  lines.push(
    "依需求改 plan。舊任務若繼續用 → 保留 id；新增 task → id 留空字串。輸出 JSON。",
  );
  return lines.join("\n");
}

// ---------------------------------------------------------------------
// 對 Gemini 的單次呼叫。useSchema=false 時改用「只指定 json mime + 在 prompt
// 內描述 JSON 結構」這種寬鬆模式 — 當 schema-validated 模式被 4xx reject 時
// 通常還有救。
// ---------------------------------------------------------------------
async function callGeminiOnce(opts: {
  apiKey: string;
  model: string;
  systemInstruction: string;
  userPrompt: string;
  useSchema: boolean;
  maxOutputTokens: number;
}): Promise<{ text: string } | { error: string; status?: number }> {
  const generationConfig: Record<string, unknown> = {
    temperature: 0.5,
    maxOutputTokens: opts.maxOutputTokens,
    responseMimeType: "application/json",
  };
  if (opts.useSchema) {
    generationConfig.responseSchema = RESPONSE_SCHEMA;
  }

  const requestBody = JSON.stringify({
    system_instruction: { parts: [{ text: opts.systemInstruction }] },
    contents: [{ role: "user", parts: [{ text: opts.userPrompt }] }],
    generationConfig,
  });

  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
    opts.model,
  )}:generateContent`;

  let response: Response;
  try {
    response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": opts.apiKey,
      },
      body: requestBody,
    });
  } catch (err) {
    return {
      error: err instanceof Error ? err.message : String(err),
    };
  }

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    return {
      status: response.status,
      error: `HTTP ${response.status}: ${body.slice(0, 300)}`,
    };
  }

  const json = (await response.json().catch(() => null)) as {
    candidates?: Array<{
      content?: { parts?: Array<{ text?: string }> };
      finishReason?: string;
    }>;
    promptFeedback?: { blockReason?: string };
  } | null;

  const candidate = json?.candidates?.[0];
  const text =
    candidate?.content?.parts?.map((p) => p.text ?? "").join("").trim() ?? "";
  if (!text) {
    return {
      error: `empty text. finishReason=${candidate?.finishReason} blockReason=${json?.promptFeedback?.blockReason}`,
    };
  }
  return { text };
}

/// 看錯誤訊息推測是不是「輸入 / 輸出超過 token 限制」。
/// 如果是 → 上層應該嘗試 ultraCompact prompt 再試一次。
function isLikelyTokenIssue(errorMsg: string): boolean {
  const m = errorMsg.toLowerCase();
  return (
    m.includes("token") ||
    m.includes("too long") ||
    m.includes("exceeds") ||
    m.includes("max_tokens") ||
    m.includes("payload") ||
    // schema-validated 模式輸出超過時 finishReason 通常是 MAX_TOKENS
    m.includes("finishreason=max_tokens")
  );
}

export async function refinePlanWithGemini(opts: {
  prompt: string;
  currentPlan: RefinePlan;
  mode: "career" | "startup";
  persona?: Persona | null;
}): Promise<RefinePlan | null> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    lastRefineGeminiError.value = "missing GEMINI_API_KEY in process.env";
    return null;
  }
  lastRefineGeminiError.value = null;

  const modelsToTry = Array.from(
    new Set(
      (
        process.env.GEMINI_PLAN_MODEL_CHAIN ||
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

  const errors: string[] = [];
  // 每個 model 都跑「3 段 retry」：
  //   A. 標準（schema + 正常 prompt）
  //   B. 壓縮 prompt（schema + ultraCompact）— 對輸入過長 / MAX_TOKENS 友善
  //   C. 無 schema fallback（只指定 json mime）— 對 schema reject 友善
  // 任何一段成功就 return；A 沒看到 token 問題就直接跳 C。
  for (const model of modelsToTry) {
    const promptStandard = buildUserPrompt({
      prompt: opts.prompt,
      currentPlan: opts.currentPlan,
      mode: opts.mode,
      persona: opts.persona,
    });
    const promptUltra = buildUserPrompt({
      prompt: opts.prompt,
      currentPlan: opts.currentPlan,
      mode: opts.mode,
      persona: opts.persona,
      ultraCompact: true,
    });

    // Attempt A — schema + 標準 prompt
    let res = await callGeminiOnce({
      apiKey,
      model,
      systemInstruction: SYSTEM_INSTRUCTION,
      userPrompt: promptStandard,
      useSchema: true,
      maxOutputTokens: 4000, // 比之前 1800 更寬，避免被截
    });

    if ("text" in res) {
      const parsed = parsePlanJson(res.text);
      if (parsed) {
        lastRefineGeminiError.value = null;
        return parsed;
      }
      errors.push(`[${model}/A] parse failed: ${res.text.slice(0, 200)}`);
    } else {
      errors.push(`[${model}/A] ${res.error}`);
      if (res.status === 429 || (res.status ?? 0) >= 500) continue;
    }

    // Attempt B — schema + ultraCompact（針對 token 超量問題）
    if ("error" in res && isLikelyTokenIssue(res.error)) {
      res = await callGeminiOnce({
        apiKey,
        model,
        systemInstruction: SYSTEM_INSTRUCTION_COMPACT,
        userPrompt: promptUltra,
        useSchema: true,
        maxOutputTokens: 4000,
      });
      if ("text" in res) {
        const parsed = parsePlanJson(res.text);
        if (parsed) {
          lastRefineGeminiError.value = null;
          return parsed;
        }
        errors.push(`[${model}/B] parse failed: ${res.text.slice(0, 200)}`);
      } else {
        errors.push(`[${model}/B] ${res.error}`);
      }
    }

    // Attempt C — 無 schema（針對 schema-validated 4xx）
    res = await callGeminiOnce({
      apiKey,
      model,
      systemInstruction: SYSTEM_INSTRUCTION_NO_SCHEMA,
      userPrompt: promptUltra,
      useSchema: false,
      maxOutputTokens: 4000,
    });
    if ("text" in res) {
      const parsed = parsePlanJson(res.text);
      if (parsed) {
        lastRefineGeminiError.value = null;
        return parsed;
      }
      errors.push(`[${model}/C] parse failed: ${res.text.slice(0, 200)}`);
    } else {
      errors.push(`[${model}/C] ${res.error}`);
    }
  }
  lastRefineGeminiError.value = errors.join(" | ") || "all attempts failed";
  return null;
}

// 給 Attempt B/C 用的更精簡 system instruction — 砍掉裝飾性指令，只留 schema 重點。
const SYSTEM_INSTRUCTION_COMPACT = [
  "你是 EmploYA! 計畫精修 AI。輸出符合 schema 的繁體中文 JSON，不加任何前後文字。",
  "保留仍合理的舊 task id；新增 task id 用空字串。",
  "每週 2–4 goals、1–3 resources、2–3 outputs；4 週節奏：盤點→打底→做出來→展示。",
  "headline ≤ 22 字。",
].join(" ");

const SYSTEM_INSTRUCTION_NO_SCHEMA = [
  "你是 EmploYA! 計畫精修 AI。只輸出純 JSON，禁止 markdown / code fence / 前後說明。",
  "JSON 結構：{headline:string, weeks:[{week:int, title:string, tasks:[{id:string, title:string, description:string, section:'goals'|'resources'|'outputs'}]}]}。",
  "保留仍合理的舊 task id；新增 task id 用空字串。",
  "繁體中文。每週 2–4 goals、1–3 resources、2–3 outputs。",
].join(" ");

function parsePlanJson(text: string): RefinePlan | null {
  const cleaned = text
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/```\s*$/i, "")
    .trim();
  let json: unknown;
  try {
    json = JSON.parse(cleaned);
  } catch {
    return null;
  }
  if (!json || typeof json !== "object") return null;
  const o = json as Record<string, unknown>;
  const headline = typeof o.headline === "string" ? o.headline.trim() : "";
  const weeksRaw = Array.isArray(o.weeks) ? o.weeks : [];
  const weeks: RefineWeek[] = [];
  for (const raw of weeksRaw) {
    if (!raw || typeof raw !== "object") continue;
    const w = raw as Record<string, unknown>;
    const week =
      typeof w.week === "number" ? w.week : Number.parseInt(`${w.week}`, 10);
    const title = typeof w.title === "string" ? w.title.trim() : "";
    if (!Number.isFinite(week) || !title) continue;
    const tasksRaw = Array.isArray(w.tasks) ? w.tasks : [];
    const tasks: RefineTask[] = [];
    for (const taskRaw of tasksRaw) {
      if (!taskRaw || typeof taskRaw !== "object") continue;
      const t = taskRaw as Record<string, unknown>;
      const taskTitle = typeof t.title === "string" ? t.title.trim() : "";
      if (!taskTitle) continue;
      const sectionRaw =
        typeof t.section === "string" ? t.section.trim().toLowerCase() : "goals";
      const section: RefineTask["section"] =
        sectionRaw === "resources"
          ? "resources"
          : sectionRaw === "outputs"
            ? "outputs"
            : "goals";
      tasks.push({
        id: typeof t.id === "string" ? t.id.trim() : "",
        title: taskTitle,
        description: typeof t.description === "string" ? t.description : "",
        section,
      });
    }
    if (tasks.length === 0) continue;
    weeks.push({ week, title, tasks });
  }
  if (!headline || weeks.length === 0) return null;
  weeks.sort((a, b) => a.week - b.week);
  const renumbered = weeks
    .slice(0, 4)
    .map((w, i) => ({ ...w, week: i + 1 }));
  return { headline, weeks: renumbered };
}

/// 給每個沒 id 的新 task 一個 stable id，便於前端後續勾選。
let _idCounter = 0;
export function ensureTaskIds(plan: RefinePlan): RefinePlan {
  const seen = new Set<string>();
  return {
    headline: plan.headline,
    weeks: plan.weeks.map((w) => ({
      ...w,
      tasks: w.tasks.map((t) => {
        let id = t.id?.trim() ?? "";
        if (!id || seen.has(id)) {
          _idCounter += 1;
          id = `t_${Date.now().toString(36)}_${_idCounter.toString(36)}`;
        }
        seen.add(id);
        return { ...t, id };
      }),
    })),
  };
}
