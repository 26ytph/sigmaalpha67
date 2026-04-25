import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

import '../data/roles.dart';
import '../data/startup_skills.dart';
import '../logic/generate_plan.dart' as plan;
import '../models/models.dart';
import '../services/app_repository.dart';
import '../utils/theme.dart';

/// 職涯路徑頁：兩個內建分頁
///   - Tab 0：Roadmap 地圖 — 串連最多 4 個 week 節點 + 1 個 goal。
///   - Tab 1：每週 Todo List — 真正可編輯的任務清單。
///
/// 資料源
/// ────────
/// 真正驅動畫面的是 [AppStorage.customPlan]：每個任務都有 stable id，
/// 使用者勾選 / 編輯 / 刪除 / 新增 → 直接寫進 SharedPreferences（透過
/// [AppRepository.updateCustomPlan]）。重啟 app 不會清空。
///
/// 第一次進來若 `customPlan` 為空：用本機 [plan.generatePlan] seed 一份
/// （給 task 補 id），同時背景打 `POST /api/plan/generate`，如果有
/// GEMINI_API_KEY 就會拿到 AI 客製版蓋過本機模板。
///
/// AI 更新
/// ────────
/// 「告訴 AI 你的目標」按鈕會打開 prompt 輸入框，把使用者輸入連同當前
/// `customPlan` 一起送到 `/api/plan/refine`。Gemini 會依需求改寫計畫，
/// 後端保證每個 task 都有 id；前端再依 id（或 title）merge 回舊的勾選
/// 狀態與使用者新增的任務。
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
  bool _aiRefining = false;
  final ScrollController _todoScroll = ScrollController();
  final Map<int, GlobalKey> _weekKeys = {};

  @override
  void initState() {
    super.initState();
    _seedIfNeeded();
  }

  @override
  void didUpdateWidget(covariant CareerPathScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 若使用者第一次完成 Onboarding 或剛滑完卡才回到這頁，
    // customPlan 仍可能是空的；補 seed。
    _seedIfNeeded();
  }

  /// 第一次進來 / customPlan 還沒任何 task → 用本機模板先 seed，
  /// 再背景撈 AI 客製版蓋掉。已經有 plan 就不動，避免覆蓋使用者編輯。
  Future<void> _seedIfNeeded() async {
    if (!widget.storage.customPlan.isEmpty) return;
    final localPlan = plan.generatePlan(
      widget.storage.explore.likedRoleIds,
      mode: widget.storage.profile.mode,
    );
    if (localPlan.weeks.isEmpty) return; // 沒滑過卡，等使用者去探索
    final seeded = AppRepository.customPlanFromGenerated(
      localPlan,
      goalPrompt: '',
    );
    final next = await AppRepository.setCustomPlan(seeded);
    if (!mounted) return;
    widget.onStorageChanged(next);

    // 背景：嘗試打後端 LLM。失敗就保留本機 seed 版。
    _hydrateFromBackend();
  }

  Future<void> _hydrateFromBackend() async {
    if (_aiPlanLoading) return;
    setState(() => _aiPlanLoading = true);
    final result = await AppRepository.fetchPlan(widget.storage);
    if (!mounted) {
      return;
    }
    if (!result.fromBackend) {
      setState(() => _aiPlanLoading = false);
      return;
    }
    // 用後端版重新 seed（保留使用者已勾選 / userAdded 的任務）。
    final aiSeed = AppRepository.customPlanFromGenerated(
      result.plan,
      goalPrompt: widget.storage.customPlan.goalPrompt,
    ).copyWith(fromAi: true);
    final merged = _mergeKeepUserState(
      previous: widget.storage.customPlan,
      next: aiSeed,
    );
    final updated = await AppRepository.setCustomPlan(merged);
    if (!mounted) return;
    setState(() => _aiPlanLoading = false);
    widget.onStorageChanged(updated);
  }

  /// 把舊計畫裡 user 已勾選 / userAdded 的東西 merge 進新計畫。
  /// 先用 task.id 對應；對不上時 fallback 用 title 比對。
  CustomPlan _mergeKeepUserState({
    required CustomPlan previous,
    required CustomPlan next,
  }) {
    final byId = <String, PlanTask>{};
    final byTitle = <String, PlanTask>{};
    final userAddedByWeek = <int, List<PlanTask>>{};
    for (final w in previous.weeks) {
      for (final t in w.tasks) {
        byId[t.id] = t;
        byTitle[t.title.trim().toLowerCase()] = t;
        if (t.userAdded) {
          userAddedByWeek.putIfAbsent(w.week, () => []).add(t);
        }
      }
    }
    final mergedWeeks = <CustomPlanWeek>[];
    for (final w in next.weeks) {
      final mergedTasks = <PlanTask>[];
      for (final t in w.tasks) {
        final old = byId[t.id] ?? byTitle[t.title.trim().toLowerCase()];
        if (old != null) {
          mergedTasks.add(
            t.copyWith(
              id: old.id,
              done: old.done,
              userAdded: old.userAdded,
            ),
          );
        } else {
          mergedTasks.add(t);
        }
      }
      // 把使用者自己加在這週的 task 接回來（避免被新版蓋掉）。
      final extras = userAddedByWeek[w.week] ?? const <PlanTask>[];
      for (final extra in extras) {
        if (!mergedTasks.any((m) => m.id == extra.id)) {
          mergedTasks.add(extra);
        }
      }
      mergedWeeks.add(
        CustomPlanWeek(week: w.week, title: w.title, tasks: mergedTasks),
      );
    }
    return next.copyWith(weeks: mergedWeeks);
  }

  // —— 取資料 ——————————————————————————————————————————

  CustomPlan get _plan => widget.storage.customPlan;
  bool get _planFromBackend => _plan.fromAi;

  CustomPlanWeek? _findWeek(int weekNum) {
    for (final w in _plan.weeks) {
      if (w.week == weekNum) return w;
    }
    return null;
  }

  /// 一週要顯示的 todo：以 goals + outputs 為主，最多 6 條。
  /// 若只有 goals 也算數；包含 user 新增的 task。
  List<PlanTask> _todosFor(int weekNum) {
    final w = _findWeek(weekNum);
    if (w == null) return const [];
    final filtered = [
      ...w.tasks.where((t) => t.section == 'goals'),
      ...w.tasks.where((t) => t.section == 'outputs'),
    ];
    return filtered.take(6).toList(growable: false);
  }

  bool _isDoneById(String id) {
    for (final w in _plan.weeks) {
      for (final t in w.tasks) {
        if (t.id == id) return t.done;
      }
    }
    return false;
  }

  // —— Mutations：所有 todo 編輯走這條 ——————————————————————

  Future<void> _persistPlanMutation(
    CustomPlan Function(CustomPlan prev) mut,
  ) async {
    final next = await AppRepository.updateCustomPlan(mut);
    if (!mounted) return;
    widget.onStorageChanged(next);
  }

  void _toggleTask(String taskId) {
    _persistPlanMutation((prev) => _mapTask(prev, taskId, (t) {
          return t.copyWith(done: !t.done);
        }));
  }

  void _editTaskTitle(String taskId, String newTitle) {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    _persistPlanMutation((prev) => _mapTask(prev, taskId, (t) {
          return t.copyWith(title: trimmed, userEdited: true);
        }));
  }

  void _deleteTask(String taskId) {
    _persistPlanMutation((prev) {
      return prev.copyWith(
        weeks: prev.weeks
            .map(
              (w) => w.copyWith(
                tasks: w.tasks.where((t) => t.id != taskId).toList(),
              ),
            )
            .toList(),
      );
    });
  }

  void _addTaskToWeek(int weekNum, String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final id =
        'usr_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${trimmed.hashCode.abs().toRadixString(36)}';
    _persistPlanMutation((prev) {
      return prev.copyWith(
        weeks: prev.weeks.map((w) {
          if (w.week != weekNum) return w;
          return w.copyWith(
            tasks: [
              ...w.tasks,
              PlanTask(
                id: id,
                title: trimmed,
                section: 'goals',
                userAdded: true,
              ),
            ],
          );
        }).toList(),
      );
    });
  }

  CustomPlan _mapTask(
    CustomPlan prev,
    String taskId,
    PlanTask Function(PlanTask t) f,
  ) {
    return prev.copyWith(
      weeks: prev.weeks
          .map(
            (w) => w.copyWith(
              tasks: w.tasks.map((t) => t.id == taskId ? f(t) : t).toList(),
            ),
          )
          .toList(),
    );
  }

  double _weekCompletion(int weekNum) {
    final items = _todosFor(weekNum);
    if (items.isEmpty) return 0;
    var done = 0;
    for (final t in items) {
      if (t.done) done++;
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

  /// 本月目標：customPlan.goalPrompt > persona.recommendedNextStep > goals[0] > headline。
  String get _monthGoal {
    if (_plan.goalPrompt.trim().isNotEmpty) return _plan.goalPrompt.trim();
    final persona = widget.storage.persona;
    final profile = widget.storage.profile;
    if (persona.recommendedNextStep.isNotEmpty) {
      return persona.recommendedNextStep;
    }
    if (profile.goals.isNotEmpty) return profile.goals.first;
    if (_plan.headline.isNotEmpty) return _plan.headline;
    return '先做出方向感：用 4–8 週找到你的下一步';
  }

  String get _monthSub {
    final profile = widget.storage.profile;
    if (_plan.weeks.isEmpty) {
      return profile.name.isEmpty
          ? '到「滑卡探索」按 ❤ 一些有興趣的職位，這條路線就會自動長出來 ✨'
          : '${profile.name}，去滑卡 ❤ 一些有興趣的職位，這個月的任務就會跟你對齊 ✨';
    }
    if (_plan.goalPrompt.trim().isNotEmpty) {
      return '已根據你的目標客製化任務，可以隨時點下方按鈕再更新。';
    }
    if (profile.currentStage.isNotEmpty) {
      return '${profile.currentStage}階段，先把這幾週的能力打底。';
    }
    return '一步一步來，不急著馬上找到答案。';
  }

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

  // —— Tab navigation ————————————————————————————————————

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

  // —— 「同步」流程 ——————————————————————————————————————
  // 1. 先打 refreshAll 把 profile / persona / swipes / translations 從後端拉回。
  // 2. 算「跟上次同步比起來」的 delta（新增 ❤ 滑卡 / profile 動了 / persona 動了 /
  //    新技能翻譯）。
  // 3. 三條岔路：
  //    a. refreshAll 全失敗 → 顯示無法連線。
  //    b. delta 全空 → 顯示「無資料」（沒有新東西不要白打 AI）。
  //    c. 有 delta → 跳出多選 sheet 讓使用者勾要餵給 AI 的滑卡。

  /// 找 role：先在 [roles]（求職）裡找，沒有再到 [startupSkills]（創業）。
  CareerRole? _lookupRole(String id) {
    for (final r in roles) {
      if (r.id == id) return r;
    }
    return findStartupSkillById(id);
  }

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
      _showDialog(title: '無法連線', body: '剛剛沒拿到任何資料。已沿用本機現況。');
      return;
    }

    final delta = AppRepository.diffSync(result.storage);
    final hasAnyData =
        result.storage.explore.likedRoleIds.isNotEmpty ||
            !result.storage.profile.isEmpty;
    final nothingNew = !delta.firstSync &&
        delta.newLikedRoleIds.isEmpty &&
        !delta.profileChanged &&
        !delta.personaChanged &&
        delta.newTranslationCount == 0;

    if (nothingNew || (!hasAnyData && delta.firstSync)) {
      _showDialog(
        title: '無資料',
        body: '當下沒有新的滑卡或個人資料更新。\n滑幾張卡或更新 Persona 之後再回來同步看看 🌸',
      );
      // 標記同步時間，但不改其他指紋（reflects "已 ack 過目前狀態"）
      final next =
          await AppRepository.markSyncedNow(result.storage);
      if (!mounted) return;
      widget.onStorageChanged(next);
      return;
    }

    await _openSyncSelectSheet(
      delta: delta,
      profileChanged: delta.profileChanged,
      personaChanged: delta.personaChanged,
      newTranslationCount: delta.newTranslationCount,
    );
  }

  /// 多選 sheet：兩區（個人 Persona / 興趣滑卡），使用者勾完按「依所選更新計畫」
  /// 把所選 persona 條目 + role 串成 prompt 送給 AI refine。
  ///
  /// 滑卡會自動去重（後端 `buildSwipeSummary` 已 dedupe，這裡再保險一次），
  /// 避免同一張卡因為被滑很多次出現多次。
  Future<void> _openSyncSelectSheet({
    required ({
      List<RoleId> newLikedRoleIds,
      List<RoleId> allLikedRoleIds,
      bool profileChanged,
      bool personaChanged,
      int newTranslationCount,
      bool firstSync,
    }) delta,
    required bool profileChanged,
    required bool personaChanged,
    required int newTranslationCount,
  }) async {
    // 去重 — 同一個 id 只 lookup 一次。
    final seen = <String>{};
    final allRoles = <CareerRole>[];
    for (final id in delta.allLikedRoleIds) {
      if (!seen.add(id)) continue;
      final role = _lookupRole(id);
      if (role != null) allRoles.add(role);
    }
    final newSet = delta.newLikedRoleIds.toSet();

    // Persona 區候選：mainInterests + strengths + skillGaps，去重。
    final persona = widget.storage.persona;
    final personaItems = <_PersonaItem>[];
    final personaSeen = <String>{};
    for (final s in persona.mainInterests) {
      if (s.trim().isEmpty || !personaSeen.add(s)) continue;
      personaItems.add(_PersonaItem(label: s, kind: _PersonaKind.interest));
    }
    for (final s in persona.strengths) {
      if (s.trim().isEmpty || !personaSeen.add(s)) continue;
      personaItems.add(_PersonaItem(label: s, kind: _PersonaKind.strength));
    }
    for (final s in persona.skillGaps) {
      if (s.trim().isEmpty || !personaSeen.add(s)) continue;
      personaItems.add(_PersonaItem(label: s, kind: _PersonaKind.skillGap));
    }

    final picked = await showCupertinoModalPopup<_SyncPick>(
      context: context,
      builder: (ctx) => _SyncSelectSheet(
        roles: allRoles,
        newRoleIdSet: newSet,
        personaItems: personaItems,
        profileChanged: profileChanged,
        personaChanged: personaChanged,
        newTranslationCount: newTranslationCount,
        firstSync: delta.firstSync,
      ),
    );
    if (picked == null) {
      // 使用者取消 → 不動同步指紋，下次按同步還會看到同樣的 sheet。
      return;
    }
    if (picked.roleIds.isEmpty && picked.personaLabels.isEmpty) {
      _showDialog(title: '沒選任何項目', body: '請至少在 Persona 或滑卡其中一區勾一個。');
      return;
    }

    // 把所選資料串成自然語言 prompt。
    final selectedRoles = <CareerRole>[];
    final pickedSeen = <String>{};
    for (final id in picked.roleIds) {
      if (!pickedSeen.add(id)) continue;
      final role = _lookupRole(id);
      if (role != null) selectedRoles.add(role);
    }
    final roleNames = selectedRoles.map((r) => r.title).toList();
    final newOnes = selectedRoles.where((r) => newSet.contains(r.id)).toList();

    final promptParts = <String>[];
    if (picked.personaLabels.isNotEmpty) {
      promptParts.add(
        '個人 Persona 重點：${picked.personaLabels.join('、')}。',
      );
    }
    if (newOnes.isNotEmpty) {
      promptParts.add(
        '我最近新喜歡了：${newOnes.map((r) => r.title).join('、')}。',
      );
    }
    if (roleNames.isNotEmpty) {
      promptParts.add('幫我把計畫聚焦在這些方向：${roleNames.join('、')}。');
    }
    if (profileChanged || personaChanged) {
      promptParts.add('我的 Persona / 個人資料剛剛更新了，請一併考慮。');
    }
    final composedPrompt = promptParts.join(' ');

    await _runAiRefine(composedPrompt);
    final fresh = await AppRepository.markSyncedNow(widget.storage);
    if (!mounted) return;
    widget.onStorageChanged(fresh);
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

  // —— AI prompt sheet：使用者口語化更新計畫 ——————————————————

  Future<void> _openAiRefineSheet() async {
    final initial = _plan.goalPrompt;
    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => _AiRefineSheet(initialPrompt: initial),
    );
    if (result == null) return;
    final prompt = result.trim();
    if (prompt.isEmpty) return;
    await _runAiRefine(prompt);
  }

  Future<void> _runAiRefine(String prompt) async {
    if (_aiRefining) return;
    setState(() => _aiRefining = true);
    final res = await AppRepository.refinePlanWithAi(
      prompt: prompt,
      storage: widget.storage,
    );
    if (!mounted) return;
    setState(() => _aiRefining = false);
    if (res == null) {
      _showDialog(
        title: '無法連到後端',
        body: '請檢查 backend 是否有跑（預設 localhost:3001），或網路狀況。',
      );
      return;
    }
    final fresh = await AppRepository.update((p) => p);
    if (!mounted) return;
    widget.onStorageChanged(fresh);
    if (res.fromAi) {
      _showDialog(
        title: '計畫已根據你的目標更新 ✨',
        body: '勾選過的任務若仍然合理會保留打勾狀態。\n你可以再點任意任務 → 編輯 / 刪除來微調。',
      );
    } else {
      // 後端有回但 Gemini 沒成功 → 顯示具體錯誤訊息給使用者，不只是「暫無 AI 結果」。
      final reason = (res.message ?? '').trim();
      _showDialog(
        title: 'AI 暫時無法更新',
        body: reason.isEmpty
            ? '後端有收到請求但 Gemini 沒生成內容。請稍後再試。'
            : '$reason\n\n你還是可以手動編輯任務、或稍後再試一次。',
      );
    }
  }

  // —— 編輯 / 新增任務的 modal ————————————————————————————

  Future<void> _openEditTaskSheet(PlanTask task) async {
    final newTitle = await _showTextInputDialog(
      context: context,
      title: '編輯任務',
      initialText: task.title,
      placeholder: '任務內容',
      submitLabel: '儲存',
    );
    if (newTitle == null) return;
    if (newTitle.trim().isEmpty) {
      _deleteTask(task.id);
    } else {
      _editTaskTitle(task.id, newTitle);
    }
  }

  Future<void> _openAddTaskSheet(int weekNum) async {
    final title = await _showTextInputDialog(
      context: context,
      title: '新增任務（第 $weekNum 週）',
      initialText: '',
      placeholder: '例如：跟學長約一次 mock interview',
      submitLabel: '加入',
    );
    if (title == null) return;
    _addTaskToWeek(weekNum, title);
  }

  Future<String?> _showTextInputDialog({
    required BuildContext context,
    required String title,
    required String initialText,
    required String placeholder,
    required String submitLabel,
  }) async {
    final controller = TextEditingController(text: initialText);
    return showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            autofocus: true,
            minLines: 1,
            maxLines: 4,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(submitLabel),
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

  // —— Build ————————————————————————————————————————————

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
                        completionFor: (w) => _weekCompletion(w.week),
                        onTapWeek: _jumpToWeek,
                        userName: widget.storage.profile.name,
                        onOpenExplore: widget.onOpenExplore,
                      )
                    : _TodoListView(
                        key: const ValueKey('todos'),
                        scrollController: _todoScroll,
                        weeks: weeks,
                        weekKeys: _weekKeys,
                        todosFor: (w) => _todosFor(w.week),
                        isDoneById: _isDoneById,
                        onToggle: _toggleTask,
                        onEdit: _openEditTaskSheet,
                        onDelete: _deleteTask,
                        onAddTask: _openAddTaskSheet,
                        monthLabel: _monthLabel,
                        monthGoal: _monthGoal,
                        monthSub: _monthSub,
                        interests: _topInterests,
                        aiCustomized: _planFromBackend,
                        aiLoading: _aiPlanLoading,
                        aiRefining: _aiRefining,
                        refreshing: _refreshing,
                        onCheckUpdates: _checkUpdates,
                        onAiRefine: _openAiRefineSheet,
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
                color:
                    selected ? CupertinoColors.white : AppColors.textSecondary,
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

  final List<CustomPlanWeek> weeks;
  final double Function(CustomPlanWeek week) completionFor;
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
                            sublabel:
                                i < weeks.length ? weeks[i].title : '完成本月目標',
                            isGoal: i == positions.length - 1,
                            progress:
                                i < weeks.length ? completionFor(weeks[i]) : null,
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
            border:
                borderColor != null ? Border.all(color: borderColor!) : null,
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
    required this.isDoneById,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onAddTask,
    required this.monthLabel,
    required this.monthGoal,
    required this.monthSub,
    required this.interests,
    required this.aiCustomized,
    required this.aiLoading,
    required this.aiRefining,
    required this.refreshing,
    required this.onCheckUpdates,
    required this.onAiRefine,
    required this.onOpenExplore,
  });

  final ScrollController scrollController;
  final List<CustomPlanWeek> weeks;
  final Map<int, GlobalKey> weekKeys;
  final List<PlanTask> Function(CustomPlanWeek week) todosFor;
  final bool Function(String id) isDoneById;
  final void Function(String taskId) onToggle;
  final Future<void> Function(PlanTask task) onEdit;
  final void Function(String taskId) onDelete;
  final Future<void> Function(int weekNum) onAddTask;
  final String monthLabel;
  final String monthGoal;
  final String monthSub;
  final List<String> interests;
  final bool aiCustomized;
  final bool aiLoading;
  final bool aiRefining;
  final bool refreshing;
  final VoidCallback onCheckUpdates;
  final VoidCallback onAiRefine;
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
                      isDoneById: isDoneById,
                      onToggle: onToggle,
                      onEdit: onEdit,
                      onDelete: onDelete,
                      onAdd: () => onAddTask(w.week),
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
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    color: AppColors.brandStart,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    onPressed: aiRefining ? null : onAiRefine,
                    child: aiRefining
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CupertinoActivityIndicator(
                                color: CupertinoColors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'AI 更新中…',
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
                                CupertinoIcons.sparkles,
                                size: 18,
                                color: CupertinoColors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '告訴 AI 你的目標',
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
                AppGaps.h8,
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    onPressed: refreshing ? null : onCheckUpdates,
                    child: refreshing
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CupertinoActivityIndicator(),
                              SizedBox(width: 8),
                              Text(
                                '同步中…',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.refresh_circled,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(width: 6),
                              Text(
                                '同步個人資料 / 滑卡結果',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
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
            '到「滑卡探索」按 ❤ 一些有興趣的職位，這個月的任務就會自己長出來。\n或是直接點下面的「告訴 AI 你的目標」自己出題。',
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
                const _AiBadge(label: 'AI 客製中…', showSpinner: true)
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
    required this.isDoneById,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  final CustomPlanWeek week;
  final List<PlanTask> todos;
  final bool Function(String id) isDoneById;
  final void Function(String taskId) onToggle;
  final Future<void> Function(PlanTask task) onEdit;
  final void Function(String taskId) onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final doneCount = [for (final t in todos) if (isDoneById(t.id)) 1].length;
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
          for (final t in todos)
            _TodoRow(
              key: ValueKey(t.id),
              task: t,
              done: isDoneById(t.id),
              onTap: () => onToggle(t.id),
              onEdit: () => onEdit(t),
              onDelete: () => onDelete(t.id),
            ),
          AppGaps.h6,
          Align(
            alignment: Alignment.centerLeft,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              minimumSize: Size.zero,
              onPressed: onAdd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    CupertinoIcons.add_circled,
                    size: 14,
                    color: AppColors.brandStart,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '新增任務',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandStart,
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

class _TodoRow extends StatelessWidget {
  const _TodoRow({
    super.key,
    required this.task,
    required this.done,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final PlanTask task;
  final bool done;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 勾選框
          CupertinoButton(
            padding: const EdgeInsets.all(6),
            minimumSize: Size.zero,
            onPressed: onTap,
            child: AnimatedContainer(
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
          ),
          // 內容（點擊也視為勾選 / 取消）
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          decorationColor: AppColors.textTertiary,
                          color: done
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (task.userAdded || task.userEdited) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandStart.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          task.userAdded ? '自訂' : '已編輯',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandStart,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // overflow 選單
          CupertinoButton(
            padding: const EdgeInsets.all(6),
            minimumSize: Size.zero,
            onPressed: () => _showActions(context),
            child: const Icon(
              Icons.more_vert,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          task.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              onEdit();
            },
            child: const Text('編輯任務'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('刪除這個任務'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
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

// =============================================================================
// AI Refine sheet — 使用者用自然語言告訴 AI 他要什麼
// =============================================================================

class _AiRefineSheet extends StatefulWidget {
  const _AiRefineSheet({required this.initialPrompt});
  final String initialPrompt;

  @override
  State<_AiRefineSheet> createState() => _AiRefineSheetState();
}

class _AiRefineSheetState extends State<_AiRefineSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialPrompt);

  static const _quickPrompts = [
    '我想投 DevOps 實習',
    '我已經會 Docker 了，幫我跳過',
    '把焦點轉到後端工程，弱化前端',
    '我想做 UX Research，幫我加上訪談技巧',
    '計畫太重了，幫我精簡到一週只做 2 件事',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.separator,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              AppGaps.h12,
              Row(
                children: const [
                  Icon(
                    CupertinoIcons.sparkles,
                    size: 18,
                    color: AppColors.brandStart,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '告訴 AI 你的目標',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              AppGaps.h6,
              const Text(
                '比如「我想投 DevOps 實習」「我已經會 Docker 了」「把焦點轉到後端」。\n'
                'AI 會依現有計畫調整，已勾選的任務會盡量保留打勾。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  color: AppColors.textSecondary,
                ),
              ),
              AppGaps.h14,
              CupertinoTextField(
                controller: _controller,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                placeholder: '輸入一段話...',
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: AppColors.separator),
                ),
              ),
              AppGaps.h10,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in _quickPrompts)
                    GestureDetector(
                      onTap: () => setState(() => _controller.text = p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(color: AppColors.separator),
                        ),
                        child: Text(
                          p,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              AppGaps.h16,
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: AppColors.brandStart,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      onPressed: () =>
                          Navigator.pop(context, _controller.text),
                      child: const Text(
                        '送出給 AI',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 同步多選 sheet：列出目前 ❤ 過的滑卡，使用者可勾要餵給 AI 計畫的那幾張。
// 新滑（自上次同步後）的卡會打 NEW 標、預設勾選；老的預設不勾。
// =============================================================================

enum _PersonaKind { interest, strength, skillGap }

extension on _PersonaKind {
  String get sectionLabel {
    switch (this) {
      case _PersonaKind.interest:
        return '興趣方向';
      case _PersonaKind.strength:
        return '已具備能力';
      case _PersonaKind.skillGap:
        return '待補強';
    }
  }

  Color get accent {
    switch (this) {
      case _PersonaKind.interest:
        return AppColors.brandStart;
      case _PersonaKind.strength:
        return AppColors.iosGreen;
      case _PersonaKind.skillGap:
        return AppColors.iosOrange;
    }
  }
}

class _PersonaItem {
  const _PersonaItem({required this.label, required this.kind});
  final String label;
  final _PersonaKind kind;
}

/// _SyncSelectSheet 使用者勾完按 confirm 後送回的東西。
/// `roleIds` = 要送進 AI 計畫的滑卡 id；
/// `personaLabels` = 要送進 AI 計畫的 persona 條目（mainInterests / strengths / skillGaps）。
class _SyncPick {
  const _SyncPick({required this.roleIds, required this.personaLabels});
  final List<RoleId> roleIds;
  final List<String> personaLabels;
}

class _SyncSelectSheet extends StatefulWidget {
  const _SyncSelectSheet({
    required this.roles,
    required this.newRoleIdSet,
    required this.personaItems,
    required this.profileChanged,
    required this.personaChanged,
    required this.newTranslationCount,
    required this.firstSync,
  });

  final List<CareerRole> roles;
  final Set<String> newRoleIdSet;
  final List<_PersonaItem> personaItems;
  final bool profileChanged;
  final bool personaChanged;
  final int newTranslationCount;
  final bool firstSync;

  @override
  State<_SyncSelectSheet> createState() => _SyncSelectSheetState();
}

class _SyncSelectSheetState extends State<_SyncSelectSheet> {
  late final Set<String> _selectedRoles;
  late final Set<String> _selectedPersona;

  @override
  void initState() {
    super.initState();
    // 滑卡：第一次同步全選；之後預設只選新增加的，沒有新增就 fallback 全選。
    if (widget.firstSync) {
      _selectedRoles = widget.roles.map((r) => r.id).toSet();
    } else {
      _selectedRoles = {
        for (final r in widget.roles)
          if (widget.newRoleIdSet.contains(r.id)) r.id,
      };
      if (_selectedRoles.isEmpty) {
        _selectedRoles.addAll(widget.roles.map((r) => r.id));
      }
    }
    // Persona：預設全選（user 看到後再自己拿掉）。
    _selectedPersona = widget.personaItems.map((p) => p.label).toSet();
  }

  void _toggleRole(String id) {
    setState(() {
      _selectedRoles.contains(id)
          ? _selectedRoles.remove(id)
          : _selectedRoles.add(id);
    });
  }

  void _togglePersona(String label) {
    setState(() {
      _selectedPersona.contains(label)
          ? _selectedPersona.remove(label)
          : _selectedPersona.add(label);
    });
  }

  void _selectAllRoles() => setState(() {
        _selectedRoles
          ..clear()
          ..addAll(widget.roles.map((r) => r.id));
      });

  void _selectNoneRoles() => setState(() => _selectedRoles.clear());

  void _selectNewRolesOnly() => setState(() {
        _selectedRoles
          ..clear()
          ..addAll(widget.newRoleIdSet);
      });

  void _selectAllPersona() => setState(() {
        _selectedPersona
          ..clear()
          ..addAll(widget.personaItems.map((p) => p.label));
      });

  void _selectNonePersona() => setState(() => _selectedPersona.clear());

  bool get _hasAnyPick =>
      _selectedRoles.isNotEmpty || _selectedPersona.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxHeight = mq.size.height * 0.88;
    final newCount = widget.newRoleIdSet.length;
    final hasPersona = widget.personaItems.isNotEmpty;
    final hasRoles = widget.roles.isNotEmpty;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.separator,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        size: 18,
                        color: AppColors.brandStart,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '挑要套用的內容',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _summaryLine(newCount),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.55,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.border),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // —— 區 1：個人 Persona ——
                  if (hasPersona)
                    _SectionHeader(
                      title: '個人 Persona',
                      subtitle: '勾要 AI 在計畫裡參考的條目',
                      countLabel:
                          '${_selectedPersona.length} / ${widget.personaItems.length}',
                      actions: [
                        _miniBtn('全選', _selectAllPersona),
                        const SizedBox(width: 6),
                        _miniBtn('全不選', _selectNonePersona),
                      ],
                    )
                  else
                    const _SectionHeader(
                      title: '個人 Persona',
                      subtitle: '尚未有 Persona — 先去「我的檔案」生成 Persona',
                      countLabel: '0 / 0',
                      actions: [],
                    ),
                  if (hasPersona)
                    for (final p in widget.personaItems)
                      _PersonaSelectTile(
                        item: p,
                        selected: _selectedPersona.contains(p.label),
                        onTap: () => _togglePersona(p.label),
                      ),
                  const SizedBox(height: 10),

                  // —— 區 2：興趣滑卡 ——
                  _SectionHeader(
                    title: '興趣滑卡',
                    subtitle: '勾要 AI 把計畫聚焦到的職位 / 能力',
                    countLabel:
                        '${_selectedRoles.length} / ${widget.roles.length}',
                    actions: [
                      _miniBtn('全選', _selectAllRoles),
                      const SizedBox(width: 6),
                      _miniBtn('全不選', _selectNoneRoles),
                      if (newCount > 0) ...[
                        const SizedBox(width: 6),
                        _miniBtn('只選新滑的', _selectNewRolesOnly),
                      ],
                    ],
                  ),
                  if (!hasRoles)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Text(
                        '尚未 ❤ 任何滑卡，去「滑卡探索」按幾張再回來。',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  if (hasRoles)
                    for (final r in widget.roles)
                      _RoleSelectTile(
                        role: r,
                        selected: _selectedRoles.contains(r.id),
                        isNew: widget.newRoleIdSet.contains(r.id),
                        onTap: () => _toggleRole(r.id),
                      ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      onPressed: () => Navigator.pop(context, null),
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: AppColors.brandStart,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      onPressed: !_hasAnyPick
                          ? null
                          : () => Navigator.pop(
                                context,
                                _SyncPick(
                                  roleIds: _selectedRoles
                                      .toList(growable: false),
                                  personaLabels: _selectedPersona
                                      .toList(growable: false),
                                ),
                              ),
                      child: const Text(
                        '依所選更新計畫',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: CupertinoColors.white,
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

  String _summaryLine(int newCount) {
    final bits = <String>[];
    if (widget.firstSync) {
      bits.add('第一次同步');
    } else if (newCount > 0) {
      bits.add('新滑了 $newCount 張');
    } else {
      bits.add('沒有新滑卡');
    }
    if (widget.profileChanged) bits.add('個人資料有更新');
    if (widget.personaChanged) bits.add('Persona 有更新');
    if (widget.newTranslationCount > 0) {
      bits.add('${widget.newTranslationCount} 筆新技能翻譯');
    }
    return '${bits.join('・')}。下方兩區（Persona / 滑卡）都可以勾，沒勾的不會影響計畫。';
  }

  Widget _miniBtn(String label, VoidCallback onTap) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: AppColors.separator),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.countLabel,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final String countLabel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Text(
                countLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              height: 1.45,
              color: AppColors.textTertiary,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: actions),
          ],
        ],
      ),
    );
  }
}

class _PersonaSelectTile extends StatelessWidget {
  const _PersonaSelectTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _PersonaItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = item.kind.accent;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: selected ? accent : AppColors.separator,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? accent : AppColors.surfaceMuted,
                shape: BoxShape.circle,
                border: selected
                    ? null
                    : Border.all(color: AppColors.separator, width: 1.5),
              ),
              child: selected
                  ? const Icon(
                      CupertinoIcons.check_mark,
                      size: 14,
                      color: CupertinoColors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.kind.sectionLabel,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleSelectTile extends StatelessWidget {
  const _RoleSelectTile({
    required this.role,
    required this.selected,
    required this.isNew,
    required this.onTap,
  });

  final CareerRole role;
  final bool selected;
  final bool isNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandStart.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: selected ? AppColors.brandStart : AppColors.separator,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: selected ? AppColors.brandGradient : null,
                color: selected ? null : AppColors.surfaceMuted,
                shape: BoxShape.circle,
                border: selected
                    ? null
                    : Border.all(color: AppColors.separator, width: 1.5),
              ),
              child: selected
                  ? const Icon(
                      CupertinoIcons.check_mark,
                      size: 14,
                      color: CupertinoColors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          role.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isNew) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.iosGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: AppColors.iosGreen,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    role.tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: AppColors.textTertiary,
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
