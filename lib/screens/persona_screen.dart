import 'package:flutter/cupertino.dart';

import '../data/interests_catalog.dart';
import '../data/skills_catalog.dart';
import '../models/models.dart';
import '../services/app_repository.dart';
import '../utils/theme.dart';
import '../widgets/searchable_picker_sheet.dart';
import 'resume_export_screen.dart';

/// 履歷風格的「我」頁。各段（學歷／經歷／技能／興趣）皆可逐項點擊修改／刪除，
/// 也可從段落上方的「+ 新增」加入新項目。整體採 iOS Settings.app 的群組式 list 風格，
/// 自介由使用者自己填寫（不再由 AI 生成），留空就維持空。
class PersonaScreen extends StatefulWidget {
  const PersonaScreen({
    super.key,
    required this.storage,
    required this.onStorageChanged,
    required this.onGoToExplore,
    required this.onGoToSkillTranslator,
  });

  final AppStorage storage;
  final ValueChanged<AppStorage> onStorageChanged;
  final VoidCallback onGoToExplore;
  final VoidCallback onGoToSkillTranslator;

  @override
  State<PersonaScreen> createState() => _PersonaScreenState();
}

class _PersonaScreenState extends State<PersonaScreen> {
  bool _summaryEditing = false;
  late TextEditingController _summary;

  // Inline 編輯狀態
  String? _activeEdit; // '<section>:<index>' 或 '<section>:new'
  String? _personalEdit; // 'name' | 'school' | 'age' | 'location' | 'contact'

  @override
  void initState() {
    super.initState();
    _summary = TextEditingController(text: widget.storage.persona.text);
  }

  @override
  void didUpdateWidget(covariant PersonaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_summaryEditing &&
        oldWidget.storage.persona.text != widget.storage.persona.text) {
      _summary.text = widget.storage.persona.text;
    }
  }

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  Future<AppStorage> _persist(AppStorage Function(AppStorage prev) fn) async {
    final next = await AppRepository.update(fn);
    if (mounted) widget.onStorageChanged(next);
    return next;
  }

  Future<void> _saveSummary() async {
    final text = _summary.text.trim();
    await _persist((prev) {
      final updated = prev.persona.copyWith(
        text: text,
        userEdited: true,
        lastUpdated: DateTime.now().toIso8601String(),
      );
      return prev.copyWith(persona: updated);
    });
    await AppRepository.syncPersonaText(text);
    setState(() => _summaryEditing = false);
  }

  Future<void> _toggleStartupMode() async {
    final go = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(
          widget.storage.profile.startupInterest ? '切換回我要求職？' : '切換為我要創業？',
        ),
        content: Text(
          widget.storage.profile.startupInterest
              ? '首頁、計畫與 AI 諮詢將回到一般求職情境。'
              : '首頁主推創業 To-do 與資源連結，AI 諮詢會優先用創業導師模型。',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確認切換'),
          ),
        ],
      ),
    );
    if (go != true) return;
    final next = await _persist((prev) {
      final p = prev.profile.copyWith(
        startupInterest: !prev.profile.startupInterest,
      );
      return prev.copyWith(profile: p);
    });
    await AppRepository.syncProfile(next.profile);
  }

  // —— 列表編輯：教育／經歷／技能／興趣 ——

  Future<void> _saveListItem({
    required String section,
    required int index, // -1 表示新增
    required String value,
  }) async {
    final v = value.trim();
    final next = await _persist((prev) {
      var profile = prev.profile;
      var persona = prev.persona;
      switch (section) {
        case 'experience':
          final list = [...profile.experiences];
          if (index < 0) {
            if (v.isNotEmpty) list.add(v);
          } else if (v.isEmpty) {
            list.removeAt(index);
          } else {
            list[index] = v;
          }
          profile = profile.copyWith(experiences: list);
          break;
        case 'skill':
          final list = [...persona.strengths];
          if (index < 0) {
            if (v.isNotEmpty) list.add(v);
          } else if (v.isEmpty) {
            list.removeAt(index);
          } else {
            list[index] = v;
          }
          persona = persona.copyWith(
            strengths: list,
            userEdited: true,
            lastUpdated: DateTime.now().toIso8601String(),
          );
          break;
        case 'interest':
          final list = [...profile.interests];
          if (index < 0) {
            if (v.isNotEmpty) list.add(v);
          } else if (v.isEmpty) {
            list.removeAt(index);
          } else {
            list[index] = v;
          }
          profile = profile.copyWith(interests: list);
          persona = persona.copyWith(
            mainInterests: list.take(4).toList(),
            userEdited: true,
            lastUpdated: DateTime.now().toIso8601String(),
          );
          break;
      }
      return prev.copyWith(profile: profile, persona: persona);
    });
    await AppRepository.syncProfile(next.profile);
    setState(() => _activeEdit = null);
  }

  Future<void> _savePersonalField(String field, String value) async {
    final v = value.trim();
    final next = await _persist((prev) {
      var p = prev.profile;
      switch (field) {
        case 'name':
          p = p.copyWith(name: v);
          break;
        case 'school':
          p = p.copyWith(school: v);
          break;
        case 'birthday':
          // 只接受合法 YYYY-MM-DD；其他輸入忽略。
          if (v.isEmpty || isValidYmdDate(v)) {
            p = p.copyWith(birthday: v);
          }
          break;
        case 'location':
          p = p.copyWith(location: v);
          break;
        case 'email':
          p = p.copyWith(email: v);
          break;
        case 'phone':
          p = p.copyWith(phone: v);
          break;
      }
      return prev.copyWith(profile: p);
    });
    await AppRepository.syncProfile(next.profile);
    setState(() => _personalEdit = null);
  }

  // —— 學歷：結構化編輯（學校／科系／年級）——
  Future<void> _editEducation({EducationEntry? initial, int? index}) async {
    final result = await showCupertinoModalPopup<EducationEntry?>(
      context: context,
      builder: (ctx) => _EducationEditSheet(initial: initial),
    );
    if (result == null) return; // user cancelled
    final next = await _persist((prev) {
      final list = [...prev.profile.educationItems];
      if (result.isEmpty) {
        if (index != null && index >= 0 && index < list.length) {
          list.removeAt(index);
        }
      } else if (index == null) {
        list.add(result);
      } else {
        list[index] = result;
      }
      return prev.copyWith(profile: prev.profile.copyWith(educationItems: list));
    });
    await AppRepository.syncProfile(next.profile);
  }

  Future<void> _confirmDeleteEducation(int index) async {
    final list = widget.storage.profile.educationItems;
    if (index < 0 || index >= list.length) return;
    final go = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('移除「${list[index].displayLine}」？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (go != true) return;
    final next = await _persist((prev) {
      final l = [...prev.profile.educationItems]..removeAt(index);
      return prev.copyWith(profile: prev.profile.copyWith(educationItems: l));
    });
    await AppRepository.syncProfile(next.profile);
  }

  // —— 從字典（fixed list）新增技能／興趣 ——
  Future<void> _addFromCatalog(String section) async {
    final excluded = section == 'skill'
        ? widget.storage.persona.strengths.toSet()
        : widget.storage.profile.interests.toSet();
    final picked = await showSearchablePickerSheet(
      context: context,
      title: section == 'skill' ? '新增技能' : '新增興趣',
      catalog: section == 'skill' ? skillsCatalog : interestsCatalog,
      excluded: excluded,
    );
    if (picked == null) return;
    await _saveListItem(section: section, index: -1, value: picked);
  }

  Future<void> _confirmRemoveCatalogItem(String section, int index) async {
    final list = section == 'skill'
        ? widget.storage.persona.strengths
        : widget.storage.profile.interests;
    if (index < 0 || index >= list.length) return;
    final label = list[index];
    final go = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('移除「$label」？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (go != true) return;
    await _saveListItem(section: section, index: index, value: '');
  }

  void _openResume() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => ResumeExportScreen(
          profile: widget.storage.profile,
          persona: widget.storage.persona,
        ),
      ),
    );
  }

  Future<void> _pickBirthday() async {
    final cur = widget.storage.profile.birthday;
    DateTime initial = DateTime(2003, 1, 1);
    final parsed = cur.isNotEmpty ? DateTime.tryParse(cur) : null;
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
    await _savePersonalField('birthday', s);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.storage.profile;
    final persona = widget.storage.persona;
    final isStartup = profile.startupInterest;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _heroCard(profile, isStartup),
            AppGaps.h20,
            _summarySection(persona),
            AppGaps.h20,
            _personalInfoSection(profile),
            AppGaps.h20,
            _EducationSection(
              items: profile.educationItems,
              onAdd: () => _editEducation(),
              onEdit: (i) => _editEducation(
                initial: profile.educationItems[i],
                index: i,
              ),
              onDelete: _confirmDeleteEducation,
            ),
            AppGaps.h20,
            _ListSection(
              icon: CupertinoIcons.briefcase_fill,
              accentColor: AppColors.iosBlue,
              title: '經歷',
              items: profile.experiences,
              section: 'experience',
              chips: false,
              activeEdit: _activeEdit,
              onSetActive: (s) => setState(() => _activeEdit = s),
              onSave: _saveListItem,
              placeholder: '例如：系上迎新籌備、課內質化研究訪談',
            ),
            AppGaps.h20,
            _PickerSection(
              icon: CupertinoIcons.bolt_fill,
              accentColor: AppColors.iosOrange,
              title: '技能',
              items: persona.strengths,
              onAdd: () => _addFromCatalog('skill'),
              onRemove: (i) => _confirmRemoveCatalogItem('skill', i),
              footer: _quickEntry(
                label: '從「技能翻譯」一鍵生成',
                onTap: widget.onGoToSkillTranslator,
              ),
            ),
            AppGaps.h20,
            _PickerSection(
              icon: CupertinoIcons.heart_fill,
              accentColor: AppColors.brandStart,
              title: '興趣',
              items: profile.interests,
              onAdd: () => _addFromCatalog('interest'),
              onRemove: (i) => _confirmRemoveCatalogItem('interest', i),
              footer: _quickEntry(
                label: '到「探索」滑卡更新興趣',
                onTap: widget.onGoToExplore,
              ),
            ),
            AppGaps.h20,
            _modeSwitchRow(isStartup),
            AppGaps.h14,
            if (persona.skillGaps.isNotEmpty) _gapsHint(persona),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(UserProfile profile, bool isStartup) {
    final letter = profile.name.isNotEmpty
        ? profile.name.characters.first
        : '?';
    final subline = [
      profile.department,
      profile.grade,
      profile.currentStage,
    ].where((s) => s.isNotEmpty).join(' ・ ');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: isStartup
            ? AppColors.startupGradient
            : AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        boxShadow: AppColors.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CupertinoColors.white.withValues(alpha: 0.7),
                    width: 2,
                  ),
                ),
                child: Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: CupertinoColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: isStartup
                          ? const Color(0xFFFE8A4F)
                          : AppColors.brandStart,
                    ),
                  ),
                ),
              ),
              AppGaps.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isStartup
                                ? CupertinoIcons.flame_fill
                                : CupertinoIcons.briefcase_fill,
                            size: 10,
                            color: CupertinoColors.white,
                          ),
                          AppGaps.w4,
                          Text(
                            isStartup ? '我要創業' : '我要求職',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppGaps.h6,
                    Text(
                      profile.name.isNotEmpty ? profile.name : '尚未命名',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: CupertinoColors.white,
                      ),
                    ),
                    if (subline.isNotEmpty) ...[
                      AppGaps.h2,
                      Text(
                        subline,
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          AppGaps.h16,
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 11),
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(AppRadii.md),
              onPressed: _openResume,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.cloud_download_fill,
                    size: 14,
                    color: isStartup
                        ? const Color(0xFFFE8A4F)
                        : AppColors.brandStart,
                  ),
                  AppGaps.w6,
                  Text(
                    '下載履歷 PDF',
                    style: TextStyle(
                      color: isStartup
                          ? const Color(0xFFFE8A4F)
                          : AppColors.brandStart,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summarySection(Persona persona) {
    return _IosSection(
      header: '自介',
      child: _summaryEditing
          ? Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CupertinoTextField(
                    controller: _summary,
                    minLines: 5,
                    maxLines: 12,
                    placeholder: '寫一段自我介紹，讓 EmploYA 更懂你 ❤',
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.border),
                    ),
                  ),
                  AppGaps.h10,
                  Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        onPressed: () {
                          setState(() {
                            _summaryEditing = false;
                            _summary.text = widget.storage.persona.text;
                          });
                        },
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        color: AppColors.iosBlue,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        onPressed: _saveSummary,
                        child: const Text(
                          '儲存',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _summaryEditing = true),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: persona.text.isEmpty
                          ? const Text(
                              '寫一段自我介紹，讓 EmploYA 更懂你 ❤',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textTertiary,
                              ),
                            )
                          : Text(
                              persona.text,
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 1.65,
                                color: AppColors.textPrimary,
                              ),
                            ),
                    ),
                    AppGaps.w8,
                    const Icon(
                      CupertinoIcons.pencil,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _personalInfoSection(UserProfile p) {
    return _IosSection(
      header: '基本資料',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _IosListRow(
            label: '姓名',
            value: p.name,
            placeholder: '請輸入本名',
            active: _personalEdit == 'name',
            onActivate: () => setState(() => _personalEdit = 'name'),
            onCancel: () => setState(() => _personalEdit = null),
            onSave: (v) => _savePersonalField('name', v),
          ),
          const _IosDivider(),
          _IosListRow(
            label: '學校',
            value: p.school,
            placeholder: '例如：國立台灣大學',
            active: _personalEdit == 'school',
            onActivate: () => setState(() => _personalEdit = 'school'),
            onCancel: () => setState(() => _personalEdit = null),
            onSave: (v) => _savePersonalField('school', v),
          ),
          const _IosDivider(),
          _IosBirthdayRow(
            birthday: p.birthday,
            age: p.age,
            onPick: _pickBirthday,
          ),
          const _IosDivider(),
          _IosListRow(
            label: '居住地',
            value: p.location,
            placeholder: '例如：台北',
            active: _personalEdit == 'location',
            onActivate: () => setState(() => _personalEdit = 'location'),
            onCancel: () => setState(() => _personalEdit = null),
            onSave: (v) => _savePersonalField('location', v),
          ),
          const _IosDivider(),
          _IosListRow(
            label: 'Email',
            value: p.email,
            placeholder: 'you@example.com',
            active: _personalEdit == 'email',
            onActivate: () => setState(() => _personalEdit = 'email'),
            onCancel: () => setState(() => _personalEdit = null),
            onSave: (v) => _savePersonalField('email', v),
          ),
          const _IosDivider(),
          _IosListRow(
            label: '電話',
            value: p.phone,
            placeholder: '0912-345-678',
            active: _personalEdit == 'phone',
            onActivate: () => setState(() => _personalEdit = 'phone'),
            onCancel: () => setState(() => _personalEdit = null),
            onSave: (v) => _savePersonalField('phone', v),
          ),
        ],
      ),
    );
  }

  Widget _quickEntry({required String label, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            children: [
              const Icon(
                CupertinoIcons.arrow_right_circle,
                size: 14,
                color: AppColors.iosBlue,
              ),
              AppGaps.w6,
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.iosBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeSwitchRow(bool isStartup) {
    return _IosSection(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _toggleStartupMode,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isStartup
                      ? AppColors.startupGradient
                      : AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  isStartup
                      ? CupertinoIcons.briefcase_fill
                      : CupertinoIcons.flame_fill,
                  color: CupertinoColors.white,
                  size: 14,
                ),
              ),
              AppGaps.w10,
              Expanded(
                child: Text(
                  isStartup ? '切回我要求職' : '我要創業 🔥❤',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gapsHint(Persona persona) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.flag,
            size: 14,
            color: AppColors.textTertiary,
          ),
          AppGaps.w6,
          Expanded(
            child: Text(
              '可以再補強：${persona.skillGaps.join('、')}',
              style: const TextStyle(
                fontSize: 12,
                height: 1.55,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// iOS Settings 風格的群組區塊：白色 inset 卡 + 上方標題（小寫灰）
class _IosSection extends StatelessWidget {
  const _IosSection({this.header, this.trailing, required this.child});

  final String? header;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    header!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _IosDivider extends StatelessWidget {
  const _IosDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16),
      height: 1,
      color: AppColors.border,
    );
  }
}

/// 一行一筆的 iOS 列：點擊後內嵌變成 TextField
/// 生日列：點擊跳出 CupertinoDatePicker；右側顯示「YYYY-MM-DD ・N 歲」。
class _IosBirthdayRow extends StatelessWidget {
  const _IosBirthdayRow({
    required this.birthday,
    required this.age,
    required this.onPick,
  });

  final String birthday;
  final int? age;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final hasBirthday = birthday.isNotEmpty && isValidYmdDate(birthday);
    final right = hasBirthday
        ? (age != null ? '$birthday ・$age 歲' : birthday)
        : '選擇生日';

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPick,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            const SizedBox(
              width: 88,
              child: Text(
                '生日',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                right,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 15,
                  color: hasBirthday
                      ? AppColors.textSecondary
                      : AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(CupertinoIcons.chevron_right,
                size: 14, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _IosListRow extends StatefulWidget {
  const _IosListRow({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.active,
    required this.onActivate,
    required this.onCancel,
    required this.onSave,
  });

  final String label;
  final String value;
  final String placeholder;
  final bool active;
  final VoidCallback onActivate;
  final VoidCallback onCancel;
  final ValueChanged<String> onSave;

  @override
  State<_IosListRow> createState() => _IosListRowState();
}

class _IosListRowState extends State<_IosListRow> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _IosListRow old) {
    super.didUpdateWidget(old);
    if (!widget.active && _ctl.text != widget.value) {
      _ctl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.active) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            SizedBox(
              width: 88,
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: CupertinoTextField(
                controller: _ctl,
                autofocus: true,
                placeholder: widget.placeholder,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: AppColors.iosBlue),
                ),
                onSubmitted: (v) => widget.onSave(v),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              onPressed: widget.onCancel,
              child: const Text(
                '取消',
                style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              onPressed: () => widget.onSave(_ctl.text),
              child: const Text(
                '儲存',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.iosBlue,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: widget.onActivate,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            SizedBox(
              width: 88,
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                widget.value.isEmpty ? widget.placeholder : widget.value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 15,
                  color: widget.value.isEmpty
                      ? AppColors.textTertiary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 學歷區塊：列出每筆 EducationEntry，點擊整列 → 結構化 sheet 編輯。
class _EducationSection extends StatelessWidget {
  const _EducationSection({
    required this.items,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<EducationEntry> items;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;

  static const _accent = AppColors.accentIndigo;

  @override
  Widget build(BuildContext context) {
    return _IosSection(
      header: '學歷',
      trailing: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        onPressed: onAdd,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.add_circled_solid, size: 14, color: _accent),
            AppGaps.w4,
            Text('新增',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _accent,
                )),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: items.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '點右上角「+ 新增」加入第一筆學歷（學校／科系／年級）',
                  style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _EducationRow(
                        index: i,
                        entry: items[i],
                        onEdit: () => onEdit(i),
                        onDelete: () => onDelete(i),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _EducationRow extends StatelessWidget {
  const _EducationRow({
    required this.index,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final EducationEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accentIndigo.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentIndigo,
                    ),
                  ),
                ),
                AppGaps.w8,
                Expanded(
                  child: Text(
                    '學歷 ${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  onPressed: onEdit,
                  child: const Text(
                    '編輯',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentIndigo,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  onPressed: onDelete,
                  child: const Text(
                    '刪除',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.iosRed,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EduSubItem(label: '學校', value: entry.school),
                _EduSubItem(label: '科系', value: entry.department),
                _EduSubItem(label: '年級', value: entry.grade),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EduSubItem extends StatelessWidget {
  const _EduSubItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    value.isEmpty ? AppColors.textTertiary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 學歷編輯 sheet：分別輸入學校／科系／年級。
class _EducationEditSheet extends StatefulWidget {
  const _EducationEditSheet({this.initial});
  final EducationEntry? initial;

  @override
  State<_EducationEditSheet> createState() => _EducationEditSheetState();
}

class _EducationEditSheetState extends State<_EducationEditSheet> {
  late final TextEditingController _school;
  late final TextEditingController _department;
  String _grade = '';

  static const _gradeOptions = [
    '高中', '大一', '大二', '大三', '大四', '研究生', '畢業',
  ];

  @override
  void initState() {
    super.initState();
    _school = TextEditingController(text: widget.initial?.school ?? '');
    _department = TextEditingController(text: widget.initial?.department ?? '');
    _grade = widget.initial?.grade ?? '';
  }

  @override
  void dispose() {
    _school.dispose();
    _department.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20, 12, 20,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4D4D8),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
              AppGaps.h12,
              const Text(
                '編輯學歷',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              AppGaps.h12,
              const Text('學校',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  )),
              AppGaps.h6,
              CupertinoTextField(
                controller: _school,
                placeholder: '例如：國立台灣大學',
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              AppGaps.h12,
              const Text('科系',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  )),
              AppGaps.h6,
              CupertinoTextField(
                controller: _department,
                placeholder: '例如：社會系；高中可留空',
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              AppGaps.h12,
              const Text('年級',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  )),
              AppGaps.h6,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in _gradeOptions)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: () => setState(() => _grade = g),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: _grade == g
                              ? AppColors.brandGradient
                              : null,
                          color: _grade == g
                              ? null
                              : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          g,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _grade == g
                                ? CupertinoColors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              AppGaps.h20,
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  AppGaps.w8,
                  Expanded(
                    flex: 2,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: AppColors.brandStart,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      onPressed: () {
                        final entry = EducationEntry(
                          school: _school.text.trim(),
                          department: _department.text.trim(),
                          grade: _grade,
                        );
                        Navigator.of(context).pop(entry);
                      },
                      child: const Text(
                        '儲存',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 字典型選擇區塊：技能 / 興趣專用。
/// 不允許自由輸入；只能從 `catalog`（由父層透過 `onAdd` 提供的 picker）挑。
/// 點現有 chip 會詢問是否刪除。
class _PickerSection extends StatelessWidget {
  const _PickerSection({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.items,
    required this.onAdd,
    required this.onRemove,
    this.footer,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final List<String> items;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return _IosSection(
      header: title,
      trailing: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        onPressed: onAdd,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.add_circled_solid,
                size: 14, color: accentColor),
            AppGaps.w4,
            Text(
              '新增',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '點右上角「+ 新增」從清單中挑 $title',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < items.length; i++)
                    _Chip(
                      label: items[i],
                      accent: accentColor,
                      onTap: () => onRemove(i),
                    ),
                ],
              ),
            ?footer,
          ],
        ),
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.items,
    required this.section,
    required this.chips,
    required this.activeEdit,
    required this.onSetActive,
    required this.onSave,
    required this.placeholder,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final List<String> items;
  final String section;
  final bool chips;
  final String? activeEdit;
  final ValueChanged<String?> onSetActive;
  final Future<void> Function({
    required String section,
    required int index,
    required String value,
  })
  onSave;
  final String placeholder;

  bool get _addingNew => activeEdit == '$section:new';

  @override
  Widget build(BuildContext context) {
    return _IosSection(
      header: title,
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: () => onSetActive('$section:new'),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.add_circled_solid,
              size: 14,
              color: AppColors.iosBlue,
            ),
            AppGaps.w4,
            Text(
              '新增',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.iosBlue,
              ),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_addingNew)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _InlineEditRow(
                  initial: '',
                  placeholder: placeholder,
                  onCancel: () => onSetActive(null),
                  onSave: (v) => onSave(section: section, index: -1, value: v),
                  onDelete: null,
                  accent: accentColor,
                ),
              ),
            if (items.isEmpty && !_addingNew)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '點右上角「+ 新增」加入第一筆 $title',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
              )
            else if (chips)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < items.length; i++)
                    if (activeEdit == '$section:$i')
                      SizedBox(
                        width: double.infinity,
                        child: _InlineEditRow(
                          initial: items[i],
                          placeholder: placeholder,
                          onCancel: () => onSetActive(null),
                          onSave: (v) =>
                              onSave(section: section, index: i, value: v),
                          onDelete: () =>
                              onSave(section: section, index: i, value: ''),
                          accent: accentColor,
                        ),
                      )
                    else
                      _Chip(
                        label: items[i],
                        accent: accentColor,
                        onTap: () => onSetActive('$section:$i'),
                      ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: activeEdit == '$section:$i'
                          ? _InlineEditRow(
                              initial: items[i],
                              placeholder: placeholder,
                              onCancel: () => onSetActive(null),
                              onSave: (v) =>
                                  onSave(section: section, index: i, value: v),
                              onDelete: () =>
                                  onSave(section: section, index: i, value: ''),
                              accent: accentColor,
                            )
                          : _Row(
                              text: items[i],
                              accent: accentColor,
                              onTap: () => onSetActive('$section:$i'),
                            ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.accent, required this.onTap});

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
            AppGaps.w6,
            Icon(
              CupertinoIcons.pencil,
              size: 11,
              color: accent.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.text, required this.accent, required this.onTap});

  final String text;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            AppGaps.w10,
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.pencil,
              size: 13,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineEditRow extends StatefulWidget {
  const _InlineEditRow({
    required this.initial,
    required this.placeholder,
    required this.onCancel,
    required this.onSave,
    required this.onDelete,
    required this.accent,
  });

  final String initial;
  final String placeholder;
  final VoidCallback onCancel;
  final ValueChanged<String> onSave;
  final VoidCallback? onDelete;
  final Color accent;

  @override
  State<_InlineEditRow> createState() => _InlineEditRowState();
}

class _InlineEditRowState extends State<_InlineEditRow> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: widget.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          CupertinoTextField(
            controller: _ctl,
            placeholder: widget.placeholder,
            autofocus: true,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: AppColors.border),
            ),
            onSubmitted: (v) => widget.onSave(v),
          ),
          AppGaps.h8,
          Row(
            children: [
              if (widget.onDelete != null)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  onPressed: widget.onDelete,
                  child: const Text(
                    '刪除',
                    style: TextStyle(
                      color: AppColors.iosRed,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              const Spacer(),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                onPressed: widget.onCancel,
                child: const Text(
                  '取消',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              AppGaps.w8,
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                color: AppColors.iosBlue,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                onPressed: () => widget.onSave(_ctl.text),
                child: const Text(
                  '儲存',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
