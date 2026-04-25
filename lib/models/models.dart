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

  String get label {
    switch (this) {
      case RoleTag.engineering:
        return '工程';
      case RoleTag.data:
        return '數據';
      case RoleTag.product:
        return '產品';
      case RoleTag.design:
        return '設計';
      case RoleTag.marketing:
        return '行銷';
      case RoleTag.sales:
        return '業務';
      case RoleTag.people:
        return '人資';
      case RoleTag.finance:
        return '財務';
      case RoleTag.security:
        return '資安';
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
    this.swipeCount = 0,
  });

  final List<RoleId> likedRoleIds;
  final List<RoleId> dislikedRoleIds;
  final String? exploreCompletedAt;
  final int swipeCount;

  ExploreResults copyWith({
    List<RoleId>? likedRoleIds,
    List<RoleId>? dislikedRoleIds,
    String? exploreCompletedAt,
    int? swipeCount,
  }) {
    return ExploreResults(
      likedRoleIds: likedRoleIds ?? this.likedRoleIds,
      dislikedRoleIds: dislikedRoleIds ?? this.dislikedRoleIds,
      exploreCompletedAt: exploreCompletedAt ?? this.exploreCompletedAt,
      swipeCount: swipeCount ?? this.swipeCount,
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

/// App 模式：求職或創業（由 UserProfile.startupInterest 推導）
enum AppMode { career, startup }

/// 使用者基本 Profile（Onboarding 收集）
class UserProfile {
  const UserProfile({
    required this.name,
    required this.school,
    required this.age,
    required this.contact,
    required this.department,
    required this.grade,
    required this.location,
    required this.currentStage,
    required this.goals,
    required this.interests,
    required this.experiences,
    required this.educationItems,
    required this.concerns,
    required this.startupInterest,
    this.createdAt,
  });

  final String name;
  final String school;
  final String age;
  final String contact;
  final String department;
  final String grade;
  final String location;
  final String currentStage;
  final List<String> goals;
  final List<String> interests;
  final List<String> experiences;
  final List<String> educationItems;
  final String concerns;
  final bool startupInterest;
  final String? createdAt;

  bool get isEmpty => department.isEmpty && currentStage.isEmpty && goals.isEmpty;

  AppMode get mode => startupInterest ? AppMode.startup : AppMode.career;

  UserProfile copyWith({
    String? name,
    String? school,
    String? age,
    String? contact,
    String? department,
    String? grade,
    String? location,
    String? currentStage,
    List<String>? goals,
    List<String>? interests,
    List<String>? experiences,
    List<String>? educationItems,
    String? concerns,
    bool? startupInterest,
    String? createdAt,
  }) {
    return UserProfile(
      name: name ?? this.name,
      school: school ?? this.school,
      age: age ?? this.age,
      contact: contact ?? this.contact,
      department: department ?? this.department,
      grade: grade ?? this.grade,
      location: location ?? this.location,
      currentStage: currentStage ?? this.currentStage,
      goals: goals ?? this.goals,
      interests: interests ?? this.interests,
      experiences: experiences ?? this.experiences,
      educationItems: educationItems ?? this.educationItems,
      concerns: concerns ?? this.concerns,
      startupInterest: startupInterest ?? this.startupInterest,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static UserProfile empty() => const UserProfile(
        name: '',
        school: '',
        age: '',
        contact: '',
        department: '',
        grade: '',
        location: '',
        currentStage: '',
        goals: [],
        interests: [],
        experiences: [],
        educationItems: [],
        concerns: '',
        startupInterest: false,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'school': school,
        'age': age,
        'contact': contact,
        'department': department,
        'grade': grade,
        'location': location,
        'currentStage': currentStage,
        'goals': goals,
        'interests': interests,
        'experiences': experiences,
        'educationItems': educationItems,
        'concerns': concerns,
        'startupInterest': startupInterest,
        'createdAt': createdAt,
      };

  static UserProfile fromJson(Map<String, dynamic> j) {
    return UserProfile(
      name: (j['name'] as String?) ?? '',
      school: (j['school'] as String?) ?? '',
      age: (j['age'] as String?) ?? '',
      contact: (j['contact'] as String?) ?? '',
      department: (j['department'] as String?) ?? '',
      grade: (j['grade'] as String?) ?? '',
      location: (j['location'] as String?) ?? '',
      currentStage: (j['currentStage'] as String?) ?? '',
      goals: List<String>.from((j['goals'] as List?) ?? const []),
      interests: List<String>.from((j['interests'] as List?) ?? const []),
      experiences: List<String>.from((j['experiences'] as List?) ?? const []),
      educationItems: List<String>.from((j['educationItems'] as List?) ?? const []),
      concerns: (j['concerns'] as String?) ?? '',
      startupInterest: j['startupInterest'] == true,
      createdAt: j['createdAt'] as String?,
    );
  }
}

/// 個人輪廓 / Persona
class Persona {
  const Persona({
    required this.text,
    required this.careerStage,
    required this.mainInterests,
    required this.strengths,
    required this.skillGaps,
    required this.mainConcerns,
    required this.recommendedNextStep,
    this.lastUpdated,
    this.userEdited = false,
  });

  final String text;
  final String careerStage;
  final List<String> mainInterests;
  final List<String> strengths;
  final List<String> skillGaps;
  final List<String> mainConcerns;
  final String recommendedNextStep;
  final String? lastUpdated;
  final bool userEdited;

  bool get isEmpty => text.isEmpty;

  Persona copyWith({
    String? text,
    String? careerStage,
    List<String>? mainInterests,
    List<String>? strengths,
    List<String>? skillGaps,
    List<String>? mainConcerns,
    String? recommendedNextStep,
    String? lastUpdated,
    bool? userEdited,
  }) {
    return Persona(
      text: text ?? this.text,
      careerStage: careerStage ?? this.careerStage,
      mainInterests: mainInterests ?? this.mainInterests,
      strengths: strengths ?? this.strengths,
      skillGaps: skillGaps ?? this.skillGaps,
      mainConcerns: mainConcerns ?? this.mainConcerns,
      recommendedNextStep: recommendedNextStep ?? this.recommendedNextStep,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      userEdited: userEdited ?? this.userEdited,
    );
  }

  static Persona empty() => const Persona(
        text: '',
        careerStage: '',
        mainInterests: [],
        strengths: [],
        skillGaps: [],
        mainConcerns: [],
        recommendedNextStep: '',
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'careerStage': careerStage,
        'mainInterests': mainInterests,
        'strengths': strengths,
        'skillGaps': skillGaps,
        'mainConcerns': mainConcerns,
        'recommendedNextStep': recommendedNextStep,
        'lastUpdated': lastUpdated,
        'userEdited': userEdited,
      };

  static Persona fromJson(Map<String, dynamic> j) {
    return Persona(
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
  }
}

class TranslatedSkillGroup {
  const TranslatedSkillGroup({required this.experience, required this.skills});
  final String experience;
  final List<String> skills;

  Map<String, dynamic> toJson() => {'experience': experience, 'skills': skills};
  static TranslatedSkillGroup fromJson(Map<String, dynamic> j) =>
      TranslatedSkillGroup(
        experience: (j['experience'] as String?) ?? '',
        skills: List<String>.from((j['skills'] as List?) ?? const []),
      );
}

class SkillTranslation {
  const SkillTranslation({
    required this.id,
    required this.rawExperience,
    required this.groups,
    required this.resumeSentence,
    required this.createdAt,
  });

  final String id;
  final String rawExperience;
  final List<TranslatedSkillGroup> groups;
  final String resumeSentence;
  final String createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'rawExperience': rawExperience,
        'groups': groups.map((g) => g.toJson()).toList(),
        'resumeSentence': resumeSentence,
        'createdAt': createdAt,
      };

  static SkillTranslation fromJson(Map<String, dynamic> j) {
    final groupsRaw = (j['groups'] as List?) ?? const [];
    return SkillTranslation(
      id: (j['id'] as String?) ?? '',
      rawExperience: (j['rawExperience'] as String?) ?? '',
      groups: groupsRaw
          .whereType<Map>()
          .map((m) => TranslatedSkillGroup.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      resumeSentence: (j['resumeSentence'] as String?) ?? '',
      createdAt: (j['createdAt'] as String?) ?? '',
    );
  }
}

class NormalizedQuestion {
  const NormalizedQuestion({
    required this.userStage,
    required this.intents,
    required this.emotion,
    required this.knownInfo,
    required this.missingInfo,
    required this.suggestedQuestions,
    required this.urgency,
    required this.counselorSummary,
  });

  final String userStage;
  final List<String> intents;
  final String emotion;
  final List<String> knownInfo;
  final List<String> missingInfo;
  final List<String> suggestedQuestions;
  final String urgency;
  final String counselorSummary;

  Map<String, dynamic> toJson() => {
        'userStage': userStage,
        'intents': intents,
        'emotion': emotion,
        'knownInfo': knownInfo,
        'missingInfo': missingInfo,
        'suggestedQuestions': suggestedQuestions,
        'urgency': urgency,
        'counselorSummary': counselorSummary,
      };
}

class AppStorage {
  const AppStorage({
    required this.profile,
    required this.persona,
    required this.explore,
    required this.dailyAnswers,
    required this.planTodos,
    required this.planWeekNotes,
    required this.strike,
    required this.skillTranslations,
  });

  final UserProfile profile;
  final Persona persona;
  final ExploreResults explore;
  final Map<String, DailyAnswerEntry> dailyAnswers;
  final Map<String, bool> planTodos;
  final Map<String, String> planWeekNotes;
  final StrikeState strike;
  final List<SkillTranslation> skillTranslations;

  bool get isOnboarded => !profile.isEmpty;

  static AppStorage empty() {
    return AppStorage(
      profile: UserProfile.empty(),
      persona: Persona.empty(),
      explore: const ExploreResults(likedRoleIds: [], dislikedRoleIds: []),
      dailyAnswers: {},
      planTodos: {},
      planWeekNotes: {},
      strike: const StrikeState(current: 0),
      skillTranslations: const [],
    );
  }

  AppStorage copyWith({
    UserProfile? profile,
    Persona? persona,
    ExploreResults? explore,
    Map<String, DailyAnswerEntry>? dailyAnswers,
    Map<String, bool>? planTodos,
    Map<String, String>? planWeekNotes,
    StrikeState? strike,
    List<SkillTranslation>? skillTranslations,
  }) {
    return AppStorage(
      profile: profile ?? this.profile,
      persona: persona ?? this.persona,
      explore: explore ?? this.explore,
      dailyAnswers: dailyAnswers ?? this.dailyAnswers,
      planTodos: planTodos ?? this.planTodos,
      planWeekNotes: planWeekNotes ?? this.planWeekNotes,
      strike: strike ?? this.strike,
      skillTranslations: skillTranslations ?? this.skillTranslations,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile': profile.toJson(),
      'persona': persona.toJson(),
      'explore': {
        'likedRoleIds': explore.likedRoleIds,
        'dislikedRoleIds': explore.dislikedRoleIds,
        'exploreCompletedAt': explore.exploreCompletedAt,
        'swipeCount': explore.swipeCount,
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
      'skillTranslations':
          skillTranslations.map((s) => s.toJson()).toList(growable: false),
    };
  }

  static AppStorage fromJson(Map<String, dynamic> json) {
    final empty = AppStorage.empty();
    final exploreRaw = json['explore'];
    final dailyRaw = json['dailyAnswers'];
    final todosRaw = json['planTodos'];
    final notesRaw = json['planWeekNotes'];
    final strikeRaw = json['strike'];
    final profileRaw = json['profile'];
    final personaRaw = json['persona'];
    final transRaw = json['skillTranslations'];

    final profile = profileRaw is Map
        ? UserProfile.fromJson(Map<String, dynamic>.from(profileRaw))
        : empty.profile;

    final persona = personaRaw is Map
        ? Persona.fromJson(Map<String, dynamic>.from(personaRaw))
        : empty.persona;

    final explore = ExploreResults(
      likedRoleIds: List<String>.from(
        (exploreRaw is Map ? exploreRaw['likedRoleIds'] : null) as List? ??
            empty.explore.likedRoleIds,
      ),
      dislikedRoleIds: List<String>.from(
        (exploreRaw is Map ? exploreRaw['dislikedRoleIds'] : null) as List? ??
            empty.explore.dislikedRoleIds,
      ),
      exploreCompletedAt: exploreRaw is Map
          ? exploreRaw['exploreCompletedAt'] as String?
          : empty.explore.exploreCompletedAt,
      swipeCount: exploreRaw is Map
          ? ((exploreRaw['swipeCount'] as num?)?.toInt() ?? 0)
          : 0,
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
      lastAnsweredDate =
          strikeRaw['lastAnsweredDate'] as String? ?? lastAnsweredDate;
    }

    final skillTranslations = <SkillTranslation>[];
    if (transRaw is List) {
      for (final t in transRaw) {
        if (t is Map) {
          skillTranslations
              .add(SkillTranslation.fromJson(Map<String, dynamic>.from(t)));
        }
      }
    }

    return AppStorage(
      profile: profile,
      persona: persona,
      explore: explore,
      dailyAnswers: dailyAnswers,
      planTodos: planTodos,
      planWeekNotes: planWeekNotes,
      strike: StrikeState(
          current: current, lastAnsweredDate: lastAnsweredDate),
      skillTranslations: skillTranslations,
    );
  }
}
