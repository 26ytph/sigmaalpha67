import '../models/models.dart';

/// 規則式 Intent Normalizer：把口語問題拆成結構化欄位（給諮詢師快速接手）。
class IntentNormalizer {
  static NormalizedQuestion normalize({
    required String question,
    UserProfile? profile,
  }) {
    final q = question;
    final intents = _detectIntents(q);
    final emotion = _detectEmotion(q);
    final urgency = _detectUrgency(q, intents, emotion);

    final stage = profile != null && profile.currentStage.isNotEmpty
        ? profile.currentStage
        : _guessStage(q);

    final knownInfo = <String>[];
    final missingInfo = <String>[];

    if (profile != null && profile.department.isNotEmpty) {
      knownInfo.add('科系：${profile.department}');
    } else {
      missingInfo.add('科系與在學狀態');
    }

    if (profile != null && profile.experiences.isNotEmpty) {
      knownInfo.add('過去經驗：${profile.experiences.take(2).join('、')}');
    } else {
      missingInfo.add('過去社團／課程／實習經驗');
    }

    if (profile != null && profile.goals.isNotEmpty) {
      knownInfo.add('目前目標：${profile.goals.first}');
    } else {
      missingInfo.add('短期目標（找實習／轉職／創業）');
    }

    if (q.contains('履歷')) {
      knownInfo.add('已關注履歷議題');
    }
    if (q.contains('沒回音') || q.contains('沒回應') || q.contains('被拒')) {
      knownInfo.add('已嘗試投履歷但未獲回應');
      missingInfo.add('投遞職缺類型與數量');
    }
    if (q.contains('不知道') || q.contains('迷惘')) {
      missingInfo.add('具體想釐清的方向');
    }

    final suggested = _suggestQuestions(intents, q, profile);
    final summary = _composeSummary(intents, stage, emotion, q, profile);

    return NormalizedQuestion(
      userStage: stage,
      intents: intents,
      emotion: emotion,
      knownInfo: knownInfo,
      missingInfo: missingInfo,
      suggestedQuestions: suggested,
      urgency: urgency,
      counselorSummary: summary,
    );
  }

  static List<String> _detectIntents(String q) {
    final out = <String>{};
    if (q.contains('履歷') || q.contains('CV') || q.contains('resume')) {
      out.add('履歷協助');
    }
    if (q.contains('面試') || q.contains('interview')) {
      out.add('面試準備');
    }
    if (q.contains('方向') || q.contains('迷惘') || q.contains('不知道做什麼')) {
      out.add('職涯探索');
    }
    if (q.contains('實習')) {
      out.add('實習尋找');
    }
    if (q.contains('正職') || q.contains('找工作') || q.contains('就業')) {
      out.add('求職規劃');
    }
    if (q.contains('技能') || q.contains('能力') || q.contains('學什麼')) {
      out.add('技能盤點');
    }
    if (q.contains('創業') || q.contains('開店') || q.contains('做生意')) {
      out.add('創業諮詢');
    }
    if (q.contains('補助') || q.contains('貸款') || q.contains('資金')) {
      out.add('資源／政策');
    }
    if (q.contains('壓力') || q.contains('焦慮') || q.contains('累')) {
      out.add('心理支持');
    }
    if (out.isEmpty) out.add('一般職涯諮詢');
    return out.toList();
  }

  static String _detectEmotion(String q) {
    if (q.contains('焦慮') || q.contains('壓力') || q.contains('煩') || q.contains('累')) {
      return '焦慮、有壓力';
    }
    if (q.contains('迷惘') || q.contains('不知道') || q.contains('不確定')) {
      return '不確定、迷惘';
    }
    if (q.contains('興奮') || q.contains('期待')) {
      return '期待、有動能';
    }
    if (q.contains('沮喪') || q.contains('失落') || q.contains('被拒')) {
      return '沮喪、信心受挫';
    }
    return '中性、想釐清';
  }

  static String _detectUrgency(String q, List<String> intents, String emotion) {
    if (q.contains('明天') || q.contains('這週') || q.contains('快來不及')) {
      return '高';
    }
    if (emotion.contains('焦慮') || emotion.contains('沮喪')) {
      return '中高';
    }
    if (intents.contains('面試準備') || intents.contains('履歷協助')) {
      return '中';
    }
    return '中低';
  }

  static String _guessStage(String q) {
    if (q.contains('應屆') || q.contains('快畢業') || q.contains('大四') || q.contains('研二')) {
      return '應屆畢業生';
    }
    if (q.contains('在學') || q.contains('大一') || q.contains('大二') || q.contains('大三')) {
      return '在學探索';
    }
    if (q.contains('轉職')) return '想轉職';
    if (q.contains('創業')) return '創業探索';
    return '尚未確認';
  }

  static List<String> _suggestQuestions(
      List<String> intents, String q, UserProfile? profile) {
    final out = <String>[];
    if (intents.contains('職涯探索')) {
      out.add('你目前就讀什麼科系？');
      out.add('過去有哪些社團、課程或實習經驗？');
      out.add('比較想找實習、正職，還是再多探索方向？');
    }
    if (intents.contains('履歷協助')) {
      out.add('履歷想投遞哪一類職缺？');
      out.add('哪一段經驗你最希望被看見？');
    }
    if (intents.contains('面試準備')) {
      out.add('面試的公司／職缺是？');
      out.add('最擔心被問到的問題是哪一類？');
    }
    if (intents.contains('創業諮詢')) {
      out.add('目前的創業想法是？預計服務的客群是誰？');
      out.add('資金與場地的需求大致為何？');
    }
    if (out.isEmpty) {
      out.add('可以再多描述一下你目前的狀況嗎？');
      out.add('你希望今天的對話結束時，能帶走什麼？');
    }
    return out.take(3).toList();
  }

  static String _composeSummary(
    List<String> intents,
    String stage,
    String emotion,
    String q,
    UserProfile? profile,
  ) {
    final buf = StringBuffer();
    final dept = profile?.department ?? '';
    if (dept.isNotEmpty) {
      buf.write('使用者為$dept學生，');
    }
    buf.write('目前處於「$stage」階段，情緒狀態偏「$emotion」。');
    if (intents.isNotEmpty) {
      buf.write('主要意圖為 ${intents.join('、')}。');
    }
    if (q.length > 60) {
      buf.write('原始問題：${q.substring(0, 60)}…');
    } else {
      buf.write('原始問題：$q');
    }
    buf.write(' 建議諮詢師先確認過去經驗與目標時程，再針對最迫切的一項給出可執行的下一步。');
    return buf.toString();
  }
}
