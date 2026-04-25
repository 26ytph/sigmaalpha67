import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { apiError } from "@/lib/errors";
import * as db from "@/lib/db";
import {
  buildCounselorFaqSource,
  ensureKnowledgeBaseSeeded,
  upsertKnowledgeSource,
} from "@/engines/rag";

/**
 * POST /api/counselor/topics/{topicId}/resolve
 *
 * 諮詢師按下「問題解決」 — 把整個主題的 Q (使用者問題們) + 諮詢師回覆統整後丟進 KB，
 * 並把 topic 標 resolved，所有成員 normalized_questions 也跟著 resolved=true。
 *
 * 重要：AI 暫時回覆**不會**被收進 KB 整理 —— 只用 user 的原始問題 + 諮詢師回覆。
 */
export const POST = withAuth<{ topicId: string }>(
  async (_req, { auth, params }) => {
    const topic = await db.fetchTopicWithMembers(params.topicId);
    if (!topic) return apiError("not_found", "Topic not found.");
    if (topic.status === "resolved") {
      return NextResponse.json({ topic, alreadyResolved: true });
    }

    // 1) 把 user 原始問題彙整
    const questionsBlock = topic.members
      .map((m, i) => `${i + 1}. ${m.rawQuestion || m.normalizedText}`)
      .join("\n");

    // 2) 把這個 topic 下所有諮詢師回覆全部串起來餵給 LLM 整理 — 比只挑最後一則更完整。
    //    fetchTopicWithMembers 已經幫我們依時間排好。
    const counselorReplies = topic.counselorReplies ?? [];
    if (counselorReplies.length === 0) {
      return apiError(
        "bad_request",
        "尚未看到任何諮詢師回覆 — 請先用 /reply 送一句答覆再標解決。",
      );
    }
    const counselorAnswer = counselorReplies
      .map((r, i) =>
        counselorReplies.length === 1 ? r.text : `(${i + 1}) ${r.text}`,
      )
      .join("\n\n");

    // 3) AI 整理（標題 / 摘要 / 整合過的問題敘述）— 不採用 AI 暫時回覆
    const summarized = await summarizeTopicQA({
      title: topic.title,
      questionsBlock,
      counselorAnswer,
    }).catch(() => null);

    const finalQuestion =
      summarized?.questionAggregate ||
      `${topic.title}\n\n${questionsBlock}`;
    const finalAnswer = summarized?.answerCleaned || counselorAnswer;

    // 4) push 進 in-memory KB + supabase counselor_faqs (兩邊都要，之前 008 已建表)
    const faqId = `topic_faq_${topic.id}`;
    try {
      ensureKnowledgeBaseSeeded();
      upsertKnowledgeSource(
        buildCounselorFaqSource({
          question: finalQuestion,
          answer: finalAnswer,
          caseId: `topic_${topic.id}`,
          tags: ["諮詢師審核", "主題彙整", topic.title].filter(Boolean),
        }),
      );
    } catch (e) {
      console.warn("[topic.resolve] push to KB failed:", e);
    }
    await db
      .upsertCounselorFaq({
        id: faqId,
        question: finalQuestion,
        answer: finalAnswer,
        tags: ["諮詢師審核", "主題彙整", topic.title].filter(Boolean),
        createdBy: auth.userId,
      })
      .catch(() => {});

    // 5) 標 topic resolved（同時 cascading 把所有成員 normalized_questions 改 resolved=true）
    const updated = await db.markTopicResolved(topic.id, {
      resolvedBy: auth.userId,
      kbSourceId: faqId,
    });

    return NextResponse.json({
      topic: updated,
      kbSourceId: faqId,
      summarized: summarized ?? null,
    });
  },
);

// ---------------------------------------------------------------------------

async function summarizeTopicQA(opts: {
  title: string;
  questionsBlock: string;
  counselorAnswer: string;
}): Promise<{ questionAggregate: string; answerCleaned: string } | null> {
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

  const prompt =
    `主題：${opts.title}\n\n` +
    `以下是同主題下使用者問過的多個版本：\n${opts.questionsBlock}\n\n` +
    `諮詢師最終的整合回覆：\n${opts.counselorAnswer}\n\n` +
    `請幫我把這個主題彙整成適合放進 RAG 的 Q&A：\n` +
    `1) 把上面那些不同講法的問題，統合成 1-3 句話、最具代表性的問題敘述（去除個人情緒、保留具體疑問）。\n` +
    `2) 整理諮詢師回覆 — 不要改變實質訊息、不要編造額外資訊，只是讓行文乾淨好讀。\n` +
    `輸出合法 JSON，不要 markdown / 解釋：\n` +
    `{"questionAggregate":"...","answerCleaned":"..."}`;

  const requestBody = JSON.stringify({
    system_instruction: {
      parts: [
        {
          text:
            "你是 EmploYA! 的 KB 整理助理。把諮詢師處理過的主題打包成可以餵給 RAG 的 Q&A。" +
            "用繁體中文。輸出純 JSON，不要包 markdown / code fence / 解釋。",
        },
      ],
    },
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: {
      temperature: 0.25,
      maxOutputTokens: 700,
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
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
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
): { questionAggregate: string; answerCleaned: string } | null {
  let body = text.trim();
  const fence = body.match(/```(?:json)?\s*([\s\S]+?)\s*```/i);
  if (fence) body = fence[1];
  if (!body.startsWith("{")) {
    const f = body.indexOf("{");
    const l = body.lastIndexOf("}");
    if (f === -1 || l === -1 || l < f) return null;
    body = body.slice(f, l + 1);
  }
  let raw: { questionAggregate?: unknown; answerCleaned?: unknown };
  try {
    raw = JSON.parse(body);
  } catch {
    return null;
  }
  const q =
    typeof raw.questionAggregate === "string"
      ? raw.questionAggregate.trim()
      : "";
  const a =
    typeof raw.answerCleaned === "string" ? raw.answerCleaned.trim() : "";
  if (!q || !a) return null;
  return { questionAggregate: q, answerCleaned: a };
}
