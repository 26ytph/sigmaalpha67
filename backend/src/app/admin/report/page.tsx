// 政策端「正式報告」頁面 — A4 列印 / PDF 匯出最佳化。
// 與 /admin/dashboard 不同：本頁是公文式靜態報告，不是互動儀表板。
//   - 純黑文字 + 純色塊（避免漸層在印表機翻車）
//   - 公文式編號（壹貳參／一二三／（一）（二）（三））
//   - 封面 + 摘要 + 章節 + 附錄
//   - 表格與條列為主，圖表是輔助
//   - 列印時自動隱藏 nav，每個大章節 page-break-before
//
// 對應 /admin/dashboard 的數據來源；同一 loadDashboardSnapshot()。

import { loadDashboardSnapshot } from "@/lib/dashboardData";
import { PrintButton } from "../dashboard/PrintButton";
import { TaiwanMap } from "../dashboard/charts";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export const metadata = {
  title: "EmploYA! ・ 青年職涯與創業需求政策建議報告",
};

const DOC_NUM = "EMP-YA-2026-Q2-001";
const ISSUER = "EmploYA! 青年職涯服務政策研究小組";
const RECIPIENT = "教育部 / 勞動部 / 國家發展委員會 / 各直轄市青年事務委員會";

// 估算頁碼：以列印 A4 為基準，每個 .sheet 約 1 頁；附錄較長算 2 頁。
// 真正列印時瀏覽器會自動 reflow，但這份目錄頁碼足以讓人粗略對照位置。
type TocChild = { id: string; index: string; title: string; page: string };
type TocEntry = {
  id: string;
  index: string;
  title: string;
  page: string;
  children?: TocChild[];
};
const TOC: TocEntry[] = [
  {
    id: "sec-1",
    index: "壹",
    title: "執行摘要",
    page: "3",
    children: [
      { id: "sec-1", index: "一", title: "重點發現", page: "3" },
      { id: "sec-1", index: "二", title: "核心指標一覽", page: "3" },
    ],
  },
  {
    id: "sec-2",
    index: "貳",
    title: "青年需求趨勢分析",
    page: "4",
    children: [
      { id: "sec-2", index: "一", title: "高頻問題（前 5 名）", page: "4" },
      { id: "sec-2", index: "二", title: "熱門職涯方向（前 5 名）", page: "4" },
      { id: "sec-2", index: "三", title: "常見技能缺口（前 5 名）", page: "4" },
    ],
  },
  {
    id: "sec-3",
    index: "參",
    title: "空間分布與創業需求",
    page: "5",
    children: [
      { id: "sec-3", index: "一", title: "全國青年使用者分布", page: "5" },
      { id: "sec-3", index: "二", title: "各縣市重點需求對照", page: "5" },
      { id: "sec-3", index: "三", title: "創業需求分類", page: "5" },
      { id: "sec-3", index: "四", title: "To-do List 卡關任務", page: "5" },
    ],
  },
  {
    id: "sec-4",
    index: "肆",
    title: "政策建議與影響預測",
    page: "6",
    children: [
      { id: "sec-4", index: "一", title: "開設「文組技能轉譯」工作坊", page: "6" },
      { id: "sec-4", index: "二", title: "推出「跨域資料分析入門」公開課", page: "6" },
      { id: "sec-4", index: "三", title: "分流創業諮詢資源至想法期使用者", page: "7" },
    ],
  },
  {
    id: "sec-5",
    index: "伍",
    title: "附錄",
    page: "8",
    children: [
      { id: "sec-5", index: "一", title: "資料來源與方法", page: "8" },
      { id: "sec-5", index: "二", title: "名詞定義", page: "8" },
      { id: "sec-5", index: "三", title: "資料品質聲明", page: "8" },
    ],
  },
];

export default async function PolicyReportPage() {
  const data = await loadDashboardSnapshot();
  const totalQuestions = data.topQuestions.reduce((s, q) => s + q.count, 0);
  const totalInterest = data.careerPaths.reduce(
    (s, c) => s + c.interestedUsers,
    0,
  );
  const totalStartup = data.startupNeeds.reduce((s, n) => s + n.users, 0);
  const totalStuck = data.stuckTasks.reduce((s, t) => s + t.stuckUsers, 0);
  const totalRegions = data.regions.reduce((s, r) => s + r.users, 0);

  const today = new Date(data.fetchedAt);
  const formatDate = (d: Date) =>
    `中華民國 ${d.getFullYear() - 1911} 年 ${d.getMonth() + 1} 月 ${d.getDate()} 日`;
  const formatTime = (d: Date) =>
    `${d.getFullYear()}/${pad(d.getMonth() + 1)}/${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;

  const topGap = [...data.radar]
    .map((d) => ({ ...d, gap: d.demand - d.supply }))
    .sort((a, b) => b.gap - a.gap)[0];

  return (
    <main className="report">
      <style>{REPORT_CSS}</style>

      {/* —— 螢幕專用 Toolbar，列印時自動隱藏 —— */}
      <nav className="screen-only toolbar">
        <div>
          <a href="/admin/dashboard" className="back-link">← 返回互動儀表板</a>
        </div>
        <div className="toolbar-actions">
          <span className="hint">提示：Ctrl + P → 「另存為 PDF」即可外帶</span>
          <PrintButton />
        </div>
      </nav>

      {/* ─────────────── 封面 ─────────────── */}
      <section className="cover sheet">
        <header className="cover-head">
          <div className="badge-box">
            <p>政策研究報告</p>
            <p>POLICY BRIEF</p>
          </div>
          <div className="cover-meta">
            <p>
              <strong>文件編號：</strong>
              {DOC_NUM}
            </p>
            <p>
              <strong>機密等級：</strong>
              一般 / 內部研議
            </p>
            <p>
              <strong>製表日期：</strong>
              {formatDate(today)}
            </p>
          </div>
        </header>

        <div className="cover-title">
          <p className="cover-eyebrow">EmploYA! 青年職涯與創業 AI 助理</p>
          <h1>
            青年職涯與創業需求趨勢
            <br />
            政策建議報告
          </h1>
          <p className="cover-period">
            分析期間：{formatTime(new Date(today.getTime() - 7 * 86400000))} ～{" "}
            {formatTime(today)}
          </p>
        </div>

        <table className="cover-info">
          <tbody>
            <tr>
              <th>製表單位</th>
              <td>{ISSUER}</td>
            </tr>
            <tr>
              <th>建議呈閱</th>
              <td>{RECIPIENT}</td>
            </tr>
            <tr>
              <th>樣本基礎</th>
              <td>
                EmploYA! 平台累計 {totalRegions.toLocaleString("zh-TW")} 名青年使用者
                ・ 跨 {data.regions.length} 個直轄市/縣市 ・
                資料皆已去識別化
              </td>
            </tr>
            <tr>
              <th>本期重點</th>
              <td>
                文組轉職與技能轉譯需求顯著上升；資源缺口集中於「
                {topGap?.axis ?? "1 對 1 諮詢"}」
              </td>
            </tr>
          </tbody>
        </table>

        <footer className="cover-foot">
          <p>
            本報告所有數據皆為去識別化彙總，僅供政策研擬與資源配置參考；
            未經授權，不得對外公開或轉載。
          </p>
        </footer>
      </section>

      {/* ─────────────── 目錄 ─────────────── */}
      <section className="sheet toc-sheet">
        <h2 className="toc-title">目　　錄</h2>
        <nav className="toc">
          <ol className="toc-list">
            {TOC.map((entry) => (
              <li key={entry.id} className="toc-row">
                <a href={`#${entry.id}`} className="toc-main">
                  <span className="toc-idx">{entry.index}、</span>
                  <span className="toc-label">{entry.title}</span>
                  <span className="toc-dots" aria-hidden="true" />
                  <span className="toc-page">{entry.page}</span>
                </a>
                {entry.children && (
                  <ol className="toc-sub">
                    {entry.children.map((c, i) => (
                      <li key={i}>
                        <a href={`#${c.id}`} className="toc-subrow">
                          <span className="toc-subidx">{c.index}、</span>
                          <span className="toc-label">{c.title}</span>
                          <span className="toc-dots" aria-hidden="true" />
                          <span className="toc-page">{c.page}</span>
                        </a>
                      </li>
                    ))}
                  </ol>
                )}
              </li>
            ))}
          </ol>
        </nav>
      </section>

      {/* ─────────────── 壹、執行摘要 ─────────────── */}
      <section className="sheet" id="sec-1">
        <SectionTitle index="壹" title="執行摘要" />

        <p className="lead">
          本期（過去 7 日）EmploYA! 平台共服務 {totalRegions.toLocaleString("zh-TW")}{" "}
          名青年，產生 {totalQuestions.toLocaleString("zh-TW")} 次 AI 問答、
          {totalInterest.toLocaleString("zh-TW")} 次職涯興趣表態、
          {totalStartup} 件創業諮詢申請。
          綜合分析後，本小組提出 <strong>{data.suggestions.length} 項</strong>
          可立即推動之政策建議，預估合計可惠及{" "}
          <strong>
            {data.forecasts
              .reduce((s, f) => s + f.beneficiaries, 0)
              .toLocaleString("zh-TW")}{" "}
            人次
          </strong>
          ，所需經費約{" "}
          <strong>
            新台幣{" "}
            {(
              data.forecasts.reduce((s, f) => s + f.budgetTwd, 0) / 10000
            ).toLocaleString("zh-TW")}{" "}
            萬元
          </strong>
          。
        </p>

        <SubTitle index="一" title="重點發現" />
        <ol className="finding-list">
          <li>
            <strong>文組學生轉職焦慮為當期最高頻問題：</strong>
            「
            {data.topQuestions[0]?.question ?? "—"}」於 7 日內被詢問{" "}
            {data.topQuestions[0]?.count ?? 0} 次，占總提問比重{" "}
            {((data.topQuestions[0]?.count ?? 0) / Math.max(1, totalQuestions) * 100).toFixed(0)}
            %。
          </li>
          <li>
            <strong>UX Research、行銷企劃、資料分析助理</strong>
            為青年最熱門職涯方向，合計吸引{" "}
            {data.careerPaths
              .slice(0, 3)
              .reduce((s, c) => s + c.interestedUsers, 0)
              .toLocaleString("zh-TW")}{" "}
            人次興趣表態。
          </li>
          <li>
            <strong>技能缺口前三名</strong>為「
            {data.skillGaps
              .slice(0, 3)
              .map((g) => g.skill)
              .join("」、「")}
            」，與履歷敘事與轉職準備密切相關。
          </li>
          <li>
            <strong>創業需求集中於早期階段</strong>：第一大宗為「
            {data.startupNeeds[0]?.stage ?? "資金"}」（
            {data.startupNeeds[0]?.users ?? 0} 人），
            顯示現行貸款資源與初期需求存在錯位。
          </li>
          <li>
            <strong>資源缺口最大維度為「{topGap?.axis ?? "—"}」</strong>
            （需求 {topGap?.demand ?? 0} ・ 供給 {topGap?.supply ?? 0}，
            缺口 {topGap?.gap ?? 0} 點），建議優先補強。
          </li>
        </ol>

        <SubTitle index="二" title="核心指標一覽" />
        <table className="data-table">
          <thead>
            <tr>
              <th>指標</th>
              <th>本期數值</th>
              <th>單位</th>
              <th>備註</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>累積 AI 問答</td>
              <td className="num">{totalQuestions.toLocaleString("zh-TW")}</td>
              <td>次</td>
              <td>含 RAG 檢索與一般閒聊路徑</td>
            </tr>
            <tr>
              <td>職涯興趣表態</td>
              <td className="num">{totalInterest.toLocaleString("zh-TW")}</td>
              <td>人次</td>
              <td>滑動探索 ❤ 行為</td>
            </tr>
            <tr>
              <td>創業諮詢申請</td>
              <td className="num">{totalStartup}</td>
              <td>人</td>
              <td>含資金 / 補助 / 場地 / 商模</td>
            </tr>
            <tr>
              <td>To-do 卡關人次</td>
              <td className="num">{totalStuck}</td>
              <td>人次</td>
              <td>建議轉介人工輔導</td>
            </tr>
            <tr>
              <td>覆蓋縣市</td>
              <td className="num">{data.regions.length}</td>
              <td>個</td>
              <td>含 6 直轄市</td>
            </tr>
          </tbody>
        </table>
      </section>

      {/* ─────────────── 貳、需求趨勢 ─────────────── */}
      <section className="sheet" id="sec-2">
        <SectionTitle index="貳" title="青年需求趨勢分析" />

        <SubTitle index="一" title="高頻問題（前 5 名）" />
        <table className="data-table">
          <thead>
            <tr>
              <th>排序</th>
              <th>問題</th>
              <th>出現次數</th>
              <th>緊急程度</th>
              <th>占比</th>
            </tr>
          </thead>
          <tbody>
            {data.topQuestions.map((q, i) => (
              <tr key={i}>
                <td className="rank">{i + 1}</td>
                <td>{q.question}</td>
                <td className="num">{q.count}</td>
                <td>
                  <UrgencyTag value={q.urgency} />
                </td>
                <td className="num">
                  {((q.count / Math.max(1, totalQuestions)) * 100).toFixed(1)}%
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <SubTitle index="二" title="熱門職涯方向（前 5 名）" />
        <table className="data-table">
          <thead>
            <tr>
              <th>排序</th>
              <th>職涯方向</th>
              <th>興趣表態人次</th>
              <th>占比</th>
            </tr>
          </thead>
          <tbody>
            {data.careerPaths.map((c, i) => (
              <tr key={i}>
                <td className="rank">{i + 1}</td>
                <td>{c.label}</td>
                <td className="num">{c.interestedUsers.toLocaleString("zh-TW")}</td>
                <td className="num">
                  {((c.interestedUsers / Math.max(1, totalInterest)) * 100).toFixed(1)}%
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <SubTitle index="三" title="常見技能缺口（前 5 名）" />
        <table className="data-table">
          <thead>
            <tr>
              <th>排序</th>
              <th>技能類別</th>
              <th>提及次數</th>
              <th>對應建議方向</th>
            </tr>
          </thead>
          <tbody>
            {data.skillGaps.map((g, i) => (
              <tr key={i}>
                <td className="rank">{i + 1}</td>
                <td>{g.skill}</td>
                <td className="num">{g.mentions}</td>
                <td>{skillSuggestion(g.skill)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      {/* ─────────────── 參、空間與創業需求 ─────────────── */}
      <section className="sheet" id="sec-3">
        <SectionTitle index="參" title="空間分布與創業需求" />

        <SubTitle index="一" title="全國青年使用者分布" />
        <div className="map-wrapper">
          <TaiwanMap regions={data.regions} accent="#1a1625" />
        </div>

        <SubTitle index="二" title="各縣市重點需求對照" />
        <table className="data-table">
          <thead>
            <tr>
              <th>縣市</th>
              <th>使用者人數</th>
              <th>當地最大需求</th>
              <th>占全國比重</th>
            </tr>
          </thead>
          <tbody>
            {[...data.regions]
              .sort((a, b) => b.users - a.users)
              .map((r) => (
                <tr key={r.code}>
                  <td>{r.label}</td>
                  <td className="num">{r.users.toLocaleString("zh-TW")}</td>
                  <td>{r.topNeed}</td>
                  <td className="num">
                    {((r.users / Math.max(1, totalRegions)) * 100).toFixed(1)}%
                  </td>
                </tr>
              ))}
          </tbody>
        </table>

        <SubTitle index="三" title="創業需求分類" />
        <table className="data-table">
          <thead>
            <tr>
              <th>類別</th>
              <th>申請人數</th>
              <th>占比</th>
              <th>對應現有資源密度</th>
            </tr>
          </thead>
          <tbody>
            {data.startupNeeds.map((n, i) => (
              <tr key={i}>
                <td>{n.stage}</td>
                <td className="num">{n.users}</td>
                <td className="num">
                  {((n.users / Math.max(1, totalStartup)) * 100).toFixed(1)}%
                </td>
                <td>{startupSupply(n.stage)}</td>
              </tr>
            ))}
          </tbody>
        </table>

        <SubTitle index="四" title="To-do List 卡關任務（待人工介入）" />
        <table className="data-table">
          <thead>
            <tr>
              <th>任務代碼</th>
              <th>任務內容</th>
              <th>卡關人數</th>
            </tr>
          </thead>
          <tbody>
            {data.stuckTasks.map((t, i) => (
              <tr key={i}>
                <td className="mono">{t.taskKey}</td>
                <td>{t.title}</td>
                <td className="num">{t.stuckUsers}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      {/* ─────────────── 肆、政策建議 ─────────────── */}
      <section className="sheet" id="sec-4">
        <SectionTitle index="肆" title="政策建議與影響預測" />

        <p className="lead">
          綜合上述分析，本小組提出以下 {data.suggestions.length}{" "}
          項可立即推動之政策建議，每項均附影響預測（受惠人次、預估預算、推行期程、AI
          信心度）與建議對接單位，作為各機關研議與資源配置之參考。
        </p>

        {data.suggestions.map((s, i) => {
          const f = data.forecasts[i];
          const cnIdx = ["一", "二", "三", "四", "五"][i] ?? `${i + 1}`;
          return (
            <article key={i} className="proposal">
              <SubTitle index={cnIdx} title={s.title} />
              <p className="rationale">
                <strong>緣由：</strong>
                {s.rationale}
              </p>

              {f && (
                <table className="forecast-table">
                  <thead>
                    <tr>
                      <th colSpan={4}>影響預測（採納本建議）</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr>
                      <th>預估受惠人次</th>
                      <td className="num strong">
                        {f.beneficiaries.toLocaleString("zh-TW")}
                      </td>
                      <th>預估預算</th>
                      <td className="num strong">
                        新台幣 {(f.budgetTwd / 10000).toLocaleString("zh-TW")} 萬元
                      </td>
                    </tr>
                    <tr>
                      <th>推行期程</th>
                      <td className="num strong">{f.timelineMonths} 個月</td>
                      <th>AI 信心度</th>
                      <td className="num strong">
                        {Math.round(f.confidence * 100)}%
                      </td>
                    </tr>
                    <tr>
                      <th>建議對接單位</th>
                      <td colSpan={3}>{f.stakeholders.join("、")}</td>
                    </tr>
                  </tbody>
                </table>
              )}

              {s.proposedActions.length > 0 && (
                <>
                  <p className="actions-label">建議具體行動：</p>
                  <ol className="action-list">
                    {s.proposedActions.map((a, ai) => (
                      <li key={ai}>{a}</li>
                    ))}
                  </ol>
                </>
              )}
            </article>
          );
        })}
      </section>

      {/* ─────────────── 伍、附錄 ─────────────── */}
      <section className="sheet" id="sec-5">
        <SectionTitle index="伍" title="附錄" />

        <SubTitle index="一" title="資料來源與方法" />
        <ol className="appendix-list">
          <li>
            <strong>EmploYA! 平台原始資料：</strong>
            包含使用者問答、滑動探索、To-do 進度、創業諮詢申請、AI 接手包等行為紀錄。
          </li>
          <li>
            <strong>去識別化處理：</strong>
            移除姓名、聯絡資訊、生日；地理粒度限縣市級；統計皆為彙總值，不揭露單一個案。
          </li>
          <li>
            <strong>AI 問題正規化：</strong>
            使用 EmploYA! Intent Normalizer 將原始問題分類至「職涯諮詢／資源／政策／情緒」等意圖。
          </li>
          <li>
            <strong>RAG 知識庫：</strong>
            檢索範圍含 30+ 政策、課程、創業資源來源（青年局、創業臺北、教育部高教平台等）。
          </li>
          <li>
            <strong>影響預測模型：</strong>
            基於受惠人數、覆蓋縣市、需求/供給比例與歷史申請案案均成本估算；AI
            信心度反映資料完整度。
          </li>
        </ol>

        <SubTitle index="二" title="名詞定義" />
        <table className="data-table">
          <thead>
            <tr>
              <th>名詞</th>
              <th>定義</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>RAG</td>
              <td>
                Retrieval-Augmented Generation，檢索擴增生成。將知識庫片段作為上下文輸入 LLM，使回覆基於可驗證來源。
              </td>
            </tr>
            <tr>
              <td>緊急程度</td>
              <td>
                由 Intent Normalizer 依「情緒詞、急迫表述、後果描述」等指標自動評等：高 / 中高 / 中 / 低。
              </td>
            </tr>
            <tr>
              <td>卡關</td>
              <td>
                同一 To-do 任務於 14 日內未完成且使用者已重複進入該任務頁 ≥ 3 次。
              </td>
            </tr>
            <tr>
              <td>AI 信心度</td>
              <td>
                檢索結果排序分數加權後正規化至 0~100%，用以表示模型對該回覆/預測的把握度。
              </td>
            </tr>
          </tbody>
        </table>

        <SubTitle index="三" title="資料品質聲明" />
        <p>
          本報告為 EmploYA! 黑客松 MVP 階段成果，部分指標基於模擬資料以驗證資料管線與展示形式；
          正式上線後將替換為真實用戶聚合資料，並接入 Supabase Postgres 進行每日批次計算。
          本小組保留依後續實證資料修訂預測值之權利。
        </p>
      </section>

      <footer className="report-foot screen-only">
        <p>
          {DOC_NUM} ・ {ISSUER} ・ Generated {formatTime(today)}
        </p>
      </footer>
    </main>
  );
}

// ──────────── helpers ────────────

function pad(n: number): string {
  return `${n}`.padStart(2, "0");
}

function SectionTitle({ index, title }: { index: string; title: string }) {
  return (
    <h2 className="section-title">
      <span className="section-index">{index}、</span>
      {title}
    </h2>
  );
}

function SubTitle({ index, title }: { index: string; title: string }) {
  return (
    <h3 className="sub-title">
      <span className="sub-index">{index}、</span>
      {title}
    </h3>
  );
}

function UrgencyTag({ value }: { value: string }) {
  const colorMap: Record<string, string> = {
    高: "#a40000",
    中高: "#a35a00",
    中: "#7a3a55",
    低: "#444",
  };
  return (
    <span className="urgency-tag" style={{ color: colorMap[value] ?? "#444" }}>
      ●&nbsp;{value}
    </span>
  );
}

function skillSuggestion(skill: string): string {
  if (skill.includes("作品集")) return "履歷敘事工作坊 / 校園駐點諮詢";
  if (skill.includes("SQL")) return "跨域資料分析入門公開課";
  if (skill.includes("STAR") || skill.includes("履歷"))
    return "STAR 結構化教材融入通識";
  if (skill.includes("Excel")) return "資料整理線上補助課程";
  if (skill.includes("簡報")) return "簡報與表達公開講座";
  return "對應專題課程或工作坊";
}

function startupSupply(stage: string): string {
  if (stage.includes("資金")) return "現有：青創貸款（多落於籌備期之後）";
  if (stage.includes("補助")) return "現有：青年事務補助（資訊不對稱）";
  if (stage.includes("場地")) return "現有：青創共享空間（覆蓋率不均）";
  if (stage.includes("商業模式")) return "現有：創業臺北諮詢（量能有限）";
  return "—";
}

const REPORT_CSS = `
  :root { color-scheme: light; }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: #e5e5e5;
    font-family: "Times New Roman", "PingFang TC", "Microsoft JhengHei", "Noto Serif TC", serif;
    color: #1a1a1a;
    -webkit-font-smoothing: antialiased;
    line-height: 1.7;
  }

  .report { max-width: 850px; margin: 0 auto; padding: 24px 16px 56px; }

  .toolbar {
    display: flex; justify-content: space-between; align-items: center;
    background: #fff; border: 1px solid #00000018;
    padding: 10px 18px; border-radius: 10px; margin-bottom: 18px;
    font-family: -apple-system, "PingFang TC", "Microsoft JhengHei", sans-serif;
    box-shadow: 0 4px 12px -8px rgba(0,0,0,0.2);
  }
  .toolbar-actions { display: flex; align-items: center; gap: 14px; }
  .back-link {
    color: #5856d6; text-decoration: none; font-size: 13px; font-weight: 700;
  }
  .back-link:hover { text-decoration: underline; }
  .hint { font-size: 11px; color: #6b6b6b; }

  /* —— sheet = 一張紙 —— */
  .sheet {
    background: #fff;
    padding: 60px 64px;
    margin-bottom: 18px;
    box-shadow: 0 8px 24px -12px rgba(0,0,0,0.18);
    min-height: 1100px;
    position: relative;
  }

  /* —— 封面 —— */
  .cover { display: flex; flex-direction: column; }
  .cover-head {
    display: flex; justify-content: space-between; align-items: flex-start;
    border-bottom: 3px double #1a1a1a;
    padding-bottom: 16px;
  }
  .badge-box {
    border: 2px solid #1a1a1a;
    padding: 12px 18px;
    text-align: center;
  }
  .badge-box p {
    margin: 0; font-size: 13px; font-weight: 800; letter-spacing: 4px;
  }
  .badge-box p:first-child { font-size: 16px; }
  .cover-meta { font-size: 13px; line-height: 2; }
  .cover-meta p { margin: 0; }
  .cover-meta strong { display: inline-block; min-width: 5em; }

  .cover-title {
    flex: 1;
    display: flex; flex-direction: column;
    justify-content: center; align-items: center;
    text-align: center; padding: 80px 0;
  }
  .cover-eyebrow {
    margin: 0 0 24px;
    font-size: 14px; letter-spacing: 4px; color: #555;
    font-family: -apple-system, "PingFang TC", sans-serif;
  }
  .cover h1 {
    margin: 0 0 32px;
    font-size: 38px; font-weight: 800; line-height: 1.5;
    letter-spacing: 2px;
  }
  .cover-period {
    margin: 0; font-size: 13px; color: #444;
    font-family: -apple-system, "PingFang TC", sans-serif;
  }

  .cover-info {
    width: 100%; border-collapse: collapse;
    border-top: 2px solid #1a1a1a; border-bottom: 2px solid #1a1a1a;
    margin-top: 24px;
    font-family: -apple-system, "PingFang TC", "Microsoft JhengHei", sans-serif;
  }
  .cover-info th, .cover-info td {
    padding: 12px 14px; text-align: left; vertical-align: top;
    border-bottom: 1px solid #00000014;
    font-size: 13px;
  }
  .cover-info th {
    width: 110px; background: #faf3f5; font-weight: 700;
  }
  .cover-info tr:last-child th, .cover-info tr:last-child td { border-bottom: none; }

  .cover-foot {
    margin-top: auto; padding-top: 24px;
    border-top: 1px solid #00000022;
    font-size: 11px; color: #555; text-align: center; line-height: 1.7;
    font-family: -apple-system, "PingFang TC", sans-serif;
  }
  .cover-foot p { margin: 0; }

  /* —— 目錄 —— */
  .toc-sheet { padding: 60px 80px; }
  .toc-title {
    margin: 0 0 36px; padding-bottom: 14px;
    text-align: center;
    font-size: 28px; font-weight: 800; letter-spacing: 24px;
    border-bottom: 3px double #1a1a1a;
  }
  .toc { font-family: -apple-system, "PingFang TC", "Microsoft JhengHei", sans-serif; }
  .toc-list { list-style: none; padding: 0; margin: 0; }
  .toc-row { margin: 18px 0; }
  .toc-main {
    display: flex; align-items: baseline;
    color: #1a1a1a; text-decoration: none;
    font-size: 16px; font-weight: 800;
    padding: 6px 0;
    border-bottom: 1px solid transparent;
    transition: border-color 120ms ease, color 120ms ease;
  }
  .toc-main:hover { color: #5856d6; border-bottom-color: #5856d633; }
  .toc-idx { color: #5856d6; margin-right: 6px; min-width: 1.6em; }
  .toc-label { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .toc-dots {
    flex: 1; margin: 0 8px;
    border-bottom: 2px dotted #00000044;
    transform: translateY(-3px);
    min-width: 24px;
  }
  .toc-page {
    color: #1a1a1a; font-weight: 800;
    font-variant-numeric: tabular-nums;
    min-width: 2em; text-align: right;
  }
  .toc-sub {
    list-style: none; padding-left: 2.4em; margin: 4px 0 0;
  }
  .toc-sub li { margin: 4px 0; }
  .toc-subrow {
    display: flex; align-items: baseline;
    color: #444; text-decoration: none;
    font-size: 13.5px; font-weight: 600;
    padding: 3px 0;
  }
  .toc-subrow:hover { color: #5856d6; }
  .toc-subidx { color: #5856d6; margin-right: 6px; min-width: 1.4em; }

  /* —— 章節 —— */
  .section-title {
    margin: 0 0 24px;
    padding-bottom: 12px;
    font-size: 24px; font-weight: 800; letter-spacing: 1px;
    border-bottom: 3px double #1a1a1a;
  }
  .section-index { color: #5856d6; margin-right: 4px; }

  .sub-title {
    margin: 28px 0 14px;
    font-size: 17px; font-weight: 800;
    color: #1a1a1a;
    border-left: 4px solid #5856d6;
    padding-left: 10px;
  }
  .sub-index { color: #5856d6; }

  .lead {
    margin: 0 0 18px; font-size: 14px; line-height: 1.95;
    text-indent: 2em;
  }
  .lead strong { color: #5856d6; }

  /* —— 列表 —— */
  .finding-list, .appendix-list, .action-list {
    padding-left: 1.6em; margin: 0 0 14px;
    font-size: 13.5px; line-height: 1.95;
  }
  .finding-list li, .appendix-list li { margin: 6px 0; }
  .finding-list strong, .appendix-list strong { color: #1a1a1a; }

  /* —— 表格 —— */
  .data-table {
    width: 100%; border-collapse: collapse; margin: 8px 0 16px;
    font-family: -apple-system, "PingFang TC", "Microsoft JhengHei", sans-serif;
    font-size: 13px;
  }
  .data-table thead th {
    background: #1a1a1a; color: #fff;
    padding: 10px 12px; text-align: left; font-weight: 700;
    font-size: 12.5px; letter-spacing: 0.5px;
  }
  .data-table tbody td {
    padding: 9px 12px;
    border-bottom: 1px solid #00000014;
    vertical-align: top;
  }
  .data-table tbody tr:nth-child(even) td { background: #faf3f5; }
  .data-table .num { text-align: right; font-variant-numeric: tabular-nums; font-weight: 600; }
  .data-table .rank { text-align: center; font-weight: 800; color: #5856d6; }
  .data-table .mono { font-family: "SFMono-Regular", Menlo, monospace; font-size: 12px; }

  /* —— 政策建議 —— */
  .proposal {
    margin: 24px 0;
    padding: 20px 24px;
    border: 1px solid #00000022;
    background: #fbfafd;
    page-break-inside: avoid;
  }
  .proposal .sub-title { margin-top: 0; }
  .rationale {
    margin: 0 0 14px;
    font-size: 13.5px; line-height: 1.85;
    text-indent: 2em;
  }
  .actions-label {
    margin: 16px 0 6px;
    font-size: 13px; font-weight: 800; color: #5856d6;
  }

  .forecast-table {
    width: 100%; border-collapse: collapse; margin: 8px 0;
    font-family: -apple-system, "PingFang TC", "Microsoft JhengHei", sans-serif;
    font-size: 13px;
    border: 1px solid #1a1a1a;
  }
  .forecast-table thead th {
    background: #1a1a1a; color: #fff;
    padding: 8px 12px; text-align: left;
    font-size: 12px; letter-spacing: 0.5px;
  }
  .forecast-table tbody th {
    background: #faf3f5; text-align: left;
    width: 110px; padding: 9px 12px;
    font-weight: 700; font-size: 12.5px;
    border-bottom: 1px solid #00000014;
  }
  .forecast-table tbody td {
    padding: 9px 12px; font-size: 13px;
    border-bottom: 1px solid #00000014;
    vertical-align: middle;
  }
  .forecast-table tbody tr:last-child th,
  .forecast-table tbody tr:last-child td { border-bottom: none; }
  .forecast-table .num.strong {
    text-align: right; font-weight: 800; color: #5856d6;
    font-size: 14.5px; font-variant-numeric: tabular-nums;
  }

  /* —— 緊急程度 tag —— */
  .urgency-tag {
    font-weight: 800; font-size: 12px;
    font-family: -apple-system, "PingFang TC", sans-serif;
  }

  /* —— 地圖 —— */
  .map-wrapper {
    text-align: center;
    padding: 12px 0 6px;
  }
  .map-wrap {
    display: flex; gap: 18px; align-items: flex-start;
    justify-content: center;
    margin: 0 auto;
  }
  .map-canvas {
    position: relative;
    flex-shrink: 0;
    background: #f7f7f7;
    border: 1px solid #00000018;
    overflow: hidden;
  }
  .map-base {
    display: block;
    width: 100%; height: 100%;
    object-fit: contain;
    filter: grayscale(100%) brightness(0.95) contrast(1.05);
    pointer-events: none; user-select: none;
  }
  .map-bubble {
    position: absolute;
    transform: translate(-50%, -50%);
    border-radius: 50%;
    display: flex; align-items: center; justify-content: center;
    color: #fff; font-weight: 800; line-height: 1;
  }
  .map-bubble-num {
    font-size: 9.5px; font-variant-numeric: tabular-nums;
    font-family: -apple-system, "PingFang TC", sans-serif;
  }
  .map-bubble-label {
    position: absolute;
    top: 100%; margin-top: 3px;
    color: #1a1a1a;
    font-size: 10px; font-weight: 800;
    background: rgba(255,255,255,0.9);
    padding: 1px 5px;
    border-radius: 3px;
    white-space: nowrap;
    font-family: -apple-system, "PingFang TC", "Microsoft JhengHei", sans-serif;
  }
  .map-legend {
    list-style: none; padding: 0; margin: 0;
    display: flex; flex-direction: column; gap: 6px;
    font-family: -apple-system, "PingFang TC", "Microsoft JhengHei", sans-serif;
    font-size: 12px;
  }
  .map-legend li {
    display: grid; grid-template-columns: 60px 1fr auto;
    gap: 10px; align-items: center;
    padding: 6px 12px;
    background: #faf3f5;
    border-radius: 6px;
  }
  .map-legend-rank { font-weight: 800; }
  .map-legend-need { color: #4a4a4a; font-size: 11.5px; }
  .map-legend strong { font-weight: 800; color: #1a1a1a; }

  .report-foot {
    text-align: center; padding: 16px 0;
    font-size: 11px; color: #666;
    font-family: -apple-system, "PingFang TC", sans-serif;
  }

  /* ─── 列印優化 ─── */
  @media print {
    body { background: #fff !important; }
    .report { padding: 0; max-width: none; }
    .screen-only { display: none !important; }
    .sheet {
      box-shadow: none !important;
      margin: 0; padding: 28mm 22mm;
      min-height: auto;
      page-break-after: always;
    }
    .sheet:last-of-type { page-break-after: auto; }
    .cover { min-height: 250mm; }
    .proposal { page-break-inside: avoid; }
    .data-table thead th, .forecast-table thead th {
      background: #1a1a1a !important;
      color: #fff !important;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    .forecast-table tbody th, .data-table tbody tr:nth-child(even) td,
    .cover-info th {
      background: #f5f0f2 !important;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    .badge-box { border-color: #000 !important; }
    .section-title, .cover-head { border-color: #000 !important; }
    a { color: inherit; text-decoration: none; }
  }

  @page {
    size: A4;
    margin: 0;
  }
`;
