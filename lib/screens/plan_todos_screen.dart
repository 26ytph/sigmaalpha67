import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../logic/generate_plan.dart';
import '../models/models.dart';
import '../services/app_repository.dart';
import '../utils/plan_todo_keys.dart';
import '../utils/theme.dart';

class PlanTodosScreen extends StatefulWidget {
  const PlanTodosScreen({
    super.key,
    required this.storage,
    required this.onStorageChanged,
  });

  final AppStorage storage;
  final ValueChanged<AppStorage> onStorageChanged;

  @override
  State<PlanTodosScreen> createState() => _PlanTodosScreenState();
}

class _PlanTodosScreenState extends State<PlanTodosScreen> {
  late int _activeWeek;

  @override
  void initState() {
    super.initState();
    final plan = generatePlan(widget.storage.explore.likedRoleIds);
    _activeWeek = plan.weeks.isNotEmpty ? plan.weeks.first.week : 1;
  }

  @override
  void didUpdateWidget(covariant PlanTodosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final plan = generatePlan(widget.storage.explore.likedRoleIds);
    if (plan.weeks.isEmpty) return;
    final first = plan.weeks.first.week;
    if (!plan.weeks.any((w) => w.week == _activeWeek)) {
      setState(() => _activeWeek = first);
    }
  }

  Future<void> _persist(AppStorage Function(AppStorage prev) fn) async {
    final next = await AppRepository.update(fn);
    widget.onStorageChanged(next);
  }

  ({int done, int total, int pct}) _weekProgress(PlanWeek w) {
    final keys = <String>[];
    for (var i = 0; i < w.goals.length; i++) {
      keys.add(makeTodoKey(w.week, 'goals', i));
    }
    for (var i = 0; i < w.resources.length; i++) {
      keys.add(makeTodoKey(w.week, 'resources', i));
    }
    for (var i = 0; i < w.outputs.length; i++) {
      keys.add(makeTodoKey(w.week, 'outputs', i));
    }
    final total = keys.length;
    var done = 0;
    for (final k in keys) {
      if (widget.storage.planTodos[k] == true) done++;
    }
    final pct = total == 0 ? 0 : ((done / total) * 100).round();
    return (done: done, total: total, pct: pct);
  }

  void _toggleTodo(int week, String section, int index) {
    final key = makeTodoKey(week, section, index);
    final done = !(widget.storage.planTodos[key] ?? false);
    unawaited(AppRepository.setPlanTodo(key: key, done: done));
    _persist((prev) {
      final nextTodos = Map<String, bool>.from(prev.planTodos);
      nextTodos[key] = done;
      return prev.copyWith(planTodos: nextTodos);
    });
  }

  /// 課程任務的 key 不綁週數，這樣同一門課在多週都會反映同一個完成狀態。
  static String courseTaskKey(String courseId) => 'course:$courseId';

  void _toggleCourseTask(String courseId) {
    final key = courseTaskKey(courseId);
    _persist((prev) {
      final nextTodos = Map<String, bool>.from(prev.planTodos);
      nextTodos[key] = !(nextTodos[key] ?? false);
      return prev.copyWith(planTodos: nextTodos);
    });
  }

  void _setWeekNote(int week, String note) {
    final key = '$week';
    unawaited(AppRepository.setWeekNote(week: week, note: note));
    _persist((prev) {
      final notes = Map<String, String>.from(prev.planWeekNotes);
      notes[key] = note;
      return prev.copyWith(planWeekNotes: notes);
    });
  }

  Widget _weekLinearProgress(({int done, int total, int pct}) p) {
    final v = p.total == 0 ? 0.0 : p.done / p.total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: v,
        minHeight: 8,
        backgroundColor: const Color(0x1A000000),
        color: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = generatePlan(widget.storage.explore.likedRoleIds);

    PlanWeek? activeWeekData;
    for (final w in plan.weeks) {
      if (w.week == _activeWeek) {
        activeWeekData = w;
        break;
      }
    }
    activeWeekData ??= plan.weeks.isNotEmpty ? plan.weeks.first : null;

    final weekProg = activeWeekData == null
        ? (done: 0, total: 0, pct: 0)
        : _weekProgress(activeWeekData);

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFFF5F8),
      navigationBar: const CupertinoNavigationBar(middle: Text('週任務清單')),
      child: SafeArea(
        child: plan.weeks.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '尚無週計畫。請先在探索頁選擇感興趣的職位。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Color(0xFF52525B)),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Text(
                    plan.headline,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '勾選每週目標、資源與產出，並記錄週心得。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF3F3F46),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionCard(
                    title: '4–8 週行動計畫',
                    subtitle: '從今天就能開始',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final w in plan.weeks)
                                _WeekProgressSelectorTile(
                                  week: w,
                                  progress: _weekProgress(w),
                                  selected: _activeWeek == w.week,
                                  onTap: () =>
                                      setState(() => _activeWeek = w.week),
                                ),
                            ],
                          ),
                        ),
                        if (activeWeekData != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: CupertinoColors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0x1A000000),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '第 ${activeWeekData.week} 週',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF52525B),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            activeWeekData.title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '本週 ${weekProg.done}/${weekProg.total}（${weekProg.pct}%）',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF52525B),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _weekLinearProgress(weekProg),
                                const SizedBox(height: 14),
                                Builder(
                                  builder: (context) {
                                    final wk = activeWeekData!;
                                    final narrow =
                                        MediaQuery.sizeOf(context).width < 520;
                                    if (narrow) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _TodoColumn(
                                            label: '目標',
                                            section: 'goals',
                                            items: wk.goals,
                                            week: wk.week,
                                            storage: widget.storage,
                                            onToggle: _toggleTodo,
                                          ),
                                          const SizedBox(height: 14),
                                          _TodoColumn(
                                            label: '資源',
                                            section: 'resources',
                                            items: wk.resources,
                                            week: wk.week,
                                            storage: widget.storage,
                                            onToggle: _toggleTodo,
                                          ),
                                          const SizedBox(height: 14),
                                          _TodoColumn(
                                            label: '產出',
                                            section: 'outputs',
                                            items: wk.outputs,
                                            week: wk.week,
                                            storage: widget.storage,
                                            onToggle: _toggleTodo,
                                          ),
                                        ],
                                      );
                                    }
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _TodoColumn(
                                            label: '目標',
                                            section: 'goals',
                                            items: wk.goals,
                                            week: wk.week,
                                            storage: widget.storage,
                                            onToggle: _toggleTodo,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _TodoColumn(
                                            label: '資源',
                                            section: 'resources',
                                            items: wk.resources,
                                            week: wk.week,
                                            storage: widget.storage,
                                            onToggle: _toggleTodo,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _TodoColumn(
                                            label: '產出',
                                            section: 'outputs',
                                            items: wk.outputs,
                                            week: wk.week,
                                            storage: widget.storage,
                                            onToggle: _toggleTodo,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                _WeekCoursesPanel(
                                  week: activeWeekData.week,
                                  courses: plan.courses
                                      .where(
                                        (c) =>
                                            c.spansWeek(activeWeekData!.week),
                                      )
                                      .toList(),
                                  storage: widget.storage,
                                  onToggleCourse: _toggleCourseTask,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F4F5),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0x1A000000),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            '任務完成心得',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF3F3F46),
                                            ),
                                          ),
                                          Text(
                                            '第 ${activeWeekData.week} 週',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF71717A),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      _WeekNoteEditor(
                                        key: ValueKey(activeWeekData.week),
                                        week: activeWeekData.week,
                                        initialText:
                                            widget
                                                .storage
                                                .planWeekNotes['${activeWeekData.week}'] ??
                                            '',
                                        onChanged: (v) => _setWeekNote(
                                          activeWeekData!.week,
                                          v,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        '會自動保存到本機（SharedPreferences）',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF71717A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _WeekProgressSelectorTile extends StatelessWidget {
  const _WeekProgressSelectorTile({
    required this.week,
    required this.progress,
    required this.selected,
    required this.onTap,
  });

  final PlanWeek week;
  final ({int done, int total, int pct}) progress;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 10),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF4F4F5) : CupertinoColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? CupertinoColors.black : const Color(0x1A000000),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            '第 ${week.week} 週',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? const Color(0xFF18181B)
                  : const Color(0xFF27272A),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekNoteEditor extends StatefulWidget {
  const _WeekNoteEditor({
    super.key,
    required this.week,
    required this.initialText,
    required this.onChanged,
  });

  final int week;
  final String initialText;
  final ValueChanged<String> onChanged;

  @override
  State<_WeekNoteEditor> createState() => _WeekNoteEditorState();
}

class _WeekNoteEditorState extends State<_WeekNoteEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void didUpdateWidget(covariant _WeekNoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.week != widget.week) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: _controller,
      minLines: 4,
      maxLines: 8,
      placeholder: '寫下你這週完成任務的心得、卡住的點、下週要怎麼調整…',
      onChanged: widget.onChanged,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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

class _TodoColumn extends StatelessWidget {
  const _TodoColumn({
    required this.label,
    required this.section,
    required this.items,
    required this.week,
    required this.storage,
    required this.onToggle,
  });

  final String label;
  final String section;
  final List<String> items;
  final int week;
  final AppStorage storage;
  final void Function(int week, String section, int index) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: Color(0xFF52525B),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < items.length; i++)
          _TodoRow(
            text: items[i],
            done: storage.planTodos[makeTodoKey(week, section, i)] ?? false,
            onPressed: () => onToggle(week, section, i),
          ),
      ],
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({
    required this.text,
    required this.done,
    required this.onPressed,
  });

  final String text;
  final bool done;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      onPressed: onPressed,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? const Color(0xFFE8F8EE) : CupertinoColors.white,
              border: Border.all(
                color: done ? const Color(0xFF86EFAC) : const Color(0x26000000),
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: done
                ? const Icon(
                    CupertinoIcons.check_mark,
                    size: 12,
                    color: Color(0xFF047857),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                decoration: done
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                color: done ? const Color(0xFF71717A) : const Color(0xFF18181B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 推薦課程／證照面板：每門課就是一個任務（有 checkbox）。
/// 完成任務即等同完成課程；同一門課跨多週時，狀態共用。
class _WeekCoursesPanel extends StatelessWidget {
  const _WeekCoursesPanel({
    required this.week,
    required this.courses,
    required this.storage,
    required this.onToggleCourse,
  });

  final int week;
  final List<RecommendedCourse> courses;
  final AppStorage storage;
  final ValueChanged<String> onToggleCourse;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(CupertinoIcons.book, size: 14, color: AppColors.textTertiary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '本週沒有特別推薦課程，先把任務做完即可。',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.book_fill,
                size: 14,
                color: AppColors.iosBlue,
              ),
              const SizedBox(width: 6),
              const Text(
                '本週課程任務',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppColors.iosBlue,
                ),
              ),
              const Spacer(),
              Text(
                '${courses.length} 項 ・ 勾完代表完成課程',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < courses.length; i++) ...[
            if (i > 0)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                height: 1,
                color: AppColors.border,
              ),
            _CourseTaskTile(
              course: courses[i],
              done:
                  storage.planTodos['course:${courses[i].id}'] ?? false,
              onToggle: () => onToggleCourse(courses[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _CourseTaskTile extends StatelessWidget {
  const _CourseTaskTile({
    required this.course,
    required this.done,
    required this.onToggle,
  });

  final RecommendedCourse course;
  final bool done;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isCert = course.type == '證照';
    final tagColor = isCert ? AppColors.iosOrange : AppColors.iosBlue;
    final spanLabel = course.weeks.length > 1
        ? '第 ${course.weeks.first}–${course.weeks.last} 週'
        : '第 ${course.weeks.first} 週';

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // —— 上方：任務（可勾選）——
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? tagColor.withValues(alpha: 0.18) : AppColors.surface,
                  border: Border.all(
                    color: done ? tagColor : AppColors.borderStrong,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: done
                    ? Icon(CupertinoIcons.check_mark,
                        size: 14, color: tagColor)
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isCert ? '考取《${course.title}》' : '完成《${course.title}》',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    decoration: done
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: done
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  course.type,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: tagColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // —— 下方：課程詳細資訊 ——
          Container(
            margin: const EdgeInsets.only(left: 32),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isCert
                          ? CupertinoIcons.rosette
                          : CupertinoIcons.play_rectangle,
                      size: 12,
                      color: tagColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        course.provider,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      spanLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  course.detail,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
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
}
