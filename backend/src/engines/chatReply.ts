// =====================================================================
// FAKE engine — keyword-based chatbot reply.
// Mirrors `_mockReply` in `lib/screens/chat_screen.dart`.
// Replace with a real LLM call (Anthropic Claude, OpenAI, etc.).
// =====================================================================

import type { Profile } from "@/types/profile";
import type { Persona } from "@/types/persona";

const FALLBACKS = [
  "可以再多說一點嗎？例如你目前卡在哪個階段？",
  "我先記下這個方向。你希望今天就動手做一件小事，還是先想清楚再行動？",
  "聽起來值得拆成幾個小步驟。要不要一起列出第一步？",
  "不錯的問題。先問自己：3 個月後若這件事完成，會長什麼樣子？",
];

export function generateChatReply(opts: {
  message: string;
  profile?: Profile | null;
  persona?: Persona | null;
  mode: "career" | "startup";
}): { reply: string; shouldHandoff: boolean; tokensUsed: number } {
  const m = opts.message;
  const p = m.toLowerCase();

  let reply: string;
  if (/面試|interview/i.test(m)) {
    reply =
      "面試前先把履歷上的每個專案濃縮成 30 秒版本，並準備 1 個量化成果（例如「將處理時間縮短 40%」）。要我幫你列幾個常見問題嗎？";
  } else if (/履歷|resume|cv/i.test(m)) {
    reply = "一頁式履歷的關鍵：用動詞開頭、加數字、把最近最相關的經驗放最上面。需要我看哪一段？";
  } else if (/計畫|plan|todo/i.test(m)) {
    reply = "可以從「計畫」分頁的 4–8 週清單開始，挑一週先完成 1 個小任務累積動能，比一次塞滿更容易持續。";
  } else if (/興趣|探索|方向/.test(m)) {
    reply = "不確定方向時，建議到「探索」分頁滑 20 張卡，把按 ❤ 的職位列出來，再看共同的關鍵字 — 那通常就是你的興趣輪廓。";
  } else if (/壓力|焦慮|迷惘/.test(m)) {
    reply = "迷惘很正常。把你今天能做的事縮到最小一步：寫下 1 件想釐清的事 + 1 個可以問的人，先動起來再說。";
  } else if (/你好|hi|hello|哈囉/i.test(p)) {
    reply = "哈囉！想從哪裡開始？我可以陪你想方向、整理履歷、或拆解計畫。";
  } else if (opts.mode === "startup" || /創業|開店|startup|founder/i.test(m)) {
    reply = "創業初期最危險的是「過早寫程式或設計」。先用 Lean Canvas 寫清楚假設，再去找 5 個目標客群驗證。";
  } else {
    reply = FALLBACKS[Math.floor(Math.random() * FALLBACKS.length)];
  }

  // Light personalisation if we know something about the user.
  if (opts.profile?.name) {
    reply = reply.replace(/^/, `${opts.profile.name}，`);
  }

  const shouldHandoff = /焦慮|壓力|急|憂鬱|難過|想哭/.test(m);
  const tokensUsed = Math.min(800, 80 + reply.length * 2);
  return { reply, shouldHandoff, tokensUsed };
}
