import '../models/models.dart';

final List<DailyQuestion> dailyQuestions = [
  DailyQuestion(
    id: 'stereotype_engineers_code_all_day',
    text: '工程師每天都在寫程式嗎？',
    answer:
        '不一定。要看工程師類型與職級。資深工程師常常花很多時間在設計、溝通與協作（例如 Code Review、架構決策、排除風險），寫程式只是其中一部分。',
    roleTags: [RoleTag.engineering],
    options: ['是', '否', '看情況', '不確定'],
  ),
  DailyQuestion(
    id: 'stereotype_analysts_love_excel',
    text: '資料分析師是不是離不開 Excel／報表？',
    answer:
        '常常會用到，但不等於只會做報表。好的分析師更在意把問題定義清楚、找到關鍵指標、提出可行建議；工具可能是 Excel、SQL、BI、或 Python，重點是能讓結論可驗證、可重現。',
    roleTags: [RoleTag.data],
    options: ['是', '否', '看情況', '不確定'],
  ),
  DailyQuestion(
    id: 'stereotype_pm_meetings_all_day',
    text: '產品經理是不是整天都在開會？',
    answer:
        '會議通常不少，因為 PM 的核心工作是對齊目標與取捨。但好的 PM 會把開會轉成產出：清楚的需求、可執行的決策、明確的優先級與驗收標準，而不只是『在會議裡』。',
    roleTags: [RoleTag.product],
    options: ['是', '否', '看情況', '不確定'],
  ),
  DailyQuestion(
    id: 'stereotype_designers_just_make_pretty',
    text: '設計師的工作只是把東西做漂亮而已嗎？',
    answer:
        '不只。UI/UX 設計更像是在解決使用者問題：理解需求、設計流程、定義互動與狀態、協助落地。視覺只是其中一層，真正的價值在於把複雜變簡單、把體驗做順。',
    roleTags: [RoleTag.design],
    options: ['是', '否', '看情況', '不確定'],
  ),
  DailyQuestion(
    id: 'stereotype_marketing_social_media',
    text: '行銷工作就是經營社群、寫貼文嗎？',
    answer:
        '社群是其中一種手段，但行銷更關心的是『讓對的人採取行動』：定位、訊息、渠道、投放、轉換與成效。寫貼文只是策略的一部分，還要能追蹤數據並持續優化。',
    roleTags: [RoleTag.marketing],
    options: ['是', '否', '看情況', '不確定'],
  ),
  DailyQuestion(
    id: 'stereotype_sales_pushy',
    text: '業務一定要很會講話、很外向嗎？',
    answer:
        '不一定。外向有幫助，但更關鍵的是理解客戶問題、能把價值講清楚、建立信任、穩定跟進。很多優秀業務其實很內向，但非常擅長傾聽與提問。',
    roleTags: [RoleTag.sales],
    options: ['是', '否', '看情況', '不確定'],
  ),
  DailyQuestion(
    id: 'stereotype_hr_only_hiring',
    text: '人資的工作就是招募跟發薪水嗎？',
    answer:
        '招募與薪酬只是部分。HR 也會做制度設計、培訓、績效、員工關係、文化與組織發展。好的 HR 是讓公司『能留人、能成長』的推進器。',
    roleTags: [RoleTag.people],
    options: ['是', '否', '看情況', '不確定'],
  ),
  DailyQuestion(
    id: 'stereotype_finance_boring',
    text: '會計／財務是不是很無聊、每天都在對數字？',
    answer:
        '會有很多細節與規範，但不只是『對數字』。財務會影響預算、風險控管、決策品質。喜歡把流程變清楚、把風險降下來的人，常常會做得很有成就感。',
    roleTags: [RoleTag.finance],
    options: ['是', '否', '看情況', '不確定'],
  ),
  DailyQuestion(
    id: 'stereotype_security_hackers',
    text: '資安分析師是不是要很會『駭』？',
    answer:
        '不一定要當黑客。資安更常在做的是：監控、分析告警、事件調查、制定規範、修補弱點。懂攻擊思路有幫助，但核心是風險管理與系統性的防護。',
    roleTags: [RoleTag.security],
    options: ['是', '否', '看情況', '不確定'],
  ),
  DailyQuestion(
    id: 'stereotype_engineers_math_genius',
    text: '工程師一定要數學很好才能做嗎？',
    answer:
        '不用到『天才』等級。大多數軟體工作更重視邏輯、抽象能力與問題拆解。特定領域（圖形、ML、金融）會更吃數學，但很多產品工程把基礎打穩就能做得很好。',
    roleTags: [RoleTag.engineering],
    options: ['是', '否', '看情況', '不確定'],
  ),
  DailyQuestion(
    id: 'stereotype_analysts_statistics',
    text: '資料分析一定要很懂統計才行嗎？',
    answer:
        '入門不需要很深，但要懂基本概念（平均/分佈/相關不等於因果/抽樣偏差）。統計越扎實越能做出可靠結論；前期可以先把常用概念學起來，再逐步加深。',
    roleTags: [RoleTag.data],
    options: ['是', '否', '看情況', '不確定'],
  ),
  DailyQuestion(
    id: 'stereotype_pm_no_real_work',
    text: '產品經理是不是只是『傳話』沒有產出？',
    answer:
        '如果只是傳話，那確實價值不高。真正的 PM 產出是：定義問題、做取捨、把模糊變清楚、讓團隊做出正確的東西、並用指標驗證成效。產出不一定是程式碼，但會直接影響結果。',
    roleTags: [RoleTag.product],
    options: ['是', '否', '看情況', '不確定'],
  ),
];
