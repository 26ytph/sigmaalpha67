import 'package:flutter/cupertino.dart';

import '../models/models.dart';

int _stableHue(String s) {
  var h = 0;
  for (var i = 0; i < s.length; i++) {
    h = (h * 31 + s.codeUnitAt(i)) & 0x7fffffff;
  }
  return h;
}

class ExplorePhotoCard extends StatelessWidget {
  const ExplorePhotoCard({super.key, required this.role});

  final CareerRole role;

  @override
  Widget build(BuildContext context) {
    final hue = _stableHue(role.id) % 360;
    final subtitle = role.tags.isNotEmpty ? role.tags.first.wireName : 'career';

    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 40,
            offset: Offset(0, 24),
            color: Color(0x24020617),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 2,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        HSVColor.fromAHSV(1, hue.toDouble(), 0.35, 0.95).toColor(),
                        HSVColor.fromAHSV(1, (hue + 40) % 360.0, 0.45, 0.88).toColor(),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0x66F4F4F5),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    CupertinoIcons.briefcase_fill,
                    size: 72,
                    color: CupertinoColors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xCCF4F4F5),
              border: Border(top: BorderSide(color: Color(0x1A000000))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  role.tagline,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xFF3F3F46),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...role.tags.map(
                      (t) => _TagChip(label: t.wireName),
                    ),
                    _TagChip(label: subtitle),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _BulletsCard(
                        title: '代表技能',
                        accent: const Color(0xB30EA5E9),
                        items: role.skills.take(5).toList(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BulletsCard(
                        title: '日常工作',
                        accent: const Color(0xB3D946EF),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Color(0xFF3F3F46)),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: Color(0xFF52525B),
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF18181B)),
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
