import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../data/roles.dart';
import '../models/models.dart';
import '../services/app_repository.dart';
import '../utils/theme.dart';
import '../widgets/explore_photo_card.dart';
import '../widgets/swipe_card.dart';

const _promptEvery = 10;

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
  late List<CareerRole> _deck;
  int _deckIdx = 0;

  // 累積到下次 prompt 還差幾張（重啟 session 重置，避免 app 重開時被舊計數困住）
  int _sinceLastPrompt = 0;
  bool _promptOpen = false;

  @override
  void initState() {
    super.initState();
    _deck = [...roles]..shuffle();
  }

  CareerRole get _current => _deck[_deckIdx % _deck.length];
  CareerRole get _next => _deck[(_deckIdx + 1) % _deck.length];

  Future<void> _persist(AppStorage Function(AppStorage prev) fn) async {
    final next = await AppRepository.update(fn);
    if (!mounted) return;
    widget.onStorageChanged(next);
  }

  void _swipe(SwipeDirection dir) {
    final role = _current;
    unawaited(
      AppRepository.recordSwipe(
        cardId: role.id,
        liked: dir == SwipeDirection.right,
      ),
    );

    _persist((prev) {
      final liked = [...prev.explore.likedRoleIds];
      final disliked = [...prev.explore.dislikedRoleIds];

      if (dir == SwipeDirection.right) {
        disliked.remove(role.id);
        if (!liked.contains(role.id)) liked.add(role.id);
      } else {
        liked.remove(role.id);
        if (!disliked.contains(role.id)) disliked.add(role.id);
      }

      return prev.copyWith(
        explore: prev.explore.copyWith(
          likedRoleIds: liked,
          dislikedRoleIds: disliked,
          swipeCount: prev.explore.swipeCount + 1,
        ),
      );
    });

    setState(() {
      _deckIdx++;
      _sinceLastPrompt++;
      // 卡組用完一輪重新洗牌，達成「無限滑卡」
      if (_deckIdx % _deck.length == 0) {
        _deck = [...roles]..shuffle();
      }
    });

    if (_sinceLastPrompt >= _promptEvery && !_promptOpen) {
      _askForUpdate();
    }
  }

  Future<void> _askForUpdate() async {
    _promptOpen = true;
    final yes = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('要更新興趣與計畫嗎？'),
        content: Text(
          '你已經滑了 $_sinceLastPrompt 張卡。要根據新的喜好重新整理 Persona 的興趣方向，'
          '並讓「計畫」更貼近你最近的選擇嗎？',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('稍後再說'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('現在更新'),
          ),
        ],
      ),
    );
    _promptOpen = false;
    setState(() => _sinceLastPrompt = 0);

    if (yes != true) return;
    final next = await AppRepository.refreshPersonaFromBackend();
    if (!mounted) return;
    widget.onStorageChanged(next);
  }

  Future<void> _resetExplore() async {
    final go = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('清空滑卡紀錄？'),
        content: const Text('將清掉目前的喜歡 / 不喜歡與滑卡計數。Persona 既有資料保留。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (go != true) return;
    await _persist(
      (prev) => prev.copyWith(
        explore: const ExploreResults(likedRoleIds: [], dislikedRoleIds: []),
      ),
    );
    setState(() {
      _deckIdx = 0;
      _sinceLastPrompt = 0;
      _deck = [...roles]..shuffle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final likedCount = widget.storage.explore.likedRoleIds.length;
    final totalSwipes = widget.storage.explore.swipeCount;
    final towardNext = _promptEvery - _sinceLastPrompt;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '興趣探索',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          AppGaps.h2,
                          Text(
                            '無限滑卡',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                CupertinoIcons.heart_fill,
                                size: 12,
                                color: AppColors.brandStart,
                              ),
                              AppGaps.w4,
                              Text(
                                '$likedCount',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandStart,
                                ),
                              ),
                              AppGaps.w8,
                              Text(
                                '已滑 $totalSwipes',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          AppGaps.h2,
                          Text(
                            '再滑 $towardNext 張更新建議',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  AppGaps.h12,
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: SizedBox(
                      height: 4,
                      child: Stack(
                        children: [
                          const ColoredBox(color: AppColors.border),
                          FractionallySizedBox(
                            widthFactor: _sinceLastPrompt / _promptEvery,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: AppColors.brandGradient,
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
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, 8),
                        child: Transform.scale(
                          scale: 0.985,
                          child: Opacity(
                            opacity: 0.7,
                            child: ExplorePhotoCard(role: _next),
                          ),
                        ),
                      ),
                      SwipeCard(
                        onSwipe: _swipe,
                        child: ExplorePhotoCard(role: _current),
                      ),
                    ],
                  ),
                  AppGaps.h20,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoundSwipeButton(
                        label: 'PASS',
                        size: 64,
                        bg: AppColors.surface,
                        iconColor: AppColors.iosRed,
                        icon: CupertinoIcons.xmark,
                        onPressed: () => _swipe(SwipeDirection.left),
                      ),
                      const SizedBox(width: 36),
                      _RoundSwipeButton(
                        label: 'LIKE',
                        size: 80,
                        gradient: AppColors.brandGradient,
                        iconColor: CupertinoColors.white,
                        icon: CupertinoIcons.heart_fill,
                        onPressed: () => _swipe(SwipeDirection.right),
                      ),
                    ],
                  ),
                  AppGaps.h12,
                  Center(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      onPressed: _resetExplore,
                      child: const Text(
                        '清空滑卡紀錄',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
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
    required this.icon,
    required this.iconColor,
    required this.onPressed,
    this.size = 64,
    this.bg,
    this.gradient,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onPressed;
  final double size;
  final Color? bg;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: gradient == null ? (bg ?? AppColors.surface) : null,
              gradient: gradient,
              shape: BoxShape.circle,
              boxShadow: gradient != null
                  ? AppColors.shadow
                  : AppColors.shadowSoft,
            ),
            child: Icon(icon, color: iconColor, size: size * 0.42),
          ),
        ),
        AppGaps.h6,
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
