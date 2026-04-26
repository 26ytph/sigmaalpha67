/**
 * 諮詢師端前端共用主題色 — 對齊 lib/utils/theme.dart 的 Tinder/Bumble 風暖粉漸層。
 * 為了不引入額外依賴，這裡只是常數，靠 inline style 套用。
 */

export const colors = {
  bg: "#FFF5F8",
  bgAlt: "#FFE4EC",
  bgPeach: "#FFEFE7",
  surface: "#FFFFFF",
  surfaceMuted: "#FAF3F5",

  textPrimary: "#1F1A24",
  textSecondary: "#4A3F51",
  textTertiary: "#8A7C8E",
  textMuted: "#AEAEB2",

  border: "rgba(0,0,0,0.08)",
  separator: "rgba(254,60,114,0.12)",
  borderStrong: "rgba(0,0,0,0.15)",

  brandStart: "#FE3C72",
  brandMid: "#FF655B",
  brandEnd: "#FFA463",

  iosBlue: "#007AFF",
  iosGreen: "#34C759",
  iosRed: "#FF3B30",
  iosPurple: "#AF52DE",
  iosTeal: "#5AC8FA",

  accentIndigo: "#5856D6",
};

export const radii = {
  sm: 10,
  md: 14,
  lg: 18,
  xl: 24,
  xxl: 32,
  pill: 999,
};

export const gradients = {
  bg: `linear-gradient(135deg, ${colors.bg} 0%, ${colors.bgAlt} 50%, ${colors.bgPeach} 100%)`,
  brand: `linear-gradient(135deg, ${colors.brandStart} 0%, ${colors.brandMid} 50%, ${colors.brandEnd} 100%)`,
  heart: `linear-gradient(135deg, #FF7ABF 0%, ${colors.brandStart} 50%, ${colors.brandMid} 100%)`,
  ai: `linear-gradient(135deg, ${colors.accentIndigo} 0%, ${colors.iosPurple} 50%, ${colors.brandStart} 100%)`,
  hero: "linear-gradient(135deg, #FFE4EC 0%, #FFEFE1 50%, #FCE7F3 100%)",
};

export const shadows = {
  brand: "0 14px 28px rgba(254,60,114,0.20)",
  soft: "0 8px 16px rgba(254,60,114,0.10)",
  neutral: "0 4px 10px rgba(31,26,36,0.08)",
};

export const fontStack =
  '-apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang TC", "Microsoft JhengHei", "Helvetica Neue", Arial, sans-serif';
