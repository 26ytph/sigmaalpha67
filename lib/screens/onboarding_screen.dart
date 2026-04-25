import 'package:flutter/cupertino.dart';

import '../data/interests_catalog.dart';
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
  late final TextEditingController _contact;
  late final TextEditingController _department;
  late final TextEditingController _location;
  late final TextEditingController _concerns;
  late final TextEditingController _selfIntro;

  String _grade = '';
  String _birthday = ''; // YYYY-MM-DD
  String _stage = '';
  final Set<String> _goals = {};
  final Set<String> _interests = {};
  final Set<String> _experiences = {};
  bool _startupInterest = false;

  // 模擬「打 API」狀態
  bool _analyzing = false;
  List<String> _recommendedInterests = [];

  int _step = 0;
  static const _totalSteps = 5;

  static const _gradeOptions = ['高中', '大一', '大二', '大三', '大四', '研究生', '畢業 1–3 年', '已工作'];
  static const _stageOptions = ['在學探索', '應屆畢業生', '想找實習', '想找正職', '想轉職', '創業探索'];
  static const _goalOptions = [
    '找實習', '找正職', '想轉職', '想創業', '釐清方向', '補強技能', '寫履歷', '練面試',
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
    _contact = TextEditingController(text: p.contact);
    _department = TextEditingController(text: p.department);
    _location = TextEditingController(text: p.location);
    _concerns = TextEditingController(text: p.concerns);
    _selfIntro = TextEditingController(text: widget.initialSelfIntro);
    _grade = p.grade;
    _birthday = p.birthday;
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
    _contact.dispose();
    _department.dispose();
    _location.dispose();
    _concerns.dispose();
    _selfIntro.dispose();
    super.dispose();
  }

  bool get _isHighSchool => _grade == '高中';

  bool get _canNext {
    switch (_step) {
      case 0:
        // 高中不需要科系
        final deptOk = _isHighSchool || _department.text.trim().isNotEmpty;
        return _name.text.trim().isNotEmpty && _grade.isNotEmpty && deptOk;
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

  Future<void> _next() async {
    if (_step == _totalSteps - 1) {
      await _finish();
      return;
    }

    // 完成 Step 1（基本資料）後，模擬向後端要興趣分析
    if (_step == 0) {
      setState(() {
        _step = 1;
      });
      // 不必 block 切到 step 2 之前的呼叫；先在背景算
      _kickInterestAnalysis();
      return;
    }

    // 進入 step 3（興趣選單）前，確保已經算完
    if (_step == 2 && _recommendedInterests.isEmpty) {
      _kickInterestAnalysis();
    }
    setState(() => _step += 1);
  }

  Future<void> _kickInterestAnalysis() async {
    setState(() {
      _analyzing = true;
    });
    // 假裝送 request 給後端，1.2 秒後拿到結果
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    final recs = recommendedInterestsFor(
      department: _department.text.trim(),
      grade: _grade,
      startupInterest: _startupInterest,
    );
    setState(() {
      _recommendedInterests = recs;
      _analyzing = false;
      // 預先勾上 3 個推薦（讓人感覺 AI 有在做事）
      if (_interests.isEmpty) {
        _interests.addAll(recs.take(3));
      }
    });
  }

  void _back() {
    if (_step == 0) {
      if (widget.editing) Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step -= 1);
  }

  Future<void> _pickBirthday() async {
    DateTime initial = DateTime(2003, 1, 1);
    final parsed = _birthday.isNotEmpty ? DateTime.tryParse(_birthday) : null;
    if (parsed != null) initial = parsed;

    DateTime tmp = initial;
    final picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) => Container(
        height: 320,
        padding: const EdgeInsets.only(top: 6),
        color: AppColors.surface,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(ctx, null),
                      child: const Text('取消',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(ctx, tmp),
                      child: const Text(
                        '確認',
                        style: TextStyle(
                          color: AppColors.brandStart,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initial,
                  minimumDate: DateTime(1950, 1, 1),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (d) => tmp = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked == null) return;
    final s = '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    setState(() => _birthday = s);
  }

  Future<void> _finish() async {
    final eduParts = [
      _school.text.trim(),
      if (!_isHighSchool) _department.text.trim(),
      _grade,
    ].where((s) => s.isNotEmpty).toList();
    final defaultEducation = eduParts.join(' ');

    final eduList = widget.initialProfile.educationItems.isNotEmpty
        ? widget.initialProfile.educationItems
        : (defaultEducation.isNotEmpty ? [defaultEducation] : <String>[]);

    final profile = UserProfile(
      name: _name.text.trim(),
      school: _school.text.trim(),
      birthday: _birthday,
      contact: _contact.text.trim(),
      department: _isHighSchool ? '' : _department.text.trim(),
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
      final base = PersonaEngine.generate(
        profile: profile,
        explore: prev.explore,
        skillTranslations: prev.skillTranslations,
        previous: prev.persona,
      );
      final newPersona = base.copyWith(text: selfIntroText, userEdited: true);
      return prev.copyWith(profile: profile, persona: newPersona);
    });

    if (!mounted) return;
    widget.onCompleted(next);
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
                              : CupertinoIcons.heart_fill)
                          : CupertinoIcons.back,
                      color: _step == 0 && !widget.editing
                          ? AppColors.brandStart
                          : AppColors.textSecondary,
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
                                fontWeight: FontWeight.w700,
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
                            height: 6,
                            child: Stack(
                              children: [
                                const ColoredBox(color: AppColors.border),
                                FractionallySizedBox(
                                  widthFactor: progress,
                                  child: const DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: AppColors.brandGradient,
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
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
            fontSize: 24,
            fontWeight: FontWeight.w800,
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
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            if (required) ...[
              AppGaps.w4,
              const Text(
                '＊',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.iosRed,
                ),
              ),
            ],
          ],
        ),
      );

  Widget _stepBasic({Key? key}) {
    final birthdayLabel = _birthday.isEmpty
        ? '選擇生日'
        : (() {
            final dt = isValidYmdDate(_birthday) ? DateTime.parse(_birthday) : null;
            if (dt == null) return _birthday;
            final now = DateTime.now();
            var y = now.year - dt.year;
            if (now.month < dt.month ||
                (now.month == dt.month && now.day < dt.day)) {
              y -= 1;
            }
            return '$_birthday ・$y 歲';
          })();

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
          _label('生日'),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadii.md),
            onPressed: _pickBirthday,
            child: Row(
              children: [
                const Icon(CupertinoIcons.calendar,
                    size: 16, color: AppColors.brandStart),
                AppGaps.w8,
                Expanded(
                  child: Text(
                    birthdayLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _birthday.isEmpty
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(CupertinoIcons.chevron_right,
                    size: 14, color: AppColors.textTertiary),
              ],
            ),
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
          _label('學校（選填）'),
          CupertinoTextField(
            controller: _school,
            placeholder: '例如：國立台灣大學',
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _isHighSchool
                ? const SizedBox(key: ValueKey('hide-dept'))
                : Padding(
                    key: const ValueKey('show-dept'),
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('科系 / 領域', required: true),
                        CupertinoTextField(
                          controller: _department,
                          placeholder: '例如：社會系、資訊管理',
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
          ),
          AppGaps.h12,
          _label('聯絡方式（選填）'),
          CupertinoTextField(
            controller: _contact,
            placeholder: 'email 或 IG',
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
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
          if (_analyzing)
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgAlt,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: const Row(
                children: [
                  CupertinoActivityIndicator(),
                  AppGaps.w10,
                  Expanded(
                    child: Text(
                      'AI 正在根據你的科系與目標分析興趣方向…',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_recommendedInterests.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(
                _isHighSchool
                    ? '從這些常見方向先試試看（可複選）：'
                    : '根據你的「${_department.text.trim()}」幫你挑了 ${_recommendedInterests.length} 個方向：',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 4),
              child: Text(
                '至少選 1 項，後續滑卡會根據你的選擇微調 Persona。',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ),
          AppGaps.h12,
          _ChipGroup(
            options: _recommendedInterests.isNotEmpty
                ? _recommendedInterests
                : interestsCatalog,
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
                fontWeight: FontWeight.w800,
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
          gradient: selected ? AppColors.brandGradient : null,
          color: selected ? null : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? const Color(0x00000000) : AppColors.border,
          ),
          boxShadow: selected ? AppColors.shadowSoft : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
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
            color: AppColors.brandStart,
            disabledColor: AppColors.borderStrong,
            borderRadius: BorderRadius.circular(AppRadii.md),
            onPressed: canNext ? onNext : null,
            child: Text(
              isLast ? '完成 ❤' : '下一步',
              style: const TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
