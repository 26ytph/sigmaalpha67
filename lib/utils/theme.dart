import 'package:flutter/cupertino.dart';

/// 整體調性：交友軟體（Tinder/Bumble）風 — 暖粉漸層、心型圖騰、柔焦白卡。
/// AI 相關用紫色／靛色微點綴（保留辨識度）。
class AppColors {
  AppColors._();

  // —— 背景：奶油粉 + 漸層紗 ——
  static const bg = Color(0xFFFFF5F8);
  static const bgAlt = Color(0xFFFFE4EC);
  static const bgPeach = Color(0xFFFFEFE7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFFAF3F5);

  // —— 文字 ——
  static const textPrimary = Color(0xFF1F1A24);
  static const textSecondary = Color(0xFF4A3F51);
  static const textTertiary = Color(0xFF8A7C8E);
  static const textMuted = Color(0xFFAEAEB2);

  // —— 細線 ——
  static const border = Color(0x14000000);
  static const separator = Color(0x1FFE3C72);
  static const borderStrong = Color(0x26000000);

  // —— 主品牌：熱粉 → 珊瑚 → 日落 ——
  static const brandStart = Color(0xFFFE3C72);
  static const brandMid = Color(0xFFFF655B);
  static const brandEnd = Color(0xFFFFA463);

  // —— iOS / 系統色（保留兼容）——
  static const iosBlue = Color(0xFF007AFF);
  static const iosGreen = Color(0xFF34C759);
  static const iosOrange = Color(0xFFFF9500);
  static const iosRed = Color(0xFFFF3B30);
  static const iosPurple = Color(0xFFAF52DE);
  static const iosTeal = Color(0xFF5AC8FA);

  // —— 兼容舊命名 ——
  static const accentIndigo = Color(0xFF5856D6);
  static const accentPurple = iosPurple;
  static const accentMagenta = brandStart;
  static const accentSky = iosTeal;
  static const accentEmerald = iosGreen;
  static const accentRose = brandStart;
  static const accentAmber = iosOrange;
  static const ok = iosGreen;
  static const warn = iosOrange;

  // —— 漸層 ——
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandStart, brandMid, brandEnd],
  );

  static const heartGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7ABF), Color(0xFFFE3C72), Color(0xFFFF655B)],
  );

  static const softGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x40FE3C72), Color(0x40FFA463)],
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

  // —— 陰影：粉色暈，仿 Tinder 浮起感 ——
  static const shadow = [
    BoxShadow(
      blurRadius: 28,
      offset: Offset(0, 14),
      color: Color(0x33FE3C72),
    ),
  ];

  static const shadowSoft = [
    BoxShadow(
      blurRadius: 16,
      offset: Offset(0, 8),
      color: Color(0x1AFE3C72),
    ),
  ];

  static const shadowNeutral = [
    BoxShadow(
      blurRadius: 10,
      offset: Offset(0, 4),
      color: Color(0x141F1A24),
    ),
  ];
}

class AppRadii {
  AppRadii._();
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
  static const xxl = 32.0;
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
