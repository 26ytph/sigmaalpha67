import 'package:employa/screens/plan_todos_screen.dart';
import 'package:flutter/cupertino.dart';

import 'models/models.dart';
import 'screens/chat_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/home_screen.dart';
import 'screens/plan_screen.dart';
import 'services/app_repository.dart';

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
        primaryColor: Color(0xFF18181B),
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

  @override
  Widget build(BuildContext context) {
    if (_storage == null) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final storage = _storage!;

    return CupertinoPageScaffold(
      child: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                HomeScreen(
                  onStartExplore: () => setState(() => _tabIndex = 1),
                  onOpenPlan: () => setState(() => _tabIndex = 2),
                ),
                ExploreScreen(
                  storage: storage,
                  onStorageChanged: _setStorage,
                  onGoToPlan: () => setState(() => _tabIndex = 2),
                ),
                PlanScreen(
                  storage: storage,
                  onStorageChanged: _setStorage,
                  onGoToExplore: () => setState(() => _tabIndex = 1),
                ),
                PlanTodosScreen(
                  storage: storage,
                  onStorageChanged: _setStorage,
                ),
                const ChatScreen(),
              ],
            ),
          ),
          CupertinoTabBar(
            backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
            currentIndex: _tabIndex,
            onTap: (i) => setState(() => _tabIndex = i),
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
                icon: Icon(CupertinoIcons.doc_text_fill),
                label: '計畫',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.list_bullet),
                label: 'TODO',
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
}
