// =====================================================================
// FAKE engine — counselor handoff brief builder.
// Mirrors `lib/logic/counselor_brief.dart`. Replace with an LLM call.
// =====================================================================

import type { CounselorCase } from "@/types/counselor";
import type { NormalizedQuestion } from "@/types/chat";
import type { Profile } from "@/types/profile";
import type { Persona } from "@/types/persona";
import type { SwipeSummary } from "@/types/swipe";
import { newId } from "@/lib/store";

export function buildCounselorBrief(opts: {
  userId: string;
  profile?: Profile | null;
  persona?: Persona | null;
  swipeSummary?: SwipeSummary | null;
  userQuestion: string;
  normalized: NormalizedQuestion;
  fromMessageId?: string;
}): CounselorCase {
  const profile = opts.profile;
  const userBackground = [
    profile?.department,
    profile?.grade,
    profile?.currentStage ?? "在學探索",
  ]
    .filter(Boolean)
    .join("・");

  const swipe = opts.swipeSummary;
  const recentActivities = swipe
    ? `近期右滑了 ${swipe.likedRoleIds.length} 個職位；興趣集中在 ${
        swipe.topTags
          .slice(0, 2)
          .map((t) => t.tag)
          .join("、") || "尚未明顯"
      }`
    : "尚無滑卡資料。";

  const aiAnalysis =
    `意圖：${opts.normalized.intents.join("、")}；情緒：${opts.normalized.emotion}；` +
    (opts.normalized.missingInfo.length
      ? `尚缺：${opts.normalized.missingInfo.join("、")}。`
      : "資訊大致完整。");

  const suggestedTopics: string[] = [];
  if (opts.normalized.emotion.includes("焦慮"))
    suggestedTopics.push("先以同理回應，避免立即給建議。");
  for (const m of opts.normalized.missingInfo) suggestedTopics.push(`優先確認：${m}`);
  if (suggestedTopics.length === 0) suggestedTopics.push("可直接進入具體建議。");

  const recommendedResources = (() => {
    const r: string[] = [];
    if (opts.normalized.intents.includes("履歷協助")) r.push("一頁式履歷模板");
    if (opts.normalized.intents.includes("面試準備")) r.push("STAR 結構問答庫");
    if (opts.normalized.intents.includes("職涯探索")) r.push("興趣探索量表");
    if (opts.normalized.intents.includes("創業諮詢")) r.push("Lean Canvas 模板");
    if (r.length === 0) r.push("通用職涯諮詢手冊");
    return r;
  })();

  const aiDraftReply =
    `嗨${profile?.name ?? ""}，聽起來目前有些壓力。` +
    `從你的背景看（${userBackground || "未填寫"}），` +
    `建議下一步：${recommendedResources[0]}。需要的話我們可以一起看 30 分鐘。`;

  const now = new Date().toISOString();
  return {
    id: newId("case"),
    userId: opts.userId,
    status: "waiting_for_counselor",
    urgency: opts.normalized.urgency,
    userBackground: userBackground || "（資料未填寫）",
    personaSummary: opts.persona?.text ?? "（尚未生成 persona）",
    recentActivities,
    mainQuestion: opts.userQuestion,
    aiAnalysis,
    suggestedTopics,
    recommendedResources,
    aiDraftReply,
    createdAt: now,
    updatedAt: now,
  };
}
