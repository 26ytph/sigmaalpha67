import 'package:flutter/cupertino.dart';

import '../logic/generate_plan.dart' as plan;
import '../models/models.dart';
import '../services/app_repository.dart';
import '../utils/theme.dart';

/// 職涯路徑頁：兩個內建分頁
///   - Tab 0：Roadmap 地圖 — 一條像旅程的曲線，串連最多 4 個 week 節點 + 1 個 goal。
///                點擊 week 節點 → 切到 Tab 1 並滾到對應週卡片。
///   - Tab 1：每週 Todo List — 上方顯示月份目標 + 興趣 chips，中段是週卡片清單，
///                每張卡片有 checkbox 樣式的待辦；底部固定一顆「查看更新」按鈕。
///
/// 「Roadmap 是依 Persona + 興趣推算出該補哪些技能」
/// ────────────────────────────────────────────────
/// 真正算出本月任務的是 [plan.generatePlan]：
///   1. 輸入 = 使用者按 ❤ 過的職位（[ExploreResults.likedRoleIds]） + mode（求職/創業）
///   2. 內部 → 把 likedRoles 轉成 RoleTag 排名 → 對應到該 tag 的週課表
///      （[plan.baseWeeks]） + 推薦課程 / 證照 ([plan._coursesFor])
///   3. 輸出 = `GeneratedPlan` 的 weeks（goals / resources / outputs）
///
/// 介面個人化會再用：
///   - `profile.name` / `profile.currentStage`：問候、副標
///   - `persona.recommendedNextStep` / `profile.goals`：本月目標 headline
///   - `persona.mainInterests` ∪ `profile.interests`：介面上的 chip
///
/// 「查看更新」打的是後端的 4 條：
///   - GET /api/users/me/profile      → profile（含 interests）
///   - GET /api/persona               → persona（含 mainInterests / 推薦下一步）
///   - GET /api/swipe/summary         → likedRoleIds（決定整份 plan 的核心輸入）
///   - GET /api/skills/translations   → 技能翻譯（之後可以選擇加進週任務）
class CareerPathScreen extends StatefulWidget {
  const CareerPathScreen({
    super.key,
    required this.storage,
    required this.onStorageChanged,
    this.onOpenExplore,
  });

  final AppStorage storage;
  final ValueChanged<AppStorage> onStorageChanged;

  /// 沒有任何 likedRoleIds → 空狀態 CTA 帶使用者去滑卡探索。
  final VoidCallback? onOpenExplore;

  @override
  State<CareerPathScreen> createState() => _CareerPathScreenState();
}

class _CareerPathScreenState extends State<CareerPathScreen> {
  int _tab = 0;
  bool _refreshing = false;
  bool _aiPlanLoading = false;
  bool _planFromBackend = false;
  final ScrollController _todoScroll = ScrollController();
  final Map<int, GlobalKey> _weekKeys = {};

  // todo 勾選狀態（local-only；app 重啟會清空）。
  // key = '<weekNumber>:<todoIdx>'
  final Map<String, bool> _todoDone = {};

  late plan.GeneratedPlan _plan;

  /// 用來判斷「需不需要重打 LLM」的 signature（liked + mode + persona text）。
  /// 避免每次 `setState` 都重新打 Gemini，浪費 quota。
  String _planSignature = '';
  // ignore: unused_field
  Object? _activeFetchToken;

  @override
  void initState() {
    super.initState();
    _plan = _buildLocalPlan(widget.storage);
    _planSignature = _signatureFor(widget.storage);
    // 立刻打一次後端，如果有 GEMINI_API_KEY 設好就會拿到客製化 plan。
    _fetchBackendPlan(widget.storage);
  }

  @override
  void didUpdateWidget(covariant CareerPathScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.storage;
    final cur = widget.storage;
    final newSig = _signatureFor(cur);
    if (newSig != _planSignature) {
      _planSignature = newSig;
      // 立刻先用本機重算一次 — 等 LLM 回來再覆蓋。
      setState(() {
        _plan = _buildLocalPlan(cur);
        _planFromBackend = false;
      });
      _fetchBackendPlan(cur);
    } else if (!identical(
          old.explore.likedRoleIds,
          cur.explore.likedRoleIds,
        ) ||
        old.profile.startupInterest != cur.profile.startupInterest) {
      // 同 signature 但 reference 變了（很少見）— 也重算本機，不打 LLM。
      setState(() => _plan = _buildLocalPlan(cur));
    }
  }

  static plan.GeneratedPlan _buildLocalPlan(AppStorage s) {
    return plan.generatePlan(s.explore.likedRoleIds, mode: s.profile.mode);
  }

  String _signatureFor(AppStorage s) {
    final liked = [...s.explore.likedRoleIds]..sort();
    return [
      s.profile.startupInterest ? 'startup' : 'career',
      liked.join(','),
      s.persona.text,
      s.persona.recommendedNextStep,
    ].join('|');
  }

  /// 背景打後端取 LLM 客製化 plan。失敗就保持本機版本。
  /// 用 token 防止舊 request 蓋掉新的（race-condition guard）。
  Future<void> _fetchBackendPlan(AppStorage s) async {
    final token = Object();
    _activeFetchToken = token;
    if (mounted) setState(() => _aiPlanLoading = true);
    final result = await AppRepository.fetchPlan(s);
    if (!mounted || _activeFetchToken != token) return;
    setState(() {
      _aiPlanLoading = false;
      if (result.fromBackend) {
        _plan = result.plan;
        _planFromBackend = true;
      }
    });
  }

  // —— 一週要顯示的 todo：goals + outputs（resources 是閱讀資源，先留下不顯）
  List<String> _todosFor(plan.PlanWeek w) {
    return [...w.goals, ...w.outputs].take(5).toList(growable: false);
  }

  bool _isDone(int weekNum, int idx) =>
      _todoDone['$weekNum:$idx'] ?? false;

  void _toggleTodo(int weekNum, int idx) {
    setState(() => _todoDone['$weekNum:$idx'] = !_isDone(weekNum, idx));
  }

  double _weekCompletion(plan.PlanWeek w) {
    final items = _todosFor(w);
    if (items.isEmpty) return 0;
    var done = 0;
    for (var i = 0; i < items.length; i++) {
      if (_isDone(w.week, i)) done++;
    }
    return done / items.length;
  }

  // —— 個人化文案（profile + persona） ————————————————————

  String get _monthLabel {
    const names = [
      '1月', '2月', '3月', '4月', '5月', '6月',
      '7月', '8月', '9月', '10月', '11月', '12月',
    ];
    return names[DateTime.now().month - 1];
  }

  /// 本月目標：persona 推薦的下一步 > 使用者自寫的 goals[0] > Plan headline。
  String get _monthGoal {
    final persona = widget.storage.persona;
    final profile = widget.storage.profile;
    if (persona.recommendedNextStep.isNotEmpty) {
      return persona.recommendedNextStep;
    }
    if (profile.goals.isNotEmpty) return profile.goals.first;
    return _plan.headline;
  }

  /// 副標：呼叫使用者名字 + 標出階段；空狀態給 onboarding 提示。
  String get _monthSub {
    final profile = widget.storage.profile;
    if (_plan.weeks.isEmpty) {
      return profile.name.isEmpty
          ? '到「滑卡探索」按 ❤ 一些有興趣的職位，這條路線就會自動長出來 ✨'
          : '${profile.name}，去滑卡 ❤ 一些有興趣的職位，這個月的任務就會跟你對齊 ✨';
    }
    if (profile.currentStage.isNotEmpty) {
      return '${profile.currentStage}階段，先把這幾週的能力打底。';
    }
    return '一步一步來，不急著馬上找到答案。';
  }

  /// persona.mainInterests 優先，profile.interests 補位，去重後最多 5 個。
  List<String> get _topInterests {
    final out = <String>[];
    final seen = <String>{};
    for (final s in widget.storage.persona.mainInterests) {
      final v = s.trim();
      if (v.isEmpty || !seen.add(v)) continue;
      out.add(v);
      if (out.length >= 5) return out;
    }
    for (final s in widget.storage.profile.interests) {
      final v = s.trim();
      if (v.isEmpty || !seen.add(v)) continue;
      out.add(v);
      if (out.length >= 5) return out;
    }
    return out;
  }

  // —— Tab navigation ———————————————————————————————————————

  void _jumpToWeek(int weekNum) {
    setState(() => _tab = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _weekKeys[weekNum]?.currentContext;
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

  // —— 「查看更新」：合併 refresh profile + persona + swipes + translations ——

  Future<void> _checkUpdates() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final result = await AppRepository.refreshAll();
    if (!mounted) return;
    setState(() => _refreshing = false);

    widget.onStorageChanged(result.storage);

    final allFailed = result.profileChanged == null &&
        result.personaChanged == null &&
        result.exploreChanged == null &&
        result.translationsChanged == null;
    if (allFailed) {
      _showDialog(
        title: '無法連線',
        body: '剛剛沒拿到任何資料。已沿用本機現況。',
      );
      return;
    }

    final summary = _summarize(result);
    if (summary.isEmpty) {
      _showDialog(
        title: '已是最新內容',
        body: '個人資料、Persona、滑卡結果都沒有更動 🌸',
      );
    } else {
      _showDialog(title: '已同步', body: summary);
    }
  }

  String _summarize(({
    AppStorage storage,
    bool? profileChanged,
    bool? personaChanged,
    int? exploreChanged,
    int? translationsChanged,
  }) r) {
    final lines = <String>[];
    if (r.profileChanged == true) lines.add('・個人資料已更新');
    if (r.personaChanged == true) lines.add('・Persona 已更新');
    if ((r.exploreChanged ?? 0) > 0) {
      lines.add('・滑卡結果有 ${r.exploreChanged} 筆變動，已重新生成路線');
    }
    if ((r.translationsChanged ?? 0) > 0) {
      lines.add('・新增 / 更動 ${r.translationsChanged} 筆技能翻譯');
    }
    return lines.join('\n');
  }

  void _showDialog({required String title, required String body}) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(body, style: const TextStyle(height: 1.5)),
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
    final weeks = _plan.weeks.take(4).toList();

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
                        weeks: weeks,
                        completionFor: _weekCompletion,
                        onTapWeek: _jumpToWeek,
                        userName: widget.storage.profile.name,
                        onOpenExplore: widget.onOpenExplore,
                      )
                    : _TodoListView(
                        key: const ValueKey('todos'),
                        scrollController: _todoScroll,
                        weeks: weeks,
                        weekKeys: _weekKeys,
                        todosFor: _todosFor,
                        isDone: _isDone,
                        onToggle: _toggleTodo,
                        monthLabel: _monthLabel,
                        monthGoal: _monthGoal,
                        monthSub: _monthSub,
                        interests: _topInterests,
                        aiCustomized: _planFromBackend,
                        aiLoading: _aiPlanLoading,
                        refreshing: _refreshing,
                        onCheckUpdates: _checkUpdates,
                        onOpenExplore: widget.onOpenExplore,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 上方分頁切換器
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
// Tab 0 — Roadmap
// =============================================================================

class _RoadmapView extends StatelessWidget {
  const _RoadmapView({
    super.key,
    required this.weeks,
    required this.completionFor,
    required this.onTapWeek,
    required this.userName,
    required this.onOpenExplore,
  });

  final List<plan.PlanWeek> weeks;
  final double Function(plan.PlanWeek week) completionFor;
  final ValueChanged<int> onTapWeek;
  final String userName;
  final VoidCallback? onOpenExplore;

  static const _slotPositions = <Offset>[
    Offset(0.20, 0.07),
    Offset(0.78, 0.27),
    Offset(0.20, 0.50),
    Offset(0.78, 0.72),
    Offset(0.50, 0.92),
  ];

  @override
  Widget build(BuildContext context) {
    final visibleSlots = weeks.length + 1;
    final positions = _slotPositions.sublist(0, visibleSlots.clamp(2, 5));

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
                      if (positions.length >= 2)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _PathPainter(positions: positions),
                          ),
                        ),
                      for (var i = 0; i < positions.length; i++)
                        Positioned(
                          left: positions[i].dx * width -
                              _nodeSize(i, positions.length) / 2,
                          top: positions[i].dy * height -
                              _nodeSize(i, positions.length) / 2,
                          child: _RoadmapNode(
                            label: i < weeks.length ? '${weeks[i].week}' : '🎯',
                            sublabel: i < weeks.length
                                ? weeks[i].title
                                : '完成本月目標',
                            isGoal: i == positions.length - 1,
                            progress: i < weeks.length
                                ? completionFor(weeks[i])
                                : null,
                            size: _nodeSize(i, positions.length),
                            onTap: i < weeks.length
                                ? () => onTapWeek(weeks[i].week)
                                : null,
                          ),
                        ),
                      if (weeks.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: _EmptyHint(
                              userName: userName,
                              onOpenExplore: onOpenExplore,
                            ),
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

  double _nodeSize(int i, int total) => i == total - 1 ? 86 : 72;

  Widget _greeting() {
    final title = userName.isEmpty ? '你的職涯小旅程' : '$userName 的職涯小旅程';
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.brandStart,
                  ),
                ),
                AppGaps.h2,
                Text(
                  weeks.isEmpty
                      ? '去滑卡探索按 ❤ 喜歡的職位，這條路線就會自動長出來 ✨'
                      : '點任一週的小圓，跳到那週的任務 ✨',
                  style: const TextStyle(
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

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.userName, this.onOpenExplore});
  final String userName;
  final VoidCallback? onOpenExplore;

  @override
  Widget build(BuildContext context) {
    final title = userName.isEmpty ? '還沒滑過卡' : '$userName，這裡還是空的';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.heart_fill,
            color: AppColors.brandStart,
            size: 28,
          ),
          AppGaps.h8,
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          AppGaps.h4,
          const Text(
            '到「滑卡探索」按 ❤ 一些有興趣的職位，這個月的任務就會自己長出來。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (onOpenExplore != null) ...[
            AppGaps.h10,
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.brandStart,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              onPressed: onOpenExplore,
              child: const Text(
                '去滑卡探索',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          ],
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

    final glowPaint = Paint()
      ..color = const Color(0x33FE3C72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(basePath, glowPaint);

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
    required this.todosFor,
    required this.isDone,
    required this.onToggle,
    required this.monthLabel,
    required this.monthGoal,
    required this.monthSub,
    required this.interests,
    required this.aiCustomized,
    required this.aiLoading,
    required this.refreshing,
    required this.onCheckUpdates,
    required this.onOpenExplore,
  });

  final ScrollController scrollController;
  final List<plan.PlanWeek> weeks;
  final Map<int, GlobalKey> weekKeys;
  final List<String> Function(plan.PlanWeek week) todosFor;
  final bool Function(int weekNum, int idx) isDone;
  final void Function(int weekNum, int idx) onToggle;
  final String monthLabel;
  final String monthGoal;
  final String monthSub;
  final List<String> interests;
  final bool aiCustomized;
  final bool aiLoading;
  final bool refreshing;
  final VoidCallback onCheckUpdates;
  final VoidCallback? onOpenExplore;

  @override
  Widget build(BuildContext context) {
    for (final w in weeks) {
      weekKeys.putIfAbsent(w.week, GlobalKey.new);
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              _MonthHeader(
                label: monthLabel,
                goal: monthGoal,
                sub: monthSub,
                interests: interests,
                aiCustomized: aiCustomized,
                aiLoading: aiLoading,
              ),
              AppGaps.h16,
              if (weeks.isEmpty)
                _emptyCard(context)
              else
                for (final w in weeks) ...[
                  Container(
                    key: weekKeys[w.week],
                    child: _WeekCard(
                      week: w,
                      todos: todosFor(w),
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
                onPressed: refreshing ? null : onCheckUpdates,
                child: refreshing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '更新中…',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ],
                      )
                    : const Row(
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

  Widget _emptyCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.separator),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.heart_fill,
            color: AppColors.brandStart,
            size: 32,
          ),
          AppGaps.h10,
          const Text(
            '本月還沒有任務',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          AppGaps.h6,
          const Text(
            '到「滑卡探索」按 ❤ 一些有興趣的職位，這個月的任務就會自己長出來。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
          if (onOpenExplore != null) ...[
            AppGaps.h12,
            CupertinoButton(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              color: AppColors.brandStart,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              onPressed: onOpenExplore,
              child: const Text(
                '去滑卡探索',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.label,
    required this.goal,
    required this.sub,
    required this.interests,
    required this.aiCustomized,
    required this.aiLoading,
  });

  final String label;
  final String goal;
  final String sub;
  final List<String> interests;
  final bool aiCustomized;
  final bool aiLoading;

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
              const Spacer(),
              if (aiLoading)
                const _AiBadge(
                  label: 'AI 客製中…',
                  showSpinner: true,
                )
              else if (aiCustomized)
                const _AiBadge(label: 'AI 客製'),
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
          if (interests.isNotEmpty) ...[
            AppGaps.h12,
            Row(
              children: [
                const Icon(
                  CupertinoIcons.heart_fill,
                  size: 11,
                  color: AppColors.brandStart,
                ),
                AppGaps.w4,
                const Text(
                  '你的興趣',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.brandStart,
                  ),
                ),
              ],
            ),
            AppGaps.h6,
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final i in interests) _InterestChip(label: i)],
            ),
          ],
        ],
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.separator),
      ),
      child: Text(
        '#$label',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.brandStart,
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.week,
    required this.todos,
    required this.isDone,
    required this.onToggle,
  });

  final plan.PlanWeek week;
  final List<String> todos;
  final bool Function(int weekNum, int idx) isDone;
  final void Function(int weekNum, int idx) onToggle;

  @override
  Widget build(BuildContext context) {
    final doneCount = [
      for (var i = 0; i < todos.length; i++) if (isDone(week.week, i)) 1,
    ].length;
    final allDone = todos.isNotEmpty && doneCount == todos.length;

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
                  'Week ${week.week}',
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
                '$doneCount / ${todos.length}',
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
            week.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: AppColors.textPrimary,
            ),
          ),
          AppGaps.h10,
          for (var i = 0; i < todos.length; i++)
            _TodoRow(
              text: todos[i],
              done: isDone(week.week, i),
              onTap: () => onToggle(week.week, i),
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

/// 顯示在月份頭右上角的小徽章 — 「AI 客製中…」/「AI 客製」。
class _AiBadge extends StatelessWidget {
  const _AiBadge({required this.label, this.showSpinner = false});
  final String label;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.separator),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner) ...[
            const CupertinoActivityIndicator(
              radius: 6,
              color: AppColors.brandStart,
            ),
            const SizedBox(width: 5),
          ] else ...[
            const Icon(
              CupertinoIcons.sparkles,
              size: 11,
              color: AppColors.brandStart,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.brandStart,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
