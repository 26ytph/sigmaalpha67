"use client";

import { createClient, type SupabaseClient } from "@supabase/supabase-js";

/**
 * 諮詢師端瀏覽器側的 Supabase client。
 *
 * 只用 anon key（NEXT_PUBLIC_SUPABASE_ANON_KEY）— RLS 會擋掉越權的讀寫。
 * 如果 env 沒設定，回 null，讓登入頁 fall back 到後端的 fake auth。
 */

let _client: SupabaseClient | null | undefined;

export function getSupabaseBrowser(): SupabaseClient | null {
  if (_client !== undefined) return _client;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) {
    _client = null;
    return null;
  }
  _client = createClient(url, key, {
    auth: {
      // 諮詢師端登入後 token 我們存在 localStorage 給 apiFetch 用，
      // 不靠 supabase-js 自己的 session 持久化（避免兩邊不同步）。
      persistSession: false,
      autoRefreshToken: false,
    },
  });
  return _client;
}

export function isSupabaseBrowserEnabled(): boolean {
  return getSupabaseBrowser() !== null;
}
