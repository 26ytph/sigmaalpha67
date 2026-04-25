import { NextResponse } from "next/server";
import { readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { getSupabaseAdmin } from "@/lib/supabase";
import type { NextRequest } from "next/server";

type Body = { email?: string; password?: string };

/**
 * 諮詢師端註冊：用 service role key 直接建 user 並把 email 標記為已確認，
 * 跳過 Supabase 預設的 email confirmation 流程。
 *
 * Idempotent：
 *   - email 不存在 → admin.createUser({ email_confirm: true })
 *   - email 已存在 → 找出該 user，admin.updateUserById({ email_confirm: true })
 *     （順手把舊密碼覆蓋成這次填的，避免使用者忘記之前的密碼；demo 用合理）
 *
 * 不用 withAuth()：註冊時還沒 token。
 *
 * 若沒設定 Supabase env，回 500，登入頁會 fallback 到原本的 fake
 * /api/auth/register（demo 模式）。
 */
export async function POST(req: NextRequest) {
  const body = await readJson<Body>(req);
  const email = (body?.email ?? "").trim();
  const password = body?.password ?? "";
  if (!email) return apiError("bad_request", "`email` is required.");
  if (password.length < 4) {
    return apiError("bad_request", "`password` is required (>=4 chars).");
  }

  const supabase = getSupabaseAdmin();
  if (!supabase) {
    return apiError(
      "internal",
      "Supabase is not configured on the server.",
    );
  }

  // 1) 嘗試建立
  const { data, error } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });

  if (!error && data.user) {
    await ensureCounselorMembership(supabase, data.user.id);
    return NextResponse.json({
      user: { id: data.user.id, email: data.user.email ?? email },
      created: true,
    });
  }

  // 2) 失敗了 → 看看是不是已經存在；若是，找出 user 並強制把 email 標為已確認
  const msg = error?.message ?? "";
  const looksLikeExists =
    /already.*registered|already.*exists|duplicate|user.*exists/i.test(msg) ||
    error?.status === 422;
  if (!looksLikeExists) {
    return apiError("internal", msg || "register_failed");
  }

  // 找到既有 user。supabase-js v2 沒有 getUserByEmail，用 listUsers 翻一下；
  // demo 規模這樣就夠，正式環境可換成直接打 GoTrue admin REST。
  let foundId: string | null = null;
  let page = 1;
  while (page <= 10) {
    const { data: list, error: listErr } = await supabase.auth.admin.listUsers({
      page,
      perPage: 200,
    });
    if (listErr) {
      return apiError("internal", listErr.message);
    }
    const hit = list.users.find(
      (u) => (u.email ?? "").toLowerCase() === email.toLowerCase(),
    );
    if (hit) {
      foundId = hit.id;
      break;
    }
    if (list.users.length < 200) break;
    page += 1;
  }

  if (!foundId) {
    return apiError("internal", "user already exists but cannot be located");
  }

  // 強制 confirm + 重設密碼
  const { data: upd, error: updErr } = await supabase.auth.admin.updateUserById(
    foundId,
    {
      email_confirm: true,
      password,
    },
  );
  if (updErr) return apiError("internal", updErr.message);

  await ensureCounselorMembership(supabase, foundId);

  return NextResponse.json({
    user: { id: foundId, email: upd.user?.email ?? email },
    created: false,
    confirmed: true,
  });
}

/**
 * 把 user 加進 public.counselors（active=true）。
 * 已經存在就 no-op；表還沒建（005 migration 沒跑）也 no-op，只 log，
 * 註冊本身不會卡住。
 */
async function ensureCounselorMembership(
  supabase: ReturnType<typeof getSupabaseAdmin>,
  userId: string,
) {
  if (!supabase) return;
  const { error } = await supabase
    .from("counselors")
    .upsert({ user_id: userId, active: true }, { onConflict: "user_id" });
  if (error) {
    console.warn(
      "[register] ensureCounselorMembership failed:",
      error.message,
    );
  }
}
