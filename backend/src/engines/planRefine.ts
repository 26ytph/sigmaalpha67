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

function summarisePlan(plan: RefinePlan): string {
  const lines: string[] = [`目前計畫主題：${plan.headline}`];
  for (const w of plan.weeks) {
    lines.push(`第 ${w.week} 週 · ${w.title}`);
    for (const t of w.tasks) {
      const flag = t.done ? "[已完成]" : t.userAdded ? "[使用者新增]" : "";
      lines.push(`  - id=${t.id} · section=${t.section} · ${t.title}${flag}`);
    }
  }
  return lines.join("\n");
}

function buildUserPrompt(opts: {
  prompt: string;
  currentPlan: RefinePlan;
  mode: "career" | "startup";
  persona: Persona | null | undefined;
}): string {
  const lines: string[] = [];
  lines.push(`模式：${opts.mode === "startup" ? "創業者" : "求職者"}`);

  if (opts.persona && opts.persona.text) {
    lines.push(`Persona：${opts.persona.text}`);
    if (opts.persona.mainInterests?.length) {
      lines.push(`興趣：${opts.persona.mainInterests.join("、")}`);
    }
    if (opts.persona.strengths?.length) {
      lines.push(`已有能力：${opts.persona.strengths.join("、")}`);
    }
    if (opts.persona.skillGaps?.length) {
      lines.push(`待補強：${opts.persona.skillGaps.join("、")}`);
    }
  }

  lines.push("");
  lines.push("使用者目前的計畫：");
  lines.push(summarisePlan(opts.currentPlan));
  lines.push("");
  lines.push(`使用者新需求：「${opts.prompt}」`);
  lines.push("");
  lines.push(
    "請依需求調整計畫並輸出 JSON。保留還合理的舊任務 id，新增任務 id 用空字串。",
  );
  return lines.join("\n");
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

  const userPrompt = buildUserPrompt({
    prompt: opts.prompt,
    currentPlan: opts.currentPlan,
    mode: opts.mode,
    persona: opts.persona,
  });
  const requestBody = JSON.stringify({
    system_instruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
    contents: [{ role: "user", parts: [{ text: userPrompt }] }],
    generationConfig: {
      temperature: 0.5,
      maxOutputTokens: 1800,
      responseMimeType: "application/json",
      responseSchema: RESPONSE_SCHEMA,
    },
  });

  const errors: string[] = [];
  for (const model of modelsToTry) {
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
      model,
    )}:generateContent`;
    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: requestBody,
      });
      if (!response.ok) {
        const body = await response.text().catch(() => "");
        const msg = `[${model}] HTTP ${response.status}: ${body.slice(0, 200)}`;
        errors.push(msg);
        if (response.status === 429 || response.status >= 500) continue;
        lastRefineGeminiError.value = errors.join(" | ");
        return null;
      }
      const json = (await response.json()) as {
        candidates?: Array<{
          content?: { parts?: Array<{ text?: string }> };
          finishReason?: string;
        }>;
        promptFeedback?: { blockReason?: string };
      };
      const candidate = json.candidates?.[0];
      const text = candidate?.content?.parts
        ?.map((p) => p.text ?? "")
        .join("")
        .trim();
      if (!text) {
        errors.push(
          `[${model}] empty text. finishReason=${candidate?.finishReason} blockReason=${json.promptFeedback?.blockReason}`,
        );
        continue;
      }
      const parsed = parsePlanJson(text);
      if (!parsed) {
        errors.push(`[${model}] parse failed: ${text.slice(0, 200)}`);
        continue;
      }
      lastRefineGeminiError.value = null;
      return parsed;
    } catch (err) {
      const msg =
        err instanceof Error ? `[${model}] ${err.message}` : `[${model}] ${err}`;
      errors.push(msg);
      continue;
    }
  }
  lastRefineGeminiError.value = errors.join(" | ") || "all models failed";
  return null;
}

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
