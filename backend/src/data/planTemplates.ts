// =====================================================================
// FAKE DATA — plan templates per top-tag.
// Replace with curated content or LLM-generated personalised plans.
// Mirrors `lib/logic/generate_plan.dart`.
// =====================================================================

import type { PlanWeek } from "@/types/plan";

type TemplateKey = "design" | "data" | "engineering" | "product" | "marketing" | "research" | "startup" | "default";

export const PLAN_HEADLINES: Record<TemplateKey, string> = {
  design: "做出好用的體驗：研究、流程與介面設計",
  data: "用數據說話：從清資料到產出可行動洞察",
  engineering: "把想法變成產品：從第一次 commit 到上線",
  product: "從問題到產品：學會優先序與決策",
  marketing: "讓對的人看到對的訊息：內容、活動、成效",
  research: "把使用者搞懂：訪談、觀察、整理 insight",
  startup: "驗證你的想法：從 idea 到 MVP",
  default: "自我盤點與第一步：先動起來再說",
};

export const PLAN_TEMPLATES: Record<TemplateKey, PlanWeek[]> = {
  design: [
    {
      week: 1,
      title: "自我盤點與目標定義",
      goals: ["盤點過去做過的設計或創意作品", "鎖定 1–2 個想專注的設計領域"],
      resources: ["《Don't Make Me Think》第 1–3 章", "Figma 入門 30 分鐘教學"],
      outputs: ["一份目標說明 + 想學什麼的清單"],
    },
    {
      week: 2,
      title: "工具熟悉",
      goals: ["跑完一個 Figma 教學專案", "建立自己的元件庫雛形"],
      resources: ["Figma 官方 community 範例", "Material 3 spec"],
      outputs: ["1 個簡易作品（登入畫面 / Dashboard）"],
    },
    {
      week: 3,
      title: "做一個小作品",
      goals: ["挑一個你會用的 app，重設計其中一頁", "寫下設計決策"],
      resources: ["Awwwards / Mobbin 參考"],
      outputs: ["重設計頁面 + 200 字設計說明"],
    },
    {
      week: 4,
      title: "整理作品集",
      goals: ["把作品放上 Notion / Behance", "錄一段 60 秒解說影片"],
      resources: ["作品集範本"],
      outputs: ["可分享的作品集連結"],
    },
  ],
  data: [
    {
      week: 1,
      title: "找一份你感興趣的資料",
      goals: ["從 Kaggle 或政府開放資料挑一份", "用 Excel/Sheets 看 10 分鐘"],
      resources: ["Kaggle Datasets", "政府資料開放平臺"],
      outputs: ["1 份你想分析的資料 + 3 個假設"],
    },
    {
      week: 2,
      title: "SQL 基本功",
      goals: ["完成 SQLBolt 1–10 課", "能用 SELECT / JOIN / GROUP BY"],
      resources: ["SQLBolt", "Mode SQL Tutorial"],
      outputs: ["10 題 SQL 練習成果"],
    },
    {
      week: 3,
      title: "做一個小型分析",
      goals: ["回答你第 1 週寫下的 3 個假設"],
      resources: ["Pandas 入門 (datacamp)"],
      outputs: ["1 份 1 頁的分析報告"],
    },
    {
      week: 4,
      title: "把它說給人聽",
      goals: ["用 5 張投影片講你的發現", "找 1 位朋友 review"],
      resources: ["Storytelling with Data 摘要"],
      outputs: ["投影片 + 一段 3 分鐘錄音"],
    },
  ],
  engineering: [
    {
      week: 1,
      title: "決定一個語言、做出 Hello World",
      goals: ["挑 1 個語言（建議 JS/Python）", "完成基本語法教學"],
      resources: ["MDN / freeCodeCamp"],
      outputs: ["GitHub 上 1 個 repo"],
    },
    {
      week: 2,
      title: "做一個能跑的小 CLI / 網頁",
      goals: ["實作一個會用到 API 的小工具"],
      resources: ["Public APIs list"],
      outputs: ["可 demo 的 repo + README"],
    },
    {
      week: 3,
      title: "讀別人的 code",
      goals: ["挑一個小型 OSS，讀 README + 1 個 issue"],
      resources: ["good-first-issue"],
      outputs: ["1 篇心得 / 1 個 PR"],
    },
    {
      week: 4,
      title: "面試準備啟動",
      goals: ["寫 5 題 LeetCode Easy", "準備 STAR 自介"],
      resources: ["NeetCode 150"],
      outputs: ["可以講 3 分鐘的自我介紹"],
    },
  ],
  product: [
    {
      week: 1,
      title: "選一個產品仔細用",
      goals: ["挑 1 個你常用的 app，記錄 5 個體驗問題"],
      resources: ["Lenny's Newsletter 入門幾篇"],
      outputs: ["問題清單 + 排序"],
    },
    {
      week: 2,
      title: "寫第一份 PRD",
      goals: ["針對其中 1 個問題，寫一份單頁 PRD"],
      resources: ["Marty Cagan《INSPIRED》摘要"],
      outputs: ["1 份 PRD"],
    },
    {
      week: 3,
      title: "做使用者訪談",
      goals: ["訪 3 位真實使用者", "整理 5 個 insight"],
      resources: ["The Mom Test 摘要"],
      outputs: ["訪談筆記 + insight 清單"],
    },
    {
      week: 4,
      title: "提案演練",
      goals: ["用 5 分鐘把 PRD 講給 2 個人聽"],
      resources: [],
      outputs: ["錄影 + 1 段反思"],
    },
  ],
  marketing: [
    {
      week: 1,
      title: "理解一個你欣賞的品牌",
      goals: ["挑 1 個品牌，拆解他們的 IG / 官網訊息結構"],
      resources: ["《Building a StoryBrand》摘要"],
      outputs: ["1 份品牌拆解 + 3 個學到的點"],
    },
    {
      week: 2,
      title: "寫 5 篇貼文",
      goals: ["設定一個主題，寫 5 篇 100–200 字貼文"],
      resources: ["Copywriting swipe files"],
      outputs: ["5 篇貼文"],
    },
    {
      week: 3,
      title: "投一個小廣告",
      goals: ["用 Meta 廣告 100–300 元跑一次測試"],
      resources: ["Meta Blueprint 入門課"],
      outputs: ["1 份廣告成效報告"],
    },
    {
      week: 4,
      title: "整理成案例",
      goals: ["把整個月做成 1 份 Case Study"],
      resources: [],
      outputs: ["1 份 Case Study (Notion / PDF)"],
    },
  ],
  research: [
    {
      week: 1,
      title: "選定研究題目",
      goals: ["寫下 1 個你想搞懂的人群與情境"],
      resources: ["The Mom Test 第 1–3 章"],
      outputs: ["題目 + 5 個假設"],
    },
    {
      week: 2,
      title: "訪 5 個人",
      goals: ["設計訪綱", "完成 5 場 30 分訪談"],
      resources: [],
      outputs: ["5 份訪談逐字稿摘要"],
    },
    {
      week: 3,
      title: "找模式",
      goals: ["做 affinity map，整理出 3 個 insight"],
      resources: ["Miro 範本"],
      outputs: ["1 張 insight 圖"],
    },
    {
      week: 4,
      title: "輸出報告",
      goals: ["寫 1 份 1 頁 Research Brief"],
      resources: [],
      outputs: ["可分享的 brief"],
    },
  ],
  startup: [
    {
      week: 1,
      title: "把點子寫清楚",
      goals: ["用 1 句話描述你的想法", "列出 3 個假設與最危險的假設"],
      resources: ["Lean Canvas 模板"],
      outputs: ["1 份 Lean Canvas"],
    },
    {
      week: 2,
      title: "找潛在使用者聊",
      goals: ["訪 5 位目標客群（不要先 pitch）"],
      resources: ["The Mom Test"],
      outputs: ["5 份訪談筆記"],
    },
    {
      week: 3,
      title: "做最小可驗證版本",
      goals: ["用最簡單方式驗證需求（landing page / 表單 / 預購）"],
      resources: ["Carrd / Tally"],
      outputs: ["1 個可分享連結"],
    },
    {
      week: 4,
      title: "看數字決定下一步",
      goals: ["評估 pivot / persevere / kill"],
      resources: [],
      outputs: ["1 頁決策備忘錄"],
    },
  ],
  default: [
    {
      week: 1,
      title: "自我盤點",
      goals: ["列出 5 件你做過覺得有成就感的事", "寫下 3 個你想避免的工作型態"],
      resources: ["MBTI / 興趣量表（參考用）"],
      outputs: ["1 頁自我盤點筆記"],
    },
    {
      week: 2,
      title: "找方向：聊 3 個人",
      goals: ["和 3 位不同領域工作者各聊 30 分"],
      resources: [],
      outputs: ["3 份簡短筆記 + 第一個感興趣的方向"],
    },
    {
      week: 3,
      title: "做一個小嘗試",
      goals: ["用 1 個週末做一個和方向相關的小作品"],
      resources: [],
      outputs: ["可以給人看的小成果"],
    },
    {
      week: 4,
      title: "整理與決定",
      goals: ["回顧前三週，挑 1 條路再深入 4 週"],
      resources: [],
      outputs: ["下一輪 4 週計畫"],
    },
  ],
};

export function pickPlanKey(topTag: string | null): TemplateKey {
  if (!topTag) return "default";
  const k = topTag.toLowerCase();
  if (k in PLAN_TEMPLATES) return k as TemplateKey;
  return "default";
}
