import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logic/generate_plan.dart';
import '../logic/persona_engine.dart';
import '../logic/skill_translator.dart';
import '../models/models.dart';
import 'backend_api.dart';

const _storageKey = 'employa:v1';

class AppRepository {
  AppRepository._();

  static Future<AppStorage> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_storageKey);
    if (raw == null || raw.isEmpty) return AppStorage.empty();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppStorage.fromJson(map);
    } catch (_) {
      return AppStorage.empty();
    }
  }

  static Future<void> save(AppStorage storage) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_storageKey, jsonEncode(storage.toJson()));
  }

  static Future<AppStorage> update(
    AppStorage Function(AppStorage prev) updater,
  ) async {
    final prev = await load();
    final next = updater(prev);
    await save(next);
    return next;
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_storageKey);
  }

  static Future<bool> backendAvailable() => BackendApi.health();

  /// 登入完之後呼叫：去後端撈既有 profile / persona 寫回本機。
  /// 這樣換瀏覽器、清快取、或在新裝置登入，都不會被當成首次使用而被
  /// 強迫重新填一次 onboarding。
  ///
  /// 後端不通 / 沒有資料時，回傳目前的本機狀態，**不會**清掉本機資料。
  static Future<AppStorage> hydrateFromBackend() async {
    var current = await load();
    try {
      final remoteProfile = await BackendApi.fetchProfile();
      if (remoteProfile != null && !remoteProfile.isEmpty) {
        current = current.copyWith(profile: remoteProfile);
      }
    } catch (_) {
      // 網路 / token 問題 → 保留本機
    }
    try {
      final remotePersona = await BackendApi.fetchPersona();
      if (remotePersona != null && !remotePersona.isEmpty) {
        current = current.copyWith(persona: remotePersona);
      }
    } catch (_) {}
    await save(current);
    return current;
  }

  static Future<AppStorage> completeOnboarding({
    required UserProfile profile,
    required String selfIntro,
  }) async {
    final prev = await load();
    final localPersona = _buildPersona(
      prev: prev,
      profile: profile,
      selfIntro: selfIntro,
    );
    var next = prev.copyWith(profile: profile, persona: localPersona);
    await save(next);

    try {
      final remoteProfile = await BackendApi.saveProfile(profile);
      var remotePersona = await BackendApi.generatePersona(
        profile: remoteProfile,
        explore: prev.explore,
        skillTranslations: prev.skillTranslations,
        previousPersona: prev.persona.isEmpty ? null : prev.persona,
      );
      if (selfIntro.trim().isNotEmpty) {
        remotePersona = remotePersona.copyWith(
          text: selfIntro.trim(),
          userEdited: true,
          lastUpdated: DateTime.now().toIso8601String(),
        );
        unawaitedSafe(BackendApi.updatePersonaText(remotePersona.text));
      }
      next = next.copyWith(profile: remoteProfile, persona: remotePersona);
      await save(next);
    } catch (_) {
      // Local state is already saved; keep the app usable if backend is down.
    }
    return next;
  }

  static Future<void> syncProfile(UserProfile profile) async {
    try {
      await BackendApi.saveProfile(profile);
    } catch (_) {}
  }

  static Future<Persona?> syncPersonaText(String text) async {
    try {
      return await BackendApi.updatePersonaText(text);
    } catch (_) {
      return null;
    }
  }

  static Future<void> recordSwipe({
    required String cardId,
    required bool liked,
  }) async {
    try {
      await BackendApi.recordSwipe(cardId: cardId, liked: liked);
    } catch (_) {}
  }

  static Future<AppStorage> refreshPersonaFromBackend() async {
    final prev = await load();
    final localPersona = PersonaEngine.generate(
      profile: prev.profile,
      explore: prev.explore,
      skillTranslations: prev.skillTranslations,
      previous: prev.persona,
    );
    var next = prev.copyWith(persona: localPersona);
    await save(next);

    try {
      await BackendApi.saveProfile(prev.profile);
      final remotePersona = await BackendApi.refreshPersona(
        profile: prev.profile,
        explore: prev.explore,
        skillTranslations: prev.skillTranslations,
        previousPersona: prev.persona,
      );
      next = next.copyWith(persona: remotePersona);
      await save(next);
    } catch (_) {}
    return next;
  }

  static Future<SkillTranslation> translateSkill(String raw) async {
    try {
      return await BackendApi.translateSkill(raw);
    } catch (_) {
      return SkillTranslatorEngine.translate(raw);
    }
  }

  /// 從後端拉一份 LLM 客製化的 4 週計畫（`POST /api/plan/generate`）。
  ///
  /// 流程：
  ///   1. 先呼叫後端（後端會 try Gemini，失敗自動 fallback 到 template）。
  ///   2. 若整個 endpoint 都不通（離線、401），fallback 到本機
  ///      [generatePlan] — 同樣的 template，但跑在裝置上。
  ///
  /// 回傳的 [GeneratedPlan] 一定可用。`fromBackend` 表示這份是否真的
  /// 來自後端（用來在 UI 上區分「AI 客製」vs「本機模板」）。
  static Future<({GeneratedPlan plan, bool fromBackend})> fetchPlan(
    AppStorage storage,
  ) async {
    final remote = await BackendApi.generatePlan(
      mode: storage.profile.mode,
      likedRoleIds: storage.explore.likedRoleIds,
      persona: storage.persona.isEmpty ? null : storage.persona,
    );

    // 本機 plan：負責 basedOnTopTags / recommendedRoles / courses 這些
    // deterministic 的部分；如果後端 OK，再用後端的 headline + weeks
    // 蓋掉。
    final localPlan = generatePlan(
      storage.explore.likedRoleIds,
      mode: storage.profile.mode,
    );

    if (remote == null) {
      return (plan: localPlan, fromBackend: false);
    }

    final weeks = remote.weeks
        .map(
          (w) => PlanWeek(
            week: w.week,
            title: w.title,
            goals: w.goals,
            resources: w.resources,
            outputs: w.outputs,
          ),
        )
        .toList();

    return (
      plan: GeneratedPlan(
        basedOnLikedRoleIds: localPlan.basedOnLikedRoleIds,
        basedOnTopTags: localPlan.basedOnTopTags,
        recommendedRoles: localPlan.recommendedRoles,
        headline: remote.headline,
        weeks: weeks,
        courses: localPlan.courses,
      ),
      fromBackend: true,
    );
  }

  /// 一次重新整理職涯路徑頁需要的三份資料：profile / persona / 技能翻譯。
  ///
  /// 任何一段網路失敗都不影響其他段；對應的 `*Changed` 欄位回 `null`
  /// 代表那段沒拿到資料（例如離線、token 過期）。回傳的 [storage]
  /// 一定可用，最差就是維持本機現況。
  static Future<({
    AppStorage storage,
    bool? profileChanged,
    bool? personaChanged,
    int? exploreChanged,
    int? translationsChanged,
  })> refreshAll() async {
    final pre = await load();
    bool? profileChanged;
    bool? personaChanged;
    int? exploreChanged;
    int? translationsChanged;

    // 1) Profile
    try {
      final remote = await BackendApi.fetchProfile();
      if (remote != null && !remote.isEmpty) {
        profileChanged = !_profileEquals(pre.profile, remote);
        await save((await load()).copyWith(profile: remote));
      } else {
        profileChanged = false;
      }
    } catch (_) {
      profileChanged = null;
    }

    // 2) Persona
    try {
      final remote = await BackendApi.fetchPersona();
      if (remote != null && !remote.isEmpty) {
        final cur = await load();
        personaChanged = !_personaEquals(cur.persona, remote);
        await save(cur.copyWith(persona: remote));
      } else {
        personaChanged = false;
      }
    } catch (_) {
      personaChanged = null;
    }

    // 3) Swipe summary — likedRoleIds is the strongest signal for the
    //    roadmap because generatePlan() takes it as input.
    try {
      final remote = await BackendApi.fetchSwipeSummary();
      final cur = await load();
      final prevLiked = cur.explore.likedRoleIds;
      final delta = _stringListDelta(prevLiked, remote.likedRoleIds);
      exploreChanged = delta;
      await save(
        cur.copyWith(
          explore: cur.explore.copyWith(
            likedRoleIds: remote.likedRoleIds,
            dislikedRoleIds: remote.dislikedRoleIds,
          ),
        ),
      );
    } catch (_) {
      exploreChanged = null;
    }

    // 4) Skill translations
    try {
      final remote = await BackendApi.listSkillTranslations();
      final cur = await load();
      final prevById = {for (final t in cur.skillTranslations) t.id: t};
      var changed = 0;
      for (final t in remote) {
        final old = prevById[t.id];
        if (old == null || !_translationEquals(old, t)) changed++;
      }
      translationsChanged = changed;
      await save(cur.copyWith(skillTranslations: remote));
    } catch (_) {
      translationsChanged = null;
    }

    final storage = await load();
    return (
      storage: storage,
      profileChanged: profileChanged,
      personaChanged: personaChanged,
      exploreChanged: exploreChanged,
      translationsChanged: translationsChanged,
    );
  }

  /// 對稱差（不在意順序）— 回傳 a∆b 的元素數。
  static int _stringListDelta(List<String> a, List<String> b) {
    final sa = a.toSet();
    final sb = b.toSet();
    var n = 0;
    for (final x in sa) {
      if (!sb.contains(x)) n++;
    }
    for (final x in sb) {
      if (!sa.contains(x)) n++;
    }
    return n;
  }

  static bool _profileEquals(UserProfile a, UserProfile b) {
    if (a.name != b.name) return false;
    if (a.currentStage != b.currentStage) return false;
    if (a.startupInterest != b.startupInterest) return false;
    if (!_listEq(a.goals, b.goals)) return false;
    if (!_listEq(a.interests, b.interests)) return false;
    return true;
  }

  static bool _personaEquals(Persona a, Persona b) {
    if (a.text != b.text) return false;
    if (a.recommendedNextStep != b.recommendedNextStep) return false;
    if (!_listEq(a.mainInterests, b.mainInterests)) return false;
    if (!_listEq(a.strengths, b.strengths)) return false;
    return true;
  }

  static bool _translationEquals(SkillTranslation a, SkillTranslation b) {
    if (a.id != b.id) return false;
    if (a.rawExperience != b.rawExperience) return false;
    if (a.groups.length != b.groups.length) return false;
    for (var i = 0; i < a.groups.length; i++) {
      if (a.groups[i].experience != b.groups[i].experience) return false;
      if (!_listEq(a.groups[i].skills, b.groups[i].skills)) return false;
    }
    return true;
  }

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static Future<AppStorage> saveSkillTranslation(
    SkillTranslation translation,
  ) async {
    final prev = await load();
    final list = [...prev.skillTranslations, translation];
    final localPersona = PersonaEngine.generate(
      profile: prev.profile,
      explore: prev.explore,
      skillTranslations: list,
      previous: prev.persona,
    );
    final mergedLocal = prev.persona.userEdited
        ? prev.persona.copyWith(
            strengths: localPersona.strengths,
            skillGaps: localPersona.skillGaps,
            recommendedNextStep: localPersona.recommendedNextStep,
            lastUpdated: DateTime.now().toIso8601String(),
          )
        : localPersona;

    var next = prev.copyWith(skillTranslations: list, persona: mergedLocal);
    await save(next);

    try {
      final remotePersona = await BackendApi.saveSkillTranslation(translation);
      if (remotePersona != null) {
        next = next.copyWith(persona: remotePersona);
        await save(next);
      }
    } catch (_) {}
    return next;
  }

  static Future<BackendChatReply> sendChatMessage({
    String? conversationId,
    required String message,
    required AppMode mode,
  }) {
    return BackendApi.sendChatMessage(
      conversationId: conversationId,
      message: message,
      mode: mode,
    );
  }

  static Future<void> answerDailyQuestion({
    required String questionId,
    required String answer,
  }) async {
    try {
      await BackendApi.answerDailyQuestion(
        questionId: questionId,
        answer: answer,
      );
    } catch (_) {}
  }

  static Future<void> setPlanTodo({
    required String key,
    required bool done,
  }) async {
    try {
      await BackendApi.setTodo(key: key, done: done);
    } catch (_) {}
  }

  // ===========================================================================
  // CustomPlan 維護：使用者可編輯 / 可勾選 / 可 prompt 更新的計畫主資料源。
  // ===========================================================================

  /// 把 deterministic 的 [GeneratedPlan]（4–8 週模板）轉成可編輯的
  /// [CustomPlan]，每個任務指派 stable id。Seed 時用。
  static CustomPlan customPlanFromGenerated(
    GeneratedPlan src, {
    required String goalPrompt,
  }) {
    final weeks = <CustomPlanWeek>[];
    for (final w in src.weeks) {
      final tasks = <PlanTask>[];
      for (var i = 0; i < w.goals.length; i++) {
        tasks.add(
          PlanTask(
            id: _stableTaskId('w${w.week}', 'goals', i, w.goals[i]),
            title: w.goals[i],
            section: 'goals',
          ),
        );
      }
      for (var i = 0; i < w.resources.length; i++) {
        tasks.add(
          PlanTask(
            id: _stableTaskId('w${w.week}', 'resources', i, w.resources[i]),
            title: w.resources[i],
            section: 'resources',
          ),
        );
      }
      for (var i = 0; i < w.outputs.length; i++) {
        tasks.add(
          PlanTask(
            id: _stableTaskId('w${w.week}', 'outputs', i, w.outputs[i]),
            title: w.outputs[i],
            section: 'outputs',
          ),
        );
      }
      weeks.add(CustomPlanWeek(week: w.week, title: w.title, tasks: tasks));
    }
    return CustomPlan(
      headline: src.headline,
      weeks: weeks,
      goalPrompt: goalPrompt,
      lastUpdated: DateTime.now().toIso8601String(),
      fromAi: false,
    );
  }

  static int _idCounter = 0;
  static String _stableTaskId(
    String weekKey,
    String section,
    int idx,
    String seed,
  ) {
    _idCounter += 1;
    final h = seed.hashCode.abs().toRadixString(36);
    return 'tpl_${weekKey}_${section}_${idx}_${h}_$_idCounter';
  }

  /// 全部寫掉 customPlan（toggle / edit / delete / add 共用入口）。
  static Future<AppStorage> updateCustomPlan(
    CustomPlan Function(CustomPlan prev) updater,
  ) async {
    return update((prev) {
      final next = updater(prev.customPlan);
      return prev.copyWith(
        customPlan: next.copyWith(
          lastUpdated: DateTime.now().toIso8601String(),
        ),
      );
    });
  }

  /// 直接覆寫整份 customPlan（AI refine 完用）。
  static Future<AppStorage> setCustomPlan(CustomPlan plan) async {
    return update(
      (prev) => prev.copyWith(
        customPlan: plan.copyWith(
          lastUpdated: DateTime.now().toIso8601String(),
        ),
      ),
    );
  }

  /// 用 [BackendApi.refinePlan] 跑一輪 AI 更新；done 狀態與 userAdded 任務
  /// 在前端做 merge 以求穩定。回 null = AI 不可用，UI 應提示。
  static Future<({CustomPlan plan, bool fromAi})?> refinePlanWithAi({
    required String prompt,
    required AppStorage storage,
  }) async {
    final remote = await BackendApi.refinePlan(
      prompt: prompt,
      currentPlan: storage.customPlan,
      mode: storage.profile.mode,
      persona: storage.persona.isEmpty ? null : storage.persona,
    );
    if (remote == null) return null;

    // Merge：把舊計畫中已勾選 done / 使用者新增的任務狀態套到新計畫。
    final oldById = <String, PlanTask>{};
    final oldByTitle = <String, PlanTask>{};
    for (final w in storage.customPlan.weeks) {
      for (final t in w.tasks) {
        oldById[t.id] = t;
        oldByTitle[t.title.trim().toLowerCase()] = t;
      }
    }
    final mergedWeeks = <CustomPlanWeek>[];
    for (final w in remote.plan.weeks) {
      final mergedTasks = <PlanTask>[];
      for (final t in w.tasks) {
        final old = oldById[t.id] ??
            oldByTitle[t.title.trim().toLowerCase()];
        if (old != null) {
          mergedTasks.add(
            t.copyWith(
              id: old.id, // keep stable id
              done: old.done,
              userAdded: old.userAdded,
              userEdited: old.userEdited || t.title != old.title,
            ),
          );
        } else {
          mergedTasks.add(t);
        }
      }
      mergedWeeks.add(
        CustomPlanWeek(week: w.week, title: w.title, tasks: mergedTasks),
      );
    }
    final merged = remote.plan.copyWith(weeks: mergedWeeks);
    await setCustomPlan(merged);
    return (plan: merged, fromAi: remote.fromAi);
  }

  static Future<void> setWeekNote({
    required int week,
    required String note,
  }) async {
    try {
      await BackendApi.setWeekNote(week: week, note: note);
    } catch (_) {}
  }

  static Persona _buildPersona({
    required AppStorage prev,
    required UserProfile profile,
    required String selfIntro,
  }) {
    final base = PersonaEngine.generate(
      profile: profile,
      explore: prev.explore,
      skillTranslations: prev.skillTranslations,
      previous: prev.persona,
    );
    final trimmed = selfIntro.trim();
    if (trimmed.isEmpty) return base;
    return base.copyWith(text: trimmed, userEdited: true);
  }

  static void unawaitedSafe(Future<void> future) {
    future.catchError((_) {});
  }
}
