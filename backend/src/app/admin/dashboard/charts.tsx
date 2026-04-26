// Pure SVG chart primitives — server-renderable, zero client JS, zero deps.
// Style stays in sync with dashboard/page.tsx via CSS variables.

import type { ReactNode } from "react";

// --------- Taiwan Map: inline SVG from real county GeoJSON ---------
// Source data: letswritetw/letswrite-taiwan-map-basic (taiwan.geojson, 19 縣市).
// Both county polygons AND city bubbles project from the same lon/lat → viewBox
// transform (see lib/taiwanMap.ts), so bubbles always land on the right county.
import {
  loadCountyPaths,
  projectLonLat,
  VB_HEIGHT,
  VB_WIDTH,
} from "@/lib/taiwanMap";

export function TaiwanMap({
  regions,
  width = 230,
  height = 420,
  accent = "#FE3C72",
}: {
  regions: Array<{
    code: string;
    label: string;
    users: number;
    lon: number;
    lat: number;
    topNeed: string;
  }>;
  width?: number;
  height?: number;
  accent?: string;
}) {
  const counties = loadCountyPaths();
  const max = Math.max(...regions.map((r) => r.users), 1);

  return (
    <div className="map-wrap">
      <div className="map-canvas" style={{ width, height }}>
        <svg
          viewBox={`0 0 ${VB_WIDTH} ${VB_HEIGHT}`}
          width={width}
          height={height}
          preserveAspectRatio="xMidYMid meet"
          aria-label="台灣青年資源需求熱點地圖"
        >
          {/* 縣市底圖（灰階） */}
          <g className="map-counties">
            {counties.map((c) => (
              <path
                key={c.id}
                d={c.d}
                fill="#e7e5ea"
                stroke="#9b9aa1"
                strokeWidth={0.12}
                strokeLinejoin="round"
              />
            ))}
          </g>

          {/* 城市氣泡 — 用同一個投影 */}
          <g className="map-bubbles">
            {regions.map((r) => {
              const [bx, by] = projectLonLat(r.lon, r.lat);
              const size = 1.6 + (r.users / max) * 2.6;
              return (
                <g key={r.code}>
                  <circle
                    cx={bx}
                    cy={by}
                    r={size * 1.7}
                    fill={accent}
                    fillOpacity={0.18}
                  />
                  <circle
                    cx={bx}
                    cy={by}
                    r={size}
                    fill={accent}
                    fillOpacity={0.95}
                    stroke="#fff"
                    strokeWidth={0.22}
                  />
                  <text
                    x={bx}
                    y={by + size * 0.34}
                    textAnchor="middle"
                    fontSize={size * 0.85}
                    fontWeight="800"
                    fill="#fff"
                    style={{ fontVariantNumeric: "tabular-nums" }}
                  >
                    {r.users}
                  </text>
                  <g>
                    <rect
                      x={bx - r.label.length * 1.0 - 0.6}
                      y={by + size + 0.4}
                      width={r.label.length * 2.0 + 1.2}
                      height={2.6}
                      rx={0.6}
                      fill="#ffffff"
                      fillOpacity={0.95}
                      stroke="#0000001a"
                      strokeWidth={0.1}
                    />
                    <text
                      x={bx}
                      y={by + size + 2.25}
                      textAnchor="middle"
                      fontSize={1.8}
                      fontWeight="800"
                      fill="#1a1625"
                    >
                      {r.label}
                    </text>
                  </g>
                </g>
              );
            })}
          </g>
        </svg>
      </div>
      <ul className="map-legend">
        {regions
          .slice()
          .sort((a, b) => b.users - a.users)
          .slice(0, 5)
          .map((r) => (
            <li key={r.code}>
              <span className="map-legend-rank" style={{ color: accent }}>
                {r.label}
              </span>
              <span className="map-legend-need">{r.topNeed}</span>
              <strong>{r.users.toLocaleString("zh-TW")}</strong>
            </li>
          ))}
      </ul>
    </div>
  );
}

// --------- Radar Chart (multi-axis demand vs supply) ---------
export function RadarChart({
  dimensions,
  size = 260,
  demandColor = "#FE3C72",
  supplyColor = "#5856D6",
}: {
  dimensions: Array<{ axis: string; demand: number; supply: number }>;
  size?: number;
  demandColor?: string;
  supplyColor?: string;
}) {
  if (dimensions.length < 3) return null;
  const cx = size / 2;
  const cy = size / 2;
  const r = size / 2 - 38;
  const n = dimensions.length;
  const angle = (i: number) => -Math.PI / 2 + (i * 2 * Math.PI) / n;
  const point = (i: number, value: number) => {
    const a = angle(i);
    const rr = (value / 100) * r;
    return [cx + rr * Math.cos(a), cy + rr * Math.sin(a)] as const;
  };
  const polyline = (key: "demand" | "supply") =>
    dimensions
      .map((d, i) => {
        const [x, y] = point(i, d[key]);
        return `${x},${y}`;
      })
      .join(" ");

  return (
    <svg viewBox={`0 0 ${size} ${size}`} width={size} height={size}>
      {/* concentric grid */}
      {[0.25, 0.5, 0.75, 1].map((g, i) => (
        <polygon
          key={g}
          points={dimensions
            .map((_, j) => {
              const [x, y] = point(j, g * 100);
              return `${x},${y}`;
            })
            .join(" ")}
          fill="none"
          stroke="#0000001a"
          strokeWidth={i === 3 ? 1 : 0.5}
        />
      ))}
      {/* axes */}
      {dimensions.map((_, i) => {
        const [x, y] = point(i, 100);
        return (
          <line
            key={i}
            x1={cx}
            y1={cy}
            x2={x}
            y2={y}
            stroke="#00000014"
            strokeWidth="0.5"
          />
        );
      })}
      {/* supply polygon */}
      <polygon
        points={polyline("supply")}
        fill={supplyColor}
        fillOpacity="0.18"
        stroke={supplyColor}
        strokeWidth="2"
      />
      {/* demand polygon */}
      <polygon
        points={polyline("demand")}
        fill={demandColor}
        fillOpacity="0.22"
        stroke={demandColor}
        strokeWidth="2"
      />
      {/* axis labels */}
      {dimensions.map((d, i) => {
        const [x, y] = point(i, 118);
        return (
          <text
            key={i}
            x={x}
            y={y}
            textAnchor="middle"
            dominantBaseline="middle"
            fontSize="10"
            fontWeight="700"
            fill="#1a1625"
          >
            {d.axis}
          </text>
        );
      })}
      {/* data points */}
      {dimensions.map((d, i) => {
        const [dx, dy] = point(i, d.demand);
        const [sx, sy] = point(i, d.supply);
        return (
          <g key={i}>
            <circle cx={sx} cy={sy} r="3" fill={supplyColor} />
            <circle cx={dx} cy={dy} r="3" fill={demandColor} />
          </g>
        );
      })}
    </svg>
  );
}

// --------- Activity Ticker (live-feel feed) ---------
const ACTIVITY_ICONS: Record<string, string> = {
  question: "💬",
  swipe: "❤️",
  todo: "✅",
  startup: "🚀",
  handoff: "🛟",
};

export function ActivityTicker({
  events,
}: {
  events: Array<{
    ts: string;
    type: keyof typeof ACTIVITY_ICONS;
    region: string;
    text: string;
    tag?: string;
  }>;
}) {
  if (events.length === 0) return <p className="empty">尚無動態。</p>;
  return (
    <ol className="ticker">
      {events.map((e, i) => (
        <li key={i} className="ticker-item">
          <span className="ticker-icon">{ACTIVITY_ICONS[e.type] ?? "·"}</span>
          <div className="ticker-body">
            <div className="ticker-meta">
              <span className="ticker-time">{e.ts}</span>
              <span className="ticker-region">{e.region}</span>
              {e.tag && <span className="ticker-tag">{e.tag}</span>}
            </div>
            <p className="ticker-text">{e.text}</p>
          </div>
        </li>
      ))}
    </ol>
  );
}

// --------- Sparkline ---------
export function Sparkline({
  values,
  width = 120,
  height = 36,
  stroke = "rgba(255,255,255,0.95)",
  fill = "rgba(255,255,255,0.18)",
}: {
  values: number[];
  width?: number;
  height?: number;
  stroke?: string;
  fill?: string;
}) {
  if (values.length < 2) return null;
  const max = Math.max(...values);
  const min = Math.min(...values);
  const range = Math.max(1, max - min);
  const stepX = width / (values.length - 1);
  const points = values.map((v, i) => {
    const x = i * stepX;
    const y = height - ((v - min) / range) * (height - 4) - 2;
    return [x, y] as const;
  });
  const linePath = points
    .map(([x, y], i) => (i === 0 ? `M${x},${y}` : `L${x},${y}`))
    .join(" ");
  const areaPath = `${linePath} L${width},${height} L0,${height} Z`;
  return (
    <svg
      viewBox={`0 0 ${width} ${height}`}
      width="100%"
      height={height}
      preserveAspectRatio="none"
      aria-hidden="true"
    >
      <path d={areaPath} fill={fill} />
      <path
        d={linePath}
        fill="none"
        stroke={stroke}
        strokeWidth={1.5}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      {points.map(([x, y], i) =>
        i === points.length - 1 ? (
          <circle key={i} cx={x} cy={y} r={2.5} fill={stroke} />
        ) : null,
      )}
    </svg>
  );
}

// --------- Horizontal Bar (used for Top Questions) ---------
export function HorizontalBars({
  rows,
  accent,
  showRank = true,
}: {
  rows: Array<{
    label: string;
    value: number;
    badge?: string;
    badgeColor?: string;
  }>;
  accent: string;
  showRank?: boolean;
}) {
  if (rows.length === 0) return <p className="empty">尚無資料。</p>;
  const max = Math.max(...rows.map((r) => r.value), 1);
  return (
    <ol className="hbar-list">
      {rows.map((r, i) => {
        const ratio = Math.max(0.04, r.value / max);
        return (
          <li key={i} className="hbar">
            <div className="hbar-header">
              {showRank && <span className="rank-pill">{i + 1}</span>}
              <span className="hbar-label">{r.label}</span>
              {r.badge && (
                <span
                  className="urgency-pill"
                  style={{
                    background: `${r.badgeColor ?? accent}1f`,
                    color: r.badgeColor ?? accent,
                  }}
                >
                  {r.badge}
                </span>
              )}
            </div>
            <div className="hbar-row">
              <div className="hbar-track">
                <div
                  className="hbar-fill"
                  style={{
                    width: `${ratio * 100}%`,
                    background: `linear-gradient(90deg, ${accent}, ${accent}cc)`,
                  }}
                />
              </div>
              <span className="hbar-value">{r.value.toLocaleString("zh-TW")}</span>
            </div>
          </li>
        );
      })}
    </ol>
  );
}

// --------- Vertical Bar Chart (used for Career Paths) ---------
export function VerticalBars({
  rows,
  accent,
  height = 220,
  unit = "",
}: {
  rows: Array<{ label: string; value: number; sub?: string }>;
  accent: string;
  height?: number;
  unit?: string;
}) {
  if (rows.length === 0) return <p className="empty">尚無資料。</p>;
  const max = Math.max(...rows.map((r) => r.value), 1);
  const w = 100 / rows.length;
  return (
    <div className="vbar-wrap" style={{ height }}>
      <div className="vbar-grid" style={{ height: height - 36 }}>
        <span style={{ top: 0 }}>{Math.round(max).toLocaleString("zh-TW")}</span>
        <span style={{ top: "33%" }}>
          {Math.round(max * 0.66).toLocaleString("zh-TW")}
        </span>
        <span style={{ top: "66%" }}>
          {Math.round(max * 0.33).toLocaleString("zh-TW")}
        </span>
        <span style={{ top: "100%" }}>0</span>
      </div>
      <div className="vbar-canvas" style={{ height: height - 36 }}>
        {rows.map((r, i) => {
          const h = (r.value / max) * 100;
          return (
            <div
              key={i}
              className="vbar-col"
              style={{ left: `${i * w}%`, width: `${w}%` }}
            >
              <span className="vbar-num">{r.value.toLocaleString("zh-TW")}</span>
              <div
                className="vbar-bar"
                style={{
                  height: `${h}%`,
                  background: `linear-gradient(180deg, ${accent} 0%, ${accent}cc 60%, ${accent}80 100%)`,
                }}
              />
            </div>
          );
        })}
      </div>
      <div className="vbar-axis">
        {rows.map((r, i) => (
          <span key={i} className="vbar-tick" style={{ width: `${w}%` }}>
            {r.label}
            {r.sub && <em>{r.sub}</em>}
          </span>
        ))}
      </div>
      {unit && <span className="vbar-unit">單位：{unit}</span>}
    </div>
  );
}

// --------- Donut Chart (used for Skill Gaps and Startup Needs) ---------
export function Donut({
  segments,
  size = 180,
  thickness = 28,
  centerLabel,
  centerValue,
}: {
  segments: Array<{ label: string; value: number; color: string }>;
  size?: number;
  thickness?: number;
  centerLabel?: string;
  centerValue?: ReactNode;
}) {
  if (segments.length === 0) return <p className="empty">尚無資料。</p>;
  const total = segments.reduce((s, x) => s + x.value, 0) || 1;
  const r = (size - thickness) / 2;
  const c = size / 2;
  const circumference = 2 * Math.PI * r;
  let offset = 0;
  return (
    <div className="donut-wrap">
      <svg
        viewBox={`0 0 ${size} ${size}`}
        width={size}
        height={size}
        aria-hidden="true"
      >
        <circle
          cx={c}
          cy={c}
          r={r}
          fill="none"
          stroke="#faf3f5"
          strokeWidth={thickness}
        />
        {segments.map((seg, i) => {
          const len = (seg.value / total) * circumference;
          const dasharray = `${len} ${circumference - len}`;
          const dashoffset = -offset;
          offset += len;
          return (
            <circle
              key={i}
              cx={c}
              cy={c}
              r={r}
              fill="none"
              stroke={seg.color}
              strokeWidth={thickness}
              strokeDasharray={dasharray}
              strokeDashoffset={dashoffset}
              strokeLinecap="butt"
              transform={`rotate(-90 ${c} ${c})`}
            />
          );
        })}
      </svg>
      <div className="donut-center">
        {centerValue !== undefined && (
          <div className="donut-value">{centerValue}</div>
        )}
        {centerLabel && <div className="donut-label">{centerLabel}</div>}
      </div>
    </div>
  );
}

export function Legend({
  items,
}: {
  items: Array<{ label: string; value: number; color: string; pct?: number }>;
}) {
  return (
    <ul className="legend">
      {items.map((it, i) => (
        <li key={i}>
          <span
            className="legend-dot"
            style={{ background: it.color }}
            aria-hidden="true"
          />
          <span className="legend-label">{it.label}</span>
          <span className="legend-value">
            {it.value.toLocaleString("zh-TW")}
            {it.pct !== undefined && (
              <em className="legend-pct">  {it.pct.toFixed(0)}%</em>
            )}
          </span>
        </li>
      ))}
    </ul>
  );
}

// --------- Radial Gauge (used for stuck-task escalation) ---------
export function RadialGauge({
  value,
  max,
  label,
  unit,
  color,
  size = 120,
}: {
  value: number;
  max: number;
  label: string;
  unit?: string;
  color: string;
  size?: number;
}) {
  const ratio = Math.min(1, Math.max(0, value / Math.max(1, max)));
  const r = (size - 14) / 2;
  const c = size / 2;
  const arcLen = Math.PI * r; // half circle
  const filled = arcLen * ratio;
  return (
    <div className="gauge-wrap" style={{ width: size }}>
      <svg
        viewBox={`0 0 ${size} ${size / 2 + 10}`}
        width={size}
        height={size / 2 + 10}
        aria-hidden="true"
      >
        <path
          d={`M ${c - r} ${c} A ${r} ${r} 0 0 1 ${c + r} ${c}`}
          fill="none"
          stroke="#faf3f5"
          strokeWidth={10}
          strokeLinecap="round"
        />
        <path
          d={`M ${c - r} ${c} A ${r} ${r} 0 0 1 ${c + r} ${c}`}
          fill="none"
          stroke={color}
          strokeWidth={10}
          strokeLinecap="round"
          strokeDasharray={`${filled} ${arcLen - filled}`}
        />
      </svg>
      <div className="gauge-readout">
        <strong style={{ color }}>{value}</strong>
        {unit && <em>{unit}</em>}
        <span>{label}</span>
      </div>
    </div>
  );
}

// --------- Area Chart (full-width trend, used inside hero or section) ---------
export function AreaChart({
  values,
  labels,
  width = 600,
  height = 140,
  color = "#5856D6",
  fillOpacity = 0.25,
}: {
  values: number[];
  labels: string[];
  width?: number;
  height?: number;
  color?: string;
  fillOpacity?: number;
}) {
  if (values.length < 2) return null;
  const padX = 24;
  const padTop = 12;
  const padBottom = 26;
  const innerW = width - padX * 2;
  const innerH = height - padTop - padBottom;
  const max = Math.max(...values);
  const min = Math.min(...values);
  const range = Math.max(1, max - min);
  const stepX = innerW / (values.length - 1);
  const pts = values.map((v, i) => {
    const x = padX + i * stepX;
    const y = padTop + (1 - (v - min) / range) * innerH;
    return [x, y] as const;
  });
  const linePath = pts
    .map(([x, y], i) => (i === 0 ? `M${x},${y}` : `L${x},${y}`))
    .join(" ");
  const areaPath = `${linePath} L${pts[pts.length - 1][0]},${padTop + innerH} L${pts[0][0]},${padTop + innerH} Z`;
  return (
    <svg
      viewBox={`0 0 ${width} ${height}`}
      width="100%"
      height={height}
      preserveAspectRatio="none"
      aria-hidden="true"
    >
      <defs>
        <linearGradient id={`area-grad-${color.replace("#", "")}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity={fillOpacity * 1.4} />
          <stop offset="100%" stopColor={color} stopOpacity={0} />
        </linearGradient>
      </defs>
      {[0.25, 0.5, 0.75].map((g) => (
        <line
          key={g}
          x1={padX}
          x2={width - padX}
          y1={padTop + innerH * g}
          y2={padTop + innerH * g}
          stroke="#0000000d"
          strokeDasharray="2 4"
        />
      ))}
      <path d={areaPath} fill={`url(#area-grad-${color.replace("#", "")})`} />
      <path
        d={linePath}
        fill="none"
        stroke={color}
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      {pts.map(([x, y], i) => (
        <circle
          key={i}
          cx={x}
          cy={y}
          r={i === pts.length - 1 ? 4 : 2.5}
          fill={color}
        />
      ))}
      {labels.map((lab, i) => {
        const x = padX + i * stepX;
        return (
          <text
            key={i}
            x={x}
            y={height - 8}
            textAnchor="middle"
            fontSize="10"
            fill="#8A7C8E"
          >
            {lab}
          </text>
        );
      })}
    </svg>
  );
}
