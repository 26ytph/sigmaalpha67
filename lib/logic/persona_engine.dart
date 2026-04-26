import '../data/roles.dart';
import '../models/models.dart';

/// 規則式假 AI：根據 Profile + 探索結果 + 技能翻譯，組裝 Persona 的「結構化欄位」。
///
/// 自介段落 (`Persona.text`) 由使用者自己填寫，**不會** 被 PersonaEngine 改寫。
/// 即便重新生成或滑卡更新，引擎只會更新 mainInterests / strengths / skillGaps / nextStep，
/// 既有的使用者自介保留不動。
class PersonaEngine {
  static Persona generate({
    required UserProfile profile,
    required ExploreResults explore,
    required List<SkillTranslation> skillTranslations,
    Persona? previous,
  }) {
    if (profile.isEmpty) return Persona.empty();

    final likedRoles =
        roles.where((r) => explore.likedRoleIds.contains(r.id)).toList();

    final tagCounts = <RoleTag, int>{};
    for (final r in likedRoles) {
      for (final t in r.tags) {
        tagCounts[t] = (tagCounts[t] ?? 0) + 1;
      }
    }
    final topTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final mainInterests = <String>[];
    for (final e in topTags.take(3)) {
      mainInterests.add(e.key.label);
    }
    if (mainInterests.isEmpty && profile.interests.isNotEmpty) {
      mainInterests.addAll(profile.interests.take(3));
    }

    final strengths = <String>{};
    for (final exp in profile.experiences) {
      strengths.addAll(_inferSkillsFromExperience(exp));
    }
    for (final t in skillTranslations) {
      for (final g in t.groups) {
        strengths.addAll(g.skills);
      }
    }
    // 不塞預設技能 — 沒填就空著，讓 user 自己用「技能翻譯」加。

    final skillGaps = _inferSkillGapsFromTags(topTags.map((e) => e.key).toList());
    final concerns = profile.concerns.isNotEmpty
        ? [profile.concerns]
        : ['尚不確定下一步方向', '想多了解業界實際工作'];

    final stage =
        profile.currentStage.isNotEmpty ? profile.currentStage : '在學探索';

    final nextStep = _pickNextStep(
      stage: stage,
      mainInterests: mainInterests,
      goals: profile.goals,
      hasExperience: profile.experiences.isNotEmpty,
    );

    return Persona(
      // 自介一律保留使用者輸入；不寫入。
      text: previous?.text ?? '',
      careerStage: stage,
      mainInterests: mainInterests,
      strengths: strengths.take(6).toList(),
      skillGaps: skillGaps,
      mainConcerns: concerns,
      recommendedNextStep: nextStep,
      lastUpdated: DateTime.now().toIso8601String(),
      userEdited: previous?.userEdited ?? false,
    );
  }

  /// 在使用者已編輯 Persona 時，僅輕量補上滑卡帶來的興趣訊號，避免覆寫敘述。
  static Persona refreshSoft({
    required Persona current,
    required ExploreResults explore,
  }) {
    if (current.isEmpty) return current;
    final likedRoles =
        roles.where((r) => explore.likedRoleIds.contains(r.id)).toList();
    final tagCounts = <RoleTag, int>{};
    for (final r in likedRoles) {
      for (final t in r.tags) {
        tagCounts[t] = (tagCounts[t] ?? 0) + 1;
      }
    }
    final topTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final newInterests = <String>{...current.mainInterests};
    for (final e in topTags.take(3)) {
      newInterests.add(e.key.label);
    }
    return current.copyWith(
      mainInterests: newInterests.take(4).toList(),
      lastUpdated: DateTime.now().toIso8601String(),
    );
  }

  static List<String> _inferSkillsFromExperience(String exp) {
    final e = exp.toLowerCase();
    final out = <String>{};
    if (e.contains('社團') || exp.contains('社團')) {
      out.addAll(['團隊合作', '溝通協調']);
    }
    if (exp.contains('幹部') || exp.contains('社長')) {
      out.addAll(['領導力', '會議管理']);
    }
    if (exp.contains('活動') || exp.contains('迎新') || exp.contains('營隊')) {
      out.addAll(['活動企劃', '流程把控', '跨組溝通']);
    }
    if (exp.contains('課內專案') || exp.contains('專題')) {
      out.addAll(['問題拆解', '報告撰寫']);
    }
    if (exp.contains('訪談') || exp.contains('報告')) {
      out.addAll(['訪談技巧', '資料整理', '結論歸納']);
    }
    if (exp.contains('打工') || exp.contains('兼職') || exp.contains('工讀')) {
      out.addAll(['服務應對', '責任感']);
    }
    if (exp.contains('實習')) {
      out.addAll(['職場適應', '任務交付']);
    }
    if (exp.contains('比賽') || exp.contains('競賽')) {
      out.addAll(['抗壓性', '時程管理']);
    }
    return out.toList();
  }

  static List<String> _inferSkillGapsFromTags(List<RoleTag> tags) {
    if (tags.isEmpty) {
      return ['作品集建立', '履歷表達', '產業基本知識'];
    }
    final gaps = <String>[];
    for (final t in tags.take(2)) {
      switch (t) {
        case RoleTag.engineering:
          gaps.addAll(['可展示專案', 'Git 工作流']);
          break;
        case RoleTag.data:
          gaps.addAll(['SQL 基礎', '指標思維']);
          break;
        case RoleTag.product:
          gaps.addAll(['需求拆解', 'PRD 撰寫']);
          break;
        case RoleTag.design:
          gaps.addAll(['作品集敘事', '原型製作']);
          break;
        case RoleTag.marketing:
          gaps.addAll(['投放追蹤', '成效分析']);
          break;
        case RoleTag.sales:
          gaps.addAll(['提案結構', 'BD 案例']);
          break;
        case RoleTag.people:
          gaps.addAll(['結構化面談', '訓練設計']);
          break;
        case RoleTag.finance:
          gaps.addAll(['三大表理解', '預算編列']);
          break;
        case RoleTag.security:
          gaps.addAll(['事件應變', 'OWASP 概念']);
          break;
      }
    }
    return gaps.toSet().take(4).toList();
  }

  static String _pickNextStep({
    required String stage,
    required List<String> mainInterests,
    required List<String> goals,
    required bool hasExperience,
  }) {
    final goalText = goals.isNotEmpty ? goals.first : '';
    if (goalText.contains('實習')) {
      return '先用「技能翻譯」整理過去經驗，再針對 ${mainInterests.isEmpty ? '感興趣' : mainInterests.first} 方向投 2–3 份實習。';
    }
    if (goalText.contains('創業')) {
      return '先把創業想法寫成一頁紙（受眾／價值／驗證），再到「創業 To-do」找補助與資源。';
    }
    if (goalText.contains('轉職') || goalText.contains('正職')) {
      return '先用滑卡探索篩出 2–3 個方向，再針對最有感的方向把履歷重寫一遍。';
    }
    if (!hasExperience) {
      return '先在「探索」滑滿一輪，再用「技能翻譯」把生活與課程經驗轉成履歷可用的句子。';
    }
    return '先到「計畫」挑一週的小任務動起來，比想清楚再行動更容易累積。';
  }

}
