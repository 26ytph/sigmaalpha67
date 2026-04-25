import 'package:flutter/cupertino.dart';

import '../logic/persona_engine.dart';
import '../models/models.dart';
import '../services/app_repository.dart';
import '../utils/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.initialProfile,
    required this.initialSelfIntro,
    required this.onCompleted,
    this.editing = false,
  });

  final UserProfile initialProfile;
  final String initialSelfIntro;
  final ValueChanged<AppStorage> onCompleted;
  final bool editing;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final TextEditingController _name;
  late final TextEditingController _school;
  late final TextEditingController _age;
  late final TextEditingController _contact;
  late final TextEditingController _department;
  late final TextEditingController _location;
  late final TextEditingController _concerns;
  late final TextEditingController _selfIntro;

  String _grade = '';
  String _stage = '';
  final Set<String> _goals = {};
  final Set<String> _interests = {};
  final Set<String> _experiences = {};
  bool _startupInterest = false;

  int _step = 0;
  static const _totalSteps = 5;

  static const _gradeOptions = ['高中', '大一', '大二', '大三', '大四', '研究生', '畢業 1–3 年', '已工作'];
  static const _stageOptions = ['在學探索', '應屆畢業生', '想找實習', '想找正職', '想轉職', '創業探索'];
  static const _goalOptions = [
    '找實習', '找正職', '想轉職', '想創業', '釐清方向', '補強技能', '寫履歷', '練面試',
  ];
  static const _interestOptions = [
    '工程／程式', '資料分析', '產品企劃', 'UI/UX 設計', '行銷／內容', '業務／BD',
    '人資／教育訓練', '財務／會計', '資安', '影音內容', '社群經營', '客戶服務',
  ];
  static const _experienceOptions = [
    '社團幹部', '系上活動', '課內專案', '實習', '工讀／打工', '比賽／黑客松',
    '志工服務', '家教／助教', '個人作品', '經營粉專／IG',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _name = TextEditingController(text: p.name);
    _school = TextEditingController(text: p.school);
    _age = TextEditingController(text: p.age);
    _contact = TextEditingController(text: p.contact);
    _department = TextEditingController(text: p.department);
    _location = TextEditingController(text: p.location);
    _concerns = TextEditingController(text: p.concerns);
    _selfIntro = TextEditingController(text: widget.initialSelfIntro);
    _grade = p.grade;
    _stage = p.currentStage;
    _goals.addAll(p.goals);
    _interests.addAll(p.interests);
    _experiences.addAll(p.experiences);
    _startupInterest = p.startupInterest;
  }

  @override
  void dispose() {
    _name.dispose();
    _school.dispose();
    _age.dispose();
    _contact.dispose();
    _department.dispose();
    _location.dispose();
    _concerns.dispose();
    _selfIntro.dispose();
    super.dispose();
  }

  bool get _canNext {
    switch (_step) {
      case 0:
        return _name.text.trim().isNotEmpty &&
            _department.text.trim().isNotEmpty &&
            _grade.isNotEmpty;
      case 1:
        return _stage.isNotEmpty && _goals.isNotEmpty;
      case 2:
        return true;
      case 3:
        return _interests.isNotEmpty;
      case 4:
        return true;
      default:
        return false;
    }
  }

  Future<void> _finish() async {
    final defaultEducation = [
      _school.text.trim(),
      _department.text.trim(),
      _grade,
    ].where((s) => s.isNotEmpty).join(' ');

    final eduList = widget.initialProfile.educationItems.isNotEmpty
        ? widget.initialProfile.educationItems
        : (defaultEducation.isNotEmpty ? [defaultEducation] : <String>[]);

    final profile = UserProfile(
      name: _name.text.trim(),
      school: _school.text.trim(),
      age: _age.text.trim(),
      contact: _contact.text.trim(),
      department: _department.text.trim(),
      grade: _grade,
      location: _location.text.trim(),
      currentStage: _stage,
      goals: _goals.toList(),
      interests: _interests.toList(),
      experiences: _experiences.toList(),
      educationItems: eduList,
      concerns: _concerns.text.trim(),
      startupInterest: _startupInterest,
      createdAt: widget.initialProfile.createdAt ??
          DateTime.now().toIso8601String(),
    );

    final selfIntroText = _selfIntro.text.trim();

    final next = await AppRepository.update((prev) {
      // 先用 PersonaEngine 算出結構化欄位（不含 text）
      final base = PersonaEngine.generate(
        profile: profile,
        explore: prev.explore,
        skillTranslations: prev.skillTranslations,
        previous: prev.persona,
      );
      // text 一律以使用者輸入為準（空就維持空）
      final newPersona = base.copyWith(text: selfIntroText, userEdited: true);
      return prev.copyWith(profile: profile, persona: newPersona);
    });

    if (!mounted) return;
    widget.onCompleted(next);
  }

  void _next() {
    if (_step == _totalSteps - 1) {
      _finish();
    } else {
      setState(() => _step += 1);
    }
  }

  void _back() {
    if (_step == 0) {
      if (widget.editing) Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step -= 1);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_step + 1) / _totalSteps;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                    onPressed: _back,
                    child: Icon(
                      _step == 0
                          ? (widget.editing
                              ? CupertinoIcons.xmark
                              : CupertinoIcons.sparkles)
                          : CupertinoIcons.back,
                      color: AppColors.iosBlue,
                      size: 22,
                    ),
                  ),
                  AppGaps.w8,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.editing ? '更新個人資料' : '建立個人輪廓',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_step + 1} / $_totalSteps',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        AppGaps.h6,
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          child: SizedBox(
                            height: 4,
                            child: Stack(
                              children: [
                                const ColoredBox(color: AppColors.border),
                                FractionallySizedBox(
                                  widthFactor: progress,
                                  child: const DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: AppColors.iosBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _buildStep(_step),
                    ),
                  ),
                ),
              ),
            ),
            _ContinueBar(
              canNext: _canNext,
              isLast: _step == _totalSteps - 1,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int step) {
    switch (step) {
      case 0:
        return _stepBasic(key: const ValueKey('s0'));
      case 1:
        return _stepStage(key: const ValueKey('s1'));
      case 2:
        return _stepStartup(key: const ValueKey('s2'));
      case 3:
        return _stepInterests(key: const ValueKey('s3'));
      case 4:
        return _stepExperience(key: const ValueKey('s4'));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _wrapCard({required Widget child, Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppColors.shadowSoft,
      ),
      child: child,
    );
  }

  Widget _heading(String big, String small) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(small, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
        AppGaps.h4,
        Text(
          big,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            if (required) ...[
              AppGaps.w4,
              const Text(
                '＊',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.iosRed,
                ),
              ),
            ],
          ],
        ),
      );

  Widget _stepBasic({Key? key}) {
    return _wrapCard(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading('讓我們先認識你', 'Step 1 ・ 基本資料'),
          AppGaps.h16,
          _label('姓名', required: true),
          CupertinoTextField(
            controller: _name,
            placeholder: '請輸入本名',
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onChanged: (_) => setState(() {}),
          ),
          AppGaps.h12,
          _label('學校（選填）'),
          CupertinoTextField(
            controller: _school,
            placeholder: '例如：國立台灣大學',
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          AppGaps.h12,
          _label('科系 / 領域', required: true),
          CupertinoTextField(
            controller: _department,
            placeholder: '例如：社會系、資訊管理',
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onChanged: (_) => setState(() {}),
          ),
          AppGaps.h12,
          _label('年級 / 身份', required: true),
          _ChipGroup(
            options: _gradeOptions,
            selected: {if (_grade.isNotEmpty) _grade},
            onChanged: (s) => setState(() => _grade = s.isEmpty ? '' : s.first),
            single: true,
          ),
          AppGaps.h12,
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label('年齡（選填）'),
                    CupertinoTextField(
                      controller: _age,
                      placeholder: '例如：21',
                      keyboardType: TextInputType.number,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ],
                ),
              ),
              AppGaps.w12,
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label('聯絡方式（選填）'),
                    CupertinoTextField(
                      controller: _contact,
                      placeholder: 'email 或 IG',
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppGaps.h12,
          _label('居住地（選填）'),
          CupertinoTextField(
            controller: _location,
            placeholder: '例如：台北市、新竹',
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ],
      ),
    );
  }

  Widget _stepStage({Key? key}) {
    return _wrapCard(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading('你目前在哪個階段？', 'Step 2 ・ 目前狀態'),
          AppGaps.h16,
          _label('你目前的狀態'),
          _ChipGroup(
            options: _stageOptions,
            selected: {if (_stage.isNotEmpty) _stage},
            onChanged: (s) => setState(() => _stage = s.isEmpty ? '' : s.first),
            single: true,
          ),
          AppGaps.h16,
          _label('短期目標（可複選）'),
          _ChipGroup(
            options: _goalOptions,
            selected: _goals,
            onChanged: (s) => setState(() {
              _goals
                ..clear()
                ..addAll(s);
            }),
          ),
        ],
      ),
    );
  }

  Widget _stepStartup({Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading('選擇你的路線', 'Step 3'),
          AppGaps.h20,
          Row(
            children: [
              Expanded(
                child: _StartupChoice(
                  selected: !_startupInterest,
                  icon: CupertinoIcons.briefcase_fill,
                  title: '我要就業',
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5856D6), Color(0xFF007AFF)],
                  ),
                  onTap: () => setState(() => _startupInterest = false),
                ),
              ),
              AppGaps.w12,
              Expanded(
                child: _StartupChoice(
                  selected: _startupInterest,
                  icon: CupertinoIcons.flame_fill,
                  title: '我要創業',
                  gradient: AppColors.startupGradient,
                  onTap: () => setState(() => _startupInterest = true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepInterests({Key? key}) {
    return _wrapCard(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(
            _startupInterest ? '對哪些創業方向感興趣？' : '哪些方向你比較有興趣？',
            'Step 4 ・ 興趣方向',
          ),
          AppGaps.h6,
          const Text(
            '至少選 1 項，後續滑卡會根據你的選擇微調 Persona。',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          AppGaps.h16,
          _ChipGroup(
            options: _interestOptions,
            selected: _interests,
            onChanged: (s) => setState(() {
              _interests
                ..clear()
                ..addAll(s);
            }),
          ),
        ],
      ),
    );
  }

  Widget _stepExperience({Key? key}) {
    return _wrapCard(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading('過去做過什麼事？', 'Step 5 ・ 經驗、自介與困擾'),
          AppGaps.h6,
          const Text(
            '勾選你曾經參與的類型；可在「技能翻譯」進一步把它們變成履歷句子。',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          AppGaps.h12,
          _ChipGroup(
            options: _experienceOptions,
            selected: _experiences,
            onChanged: (s) => setState(() {
              _experiences
                ..clear()
                ..addAll(s);
            }),
          ),
          AppGaps.h16,
          _label('自介（選填）'),
          const Text(
            '寫不出來也沒關係，留空就好；有想說的就用自己的話寫。',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary, height: 1.5),
          ),
          AppGaps.h6,
          CupertinoTextField(
            controller: _selfIntro,
            placeholder: '例如：社會系大三，喜歡觀察人、整理資訊…',
            minLines: 4,
            maxLines: 7,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          AppGaps.h16,
          _label('目前最困擾你的事（選填）'),
          CupertinoTextField(
            controller: _concerns,
            placeholder: _startupInterest
                ? '例如：不知道怎麼驗證想法、找不到夥伴…'
                : '例如：不知道哪個方向適合自己、履歷沒回音…',
            minLines: 3,
            maxLines: 5,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ],
      ),
    );
  }
}

class _StartupChoice extends StatelessWidget {
  const _StartupChoice({
    required this.selected,
    required this.icon,
    required this.title,
    required this.gradient,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          gradient: selected ? gradient : null,
          color: selected ? null : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: selected ? AppColors.shadow : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 38,
              color: selected ? CupertinoColors.white : AppColors.textTertiary,
            ),
            AppGaps.h12,
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: selected ? CupertinoColors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.single = false,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool single;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          _Chip(
            label: o,
            selected: selected.contains(o),
            onTap: () {
              final next = Set<String>.from(selected);
              if (single) {
                next
                  ..clear()
                  ..add(o);
              } else {
                if (next.contains(o)) {
                  next.remove(o);
                } else {
                  next.add(o);
                }
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.iosBlue : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? AppColors.iosBlue : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? CupertinoColors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({
    required this.canNext,
    required this.isLast,
    required this.onNext,
  });

  final bool canNext;
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 14),
            color: AppColors.iosBlue,
            disabledColor: AppColors.borderStrong,
            borderRadius: BorderRadius.circular(AppRadii.md),
            onPressed: canNext ? onNext : null,
            child: Text(
              isLast ? '完成' : '下一步',
              style: const TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
