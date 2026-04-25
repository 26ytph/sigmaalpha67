import '../models/models.dart';

/// 規則式技能翻譯器：把口語的生活／社團／課程經驗映射成履歷可用語言。
class SkillTranslatorEngine {
  static SkillTranslation translate(String raw) {
    final segments = _splitToSegments(raw);
    final groups = <TranslatedSkillGroup>[];
    for (final s in segments) {
      final skills = _mapSegmentToSkills(s);
      if (skills.isEmpty) continue;
      groups.add(TranslatedSkillGroup(experience: s, skills: skills));
    }
    if (groups.isEmpty) {
      groups.add(
        TranslatedSkillGroup(
          experience: raw.trim().isEmpty ? '（無輸入）' : raw.trim(),
          skills: const ['溝通協調', '時間管理', '責任感'],
        ),
      );
    }

    final resume = _composeResumeSentence(groups);

    return SkillTranslation(
      id: 'st_${DateTime.now().microsecondsSinceEpoch}',
      rawExperience: raw.trim(),
      groups: groups,
      resumeSentence: resume,
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  static List<String> _splitToSegments(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return const [];
    final parts = t.split(RegExp('[，。；\n,;]+'));
    return parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  }

  static List<String> _mapSegmentToSkills(String seg) {
    final out = <String>{};
    final s = seg;

    if (s.contains('迎新') || s.contains('營隊') || s.contains('辦活動') || s.contains('籌辦')) {
      out.addAll(['活動企劃', '流程把控', '跨組溝通', '現場執行']);
    }
    if (s.contains('社長') || s.contains('幹部') || s.contains('隊長') || s.contains('組長')) {
      out.addAll(['團隊領導', '會議管理', '目標拆解']);
    }
    if (s.contains('社團') && out.isEmpty) {
      out.addAll(['團隊合作', '溝通協調']);
    }
    if (s.contains('訪談') || s.contains('採訪')) {
      out.addAll(['訪談技巧', '需求探詢', '資料整理']);
    }
    if (s.contains('報告') || s.contains('簡報') || s.contains('發表')) {
      out.addAll(['口頭表達', '結論先行', '視覺化呈現']);
    }
    if (s.contains('文案') || s.contains('寫作')) {
      out.addAll(['內容策劃', '文字編輯']);
    }
    if (s.contains('家教') || s.contains('教學') || s.contains('助教')) {
      out.addAll(['教學引導', '同理心', '解釋複雜概念']);
    }
    if (s.contains('打工') || s.contains('兼職') || s.contains('工讀') || s.contains('門市')) {
      out.addAll(['服務應對', '多工處理', '責任感']);
    }
    if (s.contains('客服') || s.contains('門市')) {
      out.addAll(['客戶溝通', '問題排查']);
    }
    if (s.contains('比賽') || s.contains('競賽') || s.contains('黑客松')) {
      out.addAll(['抗壓性', '時程管理', '快速迭代']);
    }
    if (s.contains('專案') || s.contains('專題') || s.contains('課內')) {
      out.addAll(['問題拆解', '報告撰寫', '小組協作']);
    }
    if (s.contains('資料') || s.contains('分析') || s.contains('Excel') || s.contains('SQL')) {
      out.addAll(['資料整理', '邏輯分析', '指標思維']);
    }
    if (s.contains('Figma') || s.contains('設計') || s.contains('UI')) {
      out.addAll(['介面設計', '原型製作']);
    }
    if (s.contains('影片') || s.contains('剪輯') || s.contains('YouTube') || s.contains('IG')) {
      out.addAll(['內容製作', '社群經營']);
    }
    if (s.contains('粉專') || s.contains('社群') || s.contains('小編')) {
      out.addAll(['社群經營', '受眾洞察']);
    }
    if (s.contains('業務') || s.contains('銷售') || s.contains('推廣')) {
      out.addAll(['提案能力', '客戶開發']);
    }
    if (s.contains('志工') || s.contains('服務')) {
      out.addAll(['同理心', '跨組協作']);
    }
    if (s.contains('打程式') || s.contains('寫程式') || s.contains('coding')) {
      out.addAll(['程式設計', '系統思維']);
    }

    return out.toList();
  }

  static String _composeResumeSentence(List<TranslatedSkillGroup> groups) {
    if (groups.isEmpty) return '';
    final buf = StringBuffer();
    final first = groups.first;
    buf.write('曾於${first.experience}中');
    final allSkills = <String>{};
    for (final g in groups) {
      allSkills.addAll(g.skills);
    }
    if (allSkills.isNotEmpty) {
      buf.write('展現${allSkills.take(3).join('、')}的能力');
    }
    if (groups.length > 1) {
      final more = groups.skip(1).take(2).map((g) => g.experience).join('、');
      buf.write('，並於$more中累積跨情境協作經驗');
    }
    buf.write('，能將實作經驗轉化為可量化交付。');
    return buf.toString();
  }
}
