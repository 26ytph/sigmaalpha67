import 'dart:math' as math;

import '../data/roles.dart';
import '../data/startup_skills.dart';
import '../models/models.dart';

class PlanWeek {
  const PlanWeek({
    required this.week,
    required this.title,
    required this.goals,
    required this.resources,
    required this.outputs,
  });

  final int week;
  final String title;
  final List<String> goals;
  final List<String> resources;
  final List<String> outputs;
}

class TagScore {
  const TagScore({required this.tag, required this.score});

  final RoleTag tag;
  final int score;
}

/// 推薦課程／證照（同一筆可橫跨多週）
class RecommendedCourse {
  const RecommendedCourse({
    required this.id,
    required this.title,
    required this.provider,
    required this.type, // '課程' | '證照'
    required this.weeks,
    required this.detail,
  });

  final String id;
  final String title;
  final String provider;
  final String type;
  final List<int> weeks;
  final String detail;

  bool spansWeek(int w) => weeks.contains(w);
}

class GeneratedPlan {
  const GeneratedPlan({
    required this.basedOnLikedRoleIds,
    required this.basedOnTopTags,
    required this.recommendedRoles,
    required this.headline,
    required this.weeks,
    required this.courses,
  });

  final List<RoleId> basedOnLikedRoleIds;
  final List<TagScore> basedOnTopTags;
  final List<CareerRole> recommendedRoles;
  final String headline;
  final List<PlanWeek> weeks;
  final List<RecommendedCourse> courses;
}

List<TagScore> topTagsFromRoleIds(List<RoleId> roleIds) {
  final counts = <RoleTag, int>{};
  for (final id in roleIds) {
    CareerRole? role;
    for (final r in roles) {
      if (r.id == id) {
        role = r;
        break;
      }
    }
    if (role == null) continue;
    for (final t in role.tags) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
  }
  final list = counts.entries.map((e) => TagScore(tag: e.key, score: e.value)).toList();
  list.sort((a, b) => b.score.compareTo(a.score));
  return list;
}

String pickHeadline(RoleTag? top) {
  switch (top) {
    case RoleTag.engineering:
      return '把想法做成作品：從基礎到可展示的專案';
    case RoleTag.data:
      return '用數據說話：從 SQL 到可重現的分析作品';
    case RoleTag.product:
      return '把問題變成產品：需求、規劃到驗收的全流程';
    case RoleTag.design:
      return '做出好用的體驗：研究、流程與介面設計';
    case RoleTag.marketing:
      return '讓成效可追蹤：內容、投放與轉換優化';
    case RoleTag.sales:
      return '用價值換合作：提案、談判與商機管理';
    case RoleTag.people:
      return '打造團隊與制度：招募、培訓與員工體驗';
    case RoleTag.finance:
      return '用制度守住現金流：報表、稅務與內控';
    case RoleTag.security:
      return '先把基本功打穩：觀測、弱點與事件應變';
    case null:
      return '先做出方向感：用 4–8 週找到你的下一步';
  }
}

List<PlanWeek> baseWeeks(RoleTag? top) {
  const common = <PlanWeek>[
    PlanWeek(
      week: 1,
      title: '自我盤點與目標定義',
      goals: ['列出你喜歡的職位與原因', '選一個可驗證的短期目標（2 週內）', '設定每天 30–60 分鐘固定時段'],
      resources: ['用一頁紙寫下：我想做什麼／為什麼／怎麼判斷做到了'],
      outputs: ['一頁目標定義（含衡量指標）', '每週固定學習時段表'],
    ),
    PlanWeek(
      week: 2,
      title: '基礎技能補齊（最小集合）',
      goals: ['選 1–2 個核心技能先打底', '開始做可交付的小練習', '建立作品/筆記的存放位置'],
      resources: ['挑一門入門課（免費/付費皆可）', '把筆記改成可分享的文章或 repo'],
      outputs: ['2–3 個小練習（可展示）', '作品集/筆記的目錄結構'],
    ),
  ];

  const track = <RoleTag, List<PlanWeek>>{
    RoleTag.engineering: [
      PlanWeek(
        week: 3,
        title: '語言與 Web 基礎（以作品為導向）',
        goals: ['熟悉 TypeScript 基本語法', '理解 API/HTTP 與 JSON', '用 Git 管理版本'],
        resources: ['TypeScript handbook（挑 5–8 章）', '做一個最小 CRUD 小專案（可用假資料）'],
        outputs: ['一個可跑的 CRUD demo（含 README）', '3 篇學習筆記（短也可以）'],
      ),
      PlanWeek(
        week: 4,
        title: '前端/後端擇一深挖 + 測試觀念',
        goals: ['選擇前端或後端主線', '學會拆分元件/模組', '補上基本測試/型別保障'],
        resources: ['React/Next.js 或 Node/DB 入門資源', '把功能拆成 5–8 個小任務'],
        outputs: ['一個可部署的作品（Vercel/Render）', '一份功能拆解清單'],
      ),
      PlanWeek(
        week: 5,
        title: '作品精修（可被面試問）',
        goals: ['加上真實情境（登入/權限/錯誤處理）', '改善 UX（空狀態/Loading）', '補上簡單監控/日誌'],
        resources: ['寫一份『設計決策』文件（why not what）'],
        outputs: ['作品 v1（可 demo）', '設計決策文件（1–2 頁）'],
      ),
      PlanWeek(
        week: 6,
        title: '面試題與履歷素材整理',
        goals: ['整理常見題：資料結構/網路/系統設計（基礎）', '把作品寫成履歷 bullet', '練 1 次 mock interview'],
        resources: ['STAR/情境題模板', '把你做的 trade-off 寫清楚'],
        outputs: ['履歷版作品描述 5–8 行', '1 份自我介紹與作品講解稿'],
      ),
    ],
    RoleTag.data: [
      PlanWeek(
        week: 3,
        title: 'SQL + 指標思維',
        goals: ['熟悉 SELECT/JOIN/GROUP BY', '定義 3 個你關心的指標', '把分析問題拆成假設'],
        resources: ['找一份公開資料或假資料表', '用 SQL 寫出 8–12 個問題的答案'],
        outputs: ['SQL 查詢集（含註解）', '指標定義文件（1 頁）'],
      ),
      PlanWeek(
        week: 4,
        title: '視覺化與故事（Dashboard / 報告）',
        goals: ['把指標做成一頁 Dashboard', '練習『結論先行』', '確保可重現（資料/步驟）'],
        resources: ['Looker Studio / Power BI / Tableau 任選其一', '寫一份 6–10 張投影片的分析報告'],
        outputs: ['Dashboard 連結或截圖', '分析簡報（PDF）'],
      ),
      PlanWeek(
        week: 5,
        title: 'Python（可選）+ 自動化',
        goals: ['用 pandas 做資料清理', '把重複工作寫成 notebook/script', '把分析流程模板化'],
        resources: ['pandas 常用操作：merge/groupby/plot', '建立一個可重跑的 notebook'],
        outputs: ['Notebook（可重現）', '清理後資料集（或產生腳本）'],
      ),
      PlanWeek(
        week: 6,
        title: '作品集與面試練習',
        goals: ['整理 2 個完整案例', '練習講清楚假設與限制', '把成果轉成履歷 bullet'],
        resources: ['每個案例都回答：問題→方法→結果→影響→限制'],
        outputs: ['作品集頁面/README', '履歷版案例描述 6–10 行'],
      ),
    ],
    RoleTag.product: [
      PlanWeek(
        week: 3,
        title: '問題定義與需求拆解',
        goals: ['選一個生活中的痛點', '寫出 3 個 persona', '把需求拆成 user stories'],
        resources: ['JTBD / 5 Whys', '建立一份 PRD（精簡版）'],
        outputs: ['精簡 PRD（1–2 頁）', 'User stories 清單（10–20 條）'],
      ),
      PlanWeek(
        week: 4,
        title: '原型與驗證',
        goals: ['做可點擊原型', '找 3–5 位使用者測試', '把回饋轉成改版清單'],
        resources: ['Figma 原型', '簡單訪談大綱'],
        outputs: ['原型連結', '測試紀錄與優先級清單'],
      ),
      PlanWeek(
        week: 5,
        title: '規劃與協作（模擬 Sprint）',
        goals: ['排出 2 週 sprint 任務', '寫驗收標準', '思考 edge cases 與風險'],
        resources: ['用看板工具管理（Trello/Notion）'],
        outputs: ['Sprint 看板截圖', '驗收標準清單'],
      ),
      PlanWeek(
        week: 6,
        title: '指標與迭代',
        goals: ['定義北極星指標', '設計 1 個 A/B 測試想法', '寫一份迭代提案'],
        resources: ['事件追蹤/漏斗概念'],
        outputs: ['指標與追蹤方案（1 頁）', '迭代提案（1 頁）'],
      ),
    ],
    RoleTag.design: [
      PlanWeek(
        week: 3,
        title: '使用者研究與流程',
        goals: ['選一個產品場景', '做 3 次快速訪談', '畫出 user flow'],
        resources: ['訪談問題模板', '用 FigJam 畫流程'],
        outputs: ['訪談摘要', 'User flow 圖'],
      ),
      PlanWeek(
        week: 4,
        title: '介面設計與互動細節',
        goals: ['做 2–3 個關鍵頁面', '定義狀態（空/載入/錯誤）', '補上互動規範'],
        resources: ['找 1 套設計系統參考（Material/Apple）'],
        outputs: ['高保真稿', '交付規範（簡要）'],
      ),
      PlanWeek(
        week: 5,
        title: '可用性測試與迭代',
        goals: ['做 3 次可用性測試', '整理問題嚴重度', '做一次改版'],
        resources: ['可用性測試任務腳本'],
        outputs: ['測試紀錄', '改版前後對照'],
      ),
      PlanWeek(
        week: 6,
        title: '作品集敘事',
        goals: ['把案例寫成故事', '說清楚取捨與影響', '整理成可發佈的版面'],
        resources: ['案例結構：背景→目標→過程→結果→反思'],
        outputs: ['作品集案例頁', '簡報版案例（可選）'],
      ),
    ],
    RoleTag.marketing: [
      PlanWeek(
        week: 3,
        title: '受眾與內容策略',
        goals: ['定義受眾與主張', '建立內容欄位', '制定 2 週內容表'],
        resources: ['內容矩陣：受眾×情境×格式'],
        outputs: ['內容策略一頁紙', '2 週內容排程'],
      ),
      PlanWeek(
        week: 4,
        title: '投放與追蹤',
        goals: ['設定轉換目標', '建立追蹤事件', '設計 2 組素材做 A/B'],
        resources: ['UTM/漏斗追蹤基本概念'],
        outputs: ['投放計畫（預算/受眾/素材）', '成效報告模板'],
      ),
      PlanWeek(
        week: 5,
        title: '優化與復盤',
        goals: ['讀懂 CPA/ROAS/CTR', '找出瓶頸', '提出 3 個優化假設'],
        resources: ['用一頁紙做 Growth loop'],
        outputs: ['復盤報告（1 頁）', '優化待辦清單'],
      ),
      PlanWeek(
        week: 6,
        title: '作品集與可量化成果',
        goals: ['整理 1–2 個案例', '把成果寫成可量化指標', '準備 1 分鐘 pitch'],
        resources: ['成果寫法：基準→行動→結果→學到什麼'],
        outputs: ['案例頁/簡報', 'pitch 講稿'],
      ),
    ],
    RoleTag.sales: [
      PlanWeek(
        week: 3,
        title: '客戶與價值主張',
        goals: ['選一個產業', '寫出 3 個客戶痛點', '定義你的價值主張'],
        resources: ['Value proposition canvas'],
        outputs: ['價值主張一頁紙', '目標客戶清單（20 家）'],
      ),
      PlanWeek(
        week: 4,
        title: '開發與對話腳本',
        goals: ['寫 2 套開發訊息', '練 1 套提問流程', '整理 objection 回應'],
        resources: ['SPIN selling 基本結構'],
        outputs: ['對話腳本', '常見 objection 回覆表'],
      ),
      PlanWeek(
        week: 5,
        title: '提案與成交流程',
        goals: ['做一份提案簡報', '定義成交條件與下一步', '建立 CRM 欄位'],
        resources: ['提案結構：問題→影響→方案→證據→下一步'],
        outputs: ['提案簡報', 'CRM pipeline 模板'],
      ),
      PlanWeek(
        week: 6,
        title: '作品集（商務案例）',
        goals: ['寫 1 個完整 BD 案例', '整理你如何創造價值', '準備面試故事'],
        resources: ['案例結構：背景→策略→行動→結果→反思'],
        outputs: ['案例頁', '面試故事稿'],
      ),
    ],
    RoleTag.people: [
      PlanWeek(
        week: 3,
        title: '招募與面談基本功',
        goals: ['寫一份職缺 JD', '設計面談題庫', '建立評分規準'],
        resources: ['結構化面談與行為題'],
        outputs: ['JD + 面談題庫', '評分表'],
      ),
      PlanWeek(
        week: 4,
        title: '訓練與制度（小而美）',
        goals: ['設計新人 onboarding', '規劃一場內訓', '定義回饋機制'],
        resources: ['學習地圖/勝任力概念'],
        outputs: ['Onboarding 流程', '內訓大綱'],
      ),
      PlanWeek(
        week: 5,
        title: '員工體驗與文化',
        goals: ['做一次簡短員工調查', '整理 3 個改善點', '設計一個儀式/活動'],
        resources: ['eNPS/脈搏調查'],
        outputs: ['調查問卷 + 結果摘要', '改善提案（1 頁）'],
      ),
      PlanWeek(
        week: 6,
        title: 'HR 作品集',
        goals: ['整理 1–2 個制度案例', '把成果寫成影響', '準備面試故事'],
        resources: ['案例結構：問題→分析→方案→結果→迭代'],
        outputs: ['案例頁', '面試故事稿'],
      ),
    ],
    RoleTag.finance: [
      PlanWeek(
        week: 3,
        title: '報表與流程',
        goals: ['理解三大表關係', '做一份簡易月結流程', '建立科目表概念'],
        resources: ['用範例公司報表練習閱讀'],
        outputs: ['月結流程圖', '三大表關係筆記'],
      ),
      PlanWeek(
        week: 4,
        title: '稅務與內控（概念）',
        goals: ['理解常見稅別與申報', '列出 5 個內控風險點', '設計對應控制'],
        resources: ['以案例理解：發票/憑證/報稅'],
        outputs: ['風險與控制清單', '內控流程草圖'],
      ),
      PlanWeek(
        week: 5,
        title: '分析與預算',
        goals: ['做一次成本拆解', '做一份簡易預算表', '設計差異分析格式'],
        resources: ['預算/差異分析模板'],
        outputs: ['預算表', '差異分析報告（1 頁）'],
      ),
      PlanWeek(
        week: 6,
        title: '作品集（流程與分析）',
        goals: ['整理 1 個流程改善案例', '整理 1 個分析案例', '準備面試故事'],
        resources: ['案例結構：現況→問題→改善→結果'],
        outputs: ['案例頁', '面試故事稿'],
      ),
    ],
    RoleTag.security: [
      PlanWeek(
        week: 3,
        title: '網路與系統基礎',
        goals: ['理解 TCP/IP、DNS、HTTP', '熟悉 Linux 基本指令', '建立威脅思維'],
        resources: ['做一次封包/Log 觀察練習', '建立自己的工具清單'],
        outputs: ['基礎筆記', '工具清單（含用途）'],
      ),
      PlanWeek(
        week: 4,
        title: '偵測與事件應變（入門）',
        goals: ['理解告警與誤報', '設計一個簡易調查流程', '練習寫事件摘要'],
        resources: ['用公開事件報告做 reverse note'],
        outputs: ['事件摘要模板', '調查流程圖'],
      ),
      PlanWeek(
        week: 5,
        title: '弱點與修補',
        goals: ['理解常見弱點類型（OWASP）', '做一次掃描/修補練習', '寫修補建議'],
        resources: ['OWASP Top 10 概覽', '找一個 demo 專案練習'],
        outputs: ['弱點清單', '修補建議（1 頁）'],
      ),
      PlanWeek(
        week: 6,
        title: '作品集與面試故事',
        goals: ['整理 1–2 個演練案例', '把成果寫成風險降低', '準備面試故事'],
        resources: ['故事結構：偵測→調查→處置→預防'],
        outputs: ['案例頁', '面試故事稿'],
      ),
    ],
  };

  if (top != null && track[top] != null) {
    return [...common, ...track[top]!];
  }
  return common.toList();
}

/// 假資料課程／證照清單（同一筆可橫跨多週）
List<RecommendedCourse> _coursesFor(RoleTag? top) {
  // 共通類（每個方向都會推）
  final common = <RecommendedCourse>[
    RecommendedCourse(
      id: 'c_common_1',
      title: 'LinkedIn Learning：學習如何學習',
      provider: 'LinkedIn Learning',
      type: '課程',
      weeks: const [1, 2],
      detail: '建立每天 30–60 分鐘固定學習時段的方法論。',
    ),
    RecommendedCourse(
      id: 'c_common_2',
      title: 'Notion 個人作品集模板（Hahow）',
      provider: 'Hahow',
      type: '課程',
      weeks: const [2, 3],
      detail: '把筆記與小作品整理成可分享的 Notion 頁面。',
    ),
  ];

  if (top == null) return common;

  switch (top) {
    case RoleTag.engineering:
      return [
        ...common,
        const RecommendedCourse(
          id: 'c_eng_ts',
          title: 'TypeScript 官方 Handbook（自學）',
          provider: '官方文件',
          type: '課程',
          weeks: [3, 4],
          detail: '挑 5–8 章邊做小範例邊讀，先讀型別系統、模組、泛型。',
        ),
        const RecommendedCourse(
          id: 'c_eng_fso',
          title: 'Full Stack Open（赫爾辛基大學）',
          provider: 'University of Helsinki',
          type: '課程',
          weeks: [4, 5, 6],
          detail: '一條龍學 React + Node + DB，部分章節可直接當作品集 demo。',
        ),
        const RecommendedCourse(
          id: 'c_eng_aws',
          title: 'AWS Certified Cloud Practitioner',
          provider: 'AWS',
          type: '證照',
          weeks: [5, 6],
          detail: '面試常被問到雲端基礎；有證照在履歷上會加分。',
        ),
      ];
    case RoleTag.data:
      return [
        ...common,
        const RecommendedCourse(
          id: 'c_data_mode',
          title: 'Mode Analytics SQL Tutorial',
          provider: 'Mode',
          type: '課程',
          weeks: [3, 4],
          detail: '從 SELECT 到 window function，免費題庫可邊做邊學。',
        ),
        const RecommendedCourse(
          id: 'c_data_gda',
          title: 'Google Data Analytics 證照',
          provider: 'Coursera × Google',
          type: '證照',
          weeks: [4, 5, 6],
          detail: '8 門課循序漸進，含 R / Tableau / SQL 全套，可做專題。',
        ),
        const RecommendedCourse(
          id: 'c_data_kaggle',
          title: 'Kaggle Pandas 微課程',
          provider: 'Kaggle',
          type: '課程',
          weeks: [5, 6],
          detail: '學完直接挑一個 Kaggle 資料集做完整分析報告。',
        ),
      ];
    case RoleTag.product:
      return [
        ...common,
        const RecommendedCourse(
          id: 'c_pm_jtbd',
          title: 'Reforge：Product Strategy（精選文章）',
          provider: 'Reforge',
          type: '課程',
          weeks: [3, 4],
          detail: '免費 newsletter 文章已能涵蓋 JTBD、Market Sizing 概念。',
        ),
        const RecommendedCourse(
          id: 'c_pm_book',
          title: 'Cracking the PM Interview（讀書會）',
          provider: '自組讀書會',
          type: '課程',
          weeks: [5, 6],
          detail: '每週讀 1 章 + 1 題模擬題；重點放在 Product Sense。',
        ),
        const RecommendedCourse(
          id: 'c_pm_certified',
          title: 'Pendo Certified Product Manager',
          provider: 'Pendo',
          type: '證照',
          weeks: [6],
          detail: '免費線上認證，履歷加一行；考試 30 分鐘。',
        ),
      ];
    case RoleTag.design:
      return [
        ...common,
        const RecommendedCourse(
          id: 'c_design_gux',
          title: 'Google UX Design 專業證照',
          provider: 'Coursera × Google',
          type: '證照',
          weeks: [3, 4, 5, 6],
          detail: '7 門課 + 3 個作品集案例；可一邊上一邊做作品。',
        ),
        const RecommendedCourse(
          id: 'c_design_figma',
          title: 'Figma 從零到 Auto Layout',
          provider: 'Hahow / 自學',
          type: '課程',
          weeks: [3],
          detail: '把週 1 訪談摘要直接做成 Wireframe → 高保真稿。',
        ),
        const RecommendedCourse(
          id: 'c_design_md',
          title: 'Material Design 3 官方文件',
          provider: 'Google',
          type: '課程',
          weeks: [4, 5],
          detail: '挑 2 個 token / pattern 真的套到自己的 prototype。',
        ),
      ];
    case RoleTag.marketing:
      return [
        ...common,
        const RecommendedCourse(
          id: 'c_mkt_ga',
          title: 'Google Analytics 認證（GA4）',
          provider: 'Google Skillshop',
          type: '證照',
          weeks: [4, 5],
          detail: '免費，考試約 90 分鐘；履歷面試常加分。',
        ),
        const RecommendedCourse(
          id: 'c_mkt_meta',
          title: 'Meta Blueprint：Digital Marketing Associate',
          provider: 'Meta',
          type: '證照',
          weeks: [4, 5, 6],
          detail: '臉書廣告投放與成效分析；含投放實作練習。',
        ),
        const RecommendedCourse(
          id: 'c_mkt_growth',
          title: '《Growth Hacker Marketing》閱讀心得',
          provider: '讀書會',
          type: '課程',
          weeks: [5, 6],
          detail: '把書中漏斗概念套到自己練習投放的素材上。',
        ),
      ];
    case RoleTag.sales:
      return [
        ...common,
        const RecommendedCourse(
          id: 'c_sales_hubspot',
          title: 'HubSpot Sales Software 認證',
          provider: 'HubSpot Academy',
          type: '證照',
          weeks: [4, 5, 6],
          detail: '免費；含 inbound / outbound 流程設計。',
        ),
        const RecommendedCourse(
          id: 'c_sales_spin',
          title: 'SPIN Selling 重點導讀',
          provider: '自學 / 讀書會',
          type: '課程',
          weeks: [3, 4],
          detail: '掌握 4 種提問結構，套到自己模擬的客戶腳本。',
        ),
      ];
    case RoleTag.people:
      return [
        ...common,
        const RecommendedCourse(
          id: 'c_hr_shrm',
          title: 'SHRM-CP（人資基本認識）',
          provider: 'SHRM',
          type: '證照',
          weeks: [5, 6],
          detail: '較長期目標，可先把考試大綱當地圖規劃學習。',
        ),
        const RecommendedCourse(
          id: 'c_hr_struct',
          title: '結構化面談設計（線上工作坊）',
          provider: '台灣人資協會',
          type: '課程',
          weeks: [3, 4],
          detail: '把面談題庫整理成可重用的範本。',
        ),
      ];
    case RoleTag.finance:
      return [
        ...common,
        const RecommendedCourse(
          id: 'c_fin_cfa',
          title: 'CFA Level I 預備（自學版）',
          provider: 'CFA Institute',
          type: '證照',
          weeks: [4, 5, 6],
          detail: '長期目標；先把 Ethics 與 Quant Methods 兩章念完。',
        ),
        const RecommendedCourse(
          id: 'c_fin_excel',
          title: 'Excel 財務模型實戰（Hahow）',
          provider: 'Hahow',
          type: '課程',
          weeks: [3, 4],
          detail: '建立簡易月結模型 + 差異分析模板。',
        ),
      ];
    case RoleTag.security:
      return [
        ...common,
        const RecommendedCourse(
          id: 'c_sec_thm',
          title: 'TryHackMe：Pre-Security 路徑',
          provider: 'TryHackMe',
          type: '課程',
          weeks: [3, 4],
          detail: '免費開始；把網路與 Linux 基本功補齊。',
        ),
        const RecommendedCourse(
          id: 'c_sec_secplus',
          title: 'CompTIA Security+',
          provider: 'CompTIA',
          type: '證照',
          weeks: [4, 5, 6],
          detail: '入門資安最常被要求的證照；考試題型偏概念題。',
        ),
        const RecommendedCourse(
          id: 'c_sec_owasp',
          title: 'OWASP Top 10 線上閱讀',
          provider: 'OWASP',
          type: '課程',
          weeks: [5],
          detail: '每天讀一個弱點 + 找一個 demo 專案重現。',
        ),
      ];
  }
}

GeneratedPlan generatePlan(
  List<RoleId> likedRoleIds, {
  AppMode mode = AppMode.career,
}) {
  if (mode == AppMode.startup) {
    return _generateStartupPlan(likedRoleIds);
  }

  final clean = likedRoleIds.toSet().toList();
  final likedRoles = roles.where((r) => clean.contains(r.id)).toList();
  final tagScores = topTagsFromRoleIds(clean);
  final top = tagScores.isEmpty ? null : tagScores.first.tag;

  final fallback = roles.take(3).toList();
  final recommendedRoles = likedRoles.isNotEmpty ? likedRoles : fallback;

  final rawWeeks = baseWeeks(top);
  final rawLen = rawWeeks.length;
  final n = math.max(4, math.min(8, rawLen));
  final take = math.min(n, rawLen);
  final weeks = rawWeeks.sublist(0, take);

  return GeneratedPlan(
    basedOnLikedRoleIds: clean,
    basedOnTopTags: tagScores.take(3).toList(),
    recommendedRoles: recommendedRoles,
    headline: pickHeadline(top),
    weeks: weeks,
    courses: _coursesFor(top),
  );
}

// ---------------------------------------------------------------------------
// 創業者模式：用一份固定 6 週路線。如果使用者有在「探索」滑卡 LIKE 某些
// 創業能力，那些能力會在 PlanTodosScreen 額外展開成一個「想練的能力」區塊
// （由 [startupSkillTodos] 提供清單）。
// ---------------------------------------------------------------------------

GeneratedPlan _generateStartupPlan(List<RoleId> likedSkillIds) {
  final clean = likedSkillIds.toSet().toList();
  final likedSkills = clean
      .map(findStartupSkillById)
      .whereType<CareerRole>()
      .toList();
  final fallback = startupSkills.take(3).toList();
  return GeneratedPlan(
    basedOnLikedRoleIds: clean,
    basedOnTopTags: const [],
    recommendedRoles: likedSkills.isNotEmpty ? likedSkills : fallback,
    headline: '把點子做成生意：6 週啟動清單',
    weeks: _startupWeeks,
    courses: _startupCourses,
  );
}

const List<PlanWeek> _startupWeeks = [
  PlanWeek(
    week: 1,
    title: '點子驗證 — 確認問題真的存在',
    goals: [
      '寫下你的點子（一句話 + 為誰）',
      '列出 3 個最危險的假設',
      '訪談 5 位潛在客戶（不講解決方案）',
    ],
    resources: [
      '《The Mom Test》第 1–3 章',
      '一頁問題假設表',
    ],
    outputs: [
      '5 份訪談筆記',
      '經驗證／待驗證／已 kill 的假設清單',
    ],
  ),
  PlanWeek(
    week: 2,
    title: '商業模式 — Lean Canvas 一頁完成',
    goals: [
      '填完 Lean Canvas（9 格）',
      '估算單一客戶 LTV 與 CAC',
      '寫一句 < 20 字的價值主張',
    ],
    resources: [
      'Lean Canvas 模板',
      '《Business Model Generation》摘要',
    ],
    outputs: [
      '一頁 Lean Canvas',
      '一句話定位 + 6 個月現金流草表',
    ],
  ),
  PlanWeek(
    week: 3,
    title: 'MVP — 用最少的東西回答最關鍵的問題',
    goals: [
      '畫主流程 wireframe（不超過 5 頁）',
      '用 no-code 工具做出可點擊原型',
      '邀請 5 位真實 user 試用並錄影',
    ],
    resources: [
      'Tally / Notion / Carrd / Figma',
      'Wizard of Oz 測試方法',
    ],
    outputs: [
      '可分享的原型連結',
      '5 份 user testing 筆記',
    ],
  ),
  PlanWeek(
    week: 4,
    title: '第一輪驗證 — 找到第一個願意付錢的人',
    goals: [
      '設計付費或預購的最小實驗',
      '上一條冷啟動 channel（IG／PTT／社群）',
      '量化第一週的轉換漏斗',
    ],
    resources: [
      'Stripe Payment Links / 街口 / Line Pay',
      'AARRR 漏斗模板',
    ],
    outputs: [
      '第 1 位真實付費客戶（或預購）',
      '一張漏斗轉換截圖',
    ],
  ),
  PlanWeek(
    week: 5,
    title: '公司治理 — 法務、財務、補助一次盤點',
    goals: [
      '研究公司登記方式（行號／有限公司）',
      '草擬 founder agreement（角色、股權、退出）',
      '挑出 1 個最匹配的政府補助並寫提案',
    ],
    resources: [
      '經濟部商業司公司登記說明',
      'U-Start / SBIR / 青年創業貸款官網',
    ],
    outputs: [
      '一份 founder agreement 草稿',
      '一份 3 頁補助提案摘要',
    ],
  ),
  PlanWeek(
    week: 6,
    title: '募資準備 — 把故事說給投資人聽',
    goals: [
      '寫第一版 10 頁 pitch deck',
      '錄一段 60 秒 elevator pitch',
      '找 3 位 mentor 做 mock pitch',
    ],
    resources: [
      'YC pitch deck 範本',
      'Sequoia memo 結構',
    ],
    outputs: [
      'Pitch deck v1（10 頁）',
      'Q&A 矩陣（10 個犀利問題）',
    ],
  ),
];

const List<RecommendedCourse> _startupCourses = [
  RecommendedCourse(
    id: 'c_startup_yc_school',
    title: 'Y Combinator Startup School',
    provider: 'Y Combinator',
    type: '課程',
    weeks: [1, 2, 3],
    detail: '免費線上課；最有名的早期創業 playbook，邊做點子驗證邊看。',
  ),
  RecommendedCourse(
    id: 'c_startup_mom_test',
    title: '《The Mom Test》',
    provider: 'Rob Fitzpatrick',
    type: '課程',
    weeks: [1],
    detail: '訪談客戶的聖經，1 天就能看完，能讓你少做一堆白工。',
  ),
  RecommendedCourse(
    id: 'c_startup_appworks',
    title: 'AppWorks Accelerator 申請準備',
    provider: 'AppWorks',
    type: '課程',
    weeks: [4, 5, 6],
    detail: '台灣最大早期加速器；準備申請就是把整個 plan 整合成一份 deck。',
  ),
  RecommendedCourse(
    id: 'c_startup_ustart',
    title: 'U-Start 創新創業計畫',
    provider: '教育部青年發展署',
    type: '證照',
    weeks: [5],
    detail: '若你還在學或畢業 5 年內，這份補助最值得申請。',
  ),
  RecommendedCourse(
    id: 'c_startup_lean',
    title: 'Lean Canvas Workshop（線上）',
    provider: 'Strategyzer',
    type: '課程',
    weeks: [2],
    detail: '把商業模式拆成 9 格的標準工具，一個下午就能跑完一輪。',
  ),
];
