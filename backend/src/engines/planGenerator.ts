// =====================================================================
// Plan generator — Gemini-first, template-fallback.
//
// Inputs:
//   - mode: "career" | "startup"
//   - likedRoleIds: roles the user swiped right on
//   - persona: optional, for personalisation
//
// Computes deterministically:
//   - top tags (from liked-role catalogue lookup)
//   - recommended roles (the actual liked role cards, capped at 3)
//
// Gets from Gemini (with template fallback):
//   - headline
//   - 4 personalised weeks { title, goals, resources, outputs }
//
// Mirrors `lib/logic/generate_plan.dart` on the Flutter side; that file
// is now the local fallback used when the device can't reach this API.
// =====================================================================

import type { Plan, PlanWeek } from "@/types/plan";
import type { Persona } from "@/types/persona";
import type { RoleCard } from "@/types/swipe";
import { getRoleCardById } from "@/data/roles";
import {
  PLAN_HEADLINES,
  PLAN_TEMPLATES,
  pickPlanKey,
} from "@/data/planTemplates";

export const lastPlanGeminiError: { value: string | null } = { value: null };

const SYSTEM_INSTRUCTION = [
  "你是 EmploYA! 的職涯路徑生成器，專門為臺灣年輕人量身打造 4 週能力建構計畫。",
  "規則：",
  "1. 只輸出符合 schema 的 JSON，不加任何前後說明文字。",
  "2. 一律用繁體中文。語氣親切、口語、可執行；避免過於書面或八股。",
  "3. 每週 goals 寫成具體動作（含數字與動詞，例如「完成一份 1 頁 wireframe」），不要空泛口號。",
  "4. resources 是真的能找到的資源類型（書、官方文件、線上課平台），不要捏造特定書名 ISBN 或網址。",
  "5. outputs 是該週結束時應該交付的成果（可放履歷或作品集的東西）。",
  "6. headline 是一行 ≤ 22 字的本月主題，例如：「先把基本功打穩，做出第一個能展示的小作品」。",
  "7. 4 週要有節奏：盤點 → 打底 → 做出來 → 收斂展示。",
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
          goals: { type: "ARRAY", items: { type: "STRING" } },
          resources: { type: "ARRAY", items: { type: "STRING" } },
          outputs: { type: "ARRAY", items: { type: "STRING" } },
        },
        required: ["week", "title", "goals", "resources", "outputs"],
      },
    },
  },
  required: ["headline", "weeks"],
};

type GeminiPlanResult = { headline: string; weeks: PlanWeek[] };

function buildUserPrompt(opts: {
  mode: "career" | "startup";
  topTag: string | null;
  likedRoles: RoleCard[];
  persona: Persona | null | undefined;
}): string {
  const lines: string[] = [];

  lines.push(`模式：${opts.mode === "startup" ? "創業者" : "求職者"}`);

  if (opts.persona) {
    lines.push(`Persona：${opts.persona.text}`);
    lines.push(`目前階段：${opts.persona.careerStage}`);
    if (opts.persona.mainInterests.length) {
      lines.push(`興趣：${opts.persona.mainInterests.join("、")}`);
    }
    if (opts.persona.strengths.length) {
      lines.push(`已有能力：${opts.persona.strengths.join("、")}`);
    }
    if (opts.persona.skillGaps.length) {
      lines.push(`待補強：${opts.persona.skillGaps.join("、")}`);
    }
    if (opts.persona.recommendedNextStep) {
      lines.push(`下一步：${opts.persona.recommendedNextStep}`);
    }
  } else {
    lines.push("Persona：尚未產生（請以興趣推估）。");
  }

  if (opts.likedRoles.length) {
    const desc = opts.likedRoles
      .map((r) => `「${r.title}」(${r.tagline})`)
      .join("、");
    lines.push(`使用者按 ❤ 過的職位：${desc}`);
  } else {
    lines.push("使用者尚未按 ❤ 任何職位（請偏向通用方向探索）。");
  }
  if (opts.topTag) {
    lines.push(`最強訊號 tag：${opts.topTag}`);
  }

  lines.push("");
  lines.push(
    "請輸出 4 週的能力建構計畫 JSON：每週 2–4 個 goals、1–3 個 resources、2–3 個 outputs。",
  );
  return lines.join("\n");
}

async function generatePlanWithGemini(opts: {
  mode: "career" | "startup";
  topTag: string | null;
  likedRoles: RoleCard[];
  persona: Persona | null | undefined;
}): Promise<GeminiPlanResult | null> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    lastPlanGeminiError.value = "missing GEMINI_API_KEY in process.env";
    return null;
  }
  lastPlanGeminiError.value = null;

  // Same model-chain fallback as geminiChat.ts. Plan is bigger output so
  // 2.5-flash is the sweet spot; fall back to lite/2.0 on quota errors.
  const modelsToTry = Array.from(
    new Set(
      (
        process.env.GEMINI_PLAN_MODEL_CHAIN ||
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

  const userPrompt = buildUserPrompt(opts);
  const requestBody = JSON.stringify({
    system_instruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
    contents: [{ role: "user", parts: [{ text: userPrompt }] }],
    generationConfig: {
      temperature: 0.5,
      maxOutputTokens: 1500,
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
        console.error(`[planGenerator] ${msg}`);
        if (response.status === 429 || response.status >= 500) continue;
        lastPlanGeminiError.value = errors.join(" | ");
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
        const msg = `[${model}] empty text. finishReason=${candidate?.finishReason} blockReason=${json.promptFeedback?.blockReason}`;
        errors.push(msg);
        console.error(`[planGenerator] ${msg}`);
        continue;
      }
      const parsed = parsePlanJson(text);
      if (!parsed) {
        const msg = `[${model}] could not parse plan JSON: ${text.slice(0, 200)}`;
        errors.push(msg);
        console.error(`[planGenerator] ${msg}`);
        continue;
      }
      lastPlanGeminiError.value = null;
      return parsed;
    } catch (err) {
      const msg = err instanceof Error
        ? `[${model}] ${err.name}: ${err.message}`
        : `[${model}] ${String(err)}`;
      errors.push(msg);
      console.error("[planGenerator] threw:", err);
      continue;
    }
  }
  lastPlanGeminiError.value = errors.join(" | ") || "all models failed";
  return null;
}

function parsePlanJson(text: string): GeminiPlanResult | null {
  // responseMimeType=application/json should give us pure JSON, but
  // be defensive — strip code fences if Gemini sneaks them in.
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
  const weeks: PlanWeek[] = [];
  for (const raw of weeksRaw) {
    if (!raw || typeof raw !== "object") continue;
    const w = raw as Record<string, unknown>;
    const week =
      typeof w.week === "number" ? w.week : Number.parseInt(`${w.week}`, 10);
    const title = typeof w.title === "string" ? w.title.trim() : "";
    if (!Number.isFinite(week) || !title) continue;
    const goals = stringArray(w.goals);
    const resources = stringArray(w.resources);
    const outputs = stringArray(w.outputs);
    if (goals.length === 0 && outputs.length === 0) continue;
    weeks.push({ week, title, goals, resources, outputs });
  }
  if (!headline || weeks.length === 0) return null;
  // Re-number defensively — Gemini sometimes drops weeks or starts at 0.
  weeks.sort((a, b) => a.week - b.week);
  const renumbered = weeks
    .slice(0, 4)
    .map((w, i) => ({ ...w, week: i + 1 }));
  return { headline, weeks: renumbered };
}

function stringArray(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  return v
    .map((x) => (typeof x === "string" ? x.trim() : ""))
    .filter((s) => s.length > 0);
}

// ---------------------------------------------------------------------
// Public API — same signature as before but now async.
// ---------------------------------------------------------------------

export async function generatePlan(opts: {
  mode: "career" | "startup";
  likedRoleIds: string[];
  persona?: Persona | null;
}): Promise<Plan> {
  // 1) deterministic parts
  const tagCount = new Map<string, number>();
  for (const id of opts.likedRoleIds) {
    const card = getRoleCardById(id);
    if (!card) continue;
    for (const tag of card.tags) {
      tagCount.set(tag, (tagCount.get(tag) ?? 0) + 1);
    }
  }
  const sorted = [...tagCount.entries()].sort((a, b) => b[1] - a[1]);
  const topTag = sorted[0]?.[0] ?? null;
  const basedOnTopTags = sorted
    .slice(0, 3)
    .map(([tag, score]) => ({ tag, score }));

  const likedRoles = opts.likedRoleIds
    .map((id) => getRoleCardById(id))
    .filter((c): c is RoleCard => Boolean(c));
  const recommendedRoles = likedRoles.slice(0, 3);

  // 2) Try Gemini for headline + weeks
  const gemini = await generatePlanWithGemini({
    mode: opts.mode,
    topTag,
    likedRoles,
    persona: opts.persona,
  });
  if (gemini) {
    return {
      headline: gemini.headline,
      basedOnTopTags:
        opts.mode === "startup" && basedOnTopTags.length === 0
          ? [{ tag: "startup", score: opts.likedRoleIds.length || 1 }]
          : basedOnTopTags,
      recommendedRoles:
        opts.mode === "startup" && recommendedRoles.length === 0
          ? [getRoleCardById("founder")!].filter(Boolean)
          : recommendedRoles,
      weeks: gemini.weeks,
    };
  }

  // 3) Template fallback
  if (opts.mode === "startup") {
    return {
      headline: PLAN_HEADLINES.startup,
      basedOnTopTags: [{ tag: "startup", score: opts.likedRoleIds.length || 1 }],
      recommendedRoles: [getRoleCardById("founder")!].filter(Boolean),
      weeks: PLAN_TEMPLATES.startup,
    };
  }
  const key = pickPlanKey(topTag);
  return {
    headline: PLAN_HEADLINES[key],
    basedOnTopTags,
    recommendedRoles,
    weeks: PLAN_TEMPLATES[key],
  };
}
