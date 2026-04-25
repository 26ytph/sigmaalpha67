import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/app_repository.dart';
import '../services/supabase_config.dart';
import '../utils/theme.dart';

/// 登入／註冊（demo 用 mock：任何合法 email + 4+ 字密碼即可通過）。
/// 主要目的是給 onboarding 加一道帳號門。
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onSignedIn});

  final ValueChanged<AppStorage> onSignedIn;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  static final _emailRe = RegExp(r'^[\w.+\-]+@([\w-]+\.)+[\w-]{2,}$');

  bool get _canSubmit {
    return _emailRe.hasMatch(_email.text.trim()) &&
        _password.text.length >= 4 &&
        !_busy;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final email = _email.text.trim();
    final password = _password.text;

    String resolvedEmail = email;
    try {
      if (SupabaseConfig.isConfigured) {
        // 真的 Supabase 流程
        final auth = Supabase.instance.client.auth;
        final response = _register
            ? await auth.signUp(email: email, password: password)
            : await auth.signInWithPassword(email: email, password: password);
        final user = response.user;
        if (user == null) {
          throw const AuthException('沒有拿到使用者資訊');
        }
        resolvedEmail = user.email ?? email;
      } else {
        // 沒設定 Supabase → mock 流程，留時間讓 UI 顯示 loading
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '無法連線：$e';
      });
      return;
    }

    final acc = UserAccount(
      email: resolvedEmail,
      signedInAt: DateTime.now().toIso8601String(),
    );
    var next = await AppRepository.update(
      (prev) => prev.copyWith(account: acc),
    );
    // 登入成功後去後端撈既有 profile / persona —— 如果這個 user 之前
    // 已經 onboard 過，下次登入就不會被擋在 OnboardingScreen 重填一次。
    try {
      next = await AppRepository.hydrateFromBackend();
      // hydrateFromBackend 會覆寫 account（因為 load 是讀本機的最新值），
      // 所以這裡再保險一次寫進當前登入 email。
      next = await AppRepository.update(
        (prev) => prev.copyWith(account: acc),
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onSignedIn(next);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      child: Stack(
        children: [
          // 背景：漸層 + 散落愛心裝飾
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.bg,
                    AppColors.bgAlt,
                    AppColors.bgPeach,
                  ],
                ),
              ),
            ),
          ),
          ..._floatingHearts(size),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _logo(),
                      AppGaps.h20,
                      _glassCard(),
                      AppGaps.h12,
                      Center(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _register = !_register;
                                    _error = null;
                                  }),
                          child: Text(
                            _register
                                ? '已經有帳號了？來登入吧'
                                : '還沒帳號？建立一個一起出發',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandStart,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logo() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.heartGradient,
            shape: BoxShape.circle,
            boxShadow: AppColors.shadow,
          ),
          child: const Icon(
            CupertinoIcons.heart_fill,
            size: 42,
            color: CupertinoColors.white,
          ),
        ),
        AppGaps.h12,
        const Text(
          'EmploYA!',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: AppColors.brandStart,
          ),
        ),
        AppGaps.h4,
        Text(
          _register ? '一起把未來談一場戀愛' : '回來啦？想你了',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _glassCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppColors.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _register ? '建立帳號' : '登入',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppColors.textPrimary,
            ),
          ),
          AppGaps.h4,
          Text(
            _register
                ? '輸入 email 跟一個只有你知道的密碼，就能開始配對你的職涯。'
                : '輸入帳號跟密碼，繼續上次沒走完的曖昧。',
            style: const TextStyle(
              fontSize: 12,
              height: 1.55,
              color: AppColors.textTertiary,
            ),
          ),
          AppGaps.h16,
          _label('Email'),
          CupertinoTextField(
            controller: _email,
            placeholder: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          AppGaps.h12,
          _label('密碼'),
          CupertinoTextField(
            controller: _password,
            placeholder: '至少 4 個字元',
            obscureText: true,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            AppGaps.h10,
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.iosRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          AppGaps.h16,
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: AppColors.brandStart,
              disabledColor: AppColors.borderStrong,
              borderRadius: BorderRadius.circular(AppRadii.md),
              onPressed: _canSubmit ? _submit : null,
              child: _busy
                  ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                  : Text(
                      _register ? '建立帳號 ❤' : '登入 ❤',
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.6,
                      ),
                    ),
            ),
          ),
          AppGaps.h10,
          const Center(
            child: Text(
              '注意：此為 demo，密碼不會送到任何伺服器',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          s,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      );

  List<Widget> _floatingHearts(Size size) {
    final spec = <(double, double, double, double)>[
      (size.width * 0.08, size.height * 0.10, 22, 0.18),
      (size.width * 0.85, size.height * 0.12, 16, 0.14),
      (size.width * 0.05, size.height * 0.78, 28, 0.16),
      (size.width * 0.78, size.height * 0.72, 20, 0.18),
      (size.width * 0.92, size.height * 0.42, 14, 0.14),
      (size.width * 0.18, size.height * 0.45, 12, 0.12),
    ];
    return [
      for (final (x, y, s, a) in spec)
        Positioned(
          left: x,
          top: y,
          child: IgnorePointer(
            child: Icon(
              CupertinoIcons.heart_fill,
              size: s,
              color: AppColors.brandStart.withValues(alpha: a),
            ),
          ),
        ),
    ];
  }
}
