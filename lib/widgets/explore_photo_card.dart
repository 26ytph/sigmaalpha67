import 'package:flutter/cupertino.dart';

import '../models/models.dart';
import '../utils/theme.dart';

int _stableHue(String s) {
  var h = 0;
  for (var i = 0; i < s.length; i++) {
    h = (h * 31 + s.codeUnitAt(i)) & 0x7fffffff;
  }
  return h;
}

/// 交友軟體風的職位卡：上半佔比更大、漸層更飽和；底部有半透明黑漸層讓字更易讀；
/// 標題改為大字 + 標籤分別呈現，類似 Tinder Profile 卡。
class ExplorePhotoCard extends StatelessWidget {
  const ExplorePhotoCard({super.key, required this.role});

  final CareerRole role;

  @override
  Widget build(BuildContext context) {
    final hue = _stableHue(role.id) % 360;
    final hasImage = role.imageSrc.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        boxShadow: AppColors.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.05,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 底層：彩色漸層（圖片載入失敗時當 fallback 也好看）
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        HSVColor.fromAHSV(1, hue.toDouble(), 0.55, 0.98).toColor(),
                        HSVColor.fromAHSV(1, (hue + 60) % 360.0, 0.65, 0.85).toColor(),
                        HSVColor.fromAHSV(1, (hue + 120) % 360.0, 0.55, 0.78).toColor(),
                      ],
                    ),
                  ),
                ),
                // 主圖（jobs_img/<role>.png）
                if (hasImage)
                  Image.asset(
                    role.imageSrc,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(
                      child: Icon(
                        CupertinoIcons.briefcase_fill,
                        size: 96,
                        color: CupertinoColors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                else
                  Center(
                    child: Icon(
                      CupertinoIcons.briefcase_fill,
                      size: 96,
                      color: CupertinoColors.white.withValues(alpha: 0.5),
                    ),
                  ),
                // 底部黑色漸層（讓白字易讀）
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0x00000000),
                        Color(0x66000000),
                        Color(0xCC000000),
                      ],
                      stops: [0.0, 0.45, 0.78, 1.0],
                    ),
                  ),
                ),
                // 左下：標題與 tagline 疊在卡片照片上
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: CupertinoColors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 8,
                              offset: Offset(0, 2),
                              color: Color(0x80000000),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        role.tagline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 下半：技能 / 日常工作（兩欄）
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: const BoxDecoration(color: AppColors.surface),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in role.tags) _TagChip(label: '#${t.label}'),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _BulletsCard(
                        title: '代表技能',
                        accent: AppColors.accentIndigo,
                        items: role.skills.take(5).toList(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BulletsCard(
                        title: '日常工作',
                        accent: AppColors.brandStart,
                        items: role.dayToDay.take(5).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.brandStart,
        ),
      ),
    );
  }
}

class _BulletsCard extends StatelessWidget {
  const _BulletsCard({
    required this.title,
    required this.accent,
    required this.items,
  });

  final String title;
  final Color accent;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                          color: accent, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
