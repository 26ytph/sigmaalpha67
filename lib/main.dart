import 'package:flutter/cupertino.dart';

import 'models/models.dart';
import 'screens/chat_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/persona_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/plan_todos_screen.dart';
import 'screens/skill_translator_screen.dart';
import 'services/app_repository.dart';
import 'utils/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EmployaApp());
}

class EmployaApp extends StatelessWidget {
  const EmployaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.brandStart,
        scaffoldBackgroundColor: AppColors.bg,
      ),
      home: AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppStorage? _storage;
  int _tabIndex = 0;
  // Sub-screen state for "我" tab: 0 = Persona, 1 = Skill Translator
  int _meSubIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await AppRepository.load();
    if (!mounted) return;
    setState(() => _storage = s);
  }

  void _setStorage(AppStorage s) {
    setState(() => _storage = s);
  }

  void _goTo(int i) => setState(() => _tabIndex = i);

  void _openSkillTranslator() {
    setState(() {
      _tabIndex = 2;
      _meSubIndex = 1;
    });
  }

  void _openPersona() {
    setState(() {
      _tabIndex = 2;
      _meSubIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_storage == null) {
      return const CupertinoPageScaffold(
        backgroundColor: AppColors.bg,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final storage = _storage!;

    if (!storage.isOnboarded) {
      return OnboardingScreen(
        initialProfile: storage.profile,
        initialSelfIntro: storage.persona.text,
        onCompleted: _setStorage,
      );
    }

    final mePane = _meSubIndex == 0
        ? PersonaScreen(
            storage: storage,
            onStorageChanged: _setStorage,
            onGoToExplore: () => _goTo(1),
            onGoToSkillTranslator: () => setState(() => _meSubIndex = 1),
          )
        : SkillTranslatorScreen(
            storage: storage,
            onStorageChanged: _setStorage,
          );

    final meTab = Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: AppColors.surface,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                _SubTab(
                  label: 'Persona',
                  selected: _meSubIndex == 0,
                  onTap: () => setState(() => _meSubIndex = 0),
                ),
                AppGaps.w8,
                _SubTab(
                  label: '技能翻譯',
                  selected: _meSubIndex == 1,
                  onTap: () => setState(() => _meSubIndex = 1),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: mePane),
      ],
    );

    final planPane = Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _planSubIndex,
            children: [
              PlanScreen(
                storage: storage,
                onStorageChanged: _setStorage,
                onGoToExplore: () => _goTo(1),
              ),
              PlanTodosScreen(
                storage: storage,
                onStorageChanged: _setStorage,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              _SubTab(
                label: '路線總覽',
                selected: _planSubIndex == 0,
                onTap: () => setState(() => _planSubIndex = 0),
              ),
              AppGaps.w8,
              _SubTab(
                label: '週任務',
                selected: _planSubIndex == 1,
                onTap: () => setState(() => _planSubIndex = 1),
              ),
            ],
          ),
        ),
      ],
    );

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      child: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                HomeScreen(
                  storage: storage,
                  onStartExplore: () => _goTo(1),
                  onOpenPlan: () => _goTo(3),
                  onOpenPersona: _openPersona,
                  onOpenSkillTranslator: _openSkillTranslator,
                  onOpenChat: () => _goTo(4),
                ),
                ExploreScreen(
                  storage: storage,
                  onStorageChanged: _setStorage,
                  onGoToPlan: () => _goTo(3),
                ),
                meTab,
                planPane,
                ChatScreen(storage: storage),
              ],
            ),
          ),
          CupertinoTabBar(
            backgroundColor:
                CupertinoColors.systemBackground.resolveFrom(context),
            currentIndex: _tabIndex,
            onTap: _goTo,
            activeColor: AppColors.brandStart,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.house_fill),
                label: '首頁',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.heart_fill),
                label: '探索',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.person_crop_circle_fill),
                label: '我',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.doc_text_fill),
                label: '計畫',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.chat_bubble_2_fill),
                label: 'AI',
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _planSubIndex = 0;
}

class _SubTab extends StatelessWidget {
  const _SubTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brandGradient : null,
          color: selected ? null : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadii.pill),
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
