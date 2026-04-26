/// 臺北市青年補助 — 從 service.taipei + youth.gov.taipei 整理。
///
/// 兩份清單依使用者角色顯示：
///   - [jobSubsidies]: 求職／實習／進修導向，displayed when `startupInterest = false`.
///   - [startupSubsidies]: 創業導向，displayed when `startupInterest = true`.
///
/// 來源資料 v3：13 筆中扣掉「社會住宅育兒租金加碼補貼」（住宅補貼，與職涯／創業
/// 無關）與「青年局場地租用」（場地非補助），剩下 11 筆全數分類在本檔。
library;

class SubsidyLink {
  const SubsidyLink({
    required this.id,
    required this.name,
    required this.tagline,
    required this.url,
    this.isNew = false,
  });

  final String id;
  final String name;
  final String tagline;
  final String url;
  final bool isNew;
}

/// 求職／一般職涯導向補助
const List<SubsidyLink> jobSubsidies = [
  SubsidyLink(
    id: 'PO004',
    name: '青年實習津貼',
    tagline: '15–35 歲在學青年，60/90 天最高 NT\$30,000',
    url: 'https://service.taipei/case-detail/PO004',
  ),
  SubsidyLink(
    id: 'NEW01',
    name: '青年職涯進修補助計畫',
    tagline: '18–29 歲課程學費補助，最高 NT\$20,000',
    url: 'https://tpyd.104.com.tw/studies',
    isNew: true,
  ),
  SubsidyLink(
    id: 'EA026',
    name: '青年就業領航穩定就業津貼',
    tagline: '參加勞動部領航計畫者連續津貼',
    url: 'https://service.taipei/case-detail/EA026',
  ),
  SubsidyLink(
    id: 'NEW02',
    name: '海外實習計畫',
    tagline: '歐／亞 10+ 國家實習機會',
    url: 'https://youth.gov.taipei',
    isNew: true,
  ),
  SubsidyLink(
    id: 'PO008',
    name: '促進青年國際發展補助',
    tagline: '國際比賽 / 會議出席補助，個人最高 NT\$20,000',
    url: 'https://service.taipei/case-detail/PO008',
  ),
  SubsidyLink(
    id: 'PO002',
    name: '留學生就學貸款補助',
    tagline: '碩 / 博出國深造，貸款利息 10 年補助',
    url: 'https://service.taipei/case-detail/PO002',
  ),
  SubsidyLink(
    id: 'PO005',
    name: '鼓勵青年多元發展補助',
    tagline: '立案團體活動補助，每場最高 NT\$20,000',
    url: 'https://service.taipei/case-detail/PO005',
  ),
];

/// 創業導向補助
const List<SubsidyLink> startupSubsidies = [
  SubsidyLink(
    id: 'PO009',
    name: '青年創業融資貸款',
    tagline: '一般 NT\$200 萬 / 特殊條件最高 NT\$400 萬',
    url: 'https://service.taipei/case-detail/PO009',
  ),
  SubsidyLink(
    id: 'PO006',
    name: '青年創業共享空間租金補助',
    tagline: '進駐共享空間的租金折抵',
    url: 'https://service.taipei/case-detail/PO006',
  ),
  SubsidyLink(
    id: 'PO007',
    name: '職涯培力及創業活動補助',
    tagline: '機構辦理創業活動費用補助',
    url: 'https://service.taipei/case-detail/PO007',
  ),
  SubsidyLink(
    id: 'PO004B',
    name: '青年創新職場實習補助（企業端）',
    tagline: '雇主端：每月每位 NT\$10,000，最長 6 個月',
    url:
        'https://youth.gov.taipei/announcement/latest-announcement/e9f60caf-7421-4ce9-aca9-367594a78546',
  ),
];
