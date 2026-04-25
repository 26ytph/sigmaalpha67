import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/daily_questions.dart';
import '../data/roles.dart';
import '../data/subsidy_links.dart';
import '../models/models.dart';
import '../services/app_repository.dart';
import '../utils/date_util.dart';
import '../utils/hash_util.dart';
import '../utils/theme.dart';
import '../widgets/daily_question_card.dart';
import '../widgets/strike_badge.dart';

bool _intersect<T>(List<T> a, List<T> b) {
  final set = a.toSet();
  return b.any(set.contains);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.storage,
    required this.onStorageChanged,
    required this.onStartExplore,
    required this.onOpenPlan,
    required this.onOpenPersona,
    required this.onOpenChat,
    required this.onOpenSkillTranslator,
  });

  final AppStorage storage;
  final ValueChanged<AppStorage> onStorageChanged;
  final VoidCallback onStartExplore;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenPersona;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenSkillTranslator;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppStorage get storage => widget.storage;
  bool get _isStartup => storage.profile.startupInterest;

  DailyQuestion? _pickQuestion(String today) {
    final answeredToday = storage.dailyAnswers[today];
    if (answeredToday != null) {
      for (final q in dailyQuestions) {
        if (q.id == answeredToday.questionId) return q;
      }
      return null;
    }

    final likedTags = <RoleTag>{};
    for (final r in roles) {
      if (storage.explore.likedRoleIds.contains(r.id)) {
        likedTags.addAll(r.tags);
      }
    }
    final likedTagsList = likedTags.toList();

    final pool = likedTagsList.isNotEmpty
        ? dailyQuestions
              .where((q) => _intersect(q.roleTags, likedTagsList))
              .toList()
        : dailyQuestions;

    if (pool.isEmpty) {
      return dailyQuestions.isNotEmpty ? dailyQuestions.first : null;
    }
    final idx = hashStringToInt(today) % pool.length;
    return pool[idx];
  }

  Future<void> _answer(DailyQuestion q, DailyAnswerValue value) async {
    final today = toLocalDateString();
    if (storage.dailyAnswers[today] != null) return;

    final next = await AppRepository.update((prev) {
      final prevStrike = prev.strike.current;
      final last = prev.strike.lastAnsweredDate;
      final nextStrike = isYesterday(last, today) ? prevStrike + 1 : 1;

      final answers = Map<String, DailyAnswerEntry>.from(prev.dailyAnswers);
      answers[today] = DailyAnswerEntry(questionId: q.id, answer: value);

      return prev.copyWith(
        dailyAnswers: answers,
        strike: StrikeState(current: nextStrike, lastAnsweredDate: today),
      );
    });
    if (!mounted) return;
    widget.onStorageChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final p = storage.profile;
    final liked = storage.explore.likedRoleIds;
    final swiped = liked.length + storage.explore.dislikedRoleIds.length;

    final today = toLocalDateString();
    final question = _pickQuestion(today);
    final answeredToday = storage.dailyAnswers[today];

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            _topBar(p),
            AppGaps.h16,
            if (question != null) ...[
              _dailySection(question, answeredToday),
              AppGaps.h14,
            ],
            _statsRow(swiped, liked.length),
            AppGaps.h14,
            _featureGrid(),
            AppGaps.h14,
            if (_isStartup)
              _startupBanner()
            else if (liked.isNotEmpty)
              _likedRolesPreview(liked),
          ],
        ),
      ),
    );
  }

  Widget _dailySection(DailyQuestion q, DailyAnswerEntry? answered) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.flame_fill,
                size: 14,
                color: AppColors.brandStart,
              ),
              AppGaps.w6,
              const Text(
                '每日一題',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: AppColors.brandStart,
                ),
              ),
              const Spacer(),
              Text(
                answered != null
                    ? '已答 ・ streak ${storage.strike.current}'
                    : '答完 +1 streak',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          AppGaps.h10,
          DailyQuestionCard(
            question: q,
            answered: answered,
            onAnswer: (v) => _answer(q, v),
          ),
        ],
      ),
    );
  }

  Widget _topBar(UserProfile profile) {
    final letter = profile.name.isNotEmpty
        ? profile.name.characters.first
        : 'E';
    final greet = profile.name.isNotEmpty ? '哈囉，${profile.name}' : '哈囉';
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: _isStartup
                ? AppColors.startupGradient
                : AppColors.brandGradient,
            shape: BoxShape.circle,
            boxShadow: AppColors.shadowSoft,
          ),
          child: Text(
            letter,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: CupertinoColors.white,
            ),
          ),
        ),
        AppGaps.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'EmploYA!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.brandStart,
                    ),
                  ),
                  AppGaps.w8,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: _isStartup
                          ? AppColors.startupGradient
                          : AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isStartup
                              ? CupertinoIcons.flame_fill
                              : CupertinoIcons.briefcase_fill,
                          size: 9,
                          color: CupertinoColors.white,
                        ),
                        AppGaps.w4,
                        Text(
                          _isStartup ? '創業版' : '求職版',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                greet,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        StrikeBadge(strike: storage.strike.current),
      ],
    );
  }

  Widget _statsRow(int swiped, int liked) {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            label: '已滑卡',
            value: '$swiped',
            unit: '張',
            icon: CupertinoIcons.rectangle_on_rectangle,
            accent: AppColors.accentIndigo,
          ),
        ),
        AppGaps.w8,
        Expanded(
          child: _statTile(
            label: '右滑喜歡',
            value: '$liked',
            unit: '個',
            icon: CupertinoIcons.heart_fill,
            accent: AppColors.brandStart,
          ),
        ),
        AppGaps.w8,
        Expanded(
          child: _statTile(
            label: '連續答題',
            value: '${storage.strike.current}',
            unit: '天',
            icon: CupertinoIcons.flame_fill,
            accent: AppColors.accentAmber,
          ),
        ),
      ],
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          AppGaps.h8,
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          AppGaps.h4,
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureGrid() {
    final entries = [
      _FeatureEntry(
        icon: CupertinoIcons.person_crop_circle_fill,
        title: '我的檔案',
        subtitle: '個人輪廓 / 履歷',
        onTap: widget.onOpenPersona,
      ),
      _FeatureEntry(
        icon: CupertinoIcons.heart_fill,
        title: '滑卡探索',
        subtitle: '無限滑卡找方向',
        onTap: widget.onStartExplore,
      ),
      _FeatureEntry(
        icon: CupertinoIcons.doc_text_fill,
        title: '我的職涯路徑',
        subtitle: '計畫 / 路線圖 / 任務',
        onTap: widget.onOpenPlan,
      ),
      _FeatureEntry(
        icon: CupertinoIcons.text_badge_plus,
        title: '技能翻譯',
        subtitle: '把生活經驗變履歷',
        onTap: widget.onOpenSkillTranslator,
      ),
      _FeatureEntry(
        icon: CupertinoIcons.chat_bubble_2_fill,
        title: 'YAYA - AI 助理',
        subtitle: '帶交接單的對話',
        onTap: widget.onOpenChat,
      ),
    ];
    final subsidies = _isStartup ? startupSubsidies : jobSubsidies;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Text(
                _isStartup ? '青年創業補助' : '青年求職補助',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
              AppGaps.w6,
              const Text(
                '臺北市政府',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            boxShadow: AppColors.shadowSoft,
          ),
          child: Column(
            children: [
              for (var i = 0; i < subsidies.length; i++) ...[
                if (i > 0)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    height: 1,
                    color: AppColors.border,
                  ),
                _subsidyTile(subsidies[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _subsidyTile(SubsidyLink s) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _openSubsidy(s),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: _isStartup
                    ? AppColors.startupGradient
                    : AppColors.brandGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                CupertinoIcons.gift_fill,
                size: 14,
                color: CupertinoColors.white,
              ),
            ),
            AppGaps.w10,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (s.isNew) ...[
                        AppGaps.w6,
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAEEDA),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF85500B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  AppGaps.h2,
                  Text(
                    s.tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.arrow_up_right_square,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSubsidy(SubsidyLink s) async {
    final uri = Uri.tryParse(s.url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('無法開啟連結'),
          content: Text(s.url),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('好'),
            ),
          ],
        ),
      );
    }
  }

  Widget _featureTile(_FeatureEntry e) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: e.onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: AppColors.shadowSoft,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: _isStartup
                    ? AppColors.startupGradient
                    : AppColors.brandGradient,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Icon(e.icon, size: 18, color: CupertinoColors.white),
            ),
            AppGaps.w10,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  AppGaps.h4,
                  Text(
                    e.subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
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
    );
  }

  Widget _likedRolesPreview(List<RoleId> liked) {
    final likedRoles = roles
        .where((r) => liked.contains(r.id))
        .take(3)
        .toList();
    if (likedRoles.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '你最近喜歡的職位',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          AppGaps.h10,
          for (final r in likedRoles)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.heart_fill,
                    size: 14,
                    color: AppColors.brandStart,
                  ),
                  AppGaps.w8,
                  Expanded(
                    child: Text(
                      r.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    r.tags.isEmpty ? '' : '#${r.tags.first.label}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _startupBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.startupGradient,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppColors.shadow,
      ),
      child: const Row(
        children: [
          Icon(
            CupertinoIcons.flame_fill,
            color: CupertinoColors.white,
            size: 22,
          ),
          AppGaps.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '創業版本已啟用',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.white,
                  ),
                ),
                AppGaps.h4,
                Text(
                  '計畫頁主推「創業 To-do」、AI 諮詢使用創業導師模型。可在「我」切換回求職版。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: CupertinoColors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureEntry {
  const _FeatureEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}
