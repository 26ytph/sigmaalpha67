import type { Persona } from "@/types/persona";
import type { Profile } from "@/types/profile";

const SYSTEM_INSTRUCTION =
  "你是 EmploYA! 的青年職涯與創業服務助理「小幫手」。" +
  "用繁體中文、口語、溫暖、簡短地回覆（2 到 5 句話即可）。" +
  "可以聊職涯方向、面試、履歷、創業想法、心情、計畫拆解、學習路徑。" +
  "若使用者只是打招呼或問你是誰，請自我介紹並邀請他們聊聊現在卡在哪。" +
  "不要編造政策名稱、補助金額、申請資格或網址；如果問到具體政策請建議改問補助/課程關鍵字以觸發 RAG。";

export async function generateGeneralChatReply(opts: {
  message: string;
  persona?: Persona | null;
  profile?: Profile | null;
  mode: "career" | "startup";
  history?: Array<{ role: "user" | "assistant"; text: string }>;
}): Promise<{ reply: string; provider: "gemini" } | null> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) return null;

  const model = process.env.GEMINI_MODEL || "gemini-2.5-flash";
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
    model,
  )}:generateContent`;

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

  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
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
          maxOutputTokens: 400,
        },
      }),
    });

    if (!response.ok) return null;
    const json = (await response.json()) as {
      candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
    };
    const text = json.candidates?.[0]?.content?.parts
      ?.map((part) => part.text ?? "")
      .join("")
      .trim();
    if (!text) return null;
    return { reply: text, provider: "gemini" };
  } catch {
    return null;
  }
}
