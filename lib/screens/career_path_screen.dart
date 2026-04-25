import 'package:flutter/cupertino.dart';

import '../utils/theme.dart';

/// 職涯路徑頁：兩個內建分頁
///   - Tab 0：Roadmap 地圖 — 一條像旅程的曲線，串連 4 個 week 節點 + 1 個 goal。
///                點擊 week 節點 → 切到 Tab 1 並滾到對應週卡片。
///   - Tab 1：每週 Todo List — 上方顯示月份目標，中段是週卡片清單，
///                每張卡片有 checkbox 樣式的待辦；底部固定一顆「查看更新」按鈕。
///
/// 目前用 mock data，之後可以改接 [generatePlan] 與 [AppStorage.planTodos]。
class CareerPathScreen extends StatefulWidget {
  const CareerPathScreen({super.key});

  @override
  State<CareerPathScreen> createState() => _CareerPathScreenState();
}

class _CareerPathScreenState extends State<CareerPathScreen> {
  int _tab = 0;
  final ScrollController _todoScroll = ScrollController();
  final Map<int, GlobalKey> _weekKeys = {};

  // —— Mock data ———————————————————————————————————————————
  static const _monthLabel = '4月';
  static const _monthGoal = '找到職涯大方向';
  static const _monthSub = '一步一步來，不急著馬上找到答案。';

  late final List<_WeekData> _weeks = const [
    _WeekData(
      id: 1,
      title: 'Week 1',
      focus: '探索職涯方向',
      todos: ['完成個人 Profile', '瀏覽 10 張職涯卡片', '收藏 3 個感興趣方向'],
    ),
    _WeekData(
      id: 2,
      title: 'Week 2',
      focus: '建立基礎能力',
      todos: ['完成技能自評', '學習履歷基本架構', '瀏覽 3 個課程資源'],
    ),
    _WeekData(
      id: 3,
      title: 'Week 3',
      focus: '準備行動素材',
      todos: ['建立履歷初稿', '請 AI 檢查履歷', '選出 5 個想投遞的機會'],
    ),
    _WeekData(
      id: 4,
      title: 'Week 4',
      focus: '實際行動與回饋',
      todos: ['投遞 3 個機會', '預約一次職涯諮詢', '完成本週回饋'],
    ),
  ];

  // 每個 todo 的勾選狀態（mock；換頁不重置，但 app 重啟會清空）。
  // key = '<weekId>.<todoIndex>'
  final Map<String, bool> _todoDone = {};

  bool _isDone(int weekId, int idx) => _todoDone['$weekId.$idx'] ?? false;

  void _toggleTodo(int weekId, int idx) {
    setState(() => _todoDone['$weekId.$idx'] = !_isDone(weekId, idx));
  }

  // —— Tab navigation ———————————————————————————————————————

  void _jumpToWeek(int weekId) {
    setState(() => _tab = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _weekKeys[weekId]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          alignment: 0.05,
        );
      }
    });
  }

  void _showCheckUpdates() {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('已是最新內容'),
        content: const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            '目前沒有新的任務或建議，繼續完成本月目標吧 🌸',
            style: TextStyle(height: 1.5),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _todoScroll.dispose();
    super.dispose();
  }

  // —— Build ————————————————————————————————————————————————

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      navigationBar: const CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: AppColors.bg,
        border: null,
        middle: Text('職涯路徑'),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _TabPills(
                value: _tab,
                onChange: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                child: _tab == 0
                    ? _RoadmapView(
                        key: const ValueKey('roadmap'),
                        weeks: _weeks,
                        completionFor: _weekCompletion,
                        onTapWeek: _jumpToWeek,
                      )
                    : _TodoListView(
                        key: const ValueKey('todos'),
                        scrollController: _todoScroll,
                        weeks: _weeks,
                        weekKeys: _weekKeys,
                        isDone: _isDone,
                        onToggle: _toggleTodo,
                        monthLabel: _monthLabel,
                        monthGoal: _monthGoal,
                        monthSub: _monthSub,
                        onCheckUpdates: _showCheckUpdates,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _weekCompletion(int weekId) {
    final week = _weeks.firstWhere((w) => w.id == weekId);
    if (week.todos.isEmpty) return 0;
    var done = 0;
    for (var i = 0; i < week.todos.length; i++) {
      if (_isDone(week.id, i)) done++;
    }
    return done / week.todos.length;
  }
}

// =============================================================================
// 上方分頁切換器（Roadmap / 本月任務）
// =============================================================================

class _TabPills extends StatelessWidget {
  const _TabPills({required this.value, required this.onChange});

  final int value;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PillButton(
              label: 'Roadmap',
              icon: CupertinoIcons.map_fill,
              selected: value == 0,
              onTap: () => onChange(0),
            ),
          ),
          Expanded(
            child: _PillButton(
              label: '本月任務',
              icon: CupertinoIcons.checkmark_seal_fill,
              selected: value == 1,
              onTap: () => onChange(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brandGradient : null,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: selected ? AppColors.shadowSoft : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? CupertinoColors.white : AppColors.textTertiary,
            ),
            AppGaps.w6,
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? CupertinoColors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Tab 0 — Roadmap 地圖
// =============================================================================

class _RoadmapView extends StatelessWidget {
  const _RoadmapView({
    super.key,
    required this.weeks,
    required this.completionFor,
    required this.onTapWeek,
  });

  final List<_WeekData> weeks;
  final double Function(int weekId) completionFor;
  final ValueChanged<int> onTapWeek;

  // 5 個節點（4 週 + Goal）相對位置（0–1）— 像個蛇形旅程。
  static const _positions = <Offset>[
    Offset(0.20, 0.07),
    Offset(0.78, 0.27),
    Offset(0.20, 0.50),
    Offset(0.78, 0.72),
    Offset(0.50, 0.92),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _greeting(),
          AppGaps.h14,
          AspectRatio(
            aspectRatio: 0.72,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(AppRadii.xl),
                boxShadow: AppColors.shadowSoft,
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, c) {
                  final width = c.maxWidth;
                  final height = c.maxHeight;
                  return Stack(
                    children: [
                      const Positioned(
                        top: 18,
                        right: 22,
                        child: Icon(
                          CupertinoIcons.sparkles,
                          color: Color(0x66FF7ABF),
                          size: 22,
                        ),
                      ),
                      const Positioned(
                        bottom: 28,
                        left: 18,
                        child: Icon(
                          CupertinoIcons.heart_fill,
                          color: Color(0x33FE3C72),
                          size: 16,
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _PathPainter(positions: _positions),
                        ),
                      ),
                      for (var i = 0; i < _positions.length; i++)
                        Positioned(
                          left: _positions[i].dx * width - _nodeSize(i) / 2,
                          top: _positions[i].dy * height - _nodeSize(i) / 2,
                          child: _RoadmapNode(
                            label: i < weeks.length ? '${weeks[i].id}' : '🎯',
                            sublabel:
                                i < weeks.length ? weeks[i].focus : '完成本月目標',
                            isGoal: i == _positions.length - 1,
                            progress: i < weeks.length
                                ? completionFor(weeks[i].id)
                                : null,
                            size: _nodeSize(i),
                            onTap: i < weeks.length
                                ? () => onTapWeek(weeks[i].id)
                                : null,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          AppGaps.h16,
          _legend(),
        ],
      ),
    );
  }

  double _nodeSize(int i) => i == _positions.length - 1 ? 86 : 72;

  Widget _greeting() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              CupertinoIcons.flag_fill,
              color: CupertinoColors.white,
              size: 18,
            ),
          ),
          AppGaps.w12,
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '你的職涯小旅程',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.brandStart,
                  ),
                ),
                AppGaps.h2,
                Text(
                  '點任一週的小圓，跳到那週的任務 ✨',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          _LegendDot(color: AppColors.brandStart, label: '已開始'),
          AppGaps.w12,
          _LegendDot(
            color: AppColors.bgAlt,
            label: '尚未開始',
            borderColor: AppColors.separator,
          ),
          AppGaps.w12,
          _LegendDot(color: AppColors.iosGreen, label: '完成'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    this.borderColor,
  });
  final Color color;
  final String label;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: borderColor != null ? Border.all(color: borderColor!) : null,
          ),
        ),
        AppGaps.w6,
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

class _RoadmapNode extends StatelessWidget {
  const _RoadmapNode({
    required this.label,
    required this.sublabel,
    required this.isGoal,
    required this.size,
    required this.onTap,
    required this.progress,
  });

  final String label;
  final String sublabel;
  final bool isGoal;
  final double size;
  final VoidCallback? onTap;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final completed = (progress ?? 0) >= 1.0;
    final started = (progress ?? 0) > 0;

    final Gradient gradient = isGoal
        ? AppColors.heartGradient
        : completed
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6EE7B7), Color(0xFF34C759)],
              )
            : started
                ? AppColors.brandGradient
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFE4EC), Color(0xFFFFEFE7)],
                  );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: gradient,
              shape: BoxShape.circle,
              border: started || isGoal
                  ? null
                  : Border.all(color: AppColors.separator, width: 1.5),
              boxShadow: AppColors.shadowSoft,
            ),
            child: isGoal
                ? const Icon(
                    CupertinoIcons.star_fill,
                    color: CupertinoColors.white,
                    size: 28,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'WEEK',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: started
                              ? CupertinoColors.white
                              : AppColors.textTertiary,
                        ),
                      ),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: started
                              ? CupertinoColors.white
                              : AppColors.brandStart,
                        ),
                      ),
                    ],
                  ),
          ),
          AppGaps.h6,
          SizedBox(
            width: size + 30,
            child: Text(
              isGoal ? '🎯 目標' : sublabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter({required this.positions});

  final List<Offset> positions;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2) return;
    final pts = positions
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();

    final basePath = _buildPath(pts);

    // 1) 半透明粉色底線（讓路徑看起來蓬鬆）
    final glowPaint = Paint()
      ..color = const Color(0x33FE3C72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(basePath, glowPaint);

    // 2) 主要虛線（dashed）粉線
    final dashPaint = Paint()
      ..color = AppColors.brandStart
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    _drawDashed(canvas, basePath, dashPaint, dashWidth: 10, dashSpace: 8);
  }

  Path _buildPath(List<Offset> pts) {
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length; i++) {
      final from = pts[i - 1];
      final to = pts[i];
      final c1 = Offset(from.dx, (from.dy + to.dy) / 2);
      final c2 = Offset(to.dx, (from.dy + to.dy) / 2);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, to.dx, to.dy);
    }
    return path;
  }

  void _drawDashed(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashWidth,
    required double dashSpace,
  }) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter old) =>
      old.positions != positions;
}

// =============================================================================
// Tab 1 — 月份目標 + 週卡片清單
// =============================================================================

class _TodoListView extends StatelessWidget {
  const _TodoListView({
    super.key,
    required this.scrollController,
    required this.weeks,
    required this.weekKeys,
    required this.isDone,
    required this.onToggle,
    required this.monthLabel,
    required this.monthGoal,
    required this.monthSub,
    required this.onCheckUpdates,
  });

  final ScrollController scrollController;
  final List<_WeekData> weeks;
  final Map<int, GlobalKey> weekKeys;
  final bool Function(int weekId, int idx) isDone;
  final void Function(int weekId, int idx) onToggle;
  final String monthLabel;
  final String monthGoal;
  final String monthSub;
  final VoidCallback onCheckUpdates;

  @override
  Widget build(BuildContext context) {
    for (final w in weeks) {
      weekKeys.putIfAbsent(w.id, GlobalKey.new);
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              _MonthHeader(label: monthLabel, goal: monthGoal, sub: monthSub),
              AppGaps.h16,
              for (final w in weeks) ...[
                Container(
                  key: weekKeys[w.id],
                  child: _WeekCard(
                    week: w,
                    isDone: isDone,
                    onToggle: onToggle,
                  ),
                ),
                AppGaps.h12,
              ],
              AppGaps.h12,
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: const BoxDecoration(
            color: AppColors.bg,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 14),
                color: AppColors.brandStart,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                onPressed: onCheckUpdates,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.refresh_circled_solid,
                      size: 18,
                      color: CupertinoColors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '查看更新',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: CupertinoColors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.label,
    required this.goal,
    required this.sub,
  });

  final String label;
  final String goal;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
              AppGaps.w8,
              const Text(
                '本月目標',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          AppGaps.h10,
          Text(
            goal,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.3,
              letterSpacing: -0.3,
              color: AppColors.textPrimary,
            ),
          ),
          AppGaps.h6,
          Text(
            sub,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.week,
    required this.isDone,
    required this.onToggle,
  });

  final _WeekData week;
  final bool Function(int weekId, int idx) isDone;
  final void Function(int weekId, int idx) onToggle;

  @override
  Widget build(BuildContext context) {
    final doneCount = [
      for (var i = 0; i < week.todos.length; i++) if (isDone(week.id, i)) 1,
    ].length;
    final allDone = week.todos.isNotEmpty && doneCount == week.todos.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppColors.shadowSoft,
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: allDone
                      ? const LinearGradient(
                          colors: [Color(0xFF6EE7B7), Color(0xFF34C759)],
                        )
                      : AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  week.title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$doneCount / ${week.todos.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                ),
              ),
              if (allDone) ...[
                AppGaps.w6,
                const Icon(
                  CupertinoIcons.checkmark_seal_fill,
                  size: 16,
                  color: AppColors.iosGreen,
                ),
              ],
            ],
          ),
          AppGaps.h8,
          Text(
            week.focus,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: AppColors.textPrimary,
            ),
          ),
          AppGaps.h10,
          for (var i = 0; i < week.todos.length; i++)
            _TodoRow(
              text: week.todos[i],
              done: isDone(week.id, i),
              onTap: () => onToggle(week.id, i),
            ),
        ],
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({
    required this.text,
    required this.done,
    required this.onTap,
  });

  final String text;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 6),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: done ? AppColors.brandGradient : null,
              color: done ? null : AppColors.surfaceMuted,
              shape: BoxShape.circle,
              border: done
                  ? null
                  : Border.all(color: AppColors.separator, width: 1.5),
            ),
            child: done
                ? const Icon(
                    CupertinoIcons.check_mark,
                    size: 14,
                    color: CupertinoColors.white,
                  )
                : null,
          ),
          AppGaps.w10,
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w600,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.textTertiary,
                color: done ? AppColors.textTertiary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Mock data model
// =============================================================================

class _WeekData {
  const _WeekData({
    required this.id,
    required this.title,
    required this.focus,
    required this.todos,
  });

  final int id;
  final String title;
  final String focus;
  final List<String> todos;
}
