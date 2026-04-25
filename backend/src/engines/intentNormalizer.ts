// =====================================================================
// FAKE engine — keyword-based intent normalisation.
// Mirrors `lib/logic/intent_normalizer.dart`. Replace with an LLM call.
// =====================================================================

import type { NormalizedQuestion } from "@/types/chat";

export function normalizeQuestion(question: string): NormalizedQuestion {
  const q = question.toLowerCase();
  const intents: string[] = [];
  if (/履歷|resume|cv/i.test(question)) intents.push("履歷協助");
  if (/面試|interview/i.test(question)) intents.push("面試準備");
  if (/方向|興趣|科系|不知道|迷惘/.test(question)) intents.push("職涯探索");
  if (/實習|找工作|工作/.test(question)) intents.push("求職規劃");
  if (/創業|開店|founder|startup/i.test(question)) intents.push("創業諮詢");
  if (intents.length === 0) intents.push("一般諮詢");

  let userStage = "在學探索";
  if (/畢業|大四|graduating/.test(q)) userStage = "應屆畢業生";
  if (/已工作|轉職|現職/.test(q)) userStage = "在職轉職";

  let emotion = "中性";
  if (/焦慮|壓力|擔心|害怕|難|困難|迷惘/.test(question)) emotion = "焦慮、有壓力";
  if (/想嘗試|期待|興奮/.test(question)) emotion = "期待但不確定";

  let urgency: NormalizedQuestion["urgency"] = "中";
  if (/急|立刻|馬上|下週|這週/.test(question)) urgency = "高";
  else if (emotion === "焦慮、有壓力") urgency = "中高";

  const missingInfo: string[] = [];
  if (!/科系|系/.test(question)) missingInfo.push("科系");
  if (!/經驗|做過|實習/.test(question)) missingInfo.push("過去經驗");
  if (!/想做|目標|產業/.test(question)) missingInfo.push("目標產業");

  const knownInfo: string[] = [];
  const deptMatch = question.match(/(\S+?)系/);
  if (deptMatch) knownInfo.push(`科系：${deptMatch[1]}系`);

  const suggestedQuestions: string[] = [];
  if (missingInfo.includes("科系")) suggestedQuestions.push("你目前就讀什麼科系？");
  if (missingInfo.includes("過去經驗"))
    suggestedQuestions.push("過去有哪些社團、課程或實習經驗？");
  if (missingInfo.includes("目標產業"))
    suggestedQuestions.push("有沒有特別感興趣的產業或職位？");
  if (suggestedQuestions.length === 0)
    suggestedQuestions.push("你希望今天的對話結束時，能帶走什麼？");

  return {
    userStage,
    intents,
    emotion,
    knownInfo,
    missingInfo,
    suggestedQuestions,
    urgency,
    counselorSummary:
      `使用者目前處於${userStage}階段，` +
      `主要意圖：${intents.join("、")}，` +
      `情緒：${emotion}。` +
      (missingInfo.length ? `尚缺資訊：${missingInfo.join("、")}。` : ""),
  };
}
