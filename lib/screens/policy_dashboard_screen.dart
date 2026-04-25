import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../services/backend_api.dart';
import '../utils/theme.dart';

/// 政策端 Dashboard：去識別化的青年職涯／創業需求趨勢面板。
class PolicyDashboardScreen extends StatefulWidget {
  const PolicyDashboardScreen({super.key});

  @override
  State<PolicyDashboardScreen> createState() => _PolicyDashboardScreenState();
}

class _PolicyDashboardScreenState extends State<PolicyDashboardScreen> {
  bool _loading = true;
  String? _error;

  List<TopQuestion> _topQuestions = const [];
  List<CareerPathStat> _careerPaths = const [];
  List<SkillGap> _skillGaps = const [];
  List<StuckTask> _stuckTasks = const [];
  List<StartupNeed> _startupNeeds = const [];
  List<PolicySuggestion> _suggestions = const [];

  String _focusArea = 'career';
  bool _refreshingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        BackendApi.fetchTopQuestions(),
        BackendApi.fetchTopCareerPaths(),
        BackendApi.fetchSkillGaps(),
        BackendApi.fetchStuckTasks(),
        BackendApi.fetchStartupNeeds(),
        BackendApi.fetchPolicySuggestions(focusArea: _focusArea),
      ]);
      if (!mounted) return;
      setState(() {
        _topQuestions = results[0] as List<TopQuestion>;
        _careerPaths = results[1] as List<CareerPathStat>;
        _skillGaps = results[2] as List<SkillGap>;
        _stuckTasks = results[3] as List<StuckTask>;
        _startupNeeds = results[4] as List<StartupNeed>;
        _suggestions = results[5] as List<PolicySuggestion>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _refreshSuggestions(String focus) async {
    setState(() {
      _focusArea = focus;
      _refreshingSuggestions = true;
    });
    try {
      final list = await BackendApi.fetchPolicySuggestions(focusArea: focus);
      if (!mounted) return;
      setState(() {
        _suggestions = list;
        _refreshingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _refreshingSuggestions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
        middle: const Text(
          '政策端 Dashboard',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _loading ? null : _loadAll,
          child: const Icon(CupertinoIcons.refresh, size: 22),
        ),
      ),
      child: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: AppColors.iosOrange,
            ),
            AppGaps.h12,
            Text(
              '無法載入儀表板資料',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            AppGaps.h8,
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
            AppGaps.h16,
            CupertinoButton.filled(
              onPressed: _loadAll,
              child: const Text('重試'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _heroBanner(),
        AppGaps.h20,
        _section(
          title: '高頻問題',
          subtitle: '青年最常問的問題，依出現次數排序',
          icon: CupertinoIcons.chat_bubble_2_fill,
          accent: AppColors.brandStart,
          child: _topQuestionsList(),
        ),
        AppGaps.h16,
        _section(
          title: '熱門職涯方向',
          subtitle: '滑動探索按 ❤ 統計',
          icon: CupertinoIcons.heart_fill,
          accent: AppColors.brandMid,
          child: _careerPathsList(),
        ),
        AppGaps.h16,
        _section(
          title: '常見技能缺口',
          subtitle: '使用者問答與接手包提及',
          icon: CupertinoIcons.lightbulb_fill,
          accent: AppColors.iosOrange,
          child: _skillGapsList(),
        ),
        AppGaps.h16,
        _section(
          title: '常見卡關任務',
          subtitle: 'To-do 進度停滯週數最高',
          icon: CupertinoIcons.flag_fill,
          accent: AppColors.iosRed,
          child: _stuckTasksList(),
        ),
        AppGaps.h16,
        _section(
          title: '創業需求分布',
          subtitle: '依創業階段分群人數',
          icon: CupertinoIcons.rocket_fill,
          accent: AppColors.accentIndigo,
          child: _startupNeedsList(),
        ),
        AppGaps.h16,
        _section(
          title: 'AI 政策建議',
          subtitle: '基於目前指標自動產生（可切換主題）',
          icon: CupertinoIcons.sparkles,
          accent: AppColors.accentPurple,
          headerTrailing: _focusSegment(),
          child: _policySuggestionsList(),
        ),
        AppGaps.h20,
        const Center(
          child: Text(
            'EmploYA! Policy Dashboard ・ 去識別化彙總資料',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }

  Widget _heroBanner() {
    final totalUsers = _careerPaths.fold<int>(
      0,
      (sum, c) => sum + c.interestedUsers,
    );
    final totalQuestions = _topQuestions.fold<int>(0, (s, q) => s + q.count);
    final totalStartup = _startupNeeds.fold<int>(0, (s, n) => s + n.users);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: AppColors.aiGradient,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '青年需求趨勢總覽',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: CupertinoColors.white,
            ),
          ),
          AppGaps.h4,
          const Text(
            '本面板資料皆為去識別化彙總，僅作為政策研擬參考。',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xCCFFFFFF),
            ),
          ),
          AppGaps.h16,
          Row(
            children: [
              Expanded(child: _kpi('興趣表態', totalUsers, '人次')),
              Expanded(child: _kpi('累積提問', totalQuestions, '次')),
              Expanded(child: _kpi('創業意向', totalStartup, '人')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, int value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: Color(0xCCFFFFFF),
          ),
        ),
        AppGaps.h4,
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$value',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: CupertinoColors.white,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xCCFFFFFF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    Widget? headerTrailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              AppGaps.w10,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              ?headerTrailing,
            ],
          ),
          AppGaps.h12,
          child,
        ],
      ),
    );
  }

  Widget _topQuestionsList() {
    if (_topQuestions.isEmpty) return _emptyHint();
    return Column(
      children: [
        for (var i = 0; i < _topQuestions.length; i++)
          _rowWithBar(
            rank: i + 1,
            primary: _topQuestions[i].question,
            secondary: '出現 ${_topQuestions[i].count} 次',
            badge: _topQuestions[i].urgency,
            badgeColor: _urgencyColor(_topQuestions[i].urgency),
            value: _topQuestions[i].count,
            maxValue: _topQuestions.first.count,
            barColor: AppColors.brandStart,
            isLast: i == _topQuestions.length - 1,
          ),
      ],
    );
  }

  Widget _careerPathsList() {
    if (_careerPaths.isEmpty) return _emptyHint();
    return Column(
      children: [
        for (var i = 0; i < _careerPaths.length; i++)
          _rowWithBar(
            rank: i + 1,
            primary: _careerPaths[i].label,
            secondary: '${_careerPaths[i].interestedUsers} 人對此職涯方向有興趣',
            value: _careerPaths[i].interestedUsers,
            maxValue: _careerPaths.first.interestedUsers,
            barColor: AppColors.brandMid,
            isLast: i == _careerPaths.length - 1,
          ),
      ],
    );
  }

  Widget _skillGapsList() {
    if (_skillGaps.isEmpty) return _emptyHint();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final g in _skillGaps)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.iosOrange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: AppColors.iosOrange.withValues(alpha: 0.3),
              ),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: g.skill,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: '  ${g.mentions}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.iosOrange,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _stuckTasksList() {
    if (_stuckTasks.isEmpty) return _emptyHint();
    return Column(
      children: [
        for (var i = 0; i < _stuckTasks.length; i++)
          _rowWithBar(
            rank: i + 1,
            primary: _stuckTasks[i].title,
            secondary: '${_stuckTasks[i].stuckUsers} 人卡關 ・ ${_stuckTasks[i].taskKey}',
            value: _stuckTasks[i].stuckUsers,
            maxValue: _stuckTasks.first.stuckUsers,
            barColor: AppColors.iosRed,
            isLast: i == _stuckTasks.length - 1,
          ),
      ],
    );
  }

  Widget _startupNeedsList() {
    if (_startupNeeds.isEmpty) return _emptyHint();
    final maxUsers = _startupNeeds.map((n) => n.users).reduce(
          (a, b) => a > b ? a : b,
        );
    return Column(
      children: [
        for (var i = 0; i < _startupNeeds.length; i++)
          _rowWithBar(
            rank: i + 1,
            primary: _startupNeeds[i].stage,
            secondary: '${_startupNeeds[i].users} 位青年處於此階段',
            value: _startupNeeds[i].users,
            maxValue: maxUsers,
            barColor: AppColors.accentIndigo,
            isLast: i == _startupNeeds.length - 1,
          ),
      ],
    );
  }

  Widget _focusSegment() {
    return CupertinoSlidingSegmentedControl<String>(
      groupValue: _focusArea,
      backgroundColor: AppColors.surfaceMuted,
      thumbColor: AppColors.surface,
      padding: const EdgeInsets.all(2),
      onValueChanged: (v) {
        if (v == null || v == _focusArea) return;
        _refreshSuggestions(v);
      },
      children: const {
        'career': Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            '職涯',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        'startup': Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            '創業',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        'skill': Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            '技能',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      },
    );
  }

  Widget _policySuggestionsList() {
    if (_refreshingSuggestions) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (_suggestions.isEmpty) return _emptyHint();
    return Column(
      children: [
        for (var i = 0; i < _suggestions.length; i++) ...[
          _suggestionCard(_suggestions[i], index: i + 1),
          if (i < _suggestions.length - 1) AppGaps.h10,
        ],
      ],
    );
  }

  Widget _suggestionCard(PolicySuggestion s, {required int index}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.bgAlt.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: AppColors.aiGradient,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  '#$index',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
              AppGaps.w8,
              Expanded(
                child: Text(
                  s.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          AppGaps.h8,
          Text(
            s.rationale,
            style: const TextStyle(
              fontSize: 12,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
          if (s.proposedActions.isNotEmpty) ...[
            AppGaps.h10,
            const Text(
              '建議行動',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: AppColors.accentPurple,
              ),
            ),
            AppGaps.h4,
            for (final a in s.proposedActions)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5, right: 6),
                      child: Icon(
                        CupertinoIcons.checkmark_alt,
                        size: 12,
                        color: AppColors.accentPurple,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        a,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _rowWithBar({
    required int rank,
    required String primary,
    required String secondary,
    required int value,
    required int maxValue,
    required Color barColor,
    String? badge,
    Color? badgeColor,
    bool isLast = false,
  }) {
    final ratio = maxValue == 0 ? 0.0 : value / maxValue;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              AppGaps.w8,
              Expanded(
                child: Text(
                  primary,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (badge != null && badge.isNotEmpty) ...[
                AppGaps.w6,
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? AppColors.brandStart)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: badgeColor ?? AppColors.brandStart,
                    ),
                  ),
                ),
              ],
            ],
          ),
          AppGaps.h4,
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: SizedBox(
                      height: 6,
                      child: Stack(
                        children: [
                          const ColoredBox(color: AppColors.surfaceMuted),
                          FractionallySizedBox(
                            widthFactor: ratio.clamp(0.04, 1.0),
                            child: ColoredBox(color: barColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AppGaps.w8,
                Text(
                  secondary,
                  style: const TextStyle(
                    fontSize: 11,
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

  Widget _emptyHint() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text(
        '尚無資料。',
        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
      ),
    );
  }

  Color _urgencyColor(String u) {
    switch (u) {
      case '高':
        return AppColors.iosRed;
      case '中高':
        return AppColors.iosOrange;
      case '中':
        return AppColors.brandStart;
      default:
        return AppColors.textTertiary;
    }
  }
}
