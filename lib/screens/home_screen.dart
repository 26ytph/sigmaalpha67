import 'package:flutter/cupertino.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onStartExplore,
    required this.onOpenPlan,
  });

  final VoidCallback onStartExplore;
  final VoidCallback onOpenPlan;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: CupertinoColors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0x1A000000)),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 50,
                      offset: Offset(0, 18),
                      color: Color(0x1F020617),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Color(0x5938BDF8), Color(0x40F472B6)],
                            ),
                            border: Border.all(color: Color(0x1A000000)),
                          ),
                          child: const Text(
                            'e',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('職涯探索', style: TextStyle(fontSize: 13, color: Color(0xFF52525B))),
                            Text(
                              'EmploYA!',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.4),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      '用滑卡探索你的興趣，\n生成一份可執行的職涯計畫',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '先像交友軟體一樣左右滑，選出你感興趣的職位；接著根據結果，用假 AI '
                      '生成一份 4–8 週的行動清單，並每天回答一題職涯小問題累積 streak。',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.55,
                        color: Color(0xFF3F3F46),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          onPressed: onStartExplore,
                          child: const Text('開始興趣探索'),
                        ),
                        const SizedBox(height: 10),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: CupertinoColors.white,
                          onPressed: onOpenPlan,
                          child: const Text(
                            '直接看職涯計畫',
                            style: TextStyle(color: Color(0xFF18181B), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '無登入・資料只存在本機',
                      style: TextStyle(fontSize: 13, color: Color(0xFF52525B)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
