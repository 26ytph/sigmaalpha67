/// 興趣字典：個人輪廓的「興趣」欄只能從這裡選擇，不允許自由輸入。
const List<String> interestsCatalog = <String>[
  // 工程與資料
  '工程／程式', '前端開發', '後端開發', '行動 App', '雲端／DevOps',
  '資料分析', '資料工程', '機器學習',
  // 產品與設計
  '產品企劃', 'UI/UX 設計', '使用者研究', '視覺設計', '互動設計', '遊戲設計',
  // 行銷與內容
  '行銷／內容', 'SEO／成效行銷', '社群經營', '影音內容', '品牌策略', '公關媒體',
  // 業務與服務
  '業務／BD', '客戶服務', '客戶成功', '電商營運',
  // 人資與財務
  '人資／教育訓練', '組織發展', '財務／會計', '商業分析', '創投／金融',
  // 資安與其他
  '資安', '法律科技', '醫療健康', '永續／ESG',
  // 創業相關
  '商業模式設計', '群眾募資', '新創社群', '產品 0→1',
];

/// 模糊搜尋
List<String> searchInterests(String query, {Set<String> excluded = const {}}) {
  final q = query.trim().toLowerCase();
  return interestsCatalog
      .where((s) => !excluded.contains(s))
      .where((s) => q.isEmpty || s.toLowerCase().contains(q))
      .toList();
}

/// 模擬「後端」根據科系分析給出推薦的興趣選項。
/// 實際串 API 後可由 server 回傳。
List<String> recommendedInterestsFor({
  required String department,
  required String grade,
  required bool startupInterest,
}) {
  final d = department.toLowerCase();
  final isHighSchool = grade == '高中';

  // 資訊類
  if (d.contains('資工') || d.contains('資科') || d.contains('cs') ||
      d.contains('資訊工程') || d.contains('電機')) {
    return [
      '工程／程式', '後端開發', '前端開發', '資料分析',
      '機器學習', '資安', '行動 App',
    ];
  }
  if (d.contains('資管') || d.contains('mis') || d.contains('資訊管理')) {
    return [
      '工程／程式', '資料分析', '產品企劃', 'UI/UX 設計',
      '商業分析', '電商營運',
    ];
  }
  // 設計類
  if (d.contains('設計') || d.contains('藝術') || d.contains('傳達')) {
    return [
      'UI/UX 設計', '視覺設計', '互動設計', '使用者研究',
      '影音內容', '品牌策略', '遊戲設計',
    ];
  }
  // 商管類
  if (d.contains('企管') || d.contains('管理') || d.contains('經濟') ||
      d.contains('商學') || d.contains('國貿') || d.contains('行銷')) {
    return [
      '行銷／內容', 'SEO／成效行銷', '業務／BD', '客戶成功',
      '商業分析', '產品企劃', '電商營運',
    ];
  }
  // 財金類
  if (d.contains('財金') || d.contains('會計') || d.contains('金融')) {
    return [
      '財務／會計', '創投／金融', '商業分析', '資料分析',
      '電商營運',
    ];
  }
  // 人文社會類
  if (d.contains('社會') || d.contains('心理') || d.contains('人類')) {
    return [
      'UI/UX 設計', '使用者研究', '人資／教育訓練', '社群經營',
      '行銷／內容', '客戶服務', '組織發展',
    ];
  }
  // 教育、語文
  if (d.contains('教育') || d.contains('語文') || d.contains('外文')) {
    return [
      '人資／教育訓練', '行銷／內容', '社群經營', '客戶成功',
      'UI/UX 設計', '影音內容',
    ];
  }
  // 法律
  if (d.contains('法律') || d.contains('法')) {
    return [
      '法律科技', '商業分析', '人資／教育訓練', '組織發展', '永續／ESG',
    ];
  }
  // 醫護
  if (d.contains('醫') || d.contains('護') || d.contains('健康') || d.contains('生科')) {
    return [
      '醫療健康', '使用者研究', '人資／教育訓練', '資料分析', 'UI/UX 設計',
    ];
  }
  // 創業意願強的人 → 補上創業相關
  if (startupInterest) {
    return [
      '產品 0→1', '商業模式設計', '群眾募資', '新創社群',
      '行銷／內容', 'UI/UX 設計', '資料分析',
    ];
  }
  // 高中 / 不確定 → 廣譜推薦
  if (isHighSchool) {
    return [
      '工程／程式', 'UI/UX 設計', '行銷／內容', '社群經營',
      '影音內容', '產品企劃', '資料分析',
    ];
  }
  // fallback
  return [
    '產品企劃', 'UI/UX 設計', '行銷／內容', '資料分析',
    '人資／教育訓練', '社群經營', '客戶服務',
  ];
}
