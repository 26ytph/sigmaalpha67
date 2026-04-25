import type { NextRequest } from "next/server";
import { getSupabaseAdmin } from "./supabase";

export type AuthContext = {
  userId: string;
  token: string;
  email?: string;
};

/**
 * Resolve the caller's userId from the Authorization header.
 *
 * 1. If Supabase is configured (`NEXT_PUBLIC_SUPABASE_URL` and
 *    `SUPABASE_SERVICE_ROLE_KEY` set), we treat the bearer token as a
 *    Supabase access JWT and ask Supabase Auth to resolve it.
 *
 * 2. Otherwise (legacy / demo mode), the bearer token *is* the userId,
 *    matching the original fake auth — useful for `curl` / unit tests.
 *
 * 3. If `ALLOW_ANON=1` and no token is provided, we return userId="anon".
 *    Do not enable in production.
 */
export async function authenticate(
  req: NextRequest,
): Promise<AuthContext | null> {
  const header = req.headers.get("authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    if (process.env.ALLOW_ANON === "1") {
      return { userId: "anon", token: "" };
    }
    return null;
  }
  const token = match[1].trim();
  if (!token) return null;

  const supabase = getSupabaseAdmin();
  if (supabase) {
    try {
      const { data, error } = await supabase.auth.getUser(token);
      if (error || !data?.user) return null;
      return {
        userId: data.user.id,
        token,
        email: data.user.email ?? undefined,
      };
    } catch {
      return null;
    }
  }

  // Legacy fake auth — token *is* the user id.
  return { userId: token, token };
}
