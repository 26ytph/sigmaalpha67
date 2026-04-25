import '../models/models.dart';

class CounselorBrief {
  const CounselorBrief({
    required this.userBackground,
    required this.personaSummary,
    required this.recentActivities,
    required this.mainQuestion,
    required this.aiAnalysis,
    required this.suggestedTopics,
    required this.recommendedResources,
    required this.aiDraftReply,
    required this.urgency,
  });

  final String userBackground;
  final String personaSummary;
  final String recentActivities;
  final String mainQuestion;
  final String aiAnalysis;
  final List<String> suggestedTopics;
  final List<String> recommendedResources;
  final String aiDraftReply;
  final String urgency;
}

class CounselorBriefEngine {
  static CounselorBrief build({
    required UserProfile profile,
    required Persona persona,
    required ExploreResults explore,
    required NormalizedQuestion normalized,
    required String originalQuestion,
  }) {
    final bgParts = <String>[];
    if (profile.department.isNotEmpty) bgParts.add(profile.department);
    if (profile.grade.isNotEmpty) bgParts.add(profile.grade);
    if (profile.location.isNotEmpty) bgParts.add(profile.location);
    bgParts.add(profile.currentStage.isNotEmpty ? profile.currentStage : '尚未確認階段');
    final background = bgParts.join('・');

    final personaSummary =
        persona.text.isNotEmpty ? persona.text : '尚未生成 Persona，可先請使用者完成 Onboarding。';

    final activities = <String>[];
    if (explore.likedRoleIds.isNotEmpty) {
      activities.add('近期右滑了 ${explore.likedRoleIds.length} 個職位');
    }
    if (explore.dislikedRoleIds.isNotEmpty) {
      activities.add('左滑排除 ${explore.dislikedRoleIds.length} 個方向');
    }
    if (persona.mainInterests.isNotEmpty) {
      activities.add('興趣集中在 ${persona.mainInterests.join('、')}');
    }
    if (activities.isEmpty) activities.add('尚未開始探索');
    final recent = activities.join('；');

    final analysis = _composeAnalysis(persona, normalized);
    final suggestedTopics = _composeSuggestedTopics(normalized, persona);
    final resources = _composeResources(persona, normalized);
    final draft = _composeDraftReply(profile, persona, normalized);

    return CounselorBrief(
      userBackground: background,
      personaSummary: personaSummary,
      recentActivities: recent,
      mainQuestion: originalQuestion,
      aiAnalysis: analysis,
      suggestedTopics: suggestedTopics,
      recommendedResources: resources,
      aiDraftReply: draft,
      urgency: normalized.urgency,
    );
  }

  static String _composeAnalysis(Persona persona, NormalizedQuestion n) {
    final buf = StringBuffer();
    buf.write('意圖：${n.intents.join('、')}；情緒：${n.emotion}。');
    if (persona.skillGaps.isNotEmpty) {
      buf.write('可能卡關點包含 ${persona.skillGaps.take(2).join('、')}。');
    }
    if (n.missingInfo.isNotEmpty) {
      buf.write('尚缺資訊：${n.missingInfo.take(2).join('、')}。');
    }
    return buf.toString();
  }

  static List<String> _composeSuggestedTopics(
      NormalizedQuestion n, Persona persona) {
    final out = <String>[];
    out.add('先以同理回應安撫情緒，再進入結構化釐清');
    if (n.missingInfo.isNotEmpty) {
      out.add('優先確認：${n.missingInfo.first}');
    }
    if (persona.recommendedNextStep.isNotEmpty) {
      out.add('可順著 AI 建議的下一步：${persona.recommendedNextStep}');
    }
    return out;
  }

  static List<String> _composeResources(
      Persona persona, NormalizedQuestion n) {
    final out = <String>[];
    if (n.intents.contains('履歷協助')) out.add('一頁式履歷模板＋面談重點清單');
    if (n.intents.contains('面試準備')) out.add('STAR 結構問答庫');
    if (n.intents.contains('創業諮詢')) {
      out.addAll(['青年創業貸款資訊', '一站式創業諮詢窗口']);
    }
    if (n.intents.contains('資源／政策')) out.add('政府就業／補助公告整理');
    if (persona.mainInterests.isNotEmpty) {
      out.add('${persona.mainInterests.first} 入門資源包');
    }
    if (out.isEmpty) out.add('青年職涯諮詢預約連結');
    return out;
  }

  static String _composeDraftReply(
      UserProfile profile, Persona persona, NormalizedQuestion n) {
    final name = profile.name.isNotEmpty ? '${profile.name}，' : '';
    final emotionAck = n.emotion.contains('焦慮') || n.emotion.contains('沮喪')
        ? '聽起來目前有些壓力，這很正常。'
        : '謝謝你願意把現在的狀況分享出來。';
    final stepHint = persona.recommendedNextStep.isNotEmpty
        ? '我們可以從這個方向開始：${persona.recommendedNextStep}'
        : '我們可以從你最有感的一件事開始拆解。';
    final clarify = n.suggestedQuestions.isNotEmpty
        ? '想先請教：${n.suggestedQuestions.first}'
        : '可以多告訴我一點你目前的狀況嗎？';
    return '嗨$name$emotionAck$stepHint $clarify';
  }
}
