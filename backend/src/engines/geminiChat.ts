import type { Persona } from "@/types/persona";
import type { Profile } from "@/types/profile";

const SYSTEM_INSTRUCTION =
  "你是 EmploYA! 的青年職涯與創業服務助理「小幫手」。" +
  "用繁體中文、口語、溫暖、簡短地回覆（2 到 5 句話即可）。" +
  "可以聊職涯方向、面試、履歷、創業想法、心情、計畫拆解、學習路徑。" +
  "若使用者只是打招呼或問你是誰，請自我介紹並邀請他們聊聊現在卡在哪。" +
  "不要編造政策名稱、補助金額、申請資格或網址；如果問到具體政策請建議改問補助/課程關鍵字以觸發 RAG。";

export const lastGeminiChatError: { value: string | null } = { value: null };

export async function generateGeneralChatReply(opts: {
  message: string;
  persona?: Persona | null;
  profile?: Profile | null;
  mode: "career" | "startup";
  history?: Array<{ role: "user" | "assistant"; text: string }>;
}): Promise<{ reply: string; provider: "gemini" } | null> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    lastGeminiChatError.value = "missing GEMINI_API_KEY in process.env";
    return null;
  }
  lastGeminiChatError.value = null;

  // 4 層 model fallback：2.5-flash → 2.5-flash-lite → 2.0-flash → 1.5-flash
  // 不同 model family 在 Google 後端常常算不同 quota 池。
  const modelsToTry = Array.from(
    new Set(
      (process.env.GEMINI_MODEL_CHAIN ||
        [
          process.env.GEMINI_MODEL || "gemini-2.5-flash",
          process.env.GEMINI_FALLBACK_MODEL || "gemini-2.5-flash-lite",
          process.env.GEMINI_FALLBACK_MODEL_2 || "gemini-flash-latest",
          "gemini-flash-lite-latest",
        ].join(","))
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean),
    ),
  );

  const profileSummary = opts.profile
    ? `使用者資料：姓名=${opts.profile.name || "未填"}、科系=${opts.profile.department || "未填"}、年級=${opts.profile.grade || "未填"}、目前階段=${opts.profile.currentStage || "未填"}、興趣=${(opts.profile.interests ?? []).join("/") || "未填"}、目標=${(opts.profile.goals ?? []).join("/") || "未填"}、是否想創業=${opts.profile.startupInterest ? "是" : "否"}。`
    : "使用者資料：尚未填寫。";

  const personaSummary = opts.persona
    ? `Persona：${opts.persona.text}（階段：${opts.persona.careerStage}）。`
    : "Persona：尚未產生。";

  const historyText = (opts.history ?? [])
    .slice(-6)
    .map((h) => `${h.role === "user" ? "使用者" : "助理"}：${h.text}`)
    .join("\n");

  const requestBody = JSON.stringify({
    system_instruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
    contents: [
      {
        role: "user",
        parts: [
          {
            text:
              `${profileSummary}\n${personaSummary}\n模式：${opts.mode === "startup" ? "創業" : "職涯"}\n` +
              (historyText ? `\n近期對話：\n${historyText}\n` : "") +
              `\n使用者最新訊息：${opts.message}`,
          },
        ],
      },
    ],
    generationConfig: {
      temperature: 0.6,
      // 之前 400 token 對 2.5-flash 太緊，會被 thinking budget 先吃掉，
      // 實際輸出常常被截在半句中（user 看到的「也想找實…」就是這個）。
      // 拉高 + 關掉 thinking → 保證一句話講完、不浪費 quota 在 thinking。
      maxOutputTokens: 1200,
      thinkingConfig: { thinkingBudget: 0 },
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
        console.error(`[geminiChat] ${msg}`);
        if (response.status === 429 || response.status >= 500) continue;
        lastGeminiChatError.value = errors.join(" | ");
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
      const rawText =
        candidate?.content?.parts
          ?.map((part) => part.text ?? "")
          .join("")
          .trim() ?? "";
      const finishReason = candidate?.finishReason ?? "";
      if (!rawText) {
        const msg = `[${model}] empty text. finishReason=${finishReason} blockReason=${json.promptFeedback?.blockReason}`;
        errors.push(msg);
        console.error(`[geminiChat] ${msg}`);
        continue;
      }
      // 萬一還是被截：把尾巴修到最後一個完整句號 / 問號 / 驚嘆號，
      // 讓使用者至少看到一段不破句的回覆，而不是停在「也想找實」。
      const text =
        finishReason === "MAX_TOKENS" ? trimToLastSentence(rawText) : rawText;
      if (finishReason === "MAX_TOKENS") {
        console.warn(
          `[geminiChat] [${model}] finishReason=MAX_TOKENS, trimmed to last full sentence (${rawText.length} → ${text.length} chars)`,
        );
      }
      lastGeminiChatError.value = null;
      return { reply: text, provider: "gemini" };
    } catch (err) {
      const msg = err instanceof Error
        ? `[${model}] ${err.name}: ${err.message}`
        : `[${model}] ${String(err)}`;
      errors.push(msg);
      console.error("[geminiChat] threw:", err);
      continue;
    }
  }
  lastGeminiChatError.value = errors.join(" | ") || "all models failed";
  return null;
}

/// 把被 MAX_TOKENS 截斷的回覆修到最後一個完整句尾。
/// 若整段都沒出現句尾標點，最後保底加上「…」讓 user 知道是省略而非破句。
function trimToLastSentence(text: string): string {
  // 中文：。！？  英文：.!?  其他：）」』]
  const enders = ["。", "！", "？", ".", "!", "?", "）", "」", "』", "]", "\n"];
  let lastIdx = -1;
  for (const ch of enders) {
    const idx = text.lastIndexOf(ch);
    if (idx > lastIdx) lastIdx = idx;
  }
  if (lastIdx <= 0) return `${text}…`;
  // lastIdx 是最後一個句尾字元的 index → 包含它一起切。
  return text.slice(0, lastIdx + 1).trim();
}
