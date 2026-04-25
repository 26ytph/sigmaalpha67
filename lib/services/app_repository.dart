import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
