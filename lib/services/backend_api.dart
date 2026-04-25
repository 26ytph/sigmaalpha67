import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class BackendChatReply {
  const BackendChatReply({
    required this.conversationId,
    required this.reply,
    required this.shouldHandoff,
    required this.usedRag,
    this.ragProvider,
    this.chatProvider,
    this.sourceTitles = const [],
  });

  final String? conversationId;
  final String reply;
  final bool shouldHandoff;
  final bool usedRag;
  final String? ragProvider;
  final String? chatProvider;
  final List<String> sourceTitles;
}

class BackendApiException implements Exception {
  BackendApiException(this.message);
  final String message;

  @override
  String toString() => 'BackendApiException: $message';
}

class BackendApi {
  BackendApi._();

  static const String baseUrl = String.fromEnvironment(
    'EMPLOYA_API_BASE_URL',
    defaultValue: 'http://localhost:3001',
  );

  static const String token = String.fromEnvironment(
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
    final sources = <String>[];
    if (rag is Map && rag['sources'] is List) {
      for (final s in rag['sources'] as List) {
        if (s is Map && s['title'] is String) sources.add(s['title'] as String);
      }
    }
    return BackendChatReply(
      conversationId: data['conversationId'] as String?,
      reply: (data['reply'] as String?) ?? '',
      shouldHandoff: data['shouldHandoff'] == true,
      usedRag: rag is Map,
      ragProvider: rag is Map ? rag['provider'] as String? : null,
      chatProvider: data['chatProvider'] as String?,
      sourceTitles: sources,
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
      'authorization': 'Bearer $token',
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
      throw BackendApiException('$method $path failed: $message');
    }
    return decoded;
  }

  static Map<String, dynamic> _profileToJson(UserProfile p) => {
    'name': p.name,
    'school': p.school,
    'birthday': p.birthday,
    'age': p.age,
    'contact': p.contact,
    'department': p.department,
    'grade': p.grade,
    'location': p.location,
    'currentStage': p.currentStage,
    'goals': p.goals,
    'interests': p.interests,
    'experiences': p.experiences,
    'educationItems': p.educationItems,
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
      contact: (j['contact'] as String?) ?? fallback.contact,
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
      educationItems: List<String>.from(
        (j['educationItems'] as List?) ?? fallback.educationItems,
      ),
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
