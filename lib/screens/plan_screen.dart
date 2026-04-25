import 'package:flutter/cupertino.dart';

import '../data/daily_questions.dart';
import '../data/roles.dart';
import '../logic/generate_plan.dart';
import '../models/models.dart';
import '../services/app_repository.dart';
import '../utils/date_util.dart';
import '../utils/hash_util.dart';
import '../utils/plan_todo_keys.dart';
import '../widgets/daily_question_card.dart';
import '../widgets/strike_badge.dart';

bool _intersect<T>(List<T> a, List<T> b) {
  final set = a.toSet();
  return b.any(set.contains);
}

class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    required this.storage,
    required this.onStorageChanged,
    required this.onGoToExplore,
  });

  final AppStorage storage;
  final ValueChanged<AppStorage> onStorageChanged;
  final VoidCallback onGoToExplore;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  Future<void> _persist(AppStorage Function(AppStorage prev) fn) async {
    final next = await AppRepository.update(fn);
    widget.onStorageChanged(next);
  }

  DailyQuestion? _pickQuestion(String today) {
    final answeredToday = widget.storage.dailyAnswers[today];
    if (answeredToday != null) {
      for (final q in dailyQuestions) {
        if (q.id == answeredToday.questionId) return q;
      }
      return null;
    }

    final likedTags = <RoleTag>{};
    for (final r in roles) {
      if (widget.storage.explore.likedRoleIds.contains(r.id)) {
        likedTags.addAll(r.tags);
      }
    }
    final likedTagsList = likedTags.toList();

    final pool = likedTagsList.isNotEmpty
        ? dailyQuestions
              .where((q) => _intersect(q.roleTags, likedTagsList))
              .toList()
        : dailyQuestions;

    if (pool.isEmpty) {
      return dailyQuestions.isNotEmpty ? dailyQuestions.first : null;
    }
    final idx = hashStringToInt(today) % pool.length;
    return pool[idx];
  }

  ({int done, int total, int pct}) _todoProgress(GeneratedPlan plan) {
    final keys = <String>[];
    for (final w in plan.weeks) {
      for (var i = 0; i < w.goals.length; i++) {
        keys.add(makeTodoKey(w.week, 'goals', i));
      }
      for (var i = 0; i < w.resources.length; i++) {
        keys.add(makeTodoKey(w.week, 'resources', i));
      }
      for (var i = 0; i < w.outputs.length; i++) {
        keys.add(makeTodoKey(w.week, 'outputs', i));
      }
    }
    final total = keys.length;
    var done = 0;
    for (final k in keys) {
      if (widget.storage.planTodos[k] == true) done++;
    }
    final pct = total == 0 ? 0 : ((done / total) * 100).round();
    return (done: done, total: total, pct: pct);
  }

  void _answer(DailyQuestion q, DailyAnswerValue value) {
    final today = toLocalDateString();
    if (widget.storage.dailyAnswers[today] != null) return;

    _persist((prev) {
      final prevStrike = prev.strike.current;
      final last = prev.strike.lastAnsweredDate;
      final nextStrike = isYesterday(last, today) ? prevStrike + 1 : 1;

      final answers = Map<String, DailyAnswerEntry>.from(prev.dailyAnswers);
      answers[today] = DailyAnswerEntry(questionId: q.id, answer: value);

      return prev.copyWith(
        dailyAnswers: answers,
        strike: StrikeState(current: nextStrike, lastAnsweredDate: today),
      );
    });
  }

  Future<void> _confirmReset() async {
    final go = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('清空本機資料'),
        content: const Text('將移除探索紀錄、計畫勾選、每日作答與 streak。此操作無法復原。'),
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
    if (go != true || !mounted) return;
    await AppRepository.clear();
    final next = await AppRepository.load();
    widget.onStorageChanged(next);
  }

  void _openRole(CareerRole role) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) =>
          _RoleDetailSheet(role: role, onClose: () => Navigator.pop(ctx)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = toLocalDateString();
    final plan = generatePlan(widget.storage.explore.likedRoleIds);
    final question = _pickQuestion(today);
    final answeredToday = widget.storage.dailyAnswers[today];

    if (question == null) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final overall = _todoProgress(plan);

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFFF5F8),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '職涯計畫',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF52525B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        plan.headline,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '根據你喜歡的職位（${widget.storage.explore.likedRoleIds.length}）生成；資料為假資料，可之後替換成 AI API。',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Color(0xFF3F3F46),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StrikeBadge(strike: widget.storage.strike.current),
                    const SizedBox(height: 10),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      color: CupertinoColors.white,
                      onPressed: widget.onGoToExplore,
                      child: const Text(
                        '回興趣探索',
                        style: TextStyle(
                          color: Color(0xFF18181B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            DailyQuestionCard(
              question: question,
              answered: answeredToday,
              onAnswer: (v) => _answer(question, v),
            ),
            const SizedBox(height: 18),
            _PlanCard(
              title: '推薦方向',
              subtitle: '你可能會喜歡',
              child: Column(
                children: [
                  for (final r in plan.recommendedRoles.take(4))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _openRole(r),
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
                              Text(
                                r.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                r.tagline,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF3F3F46),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final s in r.skills.take(4))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.white,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: const Color(0x1A000000),
                                        ),
                                      ),
                                      child: Text(
                                        s,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF3F3F46),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _PlanCard(
              title: '4–8 週行動計畫',
              subtitle: '從今天就能開始',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '進度',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF52525B),
                        ),
                      ),
                      Text(
                        '${overall.done}/${overall.total}（${overall.pct}%）',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF52525B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 8,
                      child: Stack(
                        children: [
                          const ColoredBox(color: Color(0x1A000000)),
                          FractionallySizedBox(
                            widthFactor: overall.total == 0
                                ? 0
                                : overall.done / overall.total,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xAA10B981),
                                    Color(0xAA38BDF8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '勾選每週目標、資源與產出，並記錄週心得。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF3F3F46),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // CupertinoButton(
                  //   padding: const EdgeInsets.symmetric(
                  //     horizontal: 16,
                  //     vertical: 12,
                  //   ),
                  //   color: CupertinoColors.white,
                  //   onPressed: () {
                  //     Navigator.of(context).push(
                  //       CupertinoPageRoute<void>(
                  //         builder: (ctx) => PlanTodosScreen(
                  //           storage: widget.storage,
                  //           onStorageChanged: widget.onStorageChanged,
                  //         ),
                  //       ),
                  //     );
                  //   },
                  //   child: const Text(
                  //     '開啟任務清單',
                  //     style: TextStyle(
                  //       color: Color(0xFF18181B),
                  //       fontWeight: FontWeight.w600,
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '今日日期：$today（同一天題目固定）',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF52525B),
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  color: CupertinoColors.white,
                  onPressed: _confirmReset,
                  child: const Text(
                    '清空本機資料',
                    style: TextStyle(
                      color: Color(0xFF18181B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 36,
            offset: Offset(0, 22),
            color: Color(0x1F020617),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Color(0xFF52525B)),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _RoleDetailSheet extends StatelessWidget {
  const _RoleDetailSheet({required this.role, required this.onClose});

  final CareerRole role;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      builder: (context, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey4,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: onClose,
                      child: const Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    Text(
                      role.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      role.tagline,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFF3F3F46),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in role.tags)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F4F5),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0x1A000000),
                              ),
                            ),
                            child: Text(
                              '#${t.wireName}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF3F3F46),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _BulletPanel(
                            title: '代表技能',
                            accent: const Color(0xB30EA5E9),
                            items: role.skills,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BulletPanel(
                            title: '日常工作',
                            accent: const Color(0xB3D946EF),
                            items: role.dayToDay,
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
      },
    );
  }
}

class _BulletPanel extends StatelessWidget {
  const _BulletPanel({
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
          for (final s in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Color(0xFF18181B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
