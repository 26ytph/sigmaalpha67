import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../logic/persona_engine.dart';
import '../logic/skill_translator.dart';
import '../models/models.dart';
import '../services/app_repository.dart';
import '../utils/theme.dart';

class SkillTranslatorScreen extends StatefulWidget {
  const SkillTranslatorScreen({
    super.key,
    required this.storage,
    required this.onStorageChanged,
  });

  final AppStorage storage;
  final ValueChanged<AppStorage> onStorageChanged;

  @override
  State<SkillTranslatorScreen> createState() => _SkillTranslatorScreenState();
}

class _SkillTranslatorScreenState extends State<SkillTranslatorScreen> {
  final TextEditingController _input = TextEditingController();
  SkillTranslation? _draft;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _useExample() {
    _input.text = '我曾經辦過迎新活動，也參加過課內訪談報告。';
    _translate();
  }

  void _translate() {
    final raw = _input.text.trim();
    if (raw.isEmpty) return;
    setState(() => _draft = SkillTranslatorEngine.translate(raw));
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    final next = await AppRepository.update((prev) {
      final list = [...prev.skillTranslations, draft];
      final newPersona = PersonaEngine.generate(
        profile: prev.profile,
        explore: prev.explore,
        skillTranslations: list,
        previous: prev.persona,
      );
      // 若使用者已手動編輯過 Persona 文字，採輕量更新；否則用全新 Persona。
      final mergedPersona = prev.persona.userEdited
          ? prev.persona.copyWith(
              strengths: newPersona.strengths,
              skillGaps: newPersona.skillGaps,
              recommendedNextStep: newPersona.recommendedNextStep,
              lastUpdated: DateTime.now().toIso8601String(),
            )
          : newPersona;
      return prev.copyWith(skillTranslations: list, persona: mergedPersona);
    });
    if (!mounted) return;
    widget.onStorageChanged(next);
    setState(() {
      _input.clear();
      _draft = null;
    });
    _showToast('已加入 Persona，新的能力會出現在「既有能力」區。');
  }

  void _copyResume(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showToast('已複製到剪貼簿');
  }

  void _showToast(String text) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 88,
        left: 24,
        right: 24,
        child: IgnorePointer(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1700), () => entry.remove());
  }

  @override
  Widget build(BuildContext context) {
    final history = widget.storage.skillTranslations;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        middle: Text('技能翻譯'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            _intro(),
            AppGaps.h14,
            _inputCard(),
            if (_draft != null) ...[
              AppGaps.h14,
              _resultCard(_draft!),
            ],
            AppGaps.h20,
            if (history.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  '已加入 Persona 的翻譯',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              for (final t in history.reversed) _historyTile(t),
            ],
          ],
        ),
      ),
    );
  }

  Widget _intro() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0E7FF), Color(0xFFFCE7F3)],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: const Icon(CupertinoIcons.sparkles,
                size: 20, color: AppColors.brandStart),
          ),
          AppGaps.w12,
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '把生活、社團、課程經驗轉成履歷句子',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                AppGaps.h6,
                Text(
                  '輸入你做過的事（口語就行），AI 會幫你拆解出對應的職場能力，並產生一段可放履歷的描述。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '輸入你的經驗',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          AppGaps.h10,
          CupertinoTextField(
            controller: _input,
            minLines: 4,
            maxLines: 8,
            placeholder: '例如：我辦過迎新、社團幹部、做過課內專案訪談…',
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
          ),
          AppGaps.h12,
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: AppColors.surfaceMuted,
                  onPressed: _useExample,
                  child: const Text(
                    '塞個例子',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              AppGaps.w8,
              Expanded(
                flex: 2,
                child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onPressed: _input.text.trim().isEmpty ? null : _translate,
                  child: const Text('開始翻譯'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultCard(SkillTranslation t) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: const Text(
                  'AI 翻譯結果',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ],
          ),
          AppGaps.h12,
          for (final g in t.groups) _groupTile(g),
          AppGaps.h12,
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgAlt,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(CupertinoIcons.doc_text,
                        size: 14, color: AppColors.brandStart),
                    AppGaps.w6,
                    Text(
                      '可放履歷的句子',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: AppColors.brandStart,
                      ),
                    ),
                  ],
                ),
                AppGaps.h8,
                Text(
                  t.resumeSentence,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                ),
                AppGaps.h10,
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        color: AppColors.surface,
                        onPressed: () => _copyResume(t.resumeSentence),
                        child: const Text(
                          '複製句子',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    AppGaps.w8,
                    Expanded(
                      flex: 2,
                      child: CupertinoButton.filled(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        onPressed: _save,
                        child: const Text('加入 Persona'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupTile(TranslatedSkillGroup g) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '原始經驗',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
            AppGaps.h4,
            Text(
              g.experience,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            AppGaps.h8,
            const Text(
              '對應職場能力',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
            AppGaps.h6,
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in g.skills)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyTile(SkillTranslation t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.rawExperience,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          AppGaps.h6,
          Text(
            t.resumeSentence,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
