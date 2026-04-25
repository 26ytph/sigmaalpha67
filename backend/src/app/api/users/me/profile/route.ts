import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";
import * as db from "@/lib/db";
import type { Profile, ProfileInput, EducationEntry } from "@/types/profile";

function normaliseEducation(value: unknown): EducationEntry[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((e): EducationEntry | null => {
      if (e && typeof e === "object") {
        const obj = e as Record<string, unknown>;
        return {
          school: typeof obj.school === "string" ? obj.school : "",
          department: typeof obj.department === "string" ? obj.department : "",
          grade: typeof obj.grade === "string" ? obj.grade : "",
        };
      }
      if (typeof e === "string") {
        // legacy: try to split into 3 fields by whitespace / common separators
        const parts = e
          .split(/[\s・·|/，,]+/u)
          .filter((s) => s.length > 0);
        return {
          school: parts[0] ?? "",
          department: parts[1] ?? "",
          grade: parts.slice(2).join(" "),
        };
      }
      return null;
    })
    .filter((e): e is EducationEntry => e !== null);
}

export const GET = withAuth(async (_req, { auth }) => {
  // Try Supabase first; fall back to in-memory.
  const remote = await db.fetchProfile(auth.userId);
  if (remote) {
    store.profiles.set(auth.userId, remote);
    return NextResponse.json({ profile: remote });
  }
  const profile = store.profiles.get(auth.userId);
  if (!profile) return apiError("not_found", "Profile not yet created.");
  return NextResponse.json({ profile });
});

export const PUT = withAuth(async (req, { auth }) => {
  const body = await readJson<Partial<ProfileInput>>(req);
  if (!body || typeof body !== "object") {
    return apiError("bad_request", "Body must be a JSON object.");
  }
  const now = new Date().toISOString();
  const existing = store.profiles.get(auth.userId);
  const profile: Profile = {
    name: body.name ?? existing?.name ?? "",
    school: body.school ?? existing?.school ?? "",
    birthday: body.birthday ?? existing?.birthday ?? "",
    email: body.email ?? existing?.email ?? "",
    phone: body.phone ?? existing?.phone ?? "",
    department: body.department ?? existing?.department ?? "",
    grade: body.grade ?? existing?.grade ?? "",
    location: body.location ?? existing?.location ?? "",
    currentStage: body.currentStage ?? existing?.currentStage ?? "",
    goals: body.goals ?? existing?.goals ?? [],
    interests: body.interests ?? existing?.interests ?? [],
    experiences: body.experiences ?? existing?.experiences ?? [],
    educationItems: body.educationItems
      ? normaliseEducation(body.educationItems)
      : existing?.educationItems ?? [],
    concerns: body.concerns ?? existing?.concerns ?? "",
    startupInterest: body.startupInterest ?? existing?.startupInterest ?? false,
    createdAt: existing?.createdAt ?? now,
    updatedAt: now,
  };
  store.profiles.set(auth.userId, profile);
  // Best-effort sync to Supabase (silently ignored when not configured).
  await db.upsertProfile(auth.userId, profile);
  return NextResponse.json({ profile });
});
