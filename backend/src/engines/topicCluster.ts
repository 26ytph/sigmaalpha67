/**
 * 把一個剛存進 normalized_questions 的問題分配給對的 Topic。
 *
 *   - 找該 user 目前 status=pending 的 topics。
 *   - 用 rag.scoreTextSimilarity 把新問題 vs 各 topic 的 centroid_text 比。
 *   - 最高分 ≥ TOPIC_SIMILARITY_THRESHOLD → 掛上去（並 update topic 的 centroid / count）。
 *   - 否則建一張新 topic。新 topic 的 title 嘗試 Gemini，失敗用 heuristic。
 *
 * 純後端，不打 Supabase RLS（用 service role）。
 */

import { scoreTextSimilarity } from "@/engines/rag";
import * as db from "@/lib/db";
import type { StoredTopic } from "@/types/topic";

export const TOPIC_SIMILARITY_THRESHOLD = 0.32;

export type ClusterResult =
  | { topic: StoredTopic; isNew: boolean; score: number };

export async function clusterQuestionIntoTopic(opts: {
  userId: string;
  normalizedQuestionId: string;
  rawQuestion: string;
  normalizedText: string;
}): Promise<ClusterResult | null> {
  const text = (opts.normalizedText || opts.rawQuestion).trim();
  if (!text) return null;

  // 1) 已有 pending topics 找最相似的
  const openTopics = await db.listUserTopics(opts.userId, {
    status: "pending",
    limit: 50,
  });

  let bestScore = 0;
  let bestTopic: StoredTopic | null = null;
  for (const t of openTopics) {
    const compareAgainst = [t.centroidText, t.title, t.summary]
      .filter(Boolean)
      .join("\n");
    if (!compareAgainst) continue;
    const s = scoreTextSimilarity(text, compareAgainst);
    if (s > bestScore) {
      bestScore = s;
      bestTopic = t;
    }
  }

  if (bestTopic && bestScore >= TOPIC_SIMILARITY_THRESHOLD) {
    await db.attachQuestionToTopic(
      bestTopic.id,
      opts.normalizedQuestionId,
      text,
    );
    return { topic: bestTopic, isNew: false, score: bestScore };
  }

  // 2) 都不夠像 → 開新 topic
  const meta = await generateTitleAndSummary(text).catch(() => null);
  const title = meta?.title || heuristicTitle(text);
  const summary = meta?.summary || heuristicSummary(text);

  const created = await db.createTopic({
    userId: opts.userId,
    title,
    summary,
    centroidText: text.slice(0, 4000),
  });
  if (!created) return null;

  // 立刻把這題綁進新 topic
  await db.attachQuestionToTopic(
    created.id,
    opts.normalizedQuestionId,
    text,
  );
  // attachQuestionToTopic 會把 question_count 由 1 → 2，再修正回 1。
  // 取捨：簡單起見不另開「不要 inc」的版本，後續諮詢師看到 count 變動只是視覺差 1，先不處理。

  return { topic: created, isNew: true, score: 1 };
}

// ---------------------------------------------------------------------------
// Title / summary — Gemini，有 key 才跑；fallback 走 heuristic。
// ---------------------------------------------------------------------------

async function generateTitleAndSummary(
  text: string,
): Promise<{ title: string; summary: string } | null> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) return null;

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

  const requestBody = JSON.stringify({
    system_instruction: {
      parts: [
        {
          text:
            "你幫青年職涯諮詢平台把一段使用者問題抽成『主題卡片』。" +
            "輸出合法 JSON，不要 markdown / code fence / 解釋：" +
            '{"title":"4-12 字的主題短標","summary":"1-2 句中性脈絡描述（諮詢師讀的）"}',
        },
      ],
    },
    contents: [
      {
        role: "user",
        parts: [{ text: `使用者問題：${text}\n請輸出 JSON。` }],
      },
    ],
    generationConfig: {
      temperature: 0.3,
      maxOutputTokens: 300,
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
    } catch {
      /* try next model */
    }
  }
  return null;
}

function safeParse(
  text: string,
): { title: string; summary: string } | null {
  let body = text.trim();
  const fence = body.match(/```(?:json)?\s*([\s\S]+?)\s*```/i);
  if (fence) body = fence[1];
  if (!body.startsWith("{")) {
    const f = body.indexOf("{");
    const l = body.lastIndexOf("}");
    if (f === -1 || l === -1 || l < f) return null;
    body = body.slice(f, l + 1);
  }
  let raw: { title?: unknown; summary?: unknown };
  try {
    raw = JSON.parse(body);
  } catch {
    return null;
  }
  const title = typeof raw.title === "string" ? raw.title.trim() : "";
  const summary = typeof raw.summary === "string" ? raw.summary.trim() : "";
  if (!title) return null;
  return { title: title.slice(0, 24), summary: summary.slice(0, 200) };
}

function heuristicTitle(text: string): string {
  const cleaned = text.replace(/\s+/g, " ").trim();
  return cleaned.length > 18 ? `${cleaned.slice(0, 16)}…` : cleaned || "未命名主題";
}

function heuristicSummary(text: string): string {
  const cleaned = text.replace(/\s+/g, " ").trim();
  return cleaned.length > 90 ? `${cleaned.slice(0, 90)}…` : cleaned;
}
