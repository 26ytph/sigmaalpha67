import 'package:flutter/cupertino.dart';

import '../logic/generate_plan.dart';
import '../models/models.dart';
import '../utils/plan_todo_keys.dart';
import '../utils/theme.dart';

/// 計畫的「路線圖」子分頁：把每週的任務排成 vertical timeline，
/// 可以一眼看出進度。完成度由 planTodos 算出。
class PlanRoadmapScreen extends StatelessWidget {
  const PlanRoadmapScreen({super.key, required this.storage});

  final AppStorage storage;

  ({int done, int total}) _weekProgress(PlanWeek w) {
    var total = 0;
    var done = 0;

    final keysByWeek = <String>[];
    for (var i = 0; i < w.goals.length; i++) {
      keysByWeek.add(makeTodoKey(w.week, 'goals', i));
    }
    for (var i = 0; i < w.resources.length; i++) {
      keysByWeek.add(makeTodoKey(w.week, 'resources', i));
    }
    for (var i = 0; i < w.outputs.length; i++) {
      keysByWeek.add(makeTodoKey(w.week, 'outputs', i));
    }
    total += keysByWeek.length;
    for (final k in keysByWeek) {
      if (storage.planTodos[k] == true) done++;
    }
    return (done: done, total: total);
  }

  /// 指定週數有哪些 course tasks（同一門課跨多週時都會出現）
  Iterable<RecommendedCourse> _coursesFor(GeneratedPlan plan, int week) =>
      plan.courses.where((c) => c.spansWeek(week));

  ({int done, int total}) _courseProgress(GeneratedPlan plan, int week) {
    final cs = _coursesFor(plan, week).toList();
    final total = cs.length;
    var done = 0;
    for (final c in cs) {
      if (storage.planTodos['course:${c.id}'] == true) done++;
    }
    return (done: done, total: total);
  }

  @override
  Widget build(BuildContext context) {
    final plan = generatePlan(storage.explore.likedRoleIds);
    final isStartup = storage.profile.startupInterest;

    final overallTotal = plan.weeks.fold<int>(
      0,
      (acc, w) => acc + _weekProgress(w).total,
    );
    final overallDone = plan.weeks.fold<int>(
      0,
      (acc, w) => acc + _weekProgress(w).done,
    );
    final overallPct =
        overallTotal == 0 ? 0 : ((overallDone / overallTotal) * 100).round();

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            // —— 頂部標題 + 整體進度 ——
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                gradient: isStartup
                    ? AppColors.startupGradient
                    : AppColors.brandGradient,
                borderRadius: BorderRadius.circular(AppRadii.xl),
                boxShadow: AppColors.shadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(CupertinoIcons.map_fill,
                          color: CupertinoColors.white, size: 18),
                      AppGaps.w6,
                      Text(
                        '行動路線圖',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ],
                  ),
                  AppGaps.h6,
                  Text(
                    plan.headline,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: CupertinoColors.white,
                    ),
                  ),
                  AppGaps.h12,
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: SizedBox(
                      height: 6,
                      child: Stack(
                        children: [
                          Container(
                            color:
                                CupertinoColors.white.withValues(alpha: 0.30),
                          ),
                          FractionallySizedBox(
                            widthFactor:
                                overallTotal == 0 ? 0 : overallDone / overallTotal,
                            child: Container(color: CupertinoColors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AppGaps.h6,
                  Text(
                    '整體進度 $overallDone / $overallTotal（$overallPct%）',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.white.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),
            AppGaps.h20,
            // —— Timeline ——
            for (var i = 0; i < plan.weeks.length; i++)
              _RoadmapNode(
                week: plan.weeks[i],
                index: i,
                last: i == plan.weeks.length - 1,
                progress: _weekProgress(plan.weeks[i]),
                courseProgress: _courseProgress(plan, plan.weeks[i].week),
                courses: _coursesFor(plan, plan.weeks[i].week).toList(),
                planTodos: storage.planTodos,
              ),
          ],
        ),
      ),
    );
  }
}

class _RoadmapNode extends StatelessWidget {
  const _RoadmapNode({
    required this.week,
    required this.index,
    required this.last,
    required this.progress,
    required this.courseProgress,
    required this.courses,
    required this.planTodos,
  });

  final PlanWeek week;
  final int index;
  final bool last;
  final ({int done, int total}) progress;
  final ({int done, int total}) courseProgress;
  final List<RecommendedCourse> courses;
  final Map<String, bool> planTodos;

  bool get _completed => progress.total > 0 && progress.done == progress.total;
  bool get _inProgress => progress.done > 0 && !_completed;

  @override
  Widget build(BuildContext context) {
    final pct = progress.total == 0 ? 0 : progress.done / progress.total;

    Color dotColor;
    if (_completed) {
      dotColor = AppColors.iosGreen;
    } else if (_inProgress) {
      dotColor = AppColors.brandStart;
    } else {
      dotColor = AppColors.borderStrong;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // —— 左側：節點 + 線 ——
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: _completed
                        ? const LinearGradient(
                            colors: [
                              AppColors.iosGreen,
                              AppColors.accentEmerald,
                            ],
                          )
                        : (_inProgress ? AppColors.brandGradient : null),
                    color: _inProgress || _completed ? null : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _completed || _inProgress
                          ? const Color(0x00000000)
                          : AppColors.borderStrong,
                      width: 2,
                    ),
                    boxShadow:
                        _completed || _inProgress ? AppColors.shadowSoft : null,
                  ),
                  child: _completed
                      ? const Icon(CupertinoIcons.check_mark,
                          size: 18, color: CupertinoColors.white)
                      : Text(
                          '${week.week}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _inProgress
                                ? CupertinoColors.white
                                : AppColors.textTertiary,
                          ),
                        ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4, bottom: 4),
                      color: dotColor.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          // —— 右側：卡片 ——
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14, left: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  boxShadow: AppColors.shadowSoft,
                  border: Border.all(
                    color: _inProgress
                        ? AppColors.brandStart.withValues(alpha: 0.25)
                        : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          '第 ${week.week} 週',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${progress.done}/${progress.total}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: dotColor,
                          ),
                        ),
                      ],
                    ),
                    AppGaps.h4,
                    Text(
                      week.title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    AppGaps.h10,
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: SizedBox(
                        height: 5,
                        child: Stack(
                          children: [
                            const ColoredBox(color: AppColors.border),
                            FractionallySizedBox(
                              widthFactor: pct.toDouble(),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: _completed
                                      ? const LinearGradient(colors: [
                                          AppColors.iosGreen,
                                          AppColors.accentEmerald,
                                        ])
                                      : AppColors.brandGradient,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AppGaps.h10,
                    // 任務概要：goals 第一條
                    if (week.goals.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(CupertinoIcons.flag,
                              size: 12, color: AppColors.textTertiary),
                          AppGaps.w6,
                          Expanded(
                            child: Text(
                              week.goals.first,
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (courses.isNotEmpty) ...[
                      AppGaps.h8,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(CupertinoIcons.book_fill,
                              size: 12, color: AppColors.iosBlue),
                          AppGaps.w6,
                          Expanded(
                            child: Text(
                              '課程任務 ${courseProgress.done}/${courseProgress.total}：${courses.map((c) => c.title).join('、')}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: AppColors.iosBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
