import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../data/roles.dart';
import '../data/startup_skills.dart';
import '../models/models.dart';
import '../services/app_repository.dart';
import '../utils/theme.dart';
import '../widgets/explore_photo_card.dart';
import '../widgets/swipe_card.dart';

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
  // 記住 deck 是用哪一個來源洗的，當 user 在 PersonaScreen 切換創業／求職模式時
  // 我們可以偵測並重洗。
  late bool _deckIsStartup;

  bool get _isStartup => widget.storage.profile.startupInterest;

  List<CareerRole> _sourceDeck() => _isStartup ? startupSkills : roles;

  @override
  void initState() {
    super.initState();
    _deckIsStartup = _isStartup;
    _deck = [..._sourceDeck()]..shuffle();
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 模式切換 → 重新洗一副新牌組（已被滑過的舊紀錄保留在 likedRoleIds）。
    if (_isStartup != _deckIsStartup) {
      setState(() {
        _deckIsStartup = _isStartup;
        _deckIdx = 0;
        _deck = [..._sourceDeck()]..shuffle();
      });
    }
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
    // Tinder convention：往右 = 有興趣 / 往左 = 沒興趣
    final isLike = dir == SwipeDirection.right;
    unawaited(
      AppRepository.recordSwipe(
        cardId: role.id,
        liked: isLike,
      ),
    );

    _persist((prev) {
      final liked = [...prev.explore.likedRoleIds];
      final disliked = [...prev.explore.dislikedRoleIds];

      if (isLike) {
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
      // 卡組用完一輪重新洗牌，達成「無限滑卡」
      if (_deckIdx % _deck.length == 0) {
        _deck = [..._sourceDeck()]..shuffle();
      }
    });
    // 不再每 N 張自動跳 dialog；要更新計畫請走「職涯路徑」頁的同步按鈕，
    // 那裡可以多選想餵給 AI 的滑卡。
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
      _deck = [..._sourceDeck()]..shuffle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final likedCount = widget.storage.explore.likedRoleIds.length;
    final totalSwipes = widget.storage.explore.swipeCount;

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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isStartup ? '能力探索' : '興趣探索',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          AppGaps.h2,
                          Text(
                            _isStartup ? '創業技能滑卡' : '無限滑卡',
                            style: const TextStyle(
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
                          const Text(
                            '到「職涯路徑」按同步即可選要套用的滑卡',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                      // 左 = 沒興趣（PASS） — 往左滑同步
                      _RoundSwipeButton(
                        label: 'PASS',
                        size: 64,
                        bg: AppColors.surface,
                        iconColor: AppColors.iosRed,
                        icon: CupertinoIcons.xmark,
                        onPressed: () => _swipe(SwipeDirection.left),
                      ),
                      const SizedBox(width: 36),
                      // 右 = 有興趣（LIKE） — 往右滑同步
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
