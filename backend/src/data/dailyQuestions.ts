// =====================================================================
// FAKE DATA — daily questions pool.
// Replace with CMS-managed content or an editorial database.
// Mirrors `lib/data/daily_questions.dart`.
// =====================================================================

import type { DailyQuestion } from "@/types/daily";

export const DAILY_QUESTIONS: DailyQuestion[] = [
  {
    id: "q_engineer_01",
    text: "工程師整天都在寫程式嗎？",
    answer: "其實寫程式只佔 30–50%，其餘時間花在會議、文件、code review、debug 與和產品 / 設計對齊。",
    options: ["10–20%", "30–50%", "60–80%", "90% 以上"],
    roleTags: ["engineering"],
  },
  {
    id: "q_designer_01",
    text: "設計師的第一步通常是？",
    answer: "從理解使用者問題開始 — 訪談、觀察、找痛點，再進入 wireframe 與視覺。",
    options: ["立刻打開 Figma", "理解使用者問題", "問老闆要什麼", "找參考圖"],
    roleTags: ["design"],
  },
  {
    id: "q_pm_01",
    text: "PM 最常做的決定是什麼？",
    answer: "決定『不做什麼』。資源永遠不夠，學會排優先序、砍掉低 ROI 的功能很關鍵。",
    options: ["做什麼新功能", "不做什麼", "用什麼技術", "誰來做"],
    roleTags: ["product"],
  },
  {
    id: "q_data_01",
    text: "資料分析師最重要的能力是？",
    answer: "把問題拆成可以用資料回答的形式 — 商業敏感度比 SQL 技巧重要得多。",
    options: ["SQL 寫得快", "問題拆解能力", "Python 熟", "視覺化漂亮"],
    roleTags: ["data"],
  },
  {
    id: "q_marketing_01",
    text: "行銷成效最該看哪個指標？",
    answer: "視階段而定。品牌期看曝光與互動，轉換期看 CAC 與 ROAS。沒有單一萬能指標。",
    options: ["按讚數", "曝光", "視階段而定", "CTR"],
    roleTags: ["marketing"],
  },
  {
    id: "q_career_01",
    text: "找第一份工作最該優先看什麼？",
    answer: "團隊成長性 + 直屬主管。新人最大的紅利是「跟對人」，遠比公司名氣重要。",
    options: ["薪水", "公司名氣", "團隊與主管", "離家近"],
    roleTags: [],
  },
];

export function pickQuestionForDate(date: string): DailyQuestion {
  // Simple deterministic pick by date hash, like the Flutter app.
  let hash = 0;
  for (let i = 0; i < date.length; i++) hash = (hash * 31 + date.charCodeAt(i)) | 0;
  const idx = Math.abs(hash) % DAILY_QUESTIONS.length;
  return DAILY_QUESTIONS[idx];
}

export function getQuestionById(id: string): DailyQuestion | undefined {
  return DAILY_QUESTIONS.find((q) => q.id === id);
}
