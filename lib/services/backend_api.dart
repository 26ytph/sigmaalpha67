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
  });

  final String id;
  final String role; // 'user' | 'assistant'
  final String text;
  final String createdAt;

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

class BackendChatReply {
  const BackendChatReply({
    required this.conversationId,
    required this.reply,
    required this.shouldHandoff,
    required this.usedRag,
    this.ragProvider,
    this.chatProvider,
    this.sources = const [],
  });

  final String? conversationId;
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
      educationItems: ((j['educationItems'] as List?) ?? const [])
          .map((e) {
            if (e is Map) {
              return EducationEntry.fromJson(Map<String, dynamic>.from(e));
            }
            return EducationEntry.parseFromLine(e?.toString() ?? '');
          })
          .where((e) => !e.isEmpty)
          .toList(),
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
