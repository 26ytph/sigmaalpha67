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

/// 學歷一筆：學校／科系／年級三欄
class EducationEntry {
  const EducationEntry({
    required this.school,
    required this.department,
    required this.grade,
  });

  final String school;
  final String department;
  final String grade;

  bool get isEmpty =>
      school.isEmpty && department.isEmpty && grade.isEmpty;

  /// 把三欄拼成單行（給 LaTeX 履歷或舊有 List<String> 介面用）
  String get displayLine {
    final parts = [school, department, grade].where((s) => s.isNotEmpty);
    return parts.join(' ・ ');
  }

  EducationEntry copyWith({String? school, String? department, String? grade}) =>
      EducationEntry(
        school: school ?? this.school,
        department: department ?? this.department,
        grade: grade ?? this.grade,
      );

  Map<String, dynamic> toJson() =>
      {'school': school, 'department': department, 'grade': grade};

  static EducationEntry fromJson(Map<String, dynamic> j) => EducationEntry(
        school: (j['school'] as String?) ?? '',
        department: (j['department'] as String?) ?? '',
        grade: (j['grade'] as String?) ?? '',
      );

  /// 從舊有的 'school 系所 年級' 單行字串解析成結構化欄位（best-effort）。
  static EducationEntry parseFromLine(String line) {
    final parts = line.split(RegExp(r'[\s・·\|/，,]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return const EducationEntry(school: '', department: '', grade: '');
    }
    if (parts.length == 1) {
      return EducationEntry(school: parts[0], department: '', grade: '');
    }
    if (parts.length == 2) {
      return EducationEntry(school: parts[0], department: parts[1], grade: '');
    }
    return EducationEntry(
      school: parts[0],
      department: parts[1],
      grade: parts.sublist(2).join(' '),
    );
  }

  /// 用來判斷一個字串長得像不像「年級」（用於 legacy 偵測）。
  static final RegExp _gradeLike = RegExp(
    r'(高中|高一|高二|高三|大[一二三四]|碩[一二]|博|畢業|年級|研一|研二|國[一二三]|高中部)',
  );

  /// 用來判斷字串是否包含內部分隔（空白或 ・·|/，,）。
  /// 沒有 → 像「原子欄位」（學校／系／年級各自一個 element）；
  /// 有  → 像「整行學歷」（'台大 資工 大三'）。
  static final RegExp _eduSeparator = RegExp(r'[\s・·|/，,]');

  /// 從 JSON 解析 `educationItems`，含 legacy 格式遷移。
  ///
  /// 接受三種輸入：
  /// 1. `List<Map>` — 新格式，每個 map 是一筆學歷（直接還原）。
  /// 2. `List<String>` 但是「一個欄位一個字串」的舊格式（學校／系／年級拆 2–3 筆寫進來）—
  ///    會偵測並合併回一筆。
  /// 3. `List<String>` 每筆是合併行如「台大 資工 大三」— 用 [parseFromLine]。
  static List<EducationEntry> parseListJson(dynamic raw) {
    final list = (raw as List?) ?? const [];
    if (list.isEmpty) return const [];

    // (2) Legacy split-fields 偵測：一筆學歷被拆成 2–3 個純字串。
    //     觸發條件：list 全是 String、長度 2 或 3，且
    //       - 至少一個 element 像年級，或
    //       - 全部 element 都是「原子欄位」（沒有內部空白／分隔符）。
    final allStrings = list.every((e) => e is String);
    if (allStrings && list.length >= 2 && list.length <= 3) {
      final strings = list.cast<String>().map((s) => s.trim()).toList();
      final gradeIdx = strings.indexWhere(_gradeLike.hasMatch);
      final allSingleToken = strings
          .every((s) => s.isNotEmpty && !_eduSeparator.hasMatch(s));
      if (gradeIdx >= 0 || allSingleToken) {
        String school = '';
        String department = '';
        String grade = '';
        if (gradeIdx >= 0) {
          grade = strings[gradeIdx];
          final remaining = [
            for (var i = 0; i < strings.length; i++)
              if (i != gradeIdx) strings[i],
          ];
          if (remaining.length == 1) {
            school = remaining[0];
          } else if (remaining.length == 2) {
            // 較長的當學校（'國立臺灣大學' vs '社會系'）。
            if (remaining[0].length >= remaining[1].length) {
              school = remaining[0];
              department = remaining[1];
            } else {
              school = remaining[1];
              department = remaining[0];
            }
          }
        } else {
          // 沒抓到年級但全是原子欄位：以位置推 [學校, 學系, (年級)]
          school = strings[0];
          if (strings.length >= 2) department = strings[1];
          if (strings.length >= 3) grade = strings[2];
        }
        final merged = EducationEntry(
          school: school,
          department: department,
          grade: grade,
        );
        return merged.isEmpty ? const [] : [merged];
      }
    }

    // (1) + (3) — per-element parsing.
    return list
        .map<EducationEntry>((e) {
          if (e is Map) {
            return EducationEntry.fromJson(Map<String, dynamic>.from(e));
          }
          return EducationEntry.parseFromLine(e?.toString() ?? '');
        })
        .where((e) => !e.isEmpty)
        .toList(growable: false);
  }
}

/// 帳號（demo 用：只保留 email 與登入時間，密碼不存）
class UserAccount {
  const UserAccount({required this.email, this.signedInAt});

  final String email;
  final String? signedInAt;

  bool get isAuthenticated => email.isNotEmpty;

  static UserAccount empty() => const UserAccount(email: '');

  UserAccount copyWith({String? email, String? signedInAt}) {
    return UserAccount(
      email: email ?? this.email,
      signedInAt: signedInAt ?? this.signedInAt,
    );
  }

  Map<String, dynamic> toJson() => {'email': email, 'signedInAt': signedInAt};

  static UserAccount fromJson(Map<String, dynamic> j) => UserAccount(
        email: (j['email'] as String?) ?? '',
        signedInAt: j['signedInAt'] as String?,
      );
}

/// 使用者基本 Profile（Onboarding 收集）
///
/// 生日 (`birthday`) 以 'YYYY-MM-DD' 字串儲存；年齡為衍生欄位。
class UserProfile {
  const UserProfile({
    required this.name,
    required this.school,
    required this.birthday,
    required this.email,
    required this.phone,
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

  /// 'YYYY-MM-DD' 格式的合法日期字串；空字串表示未填。
  final String birthday;
  final String email;
  final String phone;
  final String department;
  final String grade;
  final String location;
  final String currentStage;
  final List<String> goals;
  final List<String> interests;
  final List<String> experiences;
  final List<EducationEntry> educationItems;
  final String concerns;
  final bool startupInterest;
  final String? createdAt;

  /// 顯示用：拼起來的 email + phone（用於現有顯示位置）
  String get contact {
    final parts = <String>[];
    if (email.isNotEmpty) parts.add(email);
    if (phone.isNotEmpty) parts.add(phone);
    return parts.join(' / ');
  }

  bool get isEmpty {
    // 高中生不需要填科系，所以 isEmpty 不能單看 department。
    final hasBasic = name.isNotEmpty && grade.isNotEmpty;
    return !hasBasic && currentStage.isEmpty && goals.isEmpty;
  }

  /// 從 `birthday` 字串推算的整數年齡；無效或空回 null。
  int? get age {
    final d = parsedBirthday;
    if (d == null) return null;
    final now = DateTime.now();
    var years = now.year - d.year;
    final hadBirthdayThisYear = now.month > d.month ||
        (now.month == d.month && now.day >= d.day);
    if (!hadBirthdayThisYear) years -= 1;
    return years < 0 ? null : years;
  }

  /// 解析後的合法 DateTime；若 `birthday` 不是合法 'YYYY-MM-DD' 則為 null。
  DateTime? get parsedBirthday {
    if (birthday.isEmpty) return null;
    return _tryParseDate(birthday);
  }

  /// 高中生不需要填科系
  bool get departmentRequired => grade != '高中';

  AppMode get mode => startupInterest ? AppMode.startup : AppMode.career;

  UserProfile copyWith({
    String? name,
    String? school,
    String? birthday,
    String? email,
    String? phone,
    String? department,
    String? grade,
    String? location,
    String? currentStage,
    List<String>? goals,
    List<String>? interests,
    List<String>? experiences,
    List<EducationEntry>? educationItems,
    String? concerns,
    bool? startupInterest,
    String? createdAt,
  }) {
    return UserProfile(
      name: name ?? this.name,
      school: school ?? this.school,
      birthday: birthday ?? this.birthday,
      email: email ?? this.email,
      phone: phone ?? this.phone,
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
        birthday: '',
        email: '',
        phone: '',
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
        'birthday': birthday,
        'email': email,
        'phone': phone,
        'department': department,
        'grade': grade,
        'location': location,
        'currentStage': currentStage,
        'goals': goals,
        'interests': interests,
        'experiences': experiences,
        'educationItems': educationItems.map((e) => e.toJson()).toList(),
        'concerns': concerns,
        'startupInterest': startupInterest,
        'createdAt': createdAt,
      };

  static UserProfile fromJson(Map<String, dynamic> j) {
    // 兼容舊資料：原本只有單一 'contact' 欄位 → 把它當 email 還原。
    final legacyContact = (j['contact'] as String?) ?? '';
    return UserProfile(
      name: (j['name'] as String?) ?? '',
      school: (j['school'] as String?) ?? '',
      birthday: (j['birthday'] as String?) ?? '',
      email: (j['email'] as String?) ?? legacyContact,
      phone: (j['phone'] as String?) ?? '',
      department: (j['department'] as String?) ?? '',
      grade: (j['grade'] as String?) ?? '',
      location: (j['location'] as String?) ?? '',
      currentStage: (j['currentStage'] as String?) ?? '',
      goals: List<String>.from((j['goals'] as List?) ?? const []),
      interests: List<String>.from((j['interests'] as List?) ?? const []),
      experiences: List<String>.from((j['experiences'] as List?) ?? const []),
      educationItems: EducationEntry.parseListJson(j['educationItems'])
          .toList(),
      concerns: (j['concerns'] as String?) ?? '',
      startupInterest: j['startupInterest'] == true,
      createdAt: j['createdAt'] as String?,
    );
  }
}

/// 解析 'YYYY-MM-DD' 字串為合法 DateTime；非合法日期回 null。
DateTime? _tryParseDate(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12) return null;
  if (d < 1 || d > 31) return null;
  // DateTime 會把 2-30 之類非法日期 normalize 成下個月，因此要回頭驗證
  final dt = DateTime(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  return dt;
}

/// 公開的合法日期檢查（給 UI 使用）
bool isValidYmdDate(String s) => _tryParseDate(s) != null;

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
    required this.account,
    required this.profile,
    required this.persona,
    required this.explore,
    required this.dailyAnswers,
    required this.planTodos,
    required this.planWeekNotes,
    required this.strike,
    required this.skillTranslations,
  });

  final UserAccount account;
  final UserProfile profile;
  final Persona persona;
  final ExploreResults explore;
  final Map<String, DailyAnswerEntry> dailyAnswers;
  final Map<String, bool> planTodos;
  final Map<String, String> planWeekNotes;
  final StrikeState strike;
  final List<SkillTranslation> skillTranslations;

  bool get isAuthenticated => account.isAuthenticated;
  bool get isOnboarded => !profile.isEmpty;

  static AppStorage empty() {
    return AppStorage(
      account: UserAccount.empty(),
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
    UserAccount? account,
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
      account: account ?? this.account,
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
      'account': account.toJson(),
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
    final accountRaw = json['account'];

    final account = accountRaw is Map
        ? UserAccount.fromJson(Map<String, dynamic>.from(accountRaw))
        : empty.account;

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
      account: account,
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
