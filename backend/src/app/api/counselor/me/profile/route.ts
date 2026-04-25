import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";
import * as db from "@/lib/db";
import type {
  CounselorProfile,
  CounselorProfileInput,
} from "@/types/counselorProfile";

/**
 * 諮詢師端的個人資料（姓名／敘述／專長領域）。
 *
 * 與一般使用者的 /api/users/me/profile 完全分開：
 *   - Supabase 表：public.counselor_profiles（004 migration）
 *   - in-memory：store.counselorProfiles
 *
 * 寫入策略 = write-through cache：
 *   1. 先更新 in-memory（永遠有效，offline 也行）
 *   2. 若有 Supabase 設定，再 upsert 到 Postgres
 */

export const GET = withAuth(async (_req, { auth }) => {
  // 先看 Supabase；找不到就 fall back 到 in-memory
  const remote = await db.fetchCounselorProfile(auth.userId);
  if (remote) {
    store.counselorProfiles.set(auth.userId, remote);
    return NextResponse.json({ profile: remote, exists: true });
  }
  const local = store.counselorProfiles.get(auth.userId);
  if (local) {
    return NextResponse.json({ profile: local, exists: true });
  }
  return NextResponse.json({
    profile: {
      name: "",
      description: "",
      expertise: [],
      email: auth.email ?? "",
      createdAt: "",
      updatedAt: "",
    },
    exists: false,
  });
});

export const PUT = withAuth(async (req, { auth }) => {
  const body = await readJson<Partial<CounselorProfileInput>>(req);
  if (!body || typeof body !== "object") {
    return apiError("bad_request", "Body must be a JSON object.");
  }

  const now = new Date().toISOString();
  const existing =
    store.counselorProfiles.get(auth.userId) ??
    (await db.fetchCounselorProfile(auth.userId));

  const expertise = Array.isArray(body.expertise)
    ? body.expertise
        .filter((s): s is string => typeof s === "string")
        .map((s) => s.trim())
        .filter((s) => s.length > 0)
    : existing?.expertise ?? [];

  const profile: CounselorProfile = {
    name: typeof body.name === "string" ? body.name : existing?.name ?? "",
    description:
      typeof body.description === "string"
        ? body.description
        : existing?.description ?? "",
    expertise,
    email:
      typeof body.email === "string"
        ? body.email
        : existing?.email ?? auth.email ?? "",
    createdAt: existing?.createdAt || now,
    updatedAt: now,
  };
  store.counselorProfiles.set(auth.userId, profile);
  await db.upsertCounselorProfile(auth.userId, profile);
  return NextResponse.json({ profile });
});
