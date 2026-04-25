import 'package:flutter/cupertino.dart';

/// 整體調性：以 iOS（Settings.app）為主軸 — 使用 systemGroupedBackground、
/// 白色 inset list 卡與細線分隔；品牌粉只保留在主要 CTA 與 Explore 滑卡情境，
/// 其他畫面以 iOS 系統色為主。
class AppColors {
  AppColors._();

  // —— iOS system background ——
  static const bg = Color(0xFFF2F2F7);             // systemGroupedBackground
  static const bgAlt = Color(0xFFFFE4EC);          // 給 hero 用的暖粉
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF2F2F7);

  // —— iOS text ——
  static const textPrimary = Color(0xFF000000);
  static const textSecondary = Color(0xFF3C3C43);  // 60% in iOS spec
  static const textTertiary = Color(0xFF8E8E93);
  static const textMuted = Color(0xFFAEAEB2);

  // —— iOS hairlines ——
  static const border = Color(0xFFE5E5EA);
  static const separator = Color(0xFFC6C6C8);
  static const borderStrong = Color(0xFFD1D1D6);

  // —— iOS system semantic ——
  static const iosBlue = Color(0xFF007AFF);
  static const iosGreen = Color(0xFF34C759);
  static const iosOrange = Color(0xFFFF9500);
  static const iosRed = Color(0xFFFF3B30);
  static const iosPurple = Color(0xFFAF52DE);
  static const iosTeal = Color(0xFF5AC8FA);

  // —— Brand（CTA / 滑卡 用）——
  static const brandStart = Color(0xFFFE3C72);
  static const brandMid = Color(0xFFFF655B);
  static const brandEnd = Color(0xFFFFA463);

  // —— 兼容舊命名（其他畫面引用過）——
  static const accentIndigo = Color(0xFF5856D6);   // iOS indigo
  static const accentPurple = iosPurple;
  static const accentMagenta = brandStart;
  static const accentSky = iosTeal;
  static const accentEmerald = iosGreen;
  static const accentRose = iosRed;
  static const accentAmber = iosOrange;
  static const ok = iosGreen;
  static const warn = iosOrange;

  // —— 漸層 ——
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandStart, brandMid, brandEnd],
  );

  static const softGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x33FE3C72), Color(0x33FFA463)],
  );

  static const aiGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentIndigo, accentPurple, brandStart],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE4EC), Color(0xFFFFEFE1), Color(0xFFFCE7F3)],
  );

  // 創業模式專屬色（暖橘）
  static const startupGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB347), Color(0xFFFE8A4F), Color(0xFFFE3C72)],
  );

  // —— 陰影（iOS 系統卡片風格，極輕）——
  static const shadow = [
    BoxShadow(
      blurRadius: 16,
      offset: Offset(0, 4),
      color: Color(0x14000000),
    ),
  ];

  static const shadowSoft = [
    BoxShadow(
      blurRadius: 8,
      offset: Offset(0, 2),
      color: Color(0x0A000000),
    ),
  ];

  static const shadowNeutral = [
    BoxShadow(
      blurRadius: 6,
      offset: Offset(0, 2),
      color: Color(0x08000000),
    ),
  ];
}

class AppRadii {
  AppRadii._();
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 14.0;
  static const xl = 18.0;
  static const xxl = 24.0;
  static const pill = 999.0;
}

class AppGaps {
  AppGaps._();
  static const SizedBox h2 = SizedBox(height: 2);
  static const SizedBox h4 = SizedBox(height: 4);
  static const SizedBox h6 = SizedBox(height: 6);
  static const SizedBox h8 = SizedBox(height: 8);
  static const SizedBox h10 = SizedBox(height: 10);
  static const SizedBox h12 = SizedBox(height: 12);
  static const SizedBox h14 = SizedBox(height: 14);
  static const SizedBox h16 = SizedBox(height: 16);
  static const SizedBox h20 = SizedBox(height: 20);
  static const SizedBox h24 = SizedBox(height: 24);
  static const SizedBox w4 = SizedBox(width: 4);
  static const SizedBox w6 = SizedBox(width: 6);
  static const SizedBox w8 = SizedBox(width: 8);
  static const SizedBox w10 = SizedBox(width: 10);
  static const SizedBox w12 = SizedBox(width: 12);
}
