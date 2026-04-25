/**
 * Supabase admin client (server-side only).
 *
 * Reads credentials from `process.env`:
 *   - NEXT_PUBLIC_SUPABASE_URL          required
 *   - SUPABASE_SERVICE_ROLE_KEY         required for any write that needs to
 *                                       bypass RLS (server logic acting on
 *                                       behalf of an authenticated user).
 *
 * If either env var is missing, `supabase` is `null` and callers must fall
 * back to the in-memory `store`.
 */
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

let _client: SupabaseClient | null | undefined;

export function getSupabaseAdmin(): SupabaseClient | null {
  if (_client !== undefined) return _client;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) {
    _client = null;
    return null;
  }
  _client = createClient(url, key, {
    auth: {
      // Server doesn't need session persistence — every request gets the
      // user id from its own bearer token (see `lib/auth.ts`).
      autoRefreshToken: false,
      persistSession: false,
    },
  });
  return _client;
}

/** True iff `getSupabaseAdmin()` will return a usable client. */
export function isSupabaseEnabled(): boolean {
  return getSupabaseAdmin() !== null;
}
