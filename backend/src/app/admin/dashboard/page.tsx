import { loadDashboardSnapshot, type DashboardSource } from "@/lib/dashboardData";
import {
  ActivityTicker,
  AreaChart,
  Donut,
  HorizontalBars,
  Legend,
  RadarChart,
  RadialGauge,
  Sparkline,
  TaiwanMap,
  VerticalBars,
} from "./charts";
import { PrintButton } from "./PrintButton";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export const metadata = {
  title: "EmploYA! 政策端 Dashboard",
  description: "去識別化的青年職涯與創業需求趨勢面板",
};

const SKILL_PALETTE = ["#FE3C72", "#FF655B", "#FFA463", "#AF52DE", "#5856D6"];
const STARTUP_PALETTE = ["#5856D6", "#AF52DE", "#FE3C72", "#FF9500"];

export default async function PolicyDashboardPage() {
  const data = await loadDashboardSnapshot();
  const totalInterest = data.careerPaths.reduce(
    (s, c) => s + c.interestedUsers,
    0,
  );
  const totalQuestions = data.topQuestions.reduce((s, q) => s + q.count, 0);
  const totalStartup = data.startupNeeds.reduce((s, n) => s + n.users, 0);
  const totalStuck = data.stuckTasks.reduce((s, t) => s + t.stuckUsers, 0);
  const totalSkillMentions = data.skillGaps.reduce(
    (s, g) => s + g.mentions,
    0,
  );
  const allMock = Object.values(data.sources).every((v) => v === "mock");

  const skillSegments = data.skillGaps.map((g, i) => ({
    label: g.skill,
    value: g.mentions,
    color: SKILL_PALETTE[i % SKILL_PALETTE.length],
    pct: (g.mentions / Math.max(1, totalSkillMentions)) * 100,
  }));
  const startupSegments = data.startupNeeds.map((n, i) => ({
    label: n.stage,
    value: n.users,
    color: STARTUP_PALETTE[i % STARTUP_PALETTE.length],
    pct: (n.users / Math.max(1, totalStartup)) * 100,
  }));

  return (
    <main className="dashboard">
      <style>{CSS}</style>

      {/* ───────── HERO ───────── */}
      <header className="hero">
        <div className="hero-top">
          <div>
            <p className="eyebrow">EmploYA! ・ Policy Insights Dashboard</p>
            <h1>青年職涯與創業需求 ・ 即時洞察</h1>
            <p className="lede">
              本面板資料皆為去識別化彙總，僅作為政策研擬參考。資料來源：
              EmploYA! AI 問答 / 滑動探索 / To-do 進度 / 創業諮詢申請。
            </p>
          </div>
          <div className="hero-meta">
            <span className="status-dot" /> Live
            <time>{formatDate(data.fetchedAt)}</time>
          </div>
        </div>

        {allMock && (
          <div className="banner">
            <strong>目前顯示 mock 資料。</strong> 在 Supabase 建立 <code>dashboard_*</code>{" "}
            tables 並插入資料即會自動切換到 ● Supabase 來源（schema 見 <code>backend/README.md</code>）。
          </div>
        )}

        <div className="kpi-row">
          <KpiCard
            label="累積提問"
            value={totalQuestions}
            unit="次"
            sub="近 7 日趨勢"
            trend={data.trends.questions.map((t) => t.value)}
          />
          <KpiCard
            label="興趣表態"
            value={totalInterest}
            unit="人次"
            sub="滑動探索 ❤"
            trend={data.trends.interest.map((t) => t.value)}
          />
          <KpiCard
            label="創業意向"
            value={totalStartup}
            unit="人"
            sub="諮詢申請"
            trend={data.trends.startup.map((t) => t.value)}
          />
          <KpiCard
            label="任務卡關"
            value={totalStuck}
            unit="人次"
            sub="待人工介入"
            trend={[58, 62, 60, 71, 68, 74, 81]}
          />
        </div>
      </header>

      {/* ───────── TREND ROW ───────── */}
      <section className="trend-card">
        <header>
          <div>
            <p className="card-eyebrow">PRIMARY METRIC</p>
            <h2>本週青年提問趨勢</h2>
            <p className="card-sub">每日 AI 問答提問數 ・ 含 RAG 與閒聊路徑</p>
          </div>
          <SourcePill source={data.sources.topQuestions} />
        </header>
        <AreaChart
          values={data.trends.questions.map((t) => t.value)}
          labels={data.trends.questions.map((t) => t.day)}
          color="#5856D6"
          height={170}
        />
      </section>

      {/* ───────── 創意亮點 1：地理熱點 + 即時動態 ───────── */}
      <section className="geo-row">
        <div className="card geo-card">
          <header>
            <span className="card-icon" style={{ background: "#fe3c721a", color: "#FE3C72" }}>
              🗺️
            </span>
            <div className="card-meta">
              <p className="card-eyebrow" style={{ color: "#FE3C72" }}>SPATIAL INSIGHT</p>
              <h2 style={{ color: "#FE3C72" }}>全國青年資源需求熱點</h2>
              <p className="card-sub">依縣市分布的使用者數量 ・ 氣泡大小代表規模</p>
            </div>
            <SourcePill source="mock" />
          </header>
          <div className="geo-body">
            <TaiwanMap regions={data.regions} accent="#FE3C72" />
          </div>
        </div>

        <div className="card activity-card">
          <header>
            <span className="card-icon live-icon">
              <span className="live-dot" />
            </span>
            <div className="card-meta">
              <p className="card-eyebrow" style={{ color: "#34c759" }}>LIVE</p>
              <h2>即時去識別化動態</h2>
              <p className="card-sub">系統剛剛收到的事件 ・ 已遮罩個資</p>
            </div>
          </header>
          <div className="activity-body">
            <ActivityTicker events={data.activity} />
          </div>
        </div>
      </section>

      {/* ───────── MAIN GRID ───────── */}
      <div className="grid">
        {/* 1. 高頻問題 — Horizontal Bars */}
        <Card
          title="高頻問題"
          subtitle="青年最常問的問題 ・ 依出現次數排序"
          accent="#FE3C72"
          icon="💬"
          source={data.sources.topQuestions}
        >
          <HorizontalBars
            accent="#FE3C72"
            rows={data.topQuestions.map((q) => ({
              label: q.question,
              value: q.count,
              badge: q.urgency,
              badgeColor: urgencyColor(q.urgency),
            }))}
          />
        </Card>

        {/* 2. 熱門職涯 — Vertical Bars */}
        <Card
          title="熱門職涯方向"
          subtitle="滑動探索 ❤ 統計 ・ Top 5"
          accent="#FF655B"
          icon="❤️"
          source={data.sources.careerPaths}
        >
          <VerticalBars
            accent="#FF655B"
            unit="人次"
            rows={data.careerPaths.map((c) => ({
              label: c.label,
              value: c.interestedUsers,
            }))}
          />
        </Card>

        {/* 3. 技能缺口 — Donut + Legend */}
        <Card
          title="常見技能缺口"
          subtitle="使用者問答與接手包提及 ・ 按比例分佈"
          accent="#FF9500"
          icon="💡"
          source={data.sources.skillGaps}
        >
          <div className="donut-row">
            <Donut
              segments={skillSegments}
              centerLabel="提及總數"
              centerValue={
                <strong>{totalSkillMentions.toLocaleString("zh-TW")}</strong>
              }
            />
            <Legend items={skillSegments} />
          </div>
        </Card>

        {/* 4. 卡關任務 — Horizontal Bars + Gauge */}
        <Card
          title="To-do List 卡關點"
          subtitle="進度停滯週數最高的任務 ・ 顯示需要人工輔導的數量"
          accent="#FF3B30"
          icon="🚩"
          source={data.sources.stuckTasks}
        >
          <div className="stuck-row">
            <div className="stuck-bars">
              <HorizontalBars
                accent="#FF3B30"
                rows={data.stuckTasks.map((t) => ({
                  label: t.title,
                  value: t.stuckUsers,
                  badge: t.taskKey,
                  badgeColor: "#8A7C8E",
                }))}
              />
            </div>
            <RadialGauge
              value={totalStuck}
              max={Math.max(300, Math.ceil(totalStuck * 1.5))}
              label="待人工介入"
              unit="人次"
              color="#FF3B30"
            />
          </div>
        </Card>

        {/* 5. 創業需求 — Pie / Donut + Legend */}
        <Card
          title="創業需求分類"
          subtitle="依需求類型分群人數"
          accent="#5856D6"
          icon="🚀"
          source={data.sources.startupNeeds}
        >
          <div className="donut-row">
            <Donut
              segments={startupSegments}
              centerLabel="創業使用者"
              centerValue={<strong>{totalStartup}</strong>}
            />
            <Legend items={startupSegments} />
          </div>
        </Card>

      </div>

      {/* ───────── 創意亮點 2：資源缺口雷達（demand vs supply） ───────── */}
      <section className="card card-wide radar-card">
        <header>
          <span className="card-icon" style={{ background: "#fe3c721a", color: "#FE3C72" }}>
            📡
          </span>
          <div className="card-meta">
            <p className="card-eyebrow" style={{ color: "#5856D6" }}>GAP ANALYSIS</p>
            <h2 style={{ color: "#5856D6" }}>資源缺口雷達 ・ 需求 vs 供給</h2>
            <p className="card-sub">
              兩條多邊形落差越大代表資源錯位越嚴重 ・ 紅色為需求 / 紫色為供給
            </p>
          </div>
          <SourcePill source="mock" />
        </header>
        <div className="radar-body">
          <RadarChart dimensions={data.radar} demandColor="#FE3C72" supplyColor="#5856D6" />
          <div className="radar-side">
            <div className="legend-rows">
              <div className="legend-row">
                <span className="legend-dot" style={{ background: "#FE3C72" }} />
                <span>需求強度（青年）</span>
              </div>
              <div className="legend-row">
                <span className="legend-dot" style={{ background: "#5856D6" }} />
                <span>供給強度（現有資源）</span>
              </div>
            </div>
            <ul className="gap-list">
              {data.radar
                .map((d) => ({ ...d, gap: d.demand - d.supply }))
                .sort((a, b) => b.gap - a.gap)
                .slice(0, 3)
                .map((d) => (
                  <li key={d.axis}>
                    <strong>{d.axis}</strong>
                    <span className="gap-pill">
                      缺口 +{d.gap}
                    </span>
                    <em>需求 {d.demand} ・ 供給 {d.supply}</em>
                  </li>
                ))}
            </ul>
            <p className="radar-insight">
              <strong>洞察：</strong>「1 對 1 諮詢」與「補助金額」缺口最大，
              建議優先擴編對應預算與人力配置。
            </p>
          </div>
        </div>
      </section>

      <div className="grid">
        {/* 6. 政策建議 — AI Cards 含 Impact Forecast */}
        <Card
          title="AI 政策建議 ・ 含影響預測"
          subtitle="基於目前指標自動產生 ・ 含預估受惠人數與預算"
          accent="#AF52DE"
          icon="✨"
          source={data.sources.suggestions}
          wide
        >
          <div className="suggestions">
            {data.suggestions.map((s, i) => {
              const f = data.forecasts[i];
              return (
                <article key={i} className="suggestion">
                  <header>
                    <span className="badge">建議 {i + 1}</span>
                    <h3>{s.title}</h3>
                  </header>
                  <p className="rationale">{s.rationale}</p>
                  {f && (
                    <div className="forecast">
                      <p className="actions-title">影響預測（採納本建議）</p>
                      <div className="forecast-grid">
                        <div className="forecast-stat">
                          <strong>{f.beneficiaries.toLocaleString("zh-TW")}</strong>
                          <em>預估受惠人次</em>
                        </div>
                        <div className="forecast-stat">
                          <strong>NT${(f.budgetTwd / 10000).toLocaleString("zh-TW")}萬</strong>
                          <em>預估預算</em>
                        </div>
                        <div className="forecast-stat">
                          <strong>{f.timelineMonths} 個月</strong>
                          <em>推行期程</em>
                        </div>
                        <div className="forecast-stat">
                          <strong>{Math.round(f.confidence * 100)}%</strong>
                          <em>AI 信心</em>
                        </div>
                      </div>
                      <div className="stakeholder-row">
                        <span className="stakeholder-label">對接單位</span>
                        {f.stakeholders.map((sh) => (
                          <span key={sh} className="stakeholder-pill">{sh}</span>
                        ))}
                      </div>
                    </div>
                  )}
                  {s.proposedActions.length > 0 && (
                    <>
                      <p className="actions-title">建議行動</p>
                      <ul>
                        {s.proposedActions.map((a) => (
                          <li key={a}>{a}</li>
                        ))}
                      </ul>
                    </>
                  )}
                </article>
              );
            })}
          </div>
        </Card>
      </div>

      <footer className="footer">
        <span>EmploYA! Policy Dashboard ・ 去識別化彙總資料</span>
        <div className="footer-actions">
          <a className="cta-print" href="/admin/report">
            📄 開啟正式政策報告（A4 / PDF）
          </a>
          <PrintButton />
          <span className="footer-meta">Server-rendered · Next.js · Supabase-first</span>
        </div>
      </footer>
    </main>
  );
}

// ─────────── Components ───────────

function KpiCard({
  label,
  value,
  unit,
  sub,
  trend,
}: {
  label: string;
  value: number;
  unit: string;
  sub: string;
  trend: number[];
}) {
  const delta =
    trend.length >= 2
      ? Math.round(((trend[trend.length - 1] - trend[0]) / Math.max(1, trend[0])) * 100)
      : 0;
  return (
    <div className="kpi-card">
      <div className="kpi-head">
        <p className="kpi-label">{label}</p>
        <span className={`kpi-delta ${delta >= 0 ? "up" : "down"}`}>
          {delta >= 0 ? "▲" : "▼"} {Math.abs(delta)}%
        </span>
      </div>
      <p className="kpi-value">
        {value.toLocaleString("zh-TW")}
        <span className="kpi-unit">{unit}</span>
      </p>
      <Sparkline values={trend} height={32} />
      <p className="kpi-sub">{sub}</p>
    </div>
  );
}

function Card({
  title,
  subtitle,
  accent,
  icon,
  source,
  wide,
  children,
}: {
  title: string;
  subtitle: string;
  accent: string;
  icon: string;
  source: DashboardSource;
  wide?: boolean;
  children: React.ReactNode;
}) {
  return (
    <section
      className={`card${wide ? " card-wide" : ""}`}
      style={{ borderTopColor: accent }}
    >
      <header>
        <span
          className="card-icon"
          style={{ background: `${accent}1a`, color: accent }}
        >
          {icon}
        </span>
        <div className="card-meta">
          <h2 style={{ color: accent }}>{title}</h2>
          <p className="card-sub">{subtitle}</p>
        </div>
        <SourcePill source={source} />
      </header>
      <div className="card-body">{children}</div>
    </section>
  );
}

function SourcePill({ source }: { source: DashboardSource }) {
  return (
    <span className={`source-pill ${source === "supabase" ? "live" : "mock"}`}>
      {source === "supabase" ? "● Supabase" : "○ Mock"}
    </span>
  );
}

function urgencyColor(u: string): string {
  switch (u) {
    case "高":
      return "#FF3B30";
    case "中高":
      return "#FF9500";
    case "中":
      return "#FE3C72";
    default:
      return "#8A7C8E";
  }
}

function formatDate(iso: string): string {
  const d = new Date(iso);
  const pad = (n: number) => `${n}`.padStart(2, "0");
  return `${d.getFullYear()}/${pad(d.getMonth() + 1)}/${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

const CSS = `
  :root { color-scheme: light; }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    background:
      radial-gradient(ellipse 80% 50% at 20% 0%, #fce4ed 0%, transparent 60%),
      radial-gradient(ellipse 60% 50% at 100% 30%, #ede9fe 0%, transparent 50%),
      #fafafa;
    min-height: 100vh;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI",
      "PingFang TC", "Microsoft JhengHei", "Helvetica Neue", sans-serif;
    color: #1a1625;
    -webkit-font-smoothing: antialiased;
  }
  .dashboard {
    max-width: 1280px;
    margin: 0 auto;
    padding: 32px 28px 56px;
  }

  /* ─── Hero ─── */
  .hero {
    background: linear-gradient(135deg, #2d2266 0%, #5b3aa3 35%, #c33781 70%, #ff6b3d 100%);
    color: #fff;
    border-radius: 24px;
    padding: 28px 32px 24px;
    box-shadow: 0 30px 60px -30px rgba(91, 58, 163, 0.55);
    position: relative;
    overflow: hidden;
  }
  .hero::before {
    content: "";
    position: absolute; inset: 0;
    background: radial-gradient(circle at 90% 20%, rgba(255,255,255,0.18), transparent 40%);
    pointer-events: none;
  }
  .hero-top { display: flex; justify-content: space-between; align-items: flex-start; gap: 24px; flex-wrap: wrap; }
  .eyebrow {
    margin: 0 0 6px;
    font-size: 11px; font-weight: 800; letter-spacing: 1.6px;
    color: rgba(255,255,255,0.72);
    text-transform: uppercase;
  }
  .hero h1 {
    margin: 0 0 8px;
    font-size: 30px; font-weight: 800; letter-spacing: -0.7px;
    line-height: 1.2;
  }
  .lede {
    margin: 0; font-size: 13px; line-height: 1.65;
    color: rgba(255,255,255,0.88); max-width: 640px;
  }
  .hero-meta {
    display: flex; align-items: center; gap: 8px;
    font-size: 11px; font-weight: 700;
    background: rgba(255,255,255,0.14);
    padding: 6px 12px; border-radius: 999px;
    backdrop-filter: blur(12px);
  }
  .hero-meta time { color: rgba(255,255,255,0.85); margin-left: 4px; }
  .status-dot {
    width: 7px; height: 7px; border-radius: 50%;
    background: #34c759;
    box-shadow: 0 0 0 2px rgba(52,199,89,0.3);
    animation: pulse 1.6s ease-in-out infinite;
  }
  @keyframes pulse {
    0%, 100% { box-shadow: 0 0 0 2px rgba(52,199,89,0.3); }
    50% { box-shadow: 0 0 0 6px rgba(52,199,89,0); }
  }
  .banner {
    margin-top: 18px;
    background: rgba(255,255,255,0.13);
    border: 1px solid rgba(255,255,255,0.25);
    border-radius: 14px;
    padding: 12px 16px;
    font-size: 12px; line-height: 1.6;
  }
  .banner code {
    background: rgba(0,0,0,0.22); padding: 1px 6px; border-radius: 4px;
    margin: 0 2px; font-size: 11px;
  }

  /* ─── KPI Row ─── */
  .kpi-row {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 14px; margin-top: 22px;
    position: relative;
  }
  @media (max-width: 900px) { .kpi-row { grid-template-columns: repeat(2, 1fr); } }
  .kpi-card {
    background: rgba(255,255,255,0.13);
    backdrop-filter: blur(20px);
    border: 1px solid rgba(255,255,255,0.18);
    border-radius: 16px;
    padding: 14px 16px 10px;
  }
  .kpi-head { display: flex; justify-content: space-between; align-items: center; }
  .kpi-label {
    margin: 0; font-size: 11px; font-weight: 700; letter-spacing: 0.8px;
    color: rgba(255,255,255,0.78);
  }
  .kpi-delta {
    font-size: 10px; font-weight: 800;
    padding: 2px 7px; border-radius: 999px;
  }
  .kpi-delta.up { background: rgba(52,199,89,0.22); color: #afe8b9; }
  .kpi-delta.down { background: rgba(255,59,48,0.22); color: #ffb1ab; }
  .kpi-value {
    margin: 6px 0 4px;
    font-size: 28px; font-weight: 800; letter-spacing: -0.5px;
  }
  .kpi-unit { font-size: 12px; font-weight: 500; margin-left: 4px; opacity: 0.8; }
  .kpi-sub { margin: 4px 0 0; font-size: 10px; color: rgba(255,255,255,0.65); }

  /* ─── Trend Card ─── */
  .trend-card {
    margin-top: 24px;
    background: #fff;
    border-radius: 20px;
    padding: 20px 24px 8px;
    border: 1px solid #00000010;
    box-shadow: 0 14px 36px -22px rgba(0,0,0,0.2);
  }
  .trend-card > header {
    display: flex; justify-content: space-between; align-items: flex-start;
    margin-bottom: 12px;
  }
  .card-eyebrow {
    margin: 0 0 4px; font-size: 10px; font-weight: 800;
    letter-spacing: 1.2px; color: #af52de;
  }
  .trend-card h2, .card h2 {
    margin: 0; font-size: 17px; font-weight: 800; letter-spacing: -0.3px;
  }

  /* ─── Card Grid ─── */
  .grid {
    margin-top: 22px;
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 18px;
  }
  @media (max-width: 900px) { .grid { grid-template-columns: 1fr; } }
  .card {
    background: #fff;
    border-radius: 20px;
    border: 1px solid #00000010;
    border-top: 3px solid #FE3C72;
    box-shadow: 0 14px 36px -22px rgba(0,0,0,0.2);
    padding: 20px 22px 22px;
    transition: transform 160ms ease, box-shadow 160ms ease;
  }
  .card:hover {
    transform: translateY(-2px);
    box-shadow: 0 20px 44px -22px rgba(0,0,0,0.28);
  }
  .card-wide { grid-column: 1 / -1; }
  .card > header {
    display: flex; align-items: center; gap: 12px; margin-bottom: 16px;
  }
  .card-meta { flex: 1; min-width: 0; }
  .card-icon {
    width: 38px; height: 38px;
    border-radius: 12px;
    display: flex; align-items: center; justify-content: center;
    font-size: 18px; flex-shrink: 0;
  }
  .card-sub { margin: 2px 0 0; font-size: 11px; color: #8a7c8e; line-height: 1.5; }
  .source-pill {
    font-size: 10px; font-weight: 700; letter-spacing: 0.4px;
    padding: 4px 9px; border-radius: 999px;
    border: 1px solid transparent; flex-shrink: 0;
  }
  .source-pill.live { background: #34c75922; color: #1ea34a; border-color: #34c75944; }
  .source-pill.mock { background: #8a7c8e1a; color: #6b5e6f; border-color: #8a7c8e33; }

  /* ─── HorizontalBars ─── */
  .hbar-list { list-style: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: 12px; }
  .hbar-header { display: flex; align-items: flex-start; gap: 8px; margin-bottom: 6px; }
  .rank-pill {
    width: 22px; height: 22px; flex-shrink: 0;
    border-radius: 8px; background: #faf3f5; color: #4a3f51;
    display: flex; align-items: center; justify-content: center;
    font-size: 11px; font-weight: 800;
  }
  .hbar-label { font-size: 13.5px; font-weight: 700; line-height: 1.45; flex: 1; color: #1a1625; }
  .urgency-pill { font-size: 10px; font-weight: 800; padding: 2px 7px; border-radius: 6px; flex-shrink: 0; }
  .hbar-row { display: flex; gap: 10px; align-items: center; padding-left: 30px; }
  .hbar-track {
    flex: 1; height: 8px; border-radius: 999px;
    background: #faf3f5; overflow: hidden;
  }
  .hbar-fill { height: 100%; border-radius: 999px; transition: width 600ms ease; }
  .hbar-value {
    font-size: 12px; font-weight: 800; color: #4a3f51;
    min-width: 36px; text-align: right;
  }

  /* ─── VerticalBars ─── */
  .vbar-wrap { position: relative; padding-left: 36px; padding-right: 8px; padding-bottom: 6px; }
  .vbar-grid {
    position: absolute; top: 0; left: 0; right: 0;
    pointer-events: none;
  }
  .vbar-grid span {
    position: absolute; left: 0; transform: translateY(-50%);
    font-size: 10px; color: #8a7c8e; font-weight: 600;
  }
  .vbar-canvas { position: relative; margin-left: 0; border-bottom: 1px solid #00000010; }
  .vbar-col {
    position: absolute; bottom: 0; height: 100%;
    display: flex; flex-direction: column; align-items: center; justify-content: flex-end;
  }
  .vbar-bar {
    width: 60%; min-height: 2px;
    border-radius: 8px 8px 2px 2px;
    transition: height 600ms ease;
  }
  .vbar-num { font-size: 10px; font-weight: 800; color: #4a3f51; margin-bottom: 4px; }
  .vbar-axis { display: flex; padding-top: 8px; padding-left: 0; }
  .vbar-tick {
    text-align: center; font-size: 10.5px; color: #4a3f51; font-weight: 600;
    line-height: 1.3; padding: 0 2px;
  }
  .vbar-tick em { display: block; font-style: normal; color: #8a7c8e; font-size: 9px; margin-top: 1px; }
  .vbar-unit {
    position: absolute; right: 0; top: -22px;
    font-size: 10px; color: #8a7c8e;
  }

  /* ─── Donut ─── */
  .donut-row { display: flex; gap: 22px; align-items: center; }
  @media (max-width: 540px) { .donut-row { flex-direction: column; align-items: stretch; } }
  .donut-wrap { position: relative; flex-shrink: 0; }
  .donut-center {
    position: absolute; inset: 0;
    display: flex; flex-direction: column; align-items: center; justify-content: center;
    pointer-events: none;
  }
  .donut-value { font-size: 24px; font-weight: 800; color: #1a1625; line-height: 1; }
  .donut-label { font-size: 10px; color: #8a7c8e; margin-top: 4px; letter-spacing: 0.4px; }
  .legend { list-style: none; padding: 0; margin: 0; flex: 1; display: flex; flex-direction: column; gap: 8px; min-width: 0; }
  .legend li { display: flex; align-items: center; gap: 10px; font-size: 12.5px; }
  .legend-dot { width: 10px; height: 10px; border-radius: 3px; flex-shrink: 0; }
  .legend-label { flex: 1; min-width: 0; color: #1a1625; font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .legend-value { font-weight: 800; color: #4a3f51; flex-shrink: 0; }
  .legend-pct { font-style: normal; font-weight: 600; color: #8a7c8e; margin-left: 2px; }

  /* ─── Stuck-task row (bars + gauge) ─── */
  .stuck-row { display: flex; gap: 20px; align-items: flex-start; }
  @media (max-width: 540px) { .stuck-row { flex-direction: column; } }
  .stuck-bars { flex: 1; min-width: 0; }
  .gauge-wrap { display: flex; flex-direction: column; align-items: center; flex-shrink: 0; }
  .gauge-readout { text-align: center; margin-top: -6px; }
  .gauge-readout strong { display: block; font-size: 22px; font-weight: 800; }
  .gauge-readout em { font-style: normal; font-size: 10px; color: #8a7c8e; }
  .gauge-readout span { display: block; font-size: 11px; color: #4a3f51; font-weight: 700; margin-top: 2px; }

  /* ─── Suggestions ─── */
  .suggestions {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 14px;
  }
  .suggestion {
    background: linear-gradient(135deg, #fff 0%, #fff5f8 100%);
    border: 1px solid #00000010;
    border-radius: 16px;
    padding: 16px 18px;
    position: relative; overflow: hidden;
  }
  .suggestion::before {
    content: ""; position: absolute; top: 0; left: 0; right: 0; height: 3px;
    background: linear-gradient(90deg, #5856d6, #af52de, #fe3c72);
  }
  .suggestion > header { display: flex; align-items: center; gap: 10px; margin-bottom: 10px; }
  .suggestion h3 { margin: 0; font-size: 14.5px; font-weight: 800; line-height: 1.45; }
  .badge {
    background: linear-gradient(135deg, #5856d6, #af52de);
    color: #fff; font-size: 10px; font-weight: 800;
    padding: 3px 10px; border-radius: 999px;
    flex-shrink: 0; letter-spacing: 0.3px;
  }
  .rationale { margin: 0; font-size: 12.5px; line-height: 1.65; color: #4a3f51; }
  .actions-title {
    margin: 12px 0 6px;
    font-size: 10px; font-weight: 800; letter-spacing: 0.5px; color: #af52de;
  }
  .suggestion ul { margin: 0; padding-left: 18px; }
  .suggestion li { font-size: 12.5px; line-height: 1.6; margin: 3px 0; color: #1a1625; }

  /* ─── Geo + Activity Row ─── */
  .geo-row {
    margin-top: 22px;
    display: grid;
    grid-template-columns: minmax(0, 1.1fr) minmax(0, 1fr);
    gap: 18px;
  }
  @media (max-width: 900px) { .geo-row { grid-template-columns: 1fr; } }
  .geo-card { border-top-color: #FE3C72; }
  .activity-card { border-top-color: #34c759; }
  .geo-body {
    display: flex; gap: 18px; align-items: center;
    padding-top: 4px;
  }
  .map-wrap { display: flex; gap: 18px; align-items: center; flex: 1; }
  @media (max-width: 600px) { .map-wrap { flex-direction: column; align-items: stretch; } }

  .map-canvas {
    position: relative;
    flex-shrink: 0;
    background: #faf3f5;
    border-radius: 12px;
    overflow: hidden;
    border: 1px solid #00000010;
  }
  .map-base {
    display: block;
    width: 100%; height: 100%;
    object-fit: contain;
    filter: grayscale(100%) brightness(0.92) contrast(1.05);
    pointer-events: none;
    user-select: none;
  }
  .map-bubble {
    position: absolute;
    transform: translate(-50%, -50%);
    border-radius: 50%;
    display: flex; flex-direction: column;
    align-items: center; justify-content: center;
    color: #fff;
    font-weight: 800;
    line-height: 1;
    transition: transform 200ms ease, box-shadow 200ms ease;
    cursor: default;
  }
  .map-bubble:hover {
    transform: translate(-50%, -50%) scale(1.15);
    z-index: 5;
  }
  .map-bubble-num {
    font-size: 9.5px;
    font-variant-numeric: tabular-nums;
  }
  .map-bubble-label {
    position: absolute;
    top: 100%;
    margin-top: 3px;
    color: #1a1625;
    font-size: 10px;
    font-weight: 800;
    background: rgba(255,255,255,0.85);
    padding: 1px 5px;
    border-radius: 4px;
    white-space: nowrap;
  }

  .map-legend {
    list-style: none; padding: 0; margin: 0;
    display: flex; flex-direction: column; gap: 8px;
    flex: 1; min-width: 0;
  }
  .map-legend li {
    display: grid; grid-template-columns: 60px 1fr auto;
    gap: 10px; align-items: center;
    font-size: 12px;
    padding: 8px 12px;
    background: #faf3f5;
    border-radius: 10px;
  }
  .map-legend-rank { font-weight: 800; }
  .map-legend-need { color: #4a3f51; font-size: 11.5px; }
  .map-legend strong { font-weight: 800; color: #1a1625; }

  .live-icon {
    background: #34c75922 !important;
    color: #34c759 !important;
    position: relative;
  }
  .live-dot {
    width: 12px; height: 12px; border-radius: 50%;
    background: #34c759;
    box-shadow: 0 0 0 4px rgba(52,199,89,0.3);
    animation: pulse 1.6s ease-in-out infinite;
  }

  /* ─── Activity Ticker ─── */
  .activity-body { max-height: 360px; overflow-y: auto; }
  .ticker { list-style: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: 10px; }
  .ticker-item {
    display: flex; gap: 10px;
    padding: 10px 12px;
    background: linear-gradient(135deg, #fff 0%, #fafafa 100%);
    border: 1px solid #00000010;
    border-radius: 12px;
    transition: transform 200ms ease, border-color 200ms ease;
  }
  .ticker-item:hover {
    transform: translateX(2px);
    border-color: #fe3c7244;
  }
  .ticker-item:first-child {
    border-color: #34c75944;
    background: linear-gradient(135deg, #f0fdf4 0%, #fff 100%);
  }
  .ticker-icon {
    font-size: 18px; line-height: 1;
    width: 28px; height: 28px;
    display: flex; align-items: center; justify-content: center;
    background: #fff; border-radius: 8px;
    flex-shrink: 0;
  }
  .ticker-body { flex: 1; min-width: 0; }
  .ticker-meta {
    display: flex; gap: 8px; align-items: center;
    margin-bottom: 3px; font-size: 10.5px; font-weight: 700;
  }
  .ticker-time { color: #8a7c8e; }
  .ticker-region { color: #1a1625; }
  .ticker-tag {
    background: #5856d622; color: #5856d6;
    padding: 1px 7px; border-radius: 999px;
    font-size: 9.5px; font-weight: 800; letter-spacing: 0.3px;
  }
  .ticker-text { margin: 0; font-size: 12.5px; line-height: 1.5; color: #1a1625; }

  /* ─── Radar ─── */
  .radar-card { margin-top: 22px; }
  .radar-body {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: 28px; align-items: center;
  }
  @media (max-width: 720px) {
    .radar-body { grid-template-columns: 1fr; justify-items: center; }
  }
  .radar-side { min-width: 0; }
  .legend-rows {
    display: flex; gap: 18px; flex-wrap: wrap;
    margin-bottom: 12px;
    font-size: 12px; color: #4a3f51; font-weight: 700;
  }
  .legend-row { display: flex; align-items: center; gap: 8px; }
  .gap-list {
    list-style: none; padding: 0; margin: 0 0 14px;
    display: flex; flex-direction: column; gap: 8px;
  }
  .gap-list li {
    display: flex; align-items: center; gap: 10px;
    padding: 10px 14px;
    background: linear-gradient(90deg, #fff5f8 0%, #fff 100%);
    border-radius: 10px;
    border-left: 3px solid #FE3C72;
    font-size: 12.5px;
  }
  .gap-list strong { font-weight: 800; min-width: 100px; }
  .gap-pill {
    background: #fe3c7222; color: #FE3C72;
    padding: 2px 9px; border-radius: 999px;
    font-size: 11px; font-weight: 800;
  }
  .gap-list em { font-style: normal; color: #8a7c8e; font-size: 11px; }
  .radar-insight {
    margin: 0; font-size: 12.5px; line-height: 1.6; color: #4a3f51;
    background: #5856d610; border-left: 3px solid #5856D6;
    padding: 10px 14px; border-radius: 8px;
  }
  .radar-insight strong { color: #5856D6; }

  /* ─── Impact Forecast ─── */
  .forecast {
    margin-top: 12px;
    background: linear-gradient(135deg, #fff5f8 0%, #fff 100%);
    border-radius: 12px;
    padding: 12px;
    border: 1px dashed #af52de44;
  }
  .forecast-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 10px;
    margin-bottom: 10px;
  }
  .forecast-stat {
    background: #fff; border-radius: 8px;
    padding: 8px 10px;
    border: 1px solid #00000010;
  }
  .forecast-stat strong {
    display: block; font-size: 16px; font-weight: 800;
    background: linear-gradient(135deg, #5856d6, #af52de, #fe3c72);
    -webkit-background-clip: text; -webkit-text-fill-color: transparent;
    background-clip: text;
  }
  .forecast-stat em {
    display: block; font-style: normal;
    font-size: 10px; color: #8a7c8e; margin-top: 2px;
  }
  .stakeholder-row {
    display: flex; flex-wrap: wrap; gap: 6px; align-items: center;
  }
  .stakeholder-label {
    font-size: 10px; font-weight: 800; color: #af52de;
    letter-spacing: 0.4px;
  }
  .stakeholder-pill {
    background: #af52de15; color: #6b3a99;
    font-size: 11px; font-weight: 700;
    padding: 3px 9px; border-radius: 999px;
    border: 1px solid #af52de33;
  }

  /* ─── Empty / Footer ─── */
  .empty { font-size: 12px; color: #8a7c8e; margin: 8px 0 0; }
  .footer {
    margin-top: 32px;
    display: flex; justify-content: space-between; align-items: center;
    font-size: 11px; color: #8a7c8e;
    padding: 16px 0; border-top: 1px solid #00000010;
    flex-wrap: wrap; gap: 12px;
  }
  .footer-actions { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; }
  .cta-print {
    background: linear-gradient(135deg, #5856d6, #af52de, #fe3c72);
    color: #fff; text-decoration: none;
    font-size: 12px; font-weight: 800;
    padding: 8px 16px; border-radius: 999px;
    box-shadow: 0 8px 20px -10px rgba(174,82,222,0.6);
    transition: transform 160ms ease, box-shadow 160ms ease;
    border: 0; cursor: pointer;
    font-family: inherit;
    display: inline-flex; align-items: center; gap: 4px;
  }
  .cta-print:hover {
    transform: translateY(-1px);
    box-shadow: 0 12px 26px -10px rgba(174,82,222,0.7);
  }
  .cta-print:active { transform: translateY(0); }
  .cta-print:focus-visible { outline: 3px solid #af52de66; outline-offset: 2px; }
  .footer-meta { font-size: 11px; color: #8a7c8e; }

  /* ─── Print stylesheet (Ctrl+P → A4 政策簡報) ─── */
  @media print {
    body { background: #fff !important; }
    .dashboard { padding: 12px; max-width: none; }
    .hero {
      background: #5856d6 !important;
      box-shadow: none !important;
      page-break-after: avoid;
    }
    .card, .trend-card {
      box-shadow: none !important;
      page-break-inside: avoid;
      border: 1px solid #00000022 !important;
    }
    .activity-card { display: none; }
    .cta-print, .footer-actions { display: none; }
    .source-pill { display: none; }
    .grid, .geo-row { break-inside: avoid; }
    a { color: inherit; text-decoration: none; }
    .kpi-card {
      background: #fff !important;
      border: 1px solid #00000022 !important;
      color: #1a1625 !important;
    }
    .kpi-label, .kpi-sub { color: #555 !important; }
    .kpi-value { color: #1a1625 !important; }
  }
`;
