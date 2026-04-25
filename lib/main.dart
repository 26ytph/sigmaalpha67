import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/models.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/persona_screen.dart';
import 'screens/plan_roadmap_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/plan_todos_screen.dart';
import 'screens/skill_translator_screen.dart';
import 'services/app_repository.dart';
import 'services/supabase_config.dart';
import 'utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 只有 SUPABASE_URL/ANON_KEY 都填了才初始化；否則 app 會 fall back 到本機 mock。
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  }
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
  // 預設停留在「首頁」(index 2)。
  int _tabIndex = 2;
  // 「計畫」：0 = 路線總覽, 1 = 路線圖, 2 = 週任務
  int _planSubIndex = 0;

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

  // 從首頁／其他地方需要打開技能翻譯時，push 一個 route 上去（不是 tab）。
  void _openSkillTranslatorRoute() {
    final storage = _storage;
    if (storage == null) return;
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SkillTranslatorScreen(
          storage: storage,
          onStorageChanged: _setStorage,
        ),
      ),
    );
  }

  void _openPersona() {
    setState(() {
      _tabIndex = 0;
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

    // —— 1) 沒登入 → AuthScreen ——
    if (!storage.isAuthenticated) {
      return AuthScreen(onSignedIn: _setStorage);
    }

    // —— 2) 已登入但沒 onboard → OnboardingScreen ——
    if (!storage.isOnboarded) {
      return OnboardingScreen(
        initialProfile: storage.profile,
        initialSelfIntro: storage.persona.text,
        onCompleted: _setStorage,
      );
    }

    // 「我」分頁：直接顯示 PersonaScreen；技能翻譯改為 push route。
    final meTab = PersonaScreen(
      storage: storage,
      onStorageChanged: _setStorage,
      onGoToExplore: () => _goTo(1),
      onGoToSkillTranslator: _openSkillTranslatorRoute,
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
              PlanRoadmapScreen(storage: storage),
              PlanTodosScreen(
                storage: storage,
                onStorageChanged: _setStorage,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SubTab(
                  label: '路線總覽',
                  selected: _planSubIndex == 0,
                  onTap: () => setState(() => _planSubIndex = 0),
                ),
                AppGaps.w8,
                _SubTab(
                  label: '路線圖',
                  selected: _planSubIndex == 1,
                  onTap: () => setState(() => _planSubIndex = 1),
                ),
                AppGaps.w8,
                _SubTab(
                  label: '週任務',
                  selected: _planSubIndex == 2,
                  onTap: () => setState(() => _planSubIndex = 2),
                ),
              ],
            ),
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
                // 0 — 我的檔案
                meTab,
                // 1 — 滑卡探索
                ExploreScreen(
                  storage: storage,
                  onStorageChanged: _setStorage,
                  onGoToPlan: () => _goTo(3),
                ),
                // 2 — 首頁（預設）
                HomeScreen(
                  storage: storage,
                  onStorageChanged: _setStorage,
                  onStartExplore: () => _goTo(1),
                  onOpenPlan: () => _goTo(3),
                  onOpenPersona: _openPersona,
                  onOpenChat: () => _goTo(4),
                  onOpenSkillTranslator: _openSkillTranslatorRoute,
                ),
                // 3 — 職涯路徑
                planPane,
                // 4 — AI 小助理
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
                icon: Icon(CupertinoIcons.person_crop_circle_fill),
                label: '我的檔案',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.heart_fill),
                label: '滑卡探索',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.house_fill),
                label: '首頁',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.doc_text_fill),
                label: '職涯路徑',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.chat_bubble_2_fill),
                label: 'AI 小助理',
              ),
            ],
          ),
        ],
      ),
    );
  }
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
            fontWeight: FontWeight.w800,
            color: selected ? CupertinoColors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
