import 'package:flutter/cupertino.dart';

import '../data/roles.dart';
import '../models/models.dart';
import '../services/app_repository.dart';
import '../widgets/explore_photo_card.dart';
import '../widgets/swipe_card.dart';

List<T> _uniq<T>(List<T> items) {
  final seen = <T>{};
  final out = <T>[];
  for (final x in items) {
    if (seen.add(x)) out.add(x);
  }
  return out;
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.storage,
    required this.onStorageChanged,
    required this.onGoToPlan,
  });

  final AppStorage storage;
  final ValueChanged<AppStorage> onStorageChanged;
  final VoidCallback onGoToPlan;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  Future<void> _persist(AppStorage Function(AppStorage prev) fn) async {
    final next = await AppRepository.update(fn);
    widget.onStorageChanged(next);
  }

  void _swipe(SwipeDirection dir) {
    final swiped = <String>{
      ...widget.storage.explore.likedRoleIds,
      ...widget.storage.explore.dislikedRoleIds,
    };
    final remaining = roles.where((r) => !swiped.contains(r.id)).toList();
    final current = remaining.isNotEmpty ? remaining.first : null;
    if (current == null) return;

    final roleId = current.id;
    _persist((prev) {
      final liked = List<String>.from(prev.explore.likedRoleIds);
      final disliked = List<String>.from(prev.explore.dislikedRoleIds);
      final nextLiked = dir == SwipeDirection.right ? _uniq([...liked, roleId]) : liked;
      final nextDisliked = dir == SwipeDirection.left ? _uniq([...disliked, roleId]) : disliked;

      final nextSwiped = <String>{...nextLiked, ...nextDisliked};

      final completedAt = nextSwiped.length >= roles.length
          ? DateTime.now().toUtc().toIso8601String()
          : prev.explore.exploreCompletedAt;

      return prev.copyWith(
        explore: ExploreResults(
          likedRoleIds: nextLiked,
          dislikedRoleIds: nextDisliked,
          exploreCompletedAt: completedAt,
        ),
      );
    });
  }

  void _reset() {
    _persist(
      (prev) => prev.copyWith(
        explore: const ExploreResults(likedRoleIds: [], dislikedRoleIds: []),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final swiped = <String>{
      ...widget.storage.explore.likedRoleIds,
      ...widget.storage.explore.dislikedRoleIds,
    };
    final remaining = roles.where((r) => !swiped.contains(r.id)).toList();
    final current = remaining.isNotEmpty ? remaining.first : null;
    final next = remaining.length > 1 ? remaining[1] : null;

    final likedCount = widget.storage.explore.likedRoleIds.length;
    final totalCount = roles.length;
    final doneCount = swiped.length;
    final pct = totalCount == 0 ? 0 : ((doneCount / totalCount) * 100).round();

    final likedRoles = roles.where((r) => widget.storage.explore.likedRoleIds.contains(r.id)).toList();
    final topLiked = likedRoles.take(3).toList();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('興趣探索', style: TextStyle(fontSize: 13, color: Color(0xFF52525B))),
                          SizedBox(height: 4),
                          Text(
                            '左滑／右滑',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.3),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('進度 $doneCount/$totalCount', style: const TextStyle(fontSize: 13, color: Color(0xFF52525B))),
                          Text('已喜歡 $likedCount', style: const TextStyle(fontSize: 13, color: Color(0xFF3F3F46))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 8,
                      child: Stack(
                        children: [
                          const ColoredBox(color: Color(0x1A000000)),
                          FractionallySizedBox(
                            widthFactor: pct / 100.0,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0x9938BDF8), Color(0x99D946EF)],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                children: [
                  if (current != null) ...[
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (next != null)
                          Transform.translate(
                            offset: const Offset(0, 8),
                            child: Transform.scale(
                              scale: 0.985,
                              child: Opacity(
                                opacity: 0.7,
                                child: ExplorePhotoCard(role: next),
                              ),
                            ),
                          ),
                        SwipeCard(
                          onSwipe: _swipe,
                          child: ExplorePhotoCard(role: current),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0x1A000000)),
                        boxShadow: const [
                          BoxShadow(blurRadius: 40, offset: Offset(0, 22), color: Color(0x1F020617)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('已完成探索', style: TextStyle(fontSize: 13, color: Color(0xFF52525B))),
                          const SizedBox(height: 6),
                          const Text(
                            '你的興趣摘要',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 16),
                          if (topLiked.isNotEmpty)
                            Column(
                              children: [
                                for (final r in topLiked)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0x1A000000)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(r.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 6),
                                          Text(r.tagline, style: const TextStyle(fontSize: 13, color: Color(0xFF3F3F46))),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          else
                            const Text(
                              '你目前沒有按過「有興趣」，也沒關係；可以再探索一次看看。',
                              style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF3F3F46)),
                            ),
                          const SizedBox(height: 18),
                          CupertinoButton.filled(
                            onPressed: widget.onGoToPlan,
                            child: const Text('前往職涯計畫'),
                          ),
                          const SizedBox(height: 10),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            color: CupertinoColors.white,
                            onPressed: _reset,
                            child: const Text(
                              '重新探索',
                              style: TextStyle(color: Color(0xFF18181B), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoundSwipeButton(
                        label: '左滑不喜歡',
                        color: const Color(0xFFE11D48),
                        icon: CupertinoIcons.xmark,
                        onPressed: current == null ? null : () => _swipe(SwipeDirection.left),
                      ),
                      const SizedBox(width: 56),
                      _RoundSwipeButton(
                        label: '右滑喜歡',
                        color: const Color(0xFF059669),
                        icon: CupertinoIcons.heart_fill,
                        onPressed: current == null ? null : () => _swipe(SwipeDirection.right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '也可以直接拖曳卡片左右滑動',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF52525B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundSwipeButton extends StatelessWidget {
  const _RoundSwipeButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x1A000000)),
              boxShadow: const [
                BoxShadow(blurRadius: 22, offset: Offset(0, 14), color: Color(0x24020617)),
              ],
            ),
            child: Icon(icon, color: color, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF52525B))),
      ],
    );
  }
}
