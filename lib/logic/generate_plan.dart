import 'dart:math' as math;

import '../data/roles.dart';
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

class GeneratedPlan {
  const GeneratedPlan({
    required this.basedOnLikedRoleIds,
    required this.basedOnTopTags,
    required this.recommendedRoles,
    required this.headline,
    required this.weeks,
  });

  final List<RoleId> basedOnLikedRoleIds;
  final List<TagScore> basedOnTopTags;
  final List<CareerRole> recommendedRoles;
  final String headline;
  final List<PlanWeek> weeks;
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

GeneratedPlan generatePlan(List<RoleId> likedRoleIds) {
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
  );
}
