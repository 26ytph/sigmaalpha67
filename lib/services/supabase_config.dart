/// Supabase 連線設定。
///
/// ⚠️  使用前請填入你的 Supabase 專案資訊：
/// 1. 到 Supabase Dashboard → Project Settings → API
/// 2. 把 `Project URL` 填到 [supabaseUrl]
/// 3. 把 `anon public` key 填到 [supabaseAnonKey]
///
/// `anon` key 可以放在前端，因為它本身就是公開金鑰，安全性靠 RLS 政策守住。
/// **不要** 把 `service_role` key 放在這裡 — 那只能用在後端。
///
/// 也可以從 build args 注入（CI/不同環境）：
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
/// ```
class SupabaseConfig {
  SupabaseConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    // 注意：只放純 Project URL，**不要**加 '/rest/v1/' 之類的後綴 ——
    // supabase_flutter SDK 會自己 routing 到 /rest /auth /storage。
    defaultValue: 'https://izyznfhixkqocsmigfue.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    // TODO: 把這個 default 換成你的 anon public key，例如
    //   'eyJhbGciOiJIUzI1NiIsInR5cCI6Ik...（很長）'
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml6eXpuZmhpeGtxb2NzbWlnZnVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcwNzA3NzcsImV4cCI6MjA5MjY0Njc3N30.NhX5IVobFVHxOi1ZTbiqLZuHslYV9oRoI7pmhlrf7bc',
  );

  /// 如果上面兩個值都還沒填，就視為「離線 / mock 模式」 —
  /// AuthScreen 會 fall back 回 mock 帳號，AppShell 也不會打 Supabase。
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
