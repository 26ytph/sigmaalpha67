// =====================================================================
// FAKE DATA — pre-aggregated dashboard metrics for the policy/admin view.
// Replace with real aggregation queries (warehouse / analytics pipeline).
// =====================================================================

// Mock data shaped to match Module J ("政策端儀表板") spec in 開發文件.md.
// Replace with real warehouse aggregations when ready (or seed Supabase tables;
// see backend/README.md > "Policy dashboard tables").

export const TOP_QUESTIONS = [
  { question: "文組轉職資料分析該怎麼開始？", count: 168, urgency: "中高" },
  { question: "履歷沒方向、不知道從哪寫起", count: 142, urgency: "中" },
  { question: "實習準備需要哪些技能？", count: 119, urgency: "中" },
  { question: "我科系跟想做的工作不一樣，怎麼辦？", count: 98, urgency: "中高" },
  { question: "我想創業但不知道怎麼開始", count: 71, urgency: "中" },
];

export const TOP_CAREER_PATHS = [
  { tag: "ux", label: "UX Research", interestedUsers: 312 },
  { tag: "marketing", label: "行銷企劃", interestedUsers: 287 },
  { tag: "data", label: "資料分析助理", interestedUsers: 240 },
  { tag: "design", label: "視覺 / 平面設計", interestedUsers: 188 },
  { tag: "product", label: "產品企劃", interestedUsers: 142 },
];

export const SKILL_GAPS = [
  { skill: "作品集敘事", mentions: 211 },
  { skill: "SQL 基本查詢", mentions: 178 },
  { skill: "履歷表達 (STAR)", mentions: 165 },
  { skill: "Excel 資料整理", mentions: 132 },
  { skill: "簡報與表達", mentions: 121 },
];

export const STUCK_TASKS = [
  { taskKey: "w1.t0", title: "整理作品集", stuckUsers: 96 },
  { taskKey: "w2.t1", title: "撰寫履歷", stuckUsers: 81 },
  { taskKey: "w2.t2", title: "錄製 1 分鐘自我介紹", stuckUsers: 58 },
  { taskKey: "w3.t1", title: "訪 3 位真實使用者", stuckUsers: 47 },
];

export const STARTUP_NEEDS = [
  { stage: "資金（青創貸款）", users: 124 },
  { stage: "補助申請輔導", users: 96 },
  { stage: "共享空間 / 場地", users: 58 },
  { stage: "商業模式驗證", users: 41 },
];
