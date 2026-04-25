import '../models/models.dart';

/// 創業者模式的滑卡牌組：每張卡片是一個「創業者該掌握的能力」。
///
/// 為了沿用既有的 [ExplorePhotoCard] / 記錄機制，這裡用 [CareerRole]
/// 當資料殼（id / title / tagline / skills / dayToDay / tags 都對得上）。
/// `tags` 對創業者沒有實質意義，但 ExplorePhotoCard 會用它畫 chip，所以
/// 至少給一個 tag 讓 UI 不會空。`imageSrc` 留空時會 fallback 成漸層底。
final List<CareerRole> startupSkills = [
  CareerRole(
    id: 'startup_customer_interview',
    title: '客戶訪談',
    tagline: '在寫一行 code 之前，先確認問題真的存在',
    imageSrc: 'jobs_img/marketing.png',
    skills: ['Mom Test 提問', '中性記錄', '5 Whys', '辨識真假需求', '訪談腳本設計'],
    dayToDay: ['約 5 位潛在客戶', '訪談 30 分鐘', '不講解決方案只聽問題', '整理共同痛點', '跟筆記迭代假設'],
    tags: [RoleTag.product, RoleTag.people],
  ),
  CareerRole(
    id: 'startup_business_model',
    title: '商業模式設計',
    tagline: '把點子拆成可以被驗證的格子',
    imageSrc: 'jobs_img/finance_advisor.png',
    skills: ['Lean Canvas', 'Business Model Canvas', '單位經濟學', '價值主張畫布', '北極星指標'],
    dayToDay: ['填一頁 Lean Canvas', '算 LTV/CAC', '跟潛在客戶對價值', '推估第一年現金流', '寫一句話定位'],
    tags: [RoleTag.product, RoleTag.finance],
  ),
  CareerRole(
    id: 'startup_mvp',
    title: 'MVP 打造',
    tagline: '用最少的東西，回答最關鍵的問題',
    imageSrc: 'jobs_img/designer.png',
    skills: ['No-code 工具', 'Wireframe', '最小可行流程設計', '快速原型', 'Wizard of Oz 測試'],
    dayToDay: ['用 Tally / Notion 蓋落地頁', '請 5 位 user 試用', '紀錄卡關點', '用 1 週迭代一次', '定義 kill criteria'],
    tags: [RoleTag.product, RoleTag.engineering],
  ),
  CareerRole(
    id: 'startup_growth',
    title: '增長與行銷',
    tagline: '讓對的人在對的時刻看見你',
    imageSrc: 'jobs_img/marketing.png',
    skills: ['漏斗分析', '內容行銷', 'SEO 基礎', '社群冷啟動', 'A/B 測試'],
    dayToDay: ['寫一篇能被搜尋的內容', '排 30 天發文計畫', '看每日轉換', '跑一次 A/B', '盤點 channel ROI'],
    tags: [RoleTag.marketing, RoleTag.data],
  ),
  CareerRole(
    id: 'startup_pitch',
    title: '募資簡報',
    tagline: '10 分鐘內，把投資人從問號變驚嘆號',
    imageSrc: 'jobs_img/marketing.png',
    skills: ['Pitch deck 結構', 'Storytelling', '數字敘事', '估值邏輯', '回應犀利問題'],
    dayToDay: ['寫 10 頁 deck', '跟 mentor mock pitch', '準備 Q&A 矩陣', '練 60 秒電梯簡報', '改成 5 分鐘版'],
    tags: [RoleTag.finance, RoleTag.sales],
  ),
  CareerRole(
    id: 'startup_legal',
    title: '法務與股權',
    tagline: '把規矩搞懂，未來才不會被綁住',
    imageSrc: 'jobs_img/lawyer.png',
    skills: ['公司登記', '創辦人協議', 'Term Sheet 看懂', 'IP 與商標', '個資合規'],
    dayToDay: ['看一次標準 SAFE', '寫 founder agreement', '盤點公司要登記什麼', '檢查網站隱私權政策', '請律師喝一次咖啡'],
    tags: [RoleTag.finance, RoleTag.security],
  ),
  CareerRole(
    id: 'startup_finance',
    title: '財務與現金流',
    tagline: '不是賺多少，是還能撐幾個月',
    imageSrc: 'jobs_img/finance_advisor.png',
    skills: ['Burn rate 計算', '現金流預測', '記帳基礎', '稅務申報', '報表閱讀'],
    dayToDay: ['做 6 個月現金流預測', '記每日支出', '算單月 burn rate', '計算 runway', '看一次損益表'],
    tags: [RoleTag.finance],
  ),
  CareerRole(
    id: 'startup_team',
    title: '找共同創辦人 / 早期團隊',
    tagline: '一個人走得快，一群人走得遠',
    imageSrc: 'jobs_img/marketing.png',
    skills: ['人才盤點', '股權分配對話', '價值觀對齊', '面談技巧', '遠距協作'],
    dayToDay: ['列你還缺哪些角色', '跟潛在合夥人吃飯', '共同寫一頁價值觀', '試做小專案 2 週', '討論退出機制'],
    tags: [RoleTag.people],
  ),
  CareerRole(
    id: 'startup_grants',
    title: '補助與政策資源',
    tagline: '把政府的補助變成你的第一桶金',
    imageSrc: 'jobs_img/civil_servant.png',
    skills: ['提案書撰寫', '預算編列', '政府補助查找', '結案核銷', '報告呈現'],
    dayToDay: ['查 U-Start / SBIR', '研究青年創業貸款', '寫 3 頁提案摘要', '估算所需補助金額', '排說明會行程'],
    tags: [RoleTag.finance, RoleTag.people],
  ),
  CareerRole(
    id: 'startup_ops',
    title: '營運流程',
    tagline: '把 1 次能做的事變成 100 次都能做',
    imageSrc: 'jobs_img/factory_technician.png',
    skills: ['SOP 撰寫', '工具自動化', '專案管理', '訂單流管理', '客戶服務流'],
    dayToDay: ['寫第一份 SOP', '用 Notion / Airtable 建工作台', '每週 review 流程', '把可重複的事自動化', '跟客服 SOP 對齊'],
    tags: [RoleTag.product, RoleTag.engineering],
  ),
  CareerRole(
    id: 'startup_product_design',
    title: '產品設計',
    tagline: '使用者第一秒看到什麼，決定他會不會留下',
    imageSrc: 'jobs_img/designer.png',
    skills: ['資訊架構', '互動原型', '視覺基本功', '可用性測試', '設計系統雛形'],
    dayToDay: ['畫 wireframe', '做點 click-through prototype', '跟 5 位 user 測試', '迭代主流程', '建立 design tokens'],
    tags: [RoleTag.design, RoleTag.product],
  ),
  CareerRole(
    id: 'startup_brand',
    title: '品牌敘事',
    tagline: '同樣的事，講得對才會被記得',
    imageSrc: 'jobs_img/content_creator.png',
    skills: ['品牌定位', '故事結構', '社群口吻', '視覺識別基本', 'PR 切角'],
    dayToDay: ['寫一句品牌承諾', '畫 logo 草稿', '寫 founder 故事', '排 IG 第 1–10 篇貼文', '聯絡 1 位記者'],
    tags: [RoleTag.marketing, RoleTag.design],
  ),
];

/// 一張卡 → 它被「LIKE」進 plan 後展開成的待辦清單。
/// PlanTodosScreen 在創業模式會把 user 已喜歡的技能展開成同一份清單。
const Map<String, List<String>> startupSkillTodos = {
  'startup_customer_interview': [
    '列出 10 位可能的目標客戶',
    '設計 8 題開放式訪談題目',
    '完成 5 場 30 分鐘訪談',
    '整理共同痛點 + 用一句話寫下假設',
  ],
  'startup_business_model': [
    '寫一份 Lean Canvas（一頁）',
    '估算單一客戶 LTV 與 CAC',
    '畫一張 6 個月現金流',
    '把價值主張濃縮成一句 < 20 字',
  ],
  'startup_mvp': [
    '用 Tally / Notion / Carrd 蓋落地頁',
    '做出最小流程的 click-through 原型',
    '邀請 5 位真實 user 試用並錄影',
    '記下 3 個最痛的卡關點，排優先序',
  ],
  'startup_growth': [
    '挑 1 條冷啟動 channel 並寫實驗計畫',
    '寫 3 篇可被搜尋到的內容',
    '建一個簡易漏斗 dashboard',
    '跑一次 A/B 並記錄學到什麼',
  ],
  'startup_pitch': [
    '寫第一版 10 頁 pitch deck',
    '錄一段 60 秒 elevator pitch',
    '找 3 位 mentor 做 mock pitch',
    '整理 Q&A 矩陣（10 個犀利問題）',
  ],
  'startup_legal': [
    '研究公司登記方式（行號／有限公司）',
    '草擬一份 founder agreement',
    '盤點需要的商標／IP',
    '找 1 位律師做 30 分鐘諮詢',
  ],
  'startup_finance': [
    '建立 6 個月現金流預測表',
    '算出目前 burn rate 與 runway',
    '建立日記帳習慣（30 天）',
    '研究發票與報稅基本流程',
  ],
  'startup_team': [
    '寫下你目前最缺的 3 個角色',
    '列 5 位潛在共同創辦人候選',
    '一起寫一頁共識文件（價值觀、分工）',
    '討論股權分配與退出機制',
  ],
  'startup_grants': [
    '查 U-Start / SBIR / 青創貸款條件',
    '挑出 1 個最匹配的補助',
    '撰寫 3 頁提案摘要',
    '排一場政府單位說明會行程',
  ],
  'startup_ops': [
    '寫 1 份核心服務 SOP',
    '把 3 件每週重複的事自動化',
    '建立 Notion / Airtable 任務看板',
    '每週做一次流程 retro',
  ],
  'startup_product_design': [
    '畫主流程 wireframe',
    '做 click-through prototype',
    '跑 5 場可用性測試',
    '建立簡易設計系統 tokens',
  ],
  'startup_brand': [
    '寫一句品牌承諾',
    '完成 logo 與基本 visual',
    '寫一篇 founder 故事',
    '排 IG / 官網第 1–10 則內容',
  ],
};

CareerRole? findStartupSkillById(String id) {
  for (final s in startupSkills) {
    if (s.id == id) return s;
  }
  return null;
}
