import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'supabase_config.dart';

class RagSource {
  const RagSource({required this.title, this.url});

  final String title;
  final String? url;
}

/// 後端 `/api/chat/conversations` 列出的單筆對話摘要
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.mode,
    required this.createdAt,
  });

  final String id;
  final AppMode mode;
  final String createdAt;
}

/// 後端傳回的單則訊息（chat_messages 一筆 row）
class RemoteChatMessage {
  const RemoteChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.byCounselor = false,
    this.replyToMessageId,
    this.replyToText,
  });

  final String id;
  final String role; // 'user' | 'assistant'
  final String text;
  final String createdAt;
  final bool byCounselor;
  /// 諮詢師回覆專用：這則回覆對應 user 的哪一則問題（chat_messages.id）。
  final String? replyToMessageId;
  /// 諮詢師回覆專用：對應問題的文字快照（顯示在 bubble 上方的 ↩ 引用框）。
  final String? replyToText;

  bool get fromUser => role == 'user';
}

/// 一段完整的對話歷史
class ConversationHistory {
  const ConversationHistory({
    required this.id,
    required this.mode,
    required this.messages,
  });

  final String id;
  final AppMode mode;
  final List<RemoteChatMessage> messages;
}

/// 後端 `POST /api/plan/generate` 回傳的單週資料。
/// 對應 `backend/src/types/plan.ts` 的 `PlanWeek`。
class BackendPlanWeek {
  const BackendPlanWeek({
    required this.week,
    required this.title,
    required this.goals,
    required this.resources,
    required this.outputs,
  });

  final int week;
  final String title;
  final List<String> goals;
  final List<String> resources;
  final List<String> outputs;
}

class BackendChatReply {
  const BackendChatReply({
    required this.conversationId,
    required this.reply,
    required this.shouldHandoff,
    required this.usedRag,
    this.messageId,
    this.ragProvider,
    this.chatProvider,
    this.sources = const [],
  });

  final String? conversationId;
  final String? messageId;
  final String reply;
  final bool shouldHandoff;
  final bool usedRag;
  final String? ragProvider;
  final String? chatProvider;
  final List<RagSource> sources;
}

class BackendApiException implements Exception {
  BackendApiException(this.message, {this.statusCode, this.retryAfterMs});
  final String message;
  final int? statusCode;
  final int? retryAfterMs;

  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'BackendApiException: $message';
}

class TopQuestion {
  const TopQuestion({
    required this.question,
    required this.count,
    required this.urgency,
  });

  final String question;
  final int count;
  final String urgency;

  factory TopQuestion.fromJson(Map<String, dynamic> j) => TopQuestion(
        question: (j['question'] as String?) ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
        urgency: (j['urgency'] as String?) ?? '',
      );
}

class CareerPathStat {
  const CareerPathStat({
    required this.tag,
    required this.label,
    required this.interestedUsers,
  });

  final String tag;
  final String label;
  final int interestedUsers;

  factory CareerPathStat.fromJson(Map<String, dynamic> j) => CareerPathStat(
        tag: (j['tag'] as String?) ?? '',
        label: (j['label'] as String?) ?? '',
        interestedUsers: (j['interestedUsers'] as num?)?.toInt() ?? 0,
      );
}

class SkillGap {
  const SkillGap({required this.skill, required this.mentions});

  final String skill;
  final int mentions;

  factory SkillGap.fromJson(Map<String, dynamic> j) => SkillGap(
        skill: (j['skill'] as String?) ?? '',
        mentions: (j['mentions'] as num?)?.toInt() ?? 0,
      );
}

class StuckTask {
  const StuckTask({
    required this.taskKey,
    required this.title,
    required this.stuckUsers,
  });

  final String taskKey;
  final String title;
  final int stuckUsers;

  factory StuckTask.fromJson(Map<String, dynamic> j) => StuckTask(
        taskKey: (j['taskKey'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        stuckUsers: (j['stuckUsers'] as num?)?.toInt() ?? 0,
      );
}

class StartupNeed {
  const StartupNeed({required this.stage, required this.users});

  final String stage;
  final int users;

  factory StartupNeed.fromJson(Map<String, dynamic> j) => StartupNeed(
        stage: (j['stage'] as String?) ?? '',
        users: (j['users'] as num?)?.toInt() ?? 0,
      );
}

class PolicySuggestion {
  const PolicySuggestion({
    required this.title,
    required this.rationale,
    required this.proposedActions,
  });

  final String title;
  final String rationale;
  final List<String> proposedActions;

  factory PolicySuggestion.fromJson(Map<String, dynamic> j) => PolicySuggestion(
        title: (j['title'] as String?) ?? '',
        rationale: (j['rationale'] as String?) ?? '',
        proposedActions: ((j['proposedActions'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
      );
}

class BackendApi {
  BackendApi._();

  static const String baseUrl = String.fromEnvironment(
    'EMPLOYA_API_BASE_URL',
    defaultValue: 'http://localhost:3001',
  );

  /// 取代舊的硬編 token —— 優先使用 Supabase 的 JWT；
  /// 若 Supabase 未設定或還沒登入，再 fall back 到 build-time 的
  /// `EMPLOYA_API_TOKEN`，最後才用 'demo-user'。
  static String _resolveToken() {
    if (SupabaseConfig.isConfigured) {
      try {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null && session.accessToken.isNotEmpty) {
          return session.accessToken;
        }
      } catch (_) {
        // Supabase.initialize 還沒跑或失敗
      }
    }
    return _fallbackToken;
  }

  static const String _fallbackToken = String.fromEnvironment(
    'EMPLOYA_API_TOKEN',
    defaultValue: 'demo-user',
  );

  static final http.Client _client = http.Client();

  static Future<bool> health() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// 從後端把使用者既有的 profile 撈回來。404 (尚未建立) 回 null。
  static Future<UserProfile?> fetchProfile() async {
    try {
      final data = await _request('GET', '/api/users/me/profile');
      final raw = data['profile'];
      if (raw is Map) {
        return _profileFromJson(
          Map<String, dynamic>.from(raw),
          fallback: UserProfile.empty(),
        );
      }
      return null;
    } on BackendApiException catch (e) {
      // not_found / unauthorized 都當沒資料；上層會 fall back 到本機。
      if (e.message.contains('404') || e.message.contains('not_found')) {
        return null;
      }
      rethrow;
    }
  }

  /// 從後端把 persona 撈回來。404 回 null。
  static Future<Persona?> fetchPersona() async {
    try {
      final data = await _request('GET', '/api/persona');
      final raw = data['persona'];
      if (raw is Map) {
        return _personaFromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    } on BackendApiException catch (e) {
      if (e.message.contains('404') || e.message.contains('not_found')) {
        return null;
      }
      rethrow;
    }
  }

  /// 列出該使用者的對話清單（後端會優先讀 Supabase）。
  static Future<List<ConversationSummary>> listConversations() async {
    try {
      final data = await _request('GET', '/api/chat/conversations');
      final raw = data['conversations'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((m) {
            final mm = Map<String, dynamic>.from(m);
            return ConversationSummary(
              id: (mm['id'] as String?) ?? '',
              mode: (mm['mode'] as String?) == 'startup'
                  ? AppMode.startup
                  : AppMode.career,
              createdAt: (mm['createdAt'] as String?) ?? '',
            );
          })
          .where((c) => c.id.isNotEmpty)
          .toList();
    } on BackendApiException {
      return const [];
    }
  }

  /// 抓某段對話的全部訊息（依 created_at 由舊到新）。
  static Future<ConversationHistory?> fetchConversationMessages(
    String conversationId,
  ) async {
    try {
      final data = await _request(
        'GET',
        '/api/chat/conversations/${Uri.encodeComponent(conversationId)}/messages',
      );
      final mode = (data['mode'] as String?) == 'startup'
          ? AppMode.startup
          : AppMode.career;
      final rawMsgs = data['messages'];
      final msgs = <RemoteChatMessage>[];
      if (rawMsgs is List) {
        for (final m in rawMsgs) {
          if (m is Map) {
            final mm = Map<String, dynamic>.from(m);
            msgs.add(
              RemoteChatMessage(
                id: (mm['id'] as String?) ?? '',
                role: (mm['role'] as String?) ?? 'assistant',
                text: (mm['text'] as String?) ?? '',
                createdAt: (mm['createdAt'] as String?) ?? '',
                // 後端 type 用 fromCounselor，舊 client 讀 byCounselor — 兩個都接，相容。
                byCounselor:
                    mm['byCounselor'] == true || mm['fromCounselor'] == true,
                replyToMessageId: mm['replyToMessageId'] as String?,
                replyToText: mm['replyToText'] as String?,
              ),
            );
          }
        }
      }
      return ConversationHistory(
        id: conversationId,
        mode: mode,
        messages: msgs,
      );
    } on BackendApiException catch (e) {
      if (e.message.contains('404') || e.message.contains('not_found')) {
        return null;
      }
      rethrow;
    }
  }

  static Future<UserProfile> saveProfile(UserProfile profile) async {
    final data = await _request(
      'PUT',
      '/api/users/me/profile',
      body: _profileToJson(profile),
    );
    final raw = data['profile'];
    if (raw is Map) {
      return _profileFromJson(
        Map<String, dynamic>.from(raw),
        fallback: profile,
      );
    }
    return profile;
  }

  /// 從目前 profile 跑 Gemini 生成一段自介。後端會用 in-memory store 的
  /// profile（chat / persona 路徑都會 write-through 進去），所以前端
  /// 不用再把 profile 上傳一次。
  static Future<String> generateSelfIntro() async {
    final data = await _request('POST', '/api/persona/self-intro');
    return (data['selfIntro'] as String?)?.trim() ?? '';
  }

  static Future<Persona> generatePersona({
    required UserProfile profile,
    required ExploreResults explore,
    required List<SkillTranslation> skillTranslations,
    Persona? previousPersona,
  }) async {
    final data = await _request(
      'POST',
      '/api/persona/generate',
      body: {
        'profile': _profileToJson(profile),
        'explore': _exploreToJson(explore),
        'skillTranslations': skillTranslations
            .map(_skillTranslationForPersonaJson)
            .toList(),
        'previousPersona': previousPersona == null
            ? null
            : _personaToJson(previousPersona),
      },
    );
    return _personaFromJson(Map<String, dynamic>.from(data['persona'] as Map));
  }

  static Future<Persona> refreshPersona({
    required UserProfile profile,
    required ExploreResults explore,
    required List<SkillTranslation> skillTranslations,
    required Persona previousPersona,
  }) async {
    final data = await _request(
      'POST',
      '/api/persona/refresh',
      body: {
        'profile': _profileToJson(profile),
        'explore': _exploreToJson(explore),
        'skillTranslations': skillTranslations
            .map(_skillTranslationForPersonaJson)
            .toList(),
        'previousPersona': _personaToJson(previousPersona),
      },
    );
    return _personaFromJson(Map<String, dynamic>.from(data['persona'] as Map));
  }

  static Future<Persona> updatePersonaText(String text) async {
    final data = await _request(
      'PUT',
      '/api/persona',
      body: {'text': text, 'userEdited': true},
    );
    return _personaFromJson(Map<String, dynamic>.from(data['persona'] as Map));
  }

  static Future<void> recordSwipe({
    required String cardId,
    required bool liked,
  }) async {
    await _request(
      'POST',
      '/api/swipe/record',
      body: {
        'cardId': cardId,
        'action': liked ? 'right' : 'left',
        'swipedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// 呼叫後端 `POST /api/plan/generate` 取得 LLM 客製化的 4 週計畫。
  ///
  /// 回傳的是「headline + weeks」這兩個 LLM 真正要算的部分；
  /// `basedOnTopTags` / `recommendedRoles` 後端是用 deterministic 算法回的，
  /// 但本 client 不需要 — Career Path 畫面只用 headline 與 weeks。
  ///
  /// 失敗（網路 / 401 / Gemini quota）回 `null`，呼叫端可以 fallback 到
  /// 本機 `lib/logic/generate_plan.dart`。
  static Future<({String headline, List<BackendPlanWeek> weeks})?>
  generatePlan({
    required AppMode mode,
    required List<String> likedRoleIds,
    Persona? persona,
  }) async {
    try {
      final body = <String, dynamic>{
        'mode': mode == AppMode.startup ? 'startup' : 'career',
        'likedRoleIds': likedRoleIds,
        if (persona != null && !persona.isEmpty)
          'persona': _personaToJson(persona),
      };
      final data = await _request('POST', '/api/plan/generate', body: body);
      final raw = data['plan'];
      if (raw is! Map) return null;
      final plan = Map<String, dynamic>.from(raw);
      final headline = (plan['headline'] as String?)?.trim() ?? '';
      final weeksRaw = (plan['weeks'] as List?) ?? const [];
      final weeks = <BackendPlanWeek>[];
      for (final w in weeksRaw) {
        if (w is! Map) continue;
        final m = Map<String, dynamic>.from(w);
        final week = (m['week'] as num?)?.toInt() ?? 0;
        final title = (m['title'] as String?)?.trim() ?? '';
        if (week <= 0 || title.isEmpty) continue;
        weeks.add(
          BackendPlanWeek(
            week: week,
            title: title,
            goals: List<String>.from((m['goals'] as List?) ?? const []),
            resources: List<String>.from((m['resources'] as List?) ?? const []),
            outputs: List<String>.from((m['outputs'] as List?) ?? const []),
          ),
        );
      }
      if (headline.isEmpty || weeks.isEmpty) return null;
      return (headline: headline, weeks: weeks);
    } catch (_) {
      return null;
    }
  }

  /// 呼叫後端 `POST /api/plan/refine` — 把使用者一段自然語言（例如
  /// 「我想投 DevOps 實習」「我已經會 Docker，幫我跳過」）丟給 Gemini，
  /// 請它依現有 [currentPlan] 產出新版（保留 task id 以維持勾選狀態）。
  ///
  /// 回 `null` 代表後端不通（連線層級失敗）。`fromAi: false` 代表後端有回，
  /// 但 Gemini 那邊掛了；此時 [message] 會帶人話錯誤訊息給上層 UI 顯示。
  static Future<({CustomPlan plan, bool fromAi, String? message})?>
      refinePlan({
    required String prompt,
    required CustomPlan currentPlan,
    required AppMode mode,
    Persona? persona,
  }) async {
    try {
      final body = <String, dynamic>{
        'prompt': prompt,
        'currentPlan': _customPlanForRefineJson(currentPlan),
        'mode': mode == AppMode.startup ? 'startup' : 'career',
        if (persona != null && !persona.isEmpty)
          'persona': _personaToJson(persona),
      };
      final data = await _request('POST', '/api/plan/refine', body: body);
      final raw = data['plan'];
      if (raw is! Map) return null;
      final fromAi = data['fromAi'] == true;
      final message = data['message'] as String?;
      final parsed = _customPlanFromRefineJson(
        Map<String, dynamic>.from(raw),
        fallbackHeadline: currentPlan.headline,
      );
      if (parsed == null) return null;
      return (
        plan: parsed.copyWith(fromAi: fromAi, goalPrompt: prompt),
        fromAi: fromAi,
        message: message,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _customPlanForRefineJson(CustomPlan p) => {
        'headline': p.headline,
        'weeks': p.weeks
            .map(
              (w) => {
                'week': w.week,
                'title': w.title,
                'tasks': w.tasks
                    .map(
                      (t) => {
                        'id': t.id,
                        'title': t.title,
                        'description': t.description,
                        'section': t.section,
                        'done': t.done,
                        'userAdded': t.userAdded,
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
      };

  static CustomPlan? _customPlanFromRefineJson(
    Map<String, dynamic> j, {
    required String fallbackHeadline,
  }) {
    final headline = (j['headline'] as String?)?.trim() ?? fallbackHeadline;
    final weeksRaw = (j['weeks'] as List?) ?? const [];
    final weeks = <CustomPlanWeek>[];
    for (final w in weeksRaw) {
      if (w is! Map) continue;
      final m = Map<String, dynamic>.from(w);
      final week = (m['week'] as num?)?.toInt() ?? 0;
      final title = (m['title'] as String?)?.trim() ?? '';
      if (week <= 0 || title.isEmpty) continue;
      final tasksRaw = (m['tasks'] as List?) ?? const [];
      final tasks = <PlanTask>[];
      for (final t in tasksRaw) {
        if (t is! Map) continue;
        final tm = Map<String, dynamic>.from(t);
        final id = ((tm['id'] as String?) ?? '').trim();
        final taskTitle = ((tm['title'] as String?) ?? '').trim();
        if (id.isEmpty || taskTitle.isEmpty) continue;
        final sectionRaw =
            ((tm['section'] as String?) ?? 'goals').toLowerCase();
        final section = (sectionRaw == 'resources' ||
                sectionRaw == 'outputs')
            ? sectionRaw
            : 'goals';
        tasks.add(
          PlanTask(
            id: id,
            title: taskTitle,
            description: ((tm['description'] as String?) ?? '').trim(),
            section: section,
          ),
        );
      }
      if (tasks.isEmpty) continue;
      weeks.add(CustomPlanWeek(week: week, title: title, tasks: tasks));
    }
    if (weeks.isEmpty) return null;
    return CustomPlan(
      headline: headline,
      weeks: weeks,
      lastUpdated: DateTime.now().toIso8601String(),
    );
  }

  /// 從後端拉滑卡結果（GET /api/swipe/summary）。
  /// 換裝置 / 清快取後，這是把使用者按過 ❤ 的職位帶回來的唯一管道。
  /// 之後 `generatePlan(likedRoleIds, ...)` 才有得算。
  static Future<({List<String> likedRoleIds, List<String> dislikedRoleIds})>
  fetchSwipeSummary() async {
    final data = await _request('GET', '/api/swipe/summary');
    final summary = data['summary'];
    if (summary is! Map) {
      return (likedRoleIds: const <String>[], dislikedRoleIds: const <String>[]);
    }
    final liked = (summary['likedRoleIds'] as List?) ?? const [];
    final disliked = (summary['dislikedRoleIds'] as List?) ?? const [];
    return (
      likedRoleIds: List<String>.from(liked),
      dislikedRoleIds: List<String>.from(disliked),
    );
  }

  static Future<SkillTranslation> translateSkill(String raw) async {
    final data = await _request(
      'POST',
      '/api/skills/translate',
      body: {'raw': raw},
    );
    return _skillTranslationFromJson(
      Map<String, dynamic>.from(data['translation'] as Map),
    );
  }

  static Future<Persona?> saveSkillTranslation(
    SkillTranslation translation,
  ) async {
    final data = await _request(
      'POST',
      '/api/skills/save',
      body: _skillTranslationToJson(translation),
    );
    final raw = data['updatedPersona'];
    if (raw is Map) return _personaFromJson(Map<String, dynamic>.from(raw));
    return null;
  }

  /// 列出 user 已存的所有技能翻譯（GET /api/skills/translations）。
  static Future<List<SkillTranslation>> listSkillTranslations() async {
    final data = await _request('GET', '/api/skills/translations');
    final raw = data['translations'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => _skillTranslationFromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  static Future<BackendChatReply> sendChatMessage({
    String? conversationId,
    required String message,
    required AppMode mode,
  }) async {
    final requestBody = <String, dynamic>{
      'message': message,
      'context': {
        'mode': mode == AppMode.startup ? 'startup' : 'career',
        'useProfile': true,
        'useHistory': true,
        'useRag': true,
      },
    };
    if (conversationId != null) {
      requestBody['conversationId'] = conversationId;
    }

    final data = await _request(
      'POST',
      '/api/chat/messages',
      body: requestBody,
    );
    final rag = data['rag'];
    final sources = <RagSource>[];
    if (rag is Map && rag['sources'] is List) {
      for (final s in rag['sources'] as List) {
        if (s is Map && s['title'] is String) {
          sources.add(
            RagSource(
              title: s['title'] as String,
              url: s['sourceUrl'] as String?,
            ),
          );
        }
      }
    }
    return BackendChatReply(
      conversationId: data['conversationId'] as String?,
      messageId: data['messageId'] as String?,
      reply: (data['reply'] as String?) ?? '',
      shouldHandoff: data['shouldHandoff'] == true,
      usedRag: rag is Map,
      ragProvider: rag is Map ? rag['provider'] as String? : null,
      chatProvider: data['chatProvider'] as String?,
      sources: sources,
    );
  }

  static Future<void> answerDailyQuestion({
    required String questionId,
    required String answer,
  }) async {
    await _request(
      'POST',
      '/api/daily-question/answers',
      body: {'questionId': questionId, 'answer': answer},
    );
  }

  static Future<void> setTodo({required String key, required bool done}) async {
    await _request(
      'PUT',
      '/api/plan/todos/${Uri.encodeComponent(key)}',
      body: {'done': done},
    );
  }

  static Future<void> setWeekNote({
    required int week,
    required String note,
  }) async {
    await _request('PUT', '/api/plan/weeks/$week/note', body: {'note': note});
  }

  // ===== Policy Dashboard =====
  static Future<List<TopQuestion>> fetchTopQuestions() async {
    final data = await _request('GET', '/api/admin/dashboard/top-questions');
    final items = (data['items'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((m) => TopQuestion.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  static Future<List<CareerPathStat>> fetchTopCareerPaths() async {
    final data = await _request('GET', '/api/admin/dashboard/top-career-paths');
    final items = (data['items'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((m) => CareerPathStat.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  static Future<List<SkillGap>> fetchSkillGaps() async {
    final data = await _request('GET', '/api/admin/dashboard/skill-gaps');
    final items = (data['items'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((m) => SkillGap.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  static Future<List<StuckTask>> fetchStuckTasks() async {
    final data = await _request('GET', '/api/admin/dashboard/stuck-tasks');
    final items = (data['items'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((m) => StuckTask.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  static Future<List<StartupNeed>> fetchStartupNeeds() async {
    final data = await _request('GET', '/api/admin/dashboard/startup-needs');
    final items = (data['items'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((m) => StartupNeed.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  static Future<List<PolicySuggestion>> fetchPolicySuggestions({
    String focusArea = 'career',
  }) async {
    final data = await _request(
      'POST',
      '/api/admin/dashboard/policy-suggestions',
      body: {'focusArea': focusArea},
    );
    final items = (data['suggestions'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((m) => PolicySuggestion.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {
      'authorization': 'Bearer ${_resolveToken()}',
      'content-type': 'application/json; charset=utf-8',
    };

    late final http.Response res;
    try {
      final encoded = body == null ? null : jsonEncode(body);
      switch (method) {
        case 'GET':
          res = await _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 30));
          break;
        case 'POST':
          res = await _client
              .post(uri, headers: headers, body: encoded)
              .timeout(const Duration(seconds: 45));
          break;
        case 'PUT':
          res = await _client
              .put(uri, headers: headers, body: encoded)
              .timeout(const Duration(seconds: 30));
          break;
        default:
          throw BackendApiException('Unsupported method $method');
      }
    } on TimeoutException {
      throw BackendApiException('Request timeout: $method $path');
    } catch (e) {
      throw BackendApiException('Cannot reach backend: $e');
    }

    final decoded = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = decoded['error'];
      final message = error is Map ? error['message'] : res.body;
      final retryRaw = error is Map ? error['retryAfterMs'] : null;
      throw BackendApiException(
        '$method $path failed: $message',
        statusCode: res.statusCode,
        retryAfterMs: retryRaw is int ? retryRaw : null,
      );
    }
    return decoded;
  }

  static Map<String, dynamic> _profileToJson(UserProfile p) => {
    'name': p.name,
    'school': p.school,
    'birthday': p.birthday,
    'age': p.age,
    'email': p.email,
    'phone': p.phone,
    'department': p.department,
    'grade': p.grade,
    'location': p.location,
    'currentStage': p.currentStage,
    'goals': p.goals,
    'interests': p.interests,
    'experiences': p.experiences,
    'educationItems': p.educationItems.map((e) => e.toJson()).toList(),
    'concerns': p.concerns,
    'startupInterest': p.startupInterest,
  };

  static UserProfile _profileFromJson(
    Map<String, dynamic> j, {
    required UserProfile fallback,
  }) {
    return fallback.copyWith(
      name: (j['name'] as String?) ?? fallback.name,
      school: (j['school'] as String?) ?? fallback.school,
      birthday: (j['birthday'] as String?) ?? fallback.birthday,
      email: (j['email'] as String?) ?? fallback.email,
      phone: (j['phone'] as String?) ?? fallback.phone,
      department: (j['department'] as String?) ?? fallback.department,
      grade: (j['grade'] as String?) ?? fallback.grade,
      location: (j['location'] as String?) ?? fallback.location,
      currentStage: (j['currentStage'] as String?) ?? fallback.currentStage,
      goals: List<String>.from((j['goals'] as List?) ?? fallback.goals),
      interests: List<String>.from(
        (j['interests'] as List?) ?? fallback.interests,
      ),
      experiences: List<String>.from(
        (j['experiences'] as List?) ?? fallback.experiences,
      ),
      educationItems: EducationEntry.parseListJson(j['educationItems']),
      concerns: (j['concerns'] as String?) ?? fallback.concerns,
      startupInterest:
          (j['startupInterest'] as bool?) ?? fallback.startupInterest,
      createdAt: (j['createdAt'] as String?) ?? fallback.createdAt,
    );
  }

  static Map<String, dynamic> _exploreToJson(ExploreResults e) => {
    'likedRoleIds': e.likedRoleIds,
    'dislikedRoleIds': e.dislikedRoleIds,
  };

  static Map<String, dynamic> _personaToJson(Persona p) => {
    'text': p.text,
    'careerStage': p.careerStage,
    'mainInterests': p.mainInterests,
    'strengths': p.strengths,
    'skillGaps': p.skillGaps,
    'mainConcerns': p.mainConcerns,
    'recommendedNextStep': p.recommendedNextStep,
    'lastUpdated': p.lastUpdated,
    'userEdited': p.userEdited,
  };

  static Persona _personaFromJson(Map<String, dynamic> j) => Persona(
    text: (j['text'] as String?) ?? '',
    careerStage: (j['careerStage'] as String?) ?? '',
    mainInterests: List<String>.from((j['mainInterests'] as List?) ?? const []),
    strengths: List<String>.from((j['strengths'] as List?) ?? const []),
    skillGaps: List<String>.from((j['skillGaps'] as List?) ?? const []),
    mainConcerns: List<String>.from((j['mainConcerns'] as List?) ?? const []),
    recommendedNextStep: (j['recommendedNextStep'] as String?) ?? '',
    lastUpdated: j['lastUpdated'] as String?,
    userEdited: j['userEdited'] == true,
  );

  static Map<String, dynamic> _skillTranslationForPersonaJson(
    SkillTranslation t,
  ) => {
    'rawExperience': t.rawExperience,
    'groups': t.groups.map((g) => g.toJson()).toList(),
  };

  static Map<String, dynamic> _skillTranslationToJson(SkillTranslation t) => {
    'id': t.id,
    'rawExperience': t.rawExperience,
    'groups': t.groups.map((g) => g.toJson()).toList(),
    'resumeSentence': t.resumeSentence,
    'createdAt': t.createdAt,
  };

  static SkillTranslation _skillTranslationFromJson(Map<String, dynamic> j) =>
      SkillTranslation(
        id: (j['id'] as String?) ?? '',
        rawExperience: (j['rawExperience'] as String?) ?? '',
        groups: ((j['groups'] as List?) ?? const [])
            .whereType<Map>()
            .map(
              (m) =>
                  TranslatedSkillGroup.fromJson(Map<String, dynamic>.from(m)),
            )
            .toList(),
        resumeSentence: (j['resumeSentence'] as String?) ?? '',
        createdAt: (j['createdAt'] as String?) ?? '',
      );
}
