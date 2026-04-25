// =====================================================================
// FAKE DATA — pre-aggregated dashboard metrics for the policy/admin view.
// Replace with real aggregation queries (warehouse / analytics pipeline).
// =====================================================================

export const TOP_QUESTIONS = [
  { question: "我畢業是不是很難找到好工作？", count: 142, urgency: "中高" },
  { question: "我科系沒辦法做想做的工作怎麼辦？", count: 98, urgency: "中" },
  { question: "履歷該怎麼寫才有人看？", count: 87, urgency: "中" },
  { question: "面試一直被刷掉是什麼原因？", count: 64, urgency: "中高" },
  { question: "我想創業但不知道怎麼開始", count: 55, urgency: "中" },
];

export const TOP_CAREER_PATHS = [
  { tag: "design", label: "設計 / UX", interestedUsers: 312 },
  { tag: "engineering", label: "軟體工程", interestedUsers: 287 },
  { tag: "data", label: "資料分析", interestedUsers: 220 },
  { tag: "marketing", label: "行銷企劃", interestedUsers: 188 },
  { tag: "product", label: "產品管理", interestedUsers: 142 },
];

export const SKILL_GAPS = [
  { skill: "作品集敘事", mentions: 198 },
  { skill: "SQL 基本查詢", mentions: 174 },
  { skill: "結構化面試回答 (STAR)", mentions: 165 },
  { skill: "原型製作 (Figma)", mentions: 132 },
  { skill: "簡報與表達", mentions: 121 },
];

export const STUCK_TASKS = [
  { taskKey: "w1.t0", title: "盤點過去做過的設計或創意作品", stuckUsers: 88 },
  { taskKey: "w2.t0", title: "完成一個 Figma 教學專案", stuckUsers: 64 },
  { taskKey: "w3.t1", title: "訪 3 位真實使用者", stuckUsers: 52 },
];

export const STARTUP_NEEDS = [
  { stage: "想法期", users: 124 },
  { stage: "驗證期", users: 78 },
  { stage: "籌備期", users: 41 },
  { stage: "營運初期", users: 19 },
];
