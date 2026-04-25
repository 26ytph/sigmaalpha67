import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { TOP_QUESTIONS, SKILL_GAPS, STARTUP_NEEDS } from "@/data/adminMetrics";

type Body = { focusArea?: string };

// FAKE: rule-stitched policy suggestions. Replace with an LLM that takes the
// dashboard metrics as context and produces grounded recommendations.
export const POST = withAuth(async (req) => {
  const body: Body = await readJson<Body>(req).catch(() => ({} as Body));
  const focus = body.focusArea ?? "career";

  const suggestions = [
    {
      title: "強化履歷敘事與作品集教學供給",
      rationale: `「${SKILL_GAPS[0].skill}」與「${SKILL_GAPS[3].skill}」分別有 ${SKILL_GAPS[0].mentions} 與 ${SKILL_GAPS[3].mentions} 次提及，集中於就業前學生。`,
      proposedActions: [
        "於高教平台補助製作「履歷敘事」開放課程",
        "與職涯中心合辦每月作品集 review 工作坊",
      ],
    },
    {
      title: "分流創業諮詢資源至想法期使用者",
      rationale: `想法期創業使用者（${STARTUP_NEEDS[0].users} 人）顯著多於後期，現有貸款資源主要落於籌備期之後。`,
      proposedActions: [
        "新增想法期專屬諮詢額度",
        "建立 Lean Canvas + 客戶訪談線上輔導",
      ],
    },
    {
      title: `回應高頻焦慮：${TOP_QUESTIONS[0].question}`,
      rationale: `此問題出現 ${TOP_QUESTIONS[0].count} 次，多伴隨「${TOP_QUESTIONS[0].urgency}」緊急度標記。`,
      proposedActions: ["強化媒合實習資訊揭露", "推廣同儕互助社群作為情緒支持入口"],
    },
  ];

  return NextResponse.json({ focusArea: focus, suggestions });
});
