// Server-side fetcher for the admin/policy dashboard.
// Tries Supabase first; per-table falls back to the in-memory mock if the
// table is missing, empty, or unreachable.
//
// Supabase tables (snake_case columns):
//   dashboard_top_questions   (question text, count int, urgency text)
//   dashboard_career_paths    (tag text, label text, interested_users int)
//   dashboard_skill_gaps      (skill text, mentions int)
//   dashboard_stuck_tasks     (task_key text, title text, stuck_users int)
//   dashboard_startup_needs   (stage text, users int)
// See backend/README.md for the SQL DDL + seed.

import {
  SKILL_GAPS,
  STARTUP_NEEDS,
  STUCK_TASKS,
  TOP_CAREER_PATHS,
  TOP_QUESTIONS,
} from "@/data/adminMetrics";
import { getSupabaseAdmin } from "./supabase";

export type TopQuestion = { question: string; count: number; urgency: string };
export type CareerPathStat = {
  tag: string;
  label: string;
  interestedUsers: number;
};
export type SkillGap = { skill: string; mentions: number };
export type StuckTask = { taskKey: string; title: string; stuckUsers: number };
export type StartupNeed = { stage: string; users: number };
export type PolicySuggestion = {
  title: string;
  rationale: string;
  proposedActions: string[];
};

export type DashboardSource = "supabase" | "mock";

export type TrendPoint = { day: string; value: number };
export type Trends = {
  questions: TrendPoint[];
  interest: TrendPoint[];
  startup: TrendPoint[];
};

export type RegionStat = {
  code: string;
  label: string;
  users: number;
  topNeed: string;
  // Real geographic coordinates — projected to the GeoJSON viewBox at render time.
  lon: number;
  lat: number;
};

export type ActivityEvent = {
  ts: string; // human-friendly relative time
  type: "question" | "swipe" | "todo" | "startup" | "handoff";
  region: string;
  text: string;
  tag?: string;
};

export type ImpactForecast = {
  beneficiaries: number;     // 預估受惠人數
  budgetTwd: number;         // 預估預算（新台幣）
  timelineMonths: number;    // 推行期程（月）
  confidence: number;        // 0..1
  stakeholders: string[];    // 對接單位
};

export type RadarDimension = {
  axis: string;
  demand: number; // 0..100 normalized
  supply: number; // 0..100 normalized
};

export type DashboardSnapshot = {
  topQuestions: TopQuestion[];
  careerPaths: CareerPathStat[];
  skillGaps: SkillGap[];
  stuckTasks: StuckTask[];
  startupNeeds: StartupNeed[];
  suggestions: PolicySuggestion[];
  trends: Trends;
  regions: RegionStat[];
  activity: ActivityEvent[];
  forecasts: ImpactForecast[];
  radar: RadarDimension[];
  sources: Record<string, DashboardSource>;
  fetchedAt: string;
};

async function tryTable<TRow, TOut>(
  table: string,
  orderBy: string,
  ascending: boolean,
  map: (row: TRow) => TOut,
  fallback: TOut[],
): Promise<{ rows: TOut[]; source: DashboardSource }> {
  const supa = getSupabaseAdmin();
  if (!supa) return { rows: fallback, source: "mock" };
  try {
    const { data, error } = await supa
      .from(table)
      .select("*")
      .order(orderBy, { ascending })
      .limit(50);
    if (error || !data || data.length === 0) {
      return { rows: fallback, source: "mock" };
    }
    return { rows: (data as TRow[]).map(map), source: "supabase" };
  } catch {
    return { rows: fallback, source: "mock" };
  }
}

export async function loadDashboardSnapshot(): Promise<DashboardSnapshot> {
  const [tq, cp, sg, st, sn] = await Promise.all([
    tryTable<{ question: string; count: number; urgency: string }, TopQuestion>(
      "dashboard_top_questions",
      "count",
      false,
      (r) => ({ question: r.question, count: r.count, urgency: r.urgency }),
      TOP_QUESTIONS as TopQuestion[],
    ),
    tryTable<
      { tag: string; label: string; interested_users: number },
      CareerPathStat
    >(
      "dashboard_career_paths",
      "interested_users",
      false,
      (r) => ({
        tag: r.tag,
        label: r.label,
        interestedUsers: r.interested_users,
      }),
      TOP_CAREER_PATHS as CareerPathStat[],
    ),
    tryTable<{ skill: string; mentions: number }, SkillGap>(
      "dashboard_skill_gaps",
      "mentions",
      false,
      (r) => ({ skill: r.skill, mentions: r.mentions }),
      SKILL_GAPS as SkillGap[],
    ),
    tryTable<
      { task_key: string; title: string; stuck_users: number },
      StuckTask
    >(
      "dashboard_stuck_tasks",
      "stuck_users",
      false,
      (r) => ({
        taskKey: r.task_key,
        title: r.title,
        stuckUsers: r.stuck_users,
      }),
      STUCK_TASKS as StuckTask[],
    ),
    tryTable<{ stage: string; users: number }, StartupNeed>(
      "dashboard_startup_needs",
      "users",
      false,
      (r) => ({ stage: r.stage, users: r.users }),
      STARTUP_NEEDS as StartupNeed[],
    ),
  ]);

  const suggestions: PolicySuggestion[] = buildSuggestions({
    skillGaps: sg.rows,
    startupNeeds: sn.rows,
    topQuestions: tq.rows,
  });

  return {
    topQuestions: tq.rows,
    careerPaths: cp.rows,
    skillGaps: sg.rows,
    stuckTasks: st.rows,
    startupNeeds: sn.rows,
    suggestions,
    trends: buildTrends(),
    regions: REGIONS,
    activity: buildActivity(),
    forecasts: buildForecasts(suggestions),
    radar: RADAR,
    sources: {
      topQuestions: tq.source,
      careerPaths: cp.source,
      skillGaps: sg.source,
      stuckTasks: st.source,
      startupNeeds: sn.source,
      suggestions: "mock", // computed locally — counts as derived
    },
    fetchedAt: new Date().toISOString(),
  };
}

// ───────── Regions: 直轄市 + 重點縣市 ─────────
// 真實經緯度（lon, lat），由 TaiwanMap 用 GeoJSON 同一個投影轉換成 viewBox 座標。
// 經緯度查自 OpenStreetMap 縣市中心點。
const REGIONS: RegionStat[] = [
  { code: "TPE", label: "臺北市", users: 1450, topNeed: "履歷健檢", lon: 121.55, lat: 25.04 },
  { code: "NTC", label: "新北市", users: 2120, topNeed: "資料分析", lon: 121.46, lat: 24.99 },
  { code: "TYC", label: "桃園市", users: 1180, topNeed: "實習媒合", lon: 121.31, lat: 24.99 },
  { code: "HSZ", label: "新竹",   users: 540,  topNeed: "工程職涯", lon: 120.97, lat: 24.81 },
  { code: "TCG", label: "臺中市", users: 1320, topNeed: "創業諮詢", lon: 120.68, lat: 24.16 },
  { code: "CYI", label: "嘉義",   users: 280,  topNeed: "農業創新", lon: 120.45, lat: 23.48 },
  { code: "TNN", label: "臺南市", users: 720,  topNeed: "文創行銷", lon: 120.21, lat: 22.99 },
  { code: "KHH", label: "高雄市", users: 980,  topNeed: "創業資金", lon: 120.31, lat: 22.62 },
  { code: "HUA", label: "花東",   users: 220,  topNeed: "遠距資源", lon: 121.61, lat: 23.97 },
];

// ───────── Activity Feed ─────────
function buildActivity(): ActivityEvent[] {
  return [
    { ts: "剛剛",     type: "question", region: "臺北市", text: "大三．「文組想轉資料分析該怎麼開始？」", tag: "高頻" },
    { ts: "1 分鐘前", type: "swipe",    region: "臺中市", text: "大二．❤ UX Research、❤ 行銷企劃",       tag: "熱門職涯" },
    { ts: "3 分鐘前", type: "todo",     region: "新北市", text: "完成 To-do：「整理作品集」",              tag: "里程碑" },
    { ts: "5 分鐘前", type: "startup",  region: "高雄市", text: "申請創業諮詢：「想開寵物友善咖啡廳」",   tag: "創業" },
    { ts: "8 分鐘前", type: "handoff",  region: "桃園市", text: "AI 信心 0.21 → 轉交諮詢師接手",          tag: "需介入" },
    { ts: "12 分鐘前",type: "question", region: "臺南市", text: "大四．「履歷沒方向、不知道從哪寫起」",   tag: "高頻" },
    { ts: "18 分鐘前",type: "swipe",    region: "新竹",   text: "研一．❤ 軟體工程、❤ 產品企劃",          tag: "熱門職涯" },
    { ts: "25 分鐘前",type: "startup",  region: "臺中市", text: "申請場地：青創共享空間預約",              tag: "場地" },
  ];
}

// ───────── Impact Forecast (per top suggestion) ─────────
function buildForecasts(suggestions: PolicySuggestion[]): ImpactForecast[] {
  // Stable mock forecasts indexed against the first 3 suggestions.
  const presets: ImpactForecast[] = [
    {
      beneficiaries: 1840,
      budgetTwd: 3_200_000,
      timelineMonths: 3,
      confidence: 0.82,
      stakeholders: ["臺北青年職涯發展中心", "高教平台", "校園職涯中心"],
    },
    {
      beneficiaries: 2160,
      budgetTwd: 4_500_000,
      timelineMonths: 4,
      confidence: 0.74,
      stakeholders: ["經濟部數位部", "民間培訓機構", "104 / Cake"],
    },
    {
      beneficiaries: 980,
      budgetTwd: 2_100_000,
      timelineMonths: 2,
      confidence: 0.78,
      stakeholders: ["創業臺北", "青創基地", "金融機構"],
    },
  ];
  return suggestions.slice(0, presets.length).map((_, i) => presets[i]);
}

// ───────── Radar: 資源缺口（demand vs supply）─────────
const RADAR: RadarDimension[] = [
  { axis: "補助金額",       demand: 88, supply: 52 },
  { axis: "課程供給",       demand: 76, supply: 64 },
  { axis: "1 對 1 諮詢",    demand: 92, supply: 38 },
  { axis: "共享空間",       demand: 58, supply: 70 },
  { axis: "線上資源",       demand: 70, supply: 80 },
  { axis: "媒合機會",       demand: 84, supply: 46 },
];

// 7-day trend mock — slight upward drift with daily wiggle so the sparkline
// shows movement. Replace with real `select count(*) from ... group by day`.
function buildTrends(): Trends {
  const today = new Date();
  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(today);
    d.setDate(d.getDate() - (6 - i));
    return `${d.getMonth() + 1}/${d.getDate()}`;
  });
  const seedSeries = (base: number, amp: number, drift: number) =>
    days.map((day, i) => ({
      day,
      value: Math.round(
        base + drift * i + amp * Math.sin((i + 1) * 1.3) + amp * 0.3,
      ),
    }));
  return {
    questions: seedSeries(58, 12, 4),
    interest: seedSeries(140, 22, 8),
    startup: seedSeries(26, 6, 2),
  };
}

function buildSuggestions(opts: {
  skillGaps: SkillGap[];
  startupNeeds: StartupNeed[];
  topQuestions: TopQuestion[];
}): PolicySuggestion[] {
  const sg = opts.skillGaps;
  const sn = opts.startupNeeds;
  const tq = opts.topQuestions;
  const out: PolicySuggestion[] = [];

  if (sg.length >= 1) {
    out.push({
      title: "開設「文組技能轉譯」工作坊",
      rationale: `高頻問題第一名「${tq[0]?.question ?? "文組轉職"}」出現 ${tq[0]?.count ?? 0} 次，配合技能缺口 Top 1「${sg[0].skill}」（${sg[0].mentions} 次提及），顯示文組學生在「把生活經驗翻譯成職場語言」這一段卡得最深。`,
      proposedActions: [
        "與青年職涯發展中心合辦每月「履歷敘事」開放課程",
        "在校園駐點推出 1 對 1 履歷健檢時段",
        "把 STAR 結構化教材納入職涯通識選修",
      ],
    });
  }

  if (sg.length >= 2) {
    out.push({
      title: "推出「跨域資料分析入門」公開課",
      rationale: `技能缺口包含「${sg[1].skill}」（${sg[1].mentions} 次）、「Excel 資料整理」等，且熱門職涯方向「資料分析助理」位居 Top 3，顯示跨域轉資料職務的供需缺口持續擴大。`,
      proposedActions: [
        "與民間機構合作補助 SQL / Excel 入門線上課",
        "建立「文組 → 資料分析助理」3 個月轉職地圖",
        "媒合在職資料分析師擔任線上導師",
      ],
    });
  }

  if (sn.length >= 1) {
    out.push({
      title: "分流創業諮詢資源至「想法期」使用者",
      rationale: `創業需求第一大宗為「${sn[0].stage}」（${sn[0].users} 人），明顯落在創業早期；現有青創貸款資源多落於籌備期之後，存在資源錯位。`,
      proposedActions: [
        "新增想法期專屬「Lean Canvas + 客戶訪談」線上輔導",
        "與青創基地合作開放共享場地預約",
        "把補助文件範本與案例庫公開化以降低資訊不對稱",
      ],
    });
  }

  return out;
}
