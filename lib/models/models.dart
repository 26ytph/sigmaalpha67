typedef RoleId = String;

enum RoleTag {
  engineering,
  data,
  product,
  design,
  marketing,
  sales,
  people,
  finance,
  security,
}

extension RoleTagX on RoleTag {
  String get wireName {
    switch (this) {
      case RoleTag.engineering:
        return 'engineering';
      case RoleTag.data:
        return 'data';
      case RoleTag.product:
        return 'product';
      case RoleTag.design:
        return 'design';
      case RoleTag.marketing:
        return 'marketing';
      case RoleTag.sales:
        return 'sales';
      case RoleTag.people:
        return 'people';
      case RoleTag.finance:
        return 'finance';
      case RoleTag.security:
        return 'security';
    }
  }

  static RoleTag? tryParse(String? s) {
    if (s == null) return null;
    for (final t in RoleTag.values) {
      if (t.wireName == s) return t;
    }
    return null;
  }
}

class CareerRole {
  const CareerRole({
    required this.id,
    required this.title,
    required this.tagline,
    required this.imageSrc,
    required this.skills,
    required this.dayToDay,
    required this.tags,
  });

  final RoleId id;
  final String title;
  final String tagline;
  final String imageSrc;
  final List<String> skills;
  final List<String> dayToDay;
  final List<RoleTag> tags;

  CareerRole copyWith({
    RoleId? id,
    String? title,
    String? tagline,
    String? imageSrc,
    List<String>? skills,
    List<String>? dayToDay,
    List<RoleTag>? tags,
  }) {
    return CareerRole(
      id: id ?? this.id,
      title: title ?? this.title,
      tagline: tagline ?? this.tagline,
      imageSrc: imageSrc ?? this.imageSrc,
      skills: skills ?? this.skills,
      dayToDay: dayToDay ?? this.dayToDay,
      tags: tags ?? this.tags,
    );
  }
}

class ExploreResults {
  const ExploreResults({
    required this.likedRoleIds,
    required this.dislikedRoleIds,
    this.exploreCompletedAt,
  });

  final List<RoleId> likedRoleIds;
  final List<RoleId> dislikedRoleIds;
  final String? exploreCompletedAt;

  ExploreResults copyWith({
    List<RoleId>? likedRoleIds,
    List<RoleId>? dislikedRoleIds,
    String? exploreCompletedAt,
  }) {
    return ExploreResults(
      likedRoleIds: likedRoleIds ?? this.likedRoleIds,
      dislikedRoleIds: dislikedRoleIds ?? this.dislikedRoleIds,
      exploreCompletedAt: exploreCompletedAt ?? this.exploreCompletedAt,
    );
  }
}

typedef DailyAnswerValue = String;

class DailyQuestion {
  const DailyQuestion({
    required this.id,
    required this.text,
    required this.answer,
    required this.roleTags,
    required this.options,
  });

  final String id;
  final String text;
  final String answer;
  final List<RoleTag> roleTags;
  final List<DailyAnswerValue> options;
}

class DailyAnswerEntry {
  const DailyAnswerEntry({required this.questionId, required this.answer});

  final String questionId;
  final DailyAnswerValue answer;
}

class StrikeState {
  const StrikeState({required this.current, this.lastAnsweredDate});

  final int current;
  final String? lastAnsweredDate;

  StrikeState copyWith({int? current, String? lastAnsweredDate}) {
    return StrikeState(
      current: current ?? this.current,
      lastAnsweredDate: lastAnsweredDate ?? this.lastAnsweredDate,
    );
  }
}

class AppStorage {
  const AppStorage({
    required this.explore,
    required this.dailyAnswers,
    required this.planTodos,
    required this.planWeekNotes,
    required this.strike,
  });

  final ExploreResults explore;
  final Map<String, DailyAnswerEntry> dailyAnswers;
  final Map<String, bool> planTodos;
  final Map<String, String> planWeekNotes;
  final StrikeState strike;

  static AppStorage empty() {
    return AppStorage(
      explore: const ExploreResults(likedRoleIds: [], dislikedRoleIds: []),
      dailyAnswers: {},
      planTodos: {},
      planWeekNotes: {},
      strike: const StrikeState(current: 0),
    );
  }

  AppStorage copyWith({
    ExploreResults? explore,
    Map<String, DailyAnswerEntry>? dailyAnswers,
    Map<String, bool>? planTodos,
    Map<String, String>? planWeekNotes,
    StrikeState? strike,
  }) {
    return AppStorage(
      explore: explore ?? this.explore,
      dailyAnswers: dailyAnswers ?? this.dailyAnswers,
      planTodos: planTodos ?? this.planTodos,
      planWeekNotes: planWeekNotes ?? this.planWeekNotes,
      strike: strike ?? this.strike,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'explore': {
        'likedRoleIds': explore.likedRoleIds,
        'dislikedRoleIds': explore.dislikedRoleIds,
        'exploreCompletedAt': explore.exploreCompletedAt,
      },
      'dailyAnswers': dailyAnswers.map((k, v) => MapEntry(
            k,
            {'questionId': v.questionId, 'answer': v.answer},
          )),
      'planTodos': planTodos.map((k, v) => MapEntry(k, v)),
      'planWeekNotes': planWeekNotes,
      'strike': {
        'current': strike.current,
        'lastAnsweredDate': strike.lastAnsweredDate,
      },
    };
  }

  static AppStorage fromJson(Map<String, dynamic> json) {
    final empty = AppStorage.empty();
    final exploreRaw = json['explore'];
    final dailyRaw = json['dailyAnswers'];
    final todosRaw = json['planTodos'];
    final notesRaw = json['planWeekNotes'];
    final strikeRaw = json['strike'];

    final explore = ExploreResults(
      likedRoleIds: List<String>.from(
        (exploreRaw is Map ? exploreRaw['likedRoleIds'] : null) as List? ?? empty.explore.likedRoleIds,
      ),
      dislikedRoleIds: List<String>.from(
        (exploreRaw is Map ? exploreRaw['dislikedRoleIds'] : null) as List? ?? empty.explore.dislikedRoleIds,
      ),
      exploreCompletedAt: exploreRaw is Map ? exploreRaw['exploreCompletedAt'] as String? : empty.explore.exploreCompletedAt,
    );

    final dailyAnswers = <String, DailyAnswerEntry>{};
    if (dailyRaw is Map) {
      for (final e in dailyRaw.entries) {
        final v = e.value;
        if (v is Map && v['questionId'] != null && v['answer'] != null) {
          dailyAnswers[e.key.toString()] = DailyAnswerEntry(
            questionId: v['questionId'] as String,
            answer: v['answer'] as String,
          );
        }
      }
    }

    final planTodos = <String, bool>{};
    if (todosRaw is Map) {
      for (final e in todosRaw.entries) {
        planTodos[e.key.toString()] = e.value == true;
      }
    }

    final planWeekNotes = <String, String>{};
    if (notesRaw is Map) {
      for (final e in notesRaw.entries) {
        planWeekNotes[e.key.toString()] = e.value?.toString() ?? '';
      }
    }

    int current = empty.strike.current;
    String? lastAnsweredDate = empty.strike.lastAnsweredDate;
    if (strikeRaw is Map) {
      current = (strikeRaw['current'] as num?)?.toInt() ?? current;
      lastAnsweredDate = strikeRaw['lastAnsweredDate'] as String? ?? lastAnsweredDate;
    }

    return AppStorage(
      explore: explore,
      dailyAnswers: dailyAnswers,
      planTodos: planTodos,
      planWeekNotes: planWeekNotes,
      strike: StrikeState(current: current, lastAnsweredDate: lastAnsweredDate),
    );
  }
}
